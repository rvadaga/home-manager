---
name: notes
description: read, save, or curate notes in the obsidian llm-wiki vaults. "read <topic>" to pull up notes, "save <topic>" to save durable findings, "answer [<page>]" to answer inline "> q:" questions, "cleanup <page>" to refactor accumulated q&a into atomic pages, "lint [<vault>|all]" to run the health check.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(mkdir *), Bash(ls *), Bash(git *), Bash(python3 *), Bash(find *), Bash(gstat *)
---

## your task

manage notes in the user's obsidian llm-wiki vaults at `~/development/obsidian/`. mode is the first argument word:

- **read \<topic\>**: find and display existing notes matching the topic
- **save \<topic\>**: save durable findings from the current conversation as a wiki page
- **answer [\<page\>]**: answer the user's inline `> q:` questions in place
- **cleanup \<page\>**: refactor accumulated q&a into the body + atomic pages
- **lint [\<vault\>|all]**: run the health check (default: all vaults on this machine)

if no mode word is given, default to **save**.

## vault registry

- `personal-software` — general software engineering, architecture, programming. schema: `CLAUDE.md` at vault root. topic dirs (`systems/`, `languages/`, `networking/`, `git/`, `bash/`, `terminal/`, `tools/`, `observability/`, `temporal/`, `meta/`) + project sub-wikis with their own indexes (e.g. `paneherd/`). `raw/` for web-clipper ingest.
- `oss-vespa` — vespa open-source internals, a source-code-reading wiki. schema: `SCHEMA.md`. flat `pages/`; frontmatter carries `source:` listing the files read.
- **work machines only**: if `references/work-vault.md` exists in this skill's directory, it registers the work vault and its routing/confidentiality rules — read it before routing whenever work-internal content is in play.

each vault's schema file is the source of truth for its conventions — **always read it before writing**.

## routing

- vespa open-source internals (proton, distributor, feed client, etc.) → `oss-vespa`
- general software/engineering knowledge → `personal-software`
- work-internal content → the work vault per `references/work-vault.md` (work machines); on personal machines, work content has no home here — flag it instead of saving
- mixed general + work-internal topics → the split protocol in `references/work-vault.md`
- if still ambiguous, ask the user which vault

## common setup

1. pick the target vault per the rules above
2. read the vault's schema file for conventions — filename style, frontmatter template, directory layout, log direction
3. skim the vault's `index.md` to see what's already catalogued

## read mode

4. find notes matching the topic:
   - search `index.md` first — it's the organized catalog of the vault
   - match against filenames (e.g., "vespa proton" → `pages/proton.md`)
   - if no filename match, use Grep to search content across the vault
5. read and display all matching notes in full using the Read tool
6. if no matches found, show the user the closest candidates so they can refine the query
7. done — no write operations needed

## save mode

4. check for an existing page on this topic:
   - search `index.md` for related entries
   - read the first 15 lines of likely candidates
   - if a page already covers the same topic, ask the user whether to **update** the existing page or **create a new** one
5. write the page per the vault's schema:
   - location: follow the schema's directory structure (topical subdirs for personal-software, `pages/` for oss-vespa)
   - filename: lowercase, hyphenated, descriptive — and **name = scope**: the filename must match what the page actually covers, never claim broader scope than the content delivers (a page about one system's tracing setup is `<system>-otel-tracing`, not `opentelemetry-tracing`). vault schemas may add anchor rules on top
   - frontmatter: the vault's template, always including `tags` and `created: YYYY-MM-DD`; add `source:` (files/urls the page was derived from) wherever it applies — typed metadata is what keeps staleness detectable. some vaults require a **kind** tag (mechanism/component/investigation/…) as the first tag — the vault schema defines it. no `title:` key — the filename is the title. extra provenance keys are allowed when they carry meaning
   - content: lead with a one-line summary, then durable knowledge (findings, architecture, code traces, takeaways)
   - cross-link to related pages using obsidian `[[wikilinks]]`
   - mark uncertain or inferred claims with `[inferred]`
   - do NOT include session-specific details (timestamps in prose, conversation ids, task progress)
6. **update `index.md` and `log.md` in the same pass — never skip this.** drift (pages the index doesn't know about) is the wiki pattern's primary failure mode. index: one-liner under the fitting section (project sub-wikis catalogue their own pages in their own index). log: `## [YYYY-MM-DD] action | description` — check the schema for direction (append-at-bottom vs prepend-at-top varies by vault)
7. if updating an existing page and the scope has changed significantly, suggest a new filename and ask the user before renaming
8. if the finding supersedes a claim on another page, update that page too (or mark it) — don't leave two pages disagreeing

## inline q&a workflow (answer + cleanup modes)

the user drops questions into pages as they read, as `> q: ...` blockquotes — anywhere, including mid-list or nested inside earlier answers. this is an encouraged first-class pattern (the user is extremely curious): questions are vault content, never noise to strip.

### answer mode

1. if a page is named, scan it for `> q:` blockquotes with no `> a:` beneath; otherwise grep the vault for unanswered ones
2. answer each **inline, directly beneath the question**, as `> a: ...` inside the same blockquote — keep the user's question text verbatim (typos included)
3. if a question was appended onto an existing line (e.g. tacked onto a bullet), split it out cleanly without wrecking the surrounding structure
4. answers should teach: plain language first, every jargon term unpacked, concrete numbers where they build intuition (~1ns cache hit vs ~100ns miss beats "slower")
5. finish with a `log.md` entry summarizing the round, and a brief digest of the answers in the chat reply

### cleanup mode

when q&a accumulates and the page stops reading as an article, refactor — never just delete:

- **absorb into the body only what is core to the page's own argument** — a clarification that sharpens a definition, a motivation the page was missing. resist absorbing everything; peripheral detail bloats the article
- **spin peripheral-but-durable depth into new atomic pages** (one concept each) and link each from the concept's **first mention** in the body. this fixes placement incoherence structurally: where the user happened to ask no longer matters, because the pointer lives at the concept's introduction
- the q&a dialogue format disappears from the page afterwards — the wiki stores knowledge, not transcripts
- new pages cross-link each other and back to the source page; update `index.md` (new entries) and `log.md` (refactor entry)
- verify nothing was lost: every answered question's content must survive somewhere (body or atomic page)

## lint mode

the periodic health check — per the llm-wiki pattern it is *not optional*: drift is how these wikis die. runs weekly on a schedule, after any bulk change, or on request.

**authority model — fix, don't just report.** every check below whose fix is codified by a schema rule is *executed* in the run (own git commit per logical fix, descriptive message), not flagged for a human. flag in the run summary only what is genuinely ambiguous (scope you cannot infer, content-loss risk) or big blast radius (more than ~5 structural changes queued in one run — do the mechanical ones, defer the rest). the vaults are git repos: everything is revertible, which is what makes autonomy safe.

per target vault:

1. **pre-flight**: unexplained untracked/modified files at lint start → investigate before proceeding. a deleted page reappearing usually means obsidian resurrected it from an open tab's buffer (see gotchas) — re-delete properly, don't re-index it.
2. **index coverage**: every content page has an index entry with an accurate one-liner (project sub-wikis: their own index counts). the reverse too — no index entries pointing at missing pages. fix both directions.
3. **orphans**: pages with zero inbound links from anywhere. link them from where the concept is first mentioned, or index them; deletion only with user sign-off.
4. **broken wikilinks**: extract `[[targets]]` (strip `|alias`, `#anchor`, table-escaped `\|`; skip code blocks) and resolve each against the vault namespace. on the work vault the namespace includes the personal vault through the `personal/` symlink. fix or retarget.
5. **frontmatter/tag conformance** (auto-fix): every page has `tags` + `created` (backfill `created` from file mtime); vaults whose schema requires a kind tag have exactly one; no `title:` keys; vault-specific tag rules enforced (see each schema). synthesize frontmatter for pages missing it entirely (infer topical tags from the page's own content).
6. **name = scope**: filenames claiming broader scope than the content delivers get renamed per the vault schema's naming rules (in the work vault: generic basenames are reserved for the personal vault; add the owning-system anchor). a rename rewrites ALL inbound links + the H1 and records the old→new mapping in the log entry. skip when the right anchor cannot be inferred from the content — flag instead.
7. **split candidates**: work-vault pages whose body is largely general knowledge (generic concepts with the work system only as worked example) get the split protocol from `references/work-vault.md`: general body → personal vault (scrubbed, original basename when it is the canonical generic name), work residue → anchored companion, no content lost, both indexes + logs updated. defer a split only if disentangling general from internal is genuinely lossy — flag those.
8. **one-way direction**: no personal-vault (or other general-vault) page may wikilink a page that exists only in the work vault. any such link is a violation — rewrite or remove it.
9. **basename collisions**: through the symlink the work + personal vaults share one link namespace — no basename may exist in both. resolve per the split protocol (the general page keeps the generic name; the work page gets an anchored name).
10. **confidentiality**: general vaults contain no work-internal information — run the marker grep from `references/work-vault.md` (work machines) over recently-touched general-vault files; eyeball hits (common words collide). violations are scrubbed immediately.
11. **raw linkage**: every `raw/` source is wikilinked from the compiled page that digested it; flag uncompiled raw files as ingest backlog.
12. **staleness/contradictions**: when a recent page settles an investigation, sweep older pages still stating the earlier hypothesis. spot-check pages whose `source:` targets may have moved on.
13. **junk**: `Untitled.md`, empty dailies, obsidian boilerplate — remove (report-before-delete only for files with real content).
14. **schema honesty**: dirs/conventions the schema promises actually exist; conventions the vault actually follows are documented. when a lint fix establishes a new convention, codify it in the schema in the same run.
15. **close out**: log the lint pass in each vault's `log.md` (each vault's own direction), commit each vault touched, and end with a summary: what drifted since the last lint, what was fixed (renames/splits listed explicitly with old→new names), what was deferred and why.

a scan skeleton (adapt per vault; run from `~/development/obsidian/`):

```bash
python3 - <<'EOF'
import os, re
link_re = re.compile(r'\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]')
# walk the vault (skip dotdirs), build {basename, vault-relative} namespace,
# collect link targets per file (strip trailing '\' from table-escaped pipes),
# then report: pages absent from index files, targets resolving nowhere,
# pages with zero inbound links, basenames present in BOTH vaults, personal
# pages whose link targets resolve only in the work namespace. for the work
# vault, extend the namespace with 'personal/<rel>' + basenames from
# ../personal-software (the symlink).
EOF
```

## github permalinks

when citing source code, always use commit-sha permalinks (pinned to a specific commit, not a branch). branch URLs break when files move; sha permalinks are permanent.

**label format:** backtick code-formatted, `repo-name:path/to/file#LN`
**url format:** `https://github.com/org/repo/blob/<40-char-sha>/path/to/file#LN`

rendered in markdown:
```
[`repo-name:path/to/file.ext#L42`](https://github.com/org/repo/blob/<sha>/path/to/file.ext#L42)
```

rules:
- omit `#LN` when linking to a whole file rather than a specific line
- get the sha from `git log --format="%H" -1` in the repo, or via github's "copy permalink" button (y key on any github file view)
- if line numbers would shift frequently (e.g., config files that change often), link to the file without `#LN` rather than an outdated line

## mermaid diagrams

**when to use mermaid vs ascii:** check the longest line in the diagram. if it exceeds ~60 characters, use mermaid — ascii diagrams wider than that wrap badly on mobile screens. below ~60 chars, a simple ascii diagram (e.g. `A → B → C`) is fine.

obsidian's mermaid renderer does **not** interpret `\n` as a line break in node labels or edge labels — it renders literally as `\n`. always use `<br/>` instead:

```
node["first line<br/>second line"]          ✓ correct
node["first line\nsecond line"]             ✗ renders literally
```

specific rules by diagram element:
- **node labels** (`["..."]`, `(["..."])`) — use `<br/>` for multi-line content
- **edge labels** (`|"..."|`) — prefer a single-line label with ` · ` as separator rather than `<br/>`, since edge labels are narrow
- **sequence diagram participant aliases** (`participant x as "..."`) — single-line only; `<br/>` does not work here; keep aliases short and descriptive
- **subgraph titles** (`subgraph title["..."]`) — use `<br/>` if multi-line is needed

when writing a new diagram, scan all node/edge label strings for `\n` before saving.

## important notes

- defer to each vault's schema — it is the source of truth for filename, frontmatter, tags, layout, and log direction
- lowercase everything (filenames and content) per global CLAUDE.md
- **the vaults are git repos** (since 2026-07-18; `.obsidian/workspace.json` ignored) — commit at the end of any session that wrote to a vault; a plain descriptive message, no push (local-only repos)
- prefer atomic pages — many small focused files over one big file
- when editing a page for any reason, preserve unanswered `> q:` blocks the user has added — they are pending work, not clutter
- **obsidian gotchas**: a file deleted while open in an obsidian tab can be resurrected from the editor buffer — verify deletions stick (quit obsidian → delete → scrub the leaf from `.obsidian/workspace.json` → reopen if needed). edit `.obsidian/*.json` only while obsidian is closed. obsidian's watcher may miss edits arriving through a symlinked dir until a vault reload.
