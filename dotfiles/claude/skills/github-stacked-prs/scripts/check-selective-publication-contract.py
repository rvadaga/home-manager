#!/usr/bin/env python3
"""check the structural evidence for a selective stack publication attempt."""

from __future__ import annotations

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
    for key in ("local_head", "remote_head", "pr_head", "lease_head", "base_ref", "state", "expected_state"):
        if value(layer, key) is None:
            errors.append(f"layer {index} is missing {key}")
    if value(layer, "state") not in {"draft", "ready"}:
        errors.append(f"layer {index} has an invalid state")
    return errors


def changed_indexes(manifest: dict[str, Any], layer_count: int) -> tuple[list[int], list[str]]:
    indexes = manifest.get("changed_indices")
    if not isinstance(indexes, list) or not indexes or not all(isinstance(index, int) for index in indexes):
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
    if manifest.get("semantic_propagation") is not False:
        errors.append("semantic propagation requires a complete restack")
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
    first_descendant = indexes[-1] + 1
    descendants = list(range(first_descendant, len(layers)))
    deferred = manifest.get("deferred_restack")
    if descendants:
        if not isinstance(deferred, dict):
            errors.append("untouched descendants require deferred_restack")
        elif deferred.get("first_descendant") != first_descendant or not isinstance(deferred.get("reason"), str) or not deferred["reason"]:
            errors.append("deferred_restack must name the first descendant and a reason")
    elif deferred is not None:
        errors.append("deferred_restack is only valid when untouched descendants remain")
    return errors


def post_push_errors(layers: list[dict[str, Any]], indexes: list[int]) -> list[str]:
    errors = []
    for index, layer in enumerate(layers):
        local = value(layer, "local_head")
        remote = value(layer, "remote_head")
        pr = value(layer, "pr_head")
        lease = value(layer, "lease_head")
        if value(layer, "state") != value(layer, "expected_state"):
            errors.append(f"layer {index} changed pull request state")
        if value(layer, "base_ref") != value(layer, "expected_base_ref"):
            errors.append(f"layer {index} changed pull request base reference")
        if index in indexes:
            if remote != local or pr != local:
                errors.append(f"changed layer {index} did not publish its local head")
        elif remote != lease or pr != lease:
            errors.append(f"untouched layer {index} moved from its lease")
    return errors


def validate(manifest: dict[str, Any]) -> list[str]:
    phase = manifest.get("phase")
    if phase not in {"preflight", "post-push"}:
        return ["phase must be preflight or post-push"]
    layers = manifest.get("layers")
    if not isinstance(layers, list) or not layers or not all(isinstance(layer, dict) for layer in layers):
        return ["layers must be a nonempty object list"]
    errors = []
    for index, layer in enumerate(layers):
        errors.extend(layer_errors(layer, index))
    indexes, index_errors = changed_indexes(manifest, len(layers))
    errors.extend(index_errors)
    if errors:
        return errors
    if phase == "preflight":
        return preflight_errors(manifest, layers, indexes)
    if not isinstance(manifest.get("preflight_snapshot_id"), str) or not manifest["preflight_snapshot_id"]:
        return ["post-push requires the preflight_snapshot_id"]
    return post_push_errors(layers, indexes)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check-selective-publication-contract.py <manifest.json>", file=sys.stderr)
        return 2
    try:
        manifest = json.loads(Path(argv[1]).read_text())
    except (OSError, json.JSONDecodeError) as error:
        print(f"cannot read manifest: {error}", file=sys.stderr)
        return 2
    if not isinstance(manifest, dict):
        print("manifest must be a json object", file=sys.stderr)
        return 2
    errors = validate(manifest)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f"selective publication {manifest['phase']} contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
