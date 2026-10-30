# Spotlight import extension: W0 step 1 findings (2026-10-29)

Question: does macOS call a CoreSpotlight import extension (`CSImportExtension`,
extension point `com.apple.spotlight.import`) when Spotlight indexes a `.fits` file?

Answer on macOS 26.6.1 (25G76), Xcode 27.1: **not in normal indexing.** The extension
registers and can be run on demand, but the indexer never dispatched it. macOS 14.5 is
UNCHECKED (no 14.5 machine).

## What was built

A throwaway host app with one appex, built by hand with `clang` (no Xcode target), signed
"Apple Development" (team UB45PPC2JS) with only `com.apple.security.app-sandbox`. The
principal class subclasses `CSImportExtension`; `updateAttributes:forFileAtURL:error:`
logs its path with `os_log`, sets `title` and sets `com_gillyspace27_fits_instrume` through
`CSCustomAttributeKey`. `NSExtensionAttributes` copies Apple's own macOS
`PDFKit.framework/.../PDFImporter.appex`: `CSSupportedContentTypes` = `gov.nasa.gsfc.fits`.
Samples were copies of `HelioFITSTests/Fixtures/Real/aia_cutout.fits`.

## Evidence

- `pluginkit -m -v -p com.apple.spotlight.import` lists it beside
  `com.apple.PDFKit.PDFImporter`; `mdimport -e` lists it with
  `supportedFileTypes=(gov.nasa.gsfc.fits, ...)`. The indexer's `mdbulkimport` logs
  "Found 2 import extensions" and registers it with Background Task Management (it then
  shows in System Settings).
- On demand it runs: `mdimport -m -y gov.nasa.gsfc.fits -u file://.../g.fits` prints
  `kMDItemTitle = "W0 test title g.fits"`. The custom key never appears in that output.
- Normal indexing (copy into an indexed folder, `mdimport -i`, wait 90 to 120 s, `mdls`,
  `log show --predicate 'process == "W0Importer"'`), 5 trials: the extension was never
  called. `.fits` files got the legacy importer's attributes
  (`kMDItemTitle = "SDO/AIA 193angstrom"`, `com_gillyspace27_fits_instrume = "AIA_2"`),
  and `mdimport -t -d2` names `~/Library/Spotlight/FITSMetadataImporter.mdimporter`.
- Not only because the legacy importer wins: for `public.geometry-definition-format`
  (`.obj`), which `mdimport -t` reports "with no plugIn", the extension also was not called,
  with a fresh bundle id and after launching the (no-op) host once.
- Apple's own pair behaves the same: a PDF imports "with plugIn
  /System/Library/Spotlight/PDF.mdimporter", and `log show --last 3d --predicate
  'process == "PDFImporter"'` returned 0 lines.

## Not tested

- macOS 14.5; a host in `/Applications` or installed from the App Store; a full re-index
  (`mdimport -e` shows the flag `run-on-migration`); `mdimport -r` (would re-import every
  FITS file on the disk).
- A private UTI exported by the host: the indexer stored it as `dyn.*` although
  `UTType(filenameExtension:)` resolved it, so that route told nothing.
- Embedding in `HelioFITS.app`: skipped, since the indexer did not call the extension for a
  type no other importer claims.

Consistent with `FITSMetadataImporter/main.c:3-4`. Per the scope, the legacy importer stays
in the direct download and steps 2 to 5 do not start.
