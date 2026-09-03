# preparation and publication

use this procedure before a complete restack, and as the shared checkout and timing procedure for selective publication. for a selective changed layer or contiguous changed subseries, also read [selective publication](selective-publication.md).

## choose one integrator checkout

keep one reusable, complete-object detached linked worktree for stack integration and publication. it shares the trusted primary repository object store and owns stack metadata, history changes, the final checks, and the only official publication command. source workers use separate immutable checkouts and return one commit each. do not rebuild the integrator checkout for each handoff when the existing one is clean, complete, and at the accepted stack state.

first verify the trusted primary repository: the selected remote is the intended remote, `remote.<remote>.promisor` is not true, no partial-clone filter is present, and its git lfs hook is installed. it must contain the exact current trunk and every stack ref. create a new integrator as a detached linked worktree at the verified top oid:

```sh
git -C <trusted-primary> worktree add --detach <integrator-path> <top-oid>
```

before using the linked worktree, verify its exact head, a complete nonempty index, clean porcelain, complete required objects, and materialized required git lfs objects. identify an existing published stack with a verified stack number, pull request number or url, or branch name, then use `gh stack checkout` only in this sole integrator checkout.

when a required object is missing, fetch only the exact trunk and stack refs into the trusted primary object store. do not fetch all branches, use a wildcard refspec, or hydrate a promisor checkout in place:

```sh
git -C <trusted-primary> fetch --no-tags <remote> \
  '+refs/heads/<default-branch>:refs/remotes/<remote>/<default-branch>' \
  '+refs/heads/<stack-branch>:refs/remotes/<remote>/<stack-branch>'
# add one exact stack refspec for every remaining stack branch
git -C <trusted-primary> lfs fetch <remote> <default-branch>
git -C <trusted-primary> lfs fetch <remote> <stack-branch>
```

then repair or recreate only a new disposable linked worktree from the hydrated primary store. do not reset an established integrator checkout. recheck its head, index, objects, git lfs objects, hook, remote configuration, and clean porcelain before stack work resumes. if an accepted commit or required git lfs object exists only in another checkout, stop and transfer it through a separately verified immutable handoff before making it part of the integrator state.

a separate full clone is an exception, never the response to an incomplete object store or git lfs concern. allow it only after recording a concrete reason that a detached linked worktree plus narrow exact-ref hydration cannot satisfy this checkout. make that clone the sole integrator, use no partial-clone filter, fetch only the same exact refs, retain the standard git lfs hook, and complete the same verification. a failed or unproved linked-worktree setup is a stop, not permission for a broad fetch, a promisor checkout, lfs bypass, hook bypass, or direct push.

record the checkout before changing stack state and validate it with:

```sh
python3 scripts/check-integrator-checkout-contract.py checkout.json
```

the manifest records the checkout kind, trusted primary checks, exact refs, hydration destination and result, linked-worktree state, git lfs and hook state, and the official publication command. a `full_clone_exception` additionally records the concrete failure of the linked-worktree path and its exact-ref hydration attempt.

## admit handoffs and read-only checks

each candidate handoff must name its immutable base, one commit, allowed and changed paths, required checks, actual results, and known dependencies. admit independent handoffs together only when their path claims do not overlap and no handoff depends on another. validate those records before taking the integrator lock. adopt that batch in its declared order with `git cherry-pick <sha>`, then complete-restack and publish once. a selective publication leaves pending handoffs deferred; it never adopts them merely to publish an earlier changed subseries.

overlap, a dependency, an incomplete record, a changed path outside the claim, or uncertain independence makes the handoffs serial. accept the earlier handoff first, give the next worker its accepted tip, and validate it again. a conflict is serial integrator work and invalidates affected results.

independent read-only checks may run concurrently in separate clean checkouts at immutable layer tips. this includes per-layer diffs, exact-marker scans, patch-identity or range-diff checks, and review reads. each result must name the layer oid it inspected. rerun a read that no longer names the final layer oid. integration, conflict resolution, history changes, and publication stay serialized under the exact branch or stack-history lock.

## take one preflight snapshot for a complete restack

after the final restack and before its publication, record one complete snapshot of the stack:

- the default-branch oid and ordered local parent and layer oids;
- for every published layer, its branch, exact live remote head used as the lease, pull request head, base, and draft or ready state;
- for every new layer, the expected absent remote branch and its pull request state; and
- the clean integrator state, accepted handoff ids, and the exact check results being carried or rerun.

capture every remote and pull request field in this one snapshot. do not assemble a publication decision from separately timed layer reads. immediately before `gh stack push`, re-read every recorded remote head, pull request head, base, and state. they must exactly match the snapshot. any movement, missing record, or changed base ends the publication attempt; refresh the stack and preflight instead of overwriting it.

run the required per-layer diff, marker, range-diff or patch-identity, linear-history, and review checks against the final layer tips. they may finish concurrently only when each report identifies that final immutable tip. the integrator records their results before the final live readback.

## decide whether a result carries through a complete restack

initial publication always runs the required focused tests, builds, formatters, generators, generated-output checks, and cumulative validation. after a restack, carry a prior result only when all of these are proved:

1. every relevant layer has the same ordered patch identity as when the result ran;
2. the trunk diff is unrelated to the result's source, dependencies, generated inputs and outputs, build or toolchain configuration, formatter, fixtures, and runtime; and
3. no conflict resolution, dependency change, tooling change, generated change, or semantic layer change occurred.

record the proof with the carried result. a missing proof, changed layer patch, conflict, relevant trunk change, or any uncertainty requires the canonical affected and cumulative validation. an unchanged top tree alone is not patch identity, and a moved trunk oid alone is not unrelatedness.

## publish and time the attempt

hold the exact stack-history resource only while adopting accepted handoffs, resolving conflicts, restacking, making the lease/state check, and publishing. start the preparation timer when this attempt starts preparing its integrator checkout. stop it immediately before `gh stack push`. time `gh stack push` separately, from command start through command completion.

invoke only `gh stack rebase`, `gh stack rebase --continue` after a stopped official rebase, and `gh stack push` for stack history and publication. retain hooks and git lfs safeguards. never direct-push, disable hooks, skip lfs, weaken live readback, or reduce the post-push equality check. after the push, require every local layer, remote layer, pull request head, base chain, and pull request state to match the recorded expected result.
