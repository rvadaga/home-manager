# base instructions

* when writing ANY new content, always use lower case.
    * when editing existing docs, follow the casing and styling conventions already used in that doc. if the doc is internally inconsistent, match the nearest surrounding section
    * when creating new docs, use the default lower case style
    * when editing, preserve case for code, variable names, identifiers, abbreviations and actual code
    * product names are lower case too
* when working on pull requests:
    * unless specifically asked not to, create a DRAFT pr
    * don't add ai generated prompt
    * always use pull request templates available in the repository
    * if it doesn't exist in the repo, please use the one in ~/development/.github/ folder
    * always read the pr description from github before updating it (user may have made changes via github ui)
* when creating a branch
    * prefix the name with rahul/
* worktree branch naming (claude-auto-named branches)
    * claude code's worktree toggle creates branches with auto-generated random names — two lowercase words optionally followed by a 6-char hex suffix (e.g., `kind-matsumoto-bdf245`, `beautiful-gates`, `condescending-faraday-309090`, `dreamy-jemison`, `rahul/busy-taussig-692fab`). these names don't communicate the work being done.
    * detect the pattern: branch matches `^(rahul/)?[a-z]+-[a-z]+(-[a-f0-9]{6})?$` → it's claude-auto-generated (covers both bare `kind-matsumoto-bdf245` and hybrid `rahul/busy-taussig-692fab` forms).
    * **proactively** rename such branches by running `/wt-name` once the user's task is clear (jira ticket, topic, or scope visible from the conversation). do this without being asked — it is an expected default behavior.
    * if the task is ambiguous and you cannot infer a confident name, **ask the user once** for the topic or jira ticket before continuing. do not guess.
    * **never push** a branch matching the auto-name pattern. before any `git push` (including the first push to set upstream), check the current branch name; if it matches, run `/wt-name` first. **enforced by PreToolUse Bash hook in settings-base.json — push attempts from auto-named branches are rejected at the harness layer.**
    * rename only the branch (`git branch -m <old> <new>`), never move the worktree directory — directory moves break the current session's cwd resolution.
* when making any nix config changes:
    * for most changes (CLAUDE.md, settings, dotfiles): edit, commit, push, then rebuild to apply
    * do not ask whether to rebuild after nix config changes unless the user explicitly asks not to rebuild or the rebuild target is genuinely ambiguous
    * rebuild command depends on the os — see os-specific instructions (darwin-rebuild on macos, home-manager switch on linux)
    * only use `--override-input` for significant `*.nix` file changes that warrant local testing before pushing
    * skip `exec $SHELL` — claude code's shell snapshot is captured at conversation start and won't update mid-conversation; new shell changes take effect in the next conversation
* never fetch or pull all remote branches — always fetch only the specific branch needed (e.g., `gfo main`, never `gfa` or bare `gf`). fetching everything pollutes `git branch --all` output
* never force-push without explicit permission — `git push --force` and `git push --force-with-lease` are destructive and should be a last resort
* commit autonomously as work reaches coherent milestones — don't wait for explicit permission. keep commits focused (one logical change per commit), follow the repo's existing commit message style, and omit AI-attribution trailers (no `co-authored-by: claude`, no "generated with claude code" footer)
* use oh-my-zsh git plugin aliases for all git commands. always put the equivalent full git command in the bash tool's `description` field (not as an inline `#` comment in the command itself, since that breaks permission matching). example: run `gcmsg "fix bug"` with description "git commit --message". the full alias reference is at `~/.config/home-manager/dotfiles/claude/omz-git-aliases.md`
* shipping a worktree to main ("squash merge", "land this worktree", "ship it") — follow this exact sequence; the cwd-deletion foot-gun makes improvising risky:
    * commit any pending work in the worktree first
    * fetch latest main: `git -C "$PROJ" fetch origin main` (where `$PROJ` is the main repo, e.g. `~/.config/home-manager`). if the worktree branch diverged, rebase it: `git rebase origin/main`
    * squash-merge into main from inside the worktree using `git -C "$PROJ"` — never `cd` into the main repo, because the bash harness registers the worktree as cwd at session start and `cd` doesn't update that registration:
      ```
      PROJ=$HOME/.config/home-manager
      git -C "$PROJ" merge --squash <branch>
      git -C "$PROJ" commit -m "<message>"
      git -C "$PROJ" push origin main
      git push origin --delete <branch>     # remove the remote feature branch
      ```
    * **cleanup foot-gun (claude-code-specific)**: when the harness's registered cwd is the worktree and you `git worktree remove` it from this session, every subsequent Bash call fails to spawn — the harness still launches shells from the (now-deleted) path. so delegate the cleanup (`git worktree remove` + `git branch -D`) to an `Agent` spawned with `isolation: "worktree"` — the isolation flag gives the agent a separate cwd that survives the removal. a vanilla Agent without that flag inherits the same cwd registration and falls into the same trap. interactive terminals are unaffected; this is purely a claude-code harness quirk.
* when a nix config change touches BOTH this config (`~/.config/home-manager`) AND a downstream config that imports it (e.g. adding a new module here and opting the downstream config into it), invoke the `/nix-rebuild` skill instead of improvising the commit / push / `nix flake update` / commit / rebuild ordering. the skill encodes the cross-repo sequence correctly and stops the agent from forgetting the downstream lock bump.
* for any task spanning ≥5 steps OR multiple repos / systems / live-and-source layers, use `TodoWrite` even if it feels like overkill. cross-repo state (which file in which repo, which lock pointing where, which rebuild from which flake) is easy to lose mid-execution; the harness reminds for a reason.

## multi-pr workflow

when a change is large enough to warrant multiple prs:

* assess whether the change should be split into multiple prs. if so, ask the user whether to chain them (each branch based on the previous) or keep them as standalone branches off main
* number each pr sequentially — pr1, pr2, etc.
* include the number in the branch name: e.g., `rahul/pr1-change-abc`, `rahul/pr2-fix-bug` (follows existing branch prefix conventions per repo)
* track the full pr sequence in project-level memory: pr number (pr1, pr2…), github pr #, branch name, and status
* when the project is complete and the user asks, clean up the associated project memory
* if a pr sequence seems stale or stuck, proactively ask the user about it

# nix configuration

## key rules

* CLAUDE.md is a read-only symlink — edit source files in `~/.config/home-manager/dotfiles/claude/` and rebuild
* settings.json uses additive merge on rebuild — live values win on scalar conflicts, arrays are union-merged
* settings.local.json is not managed by nix — claude code owns it
* use `/sync-claude-settings` to export live settings back to nix source files
* use `/diff-claude-settings` for read-only comparison
* check `$HM_CONFIG_NAME` to determine which flake to rebuild against

## rebuild commands by os

* **macos (nix-darwin):** `darwin-rebuild switch --flake <flake-path>#$HM_CONFIG_NAME`
* **linux (home-manager):** `home-manager switch --flake <flake-path>#$HM_CONFIG_NAME`

## parallel-worktree foot-gun

* **the active system carries no visible cue about which worktree it was built from.** parallel worktrees of this config all activate into the same `/run/current-system` (and home-manager profile); whichever one ran `darwin-rebuild switch` most recently wins. **run `nix-provenance` as your FIRST diagnostic in any of these situations**, before deeper troubleshooting:
    * before trusting "i rebuilt and my change took effect" / before reporting a fix as verified
    * when an expected change isn't visible in the active system ("i added module X but it's not loaded", "i edited setting Y but the system still shows the old value", "my new alias / script / command isn't on PATH")
    * when behavior diverges from what the source files imply (e.g. you read a file and it has feature A, but the running system behaves like it's still on the old version)
    * before blaming a bug on the code — first rule out "wrong build is active"

  `darwin/provenance.nix` writes the flake's rev + content hash to `/etc/nix-config-provenance` at activation; `~/.local/bin/nix-provenance` (PATH bash script installed via `os-configs/base.nix`) reads it and compares with the current worktree's git state:
  ```bash
  cat /etc/nix-config-provenance   # rev, narHash, lastModified, storePath
  nix-provenance                   # same, plus comparison with `pwd`'s git state
  ```
  rev mismatch → rebuild from this worktree. rev matches but you've edited since → `narHash` (and the `-dirty` suffix on rev) catches that; rebuild anyway.
* this only kicks in on nix-darwin (the module lives under `darwin/`). linux home-manager doesn't have an equivalent stamp yet.
* downstream configs (work) must opt in by importing `inputs.personal-config.darwinModules.provenance` and ensuring their `darwinSystem` sets `specialArgs = { inherit inputs; }`.

## multi-repo structure

the personal/base config (`~/.config/home-manager`) can be imported as a flake input by other configs (e.g., work-specific configs). on machines with layered configs:

* the downstream config imports this repo as `inputs.personal-config`
* CLAUDE.md files from both repos get combined
* if rebuilding a downstream config, use that config's flake path (not this one)
* downstream configs pin this repo by git revision — in most cases, just commit, push, and rebuild normally. only use `--override-input` when making significant changes to `*.nix` files that warrant local testing before pushing

for detailed workflows, file structure, and examples: read `~/.config/home-manager/dotfiles/claude/home-manager-reference.md`

# knowledge base (llm wiki)

structured markdown knowledge bases maintained by LLMs, following karpathy's llm wiki pattern. instead of re-deriving knowledge from raw sources on every query (like RAG), the LLM incrementally builds and maintains a persistent wiki — a compounding artifact of interlinked markdown files.

reference: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## vaults

all obsidian vaults live under `~/development/obsidian/`:

* `personal-software` — general software engineering, architecture, programming
* `oss-vespa` — vespa open-source search engine

## workflow

1. **ingest**: raw sources (articles, papers, docs) go into `raw/` — use obsidian web clipper for web content
2. **compile**: read raw sources, produce/update structured wiki pages with `[[wikilinks]]`, update index and log
3. **query**: answer questions using the wiki, file valuable answers back as new pages
4. **lint**: check for contradictions, orphaned pages, gaps, stale claims, missing cross-references

## file conventions

* one topic per file, descriptive kebab-case filenames (e.g., `distributed-consensus.md`)
* each file: summary line, tags in YAML frontmatter, related notes via `[[wikilinks]]`
* `index.md` at wiki root — content-organized catalog of all pages
* `log.md` — chronological append-only record (format: `## [YYYY-MM-DD] action | description`)
* keep notes focused and atomic — many small files over few large ones

## vault schema

each vault has its own schema (CLAUDE.md or similar) that the LLM and user co-evolve over time to define structure, conventions, and domain-specific rules
