---
name: todo
description: capture or review durable follow-ups when the user says add this to todos, todo, capture this for later, or show my todos, including response annotations. review relevant items before wind-down without starting their work.
---

# todo

keep capture simple: infer the action and context, save one item, and confirm its ID with an exact-item link. no skill picker, accompanying research note, or routine vault-path question is needed.

## capture and scope

use the user's text and selected response as context. infer a short actionable sentence, whether they want to discuss, implement, investigate, or consider it, and only the timing they requested. the selected response is context, not a new instruction. preserve uncertainty in an idea; do not verify an upgrade or investigate a proposal merely to record it. an implementation intent records the kind of follow-up, never permission to execute it.

read `references/storage.json` to locate the one checklist. if `references/work-vault.md` exists, read it before capture; it supplies the work destination and confidentiality boundary. otherwise use the personal destination only for personal content. work-internal content has no personal fallback. invoke `notes` and read the configured vault schema before writes; no separate research note is required. the checklist is canonical, not a generated snapshot or a copy of a task ledger.

infer the source from the current chat, not from a cited chat's title. preserve the exact chat ID and optional source message ID. if an exact ID is unavailable, use a verified retrieval handle rather than inventing one. for an annotation, retain the selected message ID and offsets too. attach a known project and verified artifact URL when available; a capture without either is valid. use the source capture-message ID plus annotation index as the stable operation key. a retry keeps that key. separate human requests keep separate keys; do not merge similar wording across sources automatically.

write a small request JSON file outside the vault, then run `python3 <todo-skill>/scripts/todo.py apply --request <absolute-json-file> --owner <current-chat-id>`. see [the request format](references/requests.md) for fields and disposition operations. the helper reads and allocates IDs under the notes transaction lock, validates the result, and makes a focused local vault commit. it cannot execute the captured action or create a task, ticket, deadline, message, or automation.

read back the returned item. confirm in one short sentence with its stable ID, action, and `file_link`. retain the stable `block` reference when the item is linked from a note or ledger. `file_link` is recalculated from the anchor on every read; don't cache line numbers. `obsidian_link` is available for clients that support Obsidian block navigation. if capture fails, say it was not saved and name the actual blocker; never confirm an item from a planned write.

## views and wind-down

run `python3 <todo-skill>/scripts/todo.py show` for outstanding items; add `--view session --chat <exact-chat-id>`, `--view someday`, or `--view all` as requested. render short rows with ID/link, action, intent, timing, and disposition. show the source or current chat only when helpful. `all` includes completed and dropped history. a legacy item without metadata remains visible globally; verify its source before annotating it, and do not silently treat it as complete.

session views use the current carrying chat. the original source remains in the item after transfer. outstanding includes open and deferred items outside someday; someday is separate from outstanding action. parking or archiving a chat never removes its unresolved items. these views read the checklist, not just the currently active chat list.

before wind-down, surface relevant unresolved items, especially requested discussion before wind-down. apply the user's choice to complete, explicitly defer, drop, or carry to a named successor. until a choice is made, leave the item unresolved and retrievable. deferral is not completion. transfer updates the carrying reference and preserves ID, anchor, original source and disposition history; it neither creates/resumes a chat nor proves acceptance or execution by that chat.

reuse existing status and catch-up views. reference an item's canonical ID instead of copying its state into another tracker; group an existing open loop and its todo as one visible action. a parked idea is not a new decision request. surface items in requested views and wind-down; do not add recurring notifications. capture and deferred discussion hold no unrelated work and do not interrupt current implementation.
