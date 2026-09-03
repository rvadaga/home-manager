#!/usr/bin/env python3

import argparse
import datetime
import json
import math
import os
import pathlib

from session_table import (
    local_timestamp,
    normalized_text,
    positive_integer,
    rendered_terminal_table,
    timezone,
)


def environment_path(name, default):
    value = os.environ.get(name)
    if value:
        return pathlib.Path(value).expanduser()
    return pathlib.Path(default).expanduser()


def numeric_milliseconds(value):
    if isinstance(value, bool):
        return None
    try:
        milliseconds = float(value)
    except (TypeError, ValueError):
        return None
    if (
        not math.isfinite(milliseconds)
        or milliseconds < 0
        or milliseconds > 253_402_300_799_999
    ):
        return None
    return int(milliseconds)


def iso_milliseconds(value):
    if not isinstance(value, str) or not value.strip():
        return None
    timestamp = value.strip()
    if timestamp.endswith("Z"):
        timestamp = f"{timestamp[:-1]}+00:00"
    try:
        instant = datetime.datetime.fromisoformat(timestamp)
    except ValueError:
        return None
    if instant.tzinfo is None:
        instant = instant.replace(tzinfo=datetime.timezone.utc)
    try:
        return int(instant.timestamp() * 1000)
    except (OverflowError, OSError):
        return None


def content_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, dict):
        text = content.get("text")
        return text if isinstance(text, str) else ""
    if not isinstance(content, list):
        return ""

    parts = []
    for item in content:
        text = content_text(item)
        if text:
            parts.append(text)
    return " ".join(parts)


def nonempty_string(value):
    if isinstance(value, str) and value.strip():
        return value
    return ""


def desktop_sessions(metadata_directory):
    if not metadata_directory.is_dir():
        return {}

    sessions = {}
    for path in sorted(metadata_directory.rglob("local_*.json")):
        try:
            with path.open(encoding="utf-8") as metadata_file:
                metadata = json.load(metadata_file)
        except (json.JSONDecodeError, OSError):
            continue
        if not isinstance(metadata, dict):
            continue

        session_id = metadata.get("cliSessionId")
        if not isinstance(session_id, str) or not session_id.strip():
            continue
        session_id = session_id.strip()
        created_at_ms = numeric_milliseconds(metadata.get("createdAt"))
        updated_at_ms = numeric_milliseconds(metadata.get("lastActivityAt"))
        rank = (
            updated_at_ms if updated_at_ms is not None else -1,
            created_at_ms if created_at_ms is not None else -1,
            str(path),
        )
        candidate = {
            "title": nonempty_string(metadata.get("title")),
            "origin_cwd": metadata.get("originCwd"),
            "cwd": metadata.get("cwd"),
            "created_at_ms": created_at_ms,
            "updated_at_ms": updated_at_ms,
            "rank": rank,
        }
        current = sessions.get(session_id)
        if current is None or rank > current["rank"]:
            sessions[session_id] = candidate
    return sessions


def transcript_paths(projects_directory):
    if not projects_directory.is_dir():
        raise FileNotFoundError(
            f"claude projects directory not found: {projects_directory}"
        )
    return sorted(
        path
        for path in projects_directory.rglob("*.jsonl")
        if not path.name.startswith("agent-")
    )


def transcript_session(path):
    timestamps = []
    cwd = ""
    custom_title = ""
    first_user_text = ""
    first_queue_text = ""

    with path.open(encoding="utf-8") as transcript_file:
        for line in transcript_file:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(record, dict):
                continue

            timestamp = iso_milliseconds(record.get("timestamp"))
            if timestamp is not None:
                timestamps.append(timestamp)

            record_cwd = record.get("cwd")
            if not cwd and isinstance(record_cwd, str) and record_cwd.strip():
                cwd = record_cwd.strip()

            record_type = record.get("type")
            if record_type == "custom-title":
                title = record.get("customTitle")
                if isinstance(title, str) and title.strip():
                    custom_title = title
            elif (
                record_type == "user"
                and not record.get("isSidechain", False)
                and not first_user_text
            ):
                message = record.get("message")
                content = message.get("content") if isinstance(message, dict) else None
                first_user_text = content_text(content or record.get("content"))
            elif record_type == "queue-operation" and not first_queue_text:
                first_queue_text = content_text(record.get("content"))

    file_updated_ms = path.stat().st_mtime_ns // 1_000_000
    return {
        "id": path.stem,
        "cwd": cwd,
        "fallback_title": custom_title
        or first_user_text
        or first_queue_text
        or "(untitled)",
        "created_at_ms": min(timestamps) if timestamps else file_updated_ms,
        "updated_at_ms": max(timestamps) if timestamps else file_updated_ms,
    }


def path_name(value):
    if not isinstance(value, str) or not value.strip():
        return ""
    path = pathlib.Path(value.strip())
    parts = path.parts
    for index, part in enumerate(parts[:-1]):
        if part == ".claude" and parts[index + 1] == "worktrees" and index:
            return parts[index - 1]
    return path.name


def sessions(projects_directory, metadata_directory, count):
    metadata = desktop_sessions(metadata_directory)
    results = []
    for path in transcript_paths(projects_directory):
        try:
            transcript = transcript_session(path)
        except OSError:
            continue
        desktop = metadata.get(transcript["id"], {})

        project = (
            path_name(desktop.get("origin_cwd"))
            or path_name(transcript["cwd"])
            or path_name(desktop.get("cwd"))
            or "(unknown)"
        )
        title = desktop.get("title") or transcript["fallback_title"]
        created_at_ms = desktop.get("created_at_ms")
        if created_at_ms is None:
            created_at_ms = transcript["created_at_ms"]
        updated_at_ms = desktop.get("updated_at_ms")
        if updated_at_ms is None:
            updated_at_ms = transcript["updated_at_ms"]
        else:
            updated_at_ms = max(updated_at_ms, transcript["updated_at_ms"])

        results.append(
            {
                "id": transcript["id"],
                "project": project,
                "title": title,
                "created_at_ms": created_at_ms,
                "updated_at_ms": updated_at_ms,
            }
        )

    results.sort(key=lambda session: (session["updated_at_ms"], session["id"]), reverse=True)
    return results[:count]


def render(session_records, selected_timezone):
    rows = []
    for session in session_records:
        rows.append(
            (
                normalized_text(session["project"], "(unknown)"),
                normalized_text(session["id"], "(unknown)"),
                normalized_text(session["title"], "(untitled)"),
                local_timestamp(session["created_at_ms"], selected_timezone),
                local_timestamp(session["updated_at_ms"], selected_timezone),
            )
        )
    return rendered_terminal_table(rows, id_header="session id")


def main():
    parser = argparse.ArgumentParser(
        prog="claude-sessions",
        description="list recent user-visible claude sessions",
    )
    parser.add_argument("count", nargs="?", type=positive_integer, default=10)
    parser.add_argument(
        "-z",
        "--timezone",
        type=timezone,
        help="show times in this iana timezone (default: system local time)",
    )
    arguments = parser.parse_args()

    projects_directory = environment_path(
        "CLAUDE_SESSIONS_PROJECTS_DIR",
        pathlib.Path.home() / ".claude" / "projects",
    )
    metadata_directory = environment_path(
        "CLAUDE_SESSIONS_METADATA_DIR",
        pathlib.Path.home()
        / "Library"
        / "Application Support"
        / "Claude"
        / "claude-code-sessions",
    )

    try:
        session_records = sessions(
            projects_directory,
            metadata_directory,
            arguments.count,
        )
        output = render(session_records, arguments.timezone)
    except (OSError, OverflowError, ValueError) as error:
        parser.exit(1, f"claude-sessions: {error}\n")
    print(output)


if __name__ == "__main__":
    main()
