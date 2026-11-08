import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "extension", Path(__file__).with_name("ensure-lean-extension.py")
)
extension = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extension)


class ExtensionTests(unittest.TestCase):
    def check(self, output, installs):
        with patch.object(extension.Path, "is_file", return_value=True), \
             patch.object(extension.subprocess, "check_output", side_effect=[output, "leanprover.lean4@0.0.240\n"]), \
             patch.object(extension.subprocess, "run") as run:
            extension.ensure("/existing/code", "/pinned/lean.vsix", "0.0.240")
            if installs:
                run.assert_called_once_with(
                    ["/existing/code", "--install-extension", "/pinned/lean.vsix"], check=True
                )
            else:
                run.assert_not_called()

    def test_missing(self):
        self.check("other.extension@9.0.0\n", True)

    def test_older(self):
        self.check("leanprover.lean4@0.0.239\n", True)

    def test_equal(self):
        self.check("leanprover.lean4@0.0.240\n", False)

    def test_newer(self):
        self.check("leanprover.lean4@0.0.300\n", False)

    def test_unknown_version_stops(self):
        with self.assertRaises(ValueError):
            self.check("leanprover.lean4@unknown\n", False)

    def test_missing_editor(self):
        with patch.object(extension.Path, "is_file", return_value=False), \
             patch.object(extension.subprocess, "check_output") as query:
            extension.ensure("/absent/code", "/pinned/lean.vsix", "0.0.240")
            query.assert_not_called()

    def test_cli_failure(self):
        with patch.object(extension.Path, "is_file", return_value=True), \
             patch.object(extension.subprocess, "check_output", side_effect=RuntimeError("CLI failed")), \
             patch.object(extension.subprocess, "run") as run:
            with self.assertRaises(RuntimeError):
                extension.ensure("/existing/code", "/pinned/lean.vsix", "0.0.240")
            run.assert_not_called()

    def test_success_exit_without_registration_fails(self):
        with patch.object(extension.Path, "is_file", return_value=True), \
             patch.object(extension.subprocess, "check_output", return_value="other.extension@9.0.0\n"), \
             patch.object(extension.subprocess, "run"):
            with self.assertRaises(RuntimeError):
                extension.ensure("/existing/code", "/pinned/lean.vsix", "0.0.240")


if __name__ == "__main__":
    unittest.main()
