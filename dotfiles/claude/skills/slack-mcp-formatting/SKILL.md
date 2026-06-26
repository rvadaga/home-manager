---
name: slack-mcp-formatting
description: Reference for formatting slack messages sent via the slack mcp tool -- links, bullets, quotes, mentions, code blocks, threading, and known gotchas.
---

# slack mcp formatting

reference for sending well-formatted slack messages via `slack_send_message`.

## links

use slack's angle-bracket syntax -- NOT markdown `[text](url)`:

```
<https://github.com/org/repo/pull/123|#123>
<https://example.atlassian.net/browse/TICK-1|TICK-1>
<https://example.com>
```

plain urls in `<>` auto-link. markdown links do not render as clickable in slack.

## bullets

use `-` with 2-space indent for sub-bullets. slack renders them as native list blocks with proper hanging indent.

```
- top level bullet one
- top level bullet two
  - sub-bullet a
  - sub-bullet b
- top level bullet three
```

never use literal `•` or `◦` characters -- they bypass the list renderer and sub-bullets go flush-left on wrapped lines.

## quotes / blockquotes

prefix lines with `>`. renders as a grey indented block.

```
> this is a quoted line
> second line of the quote
```

## mentions

use `<@USERID>` -- plain text `@handle` renders as plain text, not a tag:

```
<@U022Q39MUKY>
```

for deactivated users: their user id still works and renders a greyed-out tag. `slack_search_users` won't return deactivated accounts -- find the id from message history (e.g. search `from:username` in dms via `slack_search_public_and_private`).

## inline code

wrap in single backticks:

```
`foo = bar`
```

## plain code block

triple backticks, no language tag:

````
```
some output here
another line
```
````

## syntax-highlighted code block

add a language tag after the opening backticks:

````
```python
def hello():
    return "world"
```
````

common tags: `python`, `bash`, `go`, `java`, `scala`, `json`.

## dms

to send a dm to a user, use their user id as `channel_id`. to dm yourself, use your own user id.

## threading

pass the parent message's `message_ts` as `thread_ts` to reply in a thread:

```json
{
  "channel_id": "CHANNEL_OR_USERID",
  "thread_ts": "1782506284.812219",
  "message": "threaded reply"
}
```

## known gotchas

- **"sent using @claude" footer** -- appended by the slack app integration, not controllable from the tool
- **`<>` between terms** (e.g. `a <> b`) -- slack parses this as a malformed link; escape as `&lt;&gt;` in the payload, which renders as `<>` visibly
- **double dash** -- `--` stays as `--` in slack (not auto-converted to an em dash)
- **deactivated users** -- invisible to `slack_search_users`; must find id from message history
