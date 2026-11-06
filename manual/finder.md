# Thumbnails, Get Info and Spotlight

## Thumbnails

```{figure} ../docs/colormaps.png
:width: 80%

Finder's icon view of solar FITS files, each in its instrument's colormap.
```

The thumbnail extension draws each FITS file's image in the colormap its header calls for, in
every Finder view that shows icons: icon view, gallery view, and the small icons of list and
column views. Thumbnails of 128 px and up also carry the instrument and wavelength from the
header, and a file with several image layers shows a stack edge.

Which layer a thumbnail shows is set in {doc}`settings`: the first image HDU unless you choose
another, globally or for one folder. An opt-in setting draws an RHEF cover, which brings out the
faint corona at icon size, on thumbnails of files that have a solar limb.

### When a thumbnail looks wrong or generic

macOS caches thumbnails. After installing, or after changing which layer a folder shows, a
thumbnail can stay generic or stale for a while. Relaunch Finder, or log out and back in. For a
folder rule, **Refresh icons** in Settings touches the folder's FITS files so Finder draws them
again.

The extensions refuse input they cannot read safely: images over 2^28 pixels (16384 x 16384) and
gzip, PKZIP, bzip2, compress, pack or LZH files show the usual generic icon. The viewer app has no
such limit. `.fz` (fpack) and Rice-compressed FITS work everywhere.

## Get Info and Spotlight

```{figure} ../docs/spotlight-metadata.png
:width: 80%

FITS header fields in Finder's Get Info panel.
```

The Spotlight importer reads the header fields people search on (telescope, instrument,
wavelength, observation date, exposure, dimensions, HDU count) into Finder's **Get Info** panel
and makes them searchable in Spotlight, so you can find every 171 Å frame on a disk with a query.

Processing records (`.hfrec`, see {doc}`viewer`) get the same treatment: a thumbnail, a Quick Look
preview of the report, and Spotlight fields for the exported file, layers, instruments, source
times and program. When the record carries a picture of its export, the thumbnail is that
picture over a caption strip with the instruments and date, and the Quick Look preview shows it
beside the header; otherwise the thumbnail is a card with the layers' instruments, date and
program. Quick Look cannot read the exported file beside the record, so the picture has to be
the one embedded in the record. Legacy `.hfrec.json`
records are typed as JSON by macOS and get none of these.

## Choosing a layer for whole folders from Finder

Select folders (or FITS files, which stand for their folder) in Finder and choose **Services ▸
Sync FITS HDU** from the context menu. A **Sync FITS previews** dialog asks for one layer,
**Auto (first)**, **Auto (last)** or a numbered HDU, sets that as the folders' rule and refreshes
their icons. The same rules are listed and edited in {doc}`settings`.
