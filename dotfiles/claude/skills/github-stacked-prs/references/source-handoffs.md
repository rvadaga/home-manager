# source handoffs

use a short-lived exclusive lock only while the stack integrator adopts a handoff, resolves a cherry-pick conflict, restacks, verifies remote leases, or publishes. each lock names the exact branch, history, or path resource it protects and an observable condition that releases it. release the lock as soon as that operation finishes or aborts. one stack integrator owns each locked operation and is the only public publisher.

when source changes are independent, implementation and validation run in parallel by default. each assignment has one bounded source worker in a separate isolated checkout and names the owning layer, allowed paths, intended behavior, and required tests. an owner, polish worker, or bounded subagent may fill that role. no source worker edits the integrator's checkout or another worker's checkout. validators and polish may also run concurrently on disjoint immutable trees and paths in separate isolated checkouts. an integration lock never freezes unrelated source implementation, validation, validators, or polish.

when overlap, a semantic dependency, or uncertain independence requires serial source work, finish and accept one worker's immutable handoff before assigning the next worker. give the next assignment the resulting dependency tip as its explicit immutable base. do not hold an integration lock while either worker implements or validates its source change.

one isolated bounded worker returns exactly one immutable commit. the handoff records the exact commit sha and parent or base, changed paths, tests and test-quality evidence, clean porcelain, and known dependencies. the worker does not rewrite stack history, merge its branch into an owning layer or stack branch, or publish a stack ref.

the integrator rederives readiness and remote leases; verifies each handoff's base, path scope, content, tests, and dependencies; and adopts each approved handoff onto its owning layer in dependency order with `git cherry-pick <sha>`. never merge the worker branch. only the integrator resolves a cherry-pick conflict, serially, and then reruns affected tests. the integrator proves one linear commit sequence for every layer and the cumulative stack. only then does the integrator restack, validate, and publish once with the official flow.

accept independent, validated one-commit handoffs into one batch before opening one ordered integration, restack, and publication window. a batch is valid only when each handoff has a separate path claim, no dependency on another handoff in the batch, and complete validation evidence. adopt dependent or overlapping handoffs serially from the accepted earlier tip. do not acquire the integrator lock while a source worker or read-only validator is still running.

| case | execution |
|---|---|
| separate isolated checkouts, complete assignments, exactly one commit per worker, disjoint allowed paths, and no semantic dependency | run source implementation and validation in parallel; the integrator uses `git cherry-pick <sha>` in approved dependency order |
| validators or polish inspect disjoint immutable trees and paths in separate isolated checkouts | run them concurrently |
| a handoff adoption, cherry-pick conflict resolution, restack, lease verification, or publication lock names its exact branch, history, or path resource and an observable release condition | hold the lock only for that operation and release it when the condition is met |
| any allowed path overlaps | finish and accept one immutable handoff, then assign the next worker from the resulting dependency tip |
| a cross-layer semantic dependency exists | finish and accept the dependency handoff, then assign the dependent worker from the resulting dependency tip |
| a cherry-pick conflicts | only the integrator resolves it, serially, then reruns affected tests |
| independence cannot be proved | finish and accept one immutable handoff, then assign the next worker from the resulting dependency tip |
| a checkout is shared or an assignment is incomplete | reject parallel work |
| one lock spans source implementation, validation, integration, and publication | reject the blanket lock |
| a lock omits the exact resource or an observable release condition | reject the lock |
| a lock freezes unrelated source implementation, validation, validators, or polish | narrow the lock before proceeding |
| a worker returns zero or more than one commit | reject the handoff |
| a handoff's commit, parent or base, paths, tests, or dependencies do not match its assignment | reject the handoff and resolve the mismatch before integration |
| a source worker changes stack metadata or history, merges a worker branch, or publishes | reject the handoff |
| adoption would merge the worker branch, skip `git cherry-pick <sha>`, or create a merge commit or octopus merge | reject that adoption and preserve linear history |
| more than one task would publish | reject publication |

ordinary published pull requests that are not github-managed stack layers keep the separate local-first merge-main rule. this section does not authorize rebasing or force-updating them.
