# Processing record goldens

Fixtures and expected output for `HFRecordReportTests` (the Swift port of pyHelioFITS
`src/heliofits/core/report.py` in `HFRecordReport.swift`).

- `example-studio-connect-still.hfrec.json`: copied unchanged from pyHelioFITS
  `tests/fixtures/` at commit `4af7c9ad59067e578a6c1ddcbbe3316038427c71`.
- `example-preview.hfrec.json`: written from that fixture by
  `python3 make_preview.py example-studio-connect-still.hfrec.json example-preview.hfrec.json`:
  the same record with a `preview` object appended last (pyHelioFITS `hfrecord-1.schema.json`
  on branch `claude/project-thread-j9fagc`). Its picture is a 64 x 64 RGB PNG of a synthetic
  limb-darkened disk (1948 bytes) drawn by that script, not mission data. It has no goldens of
  its own: pyHelioFITS at `8def10a` prints all five reports of it byte for byte equal to the
  `example-studio-connect-still.*.txt` goldens, and `HFRecordPreviewTests` checks the same.
- `stress.hfrec.json`: written from that fixture by `python3 make_stress.py <fixture> stress.hfrec.json`
  (many sources, a hidden layer, an unknown step, odd numbers and strings, a Helioviewer layer).

Every `<name>.<kind>.txt` is the stdout of pyHelioFITS at that commit, run from its checkout:

    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format text   > <name>.text.txt
    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format text --full > <name>.full.txt
    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format methods > <name>.methods.txt
    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format tex     > <name>.tex.txt
    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format python  > <name>.python.txt

When report.py changes its layout, regenerate these and port the change; never edit a golden by hand.
