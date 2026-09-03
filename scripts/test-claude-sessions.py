#!/usr/bin/env python3

import datetime
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


script_path = pathlib.Path(__file__).with_name("claude-sessions.py")


def epoch_milliseconds(timestamp):
    instant = datetime.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    return int(instant.timestamp() * 1000)


class ClaudeSessionsTest(unittest.TestCase):
    first_id = "11111111-1111-4111-8111-111111111111"
    second_id = "22222222-2222-4222-8222-222222222222"
    third_id = "33333333-3333-4333-8333-333333333333"
    fifth_id = "55555555-5555-4555-8555-555555555555"

    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary_directory.name)
        self.projects_directory = self.root / "projects"
        self.metadata_directory = self.root / "metadata"
        self.projects_directory.mkdir()
        self.metadata_directory.mkdir()
        self.create_transcripts()
        self.create_metadata()

    def tearDown(self):
        self.temporary_directory.cleanup()

    def write_transcript(self, project, name, records, malformed_line=False):
        path = self.projects_directory / project / f"{name}.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        lines = [json.dumps(record) for record in records]
        if malformed_line:
            lines.append('{"type":"user"')
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    def write_metadata(self, relative_path, metadata):
        path = self.metadata_directory / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(metadata), encoding="utf-8")

    def create_transcripts(self):
        self.write_transcript(
            "example-project",
            self.first_id,
            [
                {
                    "type": "queue-operation",
                    "sessionId": self.first_id,
                    "timestamp": "2026-08-30T10:00:00Z",
                    "content": "transcript fallback title",
                },
                {
                    "type": "user",
                    "sessionId": self.first_id,
                    "timestamp": "2026-08-31T05:00:00Z",
                    "cwd": "/tmp/example project/.claude/worktrees/child",
                    "message": {"content": "transcript user title"},
                },
            ],
        )
        self.write_transcript(
            "legacy-project",
            self.second_id,
            [
                {
                    "type": "queue-operation",
                    "sessionId": self.second_id,
                    "timestamp": "2026-08-30T23:00:00Z",
                    "content": "queued fallback",
                },
                {
                    "type": "attachment",
                    "sessionId": self.second_id,
                    "timestamp": "2026-08-30T22:30:00Z",
                    "cwd": "/tmp/legacy-project",
                },
                {
                    "type": "user",
                    "sessionId": self.second_id,
                    "timestamp": "2026-08-31T03:00:00Z",
                    "cwd": "/tmp/legacy-project",
                    "message": {
                        "content": [
                            {"type": "text", "text": "first prompt\nwith \u001b[32mspacing"}
                        ]
                    },
                },
            ],
        )
        self.write_transcript(
            "archive-project",
            self.third_id,
            [
                {
                    "type": "user",
                    "sessionId": self.third_id,
                    "timestamp": "2026-08-31T00:30:00Z",
                    "cwd": "/tmp/archive project",
                    "message": {"content": "archive transcript title"},
                }
            ],
        )
        self.write_transcript(
            "unknown-project",
            self.fifth_id,
            [{"type": "queue-operation", "sessionId": self.fifth_id, "content": None}],
            malformed_line=True,
        )
        fallback_time = epoch_milliseconds("2026-08-30T20:00:00Z")
        fallback_path = (
            self.projects_directory / "unknown-project" / f"{self.fifth_id}.jsonl"
        )
        os.utime(
            fallback_path,
            ns=(fallback_time * 1_000_000, fallback_time * 1_000_000),
        )

        self.write_transcript(
            "example-project/nested-agent",
            "agent-44444444-4444-4444-8444-444444444444",
            [
                {
                    "type": "user",
                    "timestamp": "2026-09-01T00:00:00Z",
                    "cwd": "/tmp/example project",
                    "message": {"content": "agent title"},
                }
            ],
        )

    def create_metadata(self):
        self.write_metadata(
            "older/local_old.json",
            {
                "sessionId": "local_old",
                "cliSessionId": self.first_id,
                "title": "stale title",
                "originCwd": "/tmp/stale-project",
                "createdAt": epoch_milliseconds("2026-08-31T00:00:00Z"),
                "lastActivityAt": epoch_milliseconds("2026-08-31T00:30:00Z"),
            },
        )
        self.write_metadata(
            "newer/local_new.json",
            {
                "sessionId": "local_new",
                "cliSessionId": self.first_id,
                "title": "catalog title\nwith \u001b[31mspacing",
                "originCwd": "/tmp/example project",
                "cwd": "/tmp/example project/.claude/worktrees/child",
                "createdAt": epoch_milliseconds("2026-08-31T01:19:00Z"),
                "lastActivityAt": epoch_milliseconds("2026-08-31T02:20:00Z"),
                "isArchived": False,
            },
        )
        self.write_metadata(
            "local_archived.json",
            {
                "sessionId": "local_archived",
                "cliSessionId": self.third_id,
                "title": "   ",
                "createdAt": epoch_milliseconds("2026-08-31T00:30:00Z"),
                "lastActivityAt": epoch_milliseconds("2026-08-31T01:00:00Z"),
                "isArchived": True,
            },
        )
        self.write_metadata(
            "local_oversized.json",
            {
                "sessionId": "local_oversized",
                "cliSessionId": self.fifth_id,
                "title": "   ",
                "createdAt": 10**30,
                "lastActivityAt": 10**30,
            },
        )
        self.write_metadata(
            "local_stale.json",
            {
                "sessionId": "local_stale",
                "cliSessionId": "99999999-9999-4999-8999-999999999999",
                "title": "metadata without transcript",
                "createdAt": epoch_milliseconds("2026-09-01T00:00:00Z"),
                "lastActivityAt": epoch_milliseconds("2026-09-01T00:00:00Z"),
            },
        )
        malformed = self.metadata_directory / "malformed" / "local_broken.json"
        malformed.parent.mkdir(parents=True, exist_ok=True)
        malformed.write_text('{"cliSessionId":', encoding="utf-8")

    def run_command(self, *arguments, columns=200, local_timezone="America/New_York"):
        environment = os.environ.copy()
        environment["CLAUDE_SESSIONS_PROJECTS_DIR"] = str(self.projects_directory)
        environment["CLAUDE_SESSIONS_METADATA_DIR"] = str(self.metadata_directory)
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

    def test_lists_sessions_with_canonical_metadata_and_transcript_fallbacks(self):
        result = self.run_command("4")
        self.assertEqual(0, result.returncode, result.stderr)
        rows = self.logical_rows(result.stdout)
        self.assertEqual(
            ["project", "sessionid", "title", "created", "lastupdated"],
            self.reconstructed_cells(rows[0]),
        )
        self.assertEqual(
            [
                [
                    "exampleproject",
                    self.first_id,
                    "catalogtitlewith[31mspacing",
                    "SunAug30202621:19",
                    "MonAug31202601:00",
                ],
                [
                    "legacy-project",
                    self.second_id,
                    "firstpromptwith[32mspacing",
                    "SunAug30202618:30",
                    "SunAug30202623:00",
                ],
                [
                    "archiveproject",
                    self.third_id,
                    "archivetranscripttitle",
                    "SunAug30202620:30",
                    "SunAug30202621:00",
                ],
                [
                    "(unknown)",
                    self.fifth_id,
                    "(untitled)",
                    "SunAug30202616:00",
                    "SunAug30202616:00",
                ],
            ],
            [self.reconstructed_cells(row) for row in rows[1:]],
        )
        self.assertNotIn("\x1b", result.stdout)
        self.assertNotIn("metadata without transcript", result.stdout)

    def test_wraps_every_cell_without_truncating_content(self):
        result = self.run_command("1", columns=60)
        self.assertEqual(0, result.returncode, result.stderr)

        lines = result.stdout.splitlines()
        self.assertTrue(lines)
        self.assertTrue(all(len(line) == len(lines[0]) for line in lines))
        self.assertLessEqual(len(lines[0]), 60)
        borders = [line for line in lines if line.startswith("+")]
        content = [line for line in lines if line.startswith("|")]
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

        session_lines = self.logical_rows(result.stdout)[1]
        self.assertGreater(len(session_lines), 1)
        fragments = [line[1:-1].split("|") for line in session_lines]
        self.assertTrue(
            all(
                sum(bool(line[index].strip()) for line in fragments) > 1
                for index in range(5)
            )
        )
        self.assertEqual(
            [
                "exampleproject",
                self.first_id,
                "catalogtitlewith[31mspacing",
                "SunAug30202621:19",
                "MonAug31202601:00",
            ],
            self.reconstructed_cells(session_lines),
        )

    def test_timezone_override_supports_short_and_long_options(self):
        for arguments in (
            ("-z", "America/Los_Angeles", "2"),
            ("2", "--timezone", "America/Los_Angeles"),
            ("2", "--timezone=America/Los_Angeles"),
        ):
            with self.subTest(arguments=arguments):
                result = self.run_command(*arguments)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn("Sun Aug 30 2026 18:19", result.stdout)
                self.assertNotIn("Sun Aug 30 2026 21:19", result.stdout)

    def test_filters_nested_agents_before_applying_the_limit(self):
        nested_session_id = "66666666-6666-4666-8666-666666666666"
        self.write_transcript(
            "example-project/nested-session",
            nested_session_id,
            [
                {
                    "type": "user",
                    "sessionId": nested_session_id,
                    "timestamp": "2026-09-02T00:00:00Z",
                    "cwd": "/tmp/nested-project",
                    "message": {"content": "nested session title"},
                }
            ],
        )
        self.write_transcript(
            "example-project",
            "agent-77777777-7777-4777-8777-777777777777",
            [
                {
                    "type": "user",
                    "timestamp": "2026-09-03T00:00:00Z",
                    "cwd": "/tmp/example project",
                    "message": {"content": "top-level agent title"},
                }
            ],
        )
        result = self.run_command("1")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn(nested_session_id, result.stdout)
        self.assertIn("nested session title", result.stdout)
        self.assertNotIn("agent-44444444", result.stdout)
        self.assertNotIn("agent title", result.stdout)
        self.assertNotIn("agent-77777777", result.stdout)
        self.assertNotIn("top-level agent title", result.stdout)

    def test_skips_a_transcript_that_disappears_during_the_scan(self):
        broken_path = self.projects_directory / "example-project" / "broken.jsonl"
        broken_path.symlink_to(self.root / "already-removed.jsonl")
        self.assertIn(broken_path, self.projects_directory.rglob("*.jsonl"))

        result = self.run_command("4")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn(self.first_id, result.stdout)
        self.assertNotIn("Traceback", result.stderr)

    def test_default_count_remains_ten(self):
        for number in range(7):
            session_id = f"90000000-0000-4000-8000-{number:012d}"
            self.write_transcript(
                f"extra-project-{number}",
                session_id,
                [
                    {
                        "type": "user",
                        "sessionId": session_id,
                        "timestamp": f"2026-08-29T{number:02d}:00:00Z",
                        "cwd": f"/tmp/extra-project-{number}",
                        "message": {"content": f"extra title {number}"},
                    }
                ],
            )
        result = self.run_command()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(10, len(self.logical_rows(result.stdout)) - 1)

    def test_missing_desktop_metadata_uses_transcript_values(self):
        missing_metadata = self.root / "missing-metadata"
        self.metadata_directory = missing_metadata
        result = self.run_command("4")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("transcript user title", result.stdout)
        self.assertIn("example project", result.stdout)

    def test_rejects_unknown_timezone_without_a_traceback(self):
        result = self.run_command("--timezone", "not/a-zone", "1")
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("", result.stdout)
        self.assertIn("unknown timezone: not/a-zone", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_rejects_non_positive_count(self):
        result = self.run_command("0")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("count must be a positive integer", result.stderr)

    def test_missing_projects_directory_has_a_plain_error(self):
        missing_projects = self.root / "missing-projects"
        self.projects_directory = missing_projects
        result = self.run_command("1")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("claude projects directory not found", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
