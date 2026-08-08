# ship-config workflow implementation plan

> **for agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. steps use checkbox (`- [ ]`) syntax for tracking.

**goal:** encode the end-to-end "ship a config change" workflow into a new `/ship-config` skill plus corrections to `/nix-rebuild`, claude.md, settings, the downstream overlay, and project memory.

**architecture:** personal repo gets a new skill file + wiring line + corrected skill/instruction files (all downstream-generic wording per `CLAUDE-personal-scope.md`). the downstream repo gets the concrete precedence note and a lock bump in one cascade commit. the change ships through the very workflow it encodes (worktree → pr → pre-merge closure test → squash merge → cascade → rebuild → verify → delegated cleanup).

**tech stack:** nix (home-manager/nix-darwin), claude code skills (markdown), jq-merged settings json, gh cli, omz git aliases.

**spec:** `docs/superpowers/specs/2026-06-12-ship-config-workflow-design.md`

---

## file map

| file | action | repo |
|------|--------|------|
| `dotfiles/claude/skills/ship-config/SKILL.md` | create | personal |
| `os-configs/base.nix` | modify (add 1 wiring line after line 36) | personal |
| `dotfiles/claude/skills/nix-rebuild/SKILL.md` | rewrite | personal |
| `dotfiles/claude/settings-mac.json` | rewrite (currently `{}`) | personal |
| `dotfiles/claude/CLAUDE-base.md` | modify (4 edits) | personal |
| `dotfiles/claude/CLAUDE-mac.md` | modify (1 edit) | personal |
| `dotfiles/claude/CLAUDE-work.md` | modify (precedence note + esudo) | downstream |
| `flake.lock` | lock bump via `nix flake update personal-config` | downstream |
| `~/.claude/projects/-Users-rvadaga--config-home-manager/memory/feedback_personal_repo_push.md` | rewrite | memory (not a repo) |
| `~/.claude/projects/-Users-rvadaga--config-home-manager/memory/MEMORY.md` | update index line | memory (not a repo) |

note: this machine is `work-laptop` (rebuilds from the downstream flake at `~/.config/work-home-manager`). the plan writes downstream-generic text into personal-repo files but uses the concrete downstream path in *commands run on this machine*.

---

### task 1: create isolated worktree

- [ ] **step 1: create worktree with a meaningful branch off latest main**

```bash
git -C ~/.config/home-manager fetch origin main
git -C ~/.config/home-manager worktree add ~/.config/home-manager/.claude/worktrees/ship-config-skill -b rahul/ship-config-skill origin/main
```

expected: `Preparing worktree (new branch 'rahul/ship-config-skill')`. branch name is already meaningful — no `/wt-name` needed. all subsequent file edits happen under `~/.config/home-manager/.claude/worktrees/ship-config-skill/` (referred to as `$WT` below; spell the absolute path in commands).

### task 2: create ship-config skill

**files:**
- create: `$WT/dotfiles/claude/skills/ship-config/SKILL.md`

- [ ] **step 1: write the file with exactly this content**

````markdown
# /ship-config

ship a config change from a worktree to main: draft pr → pre-merge closure test → squash merge → cascade → rebuild → verify → cleanup. fully autonomous once the pre-merge test passes — test pass is merge authorization.

use this when asked to "ship", "land", or "merge" config work, or when finishing any worktree-based change in this repo. without explicit shipping approval, use `/nix-rebuild`; it opens a reviewable draft pull request and waits for approval before merging.

## workflow

1. **preflight**
   - `gfo main` (git fetch origin main — never fetch all branches), then `grbom` (git rebase origin/main)
   - if the branch matches the auto-name pattern `^(rahul/)?[a-z]+-[a-z]+(-[a-f0-9]{6})?$`, run `/wt-name` before anything else — pushes from auto-named branches are hook-rejected

2. **commit** — repo commit style, lower case, no ai-attribution trailers

3. **draft pr**
   - `gpsup` (git push --set-upstream origin <branch>)
   - `gh pr create --draft` using the repo's pr template (fallback: `~/development/.github/pull_request_template.md`); no ai-generated footer

4. **pre-merge test** — build the full closure through the flake this machine rebuilds from (check `$HM_CONFIG_NAME` and machine-specific instructions):
   - machine rebuilds from a downstream flake:
     ```bash
     darwin-rebuild build --flake <downstream-repo>#$HM_CONFIG_NAME \
       --override-input personal-config path:<worktree>
     ```
   - machine rebuilds directly from this flake:
     ```bash
     darwin-rebuild build --flake <worktree>#$HM_CONFIG_NAME       # macos
     home-manager build --flake <worktree>#$HM_CONFIG_NAME         # linux
     ```
   - **verify the artifact, not just the exit code.** locate the changed artifact in `./result`'s closure and assert the changed value, e.g. for claude settings:
     ```bash
     M=$(nix-store -qR ./result | grep claude-settings-nix-merged)
     python3 -c "import json; print(json.load(open('$M')).get('<key>'))"
     ```
   - **settings precedence check**: settings pieces merge base → os piece → downstream piece; later pieces win scalar conflicts. when changing a scalar in `settings-base.json` or an os piece, grep later pieces for the same key — if present, bump them in the same ship or the change is silently overridden
   - test fails → fix and re-test. never merge a failing branch.

5. **merge** (no confirmation gate after a passing test)
   - `gh pr ready <n>`, then `gh pr merge <n> --squash --subject "<commit msg>" --body ""`
   - `gpod <branch>` (git push origin --delete)
   - fast-forward local main without `cd`: `git -C <main-repo> fetch origin main && git -C <main-repo> merge --ff-only origin/main`

6. **cascade** — if machine-specific instructions define a downstream config consuming this flake as `personal-config`: bump its lock, commit, push (/nix-rebuild steps 4–5). fold any downstream-side edits identified in step 4 into the same commit.

7. **rebuild** — switch from the flake this machine rebuilds from. macos activation requires root: use the machine-mandated sudo wrapper if one exists, plain sudo otherwise.
   - known failure: the homebrew activation step aborts with a stale-api-cache message ("have not updated today") → run `brew update`, retry the switch once. still failing → stop and report.

8. **verify** (evidence before claims)
   - `cat /etc/nix-config-provenance` — rev equals the rebuilt repo's HEAD, tree clean (macos)
   - `readlink /run/current-system` equals the freshly built path
   - the changed artifact carries the new value (step-4 check against the real lock)
   - where the change flows into a live-merged file, confirm the merge ran (target file mtime)

9. **cleanup (mandatory last step)** — once verified, delegate worktree removal per the cleanup foot-gun instructions in global claude.md: an `Agent` with `isolation: "worktree"` runs `git -C <main-repo> worktree remove --force <worktree>` then `git -C <main-repo> branch -D <branch>`. no shell commands in this session afterward — only the final summary.

## notes

- track steps with the task tools — cross-repo state is easy to lose mid-pipeline
- if anything in steps 5–8 fails in a way you cannot fix, stop and report. never leave main broken silently.
- use omz git aliases with the full command in the bash tool's `description` field
````

### task 3: wire the skill into nix

**files:**
- modify: `$WT/os-configs/base.nix` (after the existing nix-rebuild line)

- [ ] **step 1: add the wiring line**

old:
```nix
      ".claude/skills/nix-rebuild/SKILL.md".source = ../dotfiles/claude/skills/nix-rebuild/SKILL.md;
```
new:
```nix
      ".claude/skills/nix-rebuild/SKILL.md".source = ../dotfiles/claude/skills/nix-rebuild/SKILL.md;
      ".claude/skills/ship-config/SKILL.md".source = ../dotfiles/claude/skills/ship-config/SKILL.md;
```

### task 4: rewrite nix-rebuild skill

**files:**
- rewrite: `$WT/dotfiles/claude/skills/nix-rebuild/SKILL.md`

- [ ] **step 1: replace the whole file with exactly this content**

````markdown
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
````

### task 5: settings-mac.json

**files:**
- rewrite: `$WT/dotfiles/claude/settings-mac.json` (currently `{}`)

- [ ] **step 1: replace the file with exactly this content**

```json
{
  "permissions": {
    "allow": [
      "Bash(brew update)"
    ]
  }
}
```

### task 6: CLAUDE-base.md edits

**files:**
- modify: `$WT/dotfiles/claude/CLAUDE-base.md`

- [ ] **step 1: update the override-input bullet (line 27)**

old:
```
    * only use `--override-input` for significant `*.nix` file changes that warrant local testing before pushing
```
new:
```
    * use `--override-input` for significant `*.nix` file changes and whenever a change should be validated before pushing or merging (pre-merge testing — see /ship-config and /nix-rebuild)
```

- [ ] **step 2: replace the ship-mechanics block (lines 33–43, the bullet starting "shipping a worktree to main" through the closing code fence and its last sub-bullet before the cleanup foot-gun) with the trigger bullet, and promote the cleanup foot-gun to its own top-level bullet**

old (the full bullet from `* shipping a worktree to main` down to and including the `git push origin --delete <branch>` code block line and its closing fence, plus the `    * **cleanup foot-gun` sub-bullet prefix):
```
* superseded direct-default-branch workflow. follow the assembled `CLAUDE.md`: publish a branch, open a draft pull request, and merge through that pull request.
```
new:
```
* shipping a config change from a worktree ("ship it", "land this", "squash merge") → invoke the `/ship-config` skill. pr + squash merge is the default; the skill covers pr creation, pre-merge closure testing, merge, cascade, rebuild, verification, and worktree cleanup, and proceeds autonomously once the pre-merge test passes.
* **worktree cleanup foot-gun (claude-code-specific)**:
```
(the remainder of the foot-gun sentence stays untouched; append to the end of that same bullet: ` always run this cleanup as the absolute last action once worktree work has landed on main.`)

- [ ] **step 3: scrub the two downstream mentions**

old:
```
* downstream configs (work) must opt in by importing `inputs.personal-config.darwinModules.provenance`
```
new:
```
* downstream configs must opt in by importing `inputs.personal-config.darwinModules.provenance`
```

old:
```
the personal/base config (`~/.config/home-manager`) can be imported as a flake input by other configs (e.g., work-specific configs). on machines with layered configs:
```
new:
```
the personal/base config (`~/.config/home-manager`) can be imported as a flake input by downstream configs. on machines with layered configs:
```

### task 7: CLAUDE-mac.md edit

**files:**
- modify: `$WT/dotfiles/claude/CLAUDE-mac.md`

- [ ] **step 1: generalize the downstream rebuild line**

old:
```
* for work mac: use the work flake path (see work-specific instructions)
```
new:
```
* for machines built from a downstream flake: use that flake's path (see machine-specific instructions)
```

### task 8: commit, push, draft pr

- [ ] **step 1: commit (single coherent change)**

```bash
gaa && gcmsg "claude: add /ship-config skill + ship-workflow corrections"
```

- [ ] **step 2: push and open draft pr**

```bash
gpsup
gh pr create --draft --title "claude: add /ship-config skill + ship-workflow corrections" --body "<template-based body>"
```

body uses `~/development/.github/pull_request_template.md` sections: description (new /ship-config skill; nix-rebuild corrections — root/sudo wrapper, override-input stance, precedence warning, brew self-heal, artifact verification, cleanup rule; brew update perm in settings-mac.json; claude-base/mac slimming + personal-scope scrub), context (spec path; encodes the 2026-06-12 session learnings), testing (override-input closure build + artifact checks below), impact (skills/instructions only; no behavior change to built systems beyond one permission line).

### task 9: pre-merge test + artifact verification

- [ ] **step 1: build through the downstream flake against the worktree**

```bash
darwin-rebuild build --flake ~/.config/work-home-manager#$HM_CONFIG_NAME \
  --override-input personal-config path:/Users/rvadaga/.config/home-manager/.claude/worktrees/ship-config-skill
```
expected: exit 0.

- [ ] **step 2: assert the new skill is in the built home files**

```bash
HMF=$(nix-store -qR ./result | grep -m1 home-manager-files)
gls "$HMF/.claude/skills/ship-config/"
```
expected: `SKILL.md`. (if the `home-manager-files` name doesn't match, find it via `nix-store -qR ./result | grep home-manager`.)

- [ ] **step 3: assert the brew permission is in the merged settings artifact**

```bash
M=$(nix-store -qR ./result | grep claude-settings-nix-merged)
python3 -c "import json; print('Bash(brew update)' in json.load(open('$M'))['permissions']['allow'])"
```
expected: `True`.

### task 10: squash merge + branch cleanup

- [ ] **step 1: merge**

```bash
gh pr ready <n>
gh pr merge <n> --squash --subject "claude: add /ship-config skill + ship-workflow corrections" --body ""
gh pr view <n> --json state,mergeCommit
```
expected: `"state": "MERGED"`.

- [ ] **step 2: delete remote branch, fast-forward local main**

```bash
gpod rahul/ship-config-skill
git -C ~/.config/home-manager fetch origin main
git -C ~/.config/home-manager merge --ff-only origin/main
```

### task 11: cascade to the downstream repo

**files:**
- modify: `~/.config/work-home-manager/dotfiles/claude/CLAUDE-work.md`

- [ ] **step 1: add the concrete precedence note after the lock-bump paragraph (line 51)**

old:
```
the work flake pins personal-config by git revision. for most changes to personal config, just commit, push, update the lock (`nix flake update personal-config` in the work-home-manager repo), and rebuild. only use `--override-input` for significant `.nix` file changes that need local testing.
```
new:
```
the work flake pins personal-config by git revision. for most changes to personal config, just commit, push, update the lock (`nix flake update personal-config` in the work-home-manager repo), and rebuild. use `--override-input` for significant `.nix` file changes and pre-merge validation of personal-config branches (see /ship-config).

**settings precedence**: `settings-work.json` merges after personal `settings-base.json` and the os pieces (`settings-mac.json` etc.) — it wins scalar conflicts. when a scalar key (e.g. `model`) is bumped in the personal repo and also exists in `settings-work.json`, bump it here in the same cascade, or the personal change is silently overridden on work machines.
```

- [ ] **step 2: add esudo to the work rebuild commands**

old:
```
  darwin-rebuild switch --flake ~/.config/work-home-manager#$HM_CONFIG_NAME
```
new:
```
  esudo darwin-rebuild switch --flake ~/.config/work-home-manager#$HM_CONFIG_NAME
```
(macos block only — the linux `home-manager switch` line stays as is.)

- [ ] **step 3: lock bump + single cascade commit + push**

```bash
nix flake update personal-config --flake ~/.config/work-home-manager
git -C ~/.config/work-home-manager add -A
git -C ~/.config/work-home-manager commit -m "bump personal-config: ship-config workflow; precedence note + esudo rebuild commands"
git -C ~/.config/work-home-manager push
```
verify the lock rev equals the squash-merge commit:
```bash
python3 -c "import json; print(json.load(open('/Users/rvadaga/.config/work-home-manager/flake.lock'))['nodes']['personal-config']['locked']['rev'])"
```

### task 12: switch + verify

- [ ] **step 1: switch**

```bash
esudo darwin-rebuild switch --flake ~/.config/work-home-manager#$HM_CONFIG_NAME
```
if the homebrew step aborts with the stale-cache message: `brew update`, then retry once.

- [ ] **step 2: verify with fresh evidence**

```bash
darwin-rebuild build --flake ~/.config/work-home-manager#$HM_CONFIG_NAME && echo "built:  $(readlink result)" && echo "active: $(readlink /run/current-system)"
cat /etc/nix-config-provenance && git -C ~/.config/work-home-manager rev-parse HEAD
gls ~/.claude/skills/ship-config/
python3 -c "import json; print('Bash(brew update)' in json.load(open('/Users/rvadaga/.claude/settings.json'))['permissions']['allow'])"
```
expected: built == active; provenance rev == downstream HEAD; `SKILL.md` listed; `True` (arrays union-merge into live settings).

### task 13: memory updates (Write tool — no repo, no rebuild)

- [ ] **step 1: do not create a separate repository-publication memory. the assembled `CLAUDE.md` is the canonical rule and requires a pull request for every default-branch change.**

- [ ] **step 2: update the MEMORY.md index line**

old:
```
- [Repository publication policy] — see assembled `CLAUDE.md`
```
new:
```
- [Repository publication policy] — see assembled `CLAUDE.md`
```

### task 14: delegated worktree cleanup (absolute last action)

- [ ] **step 1: delegate to an isolated agent**

dispatch an `Agent` with `isolation: "worktree"`, prompt (self-contained):
- `git -C /Users/rvadaga/.config/home-manager worktree remove --force /Users/rvadaga/.config/home-manager/.claude/worktrees/ship-config-skill`
- `git -C /Users/rvadaga/.config/home-manager branch -D rahul/ship-config-skill`
- verify with `git -C /Users/rvadaga/.config/home-manager worktree list` and `git -C /Users/rvadaga/.config/home-manager branch --list 'rahul/*'`; report verbatim.

- [ ] **step 2: no shell commands afterward** — only the final summary message.

---

## self-review notes

- spec coverage: component 1 → task 2+3; component 2 → task 4; component 3 → task 5; component 4 → tasks 6–7; component 5 → task 11; component 6 → task 13; spec "testing" section → tasks 9 + 12; mandatory cleanup decision → task 14.
- the auto-mode push hook reads the branch name; `rahul/ship-config-skill` does not match the auto-name pattern (third word group is not 6-char hex), so pushes are allowed.
- task 11 also fixes the downstream overlay's stale plain `darwin-rebuild switch` (esudo now required) — in scope as a workflow correction validated this session.
