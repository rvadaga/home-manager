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
* when making any nix config changes:
    * for most changes (CLAUDE.md, settings, dotfiles): edit, commit, push, then rebuild to apply
    * rebuild command depends on the os — see os-specific instructions (darwin-rebuild on macos, home-manager switch on linux)
    * only use `--override-input` for significant `*.nix` file changes that warrant local testing before pushing
    * skip `exec $SHELL` — claude code's shell snapshot is captured at conversation start and won't update mid-conversation; new shell changes take effect in the next conversation
* never fetch or pull all remote branches — always fetch only the specific branch needed (e.g., `gf origin main`, never `gf --all` or bare `gf`). fetching everything pollutes `git branch --all` output
* prefer merge over rebase — use merge commits to integrate changes (e.g., merge main into feature branch). rebase is a last resort; always ask for permission before rebasing
* never force-push without explicit permission — `git push --force` and `git push --force-with-lease` are destructive and should be a last resort

## multi-pr workflow

when a change is large enough to warrant multiple prs:

* assess whether the change should be split into multiple prs. if so, ask the user whether to chain them (each branch based on the previous) or keep them as standalone branches off main
* number each pr sequentially — pr1, pr2, etc.
* include the number in the branch name: e.g., `rahul/pr1-change-abc`, `rahul/pr2-fix-bug` (follows existing branch prefix conventions per repo)
* track the full pr sequence in project-level memory: pr number (pr1, pr2…), github pr #, branch name, and status
* when the project is complete and the user asks, clean up the associated project memory
* if a pr sequence seems stale or stuck, proactively ask the user about it

* use oh-my-zsh git plugin aliases for all git commands. always put the equivalent full git command in the bash tool's `description` field (not as an inline `#` comment in the command itself, since that breaks permission matching). example: run `gcmsg "fix bug"` with description "git commit --message". the full alias reference is at `~/.config/home-manager/dotfiles/claude/omz-git-aliases.md`
* never chain commands with `&&` or `;` in bash tool calls — compound commands break permission matching even when each individual command is allowed. if you need to run git commands in a different repo, prefer `git -C <path>` instead of `cd <path> && git ...`
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

## multi-repo structure

the personal/base config (`~/.config/home-manager`) can be imported as a flake input by other configs (e.g., work-specific configs). on machines with layered configs:

* the downstream config imports this repo as `inputs.personal-config`
* CLAUDE.md files from both repos get combined
* if rebuilding a downstream config, use that config's flake path (not this one)
* downstream configs pin this repo by git revision — in most cases, just commit, push, and rebuild normally. only use `--override-input` when making significant changes to `*.nix` files that warrant local testing before pushing

for detailed workflows, file structure, and examples: read `~/.config/home-manager/dotfiles/claude/home-manager-reference.md`
