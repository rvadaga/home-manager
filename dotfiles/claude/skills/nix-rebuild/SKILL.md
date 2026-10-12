---
name: nix-rebuild
description: use when changing nix config, managed instructions, settings, dotfiles, skills, or commands. carries authorized work through an isolated worktree, draft pr, validation, merge, activation, and downstream flake updates.
---

# /nix-rebuild

complete a nix config change in an isolated worktree and through a reviewable draft pr. handles this config and downstream configs that consume it as a flake input (`personal-config`).

## config task authorization

a request to install, update, or change config authorizes completing that task: isolated worktree → reviewable draft pr → passing validation → merge → activation → verification → cleanup. publish the pr link and validation results before merging, then continue without asking for another routine confirmation. a separate "looks ok" or shipping command is not required. keep the work within the requested scope, including any downstream lock update needed to use the change.

a request only to inspect, plan, prepare a draft, or wait for review does not authorize merge or activation. ask only for genuinely missing authorization or a decision needed to complete the task. stop for unexplained pr state or remote movement, unresolved ownership, or validation failures that cannot be fixed within scope. passing checks alone do not grant authorization.

every change must land through a pr. never edit or commit on the primary checkout's `main`, push directly to `main` or `master`, or bypass one-writer ownership or personal/work separation. preserve live draft/ready state and provenance under the shared `CLAUDE.md` rule. for an authorized ordinary config merge, mark only that pr ready immediately before merging; keep drafts outside that merge scope draft. an existing ready pr stays ready. github-managed stacks still use `github-stacked-prs` for readiness, publication, and merge selection.

activation follows the home/system rules below. a macos system activation still requires rahul to run or explicitly authorize the exact authenticated sudo command; task authorization does not bypass authentication.

`/nix-rebuild` starts config work; `/ship-config` finishes work already in a worktree. both use this authorization rule. keep the rule here so their approval requirements cannot drift apart.

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

## 4. validate before merging

- docs / skills / CLAUDE.md / settings-markdown change → review the full pr diff. a rebuild is still needed to activate managed instructions after merge.
- change under `dotfiles/claude/skills/**` → also validate the skill locally before publishing. the required `skills-ref` ci check validates frontmatter:
  ```bash
  npx -y skills-ref@0.1.5 validate dotfiles/claude/skills/<skill-name>/
  ```
  prints `Valid skill: <path>` and exits 0 on success. keep the version pinned — that's what ci runs.
- classify the evaluated outputs before choosing a build. a known home-only change builds the home-manager graph. a known system-only change builds the nix-darwin graph. a shared input or unclear change builds both. paths can establish obvious ownership, but do not maintain a manual filename list.
- `*.nix` / behavior change → build without activation and verify the changed artifact in the result closure (see §verify). for a downstream flake, point both builds at the worktree when both graphs are required:
  ```bash
  home-manager build --flake <downstream-repo>#$HM_CONFIG_NAME \
    --override-input personal-config path:<worktree>
  darwin-rebuild build --flake <downstream-repo>#$HM_CONFIG_NAME \
    --override-input personal-config path:<worktree>
  ```

## 5. publish the result and continue

share the pr link, what changed, and the validation results. proceed under [config task authorization](#config-task-authorization).

## 6. merge, activate, verify, clean up

1. **merge through the branch's workflow.** a github-managed stack uses `github-stacked-prs`; preserve its live states and select only a live ready bottom layer. for an ordinary pull request, rederive its live state under the shared `CLAUDE.md` rule. if it is draft, apply [config task authorization](#config-task-authorization) before `gh pr ready`; if it is already ready, preserve that state without a duplicate confirmation or ready command. verify the expected ready state, then squash-merge the validated head after required checks pass:
   ```bash
   # only when the pr is draft and this merge is authorized
   gh pr ready <n> --repo <owner>/<repo>
   gh pr view <n> --repo <owner>/<repo> --json isDraft,headRefOid
   # require ready state and the validated head before merging
   gh pr merge <n> --repo <owner>/<repo> --squash --match-head-commit <validated-head>
   ```
   then confirm it actually landed — a refused merge leaves the pr open and is easy to skim past:
   ```bash
   gh pr view <n> --repo <owner>/<repo> --json state,mergedAt,headRefOid   # want MERGED, non-null mergedAt, and the validated head
   ```
2. **activate** from the now-updated main, using the flake this machine actually uses (`$HM_CONFIG_NAME` selects the config):
   ```bash
   home-manager switch --flake ~/.config/home-manager#$HM_CONFIG_NAME
   ```
   this sudo-free command is the activation path for a known home-only change on macos or linux.

   for a macos system or shared change, build the merged nix-darwin graph first. then stop and give rahul the exact authenticated command. rahul must run it or explicitly authorize it; task authorization does not authorize an agent to satisfy or bypass sudo authentication.
   ```bash
   darwin-rebuild build --flake ~/.config/home-manager#$HM_CONFIG_NAME
   sudo darwin-rebuild switch --flake ~/.config/home-manager#$HM_CONFIG_NAME
   ```
   downstream machine → after the base pr merges, bump the downstream lock (`nix flake update personal-config`) and use the downstream flake for every build and activation. that lock bump is itself a config change → the same workflow under [config task authorization](#config-task-authorization), or part of the downstream pull request already within the task scope.
3. **verify — artifact-level** (§verify).
4. **clean up** — only after a green rebuild + verify (rebuild failed → leave the worktree for debugging). remove ONLY the worktree this invocation created:
   ```bash
   git -C ~/.config/home-manager worktree remove --force <worktree> && \
   git -C ~/.config/home-manager branch -D rahul/nix-rebuild-<topic>
   ```
   if THIS session's cwd IS the worktree, run the whole removal in ONE bash invocation via `git -C <main-checkout>` as the session's LAST bash action (no shell afterward) — the cleanup foot-gun in global claude.md; never an `isolation:"worktree"` agent (guard-refused from `git -C`).

## verify — artifact-level, not vibes

- `nix-provenance` — the active home generation and source must match after a home-manager switch. after a user-authenticated nix-darwin switch, the active system and embedded home generation must both match the merged source.
- claude settings change: assert the changed key in the merged closure artifact
  ```bash
  M=$(nix-store -qR /run/current-system | grep claude-settings-nix-merged)
  python3 -c "import json; print(json.load(open('$M')).get('<key>'))"
  ```
- tools / scripts / skills: `which <tool>`, `ls ~/.claude/skills/`.
- settings precedence is defined in `home-manager-reference.md`; this pointer keeps that rule in one place. a nix-side default can be invisible live unless declared as a forced value; inspect the generated artifact and the resulting live value.

## settings precedence (scalar bumps)

settings pieces merge in order: `settings-base.json` → os piece (`settings-mac.json` / `settings-linux.json` / `settings-nixos.json`) → downstream piece. later pieces win scalar conflicts. changing a scalar in an earlier piece → grep the later pieces for the same key and bump them in the SAME pr, or the edit is silently overridden.

## notes

- check `$HM_CONFIG_NAME` to determine which flake this machine rebuilds from.
- use omz git aliases with the full command in the bash tool's `description` field.
- skip `exec $SHELL` — claude code's shell snapshot won't update mid-conversation; changes land in the next conversation.
- once merged, a known home-only activation proceeds without sudo. a macos system activation always stops for rahul's authentication or explicit authorization.
