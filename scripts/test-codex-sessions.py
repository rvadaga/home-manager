#!/usr/bin/env python3

import json
import os
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
import unittest


script_path = pathlib.Path(__file__).with_name("codex-sessions.py")


class CodexSessionsTest(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.codex_home = pathlib.Path(self.temporary_directory.name)
        (self.codex_home / "sqlite").mkdir()
        self.state_database = self.codex_home / "state_7.sqlite"
        self.catalog_database = self.codex_home / "sqlite" / "codex-dev.db"
        self.global_state = self.codex_home / ".codex-global-state.json"
        self.create_state_database()
        self.create_catalog_database()
        self.create_global_state()

    def tearDown(self):
        self.temporary_directory.cleanup()

    def create_state_database(self):
        rows = [
            (
                "00000000-0000-7000-8000-000000000001",
                "/tmp/example-project",
                "vscode",
                "user",
                0,
                1000,
                3000,
                "state title",
            ),
            (
                "00000000-0000-7000-8000-000000000002",
                "/tmp/projectless-workspace",
                "vscode",
                "realtime_voice",
                0,
                2000,
                2000,
                "projectless state title",
            ),
            (
                "00000000-0000-7000-8000-000000000003",
                "/tmp/legacy-project",
                "cli",
                None,
                0,
                3000,
                1000,
                "legacy title",
            ),
            (
                "00000000-0000-7000-8000-000000000004",
                "/tmp/example-project",
                "vscode",
                "subagent",
                0,
                4000,
                6000,
                "subagent title",
            ),
            (
                "00000000-0000-7000-8000-000000000005",
                "/tmp/example-project",
                "vscode",
                "user",
                1,
                5000,
                5000,
                "archived title",
            ),
            (
                "00000000-0000-7000-8000-000000000006",
                "/tmp/example-project",
                "exec",
                "user",
                0,
                6000,
                7000,
                "exec title",
            ),
        ]
        with sqlite3.connect(self.state_database) as connection:
            connection.execute(
                """
                create table threads (
                  id text primary key,
                  cwd text not null,
                  source text not null,
                  thread_source text,
                  archived integer not null,
                  created_at integer not null,
                  updated_at integer not null,
                  created_at_ms integer,
                  updated_at_ms integer,
                  name text,
                  title text not null,
                  preview text not null
                )
                """
            )
            connection.executemany(
                """
                insert into threads (
                  id, cwd, source, thread_source, archived,
                  created_at_ms, updated_at_ms, title,
                  created_at, updated_at, preview
                ) values (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, '')
                """,
                rows,
            )

    def create_catalog_database(self):
        with sqlite3.connect(self.catalog_database) as connection:
            connection.execute(
                """
                create table local_thread_catalog (
                  thread_id text not null,
                  display_title text not null,
                  observation_sequence integer not null,
                  missing_candidate integer not null
                )
                """
            )
            connection.executemany(
                "insert into local_thread_catalog values (?, ?, ?, 0)",
                [
                    (
                        "00000000-0000-7000-8000-000000000001",
                        "catalog title\nwith \x1b[31mspacing",
                        2,
                    ),
                    (
                        "00000000-0000-7000-8000-000000000001",
                        "stale catalog title",
                        1,
                    ),
                ],
            )

    def create_global_state(self):
        state = {
            "thread-project-assignments": {
                "00000000-0000-7000-8000-000000000001": {
                    "projectId": "example-project-id",
                    "projectKind": "local",
                }
            },
            "local-projects": {
                "example-project-id": {
                    "id": "example-project-id",
                    "name": "example project",
                }
            },
            "projectless-thread-ids": [
                "00000000-0000-7000-8000-000000000002"
            ],
        }
        self.global_state.write_text(json.dumps(state), encoding="utf-8")

    def run_command(self, *arguments):
        environment = os.environ.copy()
        environment["CODEX_HOME"] = str(self.codex_home)
        environment["TZ"] = "Etc/GMT+6"
        return subprocess.run(
            [sys.executable, str(script_path), *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=environment,
        )

    def test_lists_visible_tasks_with_canonical_titles_and_projects(self):
        result = self.run_command("4")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            "\n".join(
                [
                    "project  task id  title",
                    "example-project  00000000-0000-7000-8000-000000000005  archived title",
                    "  created 1969-12-31T18:00:05.000-06:00  last updated 1969-12-31T18:00:05.000-06:00",
                    "example project  00000000-0000-7000-8000-000000000001  catalog title with [31mspacing",
                    "  created 1969-12-31T18:00:01.000-06:00  last updated 1969-12-31T18:00:03.000-06:00",
                    "(projectless)  00000000-0000-7000-8000-000000000002  projectless state title",
                    "  created 1969-12-31T18:00:02.000-06:00  last updated 1969-12-31T18:00:02.000-06:00",
                    "legacy-project  00000000-0000-7000-8000-000000000003  legacy title",
                    "  created 1969-12-31T18:00:03.000-06:00  last updated 1969-12-31T18:00:01.000-06:00",
                    "",
                ]
            ),
            result.stdout,
        )
        self.assertNotIn("\x1b", result.stdout)

    def test_limit_applies_after_non_session_tasks_are_filtered(self):
        result = self.run_command("1")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("00000000-0000-7000-8000-000000000005", result.stdout)
        self.assertNotIn("00000000-0000-7000-8000-000000000001", result.stdout)
        self.assertNotIn("00000000-0000-7000-8000-000000000002", result.stdout)
        self.assertNotIn("subagent title", result.stdout)
        self.assertNotIn("exec title", result.stdout)

    def test_rejects_non_positive_count(self):
        result = self.run_command("0")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("count must be a positive integer", result.stderr)

    def test_missing_state_database_has_a_plain_error(self):
        self.state_database.unlink()
        result = self.run_command("1")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("codex state database not found", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
