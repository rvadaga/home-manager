# bottom-up merge and readback

assembled `CLAUDE.md` owns squash-message intent and readiness. this procedure owns transport and post-merge stack handling. it requires actual merge authorization for the exact layer; ready state alone is not merge permission. an existing scoped authorization covers a supported transport without a duplicate request solely because the CLI lacks a message flag. authorization does not prove that a transport can produce the required message. preserve one integrator, required reviews and CI, runtime permissions and all project holds.

## establish the target and transport

1. repeat [complete-restack checks](complete-restack.md#verify-a-complete-restack-before-publication), including its decision about carried validation. record `gh stack view --json`, live remote/PR heads, bases and readiness for the complete ordered stack. retain the pre-merge heads, base and required objects in recovery refs or a verified bundle under [preparation and publication](preparation-and-publication.md).
2. select only the live ready bottom layer. verify its exact approved head, repository, base branch and base commit. both the CLI and async endpoint can include every open ancestor through the selected target: enumerate that exact downstack set and require it to contain only the approved bottom layer. a stack number is not a PR number; the CLI resolves bare numbers as stack numbers first. inspect its resolved selection before confirming. any additional ancestor, unknown relationship or changed head holds this merge.
3. inspect installed `gh stack --version`, `gh stack merge --help`, official source, repository squash defaults, branch rules and merge-queue configuration. prefer the official CLI when its actual route can express the authorized exact message and head. do not invent flags, rely on omitted body defaults, or use ordinary `gh pr merge` / synchronous merge endpoints for a stack.
4. official `gh-stack` v0.3.0 sends only `merge_method` and `merge_action`; it has no message or expected-head controls. for the default empty-body intent, use the official versioned async API only under the blank-default conditions below. `commit_message:""` alone does not clear a generated commit-list body. when no useful CLI/API route is established for the required message, use the built-in browser as the final resort below.

if a queue applies, preserve it. the async API documents no message overrides for `merge_queue`; do not force `direct_merge` to avoid it. hold only the merge when the required message cannot be controlled. inspect both the branch's merge-queue object and applicable rules; an unavailable check is not proof that no queue exists. merge authorization does not authorize changing repository settings. obtain separate explicit authorization for such a change; never change defaults as an automatic workaround or bypass rules.

## distinguish request fields from message control

the official async documentation describes `commit_title` as the title and `commit_message` as detail appended to an automatic message, not a body-replacement field. neither an explicit empty string, an accepted request nor a successful poll proves that the generated body was cleared. do not invent a different field, null or whitespace value, or endpoint to work around this limit.

one successful empty-body readback does not establish replacement when the default body was already empty. under GitHub's commit-message defaults, a one-commit pull request uses that commit's message, while multiple commits produce a list. compare commit count, original messages, repository defaults, exact request/version and independently read landed message before attributing the result to an override. this comparison explains why an observation may be inconclusive; it is not permission to run test merges.

## submit with verified blank defaults

the tested direct route produced the intended subject and empty body for a two-commit remaining layer of a real server stack under `PR_TITLE` / `BLANK`. under `COMMIT_MESSAGES`, real-stack requests retained the source-commit trail, including a request selecting two open layers with two commits each. this supports using a blank default, not claiming that an empty request replaces a nonempty default. ordinary-PR success does not establish stack behavior; queued merges and simultaneous multi-layer merges under blank defaults are not covered by this result.

1. freshly read `gh api repos/<owner>/<repo>` for the exact target repository. require `allow_squash_merge:true`, `squash_merge_commit_title:"PR_TITLE"` and `squash_merge_commit_message:"BLANK"`. retain that response with the independent queue/rules observations. missing, different or unavailable settings stop this API route; consider the browser final resort instead. preserve readiness. a meaningful requested body needs separately established support.
2. recheck the approved head, base, exact downstack set, readiness, authorization, ownership and reviews/CI immediately before submission. require the recorded observations still to match. the expected-head field protects the target, not concurrent topology or settings changes.
3. save the intended subject with exactly one normal PR-number suffix and this complete JSON request, substituting the actual subject and validated head:

   ```json
   {"commit_title":"fix parser (#7)","commit_message":"","sha":"<validated-head>","merge_method":"squash","merge_action":"direct_merge","bypass_rules":false}
   ```

   submit that saved request through the official async endpoint:

   ```sh
   gh api --method PUT "repos/<owner>/<repo>/pulls/<bottom-pr>/merge-async" \
     -H 'X-GitHub-Api-Version: 2026-03-10' --input request.json
   ```

retain HTTP status, response body and command exit status. do not retry an uncertain submission: it may already be running. a `409` may refer to an existing request with different options; retain its UUID, investigate that request and stop new submissions. a `404`, authorization failure, validation rejection or rule failure is not permission to try a synchronous endpoint. never set `bypass_rules:true`. the polling and readback procedure also applies to an existing attempt; observing it does not authorize a new submission.

## poll, then verify independently

for `pending`, require the returned UUID, `expected_head_sha`, `merge_method` and `merge_action` to match this attempt, and reject a reported bypass. poll the same repository, target and UUID with the same API header:

```sh
gh api "repos/<owner>/<repo>/pulls/<bottom-pr>/merge-async/<returned-uuid>" \
  -H 'X-GitHub-Api-Version: 2026-03-10'
```

poll at most once every two seconds for five minutes, with finite HTTP timeouts and responsive waits. retain each result. on timeout or interruption, report pending or unverified with the saved UUID; resume status reads, not a new merge request. handle results explicitly:

- `pending`: still running, not merged.
- `enqueued`: queue admission, not merged. for a recorded direct request this is an unexpected route; stop and inspect the queue without changing its state.
- `failed`: report the server's reason and stop. do not claim a merge or automatically retry.
- `merged`: a candidate completion, including an immediate already-merged response. independently read the PR and landed commit before declaring success.
- unknown/malformed status or unavailable readback: unverified; stop dependent mutation and cleanup.

read `gh pr view <bottom-pr> --repo <owner>/<repo> --json state,mergedAt,headRefOid,mergeCommit` separately. require `MERGED`, a non-null time, the approved source head and the response's merge SHA. then read `gh api repos/<owner>/<repo>/commits/<merge-sha>` independently: compare the entire subject/body with the saved intent and require exactly one parent for the squash commit. preserve that actual parent and any base movement for the descendant analysis. a submitted payload or `merged` response alone proves none of these checks. report mismatches without rewriting or reverting landed history.

the repository's `scripts/check-squash-message.py` separates historical capture checks (`async-capture`) from conditional preflight (`async-request`). preflight additionally requires the exact repository response in `snapshot.repository` with the blank defaults above. its fixtures check supplied records and independent readback comparisons, not GitHub's server implementation, observation freshness or authority. a passing fixture cannot substitute for live settings, rules, ownership or authorization checks; independent landed-message verification remains mandatory even after preflight passes.

## built-in browser final resort

when the CLI/API cannot produce the required message under the existing settings, use GitHub's squash confirmation form in the built-in browser. this uses the existing exact-layer merge authorization; it does not authorize another layer, a settings change, a rule bypass or avoiding a required queue.

1. rederive the same exact head, live readiness, bottom-layer selection, reviews, CI and rules. inspect the form's selected pull requests; require only the authorized bottom layer. stop if the UI selects more layers or cannot preserve required queue behavior.
2. choose **Squash and merge**. retain the intended title with exactly one normal `(#<pr-number>)` suffix. focus **Extended description**, select its contents and delete them through normal supported browser input, then move focus out so the form registers the edit. inspect the visible field and retained value after that interaction. a DOM assignment or accessibility readback of empty text alone does not establish that the form accepted the change.
3. recheck the selected layer and unchanged head before **Confirm squash and merge**. if selection, input state or authority is uncertain, stop this merge and report the exact obstacle. preserve readiness; do not submit speculative retries.
4. independently read the merged PR and landed commit under the readback checks above. require the intended subject, empty body and one parent before dependent work or cleanup. a UI success banner is not message proof. if the body differs, report the outcome without rewriting history; distinguish a possible input-handling failure from a server limitation unless evidence establishes the cause.

this is a form-interaction procedure, not a claim that the offline checker tests browser events or GitHub's UI. if neither the API conditions nor the browser safeguards can be satisfied, hold only the merge and continue other authorized work.

## reconcile server-restacked descendants

GitHub may rewrite descendants after the bottom merge. before any further history change, independently rederive the remaining ordered stack, every local/remote/PR head, base and draft/ready state, and the new trunk. retain both old and observed heads in recovery refs. inspect timeline actors and server evidence where needed; do not treat any post-merge movement as automatically authorized or silently refresh the old leases.

for every remaining layer, compare the old parent-to-layer range with the new range using ordered patch identity (`git range-diff` or an equally strong proof), review the full per-layer diffs and compare complete trees. exact tree equality plus ordered patches establishes an unchanged source tree; neither alone is enough. if trunk also moved, account for its complete tree delta and semantic inputs under complete-restack validation. unexplained commits, altered patches, missing objects, readiness changes or an unproved tree difference stop reconciliation. record explainable server movement explicitly as a new attempt while keeping the old snapshot and recovery refs.

only the assigned integrator reconciles its local checkout through supported official stack operations, then uses `gh stack rebase` and, after staged conflicts, only `gh stack rebase --continue`. if a previous boundary is missing, use [partial stack recovery](partial-stack-recovery.md); do not reset established work or recreate metadata to guess it. rerun affected validation and all mandatory diff, marker, linear-history and state checks, then publish only through `gh stack push`. independently verify every resulting head, base, state and current-head CI. keep remaining layers' live readiness unchanged and select the new bottom only under its own merge authorization.

the [fetch-before-lease limitation](selective-publication.md#pinned-cli-limitation) still applies to that push. patch/tree proof reconciles observed server changes; it cannot prevent a later writer's commit being overwritten between the CLI's fetch and lease construction. keep that risk separate, retain recovery copies and stop on observed unexpected movement. do not fork the CLI, suppress its fetch, bypass hooks or replace its push with ad hoc Git commands.

## official references

- [async merge API and statuses](https://github.com/github/gh-stack/blob/2a49e6751238633db504655d8a8eba3e433e827d/docs/src/content/docs/reference/merge-api.md)
- [v0.3.0 request fields and polling](https://github.com/github/gh-stack/blob/2a49e6751238633db504655d8a8eba3e433e827d/internal/github/merge_async.go)
- [v0.3.0 target resolution and CLI flags](https://github.com/github/gh-stack/blob/2a49e6751238633db504655d8a8eba3e433e827d/cmd/merge.go)
- [default squash messages and commit count](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/configuring-commit-squashing-for-pull-requests)
