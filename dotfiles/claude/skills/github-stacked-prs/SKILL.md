---
name: github-stacked-prs
description: manage github-managed stacked pull requests with the official gh stack cli. use for creating, viewing, restacking, recovering, validating, or submitting a github stack.
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

## verify the full stack before a push

after every restack and before any push:

1. enumerate the complete stack with `gh stack view --json` and keep its parent-to-child order.
2. run `git diff --check`.
3. for every layer, run `git diff --check <parent>..<layer>` and `git grep -n -E '^(<<<<<<< |=======|>>>>>>> )' <layer> --`. review every marker match.
4. review `git diff <parent>..<layer> --` in full.
5. run the tests required by each layer.

a clean current layer does not establish that the layers above it are clean.

## recover after the wrong continuation

if `git rebase --continue` was used while a `gh stack rebase` conflict was paused, stop before any push. treat the complete upstack as untrusted even when no remote ref moved.

restore trust in one of these ways:

- reconstruct the stack from a known-good state through `gh stack`, then repeat the full pre-push verification; or
- use `gh stack view --json` to enumerate every affected layer, scan every tracked file for conflict markers, review every layer's diff, and run every layer's tests.

do not clear the stop based only on the originally conflicted layer.
