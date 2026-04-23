---
name: nix-rebuild
description: Use when making any change to nix config files (home-manager, nix-darwin, CLAUDE.md, settings, dotfiles, skills, commands). Covers the edit-commit-push-rebuild workflow and downstream flake updates.
---

# /nix-rebuild

commit, push, and rebuild after nix config changes. handles both personal and downstream (work) configs.

## workflow

1. **determine scope** — check which repo was modified:
   - `~/.config/home-manager/` → personal config
   - `~/.config/work-home-manager/` → work config (skip to step 5)
   - both → personal first, then work

2. **commit and push personal config**
   ```bash
   cd ~/.config/home-manager
   gaa && gcmsg "<describe change>"  # git add -A && git commit -m
   gp                                 # git push
   ```

3. **rebuild personal config** (only if on a personal machine or no downstream config)
   ```bash
   # check os:
   darwin-rebuild switch --flake ~/.config/home-manager#$HM_CONFIG_NAME   # macos
   home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME     # linux
   ```

4. **if a downstream config exists** (work machine), update the lock:
   ```bash
   cd ~/.config/work-home-manager
   nix flake update personal-config   # pulls the commit you just pushed
   gaa && gcmsg "bump personal-config"
   gp
   ```

5. **rebuild with the downstream flake**
   ```bash
   darwin-rebuild switch --flake ~/.config/work-home-manager#$HM_CONFIG_NAME  # macos
   home-manager switch --flake ~/.config/work-home-manager#$HM_CONFIG_NAME    # linux
   ```

6. **verify** — spot-check the change took effect (e.g., `which <tool>`, `cat ~/.claude/CLAUDE.md`, `ls ~/.claude/skills/`)

## when to use `--override-input`

only for significant `.nix` file changes that need local testing before pushing:

```bash
darwin-rebuild switch --flake ~/.config/work-home-manager#$HM_CONFIG_NAME \
  --override-input personal-config path:$HOME/.config/home-manager
```

skip `--override-input` for: CLAUDE.md edits, settings.json changes, new skills/commands, dotfile tweaks.

## important notes

- `$HM_CONFIG_NAME` values: `work-laptop`, `search-vm`, `irp-workstation`, `boromir-vm`
- skip `exec $SHELL` — claude code's shell snapshot won't update mid-conversation
- CLAUDE.md is a read-only symlink — edit source files in `dotfiles/claude/`, not the symlink
- settings.json uses additive merge — live values win on scalar conflicts
- use omz git aliases with full command in the bash tool's `description` field
