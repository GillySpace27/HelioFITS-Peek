# Stretch, filters and the colorbar

Everything on this page changes only how the image is drawn. The readout and the region statistics
always report the file's raw values, and nothing is written to the file.

## The stretch panel

**Stretch** opens a panel over the image:

Low and High
: Clip the darkest pixels to black and the brightest to white, by percentile (0.5 % and 99.5 % by
  default). The sliders are logarithmic in distance from their end of the distribution, because a
  solar image's brightness has a long tail: High gives fine control near 100 %, and Low reaches as
  far as the median, enough to clip the quiet Sun away and see off-limb structure.

Gamma
: Below 1 brightens faint structure, above 1 darkens it. The default is 0.5, except for HMI
  magnetograms, which start linear (1.0).

log
: Logarithmic scaling, which brings out faint off-limb structure.

Histogram, Min and Max
: A histogram of the whole image whose two handles set the display limits, and two fields for
  typing them in data units. Typed limits are exact; clear both fields to go back to the
  percentile rule. A value that is not a number, or an empty or reversed range, is refused with a
  beep. The limits apply with no filter on.

Reset
: Back to the default stretch.

The panel also shows the data values the display is currently clipped to.

## Filters

The filter menu picks one enhancement:

RHEF: reveal faint corona
: The Radial Histogram Equalizing Filter
  ([Gilly & Cranmer 2025](https://doi.org/10.1007/s11207-025-02578-x)) ranks each pixel's brightness
  within its ring of constant height above the Sun, which flattens the steep coronal falloff and
  shows faint off-limb structure at every height. With RHEF on, the stretch panel adds
  **Shadows** and **Highlights** sliders (lower values brighten faint structure, and flatten the
  brightest, respectively) and **Reveal plain image**, a divider with RHEF on its left and the
  plain image on its right. The readout then also gives each pixel's rank in its ring.

MGN: multi-scale contrast
: Multi-scale Gaussian normalization (Morgan & Druckmüller 2014), with sunkit-image's default
  widths.

WOW: wavelet whitening
: Wavelet whitening after Auchère et al. (2023), in HelioFITS Peek's own reading of the method; it
  has not been checked against the authors' `watroo` package.

**Swipe** shows the unfiltered image left of a divider and the filtered one right of it.

Each filter runs on a grid of at most 1024 pixels a side, and MGN and WOW divide their widths by
that decimation, so the preview approximates the full-resolution filter. An opt-in setting runs
RHEF on every pixel in the viewer ({doc}`settings`). **Copy Python** in the viewer reproduces the
RHEF result at full resolution with sunkit-image.

:::{important}
Filter output is a visualization, not a calibrated radiance. Measure on the raw values, which the
readout and statistics always report.
:::

## The colorbar

**Colorbar** shows the colormap and its data limits in a strip left of the image, following the
live stretch. Its heading gives the unit, and with a filter on it describes the filter's ranks in
place of data values. The choice is remembered for the next preview.
