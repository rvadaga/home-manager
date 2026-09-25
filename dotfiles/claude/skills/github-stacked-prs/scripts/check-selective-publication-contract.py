#!/usr/bin/env python3
"""check the structural evidence for a selective stack publication attempt."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


required_preflight_checks = {
    "changed_tests",
    "changed_hooks",
    "diff",
    "markers",
    "linear_topology",
    "leases_and_states",
}


def value(layer: dict[str, Any], key: str) -> str | None:
    item = layer.get(key)
    return item if isinstance(item, str) and item else None


def layer_errors(layer: dict[str, Any], index: int) -> list[str]:
    errors = []
    for key in ("branch", "local_head", "remote_head", "pr_head", "lease_head", "base_ref", "expected_base_ref", "state", "expected_state"):
        if value(layer, key) is None:
            errors.append(f"layer {index} is missing {key}")
    if value(layer, "state") not in {"draft", "ready"}:
        errors.append(f"layer {index} has an invalid state")
    if value(layer, "state") != value(layer, "expected_state"):
        errors.append(f"layer {index} changed pull request state")
    if value(layer, "base_ref") != value(layer, "expected_base_ref"):
        errors.append(f"layer {index} changed pull request base reference")
    return errors


def changed_indexes(manifest: dict[str, Any], layer_count: int) -> tuple[list[int], list[str]]:
    indexes = manifest.get("changed_indices")
    if not isinstance(indexes, list) or not indexes or not all(type(index) is int for index in indexes):
        return [], ["changed_indices must be a nonempty integer list"]
    if indexes != sorted(set(indexes)):
        return indexes, ["changed_indices must be sorted and unique"]
    if indexes[0] < 0 or indexes[-1] >= layer_count:
        return indexes, ["changed_indices is outside layers"]
    if indexes != list(range(indexes[0], indexes[-1] + 1)):
        return indexes, ["changed_indices must be contiguous"]
    return indexes, []


def preflight_errors(manifest: dict[str, Any], layers: list[dict[str, Any]], indexes: list[int]) -> list[str]:
    errors = []
    if not isinstance(manifest.get("preflight_snapshot_id"), str) or not manifest["preflight_snapshot_id"]:
        errors.append("preflight requires one nonempty preflight_snapshot_id")
    if manifest.get("pre_push_readback") is not True:
        errors.append("preflight requires the immediate pre-push readback")
    if manifest.get("restack_ran") is not False:
        errors.append("selective publication requires restack_ran to be false")
    if manifest.get("unexpected_remote_movement") is not False:
        errors.append("selective publication requires no unexpected remote movement")
    for field in ("default_branch_sync", "conflict", "handoffs_adopted"):
        if manifest.get(field) is not False:
            errors.append(f"selective publication requires {field} to be false")
    for field in ("semantic_propagation", "pending_handoffs"):
        if type(manifest.get(field)) is not bool:
            errors.append(f"selective publication requires boolean {field}")
    if manifest.get("integrator_clean") is not True:
        errors.append("selective publication requires a clean integrator")
    if manifest.get("publication_command") != "gh stack push":
        errors.append("selective publication permits only gh stack push")
    checks = manifest.get("checks")
    if not isinstance(checks, dict):
        errors.append("preflight requires checks")
    else:
        for check in sorted(required_preflight_checks):
            if checks.get(check) is not True:
                errors.append(f"preflight requires {check}")
    for index, layer in enumerate(layers):
        remote = value(layer, "remote_head")
        pr = value(layer, "pr_head")
        lease = value(layer, "lease_head")
        local = value(layer, "local_head")
        if remote != pr or remote != lease:
            errors.append(f"layer {index} does not match its remote lease and pull request head")
        if index in indexes:
            if local == remote:
                errors.append(f"changed layer {index} has no unpublished local head")
        elif local != remote:
            errors.append(f"untouched layer {index} is not at its exact lease")
    errors.extend(deferred_errors(manifest, len(layers), indexes))
    return errors


def deferred_errors(manifest: dict[str, Any], layer_count: int, indexes: list[int]) -> list[str]:
    first = indexes[-1] + 1
    deferred = manifest.get("deferred_restack")
    if first == layer_count:
        if deferred is not None or manifest.get("semantic_propagation") or manifest.get("pending_handoffs"):
            return ["deferred work requires untouched descendants"]
        return []
    if not isinstance(deferred, dict):
        return ["untouched descendants require deferred_restack"]
    errors = []
    if deferred.get("first_descendant") != first or value(deferred, "reason") is None:
        errors.append("deferred_restack must name the first descendant and a reason")
    if deferred.get("validation_status") != "not_validated_against_selected_heads":
        errors.append("descendants must remain unvalidated against selected heads")
    work = deferred.get("work")
    if not isinstance(work, list) or not all(isinstance(item, dict) for item in work):
        return errors + ["deferred_restack requires a work object list"]
    kinds = set()
    for item in work:
        kind = item.get("kind")
        if kind not in ("migration", "handoff", "validation"):
            errors.append("invalid deferred work kind")
            continue
        kinds.add(kind)
        affected = item.get("layer_indices")
        if (not isinstance(affected, list) or not affected
                or not all(type(i) is int and first <= i < layer_count for i in affected)):
            errors.append("deferred work must name untouched descendant indexes")
        if item.get("required_for_selected") is not False:
            errors.append("work required for selected behavior cannot be deferred")
        if value(item, "remaining_work") is None:
            errors.append("deferred work must name remaining_work")
        checks = item.get("required_checks")
        if not isinstance(checks, list) or not checks or not all(isinstance(c, str) and c.strip() for c in checks):
            errors.append("deferred work must name required_checks")
        if kind == "handoff" and (value(item, "commit") is None or value(item, "base") is None):
            errors.append("deferred handoff requires its immutable commit and base")
    for flag, kind in (("semantic_propagation", "migration"), ("pending_handoffs", "handoff")):
        if manifest.get(flag) != (kind in kinds):
            errors.append(f"{flag} must match a named deferred {kind}")
    return errors


def post_push_errors(manifest: dict[str, Any], snapshot: dict[str, Any]) -> list[str]:
    errors = []
    for key in ("preflight_snapshot_id", "changed_indices", "deferred_restack"):
        if manifest.get(key) != snapshot.get(key):
            errors.append(f"post-push changed saved {key}")
    layers, before = manifest["layers"], snapshot["layers"]
    if len(layers) != len(before):
        return errors + ["post-push must read every saved layer"]
    indexes = snapshot["changed_indices"]
    for index, (layer, saved) in enumerate(zip(layers, before)):
        for key in ("branch", "local_head", "lease_head", "base_ref", "expected_base_ref", "state", "expected_state"):
            if layer.get(key) != saved.get(key):
                errors.append(f"layer {index} changed saved {key}")
        expected = saved["local_head"] if index in indexes else saved["lease_head"]
        if layer["remote_head"] != expected or layer["pr_head"] != expected:
            errors.append(f"layer {index} did not preserve its expected published head")
    return errors


def validate(manifest: dict[str, Any], snapshot: dict[str, Any] | None = None) -> list[str]:
    phase = manifest.get("phase")
    if phase not in {"preflight", "post-push"}:
        return ["phase must be preflight or post-push"]
    layers = manifest.get("layers")
    if not isinstance(layers, list) or not layers or not all(isinstance(layer, dict) for layer in layers):
        return ["layers must be a nonempty object list"]
    errors = []
    for index, layer in enumerate(layers):
        errors.extend(layer_errors(layer, index))
    branches = [value(layer, "branch") for layer in layers]
    if len(set(branches)) != len(branches):
        errors.append("layers must name unique branches")
    indexes, index_errors = changed_indexes(manifest, len(layers))
    errors.extend(index_errors)
    if errors:
        return errors
    if phase == "preflight":
        return preflight_errors(manifest, layers, indexes)
    if not isinstance(snapshot, dict) or snapshot.get("phase") != "preflight":
        return ["post-push requires the original preflight manifest"]
    snapshot_errors = validate(snapshot)
    if snapshot_errors:
        return ["invalid saved preflight: " + error for error in snapshot_errors]
    return post_push_errors(manifest, snapshot)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--preflight", type=Path)
    args = parser.parse_args(argv[1:])
    try:
        manifest = json.loads(args.manifest.read_text())
        snapshot = json.loads(args.preflight.read_text()) if args.preflight else None
    except (OSError, json.JSONDecodeError) as error:
        print(f"cannot read manifest: {error}", file=sys.stderr)
        return 2
    if not isinstance(manifest, dict):
        print("manifest must be a json object", file=sys.stderr)
        return 2
    errors = validate(manifest, snapshot)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f"selective publication {manifest['phase']} manifest is consistent; retain independent command and lease evidence")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
