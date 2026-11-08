#!/usr/bin/env python3
"""Exercise local review comparisons with real Git; this does not test app rendering."""

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

    def commit(self, name, content):
        (self.repo / name).write_text(content)
        self.git("add", name)
        self.git("commit", "-m", name)
        return self.git("rev-parse", "HEAD")

    def files(self, base, head):
        return self.git("diff", "--name-only", f"{base}...{head}").splitlines()

    def snapshot(self, name, head):
        path = self.root / name
        self.git("worktree", "add", "--detach", str(path), head)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=path), head)
        self.assertEqual(self.git("status", "--porcelain", cwd=path), "")
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "HEAD", cwd=path), "HEAD")
        return path

    def test_dedicated_snapshots_show_only_each_layer(self):
        first = self.snapshot("first-review", self.parent)
        second = self.snapshot("second-review", self.child)
        self.assertEqual(self.files(self.trunk, self.parent), ["parent.txt"])
        self.assertEqual(self.files(self.parent, self.child), ["child.txt"])
        self.assertEqual(self.files(self.trunk, self.child), ["child.txt", "parent.txt"])
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=first), self.parent)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=second), self.child)
        self.assertEqual(self.git("branch", "--show-current"), "child")

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


if __name__ == "__main__":
    unittest.main()
