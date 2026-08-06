---
name: github-stacked-prs
description: manage and publish github-managed stacked pull requests with the official gh stack cli. use for creating, viewing, restacking, recovering, validating, pushing, or submitting a github stack, including deciding whether the cli's descendant-head updates are authorized.
---

# github stacked pull requests

use the official github-owned [`github/gh-stack`](https://github.com/github/gh-stack) cli extension. this config packages stable release [`v0.1.0`](https://github.com/github/gh-stack/releases/tag/v0.1.0) declaratively in `packages/gh-stack.nix` and exposes its `bin` directory through the xdg extension link in `os-configs/base.nix`. the extension release is stable; the github stacked pull requests service is in [private preview](https://github.github.com/gh-stack/) and must be enabled for the repository.

do not install the extension imperatively or substitute another stack tool. confirm `gh stack --version` before acting. if the official command is unavailable, stop stack reconciliation.

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

this authorization does not cover:

- direct `git push --force`, `git push --force-with-lease`, their aliases, or another stack tool;
- a push when another writer owns any layer;
- overwriting remote movement that the current local stack does not account for;
- changing or publishing a ready pull request unless the active project rules allow that action now; or
- bypassing a stronger project, branch, pull request, design, deployment, or safety rule.

## recover after the wrong continuation

if `git rebase --continue` was used while a `gh stack rebase` conflict was paused, stop before any push. treat the complete upstack as untrusted even when no remote ref moved.

restore trust in one of these ways:

- reconstruct the stack from a known-good state through `gh stack`, then repeat the full pre-push verification; or
- use `gh stack view --json` to enumerate every affected layer, scan every tracked file for conflict markers, review every layer's diff, and run every layer's tests.

do not clear the stop based only on the originally conflicted layer.
