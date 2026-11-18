"""Install only the local CSS extension, preserving profiles and other extensions."""

import argparse
import json
from pathlib import Path
import subprocess
from zipfile import ZipFile


def matches_files(root, expected):
    for name, data in expected.items():
        path = root / name
        if not path.is_file():
            return False
        if name == "package.json":
            actual = json.loads(path.read_text())
            actual.pop("__metadata", None)
            if actual != json.loads(data):
                return False
        elif path.read_bytes() != data:
            return False
    return True


def install(code, vsix, extensions, user_data_dir=None):
    with ZipFile(vsix) as archive:
        manifest = json.loads(archive.read("extension/package.json"))
        identity = manifest["publisher"] + "." + manifest["name"]
        expected = {name.removeprefix("extension/"): archive.read(name)
                    for name in archive.namelist() if name.startswith("extension/")}
    registry = extensions / "extensions.json"
    entries = json.loads(registry.read_text()) if registry.exists() else []
    matches = [entry for entry in entries if entry["identifier"]["id"] == identity]
    for entry in matches:
        root = Path(entry["location"]["path"])
        if matches_files(root, expected):
            print("Markdown preview style already matches the managed files")
            return
    command = [code, "--extensions-dir", str(extensions)]
    if user_data_dir is not None:
        command += ["--user-data-dir", str(user_data_dir)]
    subprocess.run(command + ["--install-extension", str(vsix), "--force"], check=True)
    entries = json.loads(registry.read_text())
    matches = [entry for entry in entries if entry["identifier"]["id"] == identity]
    if not any(matches_files(Path(entry["location"]["path"]), expected) for entry in matches):
        raise RuntimeError("Installed preview stylesheet does not match the managed files")
    print("Installed and read back the managed preview styles; reopen an existing preview to refresh it")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--code", required=True)
    parser.add_argument("--vsix", type=Path, required=True)
    parser.add_argument("--extensions", type=Path, required=True)
    parser.add_argument("--user-data-dir", type=Path)
    args = parser.parse_args()
    install(args.code, args.vsix, args.extensions, args.user_data_dir)
