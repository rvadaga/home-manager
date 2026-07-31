---
name: sync-claude-settings
description: Use when settings changed live in ~/.claude/settings.json need writing back to the nix source files — session-approved permissions piling up in settings.local.json, mcp servers added live, or drift found by /diff-claude-settings.
---

# /sync-claude-settings

export live `~/.claude/settings.json` back to nix source files in `dotfiles/claude/`.

## steps

1. read `~/.claude/settings.json` (live file)
2. read all source files from `~/.config/home-manager/dotfiles/claude/`: `settings-{base,linux,nixos,mac}.json`
3. read `~/.config/home-manager/dotfiles/claude/desired-plugins.json`
4. check CLAUDE.md for any downstream config instructions that specify additional settings files to include and their routing rules
5. classify each `permissions.allow`, `permissions.deny`, and `permissions.ask` entry by keyword:
   - **linux:** spectacle, dbus-send, pgrep, fc-list, xdg, kde, xclip, xsel, wmctrl, xdotool, grep inet, ip route, man.archlinux.org
   - **nixos:** nixos-rebuild, nix-env, nix-store, nix-build, journalctl, systemctl, nix flake, nix profile, nix why-depends, sudo iptables, sudo nix
   - **mac:** open -a, pbcopy, pbpaste, defaults write, osascript, launchctl, diskutil, softwareupdate
   - **downstream:** route per downstream config instructions (if any)
   - **base:** everything else
6. classify top-level keys:
   - **enabledPlugins** → route to `desired-plugins.json` (NOT to settings-base.json — this key is not nix-managed)
   - route per downstream config instructions for keys that belong to a downstream settings file
   - **base:** `mcpServers` and all other top-level keys go to base by default
   - when a key exists in multiple files with different values, ask the user where it should go
7. write to dotfiles, lexicographically sorted
8. show diff, write on confirmation
9. remind user to commit/push — if downstream configs are in separate repos, note that each needs its own commit

## important notes

- `enabledPlugins` is NOT nix-managed — it lives in `desired-plugins.json` and is applied at runtime by `/bootstrap-plugins`. when syncing, write only the `enabledPlugins` object value (not wrapped in another key) to `desired-plugins.json`
- os-specific settings files should only contain `permissions` — all other keys go to base
- downstream config settings files may contain both permissions AND top-level keys — follow their routing rules
- nix merges pieces with a custom deep merge that concatenates arrays, so os-specific permissions are additive (they don't replace base permissions)
- do NOT modify `settings.local.json` — it is not managed by nix
- DO read `settings.local.json` and flag any non-empty `permissions.allow` entries — these are session-approved permissions that should be routed to the appropriate nix source file. after syncing them to dotfiles, clear the `permissions.allow` array in `settings.local.json`
- do NOT touch `CLAUDE-*.md` files — they are separate
- preserve empty `{}` for os-specific files that have no permissions to route
- use the Read and Write tools, not shell commands, for file operations
