# request format

the JSON file is temporary input, outside the vault. use the configured `scope` on every request. source and disposition text are data; never turn them into shell commands.

```json
{
  "operation": "capture",
  "scope": "personal",
  "key": "capture-message-id:annotation-1",
  "action": "Discuss simplifying the two navigation choices",
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

each disposition request has `operation`, `scope`, a fresh stable `key`, existing `id`, and a short `reason` describing the user's choice or verified completion:

- `complete` marks the item done; retain completion evidence in `reason`.
- `drop` preserves the item with a dropped disposition.
- `defer` also needs the requested `timing`, `bucket`, or both; it stays unresolved.
- `transfer` also needs `successor`, an exact destination chat ID or retrieval handle. no chat is created or resumed.

the same key and same request return the original item without a new commit. reusing a key for different input fails. do not replace a retry key simply to make an operation succeed. a new explicit request receives a new key even if its wording resembles another item.

`annotate` adds source metadata to an existing unchecked legacy item. use the capture fields with an existing `id` and without `action`. preserve its text, anchor, intended timing and bucket. verify its original source first; never label migration as new user work. completed or dropped legacy items require a separate explicit migration decision.

the Markdown checkbox and action are readable; the following JSON comment carries provenance and dispositions. keep both together. the parser rejects duplicate IDs, anchors, event keys and inconsistent checkboxes. the notes transaction retains a failed writer's dirty paths and lock; that owner must repair its transaction. never clear another writer's lock or retry a failed write as a new capture.
