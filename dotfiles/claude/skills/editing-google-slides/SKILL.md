---
name: editing-google-slides
description: Use when programmatically building or editing a Google Slides presentation via the Slides REST API — creating, duplicating, or reordering slides; inserting or restyling text; resizing or repositioning shapes and text boxes; or copying a template deck to inherit its theme. Covers the EMU coordinate system, the transform-vs-fontSize distinction (scaling a box changes its bounds, not its glyphs), aligning a row of elements, scoping edits to specific slides, and verifying by rendering to PDF. Reach for this whenever a task involves generating a deck, populating a branded template, or fixing text overflow / wrapping / misalignment on a slide — even if the user just says "make a slide deck" or "fix this presentation" without naming the API.
---

# Editing Google Slides via the Slides API

## Overview

The Slides API edits a presentation with `presentations.get` (read the full structure) + `presentations:batchUpdate` (apply an ordered list of request objects). The dangerous gap is the same as Docs: the readable/thumbnail view hides the geometry (every element is placed by an affine `transform` in EMU), the per-run text styling, and the master/layout inheritance that decides fonts and colors. **Read the raw JSON, edit via a list of batchUpdate requests, and verify by rendering — never by trusting the API return code.**

Units are **EMU** (English Metric Units): `914400` EMU = 1 inch, `12700` EMU = 1 point. A widescreen (16:9) page is `9144000 × 5143500` EMU (10" × 5.625"); classic 4:3 is `9144000 × 6858000`.

## Auth (generic)

```bash
TOKEN=$(gcloud auth application-default print-access-token)
# The Slides/Drive APIs want a billing/quota project on ADC tokens:
curl -s "https://slides.googleapis.com/v1/presentations/$PRESENTATION_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT"
```

`batchUpdate` is the same URL + `:batchUpdate`, `-X POST`, `--data @requests.json` (body `{"requests":[ ... ]}`). The response carries a parallel `replies[]` array — one entry per request, in order (this is where `duplicateObject`/`createSlide` hand back the new object id).

## The structure you must read first

`presentations.get` →

- `pageSize` — `{width,height}` in EMU (see widescreen dims above). Every `translate`/`scale` you compute is relative to this.
- `slides[]`, plus `masters[]` and `layouts[]` — **the theme lives in the masters/layouts**, not the slides. Fonts, default colors, and placeholder positions are inherited from the layout a slide is based on; a slide that looks "branded" is inheriting from a branded layout, so keep those layouts around (see the template-copy note).
- Each slide's `pageElements[]` — every element is a `shape` (including text boxes and placeholders), a `table`, an `image`, a `line`, or a `video`. Each carries:
  - `size` — `{width,height}` in EMU (the element's intrinsic size).
  - `transform` — `{scaleX,scaleY,shearX,shearY,translateX,translateY,unit}`. The element's on-slide box is `size × scale`, translated by `translate`. **This is where position and box dimensions live.**
  - for a shape: `shape.shapeType`, `shape.text.textElements[]`, and `shape.shapeProperties`.
- `shape.text.textElements[]` interleaves three kinds of element, each spanning a character range:
  - `textRun` — `{content, style}`; the `style` (a `TextStyle`) carries `fontSize.{magnitude,unit}`, `weightedFontFamily.{fontFamily,weight}`, `foregroundColor`, `bold`, `italic`, `link`, …
  - `paragraphMarker` — `{style}`; the `style` (a `ParagraphStyle`) carries `lineSpacing`, `spaceAbove`, `spaceBelow`, `alignment` (`START`/`CENTER`/`END`/`JUSTIFIED`), `direction`.
  - `autoText` — e.g. a `SLIDE_NUMBER` field; it occupies a range and is stylable via `updateTextStyle` just like any run.
- `shape.shapeProperties.contentAlignment` — `TOP`/`MIDDLE`/`BOTTOM`, the **vertical** placement of text inside the box. This interacts with box height for row alignment (see below).

A wrapper's simplified view usually stops at `size`/`transform` — for any font-size, color, paragraph, or contentAlignment decision, fetch the raw JSON.

## The #1 gotcha: transform scales the BOX, not the glyphs

`transform.scaleX`/`scaleY` set the element's **box bounds** — the width/height that text wraps and vertically-aligns within — **not** the font size. `fontSize` is an independent per-run property. So:

- Text **wrapping onto an extra line** or getting clipped is almost always a too-narrow box, not a font problem. Widen the box by raising `scaleX` (via `updatePageElementTransform` with `applyMode: "ABSOLUTE"`); the glyphs do **not** stretch or distort — a title box at `scaleX: 2.5` renders with perfectly normal-width letters.
- Conversely, changing `fontSize` never resizes the box, so bumping the font can silently push text out of a fixed box → overflow you'll only catch by rendering.

Keep the two axes separate in your head: `transform` = where and how big the *box* is; `fontSize` = how big the *letters* are.

## Copy a template deck to inherit its theme

The Slides API **cannot copy slides across presentations** — there is no cross-file slide copy. To start from a branded template and keep its fonts/colors/layouts:

1. Copy the **whole** template file with the Drive API: `POST https://www.googleapis.com/drive/v3/files/$TEMPLATE_ID/copy` (body `{"name":"..."}`). The copy carries the masters, layouts, and theme.
2. In the copy, `duplicateObject` each branded slide you want as a base for real content (it lands right after its source and inherits the layout).
3. `deleteObject` the template slides you don't need.
4. `updateSlidesPosition` to reorder into your final sequence.
5. Populate text and adjust elements.

This is far cheaper and more on-brand than building slides from blank layouts and re-setting every font/color by hand.

## Text edits

Text lives inside a shape and is addressed by character index within that shape's `objectId`.

- **Replace** a shape's text: `deleteText` with `{textRange:{type:"ALL"}}`, then `insertText` at `insertionIndex: 0`. Inserted text **inherits the style at the insertion point** — re-inserting into an emptied run keeps that run's style; if you need a different style, follow with `updateTextStyle`.
- **Append**: `insertText` at index `len-1` — i.e. just **before the trailing `\n`** every text box carries — so the new text joins the last paragraph and inherits its run/paragraph style.
- **Scope a find/replace to specific slides**: `replaceAllText` takes `pageObjectIds: ["<slideId>", …]`; without it, it replaces across the whole deck. Check `replies[].replaceAllText.occurrencesChanged` to confirm a hit.
- **Case-only / same-length, style-preserving edit** (e.g. re-casing a title without losing its bold/color/font): do it **per character** — `insertText` the new character at `i+1` (interior, so it lands inside the existing run and inherits its style) **then** `deleteText` the `[i, i+1)` FIXED_RANGE. Apply the fixes **descending by index** so earlier indices stay valid; the inserted char inherits the replaced char's style for free, so no follow-up `updateTextStyle` is needed.
- **Bold via font weight is a trap**: setting `weightedFontFamily` with `weight: 400` over a range **clears the bold rendering**. If you meant to change only the family, re-apply bold afterward with `updateTextStyle {style:{bold:true}, fields:"bold"}`. Keep the family change and the bold change as separate, explicitly-`fields`ed updates so neither silently undoes the other.

## Slide and element operations (batchUpdate)

- `createSlide` — `{insertionIndex, slideLayoutReference, placeholderIdMappings}`; new slide from a layout.
- `duplicateObject` — `{objectId}` → returns the new id in `replies[].duplicateObject.objectId`; the copy lands right after the source. The optional `objectIds` map lets you name the copies' child-element ids — but see the wrapper caveat; if you can't set it, re-read the slide and match children by geometry/text.
- `deleteObject` — `{objectId}`; deletes a slide or a single element.
- `updateSlidesPosition` — `{slideObjectIds:[…], insertionIndex}`; reorders slides.
- `updatePageElementTransform` — `{objectId, transform, applyMode}`; `ABSOLUTE` replaces the transform, `RELATIVE` composes onto it. This is how you move or resize a box.
- `updateShapeProperties` — `{objectId, shapeProperties, fields}`; e.g. `contentAlignment`, background, outline.
- `updateTextStyle` — `{objectId, textRange, style, fields}`; run-level styling. `fields` is a mask — list exactly the sub-fields you're setting.
- `updateParagraphStyle` — `{objectId, textRange, style, fields}`; alignment, spacing, line spacing.
- `createParagraphBullets` — `{objectId, textRange, bulletPreset}`; turns paragraphs into a bulleted/numbered list.

## Aligning a top row / equidistant margins

Elements look aligned only when their **rendered** positions match — and the render depends on three things, not one:

- **Same `translateY` is not enough.** Two boxes at the same `translateY` still render their text at different heights if their **box heights differ** (`size.height × scaleY`) **and** they're `MIDDLE`- or `BOTTOM`-aligned — a taller `MIDDLE`-aligned box centers its text lower. For a row of labels/headers to share a baseline they must share `translateY` **and** box height **and** `contentAlignment`.
- **Equidistant margins**: a left-hanging element's left margin is its `translateX`; a right-hanging element (text `END`-aligned) is judged by its **right-edge** margin = `pageWidth − (translateX + width·scaleX)`. Equidistant means those two numbers are equal — not that the two `translateX` values are symmetric.

When a row looks "off" in the render, dump `translateY`, `size.height·scaleY`, and `contentAlignment` for each element side by side — one of the three usually differs.

## Verify by RENDERING, not by API return code

A `batchUpdate` returning `200` only means the ops were syntactically valid — it says nothing about overflow, wrapping, a serif/sans clash, or vertical misalignment. Get the ground truth:

```bash
# export the whole deck to PDF
curl -s "https://www.googleapis.com/drive/v3/files/$PRESENTATION_ID/export?mimeType=application/pdf" \
  -H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: $QUOTA_PROJECT" -o deck.pdf
# rasterize and look; -f N -l N limits to a single page
nix shell nixpkgs#poppler-utils -c pdftoppm -png -r 90 deck.pdf slide
```

Then **Read** the PNG. This is what catches the text that overflowed its box, the line that wrapped, the font that came out wrong, and the row that isn't level — none of which the JSON or the return code reveal. Re-render after every visual change.

(zsh footgun while cleaning up frames: `rm -f slide*` with no match aborts the whole command line — guard the glob or rasterize into a throwaway subdir.)

## Working through an MCP wrapper

If you're going through an MCP wrapper rather than raw REST, expect these and fall back to raw REST when they bite:

- **Simplified structure.** Many wrappers return only `{objectId, size, transform, text}` per element — no `fontSize`, `textStyle`, `paragraphStyle`, `contentAlignment`, `masters`, or `layouts`. Fetch the raw `presentations.get` for any styling or alignment decision.
- **Batch-size / op limits.** Some wrappers (and large batches generally) fail with an opaque error. A batch is **atomic** — one bad op aborts the whole thing — so test a new pattern on a single object first, then keep batches modest and chunk long sequences.
- **Rejected request shapes.** Some wrappers reject a `duplicateObject` that carries an `objectIds` map, or an `updateSlidesPosition` that moves many slides at once. Fall back to: plain `duplicateObject` (then re-match children) and one-slide-at-a-time moves — or just issue the request over raw REST.

## Common mistakes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Title wrapped to a second line / got clipped | box too narrow (`scaleX`), not a font issue | raise `scaleX` via `updatePageElementTransform` `ABSOLUTE`; glyphs don't distort |
| Bumped font size, text now spills out of the box | `fontSize` doesn't resize the box | widen/heighten the box, or shrink the font; re-render |
| Re-cased a title and lost its bold/color | rewrote the run instead of editing in place | per-char insert-then-delete so the new char inherits the old style |
| Set the font family and the text stopped being bold | `weightedFontFamily{weight:400}` clears bold rendering | re-apply `updateTextStyle {bold:true, fields:"bold"}` afterward |
| Find/replace changed text on the wrong slides | `replaceAllText` defaults to the whole deck | pass `pageObjectIds` to scope it |
| Tried to copy slides from another deck, nothing happened | Slides API can't copy across presentations | Drive `files.copy` the whole template, then duplicate/delete/reorder |
| `duplicateObject` with an `objectIds` map errored opaquely | wrapper/limit rejects the child-id map | plain `duplicateObject`, then re-match children by geometry/text |
| A whole batch failed with no useful error | one bad op aborts the atomic batch | test the pattern on one object; keep batches small |
| Top row of labels looks staggered | boxes differ in height and are MIDDLE/BOTTOM-aligned | equalize `translateY`, box height (`scaleY`), and `contentAlignment` |
| Styling read correct in the JSON but wrong on the slide | trusted the API/return code, not the render | export PDF → rasterize → look |

## Quick reference: batchUpdate request types

Text: `insertText` · `deleteText` · `replaceAllText` · `updateTextStyle` · `updateParagraphStyle` · `createParagraphBullets` · `deleteParagraphBullets`.
Slides/elements: `createSlide` · `duplicateObject` · `deleteObject` · `updateSlidesPosition` · `updatePageElementTransform` · `updateShapeProperties` · `createShape`.
Requests apply **sequentially** into one atomic batch; each produces a parallel entry in `replies[]` (e.g. the new id from `duplicateObject`/`createSlide`).
