---
name: pr-worktrees
description: Sync the open pull requests for the current Codex Desktop chat into Changes, reusing one local checkout per PR. Use for manual reruns, after publishing, splitting, or restacking, or for an explicitly requested review worktree rename.
---

# PR worktrees

Run with $pr-worktrees in the owning Codex Desktop chat. With no arguments, include its open attached PRs and the open PRs it actually owns. Accept exact PR links to add or narrow the scope. Do not import every open PR in the repository, attach reference-only PRs, or operate in another chat.

Keep one checkout per PR. Reuse the implementation checkout if it is already the PR's checkout, even when it has local edits. For the exact published diff, use the GitHub PR when the local checkout is dirty or at a different head. Never make a second checkout just to get an exact diff, change a label, or work around an app refusal.

## Find and verify each checkout

1. Read the visible chat ID, its original working directory, and list_artifacts. Read each scoped PR's live GitHub URL, state, draft flag, head repository/ref/SHA and immediate base ref/SHA. Skip closed and merged PRs. Map each PR to a trusted local Git repository with the exact target remote. Resolve the current SHA of the named target ref independently; stale PR metadata is not a reason to use an older base. For a stack use the actual parent GitHub reports. If a moved parent makes the local diff include earlier layers, report the stale relationship to the integrator; do not substitute an old base.
2. Match by host, repository and PR number. Prefer an existing app binding, a recorded binding verified by the owning chat, or a local branch whose upstream identifies the PR's exact head repository and ref. A name or matching SHA alone only identifies a possible checkout. If the mapping is missing, ambiguous, or claimed by another chat, preserve the candidate and report the blocker rather than guessing or creating a substitute.
3. Use [the read-only planner](scripts/plan.py) with the [input format](references/plan.md). This checks Git registration, live local head, directory and changes. It proposes one path per PR and keeps native PR attachment, worktree attachment, and pairing separate. Recheck the inventory just before changing it. If app inventory or an earlier creation is incomplete, inspect or finish that exact operation before starting another.
4. When Git and app inventory show no existing checkout for the PR, the owning chat uses `create_worktree` at the exact published SHA in the trusted local repository. Get the exact head and base objects by narrow fetch if needed.
   - Use the planner's `checkoutName`. For a numbered branch, `owner/ticket-123-pr12.3-example-change` becomes `pr12.3-example-change`. Drop the owner and ticket prefix, keep the dots, and do not add a leading `Worktree` label. For an unnumbered branch, use `repo-pr<GitHub-number>`. A name alone does not identify a PR.
   - If the name is ambiguous, already in use by another PR, or refused by the app, report why. Do not substitute a different series name or create a second checkout.
   - Wait for creation and registration, then record the PR URL, exact path, attachment ID, checked-out SHA, owning and creating chat links, and why the path belongs to the PR. Keep older open reviews distinct; a local unpublished candidate does not represent the published PR.
5. Refresh a stale checkout in place only if it is a clean, detached, idle review snapshot controlled by this chat, the old commit is independently recoverable, and no other chat claims it. Reverify the exact path, head and status immediately before moving it; keep all uncommitted, unpublished and shared checkouts intact. Review setup does not rewrite branches, stage changes, or run stack operations. Refresh the local comparison when only the base moves, too.

## Attach and verify in Desktop

- Attach each missing open PR with attach_artifact for its live URL. Attach the chosen existing worktree with attach_worktree only when needed and allowed; create_worktree can already attach it. Reread list_artifacts and reuse the same identities on every run. A refusal is a blocker; do not attach a second checkout.
- For a clean checkout with the published head, verify its layer-only git diff against the exact immediate base with git merge-base and git diff <base>...<head>. Then request open_in_codex with `{type: "review", path: <checkout>, view: "branch", baseBranch: <exact-base-sha>}`. Check the resulting threadId is the visible owning chat. Leave a verified current comparison alone. If the app changed the working directory, return to the original one using a supported tool or report the change and run later commands with an explicit working directory.
- Check **Changes → Pull requests** for each attached PR and inspect the PR-to-worktree association when the app exposes it. Opening a local comparison and attaching a PR separately do not prove a native pairing. Confirm an exact matching root in app readback or inspect the actual paired view. A queued panel, null association, or unavailable renderer is not proof. Report the PR attachment, checkout path, exact comparison, native pairing and rendered state separately. Never edit the app database or use unsupported control paths to manufacture a pairing.

## Duplicates and blocked archives

An ordinary sync does not rename existing worktrees, move another chat's working directory, or archive anything. For a requested rename, follow [the in-place rename procedure](references/rename.md). If explicitly asked to retire an exact duplicate, first verify the kept worktree and its replacement view, exact ownership, fresh active and archived chat claims, clean status, and recovery of every commit. Preserve the live working copy and anything carrying an open review, local edits, unpublished commits, ambiguous ownership or an unknown safety check.

Use the supported archive_worktree operation for an eligible managed duplicate. Verify its archived attachment and absence of its checkout. For an explicitly requested chat archive or Git-linked checkout retirement, follow session-wind-down and applicable checkout cleanup rules. Do not archive a chat to get around its worktree claim; do not delete or rename a directory to bypass an app refusal.

When an archive is blocked, give the concrete reason and a Markdown link of the form `[chat title](codex://threads/<verified-chat-id>)` for each verified blocking chat, or for the verified chat whose own archive failed. Verify the claim against the exact path; a creator, an empty search, or a similar chat name does not identify a claimant. Report an unnamed refusal as such. Do not infer permission to message or resume the chat.
