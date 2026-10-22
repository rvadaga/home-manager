#!/usr/bin/env python3
"""check command display and forwarding without invoking privileged sudo."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class SudoAskTest(unittest.TestCase):
    def test_argv_and_context(self):
        source = Path(__file__).with_name("sudo-ask.sh").read_text()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stub = root / "sudo-stub"
            stub.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "print(json.dumps({'argv': sys.argv, 'command': os.environ['SUDO_ASKPASS_COMMAND'], "
                "'session': os.environ['SUDO_ASKPASS_SESSION']}))\n"
                "sys.exit(17)\n"
            )
            stub.chmod(0o700)
            launcher = root / "sudo-ask"
            self.assertEqual(source.count("/usr/bin/sudo"), 1)
            launcher.write_text(source.replace("/usr/bin/sudo", str(stub)))
            env = dict(os.environ, SUDO_ASKPASS=str(stub), SUDO_ASKPASS_SESSION="test session")
            args = ["-u", "root", "--", "/usr/bin/printf", "%s\\n", "", "a b", "'quoted'", "$(touch /not-executed)", "a\nb", "café"]
            result = subprocess.run(["/bin/bash", str(launcher), *args], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 17)
            self.assertEqual(result.stderr, "")
            record = json.loads(result.stdout)
            self.assertEqual(record["argv"], [str(stub), "-A", *args])
            self.assertEqual(record["session"], "test session")
            # only synthetic arguments are evaluated to check the shell-quoted display.
            round_trip = subprocess.run(["/bin/bash", "-c", record["command"]], env=env | {"SUDO_ASKPASS_COMMAND": record["command"]}, capture_output=True, text=True)
            self.assertEqual(round_trip.returncode, 17)
            self.assertEqual(json.loads(round_trip.stdout)["argv"], record["argv"])
            for invalid_env, invalid_args in [
                (env | {"SUDO_ASKPASS_SESSION": ""}, args),
                (env | {"SUDO_ASKPASS": str(root / "missing")}, args),
                (env, []),
            ]:
                failure = subprocess.run(["/bin/bash", str(launcher), *invalid_args], env=invalid_env, capture_output=True, text=True)
                self.assertEqual(failure.returncode, 2)
                self.assertEqual(failure.stdout, "")


if __name__ == "__main__":
    unittest.main()
