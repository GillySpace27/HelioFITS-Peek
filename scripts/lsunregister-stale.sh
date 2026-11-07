#!/bin/bash
# Unregister every Launch Services copy of HelioFITS Peek that is not the installed one in /Applications:
# the archive's DerivedData intermediate, backups made with ditto, the Trash. A stale record of such a copy
# once made the thumbnail service pick it for .hfrec, fail to launch it ("not found in LS database") and
# draw a generic icon (2026-11-06). xcodebuild archive moves the intermediate into the .xcarchive, so the
# path is gone from disk but still in the database: read the paths from the dump, never glob the disk.
# Never fatal. LSREGISTER overrides the tool (for the test).
LSREG="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}"
"$LSREG" -dump 2>/dev/null \
  | sed -n 's/^path: *//p; ' | sed 's/ (0x[0-9a-f]*)$//' \
  | grep -E '/HelioFITS Peek[^/]*\.app$' | grep -v '^/Applications/' | sort -u \
  | while IFS= read -r app; do
      "$LSREG" -u "$app" >/dev/null 2>&1 || true
      echo "==> unregistered $app"
    done
exit 0
