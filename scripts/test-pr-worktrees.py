#!/usr/bin/env python3
"""Check the planner with disposable Git checkouts and modeled Desktop readback."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


OWNER = "11111111-1111-4111-8111-111111111111"
CLAIMANT = "22222222-2222-4222-8222-222222222222"
UNRELATED = "33333333-3333-4333-8333-333333333333"
URL = "https://github.com/example/app/pull/12"
SCRIPT = Path(__file__).resolve().parents[1] / "dotfiles/claude/skills/pr-worktrees/scripts/plan.py"
SPEC = importlib.util.spec_from_file_location("pr_worktrees", SCRIPT)
planner = importlib.util.module_from_spec(SPEC)
sys.dont_write_bytecode = True
SPEC.loader.exec_module(planner)


class ReviewPlanTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.repo = self.root / "source"
        self.repo.mkdir()
        env = patch.dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        env.start()
        self.addCleanup(env.stop)
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Review Fixture")
        self.git("config", "user.email", "review@example.invalid")
        self.git("remote", "add", "origin", "git@github.com:example/app.git")
        self.base = self.commit("common.txt", "base\n")
        self.git("switch", "-c", "feature")
        self.head = self.commit("feature.txt", "feature\n")
        self.git("switch", "main")
        self.data = {
            "threadId": OWNER,
            "artifacts": [],
            "verifiedBindings": [],
            "claims": [],
            "pulls": [{
                "url": URL, "state": "OPEN", "isDraft": True, "sourceRoot": str(self.repo),
                "remote": "origin", "headRepository": "example/app", "headRefName": "feature",
                "headRefOid": self.head, "baseRefName": "main", "baseRefOid": self.base,
                "stackParent": False,
            }],
        }

    def git(self, *args, cwd=None):
        return subprocess.check_output(
            ["git", *args], cwd=cwd or self.repo, stderr=subprocess.PIPE, text=True,
        ).strip()

    def commit(self, name, text):
        (self.repo / name).write_text(text)
        self.git("add", name)
        self.git("commit", "-m", name)
        return self.git("rev-parse", "HEAD")

    def detached(self, name="review one"):
        path = self.root / name
        self.git("worktree", "add", "--detach", str(path), self.head)
        return path

    def attach(self, path, *, paired=False):
        self.data["artifacts"] += [
            {"attachmentType": "linked_worktree", "identityKey": str(path), "payload": {"root": str(path)}},
            {"attachmentType": "pull_request", "payload": {"url": URL, "root": str(path) if paired else None}},
        ]
        self.data["verifiedBindings"].append({"threadId": OWNER, "url": URL, "path": str(path)})

    def result(self):
        return planner.plan(self.data)[0]

    def test_create_once_then_reuse_same_path_and_attachments(self):
        unused = self.result()
        self.assertEqual(unused["action"], "create")
        self.assertEqual(unused["ref"], self.head)
        self.assertEqual(unused["checkoutName"], "app-pr12")
        self.assertTrue(unused["attachPr"])
        path = self.detached("review with spaces 東京")
        self.attach(path)
        before = self.git("worktree", "list", "--porcelain")
        first = self.result()
        self.assertEqual(first["action"], "reuse")
        self.assertEqual(first["path"], str(path))
        self.assertEqual(first["attachment"], str(path))
        self.assertFalse(first["attachPr"])
        self.assertFalse(first["nativePairVerified"])
        self.assertEqual(first["review"]["baseBranch"], self.base)
        self.assertEqual(self.git("diff", "--name-only", f"{self.base}...{self.head}", cwd=path), "feature.txt")
        self.assertEqual(self.result(), first)
        self.assertEqual(self.git("worktree", "list", "--porcelain"), before)
        self.data["artifacts"][1]["payload"]["root"] = str(path)
        self.assertTrue(self.result()["nativePairVerified"])

    def test_numbered_checkout_name_uses_series_position_and_description(self):
        for branch, expected in [
            ("owner/ticket-123-pr12.3-example-change", "pr12.3-example-change"),
            ("owner/pr9.10-update-v2.3", "pr9.10-update-v2.3"),
            ("pr4-fix-example", "pr4-fix-example"),
            ("owner/ticket-123-repr12.3-example", "app-pr12"),
        ]:
            with self.subTest(branch=branch):
                self.data["pulls"][0]["headRefName"] = branch
                row = self.result()
                self.assertEqual(row["action"], "create")
                self.assertEqual(row["checkoutName"], expected)

    def test_ambiguous_numbered_name_holds_creation_but_allows_proven_reuse(self):
        for branch, reason in [
            ("owner/ticket-123-pr12.3", "missing a description"),
            ("owner/pr12.3-example-pr12.4-other", "multiple numbered series positions"),
        ]:
            with self.subTest(branch=branch):
                self.data["pulls"][0]["headRefName"] = branch
                row = self.result()
                self.assertEqual(row["action"], "hold")
                self.assertIn(reason, row["reason"])
                self.assertNotIn("checkoutName", row)
        path = self.detached("previous name")
        self.attach(path)
        self.assertEqual(self.result()["action"], "reuse")
        self.assertEqual(self.result()["path"], str(path))

    def test_in_place_move_and_desktop_attachment_have_separate_readback(self):
        old = self.detached("old review name")
        self.attach(old, paired=True)
        new = self.root / "pr12.3-example-change"
        git_dir = self.git("rev-parse", "--absolute-git-dir", cwd=old)
        self.git("worktree", "move", str(old), str(new))
        self.assertFalse(old.exists())
        self.assertEqual(self.git("rev-parse", "--absolute-git-dir", cwd=new), git_dir)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=new), self.head)
        self.assertEqual(self.git("status", "--porcelain", cwd=new), "")
        self.assertEqual(self.result()["action"], "hold")
        self.assertFalse(self.result()["nativePairVerified"])
        # Model the attachment readback after the app has registered the new path.
        self.data["artifacts"][0]["payload"]["root"] = str(new)
        self.data["artifacts"][0]["identityKey"] = str(new)
        self.data["artifacts"][1]["payload"]["root"] = None
        self.data["verifiedBindings"][0]["path"] = str(new)
        row = self.result()
        self.assertEqual(row["action"], "reuse")
        self.assertEqual(row["path"], str(new))
        self.assertFalse(row["nativePairVerified"])
        self.data["artifacts"][1]["payload"]["root"] = str(new)
        self.assertTrue(self.result()["nativePairVerified"])

    def test_existing_dirty_checkout_is_preserved_even_with_published_head(self):
        path = self.detached()
        self.attach(path, paired=True)
        (path / "feature.txt").write_text("staged edit\n")
        self.git("add", "feature.txt", cwd=path)
        (path / "feature.txt").write_text("unstaged edit\n")
        (path / "untracked.txt").write_text("user file\n")
        before = self.git("status", "--porcelain", cwd=path)
        row = self.result()
        self.assertEqual(row["action"], "reuse")
        self.assertIn("has local changes", row["reason"])
        self.assertNotIn("review", row)
        self.assertEqual(self.git("status", "--porcelain", cwd=path), before)
        self.assertEqual((path / "feature.txt").read_text(), "unstaged edit\n")
        self.assertEqual((path / "untracked.txt").read_text(), "user file\n")

    def test_existing_unattached_tracking_checkout_is_not_duplicated(self):
        path = self.root / "implementation"
        self.git("config", "branch.feature.remote", "origin")
        self.git("config", "branch.feature.merge", "refs/heads/feature")
        self.git("worktree", "add", str(path), "feature")
        row = self.result()
        self.assertEqual(row["action"], "reuse")
        self.assertEqual(row["path"], str(path))
        self.assertIsNone(row["attachment"])

    def test_duplicate_claim_names_only_verified_blocking_chat(self):
        kept = self.detached()
        duplicate = self.detached("duplicate")
        self.attach(kept, paired=True)
        self.data["claims"] = [
            {"threadId": CLAIMANT, "path": str(duplicate / "subdir")},
            {"threadId": UNRELATED, "path": str(self.root / "duplicate-other")},
        ]
        row = self.result()
        self.assertEqual(row["path"], str(kept))
        self.assertEqual(row["duplicates"], [str(duplicate)])
        self.assertEqual(row["candidates"][0], {
            "path": str(duplicate), "blockingChats": [f"codex://threads/{CLAIMANT}"],
        })
        self.assertTrue(duplicate.is_dir())
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=duplicate), self.head)
        self.data["claims"] = []
        self.assertEqual(self.result()["candidates"][0]["blockingChats"], [])
        self.assertTrue(duplicate.is_dir())

    def test_same_sha_without_proven_identity_holds_creation(self):
        path = self.detached()
        result = self.result()
        self.assertEqual(result["action"], "hold")
        self.assertEqual(result["candidates"], [{"path": str(path), "blockingChats": []}])

    def test_registered_missing_path_does_not_get_replaced(self):
        path = self.detached()
        self.attach(path)
        path.rename(self.root / "moved")
        self.assertEqual(self.result()["action"], "hold")
        self.assertIn("missing", self.result()["reason"])

    def test_missing_old_attachment_does_not_hide_the_one_existing_checkout(self):
        older = self.detached("gone")
        current = self.detached("current")
        self.attach(current)
        self.data["verifiedBindings"].append({"threadId": OWNER, "url": URL, "path": str(older)})
        older.rename(self.root / "old-saved-elsewhere")
        row = self.result()
        self.assertEqual(row["action"], "reuse")
        self.assertEqual(row["path"], str(current))
        self.assertEqual(row["duplicates"], [str(older)])
        self.assertFalse(older.exists())

    def test_base_move_reuses_checkout_and_uses_new_base(self):
        path = self.detached()
        self.attach(path)
        later = self.commit("extra.txt", "base-only\n")
        self.data["pulls"][0]["baseRefOid"] = later
        self.assertEqual(self.result()["path"], str(path))
        self.assertEqual(self.result()["review"]["baseBranch"], later)
        self.assertEqual(self.git("diff", "--name-only", f"{later}...{self.head}", cwd=path), "feature.txt")
        self.data["pulls"][0]["stackParent"] = True
        self.assertIn("stack parent is not an ancestor", self.result()["reason"])
        self.assertNotIn("review", self.result())

    def test_different_head_preserves_checkout_pending_safe_refresh(self):
        path = self.detached()
        self.attach(path)
        self.git("switch", "feature")
        new_head = self.commit("feature.txt", "published update\n")
        self.data["pulls"][0]["headRefOid"] = new_head
        row = self.result()
        self.assertEqual(row["path"], str(path))
        self.assertEqual(row["localHead"], self.head)
        self.assertNotIn("review", row)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=path), self.head)

    def test_wrong_repository_and_conflicting_receipt_fail_closed(self):
        self.data["pulls"][0]["url"] = "https://github.com/another/app/pull/12"
        with self.assertRaisesRegex(ValueError, "remote.*does not match"):
            self.result()
        self.data["pulls"][0]["url"] = URL
        path = self.detached()
        self.attach(path)
        self.data["verifiedBindings"].append({
            "threadId": OWNER, "url": "https://github.com/example/app/pull/13", "path": str(path),
        })
        with self.assertRaisesRegex(ValueError, "two PRs claim"):
            self.result()

    def test_cli_skips_closed_and_deduplicates_open_prs(self):
        pull = self.data["pulls"][0]
        self.data["pulls"] += [pull, dict(pull, state="CLOSED", url=URL.replace("/12", "/13"))]
        fixture = self.root / "snapshot.json"
        fixture.write_text(json.dumps(self.data))
        actual = subprocess.check_output([sys.executable, str(SCRIPT), str(fixture)], text=True)
        self.assertEqual(json.loads(actual), [self.result()])


if __name__ == "__main__":
    unittest.main()
