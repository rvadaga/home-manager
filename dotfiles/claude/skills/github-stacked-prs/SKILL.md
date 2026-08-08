---
name: github-stacked-prs
description: create, extend, review, publish, restack, recover, and merge visible draft stacks with the official gh stack cli. use for any real dependent pull request series, including deciding whether the cli's descendant-head updates are authorized.
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
- restack only with `gh stack rebase`.
- if it stops for conflicts, resolve the files, stage them, and resume only with `gh stack rebase --continue`.
- never use per-branch `git merge`, `git rebase`, or `git rebase --continue` inside a github-managed stack.

## keep new pull requests draft

keep every new stacked pull request draft unless the user explicitly asks to change it.

- for a non-interactive submission, run `gh stack submit --auto` without `--open`.
- in the interactive editor, change every new pull request from the default ready state to draft before submitting.
- never let the interactive default ready state escape. pass `--open` only when the user explicitly asks to make the pull requests ready.

## verify the full stack before publication

after every restack and before any push:

1. enumerate the complete stack with `gh stack view --json` and keep its parent-to-child order. for each published layer, run `git ls-remote --heads <remote> <branch>` and compare the exact live head with the expected remote head. an absent remote is valid only for a new unpublished layer. stop if any existing head moved unexpectedly.
2. run `git diff --check`.
3. for every layer, run `git diff --check <parent>..<layer>` and `git grep -n -E '^(<<<<<<< |=======|>>>>>>> )' <layer> --`. review every marker match.
4. review `git diff <parent>..<layer> --` in full.
5. run the tests required by each layer.

a clean current layer does not establish that the layers above it are clean.

## publish a validated draft stack

when every existing pull request in the github-managed stack is draft and every new pull request will remain draft, normal advancement through the official cli is standing-authorized at any time:

- use `gh stack rebase` to restack.
- use `gh stack rebase --continue` to resume after resolving and staging conflicts.
- use `gh stack push` to publish the validated stack.

`gh stack push` may update descendant remote heads with force-with-lease after a restack. those official, lease-checked updates are part of the standing authorization and do not need separate force-push permission.

the shared default-branch rule in `CLAUDE.md` still applies: this authorization advances draft stack branches only and never permits a push to `main` or `master`.

this authorization does not cover:

- direct `git push --force`, `git push --force-with-lease`, their aliases, or another stack tool;
- a push when another writer owns any layer;
- overwriting remote movement that the current local stack does not account for;
- changing or publishing a ready pull request unless the active project rules allow that action now; or
- bypassing a stronger project, branch, pull request, design, deployment, or safety rule.

## merge bottom-up

merge a layer only after the user explicitly approves changing that layer from draft. keep every higher layer draft.

1. repeat the full-stack inspection and layer tests, then change only the bottom pull request to ready.
2. run `gh stack merge <bottom-pr-number>`. the command merges everything through the selected pull request, so selecting the bottom pull request lands exactly one layer.
3. rederive the merged pull request state and exact head before changing any remaining layer.
4. restack the remaining drafts with `gh stack rebase`. if conflicts stop the command, use only `gh stack rebase --continue` after resolving and staging them.
5. repeat the full-stack inspection and every remaining layer's tests, then publish the validated restack with `gh stack push` and verify that every remaining pull request is still draft at the expected remote head.

repeat from the new bottom layer. never substitute per-branch git commands for landing or restacking a github-managed stack.

## recover after the wrong continuation

if `git rebase --continue` was used while a `gh stack rebase` conflict was paused, stop before any push. treat the complete upstack as untrusted even when no remote ref moved.

restore trust in one of these ways:

- reconstruct the stack from a known-good state through `gh stack`, then repeat the full pre-push verification; or
- use `gh stack view --json` to enumerate every affected layer, scan every tracked file for conflict markers, review every layer's diff, and run every layer's tests.

do not clear the stop based only on the originally conflicted layer.
