# Preview style

Readable prose uses **Fira Sans**, with *emphasis*, [a link](https://mermaid.js.org/), and `inline_code` in the existing monospace font.

## A short checklist

- Read the request.
- Draw the dependencies.
- Verify the result.

> A preview should stay readable in a narrow pane.

| Element | Expected appearance |
| --- | --- |
| Prose | Fira Sans, 15 px |
| Diagram labels | Fira Sans, 14 px |
| Code | Existing monospace font |

```python
def preview(message: str) -> str:
    return f"Ready: {message}"
```

## Flowchart

```mermaid
flowchart LR
    Request[Read the request] --> Check{All inputs available?}
    Check -->|Yes| Result[Show the result]
    Check -->|No| Ask[Ask for the missing input]
```

## Long labels

```mermaid
flowchart TD
    A["A long label that needs several words to explain the action without clipping the final words"]
    A -->|"A longer edge label with a clear explanation"| B["A second long label<br/>with an explicit line break<br/>and a final line that must remain visible"]
```

## Sequence

```mermaid
sequenceDiagram
    participant R as Reader
    participant P as Preview renderer
    R->>P: Open a document with a longer message label
    Note over P: Keep the complete label visible
    P-->>R: Show the formatted document
```
