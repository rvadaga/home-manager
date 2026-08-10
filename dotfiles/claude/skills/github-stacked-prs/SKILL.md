---
name: github-stacked-prs
description: create, extend, sync, review, publish, restack, recover, and merge visible github stacks with the official gh stack cli. use for any real dependent pull request series, including syncing with the default branch, preserving each published layer's live draft or ready state, and deciding whether the cli's descendant-head updates are authorized.
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

## keep new pull requests draft

create every new stacked pull request as a draft. after publication, preserve its live draft or ready state unless the user changes that layer again.

- for a non-interactive submission, run `gh stack submit --auto` without `--open`.
- in the interactive editor, change every new pull request from the default ready state to draft before submitting.
- never let the interactive default ready state escape. pass `--open` only when the user explicitly asks to make the pull requests ready.
- when the user changes a published layer from draft to ready in github, treat that github action as the explicit instruction for that layer. do not require the same instruction again in chat.

## verify the full stack before publication

after every restack and before any push:

1. enumerate the complete stack with `gh stack view --json` and keep its parent-to-child order. confirm every layer's owning worktree has clean `git status --porcelain` output.
2. for each published layer, run `git ls-remote --heads <remote> <branch>` and compare the exact live head with the expected remote head. record each pull request's live base and draft or ready state, and confirm that the bases form the expected chain. an absent remote is valid only for a new unpublished layer. stop if any existing head or base moved unexpectedly.
3. when a published layer's state differs from the last verified state, inspect the github timeline event and actor. a state change made by the user is the instruction for that layer. stop for unexplained movement or movement by another actor that the current authorization does not cover.
4. run `git diff --check`, then run `git diff --check <parent>..<layer>` for every layer.
5. scan every tracked file in every layer with `git grep -n -E '^(<<<<<<< |=======|>>>>>>> )' <layer> --` and review every marker match.
6. review `git diff <parent>..<layer> --` in full for every layer.
7. run each layer's focused tests and the required end-to-end validation against the cumulative top tree.
8. compare the cumulative top tree with the accepted combined source tree and require exact tree equality.

a clean current layer does not establish that the layers above it are clean.

## publish without changing pull request states

normal advancement through the official cli is standing-authorized when every new pull request will be draft and every published layer will keep its recorded live draft or ready state:

- use `gh stack rebase` to restack.
- use `gh stack rebase --continue` to resume after resolving and staging conflicts.
- use `gh stack push` to publish the validated stack.

`gh stack push` may update descendant remote heads with force-with-lease after a restack. those official, lease-checked updates are part of the standing authorization and do not need separate force-push permission.

this authorization covers carrying a user-ready layer through a validated restack and publication of its descendants. it does not authorize changing any layer's draft or ready state. after the push, rederive every layer and require its state to equal the recorded pre-restack state exactly.

the shared default-branch rule in `CLAUDE.md` still applies: this authorization advances stack branches only and never permits a push to `main` or `master`.

this authorization does not cover:

- direct `git push --force`, `git push --force-with-lease`, their aliases, or another stack tool;
- a push when another writer owns any layer;
- overwriting remote movement that the current local stack does not account for;
- making an untouched draft layer ready, restoring a user-ready layer to draft, or otherwise changing a layer's state;
- bypassing a stronger project, branch, pull request, design, deployment, or safety rule.

## merge bottom-up

merge bottom-up and select only a layer whose live github state is ready. when the user made that layer ready in github, that action is the approval; do not require a duplicate chat confirmation. preserve every higher layer's recorded state.

1. repeat the full-stack inspection and layer tests. select only the current bottom pull request, and only when its live state is ready. stop if the bottom layer is still draft.
2. run `gh stack merge <bottom-pr-number>`. the command merges everything through the selected pull request, so selecting the bottom pull request lands exactly one layer.
3. rederive the merged pull request state and exact head before changing any remaining layer.
4. record every remaining layer's live state, then restack with `gh stack rebase`. if conflicts stop the command, use only `gh stack rebase --continue` after resolving and staging them.
5. repeat the full-stack inspection and every remaining layer's tests, then publish the validated restack with `gh stack push`. verify every remaining pull request at the expected remote head and require its live state to equal the recorded pre-restack state.

repeat from the new bottom layer. never substitute per-branch git commands for landing or restacking a github-managed stack.

## ready-state controls

- accept a user-ready bottom layer with draft descendants; preserve the full state sequence through restack and publication, then allow only that bottom layer to merge.
- accept a user-ready middle layer; preserve it while lower layers land, and do not select it until it becomes the bottom layer.
- keep every untouched layer draft.
- reject a request for duplicate chat confirmation after the github timeline shows that the user made the layer ready.
- reject automatically restoring a user-ready layer to draft.
- accept a readiness change whose timeline actor is the user.
- stop on an unexplained readiness change or a change by another actor outside the current authorization.
- reject publication unless every post-push draft or ready state exactly equals its recorded pre-restack state.

## recover after the wrong continuation

if `git rebase --continue` was used while a `gh stack rebase` conflict was paused, stop before any push. treat the complete upstack as untrusted even when no remote ref moved.

restore trust in one of these ways:

- reconstruct the stack from a known-good state through `gh stack`, then repeat the full pre-push verification; or
- use `gh stack view --json` to enumerate every affected layer, scan every tracked file for conflict markers, review every layer's diff, and run every layer's tests.

do not clear the stop based only on the originally conflicted layer.
