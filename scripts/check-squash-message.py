#!/usr/bin/env python3
"""Check captured merge inputs, async results and independent readbacks offline.

This performs no merge or network request. Captures do not establish live tool
capability, repository configuration, authorization, or the identity of a source.
"""

import argparse
import json
from pathlib import Path
import re
from time import monotonic


def expected_message(intent):
    title = intent["title"]
    number = intent["number"]
    body = intent.get("requested_body", "")
    if not isinstance(title, str) or not title.strip() or "\n" in title or "\r" in title:
        raise ValueError("title must be one nonempty line")
    if type(number) is not int or number < 1 or not isinstance(body, str):
        raise ValueError("number must be positive and requested_body must be text")
    # A title may already carry one or more suffixes; the landed subject gets one.
    title = re.sub(r"(?:\s*\(#\d+\))+$", "", title.strip())
    if not title:
        raise ValueError("title must contain more than a pull request suffix")
    return f"{title} (#{number})", body


def check_request(intent, capture, merge_path):
    """Check the replacement fields of a captured ordinary GraphQL request only."""
    if intent.get("stack"):
        raise ValueError("a stack requires the async API, not synchronous mergePullRequest")
    subject, body = expected_message(intent)
    if merge_path != "direct":
        raise ValueError("queue or unverified routing cannot guarantee message replacement")
    query = capture.get("query", "")
    if not isinstance(query, str) or not re.search(r"\bmergePullRequest\s*\(", query):
        raise ValueError("not an ordinary replacement-capable merge request; inspect the approved path")
    if re.search(r"\b(?:enqueuePullRequest|enablePullRequestAutoMerge)\s*\(", query):
        raise ValueError("queued or deferred message behavior is not established by this capture")
    payload = capture.get("variables", {}).get("input", {})
    if payload.get("mergeMethod") != "SQUASH":
        raise ValueError("request is not a squash merge")
    if payload.get("commitHeadline") != subject:
        raise ValueError("subject differs from the intended title and single suffix")
    if "commitBody" not in payload or payload["commitBody"] != body:
        raise ValueError("body must be explicitly present and equal the requested body")


def check_landed(intent, commit, expected_sha):
    subject, body = expected_message(intent)
    if not re.fullmatch(r"[0-9a-f]{40}", expected_sha) or commit.get("sha") != expected_sha:
        raise ValueError("readback is not the expected merge commit")
    actual = commit.get("commit", {}).get("message")
    expected = subject + ("\n\n" + body if body else "")
    # Git may terminate the message with one newline; do not discard body text.
    if not isinstance(actual, str) or actual.removesuffix("\n") != expected.removesuffix("\n"):
        raise ValueError("landed subject or body differs from the intended message")
    parents = commit.get("parents")
    if not isinstance(parents, list) or len(parents) != 1 or not oid(parents[0].get("sha")):
        raise ValueError("squash commit must have exactly one independently read parent")


def oid(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def check_async_request(intent, capture, snapshot):
    """Validate the qualified direct path, not authorization or live evidence."""
    subject, body = expected_message(intent)
    if intent.get("stack") is not True or not oid(intent.get("head")):
        raise ValueError("expected stack and exact approved head")
    if body:
        raise ValueError("nonempty async message behavior requires separate qualification")
    if snapshot.get("merge_queue") is not False or snapshot.get("queue_rule") is not False:
        raise ValueError("direct fallback requires independently verified absence of a queue")
    layers = snapshot.get("open_downstack")
    if not isinstance(layers, list) or len(layers) != 1:
        raise ValueError("target must be the bottom layer with no other open downstack")
    target = layers[0]
    if target.get("number") != intent["number"] or target.get("head") != intent["head"]:
        raise ValueError("target/downstack differs from the exact approved layer")
    if target.get("state") != "OPEN" or target.get("isDraft") is not False:
        raise ValueError("merge target must be live ready and open")
    if (target.get("base_ref") != intent.get("base_ref")
            or target.get("base_sha") != intent.get("base_sha")
            or not oid(intent.get("base_sha")) or not intent.get("base_ref")):
        raise ValueError("base differs from the recorded merge intent")
    repository = intent["repository"]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("invalid repository")
    path = f"repos/{repository}/pulls/{intent['number']}/merge-async"
    if capture.get("method") != "PUT" or capture.get("path") != path:
        raise ValueError("wrong async method, repository or target")
    if capture.get("headers", {}).get("X-GitHub-Api-Version") != "2026-03-10":
        raise ValueError("async API version is not qualified")
    payload = capture.get("body", {})
    expected = {"commit_title": subject, "commit_message": body, "sha": intent["head"],
                "merge_method": "squash", "merge_action": "direct_merge", "bypass_rules": False}
    if payload != expected or payload.get("bypass_rules") is not False:
        raise ValueError("async payload must explicitly match message, head, route and no-bypass intent")


def check_async_response(intent, response, request_id=None):
    """Return pending UUID or merged SHA; neither is independent landed proof."""
    code = response.get("http_status")
    body = response.get("body", {})
    details = body.get("details", {})
    if code == 409:
        raise ValueError("existing async request may have different options; inspect without resubmitting")
    if body.get("status") == "failed":
        raise ValueError(f"async merge failed: {details.get('message', 'unspecified failure')}")
    if code not in (200, 202):
        raise ValueError(f"async HTTP result is unverified: {code}")
    state = body.get("status")
    if state == "pending":
        uuid = details.get("uuid")
        if not isinstance(uuid, str) or not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", uuid):
            raise ValueError("pending response needs its UUID")
        if request_id is not None and uuid != request_id:
            raise ValueError("poll response changed request UUID")
        if (details.get("expected_head_sha") != intent["head"]
                or details.get("merge_method") != "squash"
                or details.get("merge_action") != "direct_merge"
                or details.get("bypass_rules", False) is not False):
            raise ValueError("pending request options differ from intent")
        return state, uuid
    if state == "enqueued":
        raise ValueError("enqueued is not merged; unexpected queue route requires inspection")
    if state == "merged" and oid(details.get("sha")):
        return state, details["sha"]
    raise ValueError("unknown or malformed async result")


def poll_async(intent, initial, fetch, wait, max_polls=150, clock=monotonic):
    """Bound attempts and elapsed time; fetch receives its remaining timeout.

    No network implementation is supplied here. Never resubmit on failure.
    """
    if type(max_polls) is not int or not 0 <= max_polls <= 150:
        raise ValueError("poll limit must be between zero and 150")
    state, value = check_async_response(intent, initial)
    if state == "merged":
        return value
    request_id = value
    deadline = clock() + 300
    for _ in range(max_polls):
        if deadline - clock() <= 2:
            break
        wait(2)
        remaining = deadline - clock()
        if remaining <= 0:
            break
        response = fetch(request_id, remaining)
        if clock() > deadline:
            break
        state, value = check_async_response(intent, response, request_id)
        if state == "merged":
            return value
    raise TimeoutError(f"async request {request_id} remains pending; resume reads, not submission")


def check_async_landed(intent, result, pr, commit):
    state, sha = check_async_response(intent, result)
    if state != "merged":
        raise ValueError("pending is not merged")
    if (pr.get("state") != "MERGED" or not pr.get("mergedAt")
            or pr.get("headRefOid") != intent["head"]
            or pr.get("mergeCommit", {}).get("oid") != sha
            or pr.get("number") != intent["number"]):
        raise ValueError("independent PR readback differs from the approved head or merge result")
    check_landed(intent, commit, sha)


def check_server_restack(before, after, recovery_heads):
    """Check recorded identity evidence; does not run Git or close the lease race."""
    if not before or len(before) != len(after):
        raise ValueError("remaining stack membership changed")
    previous = None
    for old, new in zip(before, after):
        if old["number"] != new["number"] or old["branch"] != new["branch"]:
            raise ValueError("ordered stack membership changed")
        for layer in (old, new):
            if not all(oid(layer[k]) for k in ("head", "base", "tree")):
                raise ValueError("missing commit or tree identity")
            if not {layer["head"], layer["base"]}.issubset(set(recovery_heads)):
                raise ValueError("missing recovery head")
            if layer["head"] != layer["remote_head"] or layer["head"] != layer["pr_head"]:
                raise ValueError("remote and PR heads disagree")
        if new["state"] != old["state"] or new["isDraft"] != old["isDraft"]:
            raise ValueError("server rewrite changed readiness")
        if new["tree"] != old["tree"]:
            raise ValueError("complete tree changed; explicit trunk/input analysis required")
        if not old["patch_ids"] or new["patch_ids"] != old["patch_ids"]:
            raise ValueError("ordered patch identity changed")
        if previous is not None and (old["base"] != previous[0] or new["base"] != previous[1]):
            raise ValueError("parent chain is not contiguous")
        previous = old["head"], new["head"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("request", "landed", "async-request", "async-response", "async-landed", "server-restack"))
    parser.add_argument("intent", type=Path, help="JSON: title, number, optional explicitly requested_body")
    parser.add_argument("observation", type=Path, help="captured request or independently fetched commit JSON")
    parser.add_argument("--sha", help="exact merge SHA, required for landed readback")
    parser.add_argument("--merge-path", choices=("direct", "queue", "unverified"), default="unverified",
                        help="independently verified routing, required for request checks")
    args = parser.parse_args()
    try:
        intent = json.loads(args.intent.read_text())
        observation = json.loads(args.observation.read_text())
        if args.mode == "request":
            check_request(intent, observation, args.merge_path)
        elif args.mode == "landed":
            check_landed(intent, observation, args.sha or "")
        elif args.mode == "async-request":
            check_async_request(intent, observation["capture"], observation["snapshot"])
        elif args.mode == "async-response":
            print(check_async_response(intent, observation))
        elif args.mode == "async-landed":
            check_async_landed(intent, observation["result"], observation["pr"], observation["commit"])
        else:
            check_server_restack(intent["layers"], observation["layers"], observation["recovery_heads"])
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        parser.exit(1, f"squash message check failed: {error}\n")
    print(f"squash message {args.mode} matches")


if __name__ == "__main__":
    main()
