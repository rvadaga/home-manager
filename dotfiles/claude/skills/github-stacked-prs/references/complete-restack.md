# complete restack and merge

read [preparation and publication](preparation-and-publication.md) for checkout setup before changing history. these checks apply when deferred work is integrated or restacked, and at its final publication boundary.

## inspect and restack

- use `gh stack view` for the current stack and pull request status. use `gh stack view --short` for compact output or `gh stack view --json` for machine-readable output.
- immediately before a restack, record the default-branch oid, the ordered local parent and layer oids, each published layer's live remote head as its old push lease, and each pull request's live base and draft or ready state. rederive this snapshot instead of reusing an earlier one, and preserve its heads using the recovery-copy step in [preparation and publication](preparation-and-publication.md#publish-and-time-the-attempt).
- treat every request to sync `main` or the default branch as a full-stack operation, even when the request names one layer. run only `gh stack rebase` so the official cli restacks the complete stack.
- if it stops for conflicts, resolve the files, stage them, and resume only with `gh stack rebase --continue`.
- never merge the default branch into one layer, run per-layer `git rebase` or `git rebase --continue`, or use `gh pr update-branch` on a stack layer.

## verify a complete restack before publication

after every complete restack and before its push, run all of these checks even when prior test results may carry:

1. enumerate the complete stack with `gh stack view --json` and keep its parent-to-child order. confirm the integrator checkout has clean `git status --porcelain` output, and confirm that every accepted handoff reported clean porcelain at its exact commit.
2. capture every validated post-restack local parent and layer oid. re-read each published layer's live remote and pull request head, base, and draft or ready state against the saved pre-restack observations; do not replace the old push lease with this later read. confirm the expected base chain and apply the shared `CLAUDE.md` state rule. retain both the original observations and intended result in the publication snapshot, then apply the shared final checks immediately before the command. stop on unexpected movement. an absent remote is valid only for a new unpublished layer.
3. compare every old parent-to-layer patch range with its post-restack range. use `git range-diff <old-parent>..<old-layer> <new-parent>..<new-layer>` and require the same ordered patch set with no added, dropped, or changed patch, or use an equally strong per-layer patch-identity proof. review both per-layer diffs when the proof is ambiguous. treat an unproved layer as changed.
4. run `git diff --check`, then run `git diff --check <parent>..<layer>` for every layer.
5. scan every tracked file in every layer with `git grep -n -E '^(<<<<<<< |=======|>>>>>>> )' <layer> --` and review every marker match.
6. review `git diff <parent>..<layer> --` in full for every layer.
7. inspect `git rev-list --parents <parent>..<layer>` for every layer. reject merge commits, require each layer to start from its recorded parent, and require the cumulative stack to remain one linear sequence.

a clean current layer does not establish that the layers above it are clean.

### decide which validation reruns

for initial publication, run every required focused test, build, formatter, generator, generated-output check, and the full cumulative end-to-end validation. after a restack, also rerun the affected checks and the relevant full cumulative validation when a conflict resolution changed a layer, a layer patch changed behavior, patch identity is unproved, or another semantic input changed.

prior focused and cumulative results may carry only when every layer is patch-identical and the default-branch movement is proved unrelated to every result being carried. record the patch-identity and unrelated-trunk proof with the result. inspect the old-to-new trunk diff and trace semantic dependencies from the stack's source: imports, includes, libraries, generated inputs, build graph, toolchain and dependency configuration, formatter configuration, generated outputs, test fixtures, and test runtime or environment. a changed trunk oid proves only that trunk moved. a filename-only comparison cannot prove that a dependency or runtime input is unrelated. when the impact analysis is incomplete or uncertain, rerun the relevant full validation.

| case | always-required checks above | focused tests, builds, formatters, and generated checks | cumulative end-to-end validation |
|---|---|---|---|
| initial publication | run all | run all required checks | run the full required validation |
| every layer is patch-identical and trunk movement is proved unrelated | run all | carry current prior results | carry current prior results |
| trunk changes stack source | run all | rerun every affected check | rerun the relevant full validation |
| trunk changes a source dependency | run all | rerun every affected check | rerun the relevant full validation |
| trunk changes build or tooling configuration | run all | rerun every affected check | rerun the relevant full validation |
| trunk changes formatter configuration | run all | rerun every affected check | rerun the relevant full validation |
| trunk changes a generator or generated output | run all | rerun every affected check | rerun the relevant full validation |
| trunk changes a test fixture | run all | rerun every affected check | rerun the relevant full validation |
| trunk changes the test runtime or environment | run all | rerun every affected check | rerun the relevant full validation |
| conflict resolution changes a layer | run all | run all required checks | run the full required validation |
| a layer patch changes behavior | run all | run all required checks | run the full required validation |
| patch identity cannot be proved | run all | run all required checks | run the full required validation |
| another semantic input changes | run all | run all required checks | rerun the relevant full validation |

for initial publication, compare the cumulative top tree with the accepted combined source tree and require exact tree equality. when a layer patch changes intentionally, update the accepted combined source and require the same equality. after trunk-only movement, compare the stack-owned patch sequence instead of the raw top-tree oid, because unrelated trunk content necessarily changes that oid.

## publish a complete restack without changing pull request states

follow the cautious procedure in [preparation and publication](preparation-and-publication.md#publish-and-time-the-attempt), which owns the final checks, concrete stop conditions and readback after every outcome. complete-restack advancement through the official cli is standing-authorized when every new pull request will be draft and every published layer will keep the state recorded under the shared `CLAUDE.md` rule:

- use `gh stack rebase` to restack.
- use `gh stack rebase --continue` to resume after resolving and staging conflicts.
- use `gh stack push` to publish the validated stack.

after every complete-restack push attempt, enumerate the complete stack again. compare every local layer head, live remote head, and pull request head to the saved intended heads, then rederive every live base and draft or ready state and require the expected chain and state to remain unchanged. preserve the saved observations if the result is partial or unverified and follow the shared reconciliation procedure.

measure and report preparation time separately from the actual `gh stack push` time. preparation starts when this publication attempt starts preparing its selected integrator checkout and ends immediately before the official command begins. push time is only the elapsed time of that one official command. neither measurement changes the validation or readback requirements.

`gh stack push` may update descendant remote heads with force-with-lease after a restack. those official updates are part of the standing authorization and do not need separate force-push permission. this describes authorization, not immutable enforcement of the saved leases; the pinned cli limitation still applies.

this authorization covers carrying a recorded ready layer through a validated restack and publication of its descendants. it does not authorize changing any layer's draft or ready state. after the push, rederive every layer and require its state to equal the state recorded immediately before publication.

the shared default-branch rule in `CLAUDE.md` still applies: this authorization advances stack branches only and never permits a push to `main` or `master`.

this authorization does not cover:

- direct `git push --force`, `git push --force-with-lease`, their aliases, or another stack tool;
- parallel publication, publication by a source worker, or a push when another task owns integration or publication for any layer;
- overwriting remote movement that the current local stack does not account for;
- making an untouched draft layer ready, restoring a recorded ready layer to draft, or otherwise changing a layer's state;
- bypassing a stronger project, branch, pull request, design, deployment, or safety rule.

## merge bottom-up

merge bottom-up and select only a layer whose live github state is ready. the shared `CLAUDE.md` rule decides whether that state is authoritative and forbids a duplicate confirmation or automatic redraft. preserve every higher layer's recorded state.

1. repeat the always-required full-stack checks and apply the validation decision above. select only the current bottom pull request, and only when its live state is ready. stop if the bottom layer is still draft.
2. apply assembled `CLAUDE.md`'s squash commit message rule to the installed official stack command and its actual direct or queued merge path before invoking it. this pointer keeps message requirements in one place. an absent override or append-only API field is not proof of replacement capability; hold the merge when the required message cannot be guaranteed. do not route around the official stack workflow.
3. only after that check passes, run `gh stack merge <bottom-pr-number> --squash` with the verified message controls. the command merges everything through the selected pull request, so verify that its resolved target is the intended bottom pull request. rederive the merged pull request state and exact head, then independently verify its landed commit message under the shared rule before changing any remaining layer.
4. record every remaining layer's live state, then restack with `gh stack rebase`. if conflicts stop the command, use only `gh stack rebase --continue` after resolving and staging them.
5. repeat the always-required full-stack checks and apply the validation decision above, then publish the validated restack with `gh stack push`. verify every remaining pull request at the expected remote head and require its live state to equal the state recorded immediately before publication.

repeat from the new bottom layer. never substitute per-branch git commands for landing or restacking a github-managed stack.

## stack state controls

- accept a ready bottom layer verified under the shared `CLAUDE.md` rule with draft descendants; preserve the full state sequence through restack and publication, then allow only that bottom layer to merge.
- accept a ready middle layer verified under the shared rule; preserve it while lower layers land, and do not select it until it becomes the bottom layer.
- keep every untouched layer draft.
- reject publication unless every post-push draft or ready state exactly equals the state recorded immediately before publication.

## recover after the wrong continuation

if `git rebase --continue` was used while a `gh stack rebase` conflict was paused, stop before any push. treat the complete upstack as untrusted even when no remote ref moved.

restore trust only from a known-good stack state whose prior boundaries are still provable. read [partial stack recovery](partial-stack-recovery.md) when a merged lower layer or a service-side rewrite may have broken a boundary. do not remove and recreate local tracking to guess that boundary.

then use `gh stack view --json` to enumerate every affected layer, scan every tracked file for conflict markers, review every layer's diff, and run every layer's tests.

do not clear the stop based only on the originally conflicted layer.
