# Features in detail

Back to the [README](../README.md).

HelioFITS is three small system extensions plus a viewer. Each lights up a
different part of macOS, and they all work together: no app window required.

## Thumbnails, on every icon

<img src="colormaps.png" width="640" alt="Finder icon view of solar FITS files, each a distinct colormap"/>

The thumbnail extension renders each FITS file's default image in the colormap its
header calls for: AIA gold, a diverging red/blue magnetogram, a LASCO coronagraph,
a PUNCH heliospheric mosaic. Icon view, gallery view, the icons in list and column
views: all of them show the real image. A directory of solar data becomes browsable
the way a folder of photos is.

## Interactive previews, from the spacebar

<table>
<tr>
<td width="50%"><img src="preview-quicklook.png" alt="A Quick Look preview of an AIA image with the pixel value and coordinate readout, the RHEF filter, and the Limb/Diff/Stretch controls"/></td>
<td width="50%"><img src="interactive-stats.png" alt="The preview with the solar limb drawn and a region selected for statistics"/></td>
</tr>
</table>

Select a `.fits` file and press the **spacebar** (the standard macOS Quick Look)
and HelioFITS draws the image live. This is not a static picture; it's fully
interactive in the spacebar panel and gallery view. (Finder's narrow column pane
gives you scroll‑to‑blink; press space there for the full controls.)

- **Hover** any pixel to read its value together with its *helioprojective*
  coordinate: **Tx, Ty**, the arcsecond offset east/west and north/south from the
  center of the Sun's disk. The readout also gives its distance from disk center in solar radii (**R☉**).
- **Drag a box** for region statistics (mean, median, σ, sum, min, max) computed
  at full native resolution, with a live histogram.
- **Scroll** (or press **↑/↓**) to blink between HDUs (a FITS file's stacked image
  extensions), pixel‑registered, to compare processing levels or filters.
- **Toggle** the solar limb, a running difference between HDUs, a live stretch
  (percentile clip, gamma, log), or the **RHEF** filter, a radial histogram
  equalization ([Gilly & Cranmer 2025](https://doi.org/10.1007/s11207-025-02578-x))
  that flattens the steep coronal falloff to reveal faint off‑limb structure at
  every height. None of it touches the file.
- Pick **MGN** (multi‑scale Gaussian normalization, Morgan & Druckmüller 2014, with
  sunkit‑image's default widths) or **WOW** (wavelet whitening after Auchère et al.
  2023, in HelioFITS's own reading; not checked against the authors' `watroo` package)
  to bring out structure at every scale. **Swipe** puts the unfiltered image left of a
  divider and the filter right of it; drag it, or press **⌥←/⌥→**.
  Every filter runs on a grid of at most 1024 px a side; MGN and WOW divide their
  widths by that decimation, so the preview approximates the full‑resolution filter.
  Filter output is a visualization, not a calibrated radiance; the readout and the
  statistics always report the file's raw values. Copy Python reproduces each filter.
- **⌥‑scroll** (or **⌘ +/−/0**) to zoom.

The coordinate math is computed the same way astropy and sunpy do it, and verified
against astropy pixel‑for‑pixel in the test suite, so you can trust the numbers. (For
the experts: real spherical deprojection for TAN/ARC/SIN/CAR, honoring CUNIT, the
PC/CD matrices, and CROTA2.) When it meets a projection it can't handle, it shows no
coordinate rather than a plausible wrong one.

## Metadata, in Get Info and Spotlight

<img src="spotlight-metadata.png" width="640" alt="A Finder Get Info panel showing telescope, instrument, wavelength and other FITS metadata"/>

The Spotlight importer pulls the header fields you actually search on (telescope,
instrument, wavelength, observation date, exposure, dimensions, HDU count) into
Finder's **Get Info** panel and makes them Spotlight‑searchable. You can find every
171 Å frame on your disk with a query.

## And a viewer, when you want more

<img src="viewer.png" width="640" alt="The HelioFITS viewer window showing an image above the full FITS header"/>

Double‑click a FITS file to open the built‑in viewer: the interactive image on top,
the complete FITS header beneath. From here you can **export any HDU to PNG** for a
slide or a paper, or **copy a ready‑to‑run sunpy snippet** that loads exactly the
HDU you're looking at: a one‑click bridge back to Python.

**Play** runs a file's layers as a looping movie. Open a **folder** (File ▸ Open…)
and its FITS files become one: frames in DATE‑OBS order, a scrubber, a frame rate,
and Diff as a running difference between neighbouring files, taken at full
resolution. Nothing plays until you press Play.
