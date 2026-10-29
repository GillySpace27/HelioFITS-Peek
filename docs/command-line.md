# Command line

Back to the [README](../README.md).

The renderer behind the thumbnails and previews is also a small command-line
tool, for scripts and SSH sessions. It is built from source only; it is not part
of the App Store app or the GitHub zip.

```sh
swift build -c release --package-path HelioFITSCore
HelioFITSCore/.build/release/heliofits --header sun.fits
HelioFITSCore/.build/release/heliofits --info sun.fits
HelioFITSCore/.build/release/heliofits --export sun.fits --hdu 1 --max-side 2048 --out sun.png
```

`--hdu` defaults to the first image HDU (`-1`; `-2` is the last), `--plane`
picks a plane of a data cube, and `--max-side` caps the longest side of the PNG.
The tool makes no network calls. Exit status is 0 on success, 1 when the file
cannot be read or rendered, and 2 on a usage error.
