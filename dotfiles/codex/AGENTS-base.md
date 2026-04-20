# base instructions

* when writing any new content, always use lower case.
    * when editing existing docs, follow the casing and styling conventions already used in that doc. if the doc is internally inconsistent, match the nearest surrounding section
    * when creating new docs, use the default lower case style
    * when editing, preserve case for code, variable names, identifiers, abbreviations, and actual code
    * product names are lower case too
* when working on pull requests:
    * unless specifically asked not to, create a draft pr
    * don't add ai generated prompt
    * always use pull request templates available in the repository
    * if it doesn't exist in the repo, use the one in `~/development/.github/`
    * always read the pr description from github before updating it (the user may have made changes via the github ui)
* when creating a branch
    * prefix the name with `rahul/`
* when making any nix config changes:
    * for most changes (AGENTS.md, dotfiles): edit, commit, push, then rebuild to apply
    * do not ask whether to rebuild after nix config changes unless the user explicitly asks not to rebuild or the rebuild target is genuinely ambiguous
    * rebuild command depends on the os - see os-specific instructions (darwin-rebuild on macos, home-manager switch on linux)
    * only use `--override-input` for significant `*.nix` file changes that warrant local testing before pushing
    * skip `exec $SHELL` - codex's shell snapshot is captured at conversation start and won't update mid-conversation; new shell changes take effect in the next conversation
* never fetch or pull all remote branches - always fetch only the specific branch needed (for example `git fetch origin main`, never fetch everything). fetching everything pollutes `git branch --all` output
* prefer merge over rebase - use merge commits to integrate changes (for example merge main into a feature branch). rebase is a last resort; always ask for permission before rebasing
* never force-push without explicit permission - `git push --force` and `git push --force-with-lease` are destructive and should be a last resort
* commit autonomously as work reaches coherent milestones - don't wait for explicit permission. keep commits focused (one logical change per commit), follow the repo's existing commit message style, and omit ai-attribution trailers
* prefer oh-my-zsh git plugin aliases when practical. the alias reference is at `~/.config/home-manager/dotfiles/claude/omz-git-aliases.md`

## multi-pr workflow

when a change is large enough to warrant multiple prs:

* assess whether the change should be split into multiple prs. if so, ask the user whether to chain them (each branch based on the previous) or keep them as standalone branches off main
* number each pr sequentially - pr1, pr2, etc.
* include the number in the branch name: e.g. `rahul/pr1-change-abc`, `rahul/pr2-fix-bug`
* track the full pr sequence in a durable note or memory: pr number (pr1, pr2...), github pr #, branch name, and status
* when the project is complete and the user asks, clean up the associated tracking note or memory
* if a pr sequence seems stale or stuck, proactively ask the user about it

# nix configuration

## key rules

* `AGENTS.md` is a read-only symlink - edit source files in `~/.config/home-manager/dotfiles/codex/` and rebuild
* check `$HM_CONFIG_NAME` to determine which flake to rebuild against

## rebuild commands by os

* **macos (nix-darwin):** `darwin-rebuild switch --flake <flake-path>#$HM_CONFIG_NAME`
* **linux (home-manager):** `home-manager switch --flake <flake-path>#$HM_CONFIG_NAME`

## multi-repo structure

the personal/base config (`~/.config/home-manager`) can be imported as a flake input by other configs (e.g. work-specific configs). on machines with layered configs:

* the downstream config imports this repo as `inputs.personal-config`
* `AGENTS.md` content from both repos gets combined
* if rebuilding a downstream config, use that config's flake path (not this one)
* downstream configs pin this repo by git revision - in most cases, just commit, push, and rebuild normally. only use `--override-input` when making significant changes to `*.nix` files that warrant local testing before pushing

for detailed workflows, file structure, and examples, read `~/.config/home-manager/README.md` and `~/.config/home-manager/WORKFLOW.md`

# knowledge base (llm wiki)

structured markdown knowledge bases maintained by llms, following karpathy's llm wiki pattern. instead of re-deriving knowledge from raw sources on every query (like rag), the llm incrementally builds and maintains a persistent wiki - a compounding artifact of interlinked markdown files.

reference: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

## vaults

all obsidian vaults live under `~/development/obsidian/`:

* `personal-software` - general software engineering, architecture, programming
* `oss-vespa` - vespa open-source search engine

## workflow

1. **ingest**: raw sources (articles, papers, docs) go into `raw/` - use obsidian web clipper for web content
2. **compile**: read raw sources, produce/update structured wiki pages with `[[wikilinks]]`, update index and log
3. **query**: answer questions using the wiki, file valuable answers back as new pages
4. **lint**: check for contradictions, orphaned pages, gaps, stale claims, and missing cross-references

## file conventions

* one topic per file, descriptive kebab-case filenames (e.g. `distributed-consensus.md`)
* each file: summary line, tags in yaml frontmatter, related notes via `[[wikilinks]]`
* `index.md` at wiki root - content-organized catalog of all pages
* `log.md` - chronological append-only record (format: `## [YYYY-MM-DD] action | description`)
* keep notes focused and atomic - many small files over few large ones

## vault schema

each vault has its own schema (`AGENTS.md`, `CLAUDE.md`, or similar) that the llm and user co-evolve over time to define structure, conventions, and domain-specific rules
