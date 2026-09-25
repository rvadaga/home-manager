---
name: github-stacked-prs
description: manage dependent pull request stacks with the official gh stack cli. use when creating, publishing, restacking, recovering, or merging a github-managed stack.
---

# github stacked pull requests

use the nix-managed official `gh stack` extension. stop if it is unavailable. independent changes stay in independent draft pull requests.

## choose the work

- **create or extend a stack:** follow the draft-layer steps below.
- **finish a selected layer or contiguous subseries:** use [selective publication](references/selective-publication.md). this is the normal path for selected work, including when descendant migrations or pending handoffs are explicitly deferred. selected behavior and its required checks must be complete; every unselected local and remote head stays unchanged.
- **integrate deferred work, sync the default branch, resolve conflicts, or restack:** use [complete restack](references/complete-restack.md). run the affected per-layer and cumulative checks at the resulting heads before publication.
- **adopt isolated source work:** use [source handoffs](references/source-handoffs.md). only the assigned integrator adopts commits and changes stack history.
- **recover broken previous boundaries or a wrong continuation:** use [partial stack recovery](references/partial-stack-recovery.md). never guess a boundary by removing and recreating stack metadata.
- **merge:** use the bottom-up procedure in [complete restack](references/complete-restack.md), with separate merge authorization and a verified ready bottom layer.

read [preparation and publication](references/preparation-and-publication.md) when establishing the integrator checkout or preparing a publication. reuse evidence while its checkout, heads, ownership and inputs remain unchanged; repeat invalidated observations after an interruption, handoff, conflict or unexpected movement.

## preserve the stack

one integrator owns adoption, history changes and publication. source workers use isolated immutable checkouts; lock only the exact integration or publication operation, without freezing unrelated work.

record the complete ordered stack, local heads, remote leases, pull request heads, bases and readiness before publication. re-read remote and pull request state immediately before the official command and independently after it. preserve the recorded bases and readiness; apply the shared `CLAUDE.md` rule for state provenance. a successful command or printed branch count is not readback evidence.

use only `gh stack rebase` for restacking, `gh stack rebase --continue` after resolving and staging its conflicts, and `gh stack push` for updates. never merge trunk into a stack layer, use per-layer rebase, direct-push managed stack refs, skip hooks or lfs, or overwrite unexpected remote movement. the publication reference records the pinned cli's lease limitation; extra reads do not close that interval.

keep required changed-layer tests, diff and exact-marker review, and linear-history checks. selected publication leaves descendant work visibly pending. it does not prove the combined stack works against the changed parent. report the checks that passed, the exact heads they cover, and the named migrations and checks still pending. deferred descendants cannot use selected-layer evidence as proof they are ready to merge.

preserve good interfaces under the production-correctness rule in `CLAUDE.md`; record the caller migration instead of retaining worse code to avoid it. scheduling belongs to the owning project.

## form and extend a visible draft stack

1. start with `gh stack init <branch>`; run the layer's required tests and publication checks, then use `gh stack submit --auto` without `--open`.
2. from the current top, use `gh stack add <child-branch>`. adopt existing dependent branches in bottom-to-top order with `gh stack init <bottom-branch> ... <top-branch>`.
3. validate each completed new layer and publish it as another draft with `gh stack submit --auto`. initial publication follows the full validation rules in [complete restack](references/complete-restack.md).

keep one branch and pull request per layer. do not keep a completed layer hidden while waiting for its parent to merge. every new pull request is draft; an interactive submission must explicitly select draft rather than accept the ready default. `--open` requires an explicit instruction to make the affected pull requests ready.

use `gh stack view --json` for ordered machine-readable state and `gh stack view --short` for a compact human view. do not infer flags from another version; check the installed command's help when needed.
