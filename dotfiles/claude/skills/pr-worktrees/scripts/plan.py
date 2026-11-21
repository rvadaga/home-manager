#!/usr/bin/env python3
"""Plan Desktop review setup without writing to Git or Codex."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit


OID = re.compile(r"[a-f0-9]{40}|[a-f0-9]{64}")
CHAT = re.compile(r"[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}")
PR_PATH = re.compile(r"/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/pull/([1-9][0-9]*)/?")


def pr_key(url):
    parsed = urlsplit(url)
    match = PR_PATH.fullmatch(parsed.path)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or not match:
        raise ValueError("expected a canonical HTTPS pull request URL")
    return (parsed.netloc.lower(), match[1].lower(), match[2].lower(), int(match[3]))


def repo_key(url):
    if "://" not in url:
        host, sep, path = url.rpartition(":")
        if not sep:
            return ()
        url = f"ssh://{host}/{path}"
    parsed = urlsplit(url)
    path = parsed.path.strip("/").removesuffix(".git").split("/")
    host = parsed.netloc if parsed.scheme == "https" and parsed.port else parsed.hostname
    if parsed.scheme not in {"ssh", "https"} or not host or len(path) != 2:
        return ()
    return (host.lower(), *[p.lower() for p in path])


def root(path):
    if not isinstance(path, str) or not os.path.isabs(path):
        raise ValueError("checkout paths must be absolute")
    return str(Path(path).resolve())


def git(path, *args, optional=False):
    run = subprocess.run(
        ["git", "--no-optional-locks", "-C", path, *args],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if run.returncode:
        if optional:
            return None
        raise ValueError(f"Git could not read {args[0]} in {path}: {os.fsdecode(run.stderr).strip()}")
    return os.fsdecode(run.stdout)


def worktrees(source):
    records = {}
    fields = {}
    for field in git(source, "worktree", "list", "--porcelain", "-z").split("\0"):
        if field:
            key, _, value = field.partition(" ")
            fields[key] = value
        elif fields:
            records[root(fields["worktree"])] = fields
            fields = {}
    return records


def tracks_pr(path, name, repository):
    remote = (git(path, "config", "--get", f"branch.{name}.remote", optional=True) or "").strip()
    ref = (git(path, "config", "--get", f"branch.{name}.merge", optional=True) or "").strip()
    if not remote or ref != f"refs/heads/{name}":
        return False
    url = git(path, "remote", "get-url", "--", remote, optional=True)
    return bool(url and repo_key(url.strip()) == repository)


def blocking_chats(path, claims, current):
    links = set()
    for claim in claims:
        thread = claim["threadId"]
        if thread != current and CHAT.fullmatch(thread):
            claimed = Path(root(claim["path"]))
            if claimed.is_relative_to(Path(path)):
                links.add(f"codex://threads/{thread}")
    return sorted(links)


def plan(snapshot):
    current = snapshot["threadId"]
    if not CHAT.fullmatch(current):
        raise ValueError("the visible Desktop chat ID is required")
    claims = snapshot["claims"]
    registered = {}
    attached = {}
    archived = set()
    for item in snapshot["artifacts"]:
        payload = item["payload"]
        match item["attachmentType"]:
            case "pull_request":
                key = pr_key(payload["url"])
                path = root(payload["root"]) if payload.get("root") else None
                if key in attached and attached[key] != path:
                    raise ValueError(f"conflicting Desktop attachments for {payload['url']}")
                attached[key] = path
            case "worktree" | "linked_worktree":
                registered[root(payload["root"])] = item["identityKey"]
            case "archived_worktree":
                if payload.get("root"):
                    archived.add(root(payload["root"]))

    # Extra bindings must come from receipts already verified by the owning chat.
    bindings = {}
    for receipt in snapshot["verifiedBindings"]:
        if receipt["threadId"] != current:
            raise ValueError("a checkout receipt belongs to a different chat")
        bindings.setdefault(pr_key(receipt["url"]), set()).add(root(receipt["path"]))
    for key, path in attached.items():
        if path:
            bindings.setdefault(key, set()).add(path)
    reserved = {}
    for key, paths in bindings.items():
        for path in paths:
            if path in reserved and reserved[path] != key:
                raise ValueError(f"two PRs claim {path}; preserve it and resolve the claim")
            reserved[path] = key

    results = []
    seen = set()
    selected = set()
    inventories = {}
    for pull in snapshot["pulls"]:
        key = pr_key(pull["url"])
        if key in seen or pull["state"] != "OPEN":
            continue
        seen.add(key)
        source = root(pull["sourceRoot"])
        head, base = pull["headRefOid"], pull["baseRefOid"]
        if (not OID.fullmatch(head) or not OID.fullmatch(base)
                or type(pull["isDraft"]) is not bool or type(pull["stackParent"]) is not bool):
            raise ValueError(f"missing exact head, base, readiness or stack relationship for {pull['url']}")
        url = git(source, "remote", "get-url", "--", pull["remote"]).strip()
        if repo_key(url) != key[:3]:
            raise ValueError(f"the remote in {source} does not match {pull['url']}")
        head_repo = pull["headRepository"].lower().split("/")
        if len(head_repo) != 2 or not all(head_repo):
            raise ValueError(f"missing PR head repository for {pull['url']}")
        ref = f"refs/heads/{pull['headRefName']}"
        git(source, "check-ref-format", ref)
        git(source, "check-ref-format", f"refs/heads/{pull['baseRefName']}")
        if source not in inventories:
            inventories[source] = worktrees(source)
        candidates = inventories[source]
        known = set(bindings.get(key, ()))
        possible = set()
        for path, entry in candidates.items():
            if path in reserved and reserved[path] != key:
                continue
            same_branch = entry.get("branch") == ref
            if same_branch and Path(path).is_dir() and tracks_pr(
                path, pull["headRefName"], (key[0], *head_repo)
            ):
                known.add(path)
            elif same_branch or entry.get("HEAD") == head:
                possible.add(path)
        matches = sorted(known | possible)
        row = {
            "url": pull["url"], "head": head, "base": base, "draft": pull["isDraft"],
            "baseBranch": pull["baseRefName"],
            "attachPr": key not in attached, "nativePairVerified": False,
            "candidates": [
                {"path": path, "blockingChats": blocking_chats(path, claims, current)}
                for path in matches
            ],
        }
        results.append(row)
        if not matches:
            row.update(action="create", ref=head, sourceRoot=source)
            continue
        usable = {path for path in known if path in candidates and path not in archived
                  and Path(path).is_dir()}
        if known and not usable:
            row.update(action="hold", reason="recorded checkout is archived, missing, or outside this Git inventory")
            continue
        if len(usable) != 1:
            row.update(action="hold", reason="existing checkout identity is ambiguous or unproved")
            continue
        path = next(iter(usable))
        row.update(path=path, duplicates=[candidate for candidate in matches if candidate != path])
        actual = git(path, "rev-parse", "--verify", "HEAD").strip()
        if actual != candidates[path].get("HEAD"):
            row.update(action="hold", reason="checkout moved during inventory")
            continue
        if path in selected:
            raise ValueError(f"two PRs resolve to {path}; preserve it and resolve the claim")
        selected.add(path)
        row.update(
            action="reuse", localHead=actual, attachment=registered.get(path),
            nativePairVerified=path in registered and attached.get(key) == path,
        )
        if path not in registered and blocking_chats(path, claims, current):
            row.update(reason="checkout is claimed by another chat; leave the checkout there")
        elif git(path, "status", "--porcelain=v1", "-z", "--untracked-files=all"):
            row.update(reason="checkout has local changes; use the published PR diff")
        elif actual != head:
            row.update(reason="checkout differs from the published head; refresh safely or use the published PR diff")
        elif git(path, "cat-file", "-t", base, optional=True) != "commit\n":
            row.update(reason="exact base commit is not present")
        elif pull["stackParent"] and (git(path, "merge-base", base, head, optional=True) or "").strip() != base:
            row.update(reason="the immediate stack parent is not an ancestor; check the published layer")
        else:
            row["review"] = {"type": "review", "view": "branch", "path": path, "baseBranch": base}
    return results


if __name__ == "__main__":
    try:
        with open(sys.argv[1], encoding="utf-8") as source:
            json.dump(plan(json.load(source)), sys.stdout, indent=2)
            print()
    except (IndexError, KeyError, TypeError, ValueError, OSError) as exc:
        sys.exit(f"pr-worktrees: {exc}")
