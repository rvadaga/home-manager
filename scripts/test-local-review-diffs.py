#!/usr/bin/env python3
"""Exercise review comparisons with real Git and model app observations with fixtures."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class LocalReviewDiffTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "source"
        self.repo.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Test User")
        self.git("config", "user.email", "test@example.invalid")
        self.trunk = self.commit("common.txt", "shared\n")
        self.git("switch", "-c", "parent")
        self.parent = self.commit("parent.txt", "parent change\n")
        self.git("switch", "-c", "child")
        self.child = self.commit("child.txt", "child change\n")

    def git(self, *args, cwd=None):
        return subprocess.check_output(
            ["git", *args], cwd=cwd or self.repo, env=self.env, stderr=subprocess.PIPE
        ).decode().strip()

    def commit(self, name, content, *, repo=None):
        repo = repo or self.repo
        (repo / name).write_text(content)
        self.git("add", name, cwd=repo)
        self.git("commit", "-m", name, cwd=repo)
        return self.git("rev-parse", "HEAD", cwd=repo)

    def files(self, base, head, *, cwd=None):
        return self.git("diff", "--name-only", f"{base}...{head}", cwd=cwd).splitlines()

    def snapshot(self, name, head, *, repo=None):
        path = self.root / name
        self.git("worktree", "add", "--detach", str(path), head, cwd=repo)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=path), head)
        self.assertEqual(self.git("status", "--porcelain", cwd=path), "")
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "HEAD", cwd=path), "HEAD")
        return path

    def test_dedicated_snapshots_show_only_each_layer(self):
        first = self.snapshot("pr42-1-app", self.parent)
        second = self.snapshot("pr42-2-app", self.child)
        self.assertEqual(self.files(self.trunk, self.parent, cwd=first), ["parent.txt"])
        self.assertEqual(self.files(self.parent, self.child, cwd=second), ["child.txt"])
        self.assertEqual(self.files(self.trunk, self.child), ["child.txt", "parent.txt"])
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=first), self.parent)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=second), self.child)
        self.assertEqual(self.git("branch", "--show-current"), "child")

    def test_merge_labels_follow_cross_repo_order_and_keep_repo_bases(self):
        tools = self.root / "tools"
        tools.mkdir()
        self.git("init", "-b", "main", cwd=tools)
        self.git("config", "user.name", "Test User", cwd=tools)
        self.git("config", "user.email", "test@example.invalid", cwd=tools)
        tools_base = self.commit("common.txt", "tools base\n", repo=tools)
        self.git("switch", "-c", "tools-feature", cwd=tools)
        tools_head = self.commit("tools.txt", "new tools\n", repo=tools)

        # The approved order interleaves repos, but Git comparisons never do.
        parts = [
            ("pr42-1-app", self.repo, self.trunk, self.parent, "parent.txt"),
            ("pr42-2-tools", tools, tools_base, tools_head, "tools.txt"),
            ("pr42-3-app", self.repo, self.parent, self.child, "child.txt"),
        ]
        for label, repo, base, head, expected in parts:
            path = self.snapshot(label, head, repo=repo)
            self.assertEqual(self.files(base, head, cwd=path), [expected])
        standalone = self.snapshot("tools-pr717", tools_head, repo=tools)
        self.assertEqual(self.files(tools_base, tools_head, cwd=standalone), ["tools.txt"])

    def test_advanced_target_excludes_base_only_changes(self):
        self.git("switch", "parent")
        advanced = self.commit("later-parent.txt", "later parent change\n")
        self.assertEqual(self.git("merge-base", advanced, self.child), self.parent)
        self.assertEqual(self.files(advanced, self.child), ["child.txt"])
        self.assertEqual(
            self.git("diff", "--name-only", f"{advanced}..{self.child}").splitlines(),
            ["child.txt", "later-parent.txt"],
        )

    def test_rewritten_parent_can_expose_an_earlier_layer(self):
        self.git("switch", "-c", "replacement-parent", self.trunk)
        replacement = self.commit("parent.txt", "revised parent change\n")
        self.assertEqual(self.git("merge-base", replacement, self.child), self.trunk)
        self.assertEqual(self.files(replacement, self.child), ["child.txt", "parent.txt"])
        self.assertNotEqual(self.files(replacement, self.child), self.files(self.parent, self.child))

    def test_new_snapshot_preserves_edits_in_old_snapshot(self):
        old = self.snapshot("old-review", self.child)
        (old / "child.txt").write_text("user edit\n")
        updated = self.commit("child.txt", "published update\n")
        self.assertNotEqual(self.git("rev-parse", "HEAD", cwd=old), updated)
        self.assertNotEqual(self.git("status", "--porcelain", cwd=old), "")
        new = self.snapshot("new-review", updated)
        self.assertEqual((old / "child.txt").read_text(), "user edit\n")
        self.assertEqual((new / "child.txt").read_text(), "published update\n")
        self.assertEqual(self.git("rev-parse", "child"), updated)
        self.assertEqual(self.git("rev-parse", "parent"), self.parent)
        self.assertEqual(self.files(self.parent, updated), ["child.txt"])

    def entry_state(self, path, head, base, attachments, panel, *, owner="owner"):
        if path not in attachments.get(owner, ()):
            return "unattached"
        if self.git("rev-parse", "HEAD", cwd=path) != head:
            return "stale checkout"
        if not panel or (panel["chat"], panel["path"], panel["base"]) != (owner, path, base):
            return "unverified comparison"
        if panel["state"] == "inspected" and (
            panel.get("head") != head
            or panel.get("diff") != self.git("diff", f"{base}...{head}", cwd=path)
        ):
            return "unverified comparison"
        return panel["state"]

    def inspected_panel(self, path, head, base):
        return dict(chat="owner", path=path, head=head, base=base, state="inspected",
                    diff=self.git("diff", f"{base}...{head}", cwd=path))

    def inventory(self, published, entries):
        """Model the picker readback with supplied app rows and actual local Git."""
        result = {}
        for key, name, head, base, expected_files in published:
            matches = [
                row
                for row in entries
                if (row["key"], row["purpose"]) == (key, "review")
                and self.git("rev-parse", "HEAD", cwd=row["path"]) == head
                and not self.git("status", "--porcelain", cwd=row["path"])
            ]
            if len(matches) != 1:
                result[key] = (None, "ambiguous" if matches else "missing exact checkout")
                continue
            row = matches[0]
            path = row["path"]
            if self.files(base, head, cwd=path) != expected_files:
                result[key] = (path, "wrong layer diff")
                continue
            owner = key[0]
            attachments = {owner: [path]} if row["attached"] else {}
            state = self.entry_state(
                path, head, base, attachments, row["panel"], owner=owner
            )
            if state == "inspected" and row["name"] != name:
                state = "verified with different name"
            result[key] = (path, state)
        return result

    def test_current_inventory_reuses_one_exact_snapshot_per_published_layer(self):
        bottom_key = ("owner", "example/app", 462)
        top_key = ("owner", "example/app", 461)
        bottom = self.snapshot("pr42-1-app", self.parent)
        top = self.snapshot("pr42-2-app", self.child)
        published = [
            (bottom_key, bottom.name, self.parent, self.trunk, ["parent.txt"]),
            (top_key, top.name, self.child, self.parent, ["child.txt"]),
        ]
        bottom_row = dict(key=bottom_key, name=bottom.name, path=bottom, purpose="review",
                          attached=True, panel=self.inspected_panel(bottom, self.parent, self.trunk))
        top_row = dict(key=top_key, name=top.name, path=top, purpose="review", attached=True,
                       panel=self.inspected_panel(top, self.child, self.parent))
        unrelated = [
            dict(top_row, key=("owner", "example/app", 463)),  # older open draft
            dict(top_row, key=("owner", "example/tools", 461)),
            dict(top_row, key=("another-chat", "example/app", 461)),
            dict(top_row, name=f"{top.name}-local", purpose="local candidate"),
        ]
        rows = [top_row, *unrelated, bottom_row]
        observed = self.inventory(published, rows)
        self.assertEqual(list(observed.items()), [
            (bottom_key, (bottom, "inspected")),
            (top_key, (top, "inspected")),
        ])
        self.assertEqual(self.inventory(published, rows), observed)
        self.assertEqual(self.inventory(published, [dict(top_row, name="old-name"),
                                                    *rows[1:]])[top_key],
                         (top, "verified with different name"))

        # Requesting or retrying inspection keeps the same checkout; it cannot prove rendering.
        self.assertEqual(self.inventory(published, [dict(top_row, panel=None), *rows[1:]])[top_key],
                         (top, "unverified comparison"))
        self.assertEqual(self.inventory(published, [dict(top_row, attached=False),
                                                    *rows[1:]])[top_key], (top, "unattached"))
        duplicate = self.snapshot("another-copy", self.child)
        duplicate_rows = [*rows, dict(top_row, path=duplicate)]
        self.assertEqual(self.inventory(published, duplicate_rows)[top_key], (None, "ambiguous"))
        (duplicate / "keep.txt").write_text("uncommitted change\n")
        self.assertEqual(self.inventory(published, duplicate_rows)[top_key], (top, "inspected"))
        self.assertEqual(self.inventory(published, unrelated)[top_key],
                         (None, "missing exact checkout"))

        changed_head = self.commit("child.txt", "new published revision\n")
        changed = [(top_key, top.name, changed_head, self.parent, ["child.txt"])]
        self.assertEqual(self.inventory(changed, rows)[top_key], (None, "missing exact checkout"))
        wrong_base = [(top_key, top.name, self.child, self.trunk, ["child.txt"])]
        self.assertEqual(self.inventory(wrong_base, rows)[top_key], (top, "wrong layer diff"))

    def test_refresh_checks_head_base_owner_and_rendering_separately(self):
        path = self.snapshot("app-pr461", self.child)
        panel = {"chat": "owner", "path": path, "base": self.parent, "state": "queued"}
        given = {"owner": [path]}
        self.assertEqual(self.entry_state(path, self.child, self.parent, {}, panel), "unattached")
        self.assertEqual(self.entry_state(path, self.child, self.parent, given, panel), "queued")
        panel = self.inspected_panel(path, self.child, self.parent)
        wrong_chat = dict(panel, chat="internal")
        self.assertEqual(self.entry_state(path, self.child, self.parent, given, wrong_chat),
                         "unverified comparison")
        wrong_base = dict(panel, base=self.trunk)
        self.assertEqual(self.entry_state(path, self.child, self.parent, given, wrong_base),
                         "unverified comparison")
        wrong_diff = dict(panel, diff=self.git("diff", f"{self.trunk}...{self.child}"))
        self.assertEqual(self.entry_state(path, self.child, self.parent, given, wrong_diff),
                         "unverified comparison")
        self.assertEqual(self.entry_state(path, self.child, self.parent, given, panel), "inspected")

        updated = self.commit("child.txt", "published update\n")
        self.assertEqual(self.entry_state(path, updated, self.parent, given, panel), "stale checkout")
        self.git("switch", "--detach", updated, cwd=path)
        self.git("switch", "parent")
        new_base = self.commit("parent-later.txt", "new base\n")
        self.assertEqual(self.entry_state(path, updated, new_base, given, panel),
                         "unverified comparison")
        self.assertEqual(self.files(new_base, updated, cwd=path), ["child.txt"])
        self.assertEqual(self.entry_state(path, updated, new_base, given,
                                         self.inspected_panel(path, updated, new_base)), "inspected")

    def can_retire(self, path, *, replacement_state, other_claimants=(), checkout_unused=True,
                   still_open_review=False, squash_pr=None, archive_refused=False):
        if (replacement_state != "inspected" or not checkout_unused or still_open_review
                or other_claimants or archive_refused):
            return False
        if self.git("status", "--porcelain", cwd=path):
            return False
        head = self.git("rev-parse", "HEAD", cwd=path)
        remote = self.git("ls-remote", str(self.repo), "refs/heads/child")
        if remote:
            try:
                self.git("merge-base", "--is-ancestor", head, remote.split()[0], cwd=path)
            except subprocess.CalledProcessError as exc:
                if exc.returncode != 1:
                    raise
            else:
                return True
        return bool(squash_pr and squash_pr["state"] == "MERGED" and squash_pr["mergedAt"]
                    and squash_pr["headRefOid"] == head)

    def naming_action(self, *, supports_rename, predecessor_safe, archive_refused=False):
        if archive_refused:
            return "keep existing attachment"
        if supports_rename:
            return "rename in place"
        if predecessor_safe:
            return "replace and verify retirement"
        return "keep existing attachment"

    def test_rename_only_keeps_existing_when_retirement_is_unverified_or_refused(self):
        old = self.snapshot("short-name", self.child)
        self.assertEqual(self.naming_action(supports_rename=True, predecessor_safe=False),
                         "rename in place")
        self.assertEqual(self.naming_action(supports_rename=False, predecessor_safe=False),
                         "keep existing attachment")
        self.assertEqual(self.naming_action(supports_rename=False, predecessor_safe=True,
                                            archive_refused=True),
                         "keep existing attachment")
        self.assertEqual(self.naming_action(supports_rename=False, predecessor_safe=True),
                         "replace and verify retirement")
        self.assertFalse(self.can_retire(old, replacement_state="queued"))
        self.assertTrue(self.can_retire(old, replacement_state="inspected"))

    def test_refusal_links_only_a_verified_claimant_for_the_exact_checkout(self):
        def observed_refusal(path, named_claimant, verified_claims):
            linked = named_claimant if (named_claimant, path) in verified_claims else None
            return named_claimant or "unnamed", linked

        old = self.snapshot("old-copy", self.child)
        self.assertEqual(observed_refusal(old, None, []), ("unnamed", None))
        self.assertEqual(observed_refusal(old, "creator", []), ("creator", None))
        self.assertEqual(observed_refusal(old, "reviewer", [("reviewer", self.repo)]),
                         ("reviewer", None))
        self.assertEqual(observed_refusal(old, "reviewer", [("reviewer", old)]),
                         ("reviewer", "reviewer"))
        self.assertFalse(self.can_retire(old, replacement_state="inspected", archive_refused=True))
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=old), self.child)

    def test_retirement_keeps_queued_dirty_shared_and_unpublished_copies(self):
        old = self.snapshot("old-review", self.child)
        self.assertTrue(self.can_retire(old, replacement_state="inspected"))
        self.assertFalse(self.can_retire(old, replacement_state="queued"))
        self.assertFalse(self.can_retire(old, replacement_state="inspected", checkout_unused=False))
        self.assertFalse(self.can_retire(old, replacement_state="inspected", still_open_review=True))
        self.assertFalse(self.can_retire(old, replacement_state="inspected",
                                         other_claimants=("archived-chat",)))
        edit = old / "untracked.txt"
        edit.write_text("keep this\n")
        self.assertFalse(self.can_retire(old, replacement_state="inspected"))
        self.assertEqual(edit.read_text(), "keep this\n")
        edit.unlink()
        self.commit("child.txt", "new remote revision\n")
        self.assertTrue(self.can_retire(old, replacement_state="inspected"))
        orphan = self.commit("local.txt", "needs publication\n", repo=old)
        self.assertFalse(self.can_retire(old, replacement_state="inspected"))
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=old), orphan)

    def test_retirement_requires_exact_submitted_head_after_squash(self):
        old = self.snapshot("old-implementation", self.child)
        self.git("switch", "parent")
        self.git("branch", "-D", "child")
        self.assertFalse(self.can_retire(old, replacement_state="inspected"))

        # Model GitHub's independent merged-PR readback after branch deletion.
        squash_pr = {"state": "MERGED", "mergedAt": "2025-01-01T00:00:00Z",
                     "headRefOid": self.child}
        self.assertTrue(self.can_retire(
            old, replacement_state="inspected", squash_pr=squash_pr
        ))
        self.assertFalse(self.can_retire(
            old, replacement_state="inspected", squash_pr=dict(squash_pr, headRefOid=self.parent)
        ))


if __name__ == "__main__":
    unittest.main()
