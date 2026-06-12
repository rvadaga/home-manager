---
name: ship-config
description: Use when shipping, landing, or squash-merging a config change from a worktree to main. Covers draft pr, pre-merge closure testing, squash merge, downstream cascade, rebuild, verification, and worktree cleanup — autonomous once tests pass.
---

# /ship-config

ship a config change from a worktree to main: draft pr → pre-merge closure test → squash merge → cascade → rebuild → verify → cleanup. fully autonomous once the pre-merge test passes — test pass is merge authorization.

use this when asked to "ship", "land", or "merge" config work, or when finishing any worktree-based change in this repo. for quick edits made directly on main, use /nix-rebuild instead.

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
