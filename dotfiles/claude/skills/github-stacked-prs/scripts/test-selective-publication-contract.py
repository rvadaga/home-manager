#!/usr/bin/env python3
"""exercise selected delivery, deferred work and immutable readback boundaries."""

from __future__ import annotations

import copy
import importlib.util
import unittest
from pathlib import Path


script_path = Path(__file__).with_name("check-selective-publication-contract.py")
spec = importlib.util.spec_from_file_location("selective_publication_contract", script_path)
assert spec is not None and spec.loader is not None
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)


def layer(name: str, local: str, remote: str, base: str) -> dict[str, str]:
    return dict(branch=name, local_head=local, remote_head=remote, pr_head=remote,
                lease_head=remote, base_ref=base, expected_base_ref=base,
                state="draft", expected_state="draft")


def preflight() -> dict:
    return {
        "phase": "preflight", "preflight_snapshot_id": "attempt-one",
        "pre_push_readback": True, "restack_ran": False,
        "default_branch_sync": False, "conflict": False, "handoffs_adopted": False,
        "unexpected_remote_movement": False, "semantic_propagation": False,
        "pending_handoffs": False, "integrator_clean": True,
        "publication_command": "gh stack push",
        "checks": {key: True for key in contract.required_preflight_checks},
        "changed_indices": [1],
        "layers": [layer("one", "a", "a", "trunk"),
                   layer("two", "b-local", "b", "one"),
                   layer("three", "c", "c", "two")],
        "deferred_restack": {"first_descendant": 2, "reason": "child rebase remains",
                             "validation_status": "not_validated_against_selected_heads", "work": []},
    }


def post_push(before: dict) -> dict:
    result = copy.deepcopy(before)
    result["phase"] = "post-push"
    for index in before["changed_indices"]:
        item = result["layers"][index]
        item["remote_head"] = item["pr_head"] = item["local_head"]
    return result


def deferred(kind: str) -> dict:
    return dict(kind=kind, layer_indices=[2], remaining_work="update child callers",
                required_checks=["child compilation", "combined behavior tests"],
                required_for_selected=False, commit="handoff-commit", base="handoff-base")


class selective_publication_test(unittest.TestCase):
    def rejected(self, manifest: dict, fragment: str, before: dict | None = None) -> None:
        errors = contract.validate(manifest, before)
        self.assertTrue(any(fragment in error for error in errors), errors)

    def accepted(self, before: dict) -> None:
        self.assertEqual([], contract.validate(before))
        self.assertEqual([], contract.validate(post_push(before), before))

    def test_selected_layer_and_contiguous_subseries(self):
        self.accepted(preflight())
        before = preflight()
        before["changed_indices"] = [0, 1]
        before["layers"][0]["local_head"] = "a-local"
        self.accepted(before)

    def test_explicit_migration_and_handoff_deferral(self):
        for kinds in (("migration",), ("handoff",), ("migration", "handoff")):
            with self.subTest(kinds=kinds):
                before = preflight()
                before["semantic_propagation"] = "migration" in kinds
                before["pending_handoffs"] = "handoff" in kinds
                before["deferred_restack"]["work"] = [deferred(kind) for kind in kinds]
                self.accepted(before)

    def test_ready_state_preserved(self):
        before = preflight()
        before["layers"][1].update(state="ready", expected_state="ready")
        self.accepted(before)

    def test_top_selection_has_no_deferred_descendants(self):
        before = preflight()
        before["changed_indices"] = [2]
        before["layers"][1]["local_head"] = "b"
        before["layers"][2]["local_head"] = "c-local"
        before.pop("deferred_restack")
        self.accepted(before)

    def test_undeclared_deferral_and_incomplete_selected_work(self):
        for field in ("semantic_propagation", "pending_handoffs"):
            before = preflight(); before[field] = True
            self.rejected(before, "must match a named deferred")
        before["deferred_restack"]["work"] = [deferred("handoff")]
        before["deferred_restack"]["work"][0]["required_for_selected"] = True
        self.rejected(before, "selected behavior cannot be deferred")

    def test_missing_handoff_identity_checks_or_descendant_scope(self):
        for field in ("commit", "base", "required_checks", "remaining_work"):
            before = preflight(); before["pending_handoffs"] = True
            item = deferred("handoff"); item.pop(field)
            before["deferred_restack"]["work"] = [item]
            self.rejected(before, "requires" if field in ("commit", "base") else "must name")
        item["layer_indices"] = [1]
        self.rejected(before, "untouched descendant indexes")

    def test_no_full_stack_validation_claim(self):
        before = preflight()
        before["deferred_restack"]["validation_status"] = "passed"
        self.rejected(before, "unvalidated")

    def test_preflight_stops(self):
        for field in ("restack_ran", "default_branch_sync", "conflict", "handoffs_adopted", "unexpected_remote_movement"):
            before = preflight(); before[field] = True
            self.rejected(before, "requires")
        for check in contract.required_preflight_checks:
            before = preflight(); before["checks"][check] = False
            self.rejected(before, check)
        for field in ("integrator_clean", "pre_push_readback"):
            before = preflight(); before[field] = False
            self.rejected(before, "requires")
        before = preflight(); before["publication_command"] = "git push origin two"
        self.rejected(before, "only gh stack push")

    def test_noncontiguous_or_invalid_selection(self):
        for indexes in ([0, 2], [True], [1, 1], [], [-1], [3]):
            before = preflight(); before["changed_indices"] = indexes
            self.rejected(before, "changed_indices")

    def test_preflight_movement_or_missing_expectations(self):
        for key in ("local_head", "remote_head", "pr_head", "lease_head", "base_ref", "state"):
            before = preflight(); before["layers"][2][key] = "moved"
            self.rejected(before, "layer 2")
        before = preflight(); before["layers"][1].pop("expected_base_ref")
        self.rejected(before, "missing expected_base_ref")
        before = preflight(); before.pop("deferred_restack")
        self.rejected(before, "deferred_restack")

    def test_post_requires_original_snapshot(self):
        before = preflight()
        self.rejected(post_push(before), "original preflight")
        after = post_push(before); after["preflight_snapshot_id"] = "different"
        self.rejected(after, "saved preflight_snapshot_id", before)

    def test_post_rejects_changed_saved_facts_and_rewritten_expectations(self):
        before = preflight()
        for index in range(3):
            for key in ("branch", "local_head", "remote_head", "pr_head", "lease_head", "base_ref", "expected_base_ref", "state", "expected_state"):
                with self.subTest(index=index, key=key):
                    after = post_push(before); after["layers"][index][key] = "moved"
                    self.rejected(after, "layer", before)
        after = post_push(before)
        after["layers"][2].update(local_head="moved", remote_head="moved", pr_head="moved", lease_head="moved")
        self.rejected(after, "saved lease_head", before)
        after = post_push(before); after["layers"][2].update(state="ready", expected_state="ready")
        self.rejected(after, "saved state", before)

    def test_post_requires_all_layers_and_unchanged_deferred_record(self):
        before = preflight(); after = post_push(before)
        after["layers"].pop()
        self.rejected(after, "every saved layer", before)
        after = post_push(before); after["deferred_restack"]["work"] = [deferred("migration")]
        self.rejected(after, "saved deferred_restack", before)


if __name__ == "__main__":
    unittest.main()
