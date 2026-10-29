#!/usr/bin/env python3
"""Check captured ordinary merge inputs or independently fetched commit JSON.

This performs no merge or network request. Captures do not establish live tool
capability, repository configuration, authorization, or the identity of a source.
"""

import argparse
import json
from pathlib import Path
import re


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("request", "landed"))
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
        else:
            check_landed(intent, observation, args.sha or "")
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        parser.exit(1, f"squash message check failed: {error}\n")
    print(f"squash message {args.mode} matches")


if __name__ == "__main__":
    main()
