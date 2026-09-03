#!/usr/bin/env python3
"""exercise the mermaid validator with table-driven markdown fixtures."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


validator = Path(__file__).with_name("validate-mermaid.py")


def run_fixture(path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(validator), str(path)],
        check=False,
        capture_output=True,
        text=True,
    )


def main() -> int:
    fixtures = [
        *[
            (
                f"valid-{direction.lower()}",
                f"```mermaid\nflowchart {direction}\n  a --> b\n```\n",
                True,
            )
            for direction in ("LR", "RL", "TD", "TB", "BT")
        ],
        (
            "positive-control-lowercase-lr",
            "```mermaid\nflowchart lr\n  a --> b\n```\n",
            False,
        ),
        (
            "invalid-lowercase-directions",
            "\n".join(
                f"```mermaid\nflowchart {direction}\n  a --> b\n```"
                for direction in ("rl", "td", "tb", "bt")
            ),
            False,
        ),
        (
            "invalid-unsupported-direction",
            "```mermaid\nflowchart ZZ\n  a --> b\n```\n",
            False,
        ),
        (
            "ignore-prose-and-non-mermaid-fences",
            r"flowchart lr and literal \n are prose."
            "\n\n"
            "```text\nflowchart lr\nnode[\"one\\ntwo\"]\n```\n",
            True,
        ),
        (
            "accept-other-mermaid-grammar",
            "~~~Mermaid\nsequenceDiagram\n  a->>b: hello\n~~~\n",
            True,
        ),
        (
            "reject-literal-line-break",
            "```mermaid\nflowchart LR\n  node[\"one\\ntwo\"]\n```\n",
            False,
        ),
    ]

    failures: list[str] = []
    with tempfile.TemporaryDirectory() as temporary_directory:
        root = Path(temporary_directory)
        for name, markdown, should_pass in fixtures:
            path = root / f"{name}.md"
            path.write_text(markdown, encoding="utf-8")
            result = run_fixture(path)
            passed = result.returncode == 0
            if passed != should_pass:
                failures.append(
                    f"{name}: expected {'pass' if should_pass else 'failure'}, "
                    f"got exit {result.returncode}: {result.stderr.strip()}"
                )

        positive_control = root / "positive-control-lowercase-lr.md"
        result = run_fixture(positive_control)
        if "invalid mermaid flowchart direction 'lr'" not in result.stderr:
            failures.append("positive control did not report lowercase flowchart lr")

    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1

    print(f"passed {len(fixtures)} mermaid validation fixtures")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
