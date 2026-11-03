#!/usr/bin/env python3
"""Docs reconcile check (DOCS-3; ported from HelioFITS Studio's DOCS-1): every change in a changelog
section says where it is documented.

  docs_check.py                      check the section for MARKETING_VERSION; warn only, exit 0
  docs_check.py --strict             the same, exit 1 on any problem
  docs_check.py --version 1.5.1      check another version's section
  docs_check.py --changelog F --root D --since TAG    (tests and other repositories)

Each top-level bullet ("- " or "* " at the start of a line) in the section ends with a pointer:

  - What changed. [docs: manual/quick-look.md, README.md#settings]
  - An internal fix nobody reads about. [docs: none]

A pointer names one or more paths relative to the repository root (an "#anchor" is allowed and not
checked). A named path must exist and, when the previous release tag is known, must differ from that
tag, so a change cannot point at a page nobody touched. The previous tag is the newest tag matching
v[0-9]* reachable from HEAD, other than v<version>-build.N; with no tag (a shallow clone) that part
prints SKIP. Every place that shows the changelog to people strips the pointers (strip_pointers here,
release-notes.py, build_manual_refs.py).
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POINTER = re.compile(r"\s*\[docs:\s*([^\]]*)\]\s*$")


def strip_pointers(text):
    """The text with every trailing [docs: ...] pointer removed, line by line."""
    return "\n".join(POINTER.sub("", line) for line in text.split("\n"))


def section(changelog, version):
    """Lines of the "## " section whose heading names `version` ("## [1.5.1] - date"), or None."""
    word = re.compile(r"(?<![\w.])" + re.escape(version) + r"(?![\w.])")
    out = None
    for line in changelog.split("\n"):
        if line.startswith("## "):
            if out is not None:
                break
            if word.search(line):
                out = []
        elif out is not None:
            out.append(line)
    return out


def bullets(lines):
    """Top-level bullets, each joined with its continuation lines (indented or not, up to a blank)."""
    items, cur = [], None
    for line in lines:
        if line.startswith(("- ", "* ")):
            if cur is not None:
                items.append(cur)
            cur = line[2:]
        elif cur is not None and line.strip() and not line.startswith("#"):
            if line.lstrip().startswith(("- ", "* ")):
                continue  # a nested bullet belongs to its parent; the parent carries the pointer
            cur += " " + line.strip()
        elif cur is not None:
            items.append(cur)
            cur = None
    if cur is not None:
        items.append(cur)
    return items


def previous_tag(root, version):
    """The newest v* tag reachable from HEAD other than v<version>-build.N (a re-run after tagging)."""
    try:
        r = subprocess.run(["git", "-C", root, "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*",
                            "--exclude", f"v{version}-*", "--exclude", f"v{version}"],
                           capture_output=True, text=True, check=False)
    except OSError:
        return None
    return r.stdout.strip() or None


def changed_since(root, tag, path):
    r = subprocess.run(["git", "-C", root, "diff", "--quiet", tag, "--", path],
                       capture_output=True, text=True, check=False)
    return r.returncode == 1


def check(changelog, version, root, since):
    """(problems, notes): problems are what --strict fails on."""
    lines = section(changelog, version)
    if lines is None:
        return [f"changelog has no '## ' section naming {version}"], []
    problems, notes = [], []
    if since is None:
        notes.append("SKIP: no previous v* tag found, so 'changed since the last release' is not checked")
    for item in bullets(lines):
        label = item[:70] + ("..." if len(item) > 70 else "")
        m = POINTER.search(item)
        if not m:
            problems.append(f"no [docs: ...] pointer: {label}")
            continue
        targets = [t.strip() for t in m.group(1).split(",") if t.strip()]
        if not targets:
            problems.append(f"empty [docs: ] pointer: {label}")
        if targets == ["none"]:
            continue
        for t in targets:
            path = t.split("#", 1)[0]
            if path == "none":
                problems.append(f"'none' mixed with paths: {label}")
            elif not os.path.exists(os.path.join(root, path)):
                problems.append(f"{path} does not exist: {label}")
            elif since is not None and not changed_since(root, since, path):
                problems.append(f"{path} unchanged since {since}: {label}")
    return problems, notes


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--strict", action="store_true", help="exit 1 on any problem (default: warn, exit 0)")
    ap.add_argument("--version", help="the section to check (default: MARKETING_VERSION in Config/Version.xcconfig)")
    ap.add_argument("--changelog", default=None, help="default: <root>/CHANGELOG.md")
    ap.add_argument("--root", default=ROOT, help="repository root (default: this repository)")
    ap.add_argument("--since", default=None, help="previous release tag (default: git describe)")
    a = ap.parse_args(argv)
    version = a.version
    if version is None:
        with open(os.path.join(a.root, "Config", "Version.xcconfig"), encoding="utf-8") as f:
            version = re.search(r"^MARKETING_VERSION\s*=\s*(\S+)", f.read(), re.M).group(1)
    with open(a.changelog or os.path.join(a.root, "CHANGELOG.md"), encoding="utf-8") as f:
        text = f.read()
    since = a.since or previous_tag(a.root, version)
    problems, notes = check(text, version, a.root, since)
    for n in notes:
        print(f"docs-check: {n}")
    word = "FAIL" if a.strict else "WARN"
    for p in problems:
        print(f"docs-check: {word}: {p}")
    print(f"docs-check: {version}: {len(problems)} problem(s){'' if a.strict or not problems else ' (warn only)'}")
    return 1 if a.strict and problems else 0


if __name__ == "__main__":
    sys.exit(main())
