#!/usr/bin/env python3

import argparse
import datetime
import json
import os
import pathlib
import re
import shutil
import sqlite3
import sys
import textwrap
import zoneinfo


COLUMNS = (
    ("project", 24),
    ("task id", 36),
    ("title", 60),
    ("created", 21),
    ("last updated", 21),
)

COLUMN_GROWTH_BANDS = (
    (7, 8, 5, 7, 12),
    (10, 12, 16, 11, 12),
    (10, 12, 16, 21, 21),
    (16, 24, 28, 21, 21),
    (24, 36, 60, 21, 21),
)

WEEKDAYS = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
MONTHS = (
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
)


def positive_integer(value):
    try:
        count = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("count must be a positive integer") from error

    if count < 1:
        raise argparse.ArgumentTypeError("count must be a positive integer")
    return count


def timezone(value):
    try:
        return zoneinfo.ZoneInfo(value)
    except zoneinfo.ZoneInfoNotFoundError as error:
        raise argparse.ArgumentTypeError(f"unknown timezone: {value}") from error


def environment_path(name, default):
    value = os.environ.get(name)
    if value:
        return pathlib.Path(value).expanduser()
    return pathlib.Path(default).expanduser()


def state_database_path(codex_home):
    override = os.environ.get("CODEX_SESSIONS_STATE_DB")
    if override:
        path = pathlib.Path(override).expanduser()
        if not path.is_file():
            raise FileNotFoundError(f"codex state database not found: {path}")
        return path

    candidates = []
    for path in codex_home.glob("state_*.sqlite"):
        match = re.fullmatch(r"state_(\d+)\.sqlite", path.name)
        if match:
            candidates.append((int(match.group(1)), path))

    if not candidates:
        raise FileNotFoundError(f"codex state database not found under {codex_home}")
    return max(candidates, key=lambda candidate: candidate[0])[1]


def read_only_connection(path):
    connection = sqlite3.connect(
        f"{path.resolve().as_uri()}?mode=ro",
        uri=True,
        timeout=3,
    )
    connection.row_factory = sqlite3.Row
    connection.execute("pragma query_only = on")
    connection.execute("pragma busy_timeout = 3000")
    return connection


def task_rows(state_database, count):
    query = """
        select
          id,
          cwd,
          coalesce(created_at_ms, created_at * 1000) as created_at_ms,
          coalesce(updated_at_ms, updated_at * 1000) as updated_at_ms,
          coalesce(
            nullif(name, ''),
            nullif(title, ''),
            nullif(preview, ''),
            '(untitled)'
          ) as fallback_title
        from threads
        where source in ('cli', 'vscode')
          and lower(coalesce(thread_source, '')) not like 'subagent%'
        order by coalesce(updated_at_ms, updated_at * 1000) desc, id desc
        limit ?
    """
    with read_only_connection(state_database) as connection:
        return [dict(row) for row in connection.execute(query, (count,))]


def desktop_titles(catalog_database):
    if not catalog_database.is_file():
        return {}

    query = """
        select thread_id, display_title
        from local_thread_catalog
        where missing_candidate = 0
          and display_title != ''
        order by observation_sequence desc
    """
    titles = {}
    with read_only_connection(catalog_database) as connection:
        for row in connection.execute(query):
            titles.setdefault(row["thread_id"], row["display_title"])
    return titles


def project_state(global_state_path):
    if not global_state_path.is_file():
        return {}, {}, set()

    with global_state_path.open(encoding="utf-8") as state_file:
        state = json.load(state_file)

    assignments = state.get("thread-project-assignments", {})
    projects = state.get("local-projects", {})
    projectless = set(state.get("projectless-thread-ids", []))
    return assignments, projects, projectless


def project_name(task, assignments, projects, projectless):
    task_id = task["id"]
    assignment = assignments.get(task_id, {})
    project_id = assignment.get("projectId") if isinstance(assignment, dict) else None
    project = projects.get(project_id, {}) if project_id else {}
    name = project.get("name") if isinstance(project, dict) else None
    if name:
        return name

    # projectless is explicit desktop state. only older unclassified tasks use
    # the workspace directory name as a fallback.
    if task_id in projectless:
        return "(projectless)"

    workspace_name = pathlib.Path(task["cwd"]).name
    return workspace_name or "(unknown)"


def normalized_text(value, fallback):
    printable = "".join(
        character if character.isprintable() else " " for character in str(value)
    )
    text = " ".join(printable.split())
    return text or fallback


def local_timestamp(milliseconds, selected_timezone):
    instant = datetime.datetime.fromtimestamp(
        int(milliseconds) / 1000,
        tz=datetime.timezone.utc,
    )
    if selected_timezone is None:
        instant = instant.astimezone()
    else:
        instant = instant.astimezone(selected_timezone)
    return (
        f"{WEEKDAYS[instant.weekday()]} {MONTHS[instant.month - 1]} "
        f"{instant.day:02d} {instant.year:04d} {instant:%H:%M}"
    )


def grow_widths(widths, preferred, targets, remaining):
    order = (2, 0, 1, 3, 4)
    while remaining:
        grew = False
        for index in order:
            target = min(preferred[index], targets[index])
            if widths[index] >= target:
                continue
            widths[index] += 1
            remaining -= 1
            grew = True
            if not remaining:
                break
        if not grew:
            break
    return remaining


def table_widths(rows, terminal_width):
    preferred = []
    for index, (header, maximum) in enumerate(COLUMNS):
        widest = max([len(header), *(len(row[index]) for row in rows)])
        preferred.append(min(maximum, widest))

    frame_width = 3 * len(COLUMNS) + 1
    available = max(len(COLUMNS), terminal_width - frame_width)
    widths = [1] * len(COLUMNS)
    remaining = available - len(COLUMNS)
    for targets in COLUMN_GROWTH_BANDS:
        remaining = grow_widths(widths, preferred, targets, remaining)
        if not remaining or widths == preferred:
            break
    return widths


def wrapped_cell(value, width):
    return textwrap.wrap(
        value,
        width=width,
        break_long_words=True,
        break_on_hyphens=False,
    ) or [""]


def rendered_row(values, widths):
    cells = [wrapped_cell(value, width) for value, width in zip(values, widths)]
    height = max(len(cell) for cell in cells)
    lines = []
    for line_number in range(height):
        parts = []
        for cell, width in zip(cells, widths):
            value = cell[line_number] if line_number < len(cell) else ""
            parts.append(f" {value:<{width}} ")
        lines.append(f"|{'|'.join(parts)}|")
    return lines


def rendered_table(rows, terminal_width):
    headers = tuple(header for header, _ in COLUMNS)
    widths = table_widths(rows, terminal_width)
    border = f"+{'+'.join('-' * (width + 2) for width in widths)}+"
    lines = [border, *rendered_row(headers, widths), border]
    for row in rows:
        lines.extend(rendered_row(row, widths))
        lines.append(border)
    return "\n".join(lines)


def render(tasks, titles, assignments, projects, projectless, selected_timezone):
    rows = []
    for task in tasks:
        project = normalized_text(
            project_name(task, assignments, projects, projectless),
            "(unknown)",
        )
        title = normalized_text(
            titles.get(task["id"], task["fallback_title"]),
            "(untitled)",
        )
        created = local_timestamp(task["created_at_ms"], selected_timezone)
        updated = local_timestamp(task["updated_at_ms"], selected_timezone)
        rows.append((project, task["id"], title, created, updated))
    terminal_width = shutil.get_terminal_size(fallback=(160, 24)).columns
    return rendered_table(rows, terminal_width)


def main():
    parser = argparse.ArgumentParser(
        prog="codex-sessions",
        description="list recent user-visible codex tasks",
    )
    parser.add_argument("count", nargs="?", type=positive_integer, default=10)
    parser.add_argument(
        "-z",
        "--timezone",
        type=timezone,
        help="show times in this iana timezone (default: system local time)",
    )
    arguments = parser.parse_args()

    codex_home = environment_path("CODEX_HOME", pathlib.Path.home() / ".codex")
    catalog_database = environment_path(
        "CODEX_SESSIONS_CATALOG_DB",
        codex_home / "sqlite" / "codex-dev.db",
    )
    global_state = environment_path(
        "CODEX_SESSIONS_GLOBAL_STATE",
        codex_home / ".codex-global-state.json",
    )

    try:
        state_database = state_database_path(codex_home)
        tasks = task_rows(state_database, arguments.count)
        assignments, projects, projectless = project_state(global_state)
    except (json.JSONDecodeError, OSError, sqlite3.Error, ValueError) as error:
        parser.exit(1, f"codex-sessions: {error}\n")

    try:
        titles = desktop_titles(catalog_database)
    except sqlite3.Error as error:
        print(
            f"codex-sessions: warning: could not read desktop titles: {error}",
            file=sys.stderr,
        )
        titles = {}

    print(
        render(
            tasks,
            titles,
            assignments,
            projects,
            projectless,
            arguments.timezone,
        )
    )


if __name__ == "__main__":
    main()
