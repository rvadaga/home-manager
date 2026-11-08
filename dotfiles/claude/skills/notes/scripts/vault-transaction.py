#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import secrets
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path


LOCK_NAME = "status-page-writer.lock"
METADATA_NAME = "owner.json"
GLOB_CHARACTERS = frozenset("*?[")


class TransactionError(RuntimeError):
    pass


def git(vault: Path, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        ["git", "-C", str(vault), *arguments],
        check=False,
        capture_output=True,
        env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"},
    )
    if check and result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise TransactionError(
            f"git {' '.join(arguments)} failed with exit {result.returncode}: {detail}"
        )
    return result


def text_output(result: subprocess.CompletedProcess[bytes]) -> str:
    return result.stdout.decode("utf-8", errors="replace").strip()


def validate_relative_path(raw_path: str) -> str:
    if not raw_path or raw_path.startswith("/") or "\\" in raw_path:
        raise argparse.ArgumentTypeError(
            f"declared path must be a nonempty vault-relative posix path: {raw_path!r}"
        )
    if any(character in raw_path for character in GLOB_CHARACTERS):
        raise argparse.ArgumentTypeError(
            f"declared path must be exact and cannot contain glob syntax: {raw_path!r}"
        )
    parts = raw_path.split("/")
    if any(part in {"", ".", ".."} for part in parts) or parts[0] == ".git":
        raise argparse.ArgumentTypeError(
            f"declared path must be normalized and outside .git: {raw_path!r}"
        )
    return raw_path


def parse_command(raw_command: str, label: str) -> list[str]:
    try:
        command = json.loads(raw_command)
    except json.JSONDecodeError as error:
        raise argparse.ArgumentTypeError(
            f"{label} must be a json array of argument strings: {error}"
        ) from error
    if not isinstance(command, list) or not command or not all(
        isinstance(argument, str) and argument for argument in command
    ):
        raise argparse.ArgumentTypeError(
            f"{label} must be a nonempty json array of nonempty argument strings"
        )
    return command


def parse_known_owner(raw_owner: str) -> tuple[str, str]:
    if "=" not in raw_owner:
        raise argparse.ArgumentTypeError(
            "known owner must use the exact form path=owner"
        )
    raw_path, owner = raw_owner.split("=", 1)
    path = validate_relative_path(raw_path)
    if not owner:
        raise argparse.ArgumentTypeError("known owner cannot be empty")
    return path, owner


def status_paths(vault: Path) -> set[str]:
    result = git(
        vault,
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
    )
    entries = result.stdout.split(b"\0")
    if entries and entries[-1] == b"":
        entries.pop()

    paths: set[str] = set()
    index = 0
    while index < len(entries):
        entry = entries[index]
        if len(entry) < 4 or entry[2:3] != b" ":
            raise TransactionError("could not parse git status porcelain output")
        state = entry[:2].decode("ascii", errors="replace")
        paths.add(entry[3:].decode("utf-8", errors="surrogateescape"))
        if "R" in state or "C" in state:
            index += 1
            if index >= len(entries):
                raise TransactionError("git status omitted a rename source path")
            paths.add(entries[index].decode("utf-8", errors="surrogateescape"))
        index += 1
    return paths


def nul_paths(result: subprocess.CompletedProcess[bytes]) -> set[str]:
    return {
        path.decode("utf-8", errors="surrogateescape")
        for path in result.stdout.split(b"\0")
        if path
    }


def staged_paths(vault: Path) -> set[str]:
    return nul_paths(
        git(vault, "diff", "--cached", "--name-only", "--no-renames", "-z", "--")
    )


def committed_paths(vault: Path, revision: str) -> set[str]:
    return nul_paths(
        git(
            vault,
            "diff-tree",
            "--root",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            "-z",
            revision,
            "--",
        )
    )


def read_metadata(lock_path: Path) -> dict[str, object] | None:
    metadata_path = lock_path / METADATA_NAME
    try:
        value = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return None
    return value if isinstance(value, dict) else None


def owner_map_from_lock(lock_path: Path) -> dict[str, str]:
    metadata = read_metadata(lock_path)
    if metadata is None:
        return {}
    owner = metadata.get("owner")
    paths = metadata.get("paths")
    if not isinstance(owner, str) or not isinstance(paths, list):
        return {}
    return {
        path: owner
        for path in paths
        if isinstance(path, str)
    }


def format_paths(paths: set[str]) -> str:
    return ", ".join(sorted(paths)) if paths else "none"


def report_dirty(
    heading: str,
    paths: set[str],
    known_owners: dict[str, str],
    declared_paths: set[str],
    transaction_owner: str,
    current_transaction: bool,
) -> str:
    lines = [heading]
    for path in sorted(paths):
        owner = known_owners.get(path)
        if owner is None and current_transaction and path in declared_paths:
            owner = transaction_owner
        lines.append(f"- {path} (owner: {owner or 'unknown'})")
    return "\n".join(lines)


def run_command(
    command: list[str],
    vault: Path,
    environment: dict[str, str],
    label: str,
) -> None:
    try:
        result = subprocess.run(command, cwd=vault, env=environment, check=False)
    except OSError as error:
        raise TransactionError(f"could not start {label}: {error}") from error
    if result.returncode != 0:
        raise TransactionError(f"{label} failed with exit {result.returncode}")


def file_state(path: Path) -> tuple[int, str] | None:
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return None
    if stat.S_ISLNK(mode):
        digest = hashlib.sha256(os.fsencode(os.readlink(path))).hexdigest()
    elif stat.S_ISREG(mode):
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
    else:
        raise TransactionError(f"expected a file or symlink: {path}")
    return mode, digest


def worktree_state(vault: Path, declared: set[str]) -> dict[str, tuple[int, str] | None]:
    paths = nul_paths(git(vault, "ls-files", "--cached", "--others", "--exclude-standard", "-z"))
    return {path: file_state(vault / path) for path in paths | declared}


def installed_mode() -> str:
    # Keep the invocation path: installed symlinks use their caller's policy.
    policy = Path(__file__).absolute().parents[1] / "references/transaction-policy.json"
    if not policy.exists():
        return "commit"
    try:
        value = json.loads(policy.read_text())
    except (OSError, ValueError) as error:
        raise TransactionError(f"cannot read transaction policy: {error}") from error
    if value not in ({"mode": "save"}, {"mode": "commit"}):
        raise TransactionError("transaction policy must contain mode save or commit")
    return value["mode"]


def check_saved_diff(vault: Path, before: dict[str, bytes], changed: set[str]) -> None:
    # Check only this save's delta, including new files; earlier edits stay intact.
    with tempfile.TemporaryDirectory(prefix="vault-save-diff-") as directory:
        old, new = Path(directory) / "before", Path(directory) / "after"
        for relative in sorted(changed):
            target = vault / relative
            if target.is_symlink():
                raise TransactionError(f"save created a symlink: {relative}")
            old.write_bytes(before[relative])
            new.write_bytes(target.read_bytes() if target.exists() else b"")
            result = subprocess.run(["git", "diff", "--no-index", "--check", "--", str(old), str(new)], capture_output=True)
            if result.returncode not in (0, 1) or result.stdout or result.stderr:
                detail = (result.stdout + result.stderr).decode("utf-8", errors="replace").strip()
                raise TransactionError(f"saved diff check failed for {relative}: {detail}")


@dataclass
class Transaction:
    vault: Path
    owner: str
    paths: list[str]
    known_owners: dict[str, str]
    commit_message: str
    write_command: list[str]
    validator_command: list[str]
    allow_noop: bool = False
    mode: str = "commit"
    declared_paths: set[str] = field(init=False)
    recorded_head: str = field(init=False, default="")
    lock_path: Path = field(init=False)
    token: str = field(init=False, default="")
    lock_acquired: bool = field(init=False, default=False)
    lock_released: bool = field(init=False, default=False)
    committed_head: str | None = field(init=False, default=None)
    before_files: dict[str, tuple[int, str] | None] | None = field(init=False, default=None)
    before_index: bytes | None = field(init=False, default=None)

    def __post_init__(self) -> None:
        if self.mode not in {"save", "commit"}:
            raise TransactionError("transaction mode must be save or commit")
        self.declared_paths = set(self.paths)
        if len(self.declared_paths) != len(self.paths):
            raise TransactionError("declared paths must be unique")

        if not self.vault.is_absolute():
            raise TransactionError("vault path must be absolute")
        self.vault = self.vault.resolve()
        if not self.vault.is_dir():
            raise TransactionError(f"vault is not a directory: {self.vault}")

        inside_worktree = text_output(git(self.vault, "rev-parse", "--is-inside-work-tree"))
        if inside_worktree != "true":
            raise TransactionError(f"vault is not a git worktree: {self.vault}")

        common_git_dir = Path(text_output(git(self.vault, "rev-parse", "--git-common-dir")))
        if not common_git_dir.is_absolute():
            common_git_dir = self.vault / common_git_dir
        self.lock_path = common_git_dir.resolve() / LOCK_NAME
        for relative in self.paths:
            target = self.vault / relative
            if any(part.is_symlink() for part in (target, *target.parents) if part != self.vault.parent):
                raise TransactionError(f"declared path must not traverse a symlink: {relative}")

    def effective_known_owners(self) -> dict[str, str]:
        owners = owner_map_from_lock(self.lock_path)
        owners.update(self.known_owners)
        return owners

    def require_clean_preflight(self) -> None:
        dirty = status_paths(self.vault)
        if dirty:
            raise TransactionError(
                report_dirty(
                    "dirty preflight; refusing to acquire the writer lock",
                    dirty,
                    self.effective_known_owners(),
                    self.declared_paths,
                    self.owner,
                    current_transaction=False,
                )
            )

    def acquire(self) -> None:
        self.recorded_head = text_output(git(self.vault, "rev-parse", "HEAD"))
        self.token = secrets.token_hex(24)
        try:
            self.lock_path.mkdir(mode=0o700)
        except FileExistsError as error:
            metadata = read_metadata(self.lock_path)
            lock_owner = metadata.get("owner") if metadata else "unknown"
            lock_paths = metadata.get("paths") if metadata else []
            raise TransactionError(
                f"writer lock already exists (owner: {lock_owner}; "
                f"paths: {lock_paths or 'unknown'})"
            ) from error

        self.lock_acquired = True
        metadata = {
            "token": self.token,
            "owner": self.owner,
            "acquired_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "head": self.recorded_head,
            "paths": self.paths,
        }
        metadata_path = self.lock_path / METADATA_NAME
        descriptor = os.open(
            metadata_path,
            os.O_CREAT | os.O_EXCL | os.O_WRONLY,
            0o600,
        )
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(metadata, stream, indent=2, sort_keys=True)
            stream.write("\n")

        current_head = text_output(git(self.vault, "rev-parse", "HEAD"))
        dirty = status_paths(self.vault)
        if current_head != self.recorded_head:
            raise TransactionError(
                f"vault head moved during lock acquisition: "
                f"{self.recorded_head} -> {current_head}"
            )
        if dirty and self.mode == "commit":
            raise TransactionError(
                report_dirty(
                    "vault became dirty during lock acquisition",
                    dirty,
                    self.effective_known_owners(),
                    self.declared_paths,
                    self.owner,
                    current_transaction=False,
                )
            )

    def environment(self) -> dict[str, str]:
        environment = os.environ.copy()
        environment.update(
            {
                "WORK_VAULT_PATH": str(self.vault),
                "WORK_VAULT_LOCK_DIR": str(self.lock_path),
                "WORK_VAULT_TOKEN": self.token,
                "WORK_VAULT_RECORDED_HEAD": self.recorded_head,
                "WORK_VAULT_DECLARED_PATHS_JSON": json.dumps(self.paths),
                "GIT_OPTIONAL_LOCKS": "0",
            }
        )
        return environment

    def require_head_unchanged(self, stage: str) -> None:
        current_head = text_output(git(self.vault, "rev-parse", "HEAD"))
        if current_head != self.recorded_head:
            raise TransactionError(
                f"vault head changed {stage}: {self.recorded_head} -> {current_head}"
            )

    def require_writer_scope(self, stage: str) -> None:
        staged = staged_paths(self.vault)
        if staged:
            raise TransactionError(
                f"{stage}: writer or validator staged paths before the wrapper: "
                f"{format_paths(staged)}"
            )
        changed = status_paths(self.vault)
        if self.allow_noop and not changed:
            return
        if changed != self.declared_paths:
            raise TransactionError(
                f"{stage}: changed path scope differs from declared scope; "
                f"declared: {format_paths(self.declared_paths)}; "
                f"changed: {format_paths(changed)}"
            )

    def release(self) -> None:
        metadata = read_metadata(self.lock_path)
        current_token = metadata.get("token") if metadata else None
        if current_token != self.token:
            raise TransactionError(
                "writer lock token mismatch; preserving the lock for coordinator recovery"
            )

        entries = {entry.name for entry in self.lock_path.iterdir()}
        if entries != {METADATA_NAME}:
            raise TransactionError(
                f"writer lock contains unexpected entries: {', '.join(sorted(entries))}"
            )

        metadata_path = self.lock_path / METADATA_NAME
        metadata_bytes = metadata_path.read_bytes()
        metadata_path.unlink()
        try:
            self.lock_path.rmdir()
        except OSError as error:
            try:
                descriptor = os.open(
                    metadata_path,
                    os.O_CREAT | os.O_EXCL | os.O_WRONLY,
                    0o600,
                )
                with os.fdopen(descriptor, "wb") as stream:
                    stream.write(metadata_bytes)
            except OSError:
                pass
            raise TransactionError(f"could not remove writer lock: {error}") from error

        if self.lock_path.exists():
            raise TransactionError("writer lock still exists after release")
        self.lock_released = True

    def execute(self) -> None:
        if self.mode == "commit":
            self.require_clean_preflight()
        self.acquire()
        if self.mode == "save":
            self.execute_save()
            return
        environment = self.environment()

        run_command(self.write_command, self.vault, environment, "write command")
        self.require_head_unchanged("after the write command")
        self.require_writer_scope("after the write command")

        run_command(
            self.validator_command,
            self.vault,
            environment,
            "validator command",
        )
        self.require_head_unchanged("after the validator command")
        self.require_writer_scope("after the validator command")

        if self.allow_noop and not status_paths(self.vault):
            self.release()
            print("transaction unchanged: validated; vault clean; writer lock absent")
            return

        diff_check = git(self.vault, "diff", "--check", check=False)
        if diff_check.returncode != 0:
            detail = diff_check.stdout.decode("utf-8", errors="replace").strip()
            raise TransactionError(f"git diff --check failed: {detail}")

        git(self.vault, "add", "--", *self.paths)
        staged = staged_paths(self.vault)
        if staged != self.declared_paths:
            raise TransactionError(
                "staged scope differs from declared scope; "
                f"declared: {format_paths(self.declared_paths)}; "
                f"staged: {format_paths(staged)}"
            )

        cached_check = git(self.vault, "diff", "--cached", "--check", check=False)
        if cached_check.returncode != 0:
            detail = cached_check.stdout.decode("utf-8", errors="replace").strip()
            raise TransactionError(f"staged git diff --check failed: {detail}")

        git(self.vault, "commit", "--message", self.commit_message)
        self.committed_head = text_output(git(self.vault, "rev-parse", "HEAD"))
        parents = text_output(git(self.vault, "show", "--no-patch", "--format=%P", "HEAD"))
        if parents.split() != [self.recorded_head]:
            raise TransactionError(
                f"commit parent differs from recorded head: {parents or 'none'}"
            )

        committed = committed_paths(self.vault, self.committed_head)
        if committed != self.declared_paths:
            raise TransactionError(
                "committed scope differs from declared scope; "
                f"declared: {format_paths(self.declared_paths)}; "
                f"committed: {format_paths(committed)}"
            )

        dirty = status_paths(self.vault)
        if dirty:
            raise TransactionError(
                report_dirty(
                    "dirty postcondition; the writing owner must finish and commit its own paths",
                    dirty,
                    self.effective_known_owners(),
                    self.declared_paths,
                    self.owner,
                    current_transaction=True,
                )
            )

        self.release()
        print(
            f"transaction complete: {self.committed_head}; "
            "vault clean; writer lock absent"
        )

    def index_bytes(self) -> bytes:
        path = Path(text_output(git(self.vault, "rev-parse", "--git-path", "index")))
        if not path.is_absolute():
            path = self.vault / path
        return path.read_bytes()

    def require_saved_git_state(self) -> None:
        self.require_head_unchanged("during save")
        if self.index_bytes() != self.before_index:
            raise TransactionError("save changed the git index; preserving the lock")

    def execute_save(self) -> None:
        self.before_index = self.index_bytes()
        self.before_files = worktree_state(self.vault, self.declared_paths)
        before_contents = {p: (self.vault / p).read_bytes() if (self.vault / p).exists() else b""
                           for p in self.paths}
        environment = self.environment()
        run_command(self.write_command, self.vault, environment, "write command")
        self.require_saved_git_state()
        written = worktree_state(self.vault, self.declared_paths)
        changed = {p for p in self.before_files.keys() | written.keys()
                   if self.before_files.get(p) != written.get(p)}
        if changed != self.declared_paths and not (self.allow_noop and not changed):
            raise TransactionError(
                "save changed path scope differs from declared scope; "
                f"declared: {format_paths(self.declared_paths)}; changed: {format_paths(changed)}"
            )
        run_command(self.validator_command, self.vault, environment, "validator command")
        self.require_saved_git_state()
        if worktree_state(self.vault, self.declared_paths) != written:
            raise TransactionError("saved file readback changed during validation; preserving the lock")
        if changed:
            check_saved_diff(self.vault, before_contents, changed)
        self.release()
        outcome = "complete" if changed else "unchanged"
        print(f"save {outcome}: validated and read back; HEAD and index unchanged; writer lock absent")

    def cleanup_after_failure(self) -> None:
        if not self.lock_acquired or self.lock_released:
            return

        if self.mode == "save":
            if (self.before_files is None or
                    worktree_state(self.vault, self.declared_paths) != self.before_files or
                    self.index_bytes() != self.before_index or
                    text_output(git(self.vault, "rev-parse", "HEAD")) != self.recorded_head):
                print("incomplete save; preserving files and matching lock for the writing owner", file=sys.stderr)
                return
            try:
                self.release()
            except TransactionError as error:
                print(f"exit cleanup could not release the writer lock: {error}", file=sys.stderr)
            return

        dirty = status_paths(self.vault)
        current_head = text_output(git(self.vault, "rev-parse", "HEAD"))
        if dirty:
            print(
                report_dirty(
                    "incomplete transaction; preserving the lock and routing paths to their writer",
                    dirty,
                    self.effective_known_owners(),
                    self.declared_paths,
                    self.owner,
                    current_transaction=True,
                ),
                file=sys.stderr,
            )
            return

        if current_head != self.recorded_head:
            print(
                "incomplete transaction changed the vault head; preserving the lock "
                "for the writing owner",
                file=sys.stderr,
            )
            return

        try:
            self.release()
        except TransactionError as error:
            print(f"exit cleanup could not release the writer lock: {error}", file=sys.stderr)
            return
        print(
            "exit cleanup released the matching writer lock; vault clean; writer lock absent",
            file=sys.stderr,
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "run one exact-path vault write with validation and matching lock release"
        )
    )
    parser.add_argument("--vault", required=True, type=Path)
    parser.add_argument("--owner", required=True)
    parser.add_argument(
        "--path",
        action="append",
        required=True,
        type=validate_relative_path,
        dest="paths",
        help="exact vault-relative path; repeat for every path the transaction will write",
    )
    parser.add_argument(
        "--known-owner",
        action="append",
        default=[],
        type=parse_known_owner,
        help="known pre-existing path owner in the exact form path=owner",
    )
    parser.add_argument("--mode", choices=("save", "commit"), help="save leaves HEAD and index unchanged; installed save policy forbids commit mode")
    parser.add_argument("--commit-message")
    parser.add_argument("--allow-noop", action="store_true", help="validate and release an unchanged transaction")
    parser.add_argument(
        "--write-command-json",
        required=True,
        help="json array containing the writer executable and each argument",
    )
    parser.add_argument(
        "--validator-command-json",
        required=True,
        help="json array containing the validator executable and each argument",
    )
    return parser


def main(*, save_only: bool = False) -> int:
    parser = build_parser()
    arguments = parser.parse_args()
    if not arguments.owner:
        parser.error("owner cannot be empty")
    try:
        policy = "save" if save_only else installed_mode()
        mode = arguments.mode or policy
        if policy == "save" and mode != "save":
            parser.error("installed save-only policy forbids writer commits")
        if mode == "commit" and not arguments.commit_message:
            parser.error("commit mode requires a nonempty --commit-message")
        if mode == "save" and arguments.commit_message is not None:
            parser.error("save mode does not accept --commit-message")
        write_command = parse_command(arguments.write_command_json, "write command")
        validator_command = parse_command(
            arguments.validator_command_json,
            "validator command",
        )
        known_owners = dict(arguments.known_owner)
        transaction = Transaction(
            vault=arguments.vault,
            owner=arguments.owner,
            paths=arguments.paths,
            known_owners=known_owners,
            commit_message=arguments.commit_message,
            write_command=write_command,
            validator_command=validator_command,
            allow_noop=arguments.allow_noop,
            mode=mode,
        )
    except (TransactionError, argparse.ArgumentTypeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    result = 0
    try:
        transaction.execute()
    except TransactionError as error:
        print(f"error: {error}", file=sys.stderr)
        result = 1
    finally:
        transaction.cleanup_after_failure()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
