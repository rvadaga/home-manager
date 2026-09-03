#!/usr/bin/env python3
"""exercise the partial stack recovery decision boundaries."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


script_path = Path(__file__).with_name("check-partial-stack-recovery-contract.py")
script_spec = importlib.util.spec_from_file_location("partial_stack_recovery_contract", script_path)
assert script_spec is not None and script_spec.loader is not None
contract = importlib.util.module_from_spec(script_spec)
script_spec.loader.exec_module(contract)


def layer(name: str, head: str) -> dict[str, str]:
    return {
        "name": name,
        "local_head": head,
        "remote_head": head,
        "pr_head": head,
        "lease_head": head,
        "base_ref": "parent",
        "state": "draft",
        "expected_state": "draft",
    }


def common(phase: str) -> dict[str, object]:
    return {
        "phase": phase,
        "preflight_snapshot_id": "snapshot",
        "integrator_clean": True,
        "server_prefix_patch_identity": True,
        "trunk_local_matches_remote": True,
        "trunk_live_matches_remote": True,
        "all_pr_states_recorded": True,
        "all_pr_states_unchanged": True,
        "history_operation": "none",
        "unexpected_remote_movement": False,
        "metadata_rebuild": False,
        "forbidden_operations": {
            "direct_push": False,
            "init": False,
            "link": False,
            "manual_rebase": False,
            "metadata_edit": False,
            "publication": False,
            "sync": False,
            "unstack_local": False,
        },
        "layers": [layer("rebased-prefix", "a"), layer("untouched", "b"), layer("child", "c")],
    }


def boundaries() -> list[dict[str, object]]:
    return [
        {
            "child_index": 1,
            "parent_index": 0,
            "recorded_base": "a-old",
            "view_base": "a-old",
            "candidate": "a-old",
            "source": "recorded_base",
            "candidate_is_child_ancestor": True,
        },
        {
            "child_index": 2,
            "parent_index": 1,
            "recorded_base": "b",
            "view_base": "b",
            "candidate": "b",
            "source": "current_parent",
            "candidate_is_child_ancestor": True,
        },
    ]


def preflight() -> dict[str, object]:
    manifest = common("preflight")
    manifest.update(
        {
            "affected_indices": [1, 2],
            "boundaries": boundaries(),
            "recovery_command": "gh stack rebase --upstack --no-trunk",
        }
    )
    return manifest


def post_rebase() -> dict[str, object]:
    manifest = common("post-rebase")
    manifest["layers"] = [
        layer("rebased-prefix", "a"),
        layer("untouched", "b-new"),
        layer("child", "c-new"),
    ]
    for entry, before in zip(manifest["layers"], ("a", "b", "c"), strict=True):
        entry["preflight_local_head"] = before
        entry["remote_head"] = before
        entry["pr_head"] = before
        entry["lease_head"] = before
    manifest.update(
        {
            "affected_indices": [1, 2],
            "boundaries": boundaries(),
            "recovery_command": "gh stack rebase --upstack --no-trunk",
            "validation": {"affected_layers": True, "cumulative_stack": True},
            "post_view_bases": [
                {"child_index": 1, "view_base": "a", "parent_head": "a"},
                {"child_index": 2, "view_base": "b-new", "parent_head": "b-new"},
            ],
        }
    )
    return manifest


def hold() -> dict[str, object]:
    manifest = common("hold")
    manifest.update({"recovery_command": "none", "hold_reason": "previous boundary is unavailable"})
    return manifest


class partial_stack_recovery_contract_test(unittest.TestCase):
    def assert_rejected(self, manifest: dict[str, object], fragment: str) -> None:
        self.assertTrue(any(fragment in error for error in contract.validate(manifest)), contract.validate(manifest))

    def test_accepts_retained_boundary_recovery_and_local_readback(self) -> None:
        self.assertEqual([], contract.validate(preflight()))
        self.assertEqual([], contract.validate(post_rebase()))

    def test_accepts_unavailable_boundary_hold(self) -> None:
        self.assertEqual([], contract.validate(hold()))

    def test_rejects_rebuilt_metadata_even_when_heads_are_unchanged(self) -> None:
        manifest = hold()
        manifest["metadata_rebuild"] = True
        self.assert_rejected(manifest, "metadata_rebuild")

    def test_rejects_ambiguous_or_mismatched_boundary(self) -> None:
        manifest = preflight()
        manifest["boundaries"][0]["candidate_is_child_ancestor"] = False
        manifest["boundaries"][1]["view_base"] = "wrong"
        self.assert_rejected(manifest, "not proved")
        self.assert_rejected(manifest, "does not match gh stack view")

    def test_rejects_stale_trunk_or_remote_movement(self) -> None:
        manifest = preflight()
        manifest["trunk_live_matches_remote"] = False
        manifest["unexpected_remote_movement"] = True
        self.assert_rejected(manifest, "trunk_live_matches_remote")
        self.assert_rejected(manifest, "unexpected remote movement")

    def test_rejects_changed_pull_request_state_or_active_rebase(self) -> None:
        manifest = preflight()
        manifest["layers"][1]["state"] = "ready"
        manifest["history_operation"] = "rebase"
        self.assert_rejected(manifest, "changed pull request state")
        self.assert_rejected(manifest, "active history operation")

    def test_rejects_missing_patch_identity(self) -> None:
        manifest = preflight()
        manifest["server_prefix_patch_identity"] = False
        self.assert_rejected(manifest, "server_prefix_patch_identity")

    def test_requires_affected_and_cumulative_validation(self) -> None:
        manifest = post_rebase()
        manifest["validation"]["cumulative_stack"] = False
        self.assert_rejected(manifest, "cumulative stack validation")

    def test_rejects_non_suffix_or_unchanged_affected_layer(self) -> None:
        manifest = preflight()
        manifest["affected_indices"] = [1]
        self.assert_rejected(manifest, "contiguous suffix")
        manifest = post_rebase()
        manifest["layers"][1]["local_head"] = "b"
        self.assert_rejected(manifest, "did not rebase locally")

    def test_rejects_remote_movement_during_local_recovery(self) -> None:
        manifest = post_rebase()
        manifest["layers"][1]["remote_head"] = "moved"
        manifest["layers"][1]["pr_head"] = "moved"
        manifest["layers"][1]["lease_head"] = "moved"
        self.assert_rejected(manifest, "moved remotely")

    def test_rejects_manual_rebase_and_direct_push_fallbacks(self) -> None:
        manifest = hold()
        manifest["forbidden_operations"]["manual_rebase"] = True
        manifest["forbidden_operations"]["direct_push"] = True
        self.assert_rejected(manifest, "forbids manual_rebase")
        self.assert_rejected(manifest, "forbids direct_push")

    def test_rejects_hold_that_claims_a_recovery(self) -> None:
        manifest = hold()
        manifest["recovery_command"] = "gh stack rebase --upstack --no-trunk"
        manifest["boundaries"] = boundaries()
        self.assert_rejected(manifest, "permits no recovery command")
        self.assert_rejected(manifest, "must not claim")


if __name__ == "__main__":
    unittest.main()
