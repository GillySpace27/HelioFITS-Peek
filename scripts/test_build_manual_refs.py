#!/usr/bin/env python3
"""scripts/build_manual_refs.py: the history page is current, pointer-free and skips empty sections (DOCS-3)."""
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_manual_refs as bmr  # noqa: E402

LOG = """# Changelog

Notes about the format.

## [Unreleased]

## [9.9.9] - 2026-01-02

### Added

- Faster. [docs: manual/quick-look.md]

## [9.9.8] - 2026-01-01

- Older.
"""


class BuildManualRefsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = self.tmp.name
        with open(os.path.join(root, "CHANGELOG.md"), "w", encoding="utf-8") as f:
            f.write(LOG)
        self._root, self._gen = bmr.ROOT, bmr.GEN
        bmr.ROOT, bmr.GEN = root, os.path.join(root, "manual", "generated")

    def tearDown(self):
        bmr.ROOT, bmr.GEN = self._root, self._gen
        self.tmp.cleanup()

    def test_history_page(self):
        page = bmr.history_page()
        self.assertNotIn("[docs:", page)
        self.assertNotIn("Unreleased", page)
        self.assertNotIn("Notes about the format", page)
        self.assertIn("## [9.9.9] - 2026-01-02\n\n### Added\n\n- Faster.\n", page)
        self.assertIn("## [9.9.8] - 2026-01-01\n\n- Older.\n", page)

    def test_write_then_check_is_clean_and_a_changelog_edit_makes_it_stale(self):
        self.assertEqual(bmr.main([]), 0)
        self.assertEqual(bmr.main(["--check"]), 0)
        with open(os.path.join(bmr.ROOT, "CHANGELOG.md"), "a", encoding="utf-8") as f:
            f.write("- Another.\n")
        self.assertEqual(bmr.main(["--check"]), 1)


if __name__ == "__main__":
    unittest.main()
