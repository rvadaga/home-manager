---
allowed-tools: Bash(git branch:*), Bash(git rev-parse:*), Bash(git status:*), Bash(git worktree list:*)
description: rename current worktree branch from a claude-auto-generated name to a meaningful one tied to the work being done
---

## your task

rename the current worktree's git branch from its auto-generated name (e.g., `kind-matsumoto-bdf245`, `beautiful-gates`, `condescending-faraday-309090`) to a meaningful name in the form `rahul/<ticket>-<desc>` or `rahul/<topic>`.

rename only the branch — leave the worktree directory alone. moving the directory mid-session breaks claude's cwd resolution.

## arguments

`$ARGUMENTS` may be:
- empty → infer from conversation context
- a bare jira ticket (regex `^[a-zA-Z]+-[0-9]+$`, e.g. `s2-306`, `MLORCAS-2883`) → ask user for short description
- a ticket + description (e.g. `s2-306-ann-indexer-failures`) → use as-is
- free-form topic (e.g. `ann-indexer-failures`) → use as-is

## steps

1. **detect current branch:** run `git branch --show-current`. if empty (detached head), abort with a clear message.

2. **decide the new name:**
   - if `$ARGUMENTS` is empty: infer the topic from the conversation so far. if the work involves a jira ticket, prefer the ticket form. if you cannot infer a confident name, **ask the user** before proceeding — do not guess.
   - if `$ARGUMENTS` is a bare ticket: ask for a short kebab-case description, then combine.
   - else: use `$ARGUMENTS` as the topic.

3. **normalize:**
   - lowercase the entire name
   - replace spaces and underscores with hyphens
   - if not already prefixed with `rahul/`, prepend it
   - final form: `rahul/<lowercase-kebab-name>` (or `rahul/<ticket-lowercased>-<desc>`)

4. **confirm with user** by showing old → new before executing. proceed without confirmation only if the user has explicitly authorized auto-rename in the conversation.

5. **execute:** `git branch -m <old> <new>`

6. **report** the new branch name and confirm it took effect with `git branch --show-current`.

## auto-name detection

the auto-generated pattern is:
- two random lowercase words separated by `-`, optionally followed by a 6-character hex suffix
- examples: `kind-matsumoto`, `beautiful-gates`, `condescending-faraday-309090`, `dreamy-jemison`
- if the current branch matches `^[a-z]+-[a-z]+(-[a-f0-9]{6})?$` and has no `/` in it, treat as auto-generated

names that should NOT be renamed (already meaningful):
- anything starting with `rahul/`
- anything containing a slash (`worktree-foo/bar`, `feature/x`)
- branches that don't match the random-word pattern

## notes

- branch rename is a cheap metadata operation — no commit history is rewritten
- do not run `git worktree move` — directory move breaks the current session's cwd
- the directory name (`kind-matsumoto-bdf245/`) stays as-is and only the branch renames
