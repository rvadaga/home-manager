# base instructions

* when writing ANY new content, always use lower case.
    * when editing existing docs, follow the casing and styling conventions already used in that doc. if the doc is internally inconsistent, match the nearest surrounding section
    * when creating new docs, use the default lower case style
    * when editing, preserve case for code, variable names, identifiers, abbreviations and actual code
    * product names are lower case too
* **write plainly for every human-facing thing you produce** (docs, PR descriptions, code comments, chat, standups) — default to the register of explaining it out loud to a colleague who just walked up. the fix is NOT "shorter": terse and readable are different axes; a short paragraph dense with coined terms still fails.
    * lead with the point in plain words; gloss or drop coined terms on first use (jargon i've "gotten used to" is invisible to me — don't assume it's shared); short sentences, active voice.
    * cut the LLM filler i keep flagging — belt-and-suspenders, load-bearing, binding gate, "X, not Y" contrasts, throat-clearing openers, fake-profound closers, emoji-in-headings, em-dash rhythm-crutches (one is sometimes apt; the problem is overuse). outsider-read prose a human reads cold; if the top needs a glossary, rewrite it.
    * fuller pattern list: peter yang's `/no-ai-slop`.
* **never quote rahul's venting verbatim in anything durable** — pr bodies, skill text, ledgers, memories, commit messages. state the rule and the concrete breakage instead; that carries the full operational weight and reads better, while a quoted outburst resurfaces in every future diff and for every future reader. neutral instructional quotes are fine, though a plain paraphrase outlives a quote and is preferred even there.
* **denylist / allowlist, never blacklist / whitelist** — in prose and in code (etsy `go/inclusivecode`, linked from the pr template header).
* when working on pull requests:
    * unless specifically asked not to, create a DRAFT pr
    * don't add ai generated prompt
    * always use pull request templates available in the repository
    * if it doesn't exist in the repo, please use the one in ~/development/.github/ folder
    * always read the pr description from github before updating it (user may have made changes via github ui)
* **pr/branch ledger — capture every durable artifact a session creates or materially depends on in project-level memory.** prs opened (in the current repo or companion prs in other repos), branches pushed but not yet pr'd, and cross-repo dependency pairs each get a ledger entry: pr number/link or branch name + tip sha, a one-line purpose, current status, and (for cross-repo pairs) which side depends on which
    * capture at creation time, not at session end — sessions get interrupted, and an unrecorded pr is invisible to parallel and future sessions
    * keep the ledger current: when refreshing or citing it, verify against the live source of truth (`gh pr list` / `gh pr view` on `<owner>/<repo>`, `git ls-remote`) rather than trusting recollection or the ledger itself; update statuses (merged/closed) as they change
    * applies in every repo and to spawned/child sessions too — they share the parent project's memory, so the ledger is the shared registry across parallel sessions
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
    * **every change goes worktree → draft pr → rahul's "looks ok" → merge to main → rebuild, via the `/nix-rebuild` skill.** NEVER edit/commit/push on the primary checkout's `main`, and NEVER `git push origin HEAD:main` — no config change lands on main without a reviewable pr first, no matter how small. (an explicit "ship it / land this / squash merge" instead uses `/ship-config`, which merges autonomously once the pre-merge test passes — the explicit command is the approval.)
    * do not ask whether to rebuild after a change MERGES — once it's on main, rebuild autonomously (the approval gate is at merge, not at rebuild) unless the rebuild target is genuinely ambiguous
    * rebuild command depends on the os — see os-specific instructions (darwin-rebuild on macos, home-manager switch on linux)
    * use `--override-input` for significant `*.nix` file changes and whenever a change should be validated before pushing or merging (pre-merge testing — see /ship-config and /nix-rebuild)
    * skip `exec $SHELL` — claude code's shell snapshot is captured at conversation start and won't update mid-conversation; new shell changes take effect in the next conversation
* never fetch or pull all remote branches — always fetch only the specific branch needed (e.g., `gfo main`, never `gfa` or bare `gf`). fetching everything pollutes `git branch --all` output
* never force-push without explicit permission — `git push --force` and `git push --force-with-lease` are destructive and should be a last resort
* commit autonomously as work reaches coherent milestones — don't wait for explicit permission. keep commits focused (one logical change per commit), follow the repo's existing commit message style, and omit AI-attribution trailers (no `co-authored-by: claude`, no "generated with claude code" footer)
* use oh-my-zsh git plugin aliases for all git commands. always put the equivalent full git command in the bash tool's `description` field (not as an inline `#` comment in the command itself, since that breaks permission matching). example: run `gcmsg "fix bug"` with description "git commit --message". the full alias reference is at `~/.config/home-manager/dotfiles/claude/omz-git-aliases.md`
* **always run bash commands backgrounded** (`run_in_background: true`) — small or large. foreground command output isn't reliably visible in the claude desktop app's transcript; backgrounded output is captured to the task output file and shows in the "background task" view. after starting one, poll/read its output and relay the result — never fire-and-forget: a command isn't "done" until its output has been surfaced to the user.
* **cross-session messaging (`mcp__ccd_session_mgmt__send_message`) MAY prompt for user confirmation — behavior varies by harness version, so verify in the acting session rather than assuming either way.** as of 2026-07-18 it prompted on every call and allowlisting could not suppress it (adding the tool to `permissions.allow` was a no-op: no "don't ask again" option, approvals persisted nowhere, the very next call re-prompted); but on 2026-07-24 a call went through promptless, so the always-prompt behavior is not reliable across versions. the auto-mode classifier also denies an agent adding that allow rule itself as self-modification unless the user authorizes it directly in the acting session. for multi-session coordination still prefer promptless channels where practical: shared ledger files in project memory, subagents spawned via the `Agent` tool (results return to the spawner without prompts), and batching anything that goes through send_message into the fewest sends.
* shipping a config change from a worktree ("ship it", "land this", "squash merge") → invoke the `/ship-config` skill. pr + squash merge is the default; the skill covers pr creation, pre-merge closure testing, merge, cascade, rebuild, verification, and worktree cleanup, and proceeds autonomously once the pre-merge test passes.
* **worktree cleanup foot-gun (claude-code-specific)**: when the harness's registered cwd is the worktree and you `git worktree remove` it from this session, every subsequent Bash call fails to spawn — the harness still launches shells from the (now-deleted) path. interactive terminals are unaffected; this is purely a claude-code harness quirk. **the fix: run the WHOLE removal in ONE bash invocation using `git -C <main-checkout>`** (`git -C <main-checkout> worktree remove --force <worktree> && git -C <main-checkout> branch -D <branch>`) — each command targets the main checkout by absolute path, so none depends on the doomed cwd. the removal kills THIS session's registered cwd, so it must be the absolute LAST bash action — no bash afterward, only a text summary. run this single shell directly from the session; a subagent buys nothing (a vanilla `Agent` shares this session's doomed cwd anyway). **do NOT spawn the cleanup with `isolation: "worktree"`** — an isolated agent's git is sandboxed to its own worktree and the harness guard-refuses `git -C <main-checkout>` outright (verified 2026-07-22, claude-code 2.1.216: even a read-only `git -C` is blocked — "a worktree-isolated agent's git operations must target its own worktree"). if you do delegate to a plain (non-isolated) subagent, tell it the target is this session's own worktree and the work has landed on main, or the security classifier flags the force-remove as interfering. always run this cleanup once worktree work has landed on main.
* **worktree cleanup scope — only the current session's worktree.** "clean up this worktree" (and worktree cleanup generally) refers exclusively to the worktree this session is registered in or created. never enumerate `git worktree list` and remove other worktrees — they belong to other live sessions, and removing them breaks those sessions mid-work. in a forked session, clean up only the fork's own worktree, never the parent session's. if the current session runs from the primary checkout and owns no worktree, say so and stop — ask which worktree is meant instead of guessing.
* when a nix config change touches BOTH this config (`~/.config/home-manager`) AND a downstream config that imports it (e.g. adding a new module here and opting the downstream config into it), invoke the `/nix-rebuild` skill instead of improvising the commit / push / `nix flake update` / commit / rebuild ordering. the skill encodes the cross-repo sequence correctly and stops the agent from forgetting the downstream lock bump.
* for any task spanning ≥5 steps OR multiple repos / systems / live-and-source layers, use `TodoWrite` even if it feels like overkill. cross-repo state (which file in which repo, which lock pointing where, which rebuild from which flake) is easy to lose mid-execution; the harness reminds for a reason.
* **verify a change against its real, observable result — render it, run it, look at it.** never declare success from proxy signals alone (an intermediate field-check, an api call returning rc=0, "the request succeeded") — proxies produce false positives. e.g. for a generated doc, export and view it; for a state mutation, re-query the actual state; for a ui change, screenshot it. the readable export/summary hides the structure that actually renders — inspect the ground truth.
* **treat the check itself as the thing most likely to be wrong, in both directions.** before trusting a probe that reports "conflict" or "someone else is editing this", re-run it with your own change excluded and see whether the signal survives. before trusting a clean result, audit the filter that produced it, because a filter bug fails silently toward "clean" — `awk -F: '$2<=4'` compares the matched text rather than the line number, and returned a false all-clear on a frontmatter sweep. a false alarm blocks a correct change while a false all-clear costs at most a merge, and most false alarms are the other side being stale: `merge-tree` conflicts often reproduce identically against plain `origin/main`.
    * `git diff origin/main -- <path>` in a stale worktree looks exactly like a concurrent edit, because main's own additions show up as that worktree's deletions. probe with `git log origin/main..HEAD -- <path>` for unpushed commits and `git status --porcelain -- <path>` for uncommitted ones. use `git diff --word-diff` when two clauses share a line.
    * re-read the source before you re-flag something, not just before you act on it. a brief can be stale the moment it arrives, and the problem you are about to report may already be fixed.
    * silence is not success. `gh pr merge --squash` prints nothing when it works, and chaining a check onto the same command also returns empty, so success and silent failure look identical. re-query `state` and `mergedAt` in a separate call, and run `gh pr ready` first because merge refuses a draft.
* **memory routing — codify durable facts/rules in the nix-managed CLAUDE.md sources, scoped right.** shared behavioral rules → `CLAUDE-base.md`; os-specific → `CLAUDE-{mac,linux,nixos}.md`; **personal-only** reference facts (personal accounts, api access, machine-local setup) → `CLAUDE-personal-scope.md`, which is NOT inherited by downstream/work flakes that consume this config as a flake input (base IS); work-specific → the work config. don't stash durable facts in loose `~/.claude/memory/` — not version-controlled, not reliably loaded, can't be scoped. reserve harness memory for transient project-session state.
* **when you write or amend a rule — in CLAUDE.md, a skill, or a doc — check its shape, not only whether it is true.** these defects get past a reader who agrees with every sentence. worked examples for each: `reference-rule-shape-defects.md` in work-home-manager project memory.
    * write for the cheapest output that still counts as conformant. a list of options is permission to pick the laziest one, and "check the flagged lines" is satisfied by checking only those while the rest of the file stays broken. name the predicate, not a sample.
    * never write an instruction that forbids its own correction — mark a superseded form "dead → migrate to X" rather than protecting it as an exception, or every future reader preserves the error. and when a rule set makes conformance impossible, the violations are the rule's output: a repeated violation is evidence about the rule before it is evidence about the actor, so check that compliance is even possible before asking anyone to try harder.
    * ask what is special about the instance you are generalizing from, or its shape gets baked in as the general shape. if holding a scheme together needs an exception clause, read the clause as a bug report about the premise instead of writing it well.
    * when amending, grep every phrasing of the rule rather than the lines someone flagged. include the frontmatter `description`, which is the most-missed restatement and the one an agent reads to decide whether a skill applies, and the notation and examples, which can contradict the prose and are what get copied. widening a rule also narrows its restatements, so sweep after a change in scope too.
    * a rule spelled out in two places will drift. add the second by reference to the canonical statement and leave a marker saying why it is thin, or someone pastes the full text back in.

## multi-pr workflow

when a change is large enough to warrant multiple prs:

* assess whether the change should be split into multiple prs. if so, ask the user whether to chain them (each branch based on the previous) or keep them as standalone branches off main
* when a pr series must be chained (each branch based on the previous, because of a real code dependency between them), build the whole stack of branches locally up front, but open each child pr only AFTER its parent has merged to the default branch and the child has been rebased onto it. never open all the chained prs at once — keep exactly one open at a time and advance as each parent lands
* this refines the chained-vs-standalone choice above: for chained series use the build-all/open-sequentially cadence; for independent chunks keep the off-main, one-at-a-time approach
* the decision to number is a judgment about series cohesion, not a repo-level toggle — reusing the same jira ticket across prs, or prs that all belong to one coherent project/effort (a shared epic, a migration, a feature spanning several prs), is a strong signal to number the series. record that judgment by numbering the branch (below); a lone pr on its own ticket stays unnumbered.
* number each pr sequentially — pr1, pr2, etc.
* include the number in the branch name: e.g., `rahul/pr1-change-abc`, `rahul/pr2-fix-bug` (follows existing branch prefix conventions per repo)
* mirror the same number into the pr **title** as a trailing `(prN)` suffix — e.g. title `add prod query pipeline (pr9.2)` for branch `rahul/s2-306-pr9.2-…`. **enforced by a PreToolUse bash hook in settings-base.json:** a `gh pr create` whose target branch carries a `prN` segment but whose `--title` omits the matching `(prN)` is denied at the harness layer, so it fails closed if forgotten. the numbered branch is the opt-in — the hook fires only when the branch is already numbered, so one-off/unnumbered prs are never affected. known gap: only `gh pr create` (bash) is gated; the github mcp `create_pull_request` and `gh api …/pulls` paths are not.
* the next sequence number in a series is CLAIMED by pushing the branch to origin — the remote branch namespace is the allocation registry, so parallel sessions can't silently mint the same number
* to allocate: check both live branches (`git ls-remote --heads origin '<series-branch-prefix>*'`) and burned numbers from merged/closed prs (`gh pr list --state all --search "<series> in:title"` — deleted branches vanish from ls-remote); take the NUMERIC max+1 (pr<N>.10 > pr<N>.9; lexical sort lies)
* claim immediately: create the branch and push it before substantive work; re-check ls-remote after pushing — if two sessions raced the small window, the later pusher renumbers before real work exists
* a session that spawns child sessions allocates numbers FOR them in their briefs (spawner allocates); ledger files (project memory) record numbers + status for reading, never for allocation
* in chained pr series, code comments may reference **subsequent/child prs only** — never the pr itself, never a parent. forward refs are breadcrumbs for later prs to pick up: pr1 leaves `TODO(pr2): <task>`, and pr2 removes that comment when it implements the task (rewording to name the real component if the context is still useful — `(pr2)` inside pr2 would be a self-reference)
* invariant: whatever lands on main never carries a stale/meaningless pr reference — every forward ref is consumed by the child that fulfills it before that child merges
* if a parent pr already contains a reference to itself or a parent, fix it in the CHILD branch — parents that are already open/merged stay untouched unless the user says otherwise
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
* downstream configs must opt in by importing `inputs.personal-config.darwinModules.provenance` and ensuring their `darwinSystem` sets `specialArgs = { inherit inputs; }`.

## multi-repo structure

the personal/base config (`~/.config/home-manager`) can be imported as a flake input by downstream configs. on machines with layered configs:

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

# x api mcp

the `xapi` mcp server (settings-base.json mcpServers) uses the `npx -y @xdevplatform/xurl mcp https://api.x.com/mcp` bridge. oauth2 token cached in `~/.xurl` (auto-refreshes), authorized as @rahul_vadaga.

* app credentials (client id + secret + app-only bearer token) are cached at `~/.config/secrets/x-mcp-oauth-client.env` (export lines, perms 600; never committed). the bearer token is also registered in xurl's local store (via `xurl auth app-only -`, reads from stdin).
* if the user-context token is ever revoked, re-auth with:
  ```bash
  source ~/.config/secrets/x-mcp-oauth-client.env && npx -y @xdevplatform/xurl auth oauth2
  ```
* full-archive post search is the exception: the hosted mcp's `search_posts_all` tool requires app-only auth and 403s with the bridge's user-context token; the other 23 tools work user-context. run it from bash instead (deliberately not a second mcp server — that would persist the token in settings.local.json):
  ```bash
  npx -y @xdevplatform/xurl --auth app "/2/tweets/search/all?query=<url-encoded>&max_results=10"
  ```
  keep `max_results` low — pay-per-use bills $0.005 per post returned. a spending limit should be set in the developer console under billing (~$10/month).
* the app-only bearer token cannot be minted via oauth2 client_credentials (403) — it comes from the developer console's app-only authentication section. if lost, regenerate there, then re-register in xurl's store from the secrets cache.
* the `x-docs` server (https://docs.x.com/mcp) needs no auth.
