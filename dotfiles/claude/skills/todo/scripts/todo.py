#!/usr/bin/env python3
"""Capture and review durable checklist items; never execute their contents."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import quote, urlparse


SKILL = Path(__file__).absolute().parents[1]
ITEM = re.compile(r"^- \[([ x-])\] \*\*(T(\d{3,})) — (.*?)\*\*(.*?) \^(todo-\d{3,})$")
META = re.compile(r"^  <!-- todo: (.*) -->$")
STATES = {"open", "deferred", "done", "dropped"}
INTENTS = {"discuss", "implement", "investigate", "consider"}
BUCKETS = {"outstanding", "someday"}


def nonempty(value, label):
    if not isinstance(value, str) or not value.strip() or any(ord(c) < 32 for c in value):
        raise ValueError(f"{label} must be nonempty single-line text")
    return value


def json_load(text):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key: {key}")
            result[key] = value
        return result
    return json.loads(text, object_pairs_hook=unique)


def contained(vault, relative):
    path = Path(relative)
    if path.is_absolute() or not path.parts or any(p in {".", "..", ".git"} for p in path.parts):
        raise ValueError("path must stay inside the vault and outside .git")
    target = vault / path
    if any(p.is_symlink() for p in (target, *target.parents) if p != vault.parent):
        raise ValueError("vault paths must not traverse symlinks")
    if not target.resolve().is_relative_to(vault.resolve()):
        raise ValueError("path escapes the vault")
    return target


def storage():
    cfg = json_load((SKILL / "references/storage.json").read_text())
    if cfg["scope"] not in {"personal", "work"} or cfg["log_order"] not in {"append", "prepend"}:
        raise ValueError("invalid storage scope or log order")
    vault = Path(cfg["vault"]).expanduser()
    if not vault.is_absolute() or vault.is_symlink():
        raise ValueError("vault must be an absolute, ordinary directory")
    for key in ("checklist", "schema"):
        contained(vault, cfg[key])
    for relative in ("index.md", "log.md"):
        contained(vault, relative)
    cfg["root"] = vault
    return cfg


def source_handle(source):
    if not isinstance(source, dict) or not set(source) <= {"chat", "handle", "title", "message", "annotation"}:
        raise ValueError("source must contain a chat or retrieval handle and optional message context")
    for key, value in source.items():
        if key == "annotation":
            if not isinstance(value, dict) or set(value) != {"message", "start", "end"}:
                raise ValueError("annotation needs its source message and exact start/end offsets")
            nonempty(value["message"], "annotation message")
            if any(type(value[k]) is not int for k in ("start", "end")) or not 0 <= value["start"] < value["end"]:
                raise ValueError("invalid annotation offsets")
        else:
            nonempty(value, f"source {key}")
    return nonempty(source.get("chat") or source.get("handle"), "source chat or retrieval handle")


def validate_metadata(meta):
    if not isinstance(meta, dict) or meta.get("schema") != 1:
        raise ValueError("unsupported todo metadata schema")
    source_handle(meta.get("source"))
    if meta.get("intent") not in INTENTS or meta.get("bucket") not in BUCKETS or meta.get("status") not in STATES:
        raise ValueError("invalid intent, bucket or disposition")
    for key in ("timing", "current_chat"):
        nonempty(meta.get(key), key)
    if not isinstance(meta.get("events"), list) or not meta["events"]:
        raise ValueError("item must preserve its capture and disposition history")
    for event in meta["events"]:
        for key in ("key", "fingerprint", "operation", "at"):
            nonempty(event.get(key), f"event {key}")


def read_items(text):
    lines = text.splitlines()
    items, ids, anchors, keys = [], set(), set(), set()
    section = ""
    for pos, line in enumerate(lines):
        if line.startswith("## "):
            section = line[3:].strip().lower()
        match = ITEM.fullmatch(line)
        if not match:
            if META.fullmatch(line) and (not pos or not ITEM.fullmatch(lines[pos - 1])):
                raise ValueError("orphan todo metadata")
            if re.match(r"^- \[.\].*\bT\d{3,}\b", line):
                raise ValueError(f"malformed todo entry at line {pos + 1}")
            continue
        mark, ident, number, action, context, anchor = match.groups()
        if ident in ids or anchor in anchors or anchor != f"todo-{number}":
            raise ValueError("duplicate or mismatched item identity/anchor")
        ids.add(ident)
        anchors.add(anchor)
        meta_match = META.fullmatch(lines[pos + 1]) if pos + 1 < len(lines) else None
        meta = json_load(meta_match[1]) if meta_match else None
        if meta is not None:
            validate_metadata(meta)
            expected = "x" if meta["status"] == "done" else "-" if meta["status"] == "dropped" else " "
            if expected != mark:
                raise ValueError("checkbox disagrees with disposition")
            for event in meta["events"]:
                if event["key"] in keys:
                    raise ValueError("duplicate operation key")
                keys.add(event["key"])
        items.append({"id": ident, "number": int(number), "action": action, "context": context.strip(),
                      "anchor": anchor, "line": pos + 1, "meta": meta, "legacy_bucket": "someday" if section == "someday" else "outstanding"})
    return items


def escaped(text):
    text = nonempty(text, "text")
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return re.sub(r"([\\`*\[\]_])", r"\\\1", text)


def encoded_metadata(meta):
    return "  <!-- todo: " + json.dumps(meta, ensure_ascii=True, sort_keys=True).replace("<", "\\u003c").replace(">", "\\u003e") + " -->"


def request_data(path):
    request = json_load(path.read_text())
    if not isinstance(request, dict):
        raise ValueError("request must be an object")
    common = {"operation", "key", "scope"}
    capture = {"action", "source", "intent", "bucket", "timing", "project", "artifact"}
    fields = {
        "capture": capture, "annotate": (capture - {"action"}) | {"id"},
        "complete": {"id", "reason"}, "drop": {"id", "reason"},
        "defer": {"id", "reason", "timing", "bucket"}, "transfer": {"id", "successor", "reason"},
    }
    operation = request.get("operation")
    if operation not in fields or not set(request) <= common | fields[operation]:
        raise ValueError("unsupported operation or fields")
    nonempty(request.get("key"), "stable operation key")
    if request.get("scope") not in {"personal", "work"}:
        raise ValueError("request needs its personal or work scope")
    if operation in {"capture", "annotate"}:
        source_handle(request.get("source"))
        if request.get("intent") not in INTENTS:
            raise ValueError("capture needs an explicit intent")
        if request.get("bucket", "outstanding") not in BUCKETS:
            raise ValueError("invalid bucket")
        if operation == "capture":
            nonempty(request.get("action"), "action")
        for key in ("timing", "project"):
            if key in request:
                nonempty(request[key], key)
        if "artifact" in request:
            url = urlparse(nonempty(request["artifact"], "artifact"))
            if url.scheme != "https" or not url.netloc:
                raise ValueError("artifact must be an HTTPS URL")
    else:
        nonempty(request.get("reason"), "disposition reason")
    if operation != "capture" and not re.fullmatch(r"T\d{3,}", request.get("id", "")):
        raise ValueError("operation needs an existing stable item ID")
    if operation == "transfer":
        nonempty(request.get("successor"), "successor retrieval handle")
    if operation == "defer":
        if "timing" not in request and "bucket" not in request:
            raise ValueError("deferral needs the user's timing or bucket")
        if "timing" in request:
            nonempty(request["timing"], "timing")
        if request.get("bucket", "outstanding") not in BUCKETS:
            raise ValueError("invalid bucket")
    return request


def fingerprint(request):
    return hashlib.sha256(json.dumps(request, sort_keys=True, ensure_ascii=True).encode()).hexdigest()


def update(text, request, now):
    items = read_items(text)
    digest = fingerprint(request)
    for item in items:
        for event in (item["meta"] or {}).get("events", []):
            if event["key"] == request["key"]:
                if event["fingerprint"] != digest:
                    raise ValueError("operation key already belongs to a different request")
                return text, item["id"]
    operation = request["operation"]
    item = next((x for x in items if x["id"] == request.get("id")), None)
    if operation != "capture" and item is None:
        raise ValueError("unknown item ID")
    if operation in {"capture", "annotate"}:
        if operation == "annotate" and item["meta"] is not None:
            raise ValueError("item already has metadata; preserve its original source")
        meta = {"schema": 1, "source": request["source"], "intent": request["intent"],
                "bucket": request.get("bucket", "outstanding"), "timing": request.get("timing", "unspecified"),
                "status": "open", "current_chat": source_handle(request["source"]), "events": []}
        meta.update({key: request[key] for key in ("project", "artifact") if key in request})
    else:
        if item["meta"] is None:
            raise ValueError("annotate this legacy item with its verified source before changing it")
        meta = item["meta"]
        if meta["status"] in {"done", "dropped"}:
            raise ValueError("terminal items cannot be deferred or reassigned")
        if operation == "transfer":
            meta["current_chat"] = request["successor"]
        else:
            meta["status"] = {"complete": "done", "drop": "dropped", "defer": "deferred"}[operation]
            for key in ("timing", "bucket"):
                if key in request:
                    meta[key] = request[key]
    meta["events"].append({"key": request["key"], "fingerprint": digest, "operation": operation,
                           "at": now, "status": meta["status"], "bucket": meta["bucket"],
                           "timing": meta["timing"], "current_chat": meta["current_chat"],
                           **({"reason": request["reason"]} if "reason" in request else {})})
    if operation == "capture":
        number = max((x["number"] for x in items), default=0) + 1
        ident = f"T{number:03d}"
        block = f"- [ ] **{ident} — {escaped(request['action'])}** ^todo-{number:03d}\n{encoded_metadata(meta)}\n"
        result = text.rstrip() + "\n\n" + block
    else:
        ident = item["id"]
        lines = text.splitlines()
        pos = item["line"] - 1
        if operation == "annotate":
            if not lines[pos].startswith("- [ ]"):
                raise ValueError("legacy terminal item requires an explicit disposition migration")
            lines.insert(pos + 1, encoded_metadata(meta))
        else:
            mark = "x" if meta["status"] == "done" else "-" if meta["status"] == "dropped" else " "
            lines[pos] = f"- [{mark}]" + lines[pos][5:]
            lines[pos + 1] = encoded_metadata(meta)
        result = "\n".join(lines) + "\n"
    read_items(result)
    return result, ident


def initial_page(cfg):
    return (f"---\ntags: {json.dumps(cfg['tags'])}\ncreated: {dt.date.today().isoformat()}\n---\n\n"
            f"# {cfg['title']}\n\nCaptured follow-ups. Recording an item does not start its work.\n")


def index_target(cfg):
    return Path(cfg["checklist"]).with_suffix("").as_posix()


def indexed(cfg):
    text = contained(cfg["root"], "index.md").read_text()
    target = index_target(cfg)
    return any(link.split("|", 1)[0].split("#", 1)[0] in {target, Path(target).name}
               for link in re.findall(r"\[\[([^\]]+)\]\]", text))


def log_parts(text):
    match = re.match(r"\A(?:(---\n.*?\n---\n\s*))?# log\n", text, re.S)
    if not match:
        raise ValueError("log needs its existing frontmatter, if any, followed by # log")
    return text[:match.end()], text[match.end():]


def validate_vault(cfg):
    vault = cfg["root"]
    if not contained(vault, cfg["schema"]).is_file():
        raise ValueError("read the vault schema before creating its checklist")
    path = contained(vault, cfg["checklist"])
    text = path.read_text()
    frontmatter = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not frontmatter or not re.search(r"^tags:\s*(?:\[.+\]|\n\s*- .+)", frontmatter[1], re.M):
        raise ValueError("checklist needs schema tags in frontmatter")
    created = re.search(r"^created: (\d{4}-\d{2}-\d{2})$", frontmatter[1], re.M)
    if not created:
        raise ValueError("checklist needs a created date")
    dt.date.fromisoformat(created[1])
    read_items(text)
    if not indexed(cfg):
        raise ValueError("checklist is missing from the vault index")
    log_parts(contained(vault, "log.md").read_text())


def writer(cfg, request):
    vault = cfg["root"]
    lock = Path(os.environ["WORK_VAULT_LOCK_DIR"])
    metadata = json_load((lock / "owner.json").read_text())
    if request["scope"] != cfg["scope"]:
        raise ValueError("request scope differs from the configured vault")
    if metadata["token"] != os.environ["WORK_VAULT_TOKEN"] or Path(os.environ["WORK_VAULT_PATH"]) != vault.resolve():
        raise ValueError("writer requires the owning notes transaction")
    path = contained(vault, cfg["checklist"])
    text = path.read_text() if path.exists() else initial_page(cfg)
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    result, ident = update(text, request, now)
    if result == text:
        return
    paths = {cfg["checklist"], "log.md"}
    if not indexed(cfg):
        paths.add("index.md")
    if paths != set(json.loads(os.environ["WORK_VAULT_DECLARED_PATHS_JSON"])):
        raise ValueError("index changed before lock acquisition; retry from the current vault")
    log = contained(vault, "log.md")
    log_text = log.read_text()
    log_header, log_body = log_parts(log_text)
    entry = f"## [{now[:10]}] update | [[{index_target(cfg)}]]\n\n{request['operation']} {ident}.\n\n"
    log_result = (log_header + "\n" + entry + log_body.lstrip()) if cfg["log_order"] == "prepend" else log_text.rstrip() + "\n\n" + entry
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(result)
    log.write_text(log_result.rstrip() + "\n")
    if "index.md" in paths:
        index = contained(vault, "index.md")
        index.write_text(index.read_text().rstrip() + f"\n\n- [[{index_target(cfg)}]] — captured follow-ups and their dispositions\n")


def apply(cfg, request_path, owner):
    request = request_data(request_path)
    if request["scope"] != cfg["scope"]:
        raise ValueError("request scope differs from the configured vault")
    nonempty(owner, "transaction owner")
    engine = SKILL / "scripts/vault-transaction.py"
    if not engine.is_file():
        engine = SKILL.parent / "notes/scripts/vault-transaction.py"
    deadline = time.monotonic() + 10
    while True:
        paths = [cfg["checklist"], "log.md"] + ([] if indexed(cfg) else ["index.md"])
        command = [sys.executable, str(engine), "--vault", str(cfg["root"]), "--owner", owner,
                   "--commit-message", "update captured follow-ups", "--allow-noop",
                   "--write-command-json", json.dumps([sys.executable, str(Path(__file__).absolute()), "write", "--request", str(request_path)]),
                   "--validator-command-json", json.dumps([sys.executable, str(Path(__file__).absolute()), "validate"])]
        for path in paths:
            command += ["--path", path]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode == 0:
            break
        # Only another transaction's live lock permits a bounded contention retry.
        retryable = "writer lock already exists" in result.stderr or "dirty preflight" in result.stderr
        if "index changed before lock acquisition" in result.stderr and time.monotonic() < deadline:
            continue
        git_dir = subprocess.run(["git", "-C", str(cfg["root"]), "rev-parse", "--git-common-dir"], capture_output=True, text=True, check=True).stdout.strip()
        lock = (cfg["root"] / git_dir).resolve() / "status-page-writer.lock"
        try:
            lock_owner = json_load((lock / "owner.json").read_text()).get("owner")
        except FileNotFoundError:
            lock_owner = None
        if retryable and lock_owner is None and time.monotonic() < deadline:
            clean = subprocess.run(["git", "-C", str(cfg["root"]), "status", "--porcelain"], capture_output=True, text=True, check=True).stdout == ""
            if clean:
                continue
        if not retryable or lock_owner in {None, owner} or time.monotonic() >= deadline:
            raise ValueError(result.stderr.strip() or result.stdout.strip())
        time.sleep(0.1)
    request = request_data(request_path)
    items = read_items(contained(cfg["root"], cfg["checklist"]).read_text())
    matched = next(i for i in items if any(e["key"] == request["key"] for e in (i["meta"] or {}).get("events", [])))
    print(json.dumps(public_item(cfg, matched), ensure_ascii=False))


def public_item(cfg, item):
    path = contained(cfg["root"], cfg["checklist"])
    meta = item["meta"]
    return {"id": item["id"], "action": item["action"], "context": item["context"],
            "status": meta["status"] if meta else "legacy: verify disposition", "intent": meta["intent"] if meta else None,
            "timing": meta["timing"] if meta else None, "bucket": meta["bucket"] if meta else item["legacy_bucket"],
            "source": meta["source"] if meta else None, "current_chat": meta["current_chat"] if meta else None,
            "artifact": meta.get("artifact") if meta else None, "project": meta.get("project") if meta else None,
            "file_link": f"{path}:{item['line']}", "block": f"[[{index_target(cfg)}#^{item['anchor']}]]",
            "obsidian_link": "obsidian://open?vault=" + quote(cfg["root"].name, safe="") + "&file=" + quote(cfg["checklist"] + "#^" + item["anchor"], safe="")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["show", "apply", "write", "validate"])
    parser.add_argument("--request", type=Path)
    parser.add_argument("--owner")
    parser.add_argument("--view", choices=["session", "outstanding", "someday", "all"], default="outstanding")
    parser.add_argument("--chat")
    args = parser.parse_args()
    try:
        cfg = storage()
        if args.command in {"apply", "write"}:
            if args.request is None:
                raise ValueError("a request JSON file is required")
            request_path = args.request.resolve()
            if request_path.is_relative_to(cfg["root"].resolve()):
                raise ValueError("keep temporary requests outside the vault")
            if args.command == "apply":
                apply(cfg, request_path, args.owner)
            else:
                writer(cfg, request_data(request_path))
        elif args.command == "validate":
            validate_vault(cfg)
        else:
            if args.view == "session" and not args.chat:
                raise ValueError("session view needs an exact chat or retrieval handle")
            path = contained(cfg["root"], cfg["checklist"])
            items = read_items(path.read_text()) if path.exists() else []
            result = []
            for item in items:
                public = public_item(cfg, item)
                if args.view != "all" and public["status"] in {"done", "dropped"}:
                    continue
                if args.view in BUCKETS and public["bucket"] != args.view:
                    continue
                if args.view == "session" and public["current_chat"] != args.chat:
                    continue
                result.append(public)
            print(json.dumps(result, ensure_ascii=False, indent=2))
    except (ValueError, KeyError, OSError, StopIteration, subprocess.CalledProcessError) as error:
        parser.exit(1, f"todo: {error}\n")


if __name__ == "__main__":
    main()
