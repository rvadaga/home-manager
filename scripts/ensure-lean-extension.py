"""Install the pinned Lean extension without downgrading an existing version."""

import argparse
from pathlib import Path
import re
import subprocess


def version_tuple(value):
    if not re.fullmatch(r"\d+\.\d+\.\d+", value):
        raise ValueError(f"unrecognized extension version: {value}")
    return tuple(map(int, value.split(".")))


def installed_versions(code):
    installed = subprocess.check_output(
        [code, "--list-extensions", "--show-versions"], text=True
    )
    return [line.split("@", 1)[1] for line in installed.splitlines()
            if line.lower().startswith("leanprover.lean4@")]


def ensure(code, vsix, version):
    if not Path(code).is_file():
        print("VS Code is not installed; leaving editor setup unchanged")
        return
    versions = installed_versions(code)
    if versions and max(map(version_tuple, versions)) >= version_tuple(version):
        print("Lean editor extension already meets the pinned version")
        return
    subprocess.run([code, "--install-extension", vsix], check=True)
    versions = installed_versions(code)
    if not versions or max(map(version_tuple, versions)) < version_tuple(version):
        raise RuntimeError("VS Code did not register the requested Lean extension")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("code", "vsix", "version"):
        parser.add_argument(f"--{name}", required=True)
    args = parser.parse_args()
    ensure(args.code, args.vsix, args.version)
