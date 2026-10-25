#!/usr/bin/env python3
import copy
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

import yaml

spec = importlib.util.spec_from_file_location(
    "names", Path(__file__).with_name("normalize-codex-skill-names.py")
)
names = importlib.util.module_from_spec(spec)
spec.loader.exec_module(names)


class SkillNamesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        self.addCleanup(self.temporary.cleanup)

    def skill(self, folder="sample-skill", name=None, metadata=None):
        path = self.root / folder
        path.mkdir()
        (path / "SKILL.md").write_text(
            f"---\nname: {name or folder}\ndescription: Preserve this description.\n---\n\n# Sample Skill\n\nKeep these instructions.\n"
        )
        (path / "assets").mkdir()
        (path / "assets/icon.svg").write_bytes(b"<svg/>\n")
        if metadata is not None:
            (path / "agents").mkdir()
            (path / "agents/openai.yaml").write_text(metadata)
        return path

    def normalize(self, path):
        names.write_metadata(*names.normalized_metadata(path, path.name))
        return yaml.safe_load((path / "agents/openai.yaml").read_text())

    def test_title_case_and_spaces_use_identifier(self):
        for label in ("Sample Skill", "sample skill", "unrelated title"):
            with self.subTest(label=label):
                path = self.skill("sample-" + str(len(list(self.root.iterdir()))), metadata=f'interface:\n  display_name: "{label}"\n')
                self.assertEqual(self.normalize(path)["interface"]["display_name"], path.name)

    def test_missing_file_interface_and_display_name(self):
        for i, metadata in enumerate((None, "", "policy:\n  allow_implicit_invocation: false\n", "interface:\n  short_description: Preserve this blurb.\n")):
            with self.subTest(metadata=metadata):
                path = self.skill(f"sample-{i}", metadata=metadata)
                self.assertEqual(self.normalize(path)["interface"]["display_name"], path.name)

    def test_canonical_metadata_is_byte_identical_and_idempotent(self):
        original = '# retain this comment\ninterface:\n  display_name: "sample-skill"\n'
        path = self.skill(metadata=original)
        self.normalize(path)
        self.assertEqual((path / "agents/openai.yaml").read_text(), original)
        self.assertIsNone(names.normalized_metadata(path)[1])

    def test_all_other_metadata_and_resources_survive(self):
        metadata = {
            "interface": {"display_name": "Sample Skill", "short_description": "Original blurb", "icon_small": "./assets/icon.svg", "icon_large": "./assets/icon.svg", "brand_color": "#AABBCC", "default_prompt": "Use $sample-skill to review this."},
            "policy": {"allow_implicit_invocation": False},
            "dependencies": {"tools": [{"type": "mcp", "value": "example", "description": "Original dependency", "transport": "streamable_http", "url": "https://example.com/mcp"}]},
            "extension": {"unknown": ["preserve", {"nested": 42}]},
        }
        path = self.skill(metadata=yaml.safe_dump(metadata))
        original_files = {str(p.relative_to(path)): p.read_bytes() for p in path.rglob("*") if p.is_file() and p.name != "openai.yaml"}
        expected = copy.deepcopy(metadata)
        expected["interface"]["display_name"] = "sample-skill"
        self.assertEqual(self.normalize(path), expected)
        self.assertEqual({str(p.relative_to(path)): p.read_bytes() for p in path.rglob("*") if p.is_file() and p.name != "openai.yaml"}, original_files)
        self.assertIsNone(names.normalized_metadata(path)[1])

    def test_invalid_or_namespaced_identity_is_never_renamed(self):
        for i, name in enumerate(("Sample-Skill", "sample skill", "plugin:sample-skill", "sample--skill", "a" * 65)):
            path = self.skill(f"folder-{i}", name=name)
            before = (path / "SKILL.md").read_bytes()
            with self.subTest(name=name), self.assertRaises(ValueError):
                names.normalized_metadata(path)
            self.assertEqual((path / "SKILL.md").read_bytes(), before)
            self.assertFalse((path / "agents").exists())

    def test_directory_alias_cannot_create_a_duplicate_invocation(self):
        self.skill()
        self.skill("other-folder", name="sample-skill")
        with self.assertRaises(ValueError):
            names.normalize_local_root(self.root)
        self.assertFalse(list(self.root.glob("*/agents/openai.yaml")))

    def test_invalid_metadata_does_not_erase_existing_fields(self):
        for i, metadata in enumerate(("[]", "interface: []", "interface: null", "interface: {display_name: one, display_name: two}", "policy: [")):
            path = self.skill(f"sample-{i}", metadata=metadata)
            with self.subTest(metadata=metadata), self.assertRaises((ValueError, yaml.YAMLError)):
                self.normalize(path)
            self.assertEqual((path / "agents/openai.yaml").read_text(), metadata)

    def test_local_root_skips_hidden_incomplete_and_linked_skills(self):
        skill = self.skill()
        self.skill(".system")
        (self.root / "incomplete").mkdir()
        (self.root / "external-plugin").symlink_to(skill, target_is_directory=True)
        self.assertEqual(names.normalize_local_root(self.root), 1)
        self.assertFalse((self.root / ".system/agents").exists())
        self.assertFalse((self.root / "incomplete/agents").exists())
        self.assertEqual(self.normalize(skill)["interface"]["display_name"], "sample-skill")

    def test_local_root_rejects_symlinked_metadata_or_ancestors(self):
        path = self.skill()
        outside = self.root / "outside.yaml"
        outside.write_text("policy:\n  allow_implicit_invocation: false\n")
        (path / "agents").mkdir()
        (path / "agents/openai.yaml").symlink_to(outside)
        with self.assertRaises(ValueError):
            names.normalize_local_root(self.root)
        self.assertEqual(outside.read_text(), "policy:\n  allow_implicit_invocation: false\n")
        alias = self.root / "alias"
        alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            names.normalize_local_root(alias / "nested")

    def test_missing_local_root_is_not_created(self):
        path = self.root / "absent"
        self.assertEqual(names.normalize_local_root(path), 0)
        self.assertFalse(path.exists())

    def test_every_owned_source_skill(self):
        source_root = Path(__file__).resolve().parents[1] / "dotfiles/claude/skills"
        sources = sorted(source_root.glob("*/SKILL.md"))
        self.assertTrue(sources, "the source inventory must not pass vacuously")
        for source in sources:
            with self.subTest(skill=source.parent.name):
                target = self.root / source.parent.name
                shutil.copytree(source.parent, target)
                source_bytes = source.read_bytes()
                self.assertEqual(self.normalize(target)["interface"]["display_name"], source.parent.name)
                self.assertEqual((target / "SKILL.md").read_bytes(), source_bytes)


if __name__ == "__main__":
    unittest.main()
