# The Quick Look preview

Select a `.fits` file in Finder and press the **spacebar**. HelioFITS Peek draws the image live in
the Quick Look panel, and it is interactive there and in gallery view. Finder's narrow column pane
gets a smaller version: scroll there to blink between layers, and press the spacebar for the full
controls.

```{figure} ../docs/preview-quicklook.png
:width: 90%

A Quick Look preview of an AIA image, with the pixel readout and the toolbar.
```

## Reading values and coordinates

- **Hover** over a pixel to read its value and its helioprojective coordinate: **Tx, Ty**, the
  offset in arcseconds east or west and north or south of the centre of the Sun's disk, and its
  distance from disk centre in solar radii (**R☉**).
- **Drag a box** for region statistics (mean, median, σ, sum, minimum and maximum), computed on the
  full-resolution data, with a live histogram.

```{figure} ../docs/interactive-stats.png
:width: 80%

The solar limb drawn, and a region selected for statistics.
```

The coordinates are computed the way astropy and sunpy compute them and are checked against
astropy pixel for pixel in the test suite: spherical deprojection for the TAN, ARC, SIN and CAR
projections, honouring CUNIT, the PC and CD matrices and CROTA2. When a file uses a projection it
cannot handle, the readout shows no coordinate rather than a plausible wrong one. The readout and
statistics always report the file's raw values, whatever filter or stretch is showing.

Without a mouse, **⌥ plus an arrow** moves a readout cursor, **⌥⇧ plus an arrow** measures a box,
and **Esc** clears them (adding ⌘ moves in finer steps).

## Layers

A FITS file can stack several images as Header Data Units (HDUs), also called extensions, each
labelled by its `EXTNAME`. **Scroll**, or press **↑** and **↓**, to blink between them; they are
pixel-registered, so processing levels or filters can be compared in place. **Play** loops through
the layers as a movie; it never starts by itself, and pressing it again stops it.

## The toolbar

The chips over the image, left to right:

Filter menu
: No filter, RHEF, MGN or WOW. See {doc}`filters`.

Swipe
: The unfiltered image left of a divider and the filtered one right of it. Greyed out while no
  filter is on. Drag the divider, or press ⌥← and ⌥→.

Limb
: Draws the solar limb, the edge of the photosphere, from the header's `RSUN_OBS`.

Colorbar
: The colormap and its data limits in a strip left of the image. Off by default; the choice is
  remembered for the next preview. Hidden in the narrow column pane.

Rings
: Plane-of-sky rings of solar radius and position-angle spokes, from the file's solar WCS. Greyed
  out when the header has no solar WCS or no solar radius (`RSUN_OBS`, `RSUN_ARC` or `DSUN_OBS`).

Diff
: A running difference: this layer minus the previous one, the usual way to spot CMEs, waves and
  dimmings.

Stretch
: Opens the stretch panel (see {doc}`filters`).

Header
: Opens the current layer's FITS header in a drawer beside the preview. It follows the layer as
  you scroll. One-click groups (All, Time, Instrument, WCS, Exposure) narrow it, and pinned
  keywords come first.

Play
: Loops the layers, as above.

## Zoom

**⌥-scroll**, or **⌘+**, **⌘−** and **⌘0**, zooms. **⌘C** copies the pixel readout.

Nothing in the preview changes the file.
