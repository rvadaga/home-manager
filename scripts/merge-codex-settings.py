#!/usr/bin/env python3

import os
import pathlib
import sys
import tempfile
import tomllib

import tomli_w


def load_toml(path):
    try:
        with path.open("rb") as file:
            return tomllib.load(file)
    except tomllib.TOMLDecodeError as error:
        raise SystemExit(f"cannot merge codex settings: invalid toml in {path}: {error}")


def deep_merge(left, right, *, merge_arrays=True):
    if isinstance(left, dict) and isinstance(right, dict):
        merged = dict(left)
        for key, value in right.items():
            merged[key] = (
                deep_merge(merged[key], value, merge_arrays=merge_arrays)
                if key in merged
                else value
            )
        return merged

    if merge_arrays and isinstance(left, list) and isinstance(right, list):
        merged = list(right)
        for item in left:
            if item not in merged:
                merged.append(item)
        return merged

    return right


def main():
    target, defaults_path, forced_path = map(pathlib.Path, sys.argv[1:])
    if target.exists() and not target.is_file():
        raise SystemExit(f"cannot merge codex settings: {target} is not a regular file")

    defaults = load_toml(defaults_path)
    live = load_toml(target) if target.exists() else {}
    forced = load_toml(forced_path)
    merged = deep_merge(defaults, live)
    # forced values replace only their declared keys, including whole arrays.
    merged = deep_merge(merged, forced, merge_arrays=False)

    target.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(
        dir=target.parent,
        prefix=".codex-settings-merge.",
    )
    temporary_path = pathlib.Path(temporary_name)
    try:
        with os.fdopen(file_descriptor, "wb") as file:
            tomli_w.dump(merged, file)
        temporary_path.chmod(0o600)
        temporary_path.replace(target)
    finally:
        temporary_path.unlink(missing_ok=True)

    print(f"merged nix settings into {target}")


if __name__ == "__main__":
    main()
