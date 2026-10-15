# selective publication

finish and publish one coherent, tested changed layer or contiguous subseries while leaving every unselected head in place. descendant migrations and pending handoffs may be explicitly deferred. neither deferral requires weakening the selected implementation or silently claiming that descendants work with it.

## admit selected work

establish one current snapshot of the ordered stack with the assigned integrator. record every branch, local head, live remote head, pull request head, lease, base reference and readiness. the selected indexes must be contiguous; each selected head must contain unpublished changes. every unselected local, remote and pull request head must equal its recorded lease.

reject a default-branch sync, conflict, restack already run, handoff adoption during this attempt, noncontiguous selection, incomplete selected behavior or checks, or unexpected head/base/state movement. use [complete restack](complete-restack.md) for work that actually integrates handoffs or changes descendant history. the existence of a pending handoff alone does not require adoption during selected publication.

when a semantic change needs descendant migrations, name those migrations in `deferred_restack.work`. do the same for pending handoffs, with their immutable commit and base. each deferred item names its descendant indexes, remaining work and required checks. only work unnecessary for the selected layers may be deferred. if the selected behavior itself requires that handoff or migration, finish it before publication.

keep one deferred record with the snapshot's exact parent and child heads, completed checks and their inputs, pending migrations and checks, and which earlier evidence the changed parent invalidates. the first untouched descendant needs a later rebase. mark the descendants `not_validated_against_selected_heads`; their earlier tests do not establish compatibility with the new parent.

## validate and prepare

use [preparation and publication](preparation-and-publication.md) for the complete-object linked integrator, ownership, hooks and lfs requirements. require clean porcelain. run the selected range's required compilation, behavior tests, formatters, generators and packaging checks according to the changed contracts. record actual check names, results and inputs with the attempt.

review every selected layer's diff, run `git diff --check`, review exact conflict-marker matches and prove linear history within the selected range. the unchanged descendant's old parent boundary must remain recorded even though it is no longer based on the selected tip. do not claim a fully restacked topology.

run the structural checker against the saved live-read manifest:

```sh
python3 scripts/check-selective-publication-contract.py preflight.json
```

the checker verifies manifest consistency, not live state, test quality or the command's effective leases. immediately before the command, independently read every remote head, pull request head, base and readiness and compare them with the snapshot. stop on any movement.

## pinned cli limitation

use only `gh stack push`. official version 0.1.1 has no per-layer push flag: it includes all active branches, so every unselected local head must remain at its remote lease. unchanged descendants need no new tests or handoff adoption during this pass. normal hooks still run for the command's actual ref set.

the [pinned push implementation](https://github.com/github/gh-stack/blob/2bd699a544a09cb5c45a013d03416e0894b0454e/cmd/push.go) fetches active branches before [constructing leases from tracking refs](https://github.com/github/gh-stack/blob/2bd699a544a09cb5c45a013d03416e0894b0454e/internal/git/gitops.go). these files are unchanged from 0.1.0. a disposable local-remote fixture reproduces an intervening remote commit being overwritten after that refresh. neither more preflight reads nor a successful post-push readback protects the recorded lease during that interval. reproduce both the unchanged-child case and this limitation with `python3 scripts/test-gh-stack-command.py <official-binary>`; it uses disposable local remotes and no github access.

retain the requirement that publication enforces the saved leases at the write. stock 0.1.1 alone does not meet it. when no separately verified enforcement exists, stop the actual push and report the cli blocker; continue selected implementation, validation and the deferred-work record. do not substitute a direct push, suppress the fetch, bypass hooks, or claim the package bump fixes the race. this limitation also affects complete-restack pushes.

## read back the complete result

retain the preflight file unchanged. after any permitted command attempt, including an error or partial update, obtain fresh local, remote and pull request state for the complete stack:

```sh
python3 scripts/check-selective-publication-contract.py post-push.json --preflight preflight.json
```

require selected remote and pull request heads to equal the saved selected local heads. require every unselected local, remote and pull request head to equal the saved lease. preserve every base and readiness. compare the post-push snapshot id, leases and deferred record with the original file; a newly rewritten expectation cannot prove preservation.

report the exact changed heads and the named deferred work. for example: `the selected layer's compilation and interface tests passed at <head>. child <branch> still needs its caller migration and rebase; its integration tests have not run against this parent.` adapt the checks to the actual evidence. measure preparation and the official command separately.

when deferred work is integrated or restacked, apply the complete per-layer and cumulative validation at those heads and at final publication. selected-layer results never stand in for that validation or authorize a descendant merge.

## manifest fields

both phases contain `phase`, `preflight_snapshot_id`, the complete ordered `layers`, and `changed_indices`. each layer contains `branch`, `local_head`, `remote_head`, `pr_head`, `lease_head`, `base_ref`, `expected_base_ref`, `state`, and `expected_state`.

preflight requires true `pre_push_readback` and `integrator_clean`; false `restack_ran`, `default_branch_sync`, `conflict`, `handoffs_adopted`, and `unexpected_remote_movement`; boolean `semantic_propagation` and `pending_handoffs`; `publication_command: "gh stack push"`; and the six true checks named by the checker. these assertions must have retained evidence.

when descendants remain, `deferred_restack` names `first_descendant`, `reason`, `validation_status: "not_validated_against_selected_heads"`, and a `work` array. each work item contains `kind` (`migration`, `handoff`, or `validation`), `layer_indices`, `remaining_work`, `required_checks`, and `required_for_selected: false`. a handoff also has `commit` and `base`. semantic propagation requires a migration item; pending handoffs require a handoff item. post-push retains this record verbatim and requires the original preflight file.
