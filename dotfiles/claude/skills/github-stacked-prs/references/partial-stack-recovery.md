# partial stack recovery

use this procedure when a lower layer has merged, a service-side rebase has moved a prefix, and a later child still has its old head. it is a recovery decision, not a publication shortcut.

## decide whether the local recovery is supported

first capture one live snapshot of the remaining stack: local and remote heads, pull request heads and bases, draft or ready states, exact leases, current trunk, and `gh stack view --json`. require the clean complete-object linked integrator checkout prepared in [preparation and publication](preparation-and-publication.md), no rebase or cherry-pick state, unchanged live heads and states, and patch identity for every service-rebased prefix layer.

for every child the scoped rebase would touch, prove one previous boundary that the child contains. the official cli can use only the current parent tip, the retained recorded base, or a valid fork point. record the candidate, its source, and the ancestry proof. also require the recorded base in `gh stack view --json` to match the recorded boundary for that child.

if every boundary is proved, check out the first untouched child and run only:

```sh
gh stack rebase --upstack --no-trunk
```

this rebases the remaining suffix locally through the official cli. it does not publish. after it finishes, require the local heads to change only in that suffix, every remote and pull request head and state to remain at the snapshot, and each post-rebase `gh stack view --json` base to equal its current parent head. then run the complete affected-layer and cumulative validation before considering the normal official publication path.

## hold when a boundary is missing

when the official rebase cannot determine a previous base, a recorded base is not an ancestor, a fork point is unavailable, or any snapshot field moved, stop. the exact hold is: do not change local stack metadata or history, and do not publish the stack.

do not use `gh stack unstack --local` followed by `gh stack init` for this shape. `init` derives a new base from the current merge base; it cannot accept the lost prior boundary. although those commands can leave branch heads unchanged, the rebuilt boundary can include already-integrated commits and make a later official rebase replay them. this is a negative control, not an alternative recovery.

also do not hand-edit stack metadata, run a manual or per-layer rebase, direct-push, use `gh stack link`, or use `gh stack sync`. `link` can push branches and change pull request composition; `sync` can rebase and publish.

the github website's rebase stack action is a separate, remote-first option. it rewrites the entire active stack from trunk upward, force-pushes every unmerged branch, and reruns checks. it has no documented selected-subseries mode, produces unsigned commits, and cannot resolve conflicts. use it only with explicit authority to rewrite the entire stack and after recording fresh heads, leases, bases, and states. verify all of those fields again after it finishes. otherwise wait for an upstream cli capability that accepts a saved prior boundary or a supported partial-prefix recovery.

## record the decision

run the checker with a live-read manifest before and after a supported local rebase, or once for a hold:

```sh
python3 scripts/check-partial-stack-recovery-contract.py recovery.json
```

the manifest records the single preflight snapshot, the planned affected suffix, each recorded and proved boundary, the official command, and the forbidden operations. a supported `post-rebase` manifest also records the local-only head changes, refreshed view bases, affected-layer validation, and cumulative stack validation. a `hold` manifest records why no candidate was available and proves that no metadata rebuild, manual rebase, direct push, linking, sync, or publication occurred.
