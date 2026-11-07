#!/bin/bash
# scripts/lsunregister-stale.sh against a stubbed lsregister: it must unregister the copies outside
# /Applications (including one whose file is gone) and leave the installed app and its extensions alone.
set -u
cd "$(dirname "$0")"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cat > "$T/lsreg" <<EOS
#!/bin/bash
if [ "\$1" = "-dump" ]; then
cat <<EOD
path:                       /Applications/HelioFITS Peek.app (0x1)
path:                       /Applications/HelioFITS Peek.app/Contents/PlugIns/HelioFITSThumbnail.appex (0x2)
path:                       /Users/x/.Trash/HelioFITS Peek.app (0x3)
path:                       /Users/x/Documents/b/HelioFITS Peek-1.5.2-build2.app (0x4)
path:                       /Users/x/Library/Developer/Xcode/DerivedData/HelioFITS-abc/Build/Intermediates.noindex/ArchiveIntermediates/HelioFITS/InstallationBuildProductsLocation/Applications/HelioFITS Peek.app (0x5)
path:                       /Applications/Other.app (0x6)
EOD
else echo "\$@" >> "$T/calls"; fi
EOS
chmod +x "$T/lsreg"
LSREGISTER="$T/lsreg" ./lsunregister-stale.sh > "$T/out"
n=$(grep -c '^-u ' "$T/calls")
[ "$n" = 3 ] || { echo "FAIL: expected 3 unregisters, got $n"; cat "$T/calls"; exit 1; }
grep -q '^-u /Applications' "$T/calls" && { echo "FAIL: touched /Applications"; exit 1; }
grep -q 'ArchiveIntermediates' "$T/calls" && grep -q '\.Trash' "$T/calls" && grep -q 'build2' "$T/calls" || { echo "FAIL: missing copy"; exit 1; }
echo "ok lsunregister-stale"
