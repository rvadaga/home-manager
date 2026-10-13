#!/usr/bin/env python3

import argparse
import os
import pathlib
import re
import stat
import subprocess
import tempfile
import unittest


def provenance_step(path):
    script = pathlib.Path(path).read_text()
    match = re.search(r'^_iNote .*"writeNixHomeProvenance"\n(.*?^fi$)', script, re.M | re.S)
    if not match:
        raise ValueError("generated provenance activation step is missing")
    return match.group(1)


class ProvenanceActivationTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.target = self.root / "state" / "provenance"

    def activate(self, mode, driver, dry_run=False):
        step = provenance_step(SCRIPTS[mode])
        step, count = re.subn(r'^  provenance_dir="[^"]*"$',
                             f'  provenance_dir="{self.target.parent}"', step, flags=re.M)
        self.assertEqual(count, 1)
        env = dict(os.environ, hmDriverVersion=str(driver), newGenPath=f"/example/{mode}",
                   DRY_RUN="1" if dry_run else "")
        subprocess.run(["bash", "-eu", "-c", step], env=env, check=True,
                       capture_output=True, text=True)

    def test_modes_follow_the_built_configuration_for_both_driver_versions(self):
        for driver in (0, 1):
            for mode in ("standalone", "embedded", "standalone"):
                with self.subTest(driver=driver, mode=mode):
                    self.activate(mode, driver)
                    stamp = dict(line.split("=", 1) for line in self.target.read_text().splitlines())
                    self.assertEqual(stamp["activation"], mode)
                    self.assertEqual(stamp["generation"], f"/example/{mode}")
                    self.assertEqual(set(stamp), {"rev", "narHash", "lastModified", "storePath",
                                                 "generation", "activation"})
                    self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o644)
                    self.assertEqual(list(self.target.parent.glob("provenance.tmp.*")), [])

    def test_dry_run_neither_creates_nor_replaces_a_stamp(self):
        for mode in SCRIPTS:
            self.activate(mode, 1, dry_run=True)
            self.assertFalse(self.target.exists())
        self.activate("standalone", 1)
        before = self.target.read_bytes()
        for mode in SCRIPTS:
            self.activate(mode, 1, dry_run=True)
            self.assertEqual(self.target.read_bytes(), before)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="test provenance writes from both generated activation scripts")
    parser.add_argument("--standalone", required=True)
    parser.add_argument("--embedded", required=True)
    args = parser.parse_args()
    SCRIPTS = {"standalone": args.standalone, "embedded": args.embedded}
    unittest.main(argv=[__file__])
