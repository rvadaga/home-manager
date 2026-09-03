#!/usr/bin/env python3
"""validate case-sensitive mermaid grammar in markdown files."""

from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Iterable, Iterator
from pathlib import Path


opening_fence_re = re.compile(
    r"^(?P<indent> {0,3})(?P<fence>`{3,}|~{3,})(?P<info>.*)$"
)
flowchart_re = re.compile(r"^\s*flowchart[ \t]+(?P<direction>[A-Za-z]+)\b")
valid_directions = ("LR", "RL", "TD", "TB", "BT")


def mermaid_lines(text: str) -> Iterator[tuple[int, str]]:
    """yield line numbers and content from mermaid fenced blocks only."""

    fence_character: str | None = None
    fence_length = 0
    in_mermaid = False

    for line_number, line in enumerate(text.splitlines(), start=1):
        if fence_character is not None:
            closing_fence_re = re.compile(
                rf"^ {{0,3}}{re.escape(fence_character)}{{{fence_length},}}[ \t]*$"
            )
            if closing_fence_re.match(line):
                fence_character = None
                fence_length = 0
                in_mermaid = False
            elif in_mermaid:
                yield line_number, line
            continue

        match = opening_fence_re.match(line)
        if match is None:
            continue

        fence = match.group("fence")
        info = match.group("info")
        if fence.startswith("`") and "`" in info:
            continue

        fence_character = fence[0]
        fence_length = len(fence)
        info_word = info.strip().split(maxsplit=1)[0] if info.strip() else ""
        in_mermaid = info_word.lower() == "mermaid"


def validation_errors(path: Path, text: str) -> list[str]:
    errors: list[str] = []

    for line_number, line in mermaid_lines(text):
        flowchart = flowchart_re.match(line)
        if flowchart is not None:
            direction = flowchart.group("direction")
            if direction not in valid_directions:
                allowed = ", ".join(valid_directions)
                errors.append(
                    f"{path}:{line_number}: invalid mermaid flowchart direction "
                    f"{direction!r}; use one of: {allowed}"
                )

        if r"\n" in line:
            errors.append(
                f"{path}:{line_number}: mermaid renders a literal backslash-n; "
                "use <br/>"
            )

    return errors


def markdown_paths(inputs: Iterable[Path]) -> Iterator[Path]:
    seen: set[Path] = set()

    for input_path in inputs:
        candidates = (
            sorted(input_path.rglob("*.md")) if input_path.is_dir() else [input_path]
        )
        for candidate in candidates:
            resolved = candidate.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            yield candidate


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="validate mermaid fenced blocks in markdown files"
    )
    parser.add_argument("paths", nargs="+", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    errors: list[str] = []

    for path in markdown_paths(args.paths):
        if not path.is_file():
            errors.append(f"{path}: markdown file does not exist")
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            errors.append(f"{path}: cannot read markdown: {error}")
            continue
        errors.extend(validation_errors(path, text))

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
