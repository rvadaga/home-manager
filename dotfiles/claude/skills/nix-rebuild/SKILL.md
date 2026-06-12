---
name: nix-rebuild
description: Use when making any change to nix config files (home-manager, nix-darwin, CLAUDE.md, settings, dotfiles, skills, commands). Covers the edit-commit-push-rebuild workflow and downstream flake updates.
---

# /nix-rebuild

commit, push, and rebuild after nix config changes. handles this config and downstream configs that consume it as a flake input (`personal-config`).

shipping a worktree-based change? use /ship-config instead — it wraps these steps with pr creation, pre-merge testing, and worktree cleanup.

## workflow

1. **determine scope** — which repo was modified:
   - this repo (`~/.config/home-manager`) → base config
   - a downstream config repo (path comes from machine-specific instructions) → skip to step 5
   - both → base first, then downstream

2. **commit and push base config** (from the repo)
   ```bash
   gaa && gcmsg "<describe change>"  # git add -A && git commit -m
   gp                                 # git push
   ```

3. **rebuild base config** (only if this machine rebuilds directly from this flake)
   ```bash
   sudo darwin-rebuild switch --flake ~/.config/home-manager#$HM_CONFIG_NAME   # macos — activation requires root; use the machine-mandated sudo wrapper if one exists
   home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME          # linux
   ```

4. **if this machine rebuilds from a downstream flake**, update its lock (downstream repo path from machine-specific instructions):
   ```bash
   nix flake update personal-config --flake <downstream-repo>
   git -C <downstream-repo> add -A
   git -C <downstream-repo> commit -m "bump personal-config: <describe change>"
   git -C <downstream-repo> push
   ```

5. **rebuild with the downstream flake**
   ```bash
   sudo darwin-rebuild switch --flake <downstream-repo>#$HM_CONFIG_NAME   # macos — root required; use the machine-mandated sudo wrapper if one exists
   home-manager switch --flake <downstream-repo>#$HM_CONFIG_NAME          # linux
   ```
   known failure: the homebrew activation step aborts with a stale-api-cache message ("have not updated today") → run `brew update`, retry the switch once. still failing → stop and report.

6. **verify — artifact-level, not vibes**
   - macos: `cat /etc/nix-config-provenance` — rev must equal the rebuilt repo's HEAD with a clean tree (`nix-provenance` compares against `pwd`'s git state)
   - claude settings changes: assert the changed key in the merged artifact
     ```bash
     M=$(nix-store -qR /run/current-system | grep claude-settings-nix-merged)
     python3 -c "import json; print(json.load(open('$M')).get('<key>'))"
     ```
   - tools/scripts/skills: `which <tool>`, `ls ~/.claude/skills/`
   - live `~/.claude/settings.json` is an additive merge: live wins scalar conflicts, arrays union-merge. a nix-side scalar change may be invisible live — the closure artifact is the truth about what nix ships.

## settings precedence (scalar bumps)

settings pieces merge in order: `settings-base.json` → os piece (`settings-mac.json` / `settings-linux.json` / `settings-nixos.json`) → downstream piece. later pieces win scalar conflicts. when changing a scalar key in an earlier piece, grep the later pieces for the same key — if present, bump them in the same change or the edit is silently overridden.

## pre-merge testing with `--override-input`

use whenever a change should be validated before pushing or merging (and always for significant `*.nix` changes):

```bash
darwin-rebuild build --flake <downstream-repo>#$HM_CONFIG_NAME \
  --override-input personal-config path:$HOME/.config/home-manager   # or path:<worktree>
```

`build` never activates — safe any time. then verify the changed artifact in `./result`'s closure (step 6).

## important notes

- check `$HM_CONFIG_NAME` to determine which flake this machine rebuilds from
- skip `exec $SHELL` — claude code's shell snapshot won't update mid-conversation
- CLAUDE.md is a read-only symlink — edit source files in `dotfiles/claude/`, not the symlink
- use omz git aliases with the full command in the bash tool's `description` field
- if this session ran from a claude worktree and the work has landed on main, finish with the worktree cleanup delegation per global claude.md (isolated agent, absolute last action)
