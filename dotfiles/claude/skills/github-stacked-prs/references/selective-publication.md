# selective publication

use this path to prioritize one coherent, tested changed layer or one contiguous changed subseries in a live draft stack. it is distinct from a complete restack: it moves only the selected local heads and deliberately leaves untouched descendants at their recorded remote heads.

## admit the selective path

use it only when all of these facts come from one current live read:

- no restack has run in this attempt;
- the selected changed layer indexes are contiguous;
- every selected layer has a local head that differs from its recorded remote lease and pull request head;
- every untouched descendant has the same local head, remote head, pull request head, and recorded lease;
- every layer has a recorded pull request base reference and draft or ready state;
- no remote head, pull request head, base reference, or state has moved unexpectedly; and
- the selected patches do not semantically require a descendant change.

reject this path for a default-branch sync, a conflict, noncontiguous selected changes, a restack already run, missing or stale leases, unexpected state movement, a pending handoff that must be adopted, or a semantic change that must propagate. use the complete-restack path instead. do not simulate a selective path with a partial rebase.

record these facts in a json manifest backed by the live reads. run:

```sh
python3 scripts/check-selective-publication-contract.py preflight.json
```

the checker proves the manifest is internally consistent. it never substitutes for the live reads, review, or command output retained with the attempt.

## prepare the selected subseries

use the normal complete-object linked integrator checkout from [preparation and publication](preparation-and-publication.md). retain its trusted-primary, exact-ref hydration, promisor, partial-clone, trunk, lfs, hook, linear-history, and exact-resource-lock safeguards. keep its porcelain clean.

run the selected layer or subseries tests and hooks. before publication, perform a diff check, exact conflict-marker review, and linear-history and topology checks that cover the selected range and show that unchanged refs can remain in place. independently read every recorded lease and pull request state immediately before the official command; they must equal the one preflight snapshot.

the untouched descendants do not need a rebase, new tests, hooks, or pending-handoff adoption during this pass. record each as deferred restack work, including its exact lease and the first untouched descendant that now needs rebase. this deferral is expected, not a publication failure.

## publish and read back

use only `gh stack push`. version 0.1.0 has no single-branch publication flag, and its printed branch count can be broader than the refs that moved. do not infer success from that count, and never direct-push a managed stack ref.

after the command, create a post-push manifest from fresh remote and pull request reads and run:

```sh
python3 scripts/check-selective-publication-contract.py post-push.json
```

the post-push manifest must prove all of these facts:

- every changed remote and pull request head equals its selected local head;
- every untouched descendant remote and pull request head still equals its exact recorded lease;
- every pull request draft or ready state remains unchanged; and
- every pull request base reference remains unchanged.

report the first untouched descendant as needing rebase and retain the deferred restack record. measure preparation through the instant before `gh stack push`, then measure the command itself separately. the later restack performs the complete per-layer and cumulative validation; selective publication never claims to have satisfied that later gate.

## manifest fields

the checker accepts `phase` as `preflight` or `post-push`, a `layers` array in parent-to-child order, and `changed_indices`. each layer records `local_head`, `remote_head`, `pr_head`, `lease_head`, `base_ref`, `state`, and `expected_state`. the preflight manifest also records one nonempty `preflight_snapshot_id`, `pre_push_readback`, `restack_ran`, `unexpected_remote_movement`, `semantic_propagation`, `integrator_clean`, `publication_command`, the six required checks, and a `deferred_restack` object when descendants remain. the post-push manifest retains that preflight snapshot id plus the preflight lease, expected state, and base reference for each layer.
