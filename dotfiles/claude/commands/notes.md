---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(mkdir *), Bash(ls *)
description: read or save notes in obsidian vaults. "read <topic>" to pull up notes, "save <topic>" to save durable findings from the conversation.
---

## your task

manage notes in the user's obsidian vaults at `~/development/obsidian/`. two modes based on the first argument word:

- **read \<topic\>**: find and display existing notes matching the topic
- **save \<topic\>**: save durable findings from the current conversation as a wiki page

if no mode word is given, default to **save**.

## vaults

- `personal-software` — general software engineering, architecture, programming
- `oss-vespa` — vespa open-source search engine (source-code reading wiki)

each vault has its own schema file at the vault root (`SCHEMA.md` or `CLAUDE.md`) — **always read it first** before writing, since conventions (directory layout, frontmatter, tags) differ by vault.

## vault selection

- vespa open-source internals (proton, distributor, bucket-distribution, etc.) → `oss-vespa`
- general software/engineering topics → `personal-software`
- if ambiguous, ask the user which vault to use

## common setup

1. pick the target vault per the rules above
2. read the vault's schema file (`SCHEMA.md` or `CLAUDE.md`) for conventions — filename style, frontmatter template, directory layout
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
   - filename: lowercase, hyphenated, descriptive (e.g., `vespa-metrics-pipeline.md`)
   - frontmatter: follow the vault's template (always includes a `tags` array; some vaults also include `created` or `source`)
   - content: lead with a one-line summary, then durable knowledge (findings, architecture, code traces, takeaways)
   - cross-link to related pages using obsidian `[[wikilinks]]`
   - mark uncertain or inferred claims with `[inferred]` (per oss-vespa schema)
   - cite source code paths when relevant (e.g., `path/to/file.ext:line`)
   - do NOT include session-specific details (timestamps in prose, conversation ids, task progress)
6. update `index.md`: add a one-liner for the new page under the appropriate section — format matches existing entries (e.g., `- [[page-name]] — short description`). if no fitting section exists, add a new heading
7. append an entry to `log.md` in the format: `## [YYYY-MM-DD] action | description` — use today's date from the session context
8. if updating an existing page and the scope has changed significantly, suggest a new filename and ask the user before renaming

## mermaid diagrams

obsidian's mermaid renderer does **not** interpret `\n` as a line break in node labels or edge labels — it renders literally as `\n`. always use `<br/>` instead:

```
node["first line<br/>second line"]          ✓ correct
node["first line\nsecond line"]             ✗ renders literally
```

specific rules by diagram element:
- **node labels** (`["..."]`, `(["..."])`, `(["..."])`) — use `<br/>` for multi-line content
- **edge labels** (`|"..."|`) — prefer a single-line label with ` · ` as separator rather than `<br/>`, since edge labels are narrow
- **sequence diagram participant aliases** (`participant x as "..."`) — single-line only; `<br/>` does not work here; keep aliases short and descriptive
- **subgraph titles** (`subgraph title["..."]`) — use `<br/>` if multi-line is needed

when writing a new diagram, scan all node/edge label strings for `\n` before saving.

## important notes

- defer to each vault's schema — it is the source of truth for filename, frontmatter, tags, and layout conventions
- lowercase everything (filenames and content) per global CLAUDE.md
- obsidian vaults are currently not git repos — do not run git commands against them
- prefer atomic pages — many small focused files over one big file
