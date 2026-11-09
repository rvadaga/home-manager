#!/usr/bin/env python3
"""Offline message-contract controls; these do not simulate GitHub merge results."""

import importlib.util
from copy import deepcopy
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
        check.check_landed(self.intent, {"sha": self.sha, "commit": {"message": "fix parser (#7)\n\n" + self.intent["requested_body"]}, "parents": [{"sha": "b" * 40}]}, self.sha)
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

    def test_unqualified_payload_is_not_an_ordinary_merge_request(self):
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
            check.check_landed(self.intent, {"sha": self.sha, "commit": {"message": message}, "parents": [{"sha": "b" * 40}]}, self.sha)


class AsyncMergeTest(unittest.TestCase):
    def setUp(self):
        self.intent = {"title": "fix parser", "number": 7, "repository": "example/project",
                       "head": "a" * 40, "base_ref": "main", "base_sha": "b" * 40, "stack": True}
        self.snapshot = {"merge_queue": False, "queue_rule": False, "open_downstack": [
            {"number": 7, "head": "a" * 40, "base_ref": "main", "base_sha": "b" * 40,
             "state": "OPEN", "isDraft": False}]}
        self.capture = {"method": "PUT", "path": "repos/example/project/pulls/7/merge-async",
                        "headers": {"X-GitHub-Api-Version": "2026-03-10"},
                        "body": {"commit_title": "fix parser (#7)", "commit_message": "",
                                 "sha": "a" * 40, "merge_method": "squash",
                                 "merge_action": "direct_merge", "bypass_rules": False}}
        self.uuid = "11111111-2222-3333-4444-555555555555"
        self.pending = {"http_status": 202, "body": {"status": "pending", "details": {
            "uuid": self.uuid, "expected_head_sha": "a" * 40, "merge_method": "squash",
            "merge_action": "direct_merge", "bypass_rules": False}}}
        self.merged = {"http_status": 200, "body": {"status": "merged", "details": {"sha": "c" * 40}}}
        self.pr = {"number": 7, "state": "MERGED", "mergedAt": "2026-01-01T00:00:00Z",
                   "headRefOid": "a" * 40, "mergeCommit": {"oid": "c" * 40}}
        self.commit = {"sha": "c" * 40, "commit": {"message": "fix parser (#7)"},
                       "parents": [{"sha": "b" * 40}]}

    def test_supported_explicit_empty_direct_request(self):
        check.check_async_request(self.intent, self.capture, self.snapshot)
        for key in self.capture["body"]:
            missing = deepcopy(self.capture)
            del missing["body"][key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                check.check_async_request(self.intent, missing, self.snapshot)

    def test_message_head_route_and_no_bypass(self):
        for key, value in (("commit_title", "fix parser (#7) (#7)"), ("commit_message", None),
                           ("commit_message", "* old commit"), ("sha", "d" * 40),
                           ("merge_method", "merge"), ("merge_action", "default"),
                           ("merge_action", "merge_queue"), ("bypass_rules", True),
                           ("bypass_rules", "false"), ("bypass_rules", 0)):
            altered = deepcopy(self.capture)
            altered["body"][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                check.check_async_request(self.intent, altered, self.snapshot)

    def test_version_and_queue_paths_need_their_own_evidence(self):
        for key in ("merge_queue", "queue_rule"):
            for value in (True, None, "false"):
                changed = deepcopy(self.snapshot)
                changed[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    check.check_async_request(self.intent, self.capture, changed)
        self.capture["headers"]["X-GitHub-Api-Version"] = "2099-01-01"
        with self.assertRaisesRegex(ValueError, "version"):
            check.check_async_request(self.intent, self.capture, self.snapshot)

    def test_target_cannot_include_unapproved_ancestors(self):
        for layers in ([], self.snapshot["open_downstack"] * 2,
                       [dict(self.snapshot["open_downstack"][0], number=8)],
                       [dict(self.snapshot["open_downstack"][0], isDraft=True)],
                       [dict(self.snapshot["open_downstack"][0], head="d" * 40)],
                       [dict(self.snapshot["open_downstack"][0], base_sha="d" * 40)]):
            with self.subTest(layers=layers), self.assertRaises(ValueError):
                check.check_async_request(self.intent, self.capture, dict(self.snapshot, open_downstack=layers))
        for path in ("repos/elsewhere/project/pulls/7/merge-async", "repos/example/project/pulls/8/merge-async"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                check.check_async_request(self.intent, dict(self.capture, path=path), self.snapshot)

    def test_synchronous_stack_route_rejected_even_with_empty_body(self):
        request = {"query": "mutation { mergePullRequest(input:$input) { clientMutationId } }",
                   "variables": {"input": {"mergeMethod": "SQUASH", "commitHeadline": "fix parser (#7)", "commitBody": ""}}}
        with self.assertRaisesRegex(ValueError, "async API"):
            check.check_request(self.intent, request, "direct")

    def test_pending_then_merged_and_immediate_completion(self):
        calls, waits = [], []
        responses = iter([dict(self.pending, http_status=200), self.merged])
        def fetch(request_id, timeout):
            self.assertGreater(timeout, 0)
            self.assertLessEqual(timeout, 300)
            calls.append(request_id)
            return next(responses)
        self.assertEqual(check.poll_async(self.intent, self.pending, fetch, waits.append), "c" * 40)
        self.assertEqual(calls, [self.uuid, self.uuid])
        self.assertEqual(waits, [2, 2])
        self.assertEqual(check.poll_async(self.intent, self.merged, self.fail, self.fail), "c" * 40)

    def test_polling_is_bounded_and_never_resubmits(self):
        reads = []
        def fetch(request_id, timeout):
            reads.append(request_id)
            return dict(self.pending, http_status=200)
        with self.assertRaisesRegex(TimeoutError, "resume reads"):
            check.poll_async(self.intent, self.pending, fetch, lambda _: None, max_polls=3)
        self.assertEqual(reads, [self.uuid] * 3)
        with self.assertRaises(ValueError):
            check.poll_async(self.intent, self.pending, fetch, lambda _: None, max_polls=151)
        with self.assertRaises(OSError):
            check.poll_async(self.intent, self.pending, lambda *_: (_ for _ in ()).throw(OSError("network")), lambda _: None)

    def test_elapsed_time_bounds_slow_reads(self):
        elapsed, reads = [0], []
        def wait(seconds):
            elapsed[0] += seconds
        def fetch(request_id, timeout):
            reads.append((request_id, timeout))
            elapsed[0] += 298
            return self.pending
        with self.assertRaisesRegex(TimeoutError, "resume reads"):
            check.poll_async(self.intent, self.pending, fetch, wait, clock=lambda: elapsed[0])
        self.assertEqual(reads, [(self.uuid, 298)])

    def test_failure_queue_conflict_unknown_and_malformed_are_not_success(self):
        for response in (
            {"http_status": 200, "body": {"status": "failed", "details": {"message": "checks failed"}}},
            {"http_status": 200, "body": {"status": "enqueued"}},
            dict(self.pending, http_status=409), dict(self.pending, http_status=404),
            {"http_status": 200, "body": {"status": "unexpected"}},
            {"http_status": 200, "body": {"status": "pending", "details": {}}},
            {"http_status": 200, "body": {"status": "merged", "details": {}}},
        ):
            with self.subTest(response=response), self.assertRaises(ValueError):
                check.poll_async(self.intent, response, self.fail, self.fail)
        for key, value in (("uuid", "wrong"), ("expected_head_sha", "d" * 40),
                           ("merge_method", "merge"), ("merge_action", "merge_queue"), ("bypass_rules", True)):
            changed = deepcopy(self.pending)
            changed["body"]["details"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                check.check_async_response(self.intent, changed, self.uuid)

    def test_independent_pr_commit_and_single_parent_readbacks(self):
        check.check_async_landed(self.intent, self.merged, self.pr, self.commit)
        for field, value in (("state", "OPEN"), ("headRefOid", "d" * 40), ("mergedAt", None), ("number", 8)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                check.check_async_landed(self.intent, self.merged, dict(self.pr, **{field: value}), self.commit)
        for parents in ([], [{"sha": "b" * 40}, {"sha": "d" * 40}], [{}]):
            with self.subTest(parents=parents), self.assertRaises(ValueError):
                check.check_async_landed(self.intent, self.merged, self.pr, dict(self.commit, parents=parents))
        for message in ("fix parser (#7)\n\n* prior commit", "fix parser (#7) (#7)"):
            with self.subTest(message=message), self.assertRaises(ValueError):
                check.check_async_landed(self.intent, self.merged, self.pr, dict(self.commit, commit={"message": message}))

    def test_server_restack_needs_ordered_patches_trees_and_state(self):
        def layer(number, head, base, tree, patches, draft):
            return dict(number=number, branch=f"feature-{number}", head=head, base=base, tree=tree,
                        patch_ids=patches, state="OPEN", isDraft=draft, remote_head=head, pr_head=head)
        old = [layer(8, "a" * 40, "b" * 40, "1" * 40, ["patch-a", "patch-b"], False),
               layer(9, "c" * 40, "a" * 40, "2" * 40, ["patch-c"], True)]
        new = [layer(8, "d" * 40, "e" * 40, "1" * 40, ["patch-a", "patch-b"], False),
               layer(9, "f" * 40, "d" * 40, "2" * 40, ["patch-c"], True)]
        recovery = [x * 40 for x in "abcdef"]
        check.check_server_restack(old, new, recovery)
        for field, value in (("tree", "3" * 40), ("patch_ids", ["patch-b", "patch-a"]),
                             ("isDraft", True), ("remote_head", "a" * 40), ("number", 10)):
            changed = deepcopy(new)
            changed[0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                check.check_server_restack(old, changed, recovery)
        with self.assertRaisesRegex(ValueError, "recovery"):
            check.check_server_restack(old, new, [])
        with self.assertRaisesRegex(ValueError, "membership"):
            check.check_server_restack(old, new[:1], recovery)


if __name__ == "__main__":
    unittest.main()
