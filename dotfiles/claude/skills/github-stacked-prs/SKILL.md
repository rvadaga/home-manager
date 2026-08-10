---
name: github-stacked-prs
description: create, extend, sync, review, publish, restack, recover, and merge visible github stacks with the official gh stack cli. use for any real dependent pull request series, including syncing with the default branch, preserving the live pull request states recorded under the shared CLAUDE.md rule, and deciding whether the cli's descendant-head updates are authorized.
---

# github stacked pull requests

use the nix-managed official `gh stack` extension. if it is unavailable, stop rather than installing it imperatively or substituting another stack tool.

## form and extend a visible draft stack

use a stack only when the layers have a real code dependency. keep independent changes as independent draft pull requests.

1. start the first layer with `gh stack init <branch>`. run its focused tests and the pre-push checks below, then publish it as a draft with `gh stack submit --auto` without `--open`.
2. when the next dependent layer is ready, check out the current top and use `gh stack add <child-branch>`. if the dependent branches already exist, adopt them in bottom-to-top order with `gh stack init <bottom-branch> ... <top-branch>`.
3. run the new layer's focused tests and the complete pre-push verification, then use `gh stack submit --auto` without `--open` to publish it as another draft layer.
4. repeat for each ready dependent layer. do not keep a ready layer hidden locally while waiting for its parent to merge.

keep one branch, pull request, owning working tree, writer, and reviewer claim per layer. do not make two sessions write the same layer.

## inspect and restack

- use `gh stack view` for the current stack and pull request status. use `gh stack view --short` for compact output or `gh stack view --json` for machine-readable output.
- treat every request to sync `main` or the default branch as a full-stack operation, even when the request names one layer. run only `gh stack rebase` so the official cli restacks the complete stack.
- if it stops for conflicts, resolve the files, stage them, and resume only with `gh stack rebase --continue`.
- never merge the default branch into one layer, run per-layer `git rebase` or `git rebase --continue`, or use `gh pr update-branch` on a stack layer.

## create stack layers as drafts

create every new stacked pull request as a draft. after publication, the shared pull request state rule in `CLAUDE.md` owns readiness provenance and exact state preservation for every layer.

- for a non-interactive submission, run `gh stack submit --auto` without `--open`.
- in the interactive editor, change every new pull request from the default ready state to draft before submitting.
- never let the interactive default ready state escape. pass `--open` only when the user explicitly asks to make the pull requests ready.

## publish from a complete-object checkout

before verification or publication, confirm that the checkout has complete git objects for the stack. use `git config --get remote.<remote>.url` to verify the selected remote. then inspect both `git config --get --bool remote.<remote>.promisor` and `git config --get remote.<remote>.partialclonefilter`. stop if `promisor` is true or a partial-clone filter is present. git lfs pre-push scans can otherwise turn promised pointer blobs into one filtered fetch per object before any ref moves.

prefer the existing complete-object owning worktree. when a separate clean checkout is required, make it the sole owning worktree and writer for every layer before it changes any stack branch. the checkout below names the selected remote `origin`. clone only the current stack top without a partial-clone filter, configure fetch refspecs for the default branch and every exact stack branch, fetch those refs together, and keep the standard git lfs hook. identify the existing stack with a verified stack number, pull request number or url, or branch name, then reconstruct it with `gh stack checkout`:

```sh
GIT_LFS_SKIP_SMUDGE=1 git clone --no-checkout --single-branch --branch <top-branch> <remote-url> <publication-checkout>
cd <publication-checkout>
git config --unset-all remote.origin.fetch
git config --add remote.origin.fetch '+refs/heads/<default-branch>:refs/remotes/origin/<default-branch>'
git config --add remote.origin.fetch '+refs/heads/<stack-branch>:refs/remotes/origin/<stack-branch>'
# add one exact refspec for every remaining stack branch
git fetch --no-tags origin <the-exact-default-and-stack-refspecs>
git lfs install --local
GIT_LFS_SKIP_SMUDGE=1 gh stack checkout <existing-stack-or-pull-request>
```

this remote-only reconstruction is valid only when the accepted stack can be recovered from its published refs. stop if an accepted commit or required git lfs object exists only in another checkout; transfer that state through a separately verified handoff before making the new checkout the owner.

repeat the complete verification below in that checkout before `gh stack push`. never use `GIT_LFS_SKIP_PUSH`, disable hooks, hydrate a partial clone in place, or substitute a direct push to make publication faster.

## verify the full stack before publication

after every restack and before any push:

1. enumerate the complete stack with `gh stack view --json` and keep its parent-to-child order. confirm every layer's owning worktree has clean `git status --porcelain` output.
2. for each published layer, run `git ls-remote --heads <remote> <branch>` and compare the exact live head with the expected remote head. record each pull request's live base and draft or ready state, and confirm that the bases form the expected chain. an absent remote is valid only for a new unpublished layer. stop if any existing head or base moved unexpectedly.
3. apply the shared `CLAUDE.md` pull request state rule to every layer. inspect the github timeline event and actor when provenance is unclear, and stop when that rule does not authorize the observed movement.
4. run `git diff --check`, then run `git diff --check <parent>..<layer>` for every layer.
5. scan every tracked file in every layer with `git grep -n -E '^(<<<<<<< |=======|>>>>>>> )' <layer> --` and review every marker match.
6. review `git diff <parent>..<layer> --` in full for every layer.
7. run each layer's focused tests and the required end-to-end validation against the cumulative top tree.
8. compare the cumulative top tree with the accepted combined source tree and require exact tree equality.

a clean current layer does not establish that the layers above it are clean.

## publish without changing pull request states

normal advancement through the official cli is standing-authorized when every new pull request will be draft and every published layer will keep the state recorded under the shared `CLAUDE.md` rule:

- use `gh stack rebase` to restack.
- use `gh stack rebase --continue` to resume after resolving and staging conflicts.
- use `gh stack push` to publish the validated stack.

`gh stack push` may update descendant remote heads with force-with-lease after a restack. those official, lease-checked updates are part of the standing authorization and do not need separate force-push permission.

this authorization covers carrying a recorded ready layer through a validated restack and publication of its descendants. it does not authorize changing any layer's draft or ready state. after the push, rederive every layer and require its state to equal the recorded pre-restack state exactly.

the shared default-branch rule in `CLAUDE.md` still applies: this authorization advances stack branches only and never permits a push to `main` or `master`.

this authorization does not cover:

- direct `git push --force`, `git push --force-with-lease`, their aliases, or another stack tool;
- a push when another writer owns any layer;
- overwriting remote movement that the current local stack does not account for;
- making an untouched draft layer ready, restoring a recorded ready layer to draft, or otherwise changing a layer's state;
- bypassing a stronger project, branch, pull request, design, deployment, or safety rule.

## merge bottom-up

merge bottom-up and select only a layer whose live github state is ready. the shared `CLAUDE.md` rule decides whether that state is authoritative and forbids a duplicate confirmation or automatic redraft. preserve every higher layer's recorded state.

1. repeat the full-stack inspection and layer tests. select only the current bottom pull request, and only when its live state is ready. stop if the bottom layer is still draft.
2. run `gh stack merge <bottom-pr-number>`. the command merges everything through the selected pull request, so selecting the bottom pull request lands exactly one layer.
3. rederive the merged pull request state and exact head before changing any remaining layer.
4. record every remaining layer's live state, then restack with `gh stack rebase`. if conflicts stop the command, use only `gh stack rebase --continue` after resolving and staging them.
5. repeat the full-stack inspection and every remaining layer's tests, then publish the validated restack with `gh stack push`. verify every remaining pull request at the expected remote head and require its live state to equal the recorded pre-restack state.

repeat from the new bottom layer. never substitute per-branch git commands for landing or restacking a github-managed stack.

## stack state controls

- accept a ready bottom layer verified under the shared `CLAUDE.md` rule with draft descendants; preserve the full state sequence through restack and publication, then allow only that bottom layer to merge.
- accept a ready middle layer verified under the shared rule; preserve it while lower layers land, and do not select it until it becomes the bottom layer.
- keep every untouched layer draft.
- reject publication unless every post-push draft or ready state exactly equals its recorded pre-restack state.

## recover after the wrong continuation

if `git rebase --continue` was used while a `gh stack rebase` conflict was paused, stop before any push. treat the complete upstack as untrusted even when no remote ref moved.

restore trust in one of these ways:

- reconstruct the stack from a known-good state through `gh stack`, then repeat the full pre-push verification; or
- use `gh stack view --json` to enumerate every affected layer, scan every tracked file for conflict markers, review every layer's diff, and run every layer's tests.

do not clear the stop based only on the originally conflicted layer.
