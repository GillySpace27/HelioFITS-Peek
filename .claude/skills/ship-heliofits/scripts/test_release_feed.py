#!/usr/bin/env python3
"""Tests for release_status.py's family-feed hook (suite SU-11).

Run: python3 .claude/skills/ship-heliofits/scripts/test_release_feed.py
No App Store Connect, no network: the writer is replaced by a recorder.
"""
import os
import sys
import tempfile
import types
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import release_status as rs  # noqa: E402

D = chr(0x2014)
CHANGELOG = f"""# Changelog

## [Unreleased]

## [1.4.0] - 2026-09-27

Opening the app now opens the viewer, the viewer knows where its file lives {D} and Copy Python
hands you the array.

### Added

- **Show in Finder.** Something.
"""


class FeedNotes(unittest.TestCase):
    def test_intro_paragraph_with_the_dash_replaced(self):
        got = rs.feed_notes(CHANGELOG, "1.4.0", "fallback")
        self.assertEqual(got, "Opening the app now opens the viewer, the viewer knows where its file lives ; and Copy "
                              "Python hands you the array.")

    def test_unknown_version_uses_the_fallback(self):
        self.assertEqual(rs.feed_notes(CHANGELOG, "9.9.9", "HelioFITS 9.9.9 (build 1)"), "HelioFITS 9.9.9 (build 1)")


class RecordRelease(unittest.TestCase):
    def site(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        feed = os.path.join(tmp.name, "heliosoftware", "feed")
        os.makedirs(feed)
        for n in ("append_record.py", "build_feed.py"):
            open(os.path.join(feed, n), "w").close()
        return tmp.name

    def test_not_ready_for_sale_writes_nothing(self):
        def boom(*a, **k):
            raise AssertionError("the writer must not run before READY_FOR_SALE")
        ok, msg = rs.record_release({"released": False, "_asc_state_raw": "WAITING_FOR_REVIEW"}, "1.4.0", "10",
                                    CHANGELOG, "2026-10-02", self.site(), run=boom)
        self.assertTrue(ok)
        self.assertIn("skipped, App Store state is WAITING_FOR_REVIEW, not READY_FOR_SALE", msg)

    def test_released_calls_the_writer_with_the_store_channel(self):
        calls = []

        def fake(argv, **kw):
            calls.append(argv)
            if "--notes-file" in argv:
                with open(argv[argv.index("--notes-file") + 1], encoding="utf-8") as f:
                    calls.append(f.read())
            return types.SimpleNamespace(returncode=0, stdout="", stderr="")
        ok, msg = rs.record_release({"released": True}, "1.4.0", "10", CHANGELOG, "2026-10-02", self.site(), run=fake)
        self.assertTrue(ok, msg)
        argv = calls[0]
        for flag, value in (("--product", "heliofits"), ("--version", "1.4.0"), ("--build", "10"),
                            ("--date", "2026-10-02"), ("--channel", "mac-app-store"),
                            ("--url", "https://apps.apple.com/app/id6790952544")):
            self.assertEqual(argv[argv.index(flag) + 1], value)
        self.assertNotIn("--asset", argv)
        self.assertTrue(calls[1].startswith("Opening the app now opens the viewer"))
        self.assertTrue(any("build_feed.py" in c[1] for c in calls if isinstance(c, list)))

    def test_doi_is_passed_to_the_writer_only_when_given(self):
        calls = []

        def fake(argv, **kw):
            calls.append(argv)
            return types.SimpleNamespace(returncode=0, stdout="", stderr="")
        for doi in ("", "10.5281/zenodo.23749497"):
            calls.clear()
            ok, msg = rs.record_release({"released": True}, "1.4.0", "10", CHANGELOG, "2026-10-02", self.site(),
                                        run=fake, doi=doi)
            self.assertTrue(ok, msg)
            self.assertEqual("--doi" in calls[0], bool(doi))
            if doi:
                self.assertEqual(calls[0][calls[0].index("--doi") + 1], doi)

    def test_check_doi_accepts_zenodo_and_refuses_anything_else(self):
        self.assertEqual(rs.check_doi(""), "")
        self.assertEqual(rs.check_doi("10.5281/zenodo.23749497"), "10.5281/zenodo.23749497")
        for bad in ("10.5281/zenodo.", "10.5281/zenodo.12a", "https://doi.org/10.5281/zenodo.1", "10.1007/s11207-025-02578-x",
                    " 10.5281/zenodo.1"):
            with self.assertRaises(ValueError, msg=bad):
                rs.check_doi(bad)

    def test_duplicate_is_not_an_error_and_a_writer_failure_is(self):
        rc = {"n": 3}

        def fake(argv, **kw):
            return types.SimpleNamespace(returncode=rc["n"], stdout="", stderr="boom\n")
        ok, msg = rs.record_release({"released": True}, "1.4.0", "10", CHANGELOG, "2026-10-02", self.site(), run=fake)
        self.assertTrue(ok)
        self.assertIn("already", msg)
        rc["n"] = 1
        ok, msg = rs.record_release({"released": True}, "1.4.0", "10", CHANGELOG, "2026-10-02", self.site(), run=fake)
        self.assertFalse(ok)
        self.assertIn("writer failed (exit 1)", msg)

    def test_missing_writer_is_reported(self):
        ok, msg = rs.record_release({"released": True}, "1.4.0", "10", CHANGELOG, "2026-10-02", "/nonexistent-site",
                                    run=lambda *a, **k: None)
        self.assertFalse(ok)
        self.assertIn("append_record.py not found", msg)


if __name__ == "__main__":
    unittest.main()
