#!/usr/bin/env python3
"""check the evidence for an official partial stack recovery decision."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


boundary_sources = {"current_parent", "recorded_base", "fork_point"}
forbidden_operations = {
    "direct_push",
    "init",
    "link",
    "manual_rebase",
    "metadata_edit",
    "publication",
    "sync",
    "unstack_local",
}


def string(item: dict[str, Any], key: str) -> str | None:
    value = item.get(key)
    return value if isinstance(value, str) and value else None


def indexes(manifest: dict[str, Any], layer_count: int) -> tuple[list[int], list[str]]:
    affected = manifest.get("affected_indices")
    if not isinstance(affected, list) or not affected or not all(isinstance(index, int) for index in affected):
        return [], ["affected_indices must be a nonempty integer list"]
    if affected != sorted(set(affected)):
        return affected, ["affected_indices must be sorted and unique"]
    if affected[0] <= 0 or affected[-1] >= layer_count:
        return affected, ["affected_indices must name a child suffix"]
    if affected != list(range(affected[0], layer_count)):
        return affected, ["affected_indices must be one contiguous suffix"]
    return affected, []


def common_errors(manifest: dict[str, Any], layers: list[dict[str, Any]]) -> list[str]:
    errors = []
    if not isinstance(manifest.get("preflight_snapshot_id"), str) or not manifest["preflight_snapshot_id"]:
        errors.append("recovery requires one nonempty preflight_snapshot_id")
    for key in (
        "integrator_clean",
        "server_prefix_patch_identity",
        "trunk_local_matches_remote",
        "trunk_live_matches_remote",
        "all_pr_states_recorded",
        "all_pr_states_unchanged",
    ):
        if manifest.get(key) is not True:
            errors.append(f"recovery requires {key}")
    if manifest.get("history_operation") != "none":
        errors.append("recovery requires no active history operation")
    if manifest.get("unexpected_remote_movement") is not False:
        errors.append("recovery requires no unexpected remote movement")
    if manifest.get("metadata_rebuild") is not False:
        errors.append("recovery never permits metadata_rebuild")
    operations = manifest.get("forbidden_operations")
    if not isinstance(operations, dict):
        errors.append("recovery requires forbidden_operations")
    else:
        for operation in sorted(forbidden_operations):
            if operations.get(operation) is not False:
                errors.append(f"recovery forbids {operation}")
    for index, layer in enumerate(layers):
        for key in ("name", "local_head", "remote_head", "pr_head", "lease_head", "base_ref", "state", "expected_state"):
            if string(layer, key) is None:
                errors.append(f"layer {index} is missing {key}")
        if string(layer, "state") not in {"draft", "ready"}:
            errors.append(f"layer {index} has an invalid state")
        if string(layer, "state") != string(layer, "expected_state"):
            errors.append(f"layer {index} changed pull request state")
        if string(layer, "remote_head") != string(layer, "pr_head") or string(layer, "remote_head") != string(layer, "lease_head"):
            errors.append(f"layer {index} does not match its remote lease and pull request head")
    return errors


def boundary_errors(manifest: dict[str, Any], affected: list[int]) -> list[str]:
    entries = manifest.get("boundaries")
    if not isinstance(entries, list) or len(entries) != len(affected) or not all(isinstance(entry, dict) for entry in entries):
        return ["recovery requires one boundary for every affected child"]
    errors = []
    for child_index, entry in zip(affected, entries, strict=True):
        if entry.get("child_index") != child_index or entry.get("parent_index") != child_index - 1:
            errors.append(f"boundary for layer {child_index} has the wrong parent")
        for key in ("recorded_base", "view_base", "candidate"):
            if string(entry, key) is None:
                errors.append(f"boundary for layer {child_index} is missing {key}")
        if string(entry, "recorded_base") != string(entry, "view_base"):
            errors.append(f"boundary for layer {child_index} does not match gh stack view")
        if entry.get("source") not in boundary_sources:
            errors.append(f"boundary for layer {child_index} has an invalid source")
        if entry.get("candidate_is_child_ancestor") is not True:
            errors.append(f"boundary for layer {child_index} is not proved as a child ancestor")
    return errors


def preflight_errors(manifest: dict[str, Any], layers: list[dict[str, Any]], affected: list[int]) -> list[str]:
    errors = boundary_errors(manifest, affected)
    if manifest.get("recovery_command") != "gh stack rebase --upstack --no-trunk":
        errors.append("supported recovery permits only gh stack rebase --upstack --no-trunk")
    for index, layer in enumerate(layers):
        if string(layer, "local_head") != string(layer, "remote_head"):
            errors.append(f"layer {index} changed before the recovery")
    return errors


def post_rebase_errors(manifest: dict[str, Any], layers: list[dict[str, Any]], affected: list[int]) -> list[str]:
    errors = boundary_errors(manifest, affected)
    if manifest.get("recovery_command") != "gh stack rebase --upstack --no-trunk":
        errors.append("post-rebase requires the official scoped rebase command")
    for index, layer in enumerate(layers):
        before = string(layer, "preflight_local_head")
        if before is None:
            errors.append(f"layer {index} is missing preflight_local_head")
        if string(layer, "remote_head") != before or string(layer, "pr_head") != before:
            errors.append(f"layer {index} moved remotely during local recovery")
        if index in affected:
            if string(layer, "local_head") == before:
                errors.append(f"affected layer {index} did not rebase locally")
        elif string(layer, "local_head") != before:
            errors.append(f"unaffected layer {index} changed locally")
    validation = manifest.get("validation")
    if not isinstance(validation, dict):
        errors.append("post-rebase requires validation")
    else:
        if validation.get("affected_layers") is not True:
            errors.append("post-rebase requires affected-layer validation")
        if validation.get("cumulative_stack") is not True:
            errors.append("post-rebase requires cumulative stack validation")
    post_bases = manifest.get("post_view_bases")
    if not isinstance(post_bases, list) or len(post_bases) != len(affected) or not all(isinstance(entry, dict) for entry in post_bases):
        return errors + ["post-rebase requires one refreshed view base for every affected child"]
    for child_index, entry in zip(affected, post_bases, strict=True):
        if entry.get("child_index") != child_index or string(entry, "view_base") != string(entry, "parent_head"):
            errors.append(f"post-rebase view base for layer {child_index} does not equal its parent")
    return errors


def hold_errors(manifest: dict[str, Any], affected: list[int]) -> list[str]:
    errors = []
    if manifest.get("recovery_command") != "none":
        errors.append("a recovery hold permits no recovery command")
    if not isinstance(manifest.get("hold_reason"), str) or not manifest["hold_reason"]:
        errors.append("a recovery hold requires hold_reason")
    if manifest.get("boundaries") not in (None, []):
        errors.append("a recovery hold must not claim a proved boundary")
    if affected:
        errors.append("a recovery hold must not name an affected suffix")
    return errors


def validate(manifest: dict[str, Any]) -> list[str]:
    phase = manifest.get("phase")
    if phase not in {"preflight", "post-rebase", "hold"}:
        return ["phase must be preflight, post-rebase, or hold"]
    layers = manifest.get("layers")
    if not isinstance(layers, list) or not layers or not all(isinstance(layer, dict) for layer in layers):
        return ["layers must be a nonempty object list"]
    errors = common_errors(manifest, layers)
    affected, index_errors = indexes(manifest, len(layers)) if phase != "hold" else ([], [])
    errors.extend(index_errors)
    if errors:
        return errors
    if phase == "preflight":
        return preflight_errors(manifest, layers, affected)
    if phase == "post-rebase":
        return post_rebase_errors(manifest, layers, affected)
    return hold_errors(manifest, affected)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check-partial-stack-recovery-contract.py <manifest.json>", file=sys.stderr)
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
    print(f"partial stack recovery {manifest['phase']} contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
