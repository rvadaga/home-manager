#!/usr/bin/env python3
"""check the recorded safety facts for a stack integrator checkout."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


exact_ref_pattern = re.compile(r"refs/heads/[a-z0-9][a-z0-9._/-]*$")


def nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value)


def exact_refs(manifest: dict[str, Any]) -> list[str]:
    refs = manifest.get("exact_refs")
    if not isinstance(refs, list) or len(refs) < 2 or not all(isinstance(ref, str) for ref in refs):
        return ["checkout requires exact_refs for trunk and stack refs"]
    if len(refs) != len(set(refs)):
        return ["exact_refs must be unique"]
    if not all(exact_ref_pattern.fullmatch(ref) for ref in refs):
        return ["exact_refs must contain only exact branch refs"]
    return []


def primary_errors(manifest: dict[str, Any]) -> list[str]:
    primary = manifest.get("trusted_primary")
    if not isinstance(primary, dict):
        return ["checkout requires trusted_primary"]
    errors = []
    for key in ("selected_remote_verified", "complete_objects", "lfs_hook_installed"):
        if primary.get(key) is not True:
            errors.append(f"trusted_primary requires {key}")
    if primary.get("promisor") is not False:
        errors.append("trusted_primary must not be a promisor checkout")
    if primary.get("partial_clone_filter") is not False:
        errors.append("trusted_primary must not have a partial-clone filter")
    return errors


def hydration_errors(manifest: dict[str, Any]) -> list[str]:
    hydration = manifest.get("hydration")
    if not isinstance(hydration, dict):
        return ["checkout requires hydration"]
    errors = []
    if hydration.get("destination") != "primary_object_store":
        errors.append("hydration must target the primary object store")
    if hydration.get("narrow_exact_refs") is not True:
        errors.append("hydration requires narrow exact refs")
    if hydration.get("promisor_checkout") is not False:
        errors.append("hydration must not use a promisor checkout")
    if hydration.get("missing_objects_after") is not False:
        errors.append("hydration must leave no missing objects")
    if hydration.get("lfs_objects_complete") is not True:
        errors.append("hydration requires complete git lfs objects")
    if hydration.get("required") is True and hydration.get("attempted") is not True:
        errors.append("required hydration must be attempted")
    if hydration.get("required") not in {True, False}:
        errors.append("hydration must record whether it was required")
    return errors


def common_errors(manifest: dict[str, Any]) -> list[str]:
    errors = exact_refs(manifest)
    errors.extend(primary_errors(manifest))
    errors.extend(hydration_errors(manifest))
    if manifest.get("publication_command") != "gh stack push":
        errors.append("checkout permits only gh stack push")
    if manifest.get("direct_push") is not False:
        errors.append("checkout forbids direct push")
    if manifest.get("hooks_disabled") is not False:
        errors.append("checkout forbids disabled hooks")
    if manifest.get("lfs_skipped") is not False:
        errors.append("checkout forbids skipping git lfs")
    return errors


def linked_worktree_errors(manifest: dict[str, Any]) -> list[str]:
    linked = manifest.get("linked_worktree")
    if not isinstance(linked, dict):
        return ["linked_worktree checkout requires linked_worktree"]
    errors = []
    for key in ("detached", "shares_primary_object_store", "clean", "complete_objects", "lfs_objects_complete"):
        if linked.get(key) is not True:
            errors.append(f"linked_worktree requires {key}")
    if manifest.get("full_clone_exception") is not None:
        errors.append("linked_worktree checkout must not record a full clone exception")
    return errors


def full_clone_exception_errors(manifest: dict[str, Any]) -> list[str]:
    exception = manifest.get("full_clone_exception")
    if not isinstance(exception, dict):
        return ["full_clone_exception checkout requires an exception record"]
    errors = []
    if not nonempty_string(exception.get("reason")):
        errors.append("full clone exception requires a concrete reason")
    for key in ("linked_worktree_attempted", "narrow_hydration_attempted", "linked_checkout_inadequate"):
        if exception.get(key) is not True:
            errors.append(f"full clone exception requires {key}")
    return errors


def validate(manifest: dict[str, Any]) -> list[str]:
    errors = common_errors(manifest)
    checkout_kind = manifest.get("checkout_kind")
    if checkout_kind == "linked_worktree":
        errors.extend(linked_worktree_errors(manifest))
    elif checkout_kind == "full_clone_exception":
        errors.extend(full_clone_exception_errors(manifest))
    else:
        errors.append("checkout_kind must be linked_worktree or full_clone_exception")
    return errors


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check-integrator-checkout-contract.py <manifest.json>", file=sys.stderr)
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
    print(f"integrator checkout {manifest['checkout_kind']} contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
