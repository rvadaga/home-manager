---
name: nix-rebuild
description: Use when making any change to nix config files (home-manager, nix-darwin, CLAUDE.md, settings, dotfiles, skills, commands). Covers the edit-commit-push-rebuild workflow and downstream flake updates.
---

# /nix-rebuild

commit, push, and rebuild after nix config changes. handles this config and downstream configs that consume it as a flake input (`personal-config`).

shipping a worktree-based change? use /ship-config instead — it wraps these steps with pr creation, pre-merge testing, and worktree cleanup.

## edit in a throwaway worktree (preferred)

prefer making the config edits in a temp worktree, not the primary checkout. this is mandatory when /nix-rebuild is invoked from an external project session (never edit the primary checkout from an unrelated session) and the right call when other sessions or rebuilds may be using the primary checkout. editing the primary directly is acceptable only when the session is already working there and nothing else is using it.

1. **create the worktree** off fresh origin/main:
   ```bash
   git -C ~/.config/home-manager fetch origin main
   git -C ~/.config/home-manager worktree add \
     ~/.config/home-manager/.claude/worktrees/nix-rebuild-<topic> \
     -b rahul/nix-rebuild-<topic> origin/main
   ```
2. **edit + commit in the worktree**, then push straight to main (no pr — /nix-rebuild is for small direct-to-main changes; anything needing review goes through /ship-config):
   ```bash
   git -C <worktree> push origin HEAD:main
   ```
   push rejected (non-ff) → fetch origin main, rebase the worktree onto origin/main, retry once.
3. **rebuild using `<worktree>` as the flake path** (workflow steps 3–5 below) — leaves the primary checkout untouched; provenance lands on the pushed main rev.
4. **clean up only after a successful rebuild + verification** (rebuild failed → leave the worktree in place for debugging):
   ```bash
   git -C ~/.config/home-manager worktree remove ~/.config/home-manager/.claude/worktrees/nix-rebuild-<topic>
   git -C ~/.config/home-manager branch -D rahul/nix-rebuild-<topic>
   git -C ~/.config/home-manager fetch origin main && git -C ~/.config/home-manager merge --ff-only origin/main   # skip if the primary checkout is dirty or another session is using it
   ```
   plain bash is safe here only because the session's registered cwd is elsewhere (external project or primary checkout). if the session's cwd IS the worktree being removed, run the whole removal in one bash invocation via `git -C ~/.config/home-manager` as the session's last bash action (no shell afterward) per the cleanup foot-gun in global claude.md — never with an `isolation: "worktree"` agent, which is guard-refused from `git -C` and won't run the removal. scope: remove only the worktree this invocation created — never other worktrees.

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
