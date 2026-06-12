# ship-config workflow — design

date: 2026-06-12
status: approved-pending-review

## goal

encode the end-to-end "ship a config change" workflow (worktree → pr → test → squash merge → cascade → rebuild → verify → cleanup) into skills and instructions so it runs autonomously with minimal per-session guidance.

## decisions (user-confirmed)

* default ship path for worktree-based changes: **pr + squash merge**. direct push to main remains the norm for quick edits made directly on main.
* **fully autonomous** once the pre-merge test passes: test pass = merge authorization; merge, cascade, rebuild, verify, and cleanup proceed without further confirmation.
* `Bash(brew update)` is pre-allowed (mac-only) to self-heal the known homebrew stale-cache failure during `darwin-rebuild switch`. no broader brew allowances.
* worktree cleanup per global claude.md (delegated isolated agent, absolute last action) is a **mandatory final step** of the workflow, not optional.
* personal-repo content never names the downstream consumer. phrase as "a downstream config consuming this flake as input `personal-config`"; concrete repo paths and file names live in the downstream repo's own overlay instructions, which are loaded at runtime on those machines.

## components

### 1. new skill: `dotfiles/claude/skills/ship-config/SKILL.md`

triggers on shipping/landing/merging a config change from a worktree. steps:

1. **preflight** — fetch only main (`gfo main`), rebase onto `origin/main`. if the branch matches the auto-name pattern, run `/wt-name` before anything else (pushes from auto-named branches are hook-rejected).
2. **commit** — repo commit style, lower case, no ai attribution.
3. **draft pr** — `gpsup`, then `gh pr create --draft` using the repo's pr template (fallback: `~/development/.github/pull_request_template.md`). no ai-generated footer.
4. **pre-merge test** — build the full closure through the flake this machine rebuilds from. on machines built from a downstream flake, override this repo: `darwin-rebuild build --flake <downstream-flake>#$HM_CONFIG_NAME --override-input personal-config path:<worktree>`. on machines built directly from this flake, build from the worktree: `darwin-rebuild build --flake <worktree>#$HM_CONFIG_NAME` (or `home-manager build` on linux). then **verify the artifact, not just the exit code**: locate the changed artifact in the closure (e.g. `nix-store -qR ./result | grep claude-settings-nix-merged`) and assert the changed key's actual value.
   * **settings precedence check**: settings pieces merge base → os piece → downstream piece, later wins scalar conflicts. when changing a scalar in `settings-base.json` (or an os piece), grep the later pieces for the same key — if present, bump them in the same ship, or the change is silently overridden.
5. **merge** — `gh pr ready` → `gh pr merge --squash --subject "<commit msg>" --body ""` → delete remote branch (`gpod`) → fast-forward local main via `git -C` (never `cd` into the main repo).
6. **cascade** — if machine-specific instructions define a downstream config consuming this flake: update its `personal-config` lock, commit, push (see /nix-rebuild steps).
7. **rebuild** — `darwin-rebuild switch` / `home-manager switch` from the flake this machine rebuilds from. activation now requires root on macos: use the machine's sudo wrapper if one is mandated, plain sudo otherwise. if the switch fails in the homebrew activation step with a stale-api-cache message: run `brew update`, retry the switch once; if it still fails, stop and report.
8. **verify** — provenance stamp rev equals the rebuilt repo's HEAD with a clean tree; `readlink /run/current-system` equals the built path; the changed artifact carries the new value; live merge ran (target file mtime) where relevant.
9. **cleanup (mandatory, absolute last action)** — per global claude.md: delegate `git worktree remove --force` + `git branch -D` to an agent with `isolation: "worktree"`. no shell commands in the session afterward.

autonomy note in the skill: once step 4 passes, steps 5–9 run without asking.

### 2. corrections to `dotfiles/claude/skills/nix-rebuild/SKILL.md`

* scrub hardcoded downstream paths → downstream-generic wording (per personal-scope rule).
* rebuild commands gain root: sudo wrapper guidance as above.
* replace "skip `--override-input` for settings.json changes" with: use `--override-input` + closure artifact inspection whenever a change must be validated before push/merge; skip it only for live-iteration convenience.
* add the settings precedence warning (same text as ship-config step 4).
* add the brew stale-cache failure mode + self-heal.
* strengthen verification: artifact-level checks (merged settings json in closure, provenance) instead of only `which <tool>`.
* closing rule: if the session ran from a claude worktree and the work has landed on main, finish with the global-claude.md worktree cleanup delegation.
* pointer: shipping via pr → `/ship-config`.

### 3. permissions: `dotfiles/claude/settings-mac.json`

add `"Bash(brew update)"` to `permissions.allow`. mac-only by construction (piece is wired in `os-configs/mac.nix`); array union-merge applies it to live settings on rebuild.

### 4. claude.md slimming + scrub

* `CLAUDE-base.md`: move the "shipping a worktree to main" mechanics into the ship-config skill; replace with a two-line trigger ("shipping a config change from a worktree → invoke `/ship-config`; pr + squash merge is the default"). generalize the two "(e.g., work-specific configs)"-style mentions to "downstream configs".
* `CLAUDE-mac.md`: generalize the downstream-flake rebuild line ("for machines built from a downstream flake: use that flake's path — see machine-specific instructions").

### 5. downstream overlay note (separate commit in the downstream repo)

add the concrete precedence note to the downstream repo's overlay instructions: its settings piece wins scalar conflicts over `settings-base.json` and os pieces; scalar bumps in base must be mirrored there. concrete file names are fine in that repo.

### 6. project memory consistency

update the existing project memory note about push norms: pr + squash via `/ship-config` is the default for worktree-based ships; direct push to main remains the norm for quick edits made directly on main.

## out of scope

* broader brew allowances (`install`/`upgrade`).
* generalizing the ship pipeline to non-config repos.
* linux provenance stamp (still darwin-only).

## testing

ship this change itself through the new workflow: worktree → pr → pre-merge closure build with `--override-input` → artifact checks (new `SKILL.md` present in the built closure's skills dir; `brew update` present in the merged settings allow array) → squash merge → cascade → switch → verify → delegated cleanup.

## resolved during review

* `/wt-name` is a command, not a skill: source at `dotfiles/claude/commands/wt-name.md`, linked via `os-configs/base.nix`. ship-config references it by invocation name (`/wt-name`), which works for commands and skills alike.
