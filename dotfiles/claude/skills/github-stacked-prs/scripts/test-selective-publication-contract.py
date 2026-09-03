#!/usr/bin/env python3
"""exercise the selective publication contract's decision boundaries."""

from __future__ import annotations

import copy
import importlib.util
import unittest
from pathlib import Path


script_path = Path(__file__).with_name("check-selective-publication-contract.py")
script_spec = importlib.util.spec_from_file_location("selective_publication_contract", script_path)
assert script_spec is not None and script_spec.loader is not None
contract = importlib.util.module_from_spec(script_spec)
script_spec.loader.exec_module(contract)


def layer(local: str, remote: str, *, state: str = "draft") -> dict[str, str]:
    return {
        "local_head": local,
        "remote_head": remote,
        "pr_head": remote,
        "lease_head": remote,
        "base_ref": "parent",
        "expected_base_ref": "parent",
        "state": state,
        "expected_state": state,
    }


def preflight() -> dict[str, object]:
    return {
        "phase": "preflight",
        "preflight_snapshot_id": "2026-08-26t120000z",
        "pre_push_readback": True,
        "restack_ran": False,
        "unexpected_remote_movement": False,
        "semantic_propagation": False,
        "integrator_clean": True,
        "publication_command": "gh stack push",
        "checks": {
            "changed_tests": True,
            "changed_hooks": True,
            "diff": True,
            "markers": True,
            "linear_topology": True,
            "leases_and_states": True,
        },
        "changed_indices": [1],
        "layers": [layer("a", "a"), layer("b-local", "b"), layer("c", "c")],
        "deferred_restack": {"first_descendant": 2, "reason": "later layer remains for restack"},
    }


def post_push() -> dict[str, object]:
    manifest = preflight()
    manifest["phase"] = "post-push"
    manifest["layers"] = [layer("a", "a"), layer("b-local", "b-local"), layer("c", "c")]
    return manifest


class selective_publication_contract_test(unittest.TestCase):
    def assert_rejected(self, manifest: dict[str, object], fragment: str) -> None:
        self.assertTrue(any(fragment in error for error in contract.validate(manifest)), contract.validate(manifest))

    def test_accepts_contiguous_changed_subseries(self) -> None:
        self.assertEqual([], contract.validate(preflight()))
        self.assertEqual([], contract.validate(post_push()))

    def test_rejects_unexpected_descendant_movement(self) -> None:
        manifest = post_push()
        manifest["layers"][2]["remote_head"] = "moved"
        self.assert_rejected(manifest, "untouched layer 2 moved")

    def test_rejects_pull_request_state_change(self) -> None:
        manifest = post_push()
        manifest["layers"][1]["state"] = "ready"
        self.assert_rejected(manifest, "changed pull request state")

    def test_rejects_restacked_attempt(self) -> None:
        manifest = preflight()
        manifest["restack_ran"] = True
        self.assert_rejected(manifest, "restack_ran")

    def test_rejects_noncontiguous_changes(self) -> None:
        manifest = preflight()
        manifest["changed_indices"] = [0, 2]
        self.assert_rejected(manifest, "contiguous")

    def test_rejects_semantic_propagation(self) -> None:
        manifest = preflight()
        manifest["semantic_propagation"] = True
        self.assert_rejected(manifest, "semantic propagation")

    def test_requires_deferred_restack_record(self) -> None:
        manifest = preflight()
        manifest.pop("deferred_restack")
        self.assert_rejected(manifest, "deferred_restack")

    def test_requires_full_post_push_readback(self) -> None:
        manifest = post_push()
        manifest["layers"][1].pop("pr_head")
        self.assert_rejected(manifest, "missing pr_head")

    def test_rejects_direct_push(self) -> None:
        manifest = preflight()
        manifest["publication_command"] = "git push origin layer"
        self.assert_rejected(manifest, "only gh stack push")

    def test_requires_one_snapshot_and_pre_push_readback(self) -> None:
        manifest = preflight()
        manifest["preflight_snapshot_id"] = ""
        manifest["pre_push_readback"] = False
        self.assert_rejected(manifest, "preflight_snapshot_id")
        self.assert_rejected(manifest, "pre-push readback")


if __name__ == "__main__":
    unittest.main()
