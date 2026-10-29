#!/usr/bin/env python3
"""Offline message-contract controls; these do not simulate GitHub merge results."""

import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location("check", Path(__file__).with_name("check-squash-message.py"))
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class SquashMessageTest(unittest.TestCase):
    def setUp(self):
        self.intent = {"title": "fix parser", "number": 7}
        self.capture = {
            "query": "mutation PullRequestMerge($input: MergePullRequestInput!) { mergePullRequest(input: $input) { clientMutationId } }",
            "variables": {"input": {"mergeMethod": "SQUASH", "commitHeadline": "fix parser (#7)", "commitBody": ""}},
        }
        self.sha = "a" * 40

    def test_explicit_empty_is_not_omitted(self):
        check.check_request(self.intent, self.capture, "direct")
        del self.capture["variables"]["input"]["commitBody"]
        with self.assertRaisesRegex(ValueError, "explicitly present"):
            check.check_request(self.intent, self.capture, "direct")

    def test_requested_meaningful_body_is_preserved(self):
        self.intent["requested_body"] = "Preserve empty records for compatibility."
        self.capture["variables"]["input"]["commitBody"] = self.intent["requested_body"]
        check.check_request(self.intent, self.capture, "direct")
        check.check_landed(self.intent, {"sha": self.sha, "commit": {"message": "fix parser (#7)\n\n" + self.intent["requested_body"]}}, self.sha)
        self.capture["variables"]["input"]["commitBody"] = ""
        with self.assertRaises(ValueError):
            check.check_request(self.intent, self.capture, "direct")

    def test_auto_commit_list_and_description_are_rejected(self):
        for body in ("* first commit\n* fix tests", "## Description\n\nfix parser behavior"):
            with self.subTest(body=body):
                self.capture["variables"]["input"]["commitBody"] = body
                with self.assertRaises(ValueError):
                    check.check_request(self.intent, self.capture, "direct")

    def test_subject_has_exactly_one_normal_suffix(self):
        for title in ("fix parser", "fix parser (#7)", "fix parser (#7) (#7)"):
            self.intent["title"] = title
            self.assertEqual(check.expected_message(self.intent), ("fix parser (#7)", ""))
        for subject in ("fix parser", "fix parser (#8)", "fix parser (#7) (#7)"):
            self.capture["variables"]["input"]["commitHeadline"] = subject
            with self.assertRaises(ValueError):
                check.check_request(self.intent, self.capture, "direct")

    def test_unsupported_append_only_and_queue_requests_stop(self):
        for request in (
            {"merge_method": "squash"},
            {"merge_method": "squash", "commit_title": "fix parser (#7)", "commit_message": ""},
            {"query": "mutation { enqueuePullRequest(input: $input) { clientMutationId } }"},
            {"query": "mutation { enablePullRequestAutoMerge(input: $input) { clientMutationId } }"},
        ):
            with self.subTest(request=request), self.assertRaises(ValueError):
                check.check_request(self.intent, request, "direct")

    def test_queue_can_ignore_an_otherwise_valid_explicit_message(self):
        for path in ("queue", "unverified"):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "routing"):
                check.check_request(self.intent, self.capture, path)

    def test_landed_readback_is_required_even_after_valid_request(self):
        check.check_request(self.intent, self.capture, "direct")
        for commit in (
            {"state": "MERGED", "mergedAt": "2026-01-01T00:00:00Z"},
            {"sha": "b" * 40, "commit": {"message": "fix parser (#7)"}},
            {"sha": self.sha, "commit": {"message": "fix parser (#7)\n\n* first commit"}},
            {"sha": self.sha, "commit": {"message": "fix parser (#7) (#7)"}},
        ):
            with self.subTest(commit=commit), self.assertRaises(ValueError):
                check.check_landed(self.intent, commit, self.sha)
        for message in ("fix parser (#7)", "fix parser (#7)\n"):
            check.check_landed(self.intent, {"sha": self.sha, "commit": {"message": message}}, self.sha)


if __name__ == "__main__":
    unittest.main()
