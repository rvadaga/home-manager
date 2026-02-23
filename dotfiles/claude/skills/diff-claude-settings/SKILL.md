# /diff-claude-settings

read-only comparison of live `~/.claude/settings.json` against nix source files.

## steps

1. read `~/.claude/settings.json` (live file)
2. read all source files: `dotfiles/claude/settings-{base,linux,nixos,mac}.json`
3. mentally merge the source files (base + os-specific for current platform) to reconstruct what nix would produce
4. compare against the live file and report:
   - **in live but not in dotfiles:** keys, permissions, plugins, mcp servers that exist in the live file but are missing from the source files
   - **in dotfiles but not in live:** entries in source files that are absent from the live file
   - **conflicts:** values that differ between live and source files
5. present findings clearly, grouped by category

## important notes

- this is read-only — do NOT modify any files
- do NOT touch `settings.local.json`
- check `$HM_CONFIG_NAME` or system type to determine which os-specific file applies
- suggest running `/sync-claude-settings` if there are differences the user wants to propagate
