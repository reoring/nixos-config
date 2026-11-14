"""Filesystem-level replacement tests; never touch the installed app or GUI."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("updater", Path(__file__).with_name("update.py"))
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class ReplacementTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.app = self.root / "Applications/Herdr.app"
        self.bundle = self.root / "build/Herdr.app"
        for bundle, contents in [(self.app, b"previous working binary"),
                                 (self.bundle, b"patched binary")]:
            (bundle / "Contents/MacOS").mkdir(parents=True)
            (bundle / "Contents/MacOS/Herdr").write_bytes(contents)

    def binary(self, bundle):
        return (bundle / "Contents/MacOS/Herdr").read_bytes()

    def test_success_retains_previous_bundle_as_backup(self):
        with patch.object(updater, "run"), patch.object(updater, "running", return_value=True), \
             patch.object(updater, "stop"), patch.object(updater, "launch_and_check"):
            updater.install(self.bundle, self.app)
        self.assertEqual(self.binary(self.app), b"patched binary")
        backups = list((self.app.parent / ".herdr-ime-backups").glob("*/Herdr.app"))
        self.assertEqual([self.binary(bundle) for bundle in backups], [b"previous working binary"])

    def test_failed_start_restores_previous_bundle(self):
        with patch.object(updater, "run"), patch.object(updater, "running", return_value=True), \
             patch.object(updater, "stop"), \
             patch.object(updater, "launch_and_check", side_effect=[RuntimeError("startup failed"), None]):
            with self.assertRaisesRegex(RuntimeError, "startup failed"):
                updater.install(self.bundle, self.app)
        self.assertEqual(self.binary(self.app), b"previous working binary")
        self.assertEqual(list(self.app.parent.glob(".herdr-ime-stage-*")), [])

    def test_bad_signature_leaves_installed_bundle_untouched(self):
        with patch.object(updater, "run", side_effect=subprocess.CalledProcessError(1, "codesign")):
            with self.assertRaises(subprocess.CalledProcessError):
                updater.install(self.bundle, self.app)
        self.assertEqual(self.binary(self.app), b"previous working binary")
        self.assertFalse((self.app.parent / ".herdr-ime-backups").exists())

    def test_refused_quit_leaves_installed_bundle_untouched(self):
        with patch.object(updater, "run"), patch.object(updater, "running", return_value=True), \
             patch.object(updater, "stop", side_effect=RuntimeError("did not quit")):
            with self.assertRaisesRegex(RuntimeError, "did not quit"):
                updater.install(self.bundle, self.app)
        self.assertEqual(self.binary(self.app), b"previous working binary")


if __name__ == "__main__":
    unittest.main()
