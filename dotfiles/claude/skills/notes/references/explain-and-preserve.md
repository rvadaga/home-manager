# explain the mechanism and preserve the meaning

## explain what the reader needs to understand

start with the question the note answers and why the answer matters. name the actual file, value, operation, or decision before introducing a shorthand label.

for a technical mechanism, trace the relevant input through the operation to its result. use a small example or pseudocode when unfamiliar syntax hides that sequence. explain the condition that changes the result; do not make the reader learn an entire library to follow one branch.

when documenting a setting, explain what it controls and which failure or tradeoff it addresses. a value and its name alone may not explain why someone would choose it. distinguish a configured value, a measured result, and an inference from either.

keep enough detail for the intended reader. an overview needs the problem and the decision; an implementation note may also need the exact calls and edge cases. put useful depth in a linked section or atomic page when it interrupts that explanation.

## shorten without changing the claim

keep the edit within the requested sections and preserve the surrounding document's style. preserve meaningful ordering, such as chronology, and comments attached to text being edited. compare the revised text with its source, not just with a desired length. check whether it still explains:

- the problem and why the proposed behavior helps;
- the conditions, alternatives, and tradeoffs that affect the decision;
- what is known, inferred, proposed, or still unanswered; and
- the evidence and operational constraints needed to use the answer correctly.

account for each substantive point removed: retained elsewhere in the page, moved to a linked page, or corrected or removed because the source shows it is false, obsolete, or redundant. open any destination page and confirm the promised detail is there. link it where the reader first needs it. this can be a working comparison; it does not require a new audit document.

an unanswered question must remain a question. do not turn an option into a requirement or a proposed dependency into an established prerequisite. preserve pending inline questions under the notes skill's existing rule.

for example, shortening a retry design to “safe retries” loses the decision about completed work. “check which steps finished, skip those, and retry the unfinished steps” preserves that mechanism when it is what the source actually proposes. it still needs any source constraint on when skipping is safe.

finally, read the revised passage on its own. a reader should be able to explain what happens, why, and what remains uncertain without recovering deleted context from the conversation.
