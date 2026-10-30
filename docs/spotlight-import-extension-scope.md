# Spotlight: replace the legacy .mdimporter with a Spotlight import extension

Scoped 2026-10-29 in the "Product comparison and deployment table" session. Gilly
approved the plan. Nothing has been built or changed yet.

## Why

The legacy importer (`FITSMetadataImporter/`, a C CFPlugIn `.mdimporter`) can only
ship in the Developer ID build: `embed-importer.sh` puts it in
`Contents/Library/Spotlight`, and the Mac App Store build must not contain it
(CLAUDE.md, RELEASING.md, the ship skill). So App Store users get no metadata in
Get Info or Spotlight.

CoreSpotlight's `CSImportExtension` is an ordinary sandboxed app extension
(extension point `com.apple.spotlight.import`), which in principle can ship in the
App Store build too.

## Checked facts

- In the macOS 27 SDK's `CSImportExtension.h`: `API_AVAILABLE(macos(12.0), ios(15.0), visionos(1.0))`.
  The method to implement is `updateAttributes:forFileAtURL:error:`.
- Xcode ships a "Spotlight Import Extension" template for **iOS and visionOS only, not macOS**.
- All 10 standard fields `main.c` writes have matching `CSSearchableItemAttributeSet`
  properties: title, contentDescription, keywords, pixelWidth, pixelHeight,
  bitsPerSample, acquisitionMake, acquisitionModel, exposureTime, contentCreationDate.
- The 7 custom attributes in `schema.xml` (`com_gillyspace27_fits_wavelnth`,
  `_instrume`, `_telescop`, `_dateobs`, `_exptime`, `_nhdus`, `_resolution`) can
  be declared with `CSCustomAttributeKey`.
- There is no automated importer test in the repo today.

## Unverified (the test build answers these)

1. **The blocker:** does macOS actually call an import extension for an arbitrary
   `.fits` file in Finder? The missing macOS template is the reason to doubt it.
2. Do `CSCustomAttributeKey` fields appear in Get Info and work as Spotlight
   search terms, the way `schema.xml` makes them do now?
3. Does App Review accept the extension in a Mac app?
4. Which one wins while the old importer and the new extension are both installed?
5. Whether the iOS app (same purchase) gets anything from it.

## Plan (nothing is deleted until step 3 passes)

1. **Test build, 2–4 h (estimate), on a branch.** A minimal extension target for
   `gov.nasa.gsfc.fits` that sets only `title` and one custom key. Check it with
   `pluginkit -m -p com.apple.spotlight.import`, then `mdimport` and `mdls` on a
   sample file, on macOS 14.5 and on the current macOS.
   If macOS ignores it, stop here: the old importer stays in the direct download
   and nothing is lost.
2. **Port, about 1 day (estimate).** Link `fits_header.c/.h` into the extension
   unchanged (it's the fuzz-tested part). Rewrite only the field mapping in
   `main.c` (about 100 lines) as `updateAttributes`, writing the same 17 fields.
3. **Compare, about half a day (estimate).** Put both in the Developer ID build and
   diff `mdls` output from old and new on the same set of FITS files. Keep this as
   the importer's first automated test.
4. **Retire the old importer.** Remove `FITSMetadataImporter/` and
   `embed-importer.sh`, and the "no Spotlight importer in the store build" checks in
   CLAUDE.md, RELEASING.md and `.claude/skills/ship-heliofits/SKILL.md`.
5. **Update store copy.** STORE.md ("The Mac App Store build has no Spotlight
   importer") and RELEASING.md's prepared App Review response (which says not to
   mention the importer) both change once the store build has the extension. So
   does README section 3, which now applies to both channels.
