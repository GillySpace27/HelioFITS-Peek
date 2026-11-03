#!/usr/bin/env python3
"""scripts/docs_check.py: pointers parsed, problems found, pointers stripped (DOCS-3)."""
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import docs_check  # noqa: E402

LOG = """# Changelog

## [Unreleased]

- Not checked until it has a version. [docs: nowhere.md]

## [9.9.9] - 2026-01-02

### Things
- Documented in the guide. [docs: guide.md]
- Points at a page that is missing. [docs: missing.md]
- Has no pointer at all.
- Internal only. [docs: none]
- Wraps onto
  a second line. [docs: guide.md#section]
    - nested bullets need no pointer

## [9.9.8] - 2026-01-01
- Older, not checked.
"""


def git(root, *args):
    subprocess.run(["git", "-C", root, *args], check=True, capture_output=True,
                   env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
                        "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"})


class DocsCheckTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        with open(os.path.join(self.root, "guide.md"), "w") as f:
            f.write("old\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_problems_without_a_tag(self):
        problems, notes = docs_check.check(LOG, "9.9.9", self.root, None)
        self.assertEqual(len(problems), 2, problems)
        self.assertTrue(any("missing.md does not exist" in p for p in problems))
        self.assertTrue(any(p.startswith("no [docs: ...] pointer: Has no pointer") for p in problems))
        self.assertTrue(any("SKIP" in n for n in notes))

    def test_unchanged_since_tag_is_a_problem_and_a_change_clears_it(self):
        git(self.root, "init", "-q")
        git(self.root, "add", "guide.md")
        git(self.root, "commit", "-qm", "start")
        git(self.root, "tag", "v9.9.8")
        problems, _ = docs_check.check(LOG, "9.9.9", self.root, "v9.9.8")
        self.assertEqual(sum("guide.md unchanged since v9.9.8" in p for p in problems), 2, problems)
        with open(os.path.join(self.root, "guide.md"), "a") as f:
            f.write("new\n")
        problems, _ = docs_check.check(LOG, "9.9.9", self.root, "v9.9.8")
        self.assertFalse(any("unchanged" in p for p in problems), problems)

    def test_previous_tag_skips_this_versions_build_tags(self):
        git(self.root, "init", "-q")
        git(self.root, "add", "guide.md")
        git(self.root, "commit", "-qm", "start")
        git(self.root, "tag", "v9.9.8-build.4")
        git(self.root, "commit", "-qm", "next", "--allow-empty")
        git(self.root, "tag", "v9.9.9-build.5")
        self.assertEqual(docs_check.previous_tag(self.root, "9.9.9"), "v9.9.8-build.4")

    def test_missing_section(self):
        problems, _ = docs_check.check(LOG, "9.9", self.root, None)
        self.assertEqual(problems, ["changelog has no '## ' section naming 9.9"])

    def test_older_section_is_its_own(self):
        problems, _ = docs_check.check(LOG, "9.9.8", self.root, None)
        self.assertEqual(problems, ["no [docs: ...] pointer: Older, not checked."])

    def test_strict_exit_code(self):
        log = os.path.join(self.root, "CHANGELOG.md")
        with open(log, "w") as f:
            f.write(LOG)
        args = ["--version", "9.9.9", "--root", self.root, "--changelog", log]
        self.assertEqual(docs_check.main(args), 0)
        self.assertEqual(docs_check.main(["--strict", *args]), 1)

    def test_strip_pointers(self):
        out = docs_check.strip_pointers(LOG)
        self.assertNotIn("[docs:", out)
        self.assertIn("- Documented in the guide.\n", out)
        self.assertIn("  a second line.\n", out)


if __name__ == "__main__":
    unittest.main()
