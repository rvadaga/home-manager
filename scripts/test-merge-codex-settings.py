#!/usr/bin/env python3

import os
import pathlib
import stat
import subprocess
import sys
import tempfile
import tomllib
import unittest

import tomli_w


class MergeCodexSettingsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.target = self.root / "home" / "config.toml"
        self.defaults = self.root / "defaults.toml"
        self.forced = self.root / "forced.toml"
        self.write(self.defaults, {"features": {"fast_mode": True, "hooks": True}})
        self.write(self.forced, {"features": {"fast_mode": False}})

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(tomli_w.dumps(data))

    def read(self):
        return tomllib.loads(self.target.read_text())

    def merge(self, *, success=True):
        command = (
            [os.environ["CODEX_SETTINGS_MERGER"]]
            if "CODEX_SETTINGS_MERGER" in os.environ
            else [sys.executable, str(pathlib.Path(__file__).with_name("merge-codex-settings.py"))]
        )
        result = subprocess.run(
            command + [str(self.target), str(self.defaults), str(self.forced)],
            capture_output=True,
            text=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_forced_value_replaces_live_without_changing_other_settings(self):
        self.write(self.target, {
            "model": "example-model",
            "features": {"fast_mode": True, "hooks": False, "shell_snapshot": False},
            "projects": {"/tmp/example": {"trust_level": "trusted"}},
        })
        expected = self.read()
        expected["features"]["fast_mode"] = False
        self.merge()
        self.assertEqual(self.read(), expected)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)

    def test_empty_forced_settings_preserve_live_scalars_and_union_arrays(self):
        self.write(self.defaults, {"features": {"fast_mode": False}, "items": ["default", "shared", "default"]})
        self.write(self.forced, {})
        self.write(self.target, {"features": {"fast_mode": True}, "items": ["live", "shared"]})
        self.merge()
        self.assertEqual(self.read(), {
            "features": {"fast_mode": True}, "items": ["live", "shared", "default"],
        })

    def test_managed_x_launcher_replaces_the_old_npx_entry(self):
        managed = {"command": "xurl-mcp", "args": ["mcp", "https://api.x.com/mcp"]}
        self.write(self.defaults, {"mcp_servers": {"xapi": managed}})
        self.write(self.forced, {"mcp_servers": {"xapi": managed}})
        self.write(self.target, {
            "mcp_servers": {
                "xapi": {"command": "npx", "args": ["-y", "@xdevplatform/xurl", "mcp", "https://api.x.com/mcp"],
                         "enabled": False, "default_tools_approval_mode": "auto"},
                "other": {"command": "other-tool", "args": ["custom"]},
            },
            "model": "custom-model",
        })
        expected = self.read()
        expected["mcp_servers"]["xapi"].update(managed)
        self.merge()
        self.assertEqual(self.read(), expected)
        self.merge()
        self.assertEqual(self.read(), expected)

    def test_forced_arrays_replace_existing_arrays(self):
        self.write(self.defaults, {"nested": {"items": ["default"], "keep": True}})
        self.write(self.target, {"nested": {"items": ["live"]}})
        for items in (["forced"], []):
            with self.subTest(items=items):
                self.write(self.forced, {"nested": {"items": items}})
                self.merge()
                self.assertEqual(self.read(), {"nested": {"items": items, "keep": True}})

    def test_first_activation_applies_forced_values(self):
        self.merge()
        self.assertEqual(self.read(), {"features": {"fast_mode": False, "hooks": True}})
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)

    def test_each_activation_restores_the_forced_value(self):
        self.merge()
        first = self.target.read_bytes()
        self.merge()
        self.assertEqual(self.target.read_bytes(), first)
        self.write(self.target, {"features": {"fast_mode": True}})
        self.merge()
        self.assertFalse(self.read()["features"]["fast_mode"])

    def test_invalid_toml_leaves_live_file_untouched(self):
        self.write(self.target, {"features": {"fast_mode": True}})
        for path in (self.defaults, self.forced, self.target):
            with self.subTest(path=path.name):
                original = path.read_bytes()
                path.write_text("invalid = [")
                before = self.target.read_bytes()
                result = self.merge(success=False)
                self.assertIn("invalid toml", result.stderr)
                self.assertEqual(self.target.read_bytes(), before)
                path.write_bytes(original)
        self.assertEqual(list(self.target.parent.glob(".codex-settings-merge.*")), [])

    def test_symlink_is_replaced_without_modifying_its_destination(self):
        original = self.root / "original.toml"
        self.write(original, {"features": {"fast_mode": True}})
        before = original.read_bytes()
        self.target.parent.mkdir()
        self.target.symlink_to(original)
        self.merge()
        self.assertFalse(self.target.is_symlink())
        self.assertFalse(self.read()["features"]["fast_mode"])
        self.assertEqual(original.read_bytes(), before)

    def test_broken_symlink_is_replaced(self):
        self.target.parent.mkdir()
        self.target.symlink_to(self.root / "missing.toml")
        self.merge()
        self.assertFalse(self.target.is_symlink())
        self.assertFalse(self.read()["features"]["fast_mode"])


if __name__ == "__main__":
    unittest.main()
