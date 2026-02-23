# /sync-claude-settings

export live `~/.claude/settings.json` back to nix source files in `dotfiles/claude/`.

## steps

1. read `~/.claude/settings.json` (live file)
2. read all source files: `dotfiles/claude/settings-{base,linux,nixos,mac}.json`
3. classify each `permissions.allow`, `permissions.deny`, and `permissions.ask` entry by keyword:
   - **linux:** spectacle, dbus-send, pgrep, fc-list, xdg, kde, xclip, xsel, wmctrl, xdotool, grep inet, ip route, man.archlinux.org
   - **nixos:** nixos-rebuild, nix-env, nix-store, nix-build, journalctl, systemctl, nix flake, nix profile, nix why-depends, sudo iptables, sudo nix
   - **mac:** open -a, pbcopy, pbpaste, defaults write, osascript, launchctl, diskutil, softwareupdate
   - **base:** everything else
4. route `enabledPlugins`, `mcpServers`, and all other top-level keys to base
5. write to dotfiles, lexicographically sorted
6. show diff, write on confirmation
7. remind user to commit/push

## important notes

- os-specific settings files should only contain `permissions` — all other keys go to base
- nix merges pieces with a custom deep merge that concatenates arrays, so os-specific permissions are additive (they don't replace base permissions)
- do NOT touch `settings.local.json` — it is not managed by nix
- do NOT touch `CLAUDE-*.md` files — they are separate
- preserve empty `{}` for os-specific files that have no permissions to route
- use the Read and Write tools, not shell commands, for file operations
