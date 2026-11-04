---
name: slack-mcp-formatting
description: Format Slack messages with readable links, lists, quotes, mentions and code; verify the intended recipient and thread before posting.
---

# Slack message formatting

follow **Slack access** in `CLAUDE-base.md` for route selection. this reference describes formatting, not permission to send or choose a different route.

## browser composer

use the composer’s formatting controls for links, lists, quotes and code. inspect the rendered draft before sending; do not assume API payload markup renders in the browser composer.

select a real mention from the composer’s suggestions and verify the intended person. plain `@name` text alone is not proof of a mention. for a deactivated account, inspect its profile or historical messages rather than guessing an identity.

open the intended conversation and verify its recipients before composing a DM. for a thread reply, open the actual parent message and use its reply composer. after an authorized send, read the posted message in that conversation or thread and verify its content and formatting.

## API-format reference

the syntax below applies only to a supported route that accepts Slack `mrkdwn`. it does not select that route or describe the browser’s rich-text composer.

### links

use slack's angle-bracket syntax -- NOT markdown `[text](url)`:

```
<https://github.com/org/repo/pull/123|#123>
<https://example.atlassian.net/browse/TICK-1|TICK-1>
<https://example.com>
```

plain urls in `<>` auto-link. markdown links do not render as clickable in slack.

### bullets

use `-` with 2-space indent for sub-bullets. slack renders them as native list blocks with proper hanging indent.

```
- top level bullet one
- top level bullet two
  - sub-bullet a
  - sub-bullet b
- top level bullet three
```

never use literal `•` or `◦` characters -- they bypass the list renderer and sub-bullets go flush-left on wrapped lines.

### quotes / blockquotes

prefix lines with `>`. renders as a grey indented block.

```
> this is a quoted line
> second line of the quote
```

### mentions

use `<@USERID>` -- plain text `@handle` renders as plain text, not a tag:

```
<@USER_ID>
```

use a verified Slack user ID. deactivated accounts may be absent from search; inspect historical messages or their profile rather than guessing.

### inline code

wrap in single backticks:

```
`foo = bar`
```

### plain code block

triple backticks, no language tag:

````
```
some output here
another line
```
````

### syntax-highlighted code block

add a language tag after the opening backticks:

````
```python
def hello():
    return "world"
```
````

common tags: `python`, `bash`, `go`, `java`, `scala`, `json`.

### known gotchas

- **`<>` between terms** (e.g. `a <> b`) -- slack parses this as a malformed link; escape as `&lt;&gt;` in the payload, which renders as `<>` visibly
- **double dash** -- `--` stays as `--` in slack (not auto-converted to an em dash)
