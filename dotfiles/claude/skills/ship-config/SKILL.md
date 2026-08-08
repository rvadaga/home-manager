---
name: ship-config
description: Use when shipping, landing, or squash-merging a config change from a worktree to main. Covers draft pr, pre-merge closure testing, squash merge, downstream cascade, rebuild, verification, and worktree cleanup — autonomous once tests pass.
---

# /ship-config

ship a config change from a worktree to main: draft pr → pre-merge closure test → squash merge → cascade → rebuild → verify → cleanup. fully autonomous once the pre-merge test passes — test pass is merge authorization.

use this when asked to "ship", "land", or "merge" config work, or when finishing any worktree-based change in this repo. for quick edits made directly on main, use /nix-rebuild instead.

## workflow

1. **preflight**
   - `gfo main` (git fetch origin main — never fetch all branches)
   - **branch not pushed yet → `grbom` (git rebase origin/main). branch already pushed → follow the canonical local-first published-branch rule in `CLAUDE.md`.** merge base into the owning local worktree, validate there, and push normally; do not rebase the published branch or use `gh pr update-branch`.
   - syncing at all is usually unnecessary: the main ruleset here does not require a branch to be up to date before merging (`strict_required_status_checks_policy: false`), so sync only when the branch genuinely needs main's changes.
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
   - **read the merge back in a separate call before doing anything destructive.** `gh pr merge` prints nothing when it succeeds, so its output alone cannot tell you whether it merged or was refused. the usual refusal here is a required check still running (currently `skills-ref validate`).
     ```bash
     gh pr view <n> --json state,mergedAt,headRefOid --jq '[.state,.mergedAt,.headRefOid]'
     ```
     want `MERGED`, a non-null `mergedAt`, and the sha you pushed. still-running check → wait for it and re-run the merge. auto-merge is not an option on this repo (`allow_auto_merge` is false, so `gh pr merge --auto` errors).
   - **only once that read says `MERGED`:** `gpod <branch>` (git push origin --delete). gate the delete on that read and nothing else — not on the merge command's silence, not on its exit status, and never by chaining the delete onto the merge. a refused merge with the delete running anyway leaves the branch deleted and the pr closed, recoverable only by re-pushing the identical sha and reopening.
   - fast-forward local main without `cd`: `git -C <main-repo> fetch origin main && git -C <main-repo> merge --ff-only origin/main`
   - keep that `gh pr view` output — deleting the branch retires the remote-ref form of the data-loss gate, so step 9 has to run on the merged-pr form.

6. **cascade** — if machine-specific instructions define a downstream config consuming this flake as `personal-config`: bump its lock, commit, push (/nix-rebuild steps 4–5). fold any downstream-side edits identified in step 4 into the same commit.

7. **rebuild** — switch from the flake this machine rebuilds from. macos activation requires root: use the machine-mandated sudo wrapper if one exists, plain sudo otherwise.
   - known failure: the homebrew activation step aborts with a stale-api-cache message ("have not updated today") → run `brew update`, retry the switch once. still failing → stop and report.

8. **verify** (evidence before claims)
   - `cat /etc/nix-config-provenance` — rev equals the rebuilt repo's HEAD, tree clean (macos)
   - `readlink /run/current-system` equals the freshly built path
   - the changed artifact carries the new value (step-4 check against the real lock)
   - where the change flows into a live-merged file, confirm the merge ran (target file mtime)

9. **cleanup (mandatory last step)** — once verified, remove the worktree.
   - **clear the data-loss gate first** (global claude.md): `git status --porcelain` empty, and every commit present somewhere other than this worktree. step 5 deleted the branch, so the remote-ref form of that gate is already retired — use the merged-pr form: `gh pr view <n> --json state,mergedAt,headRefOid` reading `MERGED` with `headRefOid` equal to this worktree's `git rev-parse HEAD`. the sha comparison is what catches a commit made after the merge.
   - then remove it per the cleanup foot-gun in global claude.md: run the whole removal in ONE bash invocation using `git -C <main-repo>` — `git -C <main-repo> worktree remove --force <worktree> && git -C <main-repo> branch -D <branch>` — as this session's absolute last bash action (no shell commands afterward, only the final summary), so no command depends on the doomed cwd. do NOT spawn this with `isolation: "worktree"` — an isolated agent is guard-refused from `git -C <main-repo>` and the removal will not run. scope: remove only the worktree being shipped — never enumerate or touch other worktrees; they belong to other sessions.

## notes

- track steps with the task tools — cross-repo state is easy to lose mid-pipeline
- if anything in steps 5–8 fails in a way you cannot fix, stop and report. never leave main broken silently.
- use omz git aliases with the full command in the bash tool's `description` field
