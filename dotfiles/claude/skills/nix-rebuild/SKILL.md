---
name: nix-rebuild
description: Use when making any change to nix config files (home-manager, nix-darwin, CLAUDE.md, settings, dotfiles, skills, commands). Covers the worktree → draft PR → approval → merge → rebuild workflow and downstream flake updates. A config change NEVER lands directly on main.
---

# /nix-rebuild

ship a nix config change the reviewable way: ALWAYS in a worktree, ALWAYS through a draft PR, merged to main ONLY after rahul says it looks ok — then rebuild. handles this config and downstream configs that consume it as a flake input (`personal-config`).

**the invariant (non-negotiable): a config change NEVER lands directly on main.** no `git push origin HEAD:main`, no committing on the primary checkout's `main`, no "it's small so I'll skip the pr." every change goes worktree → branch → draft PR → rahul's ok → merge. the pr is what makes the change reviewable BEFORE it's live; the direct-to-main shortcut is exactly the mistake this skill exists to prevent.

**/nix-rebuild vs /ship-config:** both go worktree → draft pr → merge. /nix-rebuild is the DEFAULT and STOPS for rahul's "looks ok" before merging (human gate). /ship-config is for an explicit "ship it / land this / squash merge" and proceeds autonomously once the pre-merge test passes (the explicit command IS the approval). when in doubt, use /nix-rebuild and wait.

## 1. worktree — ALWAYS (never edit the primary checkout)

determine scope first: this repo (`~/.config/home-manager`) = base config · a downstream config repo (path from machine-specific instructions) = downstream · both = base first, then downstream. create the worktree off fresh origin/main in the repo being changed:

```bash
git -C ~/.config/home-manager fetch origin main
git -C ~/.config/home-manager worktree add \
  ~/.config/home-manager/.claude/worktrees/nix-rebuild-<topic> \
  -b rahul/nix-rebuild-<topic> origin/main
```

make ALL edits in the worktree — never edit/commit on the primary checkout, even when the session is already sitting in it (a parallel rebuild or session may be using it, and it's the direct-to-main foot-gun). CLAUDE.md is a read-only symlink — edit sources under `dotfiles/claude/`.

## 2. edit + commit + push the BRANCH (never main)

commit signed (don't `--no-gpg-sign`); push the branch to its OWN ref, never to `main`:

```bash
git -C <worktree> add -A && git -C <worktree> commit -m "<describe change>"
git -C <worktree> push -u origin rahul/nix-rebuild-<topic>
```

before any source push or pull request metadata or body edit, rederive and preserve the live pull request state under the shared rule in `CLAUDE.md`. an existing published ordinary branch follows the canonical local-first rule there. a github-managed stack follows `github-stacked-prs` for full-stack synchronization, publication, and merge selection; never apply the ordinary merge-main procedure or `gh pr update-branch` to one stack layer. a rejected push or unexpected remote movement is a stop signal.

## 3. open a DRAFT pr

```bash
gh pr create --repo <owner>/<repo> --draft --base main --head rahul/nix-rebuild-<topic> \
  --title "<terse lowercase title>" --body "<fill the repo's PR template; if none, ~/development/.github/pull_request_template.md>"
```

no AI-attribution trailer/footer. read the template from the repo (or the fallback) and actually fill it.

## 4. validate before asking (pre-merge)

- docs / skills / CLAUDE.md / settings-markdown change → the PR DIFF is the reviewable artifact; no rebuild needed to review it.
- change under `dotfiles/claude/skills/**` → ALSO validate the skill locally before surfacing the pr — the diff shows wording, not frontmatter schema, and a `skills-ref` ci gate is landing that turns invalid frontmatter into a red ci:
  ```bash
  npx -y skills-ref@0.1.5 validate dotfiles/claude/skills/<skill-name>/
  ```
  prints `Valid skill: <path>` and exits 0 on success. keep the version pinned — that's what ci runs.
- `*.nix` / behavior change → build (never activates, safe any time) and verify the changed artifact in `./result`'s closure (see §verify). for a downstream flake, point it at the worktree:
  ```bash
  darwin-rebuild build --flake <downstream-repo>#$HM_CONFIG_NAME \
    --override-input personal-config path:<worktree>
  ```

## 5. STOP — surface the pr, wait for rahul's "looks ok"

give him the pr link + a one-line what-changed + the validation result. do NOT merge until he says it looks ok. this human gate is the whole point of the skill — never auto-merge here (that's /ship-config's job, on an explicit ship command).

## 6. on approval — merge, rebuild, verify, clean up

1. **merge through the branch's workflow.** a github-managed stack uses `github-stacked-prs`; preserve its live states and select only a live ready bottom layer. for an ordinary pull request, rederive its live state under the shared `CLAUDE.md` rule. if it is draft, the approval for this merge authorizes `gh pr ready`; if it is already ready, preserve that state without a duplicate confirmation or ready command. then merge it (squash is the default):
   ```bash
   gh pr ready <n> --repo <owner>/<repo>
   gh pr merge <n> --repo <owner>/<repo> --squash
   ```
   then confirm it actually landed — a refused merge leaves the pr open and is easy to skim past:
   ```bash
   gh pr view <n> --repo <owner>/<repo> --json state,mergedAt   # want state=MERGED + non-null mergedAt
   ```
2. **rebuild** from the now-updated main, using the flake this machine actually rebuilds from (`$HM_CONFIG_NAME` selects the config):
   ```bash
   sudo darwin-rebuild switch --flake ~/.config/home-manager#$HM_CONFIG_NAME   # macos — root; use the machine's sudo wrapper (esudo on work)
   home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME          # linux
   ```
   downstream machine → after the base pr merges, bump the downstream lock (`nix flake update personal-config`) and rebuild with the downstream flake. that lock bump is itself a config change → its own worktree → draft pr → ok → merge (or fold both into one review when the change spans both repos). homebrew "have not updated today" abort → `brew update`, retry the switch once; still failing → stop and report.
3. **verify — artifact-level** (§verify).
4. **clean up** — only after a green rebuild + verify (rebuild failed → leave the worktree for debugging). remove ONLY the worktree this invocation created:
   ```bash
   git -C ~/.config/home-manager worktree remove --force <worktree> && \
   git -C ~/.config/home-manager branch -D rahul/nix-rebuild-<topic>
   ```
   if THIS session's cwd IS the worktree, run the whole removal in ONE bash invocation via `git -C <main-checkout>` as the session's LAST bash action (no shell afterward) — the cleanup foot-gun in global claude.md; never an `isolation:"worktree"` agent (guard-refused from `git -C`).

## verify — artifact-level, not vibes

- macos: `nix-provenance` (or `cat /etc/nix-config-provenance`) — rev must equal the rebuilt main's HEAD with a clean tree.
- claude settings change: assert the changed key in the merged closure artifact
  ```bash
  M=$(nix-store -qR /run/current-system | grep claude-settings-nix-merged)
  python3 -c "import json; print(json.load(open('$M')).get('<key>'))"
  ```
- tools / scripts / skills: `which <tool>`, `ls ~/.claude/skills/`.
- live `~/.claude/settings.json` is an additive merge (live wins scalar conflicts, arrays union-merge) — a nix-side scalar change can be invisible live; the closure artifact is the truth about what nix ships.

## settings precedence (scalar bumps)

settings pieces merge in order: `settings-base.json` → os piece (`settings-mac.json` / `settings-linux.json` / `settings-nixos.json`) → downstream piece. later pieces win scalar conflicts. changing a scalar in an earlier piece → grep the later pieces for the same key and bump them in the SAME pr, or the edit is silently overridden.

## notes

- check `$HM_CONFIG_NAME` to determine which flake this machine rebuilds from.
- use omz git aliases with the full command in the bash tool's `description` field.
- skip `exec $SHELL` — claude code's shell snapshot won't update mid-conversation; changes land in the next conversation.
- once merged, rebuild without asking (the approval gate is at merge, not rebuild) unless the rebuild target is genuinely ambiguous.
