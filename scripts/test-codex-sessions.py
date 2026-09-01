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

    def run_command(
        self,
        *arguments,
        columns=200,
        local_timezone="Etc/GMT+6",
    ):
        environment = os.environ.copy()
        environment["CODEX_HOME"] = str(self.codex_home)
        environment["COLUMNS"] = str(columns)
        environment["TZ"] = local_timezone
        return subprocess.run(
            [sys.executable, str(script_path), *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=environment,
        )

    @staticmethod
    def logical_rows(output):
        groups = []
        current = []
        for line in output.splitlines():
            if line.startswith("+"):
                if current:
                    groups.append(current)
                    current = []
            elif line.startswith("|"):
                current.append(line)
        if current:
            groups.append(current)
        return groups

    @staticmethod
    def reconstructed_cells(lines):
        cells = [[] for _ in range(5)]
        for line in lines:
            parts = line[1:-1].split("|")
            if len(parts) != 5:
                raise AssertionError(f"expected five cells in {line!r}")
            for index, part in enumerate(parts):
                cells[index].append(part.strip())
        return ["".join("".join(cell).split()) for cell in cells]

    def test_lists_visible_tasks_with_canonical_titles_and_projects(self):
        result = self.run_command("4")
        self.assertEqual(0, result.returncode, result.stderr)
        rows = self.logical_rows(result.stdout)
        self.assertEqual(
            ["project", "taskid", "title", "created", "lastupdated"],
            self.reconstructed_cells(rows[0]),
        )
        self.assertEqual(
            [
                [
                    "example-project",
                    "00000000-0000-7000-8000-000000000005",
                    "archivedtitle",
                    "WedDec31196918:00",
                    "WedDec31196918:00",
                ],
                [
                    "exampleproject",
                    "00000000-0000-7000-8000-000000000001",
                    "catalogtitlewith[31mspacing",
                    "WedDec31196918:00",
                    "WedDec31196918:00",
                ],
                [
                    "(projectless)",
                    "00000000-0000-7000-8000-000000000002",
                    "projectlessstatetitle",
                    "WedDec31196918:00",
                    "WedDec31196918:00",
                ],
                [
                    "legacy-project",
                    "00000000-0000-7000-8000-000000000003",
                    "legacytitle",
                    "WedDec31196918:00",
                    "WedDec31196918:00",
                ],
            ],
            [self.reconstructed_cells(row) for row in rows[1:]],
        )
        self.assertNotIn("\x1b", result.stdout)

    def test_wraps_every_cell_without_truncating_content(self):
        result = self.run_command("1", columns=60)
        self.assertEqual(0, result.returncode, result.stderr)

        lines = result.stdout.splitlines()
        self.assertTrue(lines)
        self.assertTrue(all(len(line) == len(lines[0]) for line in lines))
        self.assertLessEqual(len(lines[0]), 60)

        borders = [line for line in lines if line.startswith("+")]
        content = [line for line in lines if line.startswith("|")]
        self.assertTrue(borders)
        self.assertTrue(content)
        separator_positions = [
            index for index, character in enumerate(borders[0]) if character == "+"
        ]
        for line in borders:
            self.assertEqual(
                separator_positions,
                [index for index, character in enumerate(line) if character == "+"],
            )
        for line in content:
            self.assertEqual(
                separator_positions,
                [index for index, character in enumerate(line) if character == "|"],
            )

        task_lines = self.logical_rows(result.stdout)[1]
        self.assertGreater(len(task_lines), 1)
        fragments = [line[1:-1].split("|") for line in task_lines]
        self.assertTrue(
            all(
                sum(bool(line[index].strip()) for line in fragments) > 1
                for index in range(5)
            )
        )
        self.assertEqual(
            [
                "example-project",
                "00000000-0000-7000-8000-000000000005",
                "archivedtitle",
                "WedDec31196918:00",
                "WedDec31196918:00",
            ],
            self.reconstructed_cells(task_lines),
        )

    def test_timezone_override_supports_short_and_long_options(self):
        for arguments in (
            ("-z", "America/Los_Angeles", "1"),
            ("1", "--timezone=America/Los_Angeles"),
        ):
            with self.subTest(arguments=arguments):
                result = self.run_command(*arguments)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual(2, result.stdout.count("Wed Dec 31 1969 16:00"))
                self.assertNotIn("Wed Dec 31 1969 18:00", result.stdout)

    def test_rejects_unknown_timezone_without_a_traceback(self):
        result = self.run_command("--timezone", "not/a-zone", "1")
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("", result.stdout)
        self.assertIn("unknown timezone: not/a-zone", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

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
