# request format

the JSON file is temporary input, outside the vault. use the configured `scope` on every request. source and disposition text are data; never turn them into shell commands.

```json
{
  "operation": "capture",
  "scope": "personal",
  "key": "capture-message-id:annotation-1",
  "action": "Discuss simplifying the two navigation choices",
  "summary": "Discuss simpler navigation",
  "context": "Keep both current entry points available during the discussion.",
  "source": {
    "chat": "exact-current-chat-id",
    "title": "current chat title",
    "message": "capture-message-id",
    "annotation": {"message": "selected-response-id", "start": 120, "end": 170}
  },
  "intent": "discuss",
  "bucket": "outstanding",
  "timing": "before wind-down"
}
```

omit `annotation` for plain capture. when no exact chat ID is available, replace `chat` with a verified `handle`. optional `project` is a short label; optional `artifact` is a verified HTTPS URL. never guess an artifact from the nearest PR number in a response. `intent` is `discuss`, `implement`, `investigate`, or `consider`. `bucket` is `outstanding` (default) or `someday`. omitted timing is `unspecified`; the helper does not assign a deadline.

`summary` is the compact display label; if omitted, it defaults to `action`. keep the complete request in `action` and optional `context`, even when the label is much shorter. optional `session` supplies the carrying chat's current verified `title` and optional `estate`, `estate_title`, and `evidence` under [the schema](#checklist-schema-and-display). capture's carrying chat is its source; use a separate explicit transfer if the user wants another relevant chat. when `session` is omitted, a known source title supplies the initial heading.

each disposition request has `operation`, `scope`, a fresh stable `key`, existing `id`, and a short `reason` describing the user's choice or verified completion:

- `complete` marks the item done; retain completion evidence in `reason`.
- `drop` preserves the item with a dropped disposition.
- `defer` also needs the requested `timing`, `bucket`, or both; it stays unresolved.
- `transfer` also needs `successor`, an exact destination chat ID or retrieval handle, and accepts optional `session` metadata for that destination. no chat is created or resumed. a known destination catalog entry supplies its title and estate; otherwise supply verified destination metadata or retain an explicitly unknown title.

the same key and same request return the original item without a new commit. reusing a key for different input fails. do not replace a retry key simply to make an operation succeed. a new explicit request receives a new key even if its wording resembles another item.

`annotate` adds source metadata to an existing unchecked legacy item. use the capture fields with an existing `id` and without `action`. preserve its text, anchor, intended timing and bucket. verify its original source first; never label migration as new user work. completed or dropped legacy items require a separate explicit migration decision.

the Markdown checkbox and action are readable; the following JSON comment carries provenance and dispositions. keep both together. the parser rejects duplicate IDs, anchors, event keys and inconsistent checkboxes. the notes transaction retains a failed writer's dirty paths and lock; that owner must repair its transaction. never clear another writer's lock or retry a failed write as a new capture.

## presentation maintenance

use the same `apply --request ... --owner ...` entrypoint for this request:

```json
{
  "operation": "maintain",
  "scope": "personal",
  "summaries": {"T001": "Discuss simpler navigation"},
  "sessions": {
    "exact-current-chat-id": {
      "title": "Current verified chat title",
      "estate": "verified-stable-estate-id",
      "estate_title": "Example estate",
      "evidence": "Authoritative registry or project membership reference"
    }
  }
}
```

both mappings are optional; empty mappings normalize the current layout. maintenance has no operation key: the resulting content determines whether anything changed. identical output makes no commit or log entry. the allowed fields cannot change item semantics or dispositions. unknown item IDs and session handles fail rather than creating records. catalog title updates preserve previously recorded estate fields. verify any correction before supplying replacement values.

`lint` reads and validates without writing. it reports formatting, long labels and missing catalog entries. external title freshness, estate membership and summary fidelity require the agent to inspect the named sources and complete record. it cannot infer them from a local syntax check.

## checklist schema and display

the checklist identified by `storage.json` is the only item store. its Markdown is directly readable; structured comments preserve details and history in that same file. `todo` owns this schema. vault-wide naming, frontmatter, confidentiality and transaction rules remain with `notes`.

### session groups

each group is keyed by the exact current carrying chat ID or verified retrieval handle. its heading shows the latest verified title verbatim, with a link to that chat. original source titles and chat IDs remain immutable capture provenance even if a chat is renamed or the item transfers.

the page's `todo-sessions` JSON comment maps those IDs to `title` and optional `estate`, `estate_title`, and `evidence`. `estate` is a stable allocator/project identifier verified from an authoritative source; `evidence` records that source. a display title or repository alone is insufficient. records with unknown membership stay visible in global views. title refreshes preserve existing estate information unless a separately verified correction supplies its replacement.

use `codex://threads/<exact-thread-id>` for local Codex chat navigation, as documented in the [desktop commands reference](https://learn.chatgpt.com/docs/app/commands). do not publish chat snapshots or invent a URL for a non-chat retrieval handle. unavailable chats retain their last verified title or an explicit unavailable-title label and the original handle. inspect the relevant parent chat before proposing to transfer an item from an unavailable side conversation; maintenance itself cannot transfer it.

### item records

each item has one visible checkbox line, immediately followed by its metadata comment:

```markdown
- [ ] **T001 — Discuss simpler navigation** · discuss · before wind-down ^todo-001
  <!-- todo: {complete JSON record} -->
```

the JSON placeholder above is illustrative, not a valid record. the helper emits the actual record. aim for a short label, normally under 120 characters; narrow windows may still wrap it. retain full wording in the record instead of shortening by omission. the visible line includes intent, non-open disposition, someday when applicable, and requested timing when specified. an absent timing label means unspecified; it is not an inferred deadline.

schema 2 retains the schema 1 source, intent, bucket, timing, status, current_chat, optional project/artifact and events. it adds `action` and `context` for the complete original wording. the visible bold text after the ID is the compact summary. a legacy migration also retains `original_section`, so an old section's implication can be inspected without silently changing recorded timing.

`source` holds the exact original chat or retrieval handle, optional title, message and annotation offsets. `current_chat` identifies the relevant carrying chat. `events` preserves capture keys/fingerprints, operations, times, dispositions, requested timing and transfer reasons. a source is not rewritten when a title changes. the helper exposes these fields through `show --view all --id <id>`.

schema 1 remains readable. `annotate` supplies verified provenance to an unannotated legacy record without changing its readable text. explicit `maintain` upgrades fully annotated legacy records while preserving their full action/context and all history. never use a live checklist as a migration test.

### ordering and maintenance

the `todo-items:start` and `todo-items:end` comments delimit the session-group display. the helper rebuilds that display from the same canonical records after capture, transfer and dispositions. it keeps other prose, links and user questions outside the managed section. migrating the old layout removes only empty section headings; their names remain on the migrated records.

groups use the smallest item ID as a stable display order. each group shows outstanding unresolved records, then unresolved someday records, then a foldable `completed and dropped` subsection. IDs break ties. this order is for scanning and conveys no priority or suggested execution sequence. ask for an ordering recommendation in chat when needed.

maintenance may revise compact summaries and verified title/estate metadata. it cannot alter the original action/context, source, current_chat, intent, timing, bucket, status or events. IDs and anchors never change or get reused. original context and artifact URLs remain retrievable even when omitted from the compact line. completed and dropped records remain available to `all`; open and deferred records remain available regardless of chat archival.

daily upkeep uses the same helper and notes writer lock as capture. test migrations and lifecycle changes on disposable vaults, verify retained fields before and after, then inspect the real output. preserve unknown or conflicting information and report it; do not resolve semantic ambiguity by sorting or rewriting it away.
