# HelioFITS Peek user manual

HelioFITS Peek teaches Finder and Quick Look to read solar FITS files. Once it is installed, a
folder of `.fits` files shows each file as the image it holds, in its instrument's colormap; the
spacebar opens an interactive preview with pixel values, helioprojective coordinates, region
statistics, filters and a layer-by-layer blink; and the viewer app adds the full header, PNG and
movie export, comparison of two files, and a folder's files as a movie, a grid or a table.

This manual is for version {{ release }}. Its revision history is built from the same changelog
the release notes come from. HelioFITS Peek is free and open source (BSD 2-Clause), built by Gilly
at NorthWest Research Associates, and maintained at
[github.com/GillySpace27/HelioFITS-Peek](https://github.com/GillySpace27/HelioFITS-Peek).

```{figure} ../docs/before-after.png
:width: 100%

The same folder of FITS files without HelioFITS Peek (left) and with it (right).
```

```{toctree}
:caption: Using HelioFITS Peek
:maxdepth: 2

install
finder
quick-look
viewer
filters
folders
settings
```

```{toctree}
:caption: Reference
:maxdepth: 1

reference/shortcuts
reference/instruments
reference/command-line
reference/building
privacy-and-accessibility
generated/history
credits
```
