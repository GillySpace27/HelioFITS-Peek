# Processing record goldens

Fixtures and expected output for `HFRecordReportTests` (the Swift port of pyHelioFITS
`src/heliofits/core/report.py` in `HFRecordReport.swift`).

- `example-studio-connect-still.hfrec.json`: copied unchanged from pyHelioFITS
  `tests/fixtures/` at commit `4af7c9ad59067e578a6c1ddcbbe3316038427c71`.
- `stress.hfrec.json`: written from that fixture by `python3 make_stress.py <fixture> stress.hfrec.json`
  (many sources, a hidden layer, an unknown step, odd numbers and strings, a Helioviewer layer).

Every `<name>.<kind>.txt` is the stdout of pyHelioFITS at that commit, run from its checkout:

    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format text   > <name>.text.txt
    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format text --full > <name>.full.txt
    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format methods > <name>.methods.txt
    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format tex     > <name>.tex.txt
    PYTHONPATH=src python3 -m heliofits.core record show <name>.hfrec.json --format python  > <name>.python.txt

When report.py changes its layout, regenerate these and port the change; never edit a golden by hand.
