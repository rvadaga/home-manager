# preparation and publication

use this procedure before an existing stack is restacked or published.

## choose one integrator checkout

keep one reusable, complete-object linked worktree for stack integration and publication. it owns stack metadata, history changes, the final checks, and the only official publication command. source workers use separate immutable checkouts and return one commit each. do not rebuild the integrator checkout for each handoff when the existing one is clean, complete, and at the accepted stack state.

before using the checkout, verify its selected remote, complete objects, non-promisor configuration, absence of a partial-clone filter, clean porcelain, and normal git lfs hook. these checks remain required when a reusable checkout avoids earlier setup time.

## admit handoffs and read-only checks

each candidate handoff must name its immutable base, one commit, allowed and changed paths, required checks, actual results, and known dependencies. admit independent handoffs together only when their path claims do not overlap and no handoff depends on another. validate those records before taking the integrator lock. adopt that batch in its declared order with `git cherry-pick <sha>`, then restack and publish once.

overlap, a dependency, an incomplete record, a changed path outside the claim, or uncertain independence makes the handoffs serial. accept the earlier handoff first, give the next worker its accepted tip, and validate it again. a conflict is serial integrator work and invalidates affected results.

independent read-only checks may run concurrently in separate clean checkouts at immutable layer tips. this includes per-layer diffs, exact-marker scans, patch-identity or range-diff checks, and review reads. each result must name the layer oid it inspected. rerun a read that no longer names the final layer oid. integration, conflict resolution, history changes, and publication stay serialized under the exact branch or stack-history lock.

## take one preflight snapshot

after the final restack and before publication, record one complete snapshot of the stack:

- the default-branch oid and ordered local parent and layer oids;
- for every published layer, its branch, exact live remote head used as the lease, pull request head, base, and draft or ready state;
- for every new layer, the expected absent remote branch and its pull request state; and
- the clean integrator state, accepted handoff ids, and the exact check results being carried or rerun.

capture every remote and pull request field in this one snapshot. do not assemble a publication decision from separately timed layer reads. immediately before `gh stack push`, re-read every recorded remote head, pull request head, base, and state. they must exactly match the snapshot. any movement, missing record, or changed base ends the publication attempt; refresh the stack and preflight instead of overwriting it.

run the required per-layer diff, marker, range-diff or patch-identity, linear-history, and review checks against the final layer tips. they may finish concurrently only when each report identifies that final immutable tip. the integrator records their results before the final live readback.

## decide whether a result carries

initial publication always runs the required focused tests, builds, formatters, generators, generated-output checks, and cumulative validation. after a restack, carry a prior result only when all of these are proved:

1. every relevant layer has the same ordered patch identity as when the result ran;
2. the trunk diff is unrelated to the result's source, dependencies, generated inputs and outputs, build or toolchain configuration, formatter, fixtures, and runtime; and
3. no conflict resolution, dependency change, tooling change, generated change, or semantic layer change occurred.

record the proof with the carried result. a missing proof, changed layer patch, conflict, relevant trunk change, or any uncertainty requires the canonical affected and cumulative validation. an unchanged top tree alone is not patch identity, and a moved trunk oid alone is not unrelatedness.

## publish and time the attempt

hold the exact stack-history resource only while adopting accepted handoffs, resolving conflicts, restacking, making the lease/state check, and publishing. start the preparation timer when this attempt starts preparing its integrator checkout. stop it immediately before `gh stack push`. time `gh stack push` separately, from command start through command completion.

invoke only `gh stack rebase`, `gh stack rebase --continue` after a stopped official rebase, and `gh stack push` for stack history and publication. retain hooks and git lfs safeguards. never direct-push, disable hooks, skip lfs, weaken live readback, or reduce the post-push equality check. after the push, require every local layer, remote layer, pull request head, base chain, and pull request state to match the recorded expected result.
