# The viewer

Double-click a FITS file (or choose **File ▸ Open…**, ⌘O) to open it in the viewer: the
interactive image on top, with the same readout, statistics, layers and toolbar as
{doc}`quick-look`, and the complete FITS header beneath it. Drag the divider between them to give
the image more room.

```{figure} ../docs/viewer.png
:width: 80%

The viewer: the image above the full FITS header.
```

The viewer's toolbar has the filter menu, **Swipe**, **Limb**, **Colorbar**, **Rings**, **Diff**
and **Stretch** as in Quick Look, and adds **Compare** (below). The header is always shown, so
there is no Header chip. The header pane is selectable, searchable with ⌘F, and navigable with
VoiceOver.

## The bar under the image

Layer menu
: Which HDU to display. Scrolling over the image blinks between them too.

Play, frame rate and scrubber
: Plays the file's layers, or a folder's files ({doc}`folders`), as a loop at 1, 2, 5, 10 or 24
  frames per second.

Show in Finder (⇧⌘R) and Copy Path (⌥⌘C)
: Where the file lives, and its full path. Both are also in the File menu.

Provenance (the ⓘ button)
: The display recipe a saved PNG records: layer, colormap, limits, stretch, filter and app
  version.

Pin
: Pins the keyword on the selected header line, so it shows in the caption here and in Quick
  Look. Click again to unpin. Pinned keywords are also set in {doc}`settings`.

Copy Python
: Copies Python that loads this image into sunpy. In it, `data` is the displayed array as stored
  in the file (numpy), with the header and WCS still on the map; with RHEF on, `rhef_data` is the
  filtered array, computed with sunkit-image at full resolution.

Save RHEF PNG…
: Writes this image through RHEF as a PNG, with its recipe and an RHEF stamp, whatever filter is
  showing.

Save PNG…
: Writes the displayed layer as a colour-mapped PNG: the image as you see it, with the display
  recipe in the PNG's text chunks.

The viewer's title bar carries the file's icon: drag it into Terminal, Mail or a save panel to hand
over the file, or ⌘-click the title to see the folders above it.

## Exporting a movie

**File ▸ Export Movie…** writes the playing frames (a folder's files, or one file's layers) as an
H.264 movie, an HEVC movie or an animated PNG, with the display recipe in the movie's description.
**File ▸ Export RHEF Movie…** does the same with every frame run through RHEF and stamped as such.
Neither overwrites an existing file. Frames are a visualization, not a calibrated radiance.

## Processing records

HelioFITS Studio writes a processing record beside each export, named after it with `.hfrec`
added: `frame.png.hfrec` describes `frame.png`. Double-click one, or open it with **File ▸
Open…** or by dragging it onto the app, to see its report: every layer's dataset, source files,
time range and processing steps. Buttons copy the report, a methods paragraph, the same as LaTeX
or a Python script that opens the same sources, save that script, list every source file, and
reveal the exported file. The exported file is the one the record names, else the record's own
name without `.hfrec`.

Older records are named `.hfrec.json`. The viewer opens them the same way, but Finder treats them
as JSON, so double-click opens your JSON editor: use **File ▸ Open…**, drag and drop, or **Open
With ▸ HelioFITS Peek**. Renaming `frame.png.hfrec.json` to `frame.png.hfrec` gives it the Quick
Look preview, thumbnail and Spotlight fields below.

## Comparing two files

**Compare** opens a menu: **Compare With File...** picks a second FITS file (B). Once one is
chosen, the same menu offers **Side by side**, **Swipe** or **Blink** (with **Pause Blinking** and
**Resume Blinking**), and **Stop Comparing**. It also says whether the two are linked by
helioprojective coordinates: they are not when a frame has no solar WCS or the frames were seen
from different places. Solar rotation between the two times is not compensated.
