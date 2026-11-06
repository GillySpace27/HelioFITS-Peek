#!/bin/bash
# Build + sign the legacy FITS .mdimporter CFPlugIn bundle. No install: the
# importer ships INSIDE HelioFITS.app/Contents/Library/Spotlight (embedded
# and re-signed by ../embed-importer.sh). That's the copy Spotlight discovers
# when the user launches the app (LaunchServices registers the bundle, and mds
# enumerates importers in registered apps' Contents/Library/Spotlight).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_NAME="FITSMetadataImporter.mdimporter"
BUILD="$SRC/build"
BUNDLE="$BUILD/$BUNDLE_NAME"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

# mdworker_shared will load a Developer ID / Apple-team-signed importer; a bare
# ad-hoc one is discovered but may be refused. Fall back to ad-hoc if no cert.
SIGN_ID="${SIGN_ID:-Developer ID Application: CHRISTOPHER RAYMOND GILBERT (UB45PPC2JS)}"
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    echo "note: '$SIGN_ID' not found; signing ad-hoc"
    SIGN_ID="-"; SIGN_OPTS=()
else
    SIGN_OPTS=(--options runtime --timestamp=none)
fi

rm -rf "$BUILD"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources/English.lproj"

# The processing-record half is Swift: hfrec_import.swift plus HelioFITSCore's two Foundation-only
# record files, so the importer reads a record exactly as Quick Look and the app do. swiftc links
# each architecture (it brings the Swift runtime, which macOS 12 has in /usr/lib/swift), lipo joins them.
CORE="$SRC/../HelioFITSCore/Sources/HelioFITSCore"
OBJ="$BUILD/obj"
mkdir -p "$OBJ"
for ARCH in arm64 x86_64; do
    T="$ARCH-apple-macos12.0"
    clang -c -target "$T" -isysroot "$SDK" -O2 -Wall "$SRC/main.c" -o "$OBJ/main.$ARCH.o"
    clang -c -target "$T" -isysroot "$SDK" -O2 -Wall "$SRC/fits_header.c" -o "$OBJ/fits_header.$ARCH.o"
    swiftc -target "$T" -sdk "$SDK" -swift-version 5 -parse-as-library -O -wmo -module-name HFRecImporter \
        -emit-object -o "$OBJ/hfrec.$ARCH.o" \
        "$SRC/hfrec_import.swift" "$CORE/HFRecordJSON.swift" "$CORE/HFRecordReport.swift"
    swiftc -target "$T" -sdk "$SDK" -emit-executable -Xlinker -bundle -o "$OBJ/FITSMetadataImporter.$ARCH" \
        "$OBJ/main.$ARCH.o" "$OBJ/fits_header.$ARCH.o" "$OBJ/hfrec.$ARCH.o" \
        -framework CoreFoundation -framework CoreServices
done
lipo -create -output "$BUNDLE/Contents/MacOS/FITSMetadataImporter" \
    "$OBJ/FITSMetadataImporter.arm64" "$OBJ/FITSMetadataImporter.x86_64"
rm -rf "$OBJ"

cp "$SRC/Info.plist"      "$BUNDLE/Contents/Info.plist"
cp "$SRC/schema.xml"      "$BUNDLE/Contents/Resources/schema.xml"
cp "$SRC/schema.strings"  "$BUNDLE/Contents/Resources/English.lproj/schema.strings"

# ${SIGN_OPTS[@]+...} keeps an empty array legal under set -u (bash 3.2 on macOS and CI runners)
codesign --force ${SIGN_OPTS[@]+"${SIGN_OPTS[@]}"} --sign "$SIGN_ID" "$BUNDLE"
echo "Built: $BUNDLE"
