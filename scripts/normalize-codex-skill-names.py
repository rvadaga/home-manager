#!/usr/bin/env python3
"""Keep Codex picker labels equal to canonical skill invocation names."""

import argparse
import copy
import os
from pathlib import Path
import re
import tempfile

import yaml


class UniqueKeyLoader(yaml.SafeLoader):
    def construct_mapping(self, node, deep=False):
        seen = set()
        for key_node, _ in node.value:
            if key_node.tag == "tag:yaml.org,2002:merge":
                continue
            key = self.construct_object(key_node, deep=deep)
            if key in seen:
                raise ValueError(f"duplicate YAML key: {key!r}")
            seen.add(key)
        return super().construct_mapping(node, deep=deep)


def load_yaml(text):
    return yaml.load(text, Loader=UniqueKeyLoader)


def mapping(value, label):
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a YAML mapping")
    return value


def normalized_metadata(skill, expected_name=None):
    """Return the metadata path and replacement; leave the skill untouched."""
    skill = Path(skill)
    for path in (skill, skill / "SKILL.md", skill / "agents", skill / "agents/openai.yaml"):
        if path.is_symlink():
            raise ValueError(f"refusing to edit through a symlink: {path}")
    source = (skill / "SKILL.md").read_text()
    match = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", source, re.DOTALL)
    if match is None:
        raise ValueError(f"missing frontmatter: {skill}")
    frontmatter = mapping(load_yaml(match[1]), "frontmatter")
    name = frontmatter.get("name")
    if not isinstance(name, str) or len(name) > 64 or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
        raise ValueError(f"noncanonical skill name: {name!r}")
    if expected_name is not None and name != expected_name:
        raise ValueError(f"skill name {name!r} differs from directory name {expected_name!r}")
    path = skill / "agents/openai.yaml"
    original = path.read_text() if path.exists() else ""
    parsed = load_yaml(original)
    metadata = mapping({} if parsed is None else parsed, str(path))
    interface = mapping(metadata.get("interface", {}), "interface")
    if interface.get("display_name") == name:
        return path, None
    updated = copy.deepcopy(metadata)
    updated.setdefault("interface", {})["display_name"] = name
    return path, yaml.safe_dump(updated, sort_keys=False, allow_unicode=True)


def write_metadata(path, replacement):
    if replacement is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    # Replace only metadata; a failed write must not truncate the installed file.
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(replacement)
            stream.flush()
            os.chmod(temporary, mode)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def normalize_local_root(root):
    """Update ordinary local skills, leaving externally managed links alone."""
    root = Path(root)
    if any(path.is_symlink() for path in (root, *root.parents)):
        raise ValueError(f"local skill root must not traverse a symlink: {root}")
    if not root.exists():
        return 0
    planned = []
    for skill in sorted(root.iterdir()):
        if skill.name.startswith(".") or skill.is_symlink() or not skill.is_dir():
            continue
        if not (skill / "SKILL.md").is_file():
            continue
        planned.append(normalized_metadata(skill, skill.name))
    # Validate the complete root before changing any of its metadata.
    for path, replacement in planned:
        write_metadata(path, replacement)
    return len(planned)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    skill = commands.add_parser("skill")
    skill.add_argument("directory", type=Path)
    skill.add_argument("--expected-name", required=True)
    local = commands.add_parser("local-root")
    local.add_argument("directory", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "skill":
            write_metadata(*normalized_metadata(args.directory, args.expected_name))
        else:
            count = normalize_local_root(args.directory)
            print(f"verified picker names for {count} local skills")
    except (OSError, ValueError, yaml.YAMLError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
