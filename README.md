<div align="center">

# HelioFITS Peek

### Know what you're looking at before you open a thing.

<img src="docs/before-after.png" width="860" alt="The same folder of FITS files, before and after HelioFITS: on the left every file is an identical generic document icon; on the right each is a distinct colored solar image" />

**Solar FITS files, previewable in Finder: in the right colors, with real coordinates.**

<a href="https://apps.apple.com/app/id6790952544"><img src="docs/badges/download-on-the-mac-app-store.svg" height="54" alt="Download on the Mac App Store" /></a>

Free and open source. Universal for Apple Silicon and Intel. No network access of any kind.

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23749496.svg)](https://doi.org/10.5281/zenodo.23749496)
[![Latest release](https://img.shields.io/github/v/release/GillySpace27/HelioFITS-Peek?style=flat)](https://github.com/GillySpace27/HelioFITS-Peek/releases)
[![Tests](https://img.shields.io/github/actions/workflow/status/GillySpace27/HelioFITS-Peek/tests.yml?branch=main&style=flat&label=tests)](https://github.com/GillySpace27/HelioFITS-Peek/actions/workflows/tests.yml)
[![License: BSD-2-Clause](https://img.shields.io/badge/License-BSD--2--Clause-blue.svg?style=flat)](LICENSE)
[![Platform: macOS 14.5+](https://img.shields.io/badge/platform-macOS%2014.5%2B-blue?style=flat)](https://apps.apple.com/app/id6790952544)

</div>

> **The HelioFITS suite**
> - [HelioFITS Peek](https://github.com/GillySpace27/HelioFITS-Peek): solar FITS thumbnails and previews in macOS Finder and Quick Look.
> - [HelioFITS Studio](https://github.com/GillySpace27/HelioFITS-Studio): a desktop viewer for coronagraph and wide-field solar imagery, forked from JHelioviewer.
> - [HelioFITS Suite](https://github.com/GillySpace27/HelioFITS-suite): how the programs fit together, with one DOI to cite them all.

---

Do you have a hundred directories of FITS files and no way to preview them
without launching a heavy application for each one? On the left above, every file
is the same grey icon; you can't tell an EUV frame from a magnetogram without
opening each one. On the right is the same folder with HelioFITS installed. That's
the whole idea.

**HelioFITS Peek teaches Finder to read solar FITS files.** Once it's installed, your
`.fits` files stop being rows of identical grey document icons and become what
they actually are: the Sun, rendered in the correct instrument colormap. Press
the spacebar on any of them and you get an interactive preview with pixel values,
helioprojective coordinates, region statistics, and multi-HDU blink comparison,
without opening anything. It is built by a solar physicist, for the archive already
sitting on your disk.

## What it does

<a id="three-ways-it-makes-finder-understand-fits"></a>

- **Thumbnails on every icon.** Each file is drawn in the colormap its header calls
  for, so a folder of solar data browses like a folder of photos.

  <img src="docs/colormaps.png" width="560" alt="Finder icon view of solar FITS files, each a distinct colormap"/>

- **Interactive previews from the spacebar.** Hover for pixel values and
  helioprojective coordinates, drag a box for region statistics, scroll to blink
  between HDUs. Limb, difference, stretch and the RHEF filter are one click each.

  <img src="docs/preview-quicklook.png" width="560" alt="A Quick Look preview of an AIA image with the pixel value and coordinate readout, the RHEF filter, and the Limb/Diff/Stretch controls"/>

- **Metadata in Get Info and Spotlight.** Telescope, instrument, wavelength,
  observation date and exposure become searchable.

  <img src="docs/spotlight-metadata.png" width="560" alt="A Finder Get Info panel showing telescope, instrument, wavelength and other FITS metadata"/>

- **A viewer, when you want more.** Double-click a file for the image above its full
  header. Export any HDU to PNG, copy a sunpy snippet, or play a folder as a movie.

  <img src="docs/viewer.png" width="560" alt="The HelioFITS viewer window showing an image above the full FITS header"/>

Every control and filter is described in [Features in detail](docs/features.md).
<a id="settings"></a>Folder pinning and the default HDU are in [Settings](docs/settings.md).
<a id="accessibility"></a>Keyboard and VoiceOver support is in [Accessibility](docs/accessibility.md).

## Install

> **Runs on any Mac**, Apple Silicon or Intel, with macOS 14.5 or later. It's a
> universal binary.

### [**Get it on the Mac App Store →**](https://apps.apple.com/app/id6790952544)

That's the whole install: it's free, it updates itself, and macOS registers the
Finder extensions for you. Then press the **spacebar** on any `.fits` file. (If a
thumbnail still looks generic at first, relaunch Finder or log out and back in;
macOS caches icons.)

<details>
<summary>If you can't use the App Store</summary>

Some managed and institutional Macs block it. The notarized build is also attached
to each [GitHub release](https://github.com/GillySpace27/HelioFITS-Peek/releases):
download the zip, unzip it, drag `HelioFITS.app` into `/Applications`, and launch it
once so the extensions register. It opens without security warnings, but it does
**not** self-update; watch the
[releases feed](https://github.com/GillySpace27/HelioFITS-Peek/releases.atom) for new
versions. The App Store is the supported channel; this is a fallback.

</details>

<a id="supported-instruments"></a>

## Supported data

AIA · HMI (line‑of‑sight magnetograms and synoptic B_r charts) · LASCO C2/C3 ·
SUVI · EIT · STEREO/SECCHI (EUVI, COR, HI) · PUNCH (including its polarized Stokes
cubes, a stack of polarization measurements in one file) · K‑Cor · TRACE · XRT ·
Solar Orbiter/EUI · Proba‑3/ASPIICS.
Instrument is recognized from `TELESCOP`/`INSTRUME`/`DETECTOR`; anything
unrecognized falls back to a sensible grayscale stretch. Missing one?
[Open an issue](https://github.com/GillySpace27/HelioFITS-Peek/issues); colormaps are
easy to add. `.fz` (fpack) and Rice‑compressed files work natively.

### Getting FITS files to try

The repo ships no data. Any solar `.fits` file works; free sources include
[SDO data](https://sdo.gsfc.nasa.gov/data/), the
[Virtual Solar Observatory](https://sdac.virtualsolar.org/),
[PUNCH](https://umbra.nascom.nasa.gov/punch/), and
[sunpy's Fido](https://docs.sunpy.org/en/stable/tutorial/acquiring_data/).

<a id="reporting-bugs"></a>

## Reporting problems

Open an issue: <https://github.com/GillySpace27/HelioFITS-Peek/issues>. Attaching (or
linking) a FITS file that reproduces the problem makes fixes much faster. If a
readout ever disagrees with what sunpy tells you, I especially want to know.

## Building from source

```sh
git clone https://github.com/GillySpace27/HelioFITS-Peek.git
cd HelioFITS-Peek
xcodebuild -project HelioFITS.xcodeproj -scheme HelioFITS -configuration Release \
  -destination 'platform=macOS,arch=arm64' build
```

The app is universal (Apple Silicon and Intel): the vendored CFITSIO library in
`HelioFITSCore/CFITSIO.xcframework` carries both Mac slices, and
`lipo -archs HelioFITSCore/CFITSIO.xcframework/macos-arm64_x86_64/libcfitsio.a`
prints `x86_64 arm64`. The core tests (the WCS math pinned against astropy ground
truth, colormaps, cubes, RHEF, the readout) live under
`HelioFITSCore/Tests/HelioFITSCoreTests/` and run headless with
`swift test --package-path HelioFITSCore`, without launching the app. Tests that need
the app (canvas, toolbar, stretch panel, header reader) live under `HelioFITSTests/`;
run them with the scheme's Test action, then
`./lsclean.sh`. `ship.sh` documents the notarized release flow and `RELEASING.md`
the full two-channel process. Contributors and coding agents start at `CLAUDE.md`;
`bash scripts/check.sh` runs the fast static checks.

<a id="command-line"></a>The renderer is also a small command-line tool, built from source only. See
[Command line](docs/command-line.md).

### iPhone and iPad (in development)

`HelioFITS-iOS/` holds an iPhone and iPad app that shares `HelioFITSCore` with the
Mac: thumbnails and Quick Look previews in the Files app, and an interactive
viewer. It is not on the App Store yet, keeps its own version number, and has
been tested in the Simulator only. Build it with:

```sh
xcodebuild -project HelioFITS-iOS/HelioFITS-iOS.xcodeproj -scheme HelioFITS \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Citing

If HelioFITS Peek helps your research, please cite it. Every release is archived
on Zenodo. The concept DOI, <https://doi.org/10.5281/zenodo.23749496>, always
resolves to the newest version. Version 1.5.0 is <https://doi.org/10.5281/zenodo.23749497>.
[CITATION.cff](CITATION.cff) has the details, and GitHub's "Cite this repository"
button turns it into APA or BibTeX.

```bibtex
@software{gilly_heliofits_peek,
  author    = {Gilly, Chris R.},
  title     = {{HelioFITS Peek}},
  year      = {2026},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.23749496},
  url       = {https://doi.org/10.5281/zenodo.23749496}
}
```

If you used the RHEF filter, please also cite Gilly & Cranmer (2025),
*Solar Physics* 300, 174, <https://doi.org/10.1007/s11207-025-02578-x>.

HelioFITS Peek is part of the HelioFITS suite, which has its own DOI:
<https://doi.org/10.5281/zenodo.23524598>.

## License and credits

[BSD 2‑Clause](LICENSE). Vendors [CFITSIO](https://heasarc.gsfc.nasa.gov/fitsio/)
by William Pence (NASA HEASARC); see
[its license](HelioFITSExtension/cfitsio/LICENSE). Instrument colormaps are the
standard [sunpy](https://sunpy.org) color tables.

Built by **Gilly**, heliophysics research scientist at
[NorthWest Research Associates](https://www.nwra.com) · [gilly.space](https://gilly.space).

### Privacy

HelioFITS collects nothing and has **no network entitlement**: the macOS sandbox
denies it all internet access, so nothing can leave your Mac. No accounts, no
analytics, no telemetry. See [PRIVACY.md](PRIVACY.md).
