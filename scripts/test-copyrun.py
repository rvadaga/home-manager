#!/usr/bin/env python3
"""Exercise copyrun in clean zsh processes without touching the real clipboard."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).with_name("copyrun.zsh")


class CopyrunTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="test-copyrun-")
        self.root = Path(self.directory.name)
        self.clipboard = self.root / "clipboard"
        self.env = dict(os.environ, TMPDIR=str(self.root), COPYRUN_HELPER=str(HELPER),
                        TEST_CLIPBOARD=str(self.clipboard))

    def tearDown(self):
        self.directory.cleanup()

    def run_shell(self, body, *, stdin=None):
        script = self.root / "test.zsh"
        script.write_text('''
unsetopt bg_nice
source "$COPYRUN_HELPER"
function clipcopy { command cat > "$TEST_CLIPBOARD"; }
''' + body)
        result = subprocess.run(
            ["zsh", "-f", str(script)], input=stdin, capture_output=True, env=self.env,
        )
        self.assertEqual(list(self.root.glob("copyrun.*")), [])
        return result

    def assert_copied(self, result, status=0):
        self.assertEqual(result.returncode, status, result.stderr)
        self.assertEqual(result.stderr, b"")
        self.assertEqual(self.clipboard.read_bytes(), result.stdout)

    def test_executable_and_combined_output(self):
        result = self.run_shell("copyrun sh -c 'printf out; printf err >&2; exit 17'")
        self.assert_copied(result, 17)
        self.assertTrue(result.stdout.endswith(b"outerr"))

    def test_arguments_and_function(self):
        result = self.run_shell('''
function show_args { printf '<%s>\\n' "$@"; }
copyrun show_args '' 'two words' "it's quoted" '雪' '$HOME' '$(false)' '; false' '*'
''')
        self.assert_copied(result)
        self.assertTrue(result.stdout.endswith(
            "<>\n<two words>\n<it's quoted>\n<雪>\n<$HOME>\n<$(false)>\n<; false>\n<*>\n".encode()))

    def test_aliases_and_reload(self):
        result = self.run_shell('''
source "$COPYRUN_HELPER"
function show_args { printf '<%s>\\n' "$@"; }
alias short=show_args
alias multi='show_args fixed "two words"'
copyrun short first
copyrun multi last
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"show_args first\n<first>\n", result.stdout)
        self.assertTrue(result.stdout.endswith(b"<fixed>\n<two words>\n<last>\n"))
        self.assertIn(b"show_args fixed", self.clipboard.read_bytes())
        self.assertNotIn(b"multi", self.clipboard.read_bytes())

    def test_piped_stdin(self):
        result = self.run_shell("copyrun cat", stdin=b"input\n")
        self.assert_copied(result)
        self.assertTrue(result.stdout.endswith(b"cat\ninput\n"))

    def test_large_output(self):
        result = self.run_shell("copyrun head -c 1000000 /dev/zero")
        self.assert_copied(result)
        self.assertTrue(result.stdout.endswith(b"\0" * 1000000))

    def test_missing_and_failed_clipboard(self):
        for setup, warning in [("unfunction clipcopy", b"unavailable"),
                               ("function clipcopy { return 9; }", b"copy failed")]:
            for status in (0, 23):
                with self.subTest(setup=setup, status=status):
                    result = self.run_shell(setup + f"\ncopyrun sh -c 'printf complete; exit {status}'")
                    self.assertEqual(result.returncode, status)
                    self.assertTrue(result.stdout.endswith(b"complete"))
                    self.assertIn(warning, result.stderr)

    def test_async_clipboard_reads_open_stdin(self):
        result = self.run_shell('''
function clipcopy { unsetopt bg_nice; (sleep 0.1; command cat > "$TEST_CLIPBOARD") &! }
copyrun printf 'delayed copy\\n'
sleep 0.3
''')
        self.assert_copied(result)

    def test_caller_error_options(self):
        for option in ("err_exit", "err_return"):
            with self.subTest(option=option):
                result = self.run_shell(f"setopt {option}\ncopyrun sh -c 'printf failed; exit 27'")
                self.assert_copied(result, 27)

    def test_usage_and_missing_command(self):
        result = self.run_shell("copyrun")
        self.assertEqual(result.returncode, 2)
        self.assertIn(b"usage:", result.stderr)
        self.assertFalse(self.clipboard.exists())
        result = self.run_shell("copyrun copyrun_nonexistent_command")
        self.assert_copied(result, 127)
        self.assertIn(b"command not found", result.stdout)

    def test_output_is_live(self):
        process = subprocess.Popen(
            ["zsh", "-f", "-c", '''
source "$COPYRUN_HELPER"
function clipcopy { command cat > "$TEST_CLIPBOARD"; }
function stream {
  printf 'first\\n'
  while [[ ! -e "$TMPDIR/continue" ]]; do sleep 0.02; done
  printf 'last\\n'
}
copyrun stream
'''], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=self.env,
        )
        try:
            invocation = process.stdout.readline()
            self.assertEqual(process.stdout.readline(), b"first\n")
            self.assertIsNone(process.poll())
            (self.root / "continue").touch()
            rest, errors = process.communicate(timeout=5)
            self.assertEqual(rest, b"last\n")
            self.assertEqual(errors, b"")
            self.assertEqual(self.clipboard.read_bytes(), invocation + b"first\nlast\n")
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


if __name__ == "__main__":
    unittest.main()
