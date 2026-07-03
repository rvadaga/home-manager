---
name: editing-google-docs
description: Use when programmatically editing an existing Google Doc via the Docs REST API — inserting or replacing text, changing fonts/sizes, adding/removing list bullets, or preserving anchored comments — especially a shared doc others may be editing at the same time. Also covers creating a formatted doc via Drive HTML import and cleaning up the artifacts that import leaves (stray horizontalRule elements from CSS borders, Arial list-glyph fonts), and verifying edits by rendering.
---

# Editing Google Docs via the Docs API

## Overview

The Docs API edits a document with `documents.get` (read structure) + `documents:batchUpdate` (apply a list of requests). The dangerous gap: the document is a flat character stream addressed by integer indices, but the readable/markdown export hides those indices, the paragraph/list structure, and the per-run font styling. **Read the raw JSON, prefer text-anchored edits, snapshot before editing, verify after.**

## Auth (generic)

```bash
TOKEN=$(gcloud auth application-default print-access-token)
# Docs API requires a billing/quota project on ADC tokens:
curl -s "https://docs.googleapis.com/v1/documents/$DOC_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT"
```

`batchUpdate` is the same URL + `:batchUpdate`, `-X POST`, `--data @requests.json`.

## The structure you must read first

`documents.get` → `body.content[]`. Each `paragraph` has:
- `startIndex` / `endIndex` — the character range (edits address these).
- `elements[].textRun.{content,textStyle}` — `textStyle.weightedFontFamily.fontFamily`, `textStyle.fontSize.{magnitude,unit}`.
- `bullet` (present only for list items) — `listId`, `nestingLevel`. Glyph is in top-level `lists[listId]` (`glyphType: DECIMAL` = numbered).
- Inline objects — person/date **smart-chips**, equations, footnote refs — occupy an index but have **no `textRun`**. When mapping characters to indices, count each such element as its `[startIndex,endIndex)` span; a `textRun`-only concatenation drifts every index after the first chip.

Never derive indices/styling from the markdown export — only from this JSON.

## Two newline characters (the #1 gotcha)

| Char | Effect |
|------|--------|
| `\n` | **new paragraph** (in a list → a new bullet/number) |
| `\v` (U+000B, vertical tab) | **line break within the same paragraph** |

A multi-line code block as **one** list item → join lines with `\v`. Separate paragraphs (one per line) → join with `\n`. Mixing these by accident is what makes a pasted command fan out into numbered bullets.

## Prefer replaceAllText over index math

`replaceAllText` is anchored to text, so it survives index shifts from other edits:

```json
{"requests":[{"replaceAllText":{
  "containsText":{"text":"<exact current text>","matchCase":true},
  "replaceText":"<new text>"}}]}
```

- Match the **exact** current text — including `\v`, trailing spaces, and typos. Extract it from the fetched JSON; don't hand-type it. Assert it's present before sending so you don't silently no-op or mis-target.
- Check `replies[].replaceAllText.occurrencesChanged` in the response (`1` = hit).

Use index ops (`insertText`, `deleteParagraphBullets`, `updateTextStyle`, `deleteContentRange`) only when text-anchoring can't express the edit.

## Concurrency: indices go stale instantly

A collaborator editing the doc shifts every index after their cursor. For any **index-based** request: fetch a fresh `documents.get`, compute indices, and POST in as tight a window as possible — then re-verify. A stale range fails silently (wrong text styled, a line missed, content mangled), not loudly.

**Guard every index-based batch with `writeControl`.** Pass the `revisionId` from the `documents.get` you planned against as `requiredRevisionId`; if the doc moved, the batch fails cleanly (the whole batch is atomic — no partial write) instead of mis-targeting. On that failure, re-fetch → recompute → retry. Make each batch **idempotent** (only edit what's still wrong), so a retry — or splitting a long edit into chunks — can't double-apply.

```json
{"requests":[ ... ],"writeControl":{"requiredRevisionId":"<revisionId from documents.get>"}}
```

A *forked/parallel* agent session is a real second writer: both compute indices off the same fetch and the second blind write lands mid-character. `writeControl` is what turns that into a clean failure you can retry.

## Inserted text inherits style — fix it explicitly

`insertText` gives the new text the paragraph + run style **at the insertion point**, not the style you intended. To match an existing code block, read a known-good line's `textStyle`, then:

```json
{"updateTextStyle":{
  "range":{"startIndex":A,"endIndex":B},
  "textStyle":{"weightedFontFamily":{"fontFamily":"Fira Code","weight":400},
               "fontSize":{"magnitude":10,"unit":"PT"}},
  "fields":"weightedFontFamily,fontSize"}}
```

## Lists: how to get "one bulleted label + plain lines"

- Inserting `\n`-separated text **into a list-item paragraph** makes every resulting paragraph inherit that same `listId` (they all become bullets).
- So: insert the whole block at the start of an existing list item, then `deleteParagraphBullets` over the range covering the lines that should be plain — leaving only the label bulleted.
- `createParagraphBullets` makes a **new** list (restarts numbering); it will not join an existing numbered list. To continue an existing list, split from one of its items instead.

**The list glyph font lives in the list definition, not the runs.** the bullet/number glyph inherits `lists[listId].nestingLevels[n].textStyle`, *not* the paragraph's text runs or its paragraph-mark. so `updateTextStyle` over the item text — even including the trailing `\n` — never changes the marker font; a doc can show Fira-Sans body text with Arial numbers. the only fix is to regenerate the list: `deleteParagraphBullets` then `createParagraphBullets` over the same range, which derives the new glyph style from the paragraphs' current text font. numbering restarts, so recreate each contiguous list as its own range.

## Creating a formatted doc via HTML import (Drive) — and its artifacts

Building a *formatted* doc (tables, headings, real fonts) is far cheaper via a Drive HTML→Doc conversion than via dozens of Docs API inserts. Upload HTML with the target mime set to a native doc:

```bash
curl -X POST "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart" \
  -H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -F 'metadata={"name":"My Doc","mimeType":"application/vnd.google-apps.document"};type=application/json' \
  -F "file=@doc.html;type=text/html"
```

Inline `font-family`/`font-size` in the HTML map to real fonts (any Google Font name resolves). But the converter injects artifacts you then clean up **with this skill's Docs API edits** — find them in the JSON, never trust the visual export to reveal them:

- **CSS `border` → a `horizontalRule` element** placed at the *start of the following paragraph* (a stray divider, easily misread as a section break). find each `elements[].horizontalRule` and delete it with `deleteContentRange` over its `[startIndex,endIndex)`, descending by index.
- **list glyph fonts hard-set to `Arial`** in the list definition — fix by delete + `createParagraphBullets` (see the Lists note above).
- to replace a doc's content while keeping the same id/URL, re-upload with `PATCH https://www.googleapis.com/upload/drive/v3/files/{id}?uploadType=media` (source `text/html`) — Drive re-converts in place.

## Preserving comments while editing anchored text

Comments are anchored to a **text range**, and a comment **orphans** (detaches) only if its *entire* anchored range is deleted — partial edits inside the range keep it attached. So the usual "delete the run, insert the replacement" pattern silently orphans any comment sitting on that run.

To change text a comment is on **without losing the comment**: insert the new text *inside* the anchored range first, then trim the old text off the edges — the range never goes empty, so the comment rides onto the new text.

For case-only or small in-place edits, the cheapest form is **per-character insert-then-delete**: to change the character at index `A`, `insertText` the new character at `A+1` (interior, so it lands inside any anchor) **then** `deleteContentRange` `[A, A+1)`. Bonus: the inserted character inherits the *replaced* character's `textStyle`, so bold / mono / links survive for free — no `updateTextStyle` needed. Apply many such fixes **descending by index**; each insert+delete pair is net-zero length, so lower indices stay valid against the original fetch and the whole set can go in one batch.

This makes equal-length rewrites cheap: a whole-doc re-casing (or any same-length swap) touches only the characters that change and never shifts an index — skip code blocks, inline `mono` runs, and smart-chips, and batch every fix at once.

**Find which text carries comments** via the Drive API — the Docs API does not expose comments:

```bash
curl -s "https://www.googleapis.com/drive/v3/files/$DOC_ID/comments?fields=comments(id,resolved,quotedFileContent(value))" \
  -H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: $QUOTA_PROJECT"
```

`quotedFileContent.value` is the anchored text — but it's the **original snapshot**, frozen at comment-creation time; it does *not* update when the live text changes. So to confirm a comment survived an edit, check that it's still **present** (and not `resolved`), not that the snapshot still matches. Anchors are **position-specific**: editing one occurrence of a string never touches a comment anchored to a *different* occurrence, and pure inserts orphan nothing — only deleting a whole anchored range does.

## Snapshot before, verify after

- Before editing a shared doc: save `documents.get` JSON + `revisionId` so you can diff or restore.
- After editing: re-fetch and inspect structure + styling from the JSON — necessary, but **not sufficient**. Individual fields can each read correct while a *separate* element (a stray `horizontalRule`) or the *list definition* still renders wrong, so a field-check will report "fixed" when the page isn't. For anything visual, get the ground truth: export to PDF (`files/{id}/export?mimeType=application/pdf`), rasterize it (`nix shell nixpkgs#poppler-utils -c pdftoppm in.pdf out`), and **look**.
- If you embedded a runnable command, extract it and run it with the side-effecting parts stubbed to prove it actually runs.

## Common mistakes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Pasted multi-line command became N numbered bullets | used `\n` inside a list item | use `\v` for in-paragraph line breaks |
| Edit did nothing (`occurrencesChanged: 0`) | match text didn't exactly match (a `\v`/space/typo differs) | extract match text from JSON; assert present |
| Wrong text got styled / a line missed | index range computed from a stale fetch | re-fetch immediately before index-based ops |
| Inserted code is in the prose font | new text inherited insertion-point style | `updateTextStyle` over the inserted range |
| New label not numbered like siblings | `createParagraphBullets` made a separate list | split from an existing item of the target list |
| Duplicated a block | replaced a line that had been re-split into many paragraphs | re-inspect current paragraph layout before assuming a block is one unit |
| Comment disappeared after an edit | deleted the whole range a comment was anchored to | insert the new text inside the range, then trim the edges (or per-char insert-then-delete) |
| Every index off after a person/date chip | built the char→index map from `textRun` text only | count each smart-chip element as its `[startIndex,endIndex)` span |
| Blind write mangled a shared doc | index-based batch on a stale fetch, no `writeControl` | set `writeControl.requiredRevisionId`; fail-clean, then re-fetch + retry |
| List numbers/bullets render in a different font (e.g. Arial) than the styled text | glyph font is in the list definition (`lists[].nestingLevels[].textStyle`), not the runs | `deleteParagraphBullets` + `createParagraphBullets` to regenerate from the text font |
| Stray horizontal divider, often right after a heading | HTML import turned a CSS `border` into a `horizontalRule` element | delete the `horizontalRule` via `deleteContentRange` over its span |
| Reported a fix as done, but it still renders wrong | verified JSON fields instead of the rendering | export PDF → rasterize → look; the render is ground truth |

## Quick reference: batchUpdate request types

`insertText` · `replaceAllText` · `deleteContentRange` · `updateTextStyle` · `updateParagraphStyle` · `createParagraphBullets` · `deleteParagraphBullets`. Requests apply sequentially; text-anchored ones are unaffected by earlier index shifts, index-based ones see the post-mutation indices.
