#!/usr/bin/env python3

import json
import pathlib
import subprocess
import unittest


class MergeClaudeSettingsTest(unittest.TestCase):
    def merge(self, defaults, live, forced):
        result = subprocess.run(
            ["jq", "-s", "-f", str(pathlib.Path(__file__).with_name("merge-claude-settings.jq"))],
            input="\n".join(json.dumps(value) for value in (defaults, live, forced)),
            capture_output=True, text=True, check=True,
        )
        return json.loads(result.stdout)

    def test_managed_x_launcher_replaces_the_old_npx_entry(self):
        managed = {"command": "xurl-mcp", "args": ["mcp", "https://api.x.com/mcp"]}
        defaults = {"mcpServers": {"xapi": managed}}
        forced = defaults
        live = {
            "mcpServers": {
                "xapi": {"command": "npx", "args": ["-y", "@xdevplatform/xurl", "https://api.x.com/mcp", "mcp"],
                         "env": {"EXAMPLE_SETTING": "custom"}},
                "other": {"command": "other-tool"},
            },
            "permissions": {"allow": ["custom"]},
        }
        expected = json.loads(json.dumps(live))
        expected["mcpServers"]["xapi"].update(managed)
        merged = self.merge(defaults, live, forced)
        self.assertEqual(merged, expected)
        self.assertEqual(self.merge(defaults, merged, forced), expected)

    def test_unforced_settings_keep_live_scalars_and_union_arrays(self):
        self.assertEqual(self.merge({"value": "default", "items": ["default", "shared"]},
                                    {"value": "live", "items": ["live", "shared"]}, {}),
                         {"value": "live", "items": ["default", "live", "shared"]})

    def test_forced_arrays_can_be_cleared(self):
        self.assertEqual(self.merge({"items": ["default"]}, {"items": ["live"]}, {"items": []}),
                         {"items": []})

    def test_first_activation_uses_managed_values(self):
        managed = {"mcpServers": {"xapi": {"command": "xurl-mcp", "args": ["mcp"]}}}
        self.assertEqual(self.merge(managed, {}, managed), managed)


if __name__ == "__main__":
    unittest.main()
