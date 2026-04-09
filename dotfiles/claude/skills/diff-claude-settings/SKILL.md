# /diff-claude-settings

read-only comparison of live `~/.claude/settings.json` against nix source files.

## steps

1. read `~/.claude/settings.json` (live file)
2. read all source files from `~/.config/home-manager/dotfiles/claude/`: `settings-{base,linux,nixos,mac}.json`
3. read `~/.config/home-manager/dotfiles/claude/desired-plugins.json`
4. check CLAUDE.md for any downstream config instructions that specify additional settings files to include
5. mentally merge all applicable source files (base + os-specific + any downstream) to reconstruct what nix would produce
6. compare against the live file and report:
   - **in live but not in dotfiles:** keys, permissions, mcp servers that exist in the live file but are missing from all source files
   - **in dotfiles but not in live:** entries in source files that are absent from the live file
   - **conflicts:** values that differ between live and source files
   - **plugin drift:** compare `enabledPlugins` in live settings against `desired-plugins.json` — report any differences (missing, extra, or changed enabled state)
7. present findings clearly, grouped by category

## important notes

- this is read-only — do NOT modify any files
- do NOT modify `settings.local.json`
- DO read `settings.local.json` and report any non-empty `permissions.allow` entries as "stale session permissions that should be routed to nix source files"
- `enabledPlugins` is NOT part of the nix merge — it lives in `desired-plugins.json` and is applied by `/bootstrap-plugins`. compare it separately from other settings
- check `$HM_CONFIG_NAME` or system type to determine which os-specific file applies
- suggest running `/sync-claude-settings` if there are differences the user wants to propagate
- suggest running `/bootstrap-plugins` if plugin drift is detected
