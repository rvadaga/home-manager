---
name: editing-google-docs
description: Use when programmatically editing an existing Google Doc via the Docs REST API — inserting or replacing text, changing fonts/sizes, or adding/removing list bullets — especially a shared doc others may be editing at the same time.
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

## Snapshot before, verify after

- Before editing a shared doc: save `documents.get` JSON + `revisionId` so you can diff or restore.
- After editing: re-fetch and inspect structure + styling (not the export). If you embedded a runnable command, extract it and run it with the side-effecting parts stubbed to prove it actually runs.

## Common mistakes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Pasted multi-line command became N numbered bullets | used `\n` inside a list item | use `\v` for in-paragraph line breaks |
| Edit did nothing (`occurrencesChanged: 0`) | match text didn't exactly match (a `\v`/space/typo differs) | extract match text from JSON; assert present |
| Wrong text got styled / a line missed | index range computed from a stale fetch | re-fetch immediately before index-based ops |
| Inserted code is in the prose font | new text inherited insertion-point style | `updateTextStyle` over the inserted range |
| New label not numbered like siblings | `createParagraphBullets` made a separate list | split from an existing item of the target list |
| Duplicated a block | replaced a line that had been re-split into many paragraphs | re-inspect current paragraph layout before assuming a block is one unit |

## Quick reference: batchUpdate request types

`insertText` · `replaceAllText` · `deleteContentRange` · `updateTextStyle` · `updateParagraphStyle` · `createParagraphBullets` · `deleteParagraphBullets`. Requests apply sequentially; text-anchored ones are unaffected by earlier index shifts, index-based ones see the post-mutation indices.
