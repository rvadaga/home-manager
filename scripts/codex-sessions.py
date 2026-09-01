#!/usr/bin/env python3

import argparse
import json
import os
import pathlib
import re
import sqlite3
import sys

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
    return rendered_terminal_table(rows)


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
