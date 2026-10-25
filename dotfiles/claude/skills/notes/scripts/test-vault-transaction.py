#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


WRAPPER = Path(__file__).with_name("vault-transaction.py")
LOCK_NAME = "status-page-writer.lock"
LOCAL_OBSIDIAN_IGNORES = (
    ".obsidian/workspace.json",
    ".obsidian/workspace-mobile.json",
)


class Fixture:
    def __init__(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.vault = self.root / "vault"
        self.tools = self.root / "tools"
        self.vault.mkdir()
        self.tools.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "fixture writer")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        (self.vault / ".gitignore").write_text(
            "".join(f"{path}\n" for path in LOCAL_OBSIDIAN_IGNORES),
            encoding="utf-8",
        )
        hotkeys = self.vault / ".obsidian" / "hotkeys.json"
        hotkeys.parent.mkdir()
        hotkeys.write_text("{}\n", encoding="utf-8")
        (self.vault / "page.md").write_text("before\n", encoding="utf-8")
        self.git("add", ".gitignore", ".obsidian/hotkeys.json", "page.md")
        self.git("commit", "-m", "initialize fixture")

    def close(self) -> None:
        self.temporary.cleanup()

    @property
    def lock(self) -> Path:
        return self.vault / ".git" / LOCK_NAME

    def git(self, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["git", "-C", str(self.vault), *arguments],
            check=check,
            capture_output=True,
            text=True,
        )

    def script(self, name: str, body: str) -> Path:
        path = self.tools / name
        path.write_text(textwrap.dedent(body).lstrip(), encoding="utf-8")
        return path

    def run(
        self,
        writer: Path,
        validator: Path,
        *,
        paths: tuple[str, ...] = ("page.md",),
        owner: str = "fixture-owner",
        known_owners: tuple[tuple[str, str], ...] = (),
        vault: Path | None = None,
        allow_noop: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        target_vault = vault or self.vault
        command = [
            sys.executable,
            str(WRAPPER),
            "--vault",
            str(target_vault),
            "--owner",
            owner,
            "--commit-message",
            "update fixture page",
            "--write-command-json",
            json.dumps([sys.executable, str(writer)]),
            "--validator-command-json",
            json.dumps([sys.executable, str(validator)]),
        ]
        for path in paths:
            command.extend(["--path", path])
        if allow_noop:
            command.append("--allow-noop")
        for path, known_owner in known_owners:
            command.extend(["--known-owner", f"{path}={known_owner}"])
        return subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
        )

    def passing_validator(self) -> Path:
        return self.script("pass-validator.py", "raise SystemExit(0)\n")

    def page_writer(self, content: str = "after\n") -> Path:
        return self.script(
            "write-page.py",
            f"""
            from pathlib import Path

            Path("page.md").write_text({content!r}, encoding="utf-8")
            """,
        )


class WorkVaultTransactionTest(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = Fixture()

    def tearDown(self) -> None:
        self.fixture.close()

    def test_opt_in_noop_validates_without_commit_and_releases_lock(self) -> None:
        head = self.fixture.git("rev-parse", "HEAD").stdout
        writer = self.fixture.script("noop.py", "pass\n")
        marker = self.fixture.root / "validated"
        validator = self.fixture.script("mark-validation.py", f"from pathlib import Path\nPath({str(marker)!r}).write_text('validated')\n")
        result = self.fixture.run(writer, validator, allow_noop=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(marker.exists())
        self.assertIn("transaction unchanged", result.stdout)
        self.assertEqual(self.fixture.git("rev-parse", "HEAD").stdout, head)
        self.assertFalse(self.fixture.lock.exists())

    def test_default_still_rejects_noop(self) -> None:
        result = self.fixture.run(self.fixture.script("noop.py", "pass\n"), self.fixture.passing_validator())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed path scope differs", result.stderr)
        self.assertFalse(self.fixture.lock.exists())

    def test_noop_cannot_skip_failing_validator(self) -> None:
        result = self.fixture.run(self.fixture.script("noop.py", "pass\n"), self.fixture.script("reject.py", "raise SystemExit(1)\n"), allow_noop=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("transaction unchanged", result.stdout)
        self.assertFalse(self.fixture.lock.exists())

    def test_noop_option_does_not_accept_partial_write(self) -> None:
        result = self.fixture.run(self.fixture.page_writer(), self.fixture.passing_validator(), paths=("page.md", "other.md"), allow_noop=True)
        self.assert_locked_and_incomplete(result)

    def assert_locked_and_incomplete(
        self,
        result: subprocess.CompletedProcess[str],
    ) -> None:
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue(self.fixture.lock.is_dir())
        self.assertNotIn("transaction complete", result.stdout)
        self.assertIn("preserving the lock", result.stderr)

    def test_success_commits_exact_path_and_releases_lock(self) -> None:
        writer = self.fixture.script(
            "write-with-metadata-check.py",
            """
            import json
            import os
            from pathlib import Path

            lock = Path(os.environ["WORK_VAULT_LOCK_DIR"])
            metadata = json.loads((lock / "owner.json").read_text(encoding="utf-8"))
            assert metadata["token"] == os.environ["WORK_VAULT_TOKEN"]
            assert metadata["owner"] == "fixture-owner"
            assert metadata["paths"] == ["page.md"]
            Path("page.md").write_text("after\\n", encoding="utf-8")
            """,
        )
        validator = self.fixture.script(
            "validate-page.py",
            """
            from pathlib import Path

            assert Path("page.md").read_text(encoding="utf-8") == "after\\n"
            """,
        )

        result = self.fixture.run(writer, validator)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("transaction complete", result.stdout)
        self.assertIn("vault clean; writer lock absent", result.stdout)
        self.assertFalse(self.fixture.lock.exists())
        self.assertEqual(self.fixture.git("status", "--porcelain").stdout, "")
        committed = self.fixture.git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "-r",
            "HEAD",
        ).stdout.splitlines()
        self.assertEqual(committed, ["page.md"])

    def test_linked_worktree_uses_shared_git_directory_lock(self) -> None:
        linked = self.fixture.root / "linked"
        self.fixture.git("worktree", "add", "-b", "linked", str(linked))
        expected_lock = self.fixture.lock.resolve()
        writer = self.fixture.script(
            "write-linked-page.py",
            f"""
            import os
            from pathlib import Path

            assert Path(os.environ["WORK_VAULT_LOCK_DIR"]) == Path({str(expected_lock)!r})
            Path("page.md").write_text("linked after\\n", encoding="utf-8")
            """,
        )

        result = self.fixture.run(
            writer,
            self.fixture.passing_validator(),
            vault=linked,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(expected_lock.exists())
        self.assertEqual(
            subprocess.run(
                ["git", "-C", str(linked), "status", "--porcelain"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout,
            "",
        )

    def test_dirty_preflight_stops_before_lock_acquisition(self) -> None:
        (self.fixture.vault / "page.md").write_text("pre-existing\n", encoding="utf-8")

        result = self.fixture.run(
            self.fixture.page_writer(),
            self.fixture.passing_validator(),
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dirty preflight", result.stderr)
        self.assertIn("page.md (owner: unknown)", result.stderr)
        self.assertFalse(self.fixture.lock.exists())

    def test_dirty_preflight_reports_known_other_owner(self) -> None:
        (self.fixture.vault / "other.md").write_text("owned elsewhere\n", encoding="utf-8")

        result = self.fixture.run(
            self.fixture.page_writer(),
            self.fixture.passing_validator(),
            known_owners=(("other.md", "other-session"),),
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("other.md (owner: other-session)", result.stderr)
        self.assertFalse(self.fixture.lock.exists())

    def test_undeclared_staged_path_stops_and_preserves_lock(self) -> None:
        writer = self.fixture.script(
            "stage-extra.py",
            """
            import subprocess
            from pathlib import Path

            Path("page.md").write_text("after\\n", encoding="utf-8")
            Path("extra.md").write_text("extra\\n", encoding="utf-8")
            subprocess.run(["git", "add", "extra.md"], check=True)
            """,
        )

        result = self.fixture.run(writer, self.fixture.passing_validator())

        self.assert_locked_and_incomplete(result)
        self.assertIn("staged paths before the wrapper: extra.md", result.stderr)
        self.assertIn("extra.md", self.fixture.git("diff", "--cached", "--name-only").stdout)

    def test_committed_scope_drift_fails_and_preserves_lock(self) -> None:
        hook = self.fixture.vault / ".git" / "hooks" / "pre-commit"
        hook.write_text(
            "#!/bin/sh\nprintf 'extra\\n' > extra.md\ngit add extra.md\n",
            encoding="utf-8",
        )
        hook.chmod(0o755)

        result = self.fixture.run(
            self.fixture.page_writer(),
            self.fixture.passing_validator(),
        )

        self.assert_locked_and_incomplete(result)
        self.assertIn("committed scope differs from declared scope", result.stderr)
        committed = set(
            self.fixture.git(
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "-r",
                "HEAD",
            ).stdout.splitlines()
        )
        self.assertEqual(committed, {"extra.md", "page.md"})

    def test_validator_failure_keeps_writer_and_lock_responsible(self) -> None:
        validator = self.fixture.script("fail-validator.py", "raise SystemExit(7)\n")

        result = self.fixture.run(self.fixture.page_writer(), validator)

        self.assert_locked_and_incomplete(result)
        self.assertIn("validator command failed with exit 7", result.stderr)
        self.assertIn("page.md (owner: fixture-owner)", result.stderr)

    def test_diff_check_failure_keeps_writer_and_lock_responsible(self) -> None:
        result = self.fixture.run(
            self.fixture.page_writer("trailing whitespace  \n"),
            self.fixture.passing_validator(),
        )

        self.assert_locked_and_incomplete(result)
        self.assertIn("git diff --check failed", result.stderr)

    def test_dirty_postcondition_cannot_report_or_release(self) -> None:
        hook = self.fixture.vault / ".git" / "hooks" / "post-commit"
        hook.write_text(
            "#!/bin/sh\nprintf 'after hook\\n' >> page.md\n",
            encoding="utf-8",
        )
        hook.chmod(0o755)

        result = self.fixture.run(
            self.fixture.page_writer(),
            self.fixture.passing_validator(),
        )

        self.assert_locked_and_incomplete(result)
        self.assertIn("dirty postcondition", result.stderr)
        self.assertIn("page.md (owner: fixture-owner)", result.stderr)

    def test_token_mismatch_never_releases_lock(self) -> None:
        writer = self.fixture.script(
            "replace-token.py",
            """
            import json
            import os
            from pathlib import Path

            lock = Path(os.environ["WORK_VAULT_LOCK_DIR"])
            metadata_path = lock / "owner.json"
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            metadata["token"] = "another-token"
            metadata_path.write_text(json.dumps(metadata), encoding="utf-8")
            Path("page.md").write_text("after\\n", encoding="utf-8")
            """,
        )

        result = self.fixture.run(writer, self.fixture.passing_validator())

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("writer lock token mismatch", result.stderr)
        self.assertTrue(self.fixture.lock.is_dir())
        self.assertNotIn("transaction complete", result.stdout)

    def test_matching_token_exit_cleanup_releases_only_clean_no_write_failure(self) -> None:
        writer = self.fixture.script("fail-before-write.py", "raise SystemExit(9)\n")
        original_head = self.fixture.git("rev-parse", "HEAD").stdout.strip()

        result = self.fixture.run(writer, self.fixture.passing_validator())

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("write command failed with exit 9", result.stderr)
        self.assertIn("exit cleanup released the matching writer lock", result.stderr)
        self.assertFalse(self.fixture.lock.exists())
        self.assertEqual(self.fixture.git("status", "--porcelain").stdout, "")
        self.assertEqual(self.fixture.git("rev-parse", "HEAD").stdout.strip(), original_head)

    def test_self_written_modified_path_cannot_finish_or_release(self) -> None:
        validator = self.fixture.script("fail-modified.py", "raise SystemExit(2)\n")
        result = self.fixture.run(self.fixture.page_writer(), validator)
        self.assert_locked_and_incomplete(result)
        self.assertTrue(self.fixture.git("status", "--porcelain").stdout.startswith(" M"))

    def test_self_written_staged_path_cannot_finish_or_release(self) -> None:
        writer = self.fixture.script(
            "stage-page.py",
            """
            import subprocess
            from pathlib import Path

            Path("page.md").write_text("after\\n", encoding="utf-8")
            subprocess.run(["git", "add", "page.md"], check=True)
            """,
        )
        result = self.fixture.run(writer, self.fixture.passing_validator())
        self.assert_locked_and_incomplete(result)
        self.assertTrue(self.fixture.git("status", "--porcelain").stdout.startswith("M "))

    def test_self_written_deleted_path_cannot_finish_or_release(self) -> None:
        writer = self.fixture.script(
            "delete-page.py",
            """
            from pathlib import Path

            Path("page.md").unlink()
            """,
        )
        validator = self.fixture.script("fail-deleted.py", "raise SystemExit(2)\n")
        result = self.fixture.run(writer, validator)
        self.assert_locked_and_incomplete(result)
        self.assertIn(" D page.md", self.fixture.git("status", "--porcelain").stdout)

    def test_self_written_untracked_path_cannot_finish_or_release(self) -> None:
        writer = self.fixture.script(
            "write-new.py",
            """
            from pathlib import Path

            Path("new.md").write_text("new\\n", encoding="utf-8")
            """,
        )
        validator = self.fixture.script("fail-untracked.py", "raise SystemExit(2)\n")
        result = self.fixture.run(writer, validator, paths=("new.md",))
        self.assert_locked_and_incomplete(result)
        self.assertIn("?? new.md", self.fixture.git("status", "--porcelain").stdout)

    def test_another_session_cannot_adopt_first_writers_dirty_path(self) -> None:
        first_validator = self.fixture.script("first-fails.py", "raise SystemExit(3)\n")
        first = self.fixture.run(
            self.fixture.page_writer("first owner\n"),
            first_validator,
            owner="first-owner",
        )
        self.assert_locked_and_incomplete(first)
        original_metadata = (self.fixture.lock / "owner.json").read_text(encoding="utf-8")

        second = self.fixture.run(
            self.fixture.page_writer("second owner\n"),
            self.fixture.passing_validator(),
            owner="second-owner",
        )

        self.assertNotEqual(second.returncode, 0)
        self.assertIn("dirty preflight", second.stderr)
        self.assertIn("page.md (owner: first-owner)", second.stderr)
        self.assertEqual(
            (self.fixture.lock / "owner.json").read_text(encoding="utf-8"),
            original_metadata,
        )
        self.assertEqual(
            (self.fixture.vault / "page.md").read_text(encoding="utf-8"),
            "first owner\n",
        )

    def test_exact_local_obsidian_ignore_set_stays_clean(self) -> None:
        for relative_path in LOCAL_OBSIDIAN_IGNORES:
            path = self.fixture.vault / relative_path
            path.parent.mkdir(exist_ok=True)
            path.write_text("local state\n", encoding="utf-8")

        result = self.fixture.run(
            self.fixture.page_writer(),
            self.fixture.passing_validator(),
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        ignored = self.fixture.git("check-ignore", *LOCAL_OBSIDIAN_IGNORES).stdout.splitlines()
        self.assertEqual(tuple(ignored), LOCAL_OBSIDIAN_IGNORES)
        self.fixture.git("ls-files", "--error-unmatch", ".obsidian/hotkeys.json")
        self.assertEqual(self.fixture.git("status", "--porcelain").stdout, "")

    def test_tracked_hotkeys_uses_its_own_focused_transaction(self) -> None:
        writer = self.fixture.script(
            "write-hotkeys.py",
            """
            from pathlib import Path

            Path(".obsidian/hotkeys.json").write_text('{"command": true}\\n', encoding="utf-8")
            """,
        )
        validator = self.fixture.script(
            "validate-hotkeys.py",
            """
            import json
            from pathlib import Path

            assert json.loads(Path(".obsidian/hotkeys.json").read_text(encoding="utf-8")) == {"command": True}
            """,
        )

        result = self.fixture.run(
            writer,
            validator,
            paths=(".obsidian/hotkeys.json",),
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.fixture.lock.exists())
        committed = self.fixture.git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "-r",
            "HEAD",
        ).stdout.splitlines()
        self.assertEqual(committed, [".obsidian/hotkeys.json"])

    def test_unknown_obsidian_file_blocks_preflight(self) -> None:
        unknown = self.fixture.vault / ".obsidian" / "new-plugin-state.json"
        unknown.parent.mkdir(exist_ok=True)
        unknown.write_text("{}\n", encoding="utf-8")

        result = self.fixture.run(
            self.fixture.page_writer(),
            self.fixture.passing_validator(),
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(".obsidian/new-plugin-state.json", result.stderr)
        self.assertFalse(self.fixture.lock.exists())

    def test_ordinary_markdown_formatting_blocks_unrelated_transaction(self) -> None:
        (self.fixture.vault / "page.md").write_text("formatted elsewhere\n", encoding="utf-8")

        result = self.fixture.run(
            self.fixture.page_writer(),
            self.fixture.passing_validator(),
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("page.md", result.stderr)
        self.assertFalse(self.fixture.lock.exists())

    def test_declared_paths_reject_unresolved_globs(self) -> None:
        command = [
            sys.executable,
            str(WRAPPER),
            "--vault",
            str(self.fixture.vault),
            "--owner",
            "fixture-owner",
            "--path",
            "pages/*.md",
            "--commit-message",
            "invalid",
            "--write-command-json",
            json.dumps([sys.executable, str(self.fixture.page_writer())]),
            "--validator-command-json",
            json.dumps([sys.executable, str(self.fixture.passing_validator())]),
        ]

        result = subprocess.run(command, check=False, capture_output=True, text=True)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot contain glob syntax", result.stderr)
        self.assertFalse(self.fixture.lock.exists())


if __name__ == "__main__":
    unittest.main()
