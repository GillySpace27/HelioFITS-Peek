# Settings

Open **HelioFITS Peek ▸ Settings…** (⌘,).

```{figure} ../docs/settings.png
:width: 80%

The Settings window.
```

Default image layer
: A FITS file can stack several images, each a Header Data Unit (HDU), also called an extension
  and labelled by its `EXTNAME`: for example a raw frame, a processed layer and an uncertainty map.
  This picks which one previews and thumbnails show. The first image HDU is the default.

Folder rules
: Pin a folder so every FITS file in it previews the same layer, for like-for-like comparison.
  **Add Folder…** adds one; each rule has a layer menu, **Refresh icons** (which touches the
  folder's FITS files so Finder draws their thumbnails again) and a remove button. **Services ▸
  Sync FITS HDU** in Finder sets the same rules ({doc}`finder`).

RHEF
: **Run RHEF at full resolution in the viewer.** Off by default, when RHEF runs on a grid of at
  most 1024 pixels a side. On, it runs on every pixel of the viewer's frame: slower, and a 4096
  pixel frame needs a few hundred megabytes while it runs. It takes effect for files opened
  afterwards. Previews and thumbnails always use the smaller grid.

Thumbnails
: **Show RHEF covers on thumbnails of files with a solar limb.** Brings out the faint corona at
  icon size, at some cost per icon. Use **Refresh icons** on a folder rule to redraw existing
  thumbnails.

Colortables
: Which colortable each instrument is drawn with. **Automatic**, the default, picks the table from
  the file's header, as before. Under **Instruments**, choose a table for a whole instrument (for
  example every AIA channel) or open it to choose one channel; a channel's choice wins over its
  instrument's. **Grayscale** forces grey, and **Files with no recognised instrument** colours files
  the header gives no table. **Reset All** returns to Automatic, and **Export…** and **Import…** save
  and restore the choices as a small JSON file, to keep them across a reinstall or move them to
  another Mac. The viewer and Quick Look follow a change at once; use **Refresh icons** on a folder
  rule to redraw existing thumbnails. A choice changes the colours only: the stretch and, for
  magnetograms, the symmetric limits are unchanged. Choices are stored in the same shared settings
  as the rest of this window and survive app updates; a copy saved by a newer version is never
  overwritten by an older one.

Pinned keywords
: A comma-separated list of header keywords (for example `EXPTIME, WAVELNTH`) shown after the
  caption in the viewer and in Quick Look when the layer has them. **Save Keywords** keeps them.
  You can also pin from a header line in the viewer.

The settings are shared by the app and its Finder extensions.
