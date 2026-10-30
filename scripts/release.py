#!/usr/bin/env python3
"""The Mac App Store lane as one script (HF-21): archive, verify, upload, prepare, submit, release.

Every step is idempotent and refuses rather than overwrites (nothing is deleted). Steps that reach
Apple or the public (upload, submit, release) need `--confirm "<action> <version> build <build>"`
(gates.py), so a yes for build N cannot carry to build N+1. `submit` and `release` stop after the
gate: the App Store Connect write is not implemented here and stays Gilly's step (UNCHECKED).
Nothing here has run against App Store Connect or a real archive: UNCHECKED until Gilly's first run.
RELEASING.md is authoritative.
"""
import argparse
import datetime
import os
import plistlib
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import gates  # noqa: E402

ASC_API = os.path.join(ROOT, ".claude", "skills", "ship-heliofits", "scripts", "asc_api.py")
EXPORT_OPTIONS = os.path.join(HERE, "ExportOptions-AppStore.plist")
IMPORTER = os.path.join("Contents", "Library", "Spotlight", "FITSMetadataImporter.mdimporter")
WANT_ARCHS = {"arm64", "x86_64"}


def xcconfig(root=ROOT):
    """(version, build) from Config/Version.xcconfig; exits 2 when it cannot be read."""
    try:
        text = open(os.path.join(root, "Config", "Version.xcconfig"), encoding="utf-8").read()
    except OSError:
        sys.exit("Config/Version.xcconfig is missing")
    v = re.findall(r"^MARKETING_VERSION = (\S+)$", text, re.M)
    b = re.findall(r"^CURRENT_PROJECT_VERSION = (\S+)$", text, re.M)
    if len(v) != 1 or len(b) != 1:
        sys.exit("Config/Version.xcconfig does not hold exactly one version and one build")
    return v[0], b[0]


def archive_path(version, build):
    return os.path.join("build", f"HelioFITS-{version}-b{build}.xcarchive")


def archive_cmd(version, build):
    """The store archive: Automatic signing (the project's own), universal, no DIRECT_DOWNLOAD."""
    return ["xcodebuild", "-project", "HelioFITS.xcodeproj", "-scheme", "HelioFITS",
            "-configuration", "Release", "-destination", "generic/platform=macOS",
            "ARCHS=arm64 x86_64", "ONLY_ACTIVE_ARCH=NO", "-archivePath", archive_path(version, build), "archive"]


def asc_credentials(path=ASC_API):
    """(key_id, issuer_id, key_path) read as text from asc_api.py; the key itself is never opened."""
    t = open(path, encoding="utf-8").read()
    kid = re.search(r'^KEY_ID = "([^"]+)"', t, re.M).group(1)
    iss = re.search(r'^ISSUER_ID = "([^"]+)"', t, re.M).group(1)
    return kid, iss, os.path.expanduser(f"~/.claude/secrets/appstoreconnect/AuthKey_{kid}.p8")


def upload_cmd(version, build, creds):
    kid, iss, key = creds
    return ["xcodebuild", "-exportArchive", "-archivePath", archive_path(version, build),
            "-exportOptionsPlist", EXPORT_OPTIONS, "-allowProvisioningUpdates",
            "-authenticationKeyPath", key, "-authenticationKeyID", kid, "-authenticationKeyIssuerID", iss]


def lipo_archs(binary):
    """Set of architectures, or None when lipo cannot say (not macOS)."""
    try:
        r = subprocess.run(["lipo", "-archs", binary], capture_output=True, text=True)
    except FileNotFoundError:
        return None
    return set(r.stdout.split()) if r.returncode == 0 else None


def signing_authority(app, run=subprocess.run):
    """The leaf signing authority of an app, from `codesign -dvv`, or None (ad hoc, unsigned, no codesign)."""
    try:
        r = run(["codesign", "-dvv", app], capture_output=True, text=True)
    except FileNotFoundError:
        return None
    m = re.search(r"^Authority=(.+)$", r.stderr, re.M)
    return m.group(1) if m else None


def embed_cmd(root, app):
    """embed-importer.sh cd's to its own folder, so the app path must be absolute. SIGN_ID goes in the env."""
    return [os.path.join(root, "embed-importer.sh"), app]


def importer_state(path):
    """(signed, has_entitlements) of the importer bundle; (None, None) when codesign cannot be run."""
    try:
        v = subprocess.run(["codesign", "--verify", "--strict", path], capture_output=True)
        e = subprocess.run(["codesign", "-d", "--entitlements", ":-", path], capture_output=True)
    except FileNotFoundError:
        return None, None
    return v.returncode == 0, bool(e.stdout.strip())


def verify_app(app, version, build, archs=lipo_archs, importer=importer_state):
    """(problems, unchecked). Reads only. The MAS app must carry the Spotlight importer, signed, with no entitlements.

    A plain Xcode archive does not (embed-importer.sh adds it); `release.py archive` does.
    """
    problems, unchecked = [], []
    try:
        info = plistlib.load(open(os.path.join(app, "Contents", "Info.plist"), "rb"))
    except (OSError, plistlib.InvalidFileException) as e:
        return [f"cannot read {app}/Contents/Info.plist: {e}"], unchecked
    imp = os.path.join(app, IMPORTER)
    if not os.path.isdir(imp):
        problems.append(f"{IMPORTER} is missing: the store build carries the importer "
                        "(release.py archive embeds it; run embed-importer.sh on a hand-made archive)")
    else:
        signed, entitled = importer(imp)
        if signed is None:
            unchecked.append("importer signature: codesign could not be run on " + imp)
        else:
            if not signed:
                problems.append("the importer is not signed (codesign --verify --strict fails)")
            if entitled:
                problems.append("the importer carries entitlements; it must have none")
    if (info.get("CFBundleShortVersionString"), info.get("CFBundleVersion")) != (version, build):
        problems.append("app says %s build %s, Config/Version.xcconfig says %s build %s"
                        % (info.get("CFBundleShortVersionString"), info.get("CFBundleVersion"), version, build))
    exe = os.path.join(app, "Contents", "MacOS", info.get("CFBundleExecutable", "HelioFITS"))
    got = archs(exe) if os.path.exists(exe) else None
    if got is None:
        unchecked.append("architectures: lipo could not read " + exe)
    elif got != WANT_ARCHS:
        problems.append("architectures are %s, want %s" % (" ".join(sorted(got)), " ".join(sorted(WANT_ARCHS))))
    return problems, unchecked


def already_logged(action, version, build, result="ok"):
    path = os.path.expanduser(os.environ.get(gates.LOG_ENV) or gates.DEFAULT_LOG)
    try:
        want = [action, version, str(build), result]
        return any(line.rstrip("\n").split("\t")[1:] == want for line in open(path, encoding="utf-8"))
    except OSError:
        return False


def main(argv=None, root=ROOT):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("step", choices=["archive", "verify", "upload", "prepare", "submit", "release"])
    p.add_argument("--platform", default="MAC_OS", choices=["MAC_OS", "IOS"])
    p.add_argument("--confirm", default=None, help='typed gate text, e.g. "upload 1.4.0 build 10"')
    p.add_argument("--dry-run", action="store_true", help="print the command, run nothing")
    a = p.parse_args(argv)
    if a.platform != "MAC_OS":
        print("UNCHECKED: only the Mac lane is scripted; the iOS lane is not built yet", file=sys.stderr)
        return 4
    version, build = xcconfig(root)
    if a.step == "archive":
        dest = archive_path(version, build)
        if os.path.exists(os.path.join(root, dest)):
            print(f"{dest} exists; nothing to do")
            return 0
        cmd = archive_cmd(version, build)
        print(" ".join(cmd))
        if a.dry_run:
            print("then: SIGN_ID=<the archive app's signing authority> embed-importer.sh <archived app>")
            return 0
        rc = subprocess.run(cmd, cwd=root).returncode
        if rc:
            return rc
        # The store build carries the importer (RELEASING.md step 6); Xcode's archive does not. Same
        # identity as the archived app, so the importer and the re-sealed app match; export re-signs both.
        app = os.path.join(root, dest, "Products", "Applications", "HelioFITS.app")
        sign_id = signing_authority(app)
        if not sign_id:
            print(f"FAIL: cannot read the signing authority of {app}; importer not embedded", file=sys.stderr)
            return 1
        return subprocess.run(embed_cmd(root, app), cwd=root, env=dict(os.environ, SIGN_ID=sign_id)).returncode
    if a.step in ("verify", "prepare"):
        app = os.path.join(root, archive_path(version, build), "Products", "Applications", "HelioFITS.app")
        problems, unchecked = verify_app(app, version, build)
        for u in unchecked:
            print("UNCHECKED:", u)
        for q in problems:
            print("FAIL:", q)
        if a.step == "prepare" and not problems:
            r = subprocess.run([sys.executable, os.path.join(HERE, "release-notes.py"), version, "--check-whats-new"], cwd=root)
            problems = ["release notes lint failed"] if r.returncode else []
        print("verify: " + ("FAIL" if problems else "ok" if not unchecked else "ok with UNCHECKED"))
        return 1 if problems else 0
    gates.require_confirm(a.confirm, gates.expected_text(a.step, version, build))
    if a.step == "upload":
        if already_logged("upload", version, build):
            print(f"upload {version} build {build} is already in the state log; nothing to do")
            return 0
        cmd = upload_cmd(version, build, asc_credentials(os.path.join(root, os.path.relpath(ASC_API, ROOT))))
        print(" ".join(cmd))
        if a.dry_run:
            return 0
        rc = subprocess.run(cmd, cwd=root).returncode
        gates.append_state_log("upload", version, build, "ok" if rc == 0 else f"failed {rc}")
        return rc
    gates.append_state_log(a.step, version, build, "gate passed; ASC write not implemented")
    print(f"UNCHECKED: {a.step} is Gilly's step in App Store Connect; this script only holds the gate")
    return 4


if __name__ == "__main__":
    sys.exit(main())
