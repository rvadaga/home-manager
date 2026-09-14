#!/usr/bin/env python3
"""check real bash redirections against a child-local 512-byte pipe model."""

import argparse
import json
import os
from pathlib import Path
import select
import signal
import stat
import subprocess
import sys
import tempfile


def run_owned(argv, env, folder, timeout):
    with tempfile.TemporaryFile(dir=folder) as output, tempfile.TemporaryFile(dir=folder) as errors:
        child = subprocess.Popen(argv, env=env, cwd=folder, stdout=output,
                                 stderr=errors, start_new_session=True)
        timed_out = False
        try:
            child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=2)
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=2)
        output.seek(0)
        errors.seek(0)
        return child.pid, child.returncode, timed_out, output.read(), errors.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--patched", required=True)
    parser.add_argument("--unpatched", required=True)
    parser.add_argument("--fixture", required=True)
    parser.add_argument("--evidence", required=True)
    args = parser.parse_args()
    evidence = Path(args.evidence).resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    results = []

    def case(shell, mode, kind, size, expect_timeout=False, expect_error=False):
        pattern = "az09_:/ \t$\\\"'\n"
        body = (pattern * (size // len(pattern) + 1))[:size]
        expected = body.encode() + b"\n"
        if kind == "empty-document":
            script = 'exec "$2" "$3" --read-stdin <<\'EOF\'\nEOF\n'
            expected = b""
        elif kind == "quoted-document":
            script = 'exec "$2" "$3" --read-stdin <<\'EOF\'\n' + body + '\nEOF\n'
        elif kind == "document":
            script = 'exec "$2" "$3" --read-stdin <<EOF\n$1\nEOF\n'
        else:
            script = 'exec "$2" "$3" --read-stdin <<< "$1"'
        label = f"{Path(shell).parent.parent.name}-{mode}-{kind}-{size}"
        log = evidence / f"{label}.jsonl"
        log.unlink(missing_ok=True)
        with tempfile.TemporaryDirectory(prefix="case-", dir=evidence) as folder:
            env = {"PATH": "/usr/bin:/bin", "HOME": folder, "TMPDIR": folder, "LC_ALL": "C"}
            if mode != "native":
                env.update(DYLD_INSERT_LIBRARIES=str(Path(args.fixture).resolve()),
                           BASH_PIPE_FIXTURE=mode, BASH_PIPE_FIXTURE_LOG=str(log))
            pid, code, timeout, output, errors = run_owned(
                [shell, "--noprofile", "--norc", "-c", script, "bash-pipe-test",
                 body, sys.executable, str(Path(__file__).resolve())], env, folder, 2)
            events = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            result = {"case": label, "pid": pid, "returncode": code, "timed_out": timeout,
                      "expected_bytes": len(expected), "actual_bytes": len(output),
                      "exact_bytes": output == expected, "events": events,
                      "reader": errors.decode(errors="replace").strip()}
            results.append(result)
            (evidence / "results.json").write_text(json.dumps(results, indent=2) + "\n")
            assert timeout == expect_timeout, result
            if expect_timeout:
                assert any(e["action"] == "blocked" and not e["nonblocking"] for e in events), result
            elif expect_error:
                assert code != 0 and output != expected, result
                assert events and all(e["action"] == "invalid-write-end" for e in events), result
            else:
                assert code == 0 and output == expected, result
                if mode != "native" and expected and len(expected) <= 16384:
                    assert events, result
                    if mode == "fcntl-failure":
                        assert all(e["action"] == "invalid-write-end" for e in events), result
                        assert result["reader"] == "file", result
                    else:
                        assert all(e["nonblocking"] == (shell == args.patched) for e in events), result
                        assert result["reader"] == ("pipe" if len(expected) <= 512 else "file"), result
                if len(expected) > 16384:
                    assert not events and result["reader"] == "file", result
                assert not list(Path(folder).iterdir()), result
            print(json.dumps({k: result[k] for k in ["case", "pid", "timed_out", "exact_bytes", "reader"]}), flush=True)

    for mode in ["partial", "eagain"]:
        case(args.unpatched, mode, "string", 511)
        case(args.unpatched, mode, "string", 512, expect_timeout=True)
        for kind in ["string", "document", "quoted-document"]:
            for size in [0, 1, 510, 511, 512, 513, 729, 4095, 4096, 16383, 16384, 65536]:
                case(args.patched, mode, kind, size)
        case(args.patched, mode, "empty-document", 0)
    for kind in ["string", "document", "quoted-document"]:
        for size in [511, 512, 729, 65536]:
            case(args.patched, "native", kind, size)
        for size in [511, 512, 16383]:
            case(args.patched, "fcntl-failure", kind, size)
    case(args.unpatched, "fcntl-failure", "string", 511, expect_error=True)

    for mode in ["partial", "eagain", "fcntl-failure", "native"]:
        log = evidence / f"lifetime-{mode}.jsonl"
        log.unlink(missing_ok=True)
        with tempfile.TemporaryDirectory(prefix="lifetime-", dir=evidence) as folder:
            env = {"PATH": "/usr/bin:/bin", "HOME": folder, "TMPDIR": folder, "LC_ALL": "C"}
            if mode != "native":
                env.update(DYLD_INSERT_LIBRARIES=str(Path(args.fixture).resolve()),
                           BASH_PIPE_FIXTURE=mode, BASH_PIPE_FIXTURE_LOG=str(log))
            script = '''printf -v body '%0730d' 0
for batch in 0 1 2 3; do
  if (( batch > 0 )); then
    for ((i=0; i<1000; i++)); do
      IFS= read -r got <<< "$body" || exit 9
      [[ $got == "$body" ]] || exit 10
    done
  fi
  printf '%s ' /dev/fd/*
  printf '\\n'
  IFS= read -r next || exit 11
done
'''
            with tempfile.TemporaryFile(dir=folder) as errors:
                child = subprocess.Popen([args.patched, "--noprofile", "--norc", "-c", script],
                                         env=env, cwd=folder, stdin=subprocess.PIPE,
                                         stdout=subprocess.PIPE, stderr=errors, start_new_session=True)
                descriptors = []
                try:
                    for batch in range(4):
                        assert select.select([child.stdout], [], [], 10)[0], (mode, child.pid, "checkpoint timeout")
                        line = child.stdout.readline().decode().split()
                        assert line and all(value.startswith("/dev/fd/") for value in line), (mode, line)
                        descriptors.append(line)
                        child.stdin.write(b"next\n")
                        child.stdin.flush()
                    assert child.wait(timeout=3) == 0, (mode, child.pid)
                finally:
                    if child.poll() is None:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait(timeout=3)
                    child.stdin.close()
                    child.stdout.close()
                assert all(value == descriptors[0] for value in descriptors), (mode, descriptors)
                assert not list(Path(folder).iterdir()), (mode, folder)
                if mode != "native":
                    events = [json.loads(line) for line in log.read_text().splitlines()]
                    action = "invalid-write-end" if mode == "fcntl-failure" else mode
                    assert sum(event["action"] == action for event in events) >= 3000, (mode, len(events))
                result = {"mode": mode, "pid": child.pid, "redirections": 3000, "descriptors": descriptors}
                (evidence / f"lifetime-{mode}.json").write_text(json.dumps(result, indent=2) + "\n")
                print(json.dumps(result), flush=True)
    print(f"passed {len(results)} owned-child cases", flush=True)


if __name__ == "__main__":
    if sys.argv[1:] == ["--read-stdin"]:
        mode = os.fstat(0).st_mode
        print("pipe" if stat.S_ISFIFO(mode) else "file" if stat.S_ISREG(mode) else "other", file=sys.stderr)
        sys.stdout.buffer.write(sys.stdin.buffer.read())
    else:
        main()
