#!/usr/bin/env python3
"""Exercise the real CLI and notes transactions in disposable vaults."""

import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]


class TodoTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.skills = self.root / "skills"
        shutil.copytree(SOURCE, self.skills / "todo")
        shutil.copytree(SOURCE.parent / "notes", self.skills / "notes")
        self.vault = self.root / "vault"
        self.vault.mkdir()
        self.cfg = {"scope": "personal", "vault": str(self.vault), "schema": "SCHEMA.md",
                    "checklist": "pages/todos.md", "title": "todos", "tags": ["reference", "todos"], "log_order": "append"}
        self.configure()
        (self.vault / "SCHEMA.md").write_text("# schema\n\nTags and created date are required.\n")
        (self.vault / "index.md").write_text("# index\n")
        (self.vault / "log.md").write_text("# log\n")
        self.git("init", "-b", "main")
        self.git("config", "user.name", "fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("add", ".")
        self.git("commit", "-m", "fixture")

    def tearDown(self):
        self.temp.cleanup()

    def configure(self):
        (self.skills / "todo/references/storage.json").write_text(json.dumps(self.cfg))

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.vault), *args], check=True, text=True, capture_output=True).stdout.strip()

    def run_cli(self, *args):
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        return subprocess.run([sys.executable, str(self.skills / "todo/scripts/todo.py"), *args], text=True, capture_output=True, env=env)

    def request(self, **changes):
        return {"operation": "capture", "scope": self.cfg["scope"], "key": "message-one:plain",
                "action": "Discuss the two navigation choices", "intent": "discuss", "timing": "before wind-down",
                "source": {"chat": "source-chat", "message": "message-one", "title": "Example discussion"}, **changes}

    def write_request(self, request, filename="request.json"):
        path = self.root / filename
        path.write_text(json.dumps(request))
        return path

    def apply(self, request, *, owner="fixture-owner", filename="request.json", success=True):
        path = self.write_request(request, filename)
        result = self.run_cli("apply", "--request", str(path), "--owner", owner)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.git("status", "--porcelain"), "")
            self.assertFalse((self.vault / ".git/status-page-writer.lock").exists())
            return json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0)
        return result

    def show(self, view="all", chat=None):
        args = ["show", "--view", view]
        if chat:
            args += ["--chat", chat]
        result = self.run_cli(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_capture_without_note_and_exact_links(self):
        item = self.apply(self.request())
        self.assertEqual(item["id"], "T001")
        self.assertEqual(item["intent"], "discuss")
        self.assertIsNone(item["artifact"])
        path, line = item["file_link"].rsplit(":", 1)
        self.assertIn("^todo-001", Path(path).read_text().splitlines()[int(line)-1])
        self.assertEqual(item["block"], "[[pages/todos#^todo-001]]")
        self.assertIn("%23%5Etodo-001", item["obsidian_link"])
        self.assertEqual(self.show("session", "source-chat")[0]["id"], "T001")
        self.assertEqual(sorted(p.name for p in (self.vault / "pages").iterdir()), ["todos.md"])

    def test_annotation_and_optional_context_survive(self):
        source = {"chat": "chat-two", "message": "capture-two", "annotation": {"message": "response-one", "start": 14, "end": 87}}
        item = self.apply(self.request(source=source, key="capture-two:annotation-1", artifact="https://example.invalid/pull/7", project="example"))
        self.assertEqual(item["source"], source)
        self.assertEqual(item["artifact"], "https://example.invalid/pull/7")
        self.assertEqual(item["project"], "example")

    def test_retry_deduplicates_without_log_or_commit(self):
        request = self.request()
        self.apply(request)
        head, log = self.git("rev-parse", "HEAD"), (self.vault / "log.md").read_bytes()
        item = self.apply(request)
        self.assertEqual(item["id"], "T001")
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertEqual((self.vault / "log.md").read_bytes(), log)
        result = self.apply(self.request(action="Different request"), success=False)
        self.assertIn("different request", result.stderr)

    def test_views_ignore_source_liveness_and_keep_someday_separate(self):
        self.apply(self.request())
        self.apply(self.request(key="future", action="Consider a future model change", intent="consider", bucket="someday", timing="someday", source={"chat": "archived-source"}))
        self.assertEqual([i["id"] for i in self.show("outstanding")], ["T001"])
        self.assertEqual([i["id"] for i in self.show("someday")], ["T002"])
        self.assertEqual(self.show("session", "archived-source")[0]["id"], "T002")

    def test_defer_transfer_complete_preserve_identity_source_and_history(self):
        initial = self.apply(self.request())
        deferred = self.apply({"operation": "defer", "scope": "personal", "key": "defer-one", "id": "T001", "reason": "User chose a later discussion", "timing": "next session"})
        self.assertEqual(deferred["status"], "deferred")
        self.assertEqual(self.show("outstanding")[0]["id"], "T001")
        moved = self.apply({"operation": "transfer", "scope": "personal", "key": "carry-one", "id": "T001", "reason": "User chose the successor", "successor": "next-chat"})
        self.assertEqual(moved["source"], initial["source"])
        self.assertEqual(moved["block"], initial["block"])
        self.assertEqual(moved["status"], "deferred")
        self.assertEqual(self.show("session", "source-chat"), [])
        self.assertEqual(self.show("session", "next-chat")[0]["id"], "T001")
        done = self.apply({"operation": "complete", "scope": "personal", "key": "done-one", "id": "T001", "reason": "User marked discussion complete"})
        self.assertEqual(done["status"], "done")
        self.assertEqual(self.show("outstanding"), [])
        text = (self.vault / "pages/todos.md").read_text()
        for key in ("message-one:plain", "defer-one", "carry-one", "done-one"):
            self.assertIn(key, text)

    def test_drop_remains_in_history(self):
        self.apply(self.request())
        dropped = self.apply({"operation": "drop", "scope": "personal", "key": "drop-one", "id": "T001", "reason": "User no longer wants this"})
        self.assertEqual(dropped["status"], "dropped")
        self.assertEqual(self.show("outstanding"), [])
        self.assertEqual(self.show()[0]["id"], "T001")

    def test_concurrent_captures_allocate_unique_ids_and_retry_one_request(self):
        paths = [self.write_request(self.request(key=f"parallel-{i}"), f"request-{i}.json") for i in range(6)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(lambda pair: self.run_cli("apply", "--request", str(pair[1]), "--owner", f"writer-{pair[0]}"), enumerate(paths)))
        for result in results:
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual({item["id"] for item in self.show()}, {f"T{i:03d}" for i in range(1, 7)})
        same = self.write_request(self.request(key="same-retry"), "same.json")
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda owner: self.run_cli("apply", "--request", str(same), "--owner", owner), ["retry-a", "retry-b"]))
        for result in results:
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.show()), 7)
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_legacy_annotation_preserves_text_anchor_and_allocates_after_seeds(self):
        path = self.vault / "pages/todos.md"
        path.parent.mkdir()
        seed = "---\ntags: [reference, todos]\ncreated: 2026-01-01\n---\n\n# todos\n\n## discuss before session wind-down\n\n- [ ] **T001 — Discuss the options.** Capture only. ^todo-001\n\n## someday\n\n- [ ] **T002 — Consider a future change.** No work scheduled. ^todo-002\n"
        path.write_text(seed)
        (self.vault / "index.md").write_text("# index\n\n- [[todos]] — follow-ups\n")
        self.git("add", ".")
        self.git("commit", "-m", "legacy fixture")
        for ident, bucket in (("T001", "outstanding"), ("T002", "someday")):
            request = self.request(operation="annotate", id=ident, key=f"migration-{ident}", bucket=bucket)
            del request["action"]
            self.apply(request)
        after = path.read_text()
        self.assertEqual("\n".join(line for line in after.splitlines() if not line.startswith("  <!-- todo:")) + "\n", seed)
        self.assertEqual(self.apply(self.request())["id"], "T003")

    def test_content_is_never_executed(self):
        marker = self.root / "unexpected-execution"
        text = f"Consider $(touch {marker}) and `touch {marker}` <script>alert(1)</script>"
        self.apply(self.request(action=text, intent="consider"))
        self.assertFalse(marker.exists())
        self.assertIn("&lt;script&gt;", self.show()[0]["action"])

    def test_scope_mismatch_and_symlink_escape_fail_before_write(self):
        before = self.git("rev-parse", "HEAD")
        self.apply(self.request(scope="work"), success=False)
        self.assertEqual(self.git("rev-parse", "HEAD"), before)
        outside = self.root / "outside"
        outside.mkdir()
        (self.vault / "pages").symlink_to(outside, target_is_directory=True)
        self.apply(self.request(), success=False)
        self.assertEqual(list(outside.iterdir()), [])

    def test_work_log_prepends_and_never_touches_other_vault(self):
        self.cfg.update(scope="work", log_order="prepend")
        self.configure()
        (self.root / "personal-vault").mkdir()
        self.apply(self.request(key="first"))
        self.apply(self.request(key="second"))
        text = (self.vault / "log.md").read_text()
        self.assertLess(text.index("capture T002"), text.index("capture T001"))
        self.assertEqual(list((self.root / "personal-vault").iterdir()), [])

    def test_symlinked_installed_skill_finds_sibling_notes(self):
        installed = self.root / "installed"
        installed.mkdir()
        (installed / "todo").symlink_to(self.skills / "todo", target_is_directory=True)
        (installed / "notes").symlink_to(self.skills / "notes", target_is_directory=True)
        path = self.write_request(self.request())
        result = subprocess.run([sys.executable, str(installed / "todo/scripts/todo.py"), "apply", "--request", str(path), "--owner", "installed-owner"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["id"], "T001")

    def test_direct_store_path_uses_packaged_transaction_dependency(self):
        isolated = self.root / "store-skill"
        shutil.copytree(self.skills / "todo", isolated)
        (isolated / "scripts/vault-transaction.py").symlink_to(self.skills / "notes/scripts/vault-transaction.py")
        path = self.write_request(self.request())
        result = subprocess.run([sys.executable, str(isolated / "scripts/todo.py"), "apply", "--request", str(path), "--owner", "store-owner"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["id"], "T001")

    def test_dirty_vault_and_bad_request_are_not_saved(self):
        (self.vault / "unrelated.md").write_text("another writer\n")
        result = self.apply(self.request(), success=False)
        self.assertIn("dirty preflight", result.stderr)
        self.assertFalse((self.vault / "pages/todos.md").exists())
        (self.vault / "unrelated.md").unlink()
        result = self.apply(self.request(artifact="javascript:alert(1)"), success=False)
        self.assertIn("HTTPS", result.stderr)


if __name__ == "__main__":
    unittest.main()
