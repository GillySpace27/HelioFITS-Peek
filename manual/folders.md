# Folders: movie, grid and table

Open a folder in the viewer (**File ▸ Open…**, and choose the folder) and its FITS files become one
sequence: frames in DATE-OBS order, a scrubber, a frame-rate menu, and **Diff** as a running
difference between neighbouring files, computed at full resolution. Nothing plays until you press
**Play**. Stepping through renders only the page on screen and reads the next frame ahead.

A **Movie | Grid | List** switch in the window shows the files in two other ways:

Grid
: The files' thumbnails (the same ones Finder shows), with a size slider, a caption of
  instrument, wavelength and date, and a **Sort** menu.

List
: A table with a thumbnail, the file name, instrument, wavelength (as 193 Å or 530 nm),
  observation date, exposure and size, read with the same keywords as the Spotlight importer.
  Right-click the table's header to show or hide columns, among them telescope, BITPIX, image
  HDUs and file size; the choice is remembered. Click a column to sort; wavelengths sort in one
  unit, numbers as numbers, and missing values last. **Export CSV…** writes the table.

In both, double-click to open a file. The context menu offers **Open**, **Reveal in Finder** and
**Show in Movie**. Rows fill in as a large folder is read.

Only the files directly in the folder are included, and the folder is not remembered after you
quit. **File ▸ Export Movie…** writes the sequence as a movie ({doc}`viewer`).
