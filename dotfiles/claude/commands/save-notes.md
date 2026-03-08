---
allowed-tools: Bash(git *), Bash(mkdir *), Bash(ls *), Bash(echo $SCRATCHPAD_DIR)
description: save findings/notes from the current conversation to the scratchpad repo as markdown
---

## your task

save findings, analysis, or notes from the current conversation to the scratchpad repo as markdown.

## steps

1. determine scratchpad directory:
   - run `echo $SCRATCHPAD_DIR` to get the repo root directory
   - if not set or empty, tell the user to set it via home-manager (`sessionVariables.SCRATCHPAD_DIR`) and stop
   - notes go in `$SCRATCHPAD_DIR/claude-notes/`
2. if `$SCRATCHPAD_DIR` doesn't exist, clone the repo first:
   - extract the repo name from the path (last component of `$SCRATCHPAD_DIR`)
   - ask the user for the git clone URL (e.g., `git@github.com:rvadaga/scratchpad.git`)
   - clone to `$SCRATCHPAD_DIR`
3. create the notes directory if it doesn't exist: `mkdir -p $SCRATCHPAD_DIR/claude-notes`
4. list existing `.md` files in `$SCRATCHPAD_DIR/claude-notes/`
5. determine if the current topic matches an existing doc:
   - read the first 15 lines of each existing doc
   - if a doc covers the same topic or system, ask the user whether to:
     - **update** the existing doc (add/modify sections)
     - **create a new** separate doc
6. write the markdown file:
   - filename: kebab-case, descriptive (e.g., `vespa-metrics-pipeline.md`)
   - content: follow the user's lowercase writing conventions from CLAUDE.md
   - focus on durable knowledge: findings, architecture, code traces, key takeaways
   - do NOT include session-specific details (timestamps, conversation IDs, task progress)
7. if updating an existing doc and the scope has changed significantly:
   - suggest a new filename that better reflects the expanded scope
   - ask user for confirmation before renaming
   - use `git mv old-name.md new-name.md` to rename (preserves history)
8. auto commit and push (from `$SCRATCHPAD_DIR`):
   - `ga claude-notes/<file>` (git add)
   - `gcmsg "add/update <filename>"` (git commit --message)
   - `gp` (git push)
   - if push fails, warn the user but don't error out

## important notes

- use kebab-case for all filenames (e.g., `vespa-metrics-pipeline.md`)
- follow the user's lowercase writing conventions (from CLAUDE.md)
- when updating, preserve existing content structure — add/modify sections, don't rewrite from scratch unless asked
- use omz git aliases with inline comments showing the full command
