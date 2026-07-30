---
name: clean-plugins
description: Use when claude code has leftover or unwanted plugins installed — plugins present in a project but absent from desired-plugins.json, plugin cruft accumulated across project paths, or a request to audit what is installed where.
---

# /clean-plugins

list all projects where claude code has plugins installed, and clean up plugins not in `desired-plugins.json`.

## steps

1. read `~/.claude/plugins/installed_plugins.json`
2. read `~/.config/home-manager/dotfiles/claude/desired-plugins.json` (source of truth for wanted plugins)
3. collect all unique `projectPath` values from installed_plugins.json
4. present a summary:
   - **projects:** list all unique project paths with the number of plugins installed in each
   - **wanted plugins:** list from `desired-plugins.json`
   - **unwanted plugins:** installed plugins whose key is NOT in `desired-plugins.json` — grouped by project path
5. if there are unwanted plugins, ask the user for confirmation before uninstalling
6. to uninstall, run `claude plugin uninstall "<plugin-name>@<marketplace>" --scope local` from each relevant project path (must `cd` into the `projectPath` first — the CLI requires this)
7. after uninstalling, re-read `installed_plugins.json` to verify and report the final state

## important notes

- this is a destructive operation — always ask before uninstalling
- the `claude plugin uninstall` command requires `CLAUDECODE=` prefix to avoid nested-session errors
- the `--scope local` flag is required for plugins installed with `"scope": "local"`
- the CLI is directory-sensitive: you must `cd` into the `projectPath` before running uninstall for that project's entries
- plugins can have entries under multiple project paths — uninstall from each path separately
- do NOT modify `settings.json`, `settings.local.json`, or `installed_plugins.json` directly
