#!/usr/bin/env python3
"""verify the pinned binary with disposable local remotes and no github access."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path


def exercise(binary: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="gh-stack-command-") as directory:
        root = Path(directory)
        repo, remote = root / "repo", root / "remote.git"
        repo.mkdir()
        env = {key: val for key, val in os.environ.items() if not key.startswith(("GIT_", "GH_"))}
        env.update(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                   GH_CONFIG_DIR=str(root / "gh"), GH_PROMPT_DISABLED="1")

        def run(*args: str, cwd: Path = repo, success: bool = True) -> str:
            result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
            if success and result.returncode != 0:
                raise AssertionError((args, result.returncode, result.stdout, result.stderr))
            if not success and result.returncode == 0:
                raise AssertionError("command unexpectedly succeeded")
            return (result.stdout + result.stderr).strip()

        def git(*args: str, cwd: Path = repo) -> str:
            return run("git", *args, cwd=cwd)

        def stack(*args: str, success: bool = True) -> str:
            return run(str(binary), *args, success=success)

        def commit(name: str) -> str:
            (repo / name).write_text(name)
            git("add", name)
            git("commit", "-m", name)
            return git("rev-parse", "HEAD")

        assert stack("--version") == "gh stack version 0.1.1"
        help_text = stack("push", "--help")
        assert "--remote" in help_text
        assert "--upstack" not in help_text and "--branch" not in help_text
        git("init", "-b", "trunk")
        git("config", "user.name", "fixture")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "commit.gpgsign", "false")
        git("config", "rerere.enabled", "true")
        commit("base")
        git("switch", "-c", "parent")
        parent = commit("parent")
        git("switch", "-c", "child")
        child = commit("child")
        git("clone", "--bare", str(repo), str(remote))
        git("remote", "add", "origin", str(remote))
        git("fetch", "origin", "parent", "child")
        stack("init", "--base", "trunk", "parent", "child")
        git("switch", "parent")
        selected = commit("selected")
        hook = repo / ".git/hooks/pre-push"
        hook.write_text('#!/bin/sh\ncat > "$(git rev-parse --git-dir)/hook-refs"\n')
        hook.chmod(0o755)
        stack("push")
        assert git("rev-parse", "parent", cwd=remote) == selected
        assert git("rev-parse", "child", cwd=remote) == child
        assert "refs/heads/parent" in (repo / ".git/hook-refs").read_text()
        state = json.loads((repo / ".git/gh-stack").read_text())
        assert state["stacks"][0]["branches"][1]["base"] == parent
        print("selected parent advanced; child head and old base preserved; pre-push hook ran")

        hook.write_text("#!/bin/sh\nexit 1\n")
        selected2 = commit("selected-again")
        stack("push", success=False)
        assert git("rev-parse", "parent", cwd=remote) == selected
        print("rejecting hook prevented publication")
        hook.write_text("#!/bin/sh\nexit 0\n")

        # only the disposable bare remote moves between the recorded lease and push.
        git("switch", "-c", "other-writer", selected)
        moved = commit("other-writer")
        git("fetch", str(repo), "other-writer:refs/heads/parent", cwd=remote)
        git("switch", "parent")
        assert git("rev-parse", "refs/remotes/origin/parent") == selected
        stack("push")
        assert git("rev-parse", "parent", cwd=remote) == selected2
        assert moved != selected2
        print("known limitation reproduced: refreshed lease allowed intervening remote commit to be overwritten")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path, help="path to the official 0.1.1 binary")
    exercise(parser.parse_args().binary.resolve())
