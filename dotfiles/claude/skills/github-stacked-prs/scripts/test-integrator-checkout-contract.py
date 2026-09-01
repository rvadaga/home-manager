#!/usr/bin/env python3
"""exercise the recorded safety rules for an integrator checkout."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


script_path = Path(__file__).with_name("check-integrator-checkout-contract.py")
script_spec = importlib.util.spec_from_file_location("integrator_checkout_contract", script_path)
assert script_spec is not None and script_spec.loader is not None
contract = importlib.util.module_from_spec(script_spec)
script_spec.loader.exec_module(contract)


def linked_worktree() -> dict[str, object]:
    return {
        "checkout_kind": "linked_worktree",
        "exact_refs": ["refs/heads/main", "refs/heads/layer-a"],
        "trusted_primary": {
            "selected_remote_verified": True,
            "complete_objects": True,
            "lfs_hook_installed": True,
            "promisor": False,
            "partial_clone_filter": False,
        },
        "hydration": {
            "required": True,
            "attempted": True,
            "destination": "primary_object_store",
            "narrow_exact_refs": True,
            "promisor_checkout": False,
            "missing_objects_after": False,
            "lfs_objects_complete": True,
        },
        "linked_worktree": {
            "detached": True,
            "shares_primary_object_store": True,
            "clean": True,
            "complete_objects": True,
            "lfs_objects_complete": True,
        },
        "publication_command": "gh stack push",
        "direct_push": False,
        "hooks_disabled": False,
        "lfs_skipped": False,
    }


def full_clone_exception() -> dict[str, object]:
    manifest = linked_worktree()
    manifest["checkout_kind"] = "full_clone_exception"
    manifest.pop("linked_worktree")
    manifest["full_clone_exception"] = {
        "reason": "the verified linked checkout cannot materialize a required object",
        "linked_worktree_attempted": True,
        "narrow_hydration_attempted": True,
        "linked_checkout_inadequate": True,
    }
    return manifest


class integrator_checkout_contract_test(unittest.TestCase):
    def assert_rejected(self, manifest: dict[str, object], fragment: str) -> None:
        self.assertTrue(any(fragment in error for error in contract.validate(manifest)), contract.validate(manifest))

    def test_accepts_detached_linked_worktree_with_exact_ref_hydration(self) -> None:
        self.assertEqual([], contract.validate(linked_worktree()))

    def test_accepts_recorded_full_clone_exception_only_after_the_linked_path(self) -> None:
        self.assertEqual([], contract.validate(full_clone_exception()))

    def test_rejects_unjustified_full_clone(self) -> None:
        manifest = linked_worktree()
        manifest["checkout_kind"] = "full_clone_exception"
        manifest.pop("linked_worktree")
        self.assert_rejected(manifest, "exception record")

    def test_rejects_broad_fetch_or_promisor_checkout(self) -> None:
        manifest = linked_worktree()
        manifest["exact_refs"] = ["refs/heads/main", "refs/heads/*"]
        manifest["hydration"]["narrow_exact_refs"] = False
        manifest["hydration"]["promisor_checkout"] = True
        self.assert_rejected(manifest, "exact branch refs")
        self.assert_rejected(manifest, "narrow exact refs")
        self.assert_rejected(manifest, "promisor checkout")

    def test_rejects_promisor_primary_or_missing_objects(self) -> None:
        manifest = linked_worktree()
        manifest["trusted_primary"]["promisor"] = True
        manifest["hydration"]["missing_objects_after"] = True
        manifest["linked_worktree"]["complete_objects"] = False
        self.assert_rejected(manifest, "must not be a promisor")
        self.assert_rejected(manifest, "no missing objects")
        self.assert_rejected(manifest, "requires complete_objects")

    def test_rejects_lfs_or_hook_bypass(self) -> None:
        manifest = linked_worktree()
        manifest["trusted_primary"]["lfs_hook_installed"] = False
        manifest["hooks_disabled"] = True
        manifest["lfs_skipped"] = True
        self.assert_rejected(manifest, "lfs_hook_installed")
        self.assert_rejected(manifest, "disabled hooks")
        self.assert_rejected(manifest, "skipping git lfs")

    def test_rejects_direct_push(self) -> None:
        manifest = linked_worktree()
        manifest["publication_command"] = "git push origin layer-a"
        manifest["direct_push"] = True
        self.assert_rejected(manifest, "only gh stack push")
        self.assert_rejected(manifest, "forbids direct push")


if __name__ == "__main__":
    unittest.main()
