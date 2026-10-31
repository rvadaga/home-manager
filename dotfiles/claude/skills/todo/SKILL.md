---
name: todo
description: capture, review, order, or maintain durable follow-ups. use for todo requests, outstanding items across chats or estates, ideas left to explore, session next-step planning, and scheduled checklist upkeep.
---

# todo

`todo` refers to this skill's capture, review, format and maintenance contract. keep one canonical checklist, with single-line summaries grouped under the current relevant Codex chat's linked title and expandable descriptions beneath each item. full details stay readable in the note; comments hold provenance and disposition metadata. read [the schema](references/requests.md#checklist-schema-and-display) for representation and preservation rules; read [requests](references/requests.md) before a write.

## capture

infer a short actionable label, the full request and context, whether the user wants to discuss, implement, investigate or consider it, and only the timing they requested. preserve uncertainty. selected response text is context, not another instruction. capture does not investigate or execute the idea, create or resume a chat, make a ticket, notify anyone, or schedule work.

read `references/storage.json` to locate the checklist. if `references/work-vault.md` exists, read it for work routing and confidentiality. work-internal content has no personal fallback. invoke `notes` and read the configured vault schema before writes. no accompanying research note or routine destination question is needed.

preserve the original source chat ID, optional capture message ID and annotation message/offsets. use a verified retrieval handle when an exact chat ID is unavailable. the relevant carrying chat defaults to that source. when the user's request or explicit source context establishes another relevant chat, verify the association and record a transfer with its reason. ask only when that association is unclear. a transfer changes where the reminder appears, not who has accepted or started the work.

verify the carrying chat's current title through the chat tools, including archived chats when needed. preserve the title verbatim and use its exact ID for navigation. record known estate membership with a stable estate ID, readable title and source evidence. a repository path, title prefix or optional project label alone is not proof of estate membership. missing metadata never prevents capture: retain the known handle and show what could not be verified.

use the capture message ID plus annotation index as the stable operation key. a retry keeps that key; separate human requests keep separate keys. attach verified project and artifact context when available. do not merge similar requests automatically.

write the request JSON outside the vault and run `python3 <todo-skill>/scripts/todo.py apply --request <absolute-json-file> --owner <current-chat-id>`. the helper allocates IDs, updates session groups and commits through the notes transaction. read back the result and confirm the ID, concise label and exact `file_link`. use the stable `block` link in notes; recalculate line links on every read. a failed write is unsaved.

## review across chats and estates

read the checklist independently of which chats are active. archiving a chat leaves its unresolved reminders discoverable. the helper supports:

| request | read-only view |
|---|---|
| pool all outstanding items, across all estates | `show --view unresolved` |
| outstanding action, excluding someday | `show --view outstanding` |
| ideas left to explore | `show --view ideas` |
| a particular chat | `show --view session --chat <exact-id>` |
| an estate | add `--estate <verified-estate-id-or-title>` to a view |
| parked ideas | `show --view someday` |
| one full record, including closed history | `show --view all --id T001` |
| every record | `show --view all` |

add `--format markdown` for compact groups with linked chat titles. JSON includes full action/context, source, history, timing and disposition. `unresolved` includes open and deferred items in both buckets. `ideas` includes unresolved discuss, investigate and consider items, including someday; it does not silently turn implementation tasks into ideas. clarify a broader interpretation in the answer when the user asks for it.

for estate queries, resolve missing membership from authoritative project or estate records where possible. disclose unclassified items rather than claiming a filtered result is complete. all-estate views keep them visible. coverage means captured items in this checklist, not every unfinished thought in every transcript; a historical backfill is a separate requested task.

render one summary line per item with its ID/link, short label and useful timing/disposition, followed by a collapsed Details callout containing the full description and context. group by the relevant chat and use verified titles as navigation links. preserve someday and deferral labels. avoid copying state into another tracker; existing status and catch-up views link to these canonical IDs.

## suggested order within a chat

when asked what order to address the outstanding items, read every unresolved item for that chat, including its full details. use known prerequisites, requested timing, decisions that unblock other work, and relevant source context to propose an order with brief reasons. distinguish established dependencies from your suggestions, and identify work that can proceed independently. keep someday ideas visibly parked unless the user chooses to include them.

do not invent priorities, deadlines or completed work. a suggested order is advice in the response; it does not rewrite the checklist order or start the tasks. before wind-down, surface relevant unresolved items, especially requested discussions before wind-down. record completion, deferral, dropping or transfer only from the user's choice or verified completion within an already authorized task. deferral remains unresolved.

## maintenance

for a requested or scheduled todo lint, read [the schema](references/requests.md#checklist-schema-and-display), run `python3 <todo-skill>/scripts/todo.py lint`, and inspect the full records. refresh current chat titles and verified estate information through read-only sources. use a `maintain` request to shorten display labels, consolidate session groups, restore consistent formatting and move completed/dropped records below unresolved items within their session. retain the full request and context; never truncate them to meet a display target.

the helper's maintenance operation changes presentation and navigation metadata only. it preserves IDs, anchors, original source, carrying chat, intent, timing, bucket, disposition and every history event. keep all records in the same checklist. do not delete old items, merge similar requests, infer completion from inactivity, transfer chats, change priorities or execute captured work during lint. report ambiguous meaning or membership for review. unchanged maintenance produces no commit or log entry.

use the notes transaction and its validator for every write. verify retained records and the actual Markdown result after maintenance. a daily maintenance request authorizes that upkeep at its configured schedule; ordinary capture does not create an automation. keep scheduled upkeep quiet when nothing meaningful changed and report only meaningful repairs, failure or required user input. reuse an existing matching schedule when present.
