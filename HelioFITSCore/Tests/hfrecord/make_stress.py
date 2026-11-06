import json, sys, copy
r = json.load(open(sys.argv[1]))
r["producer"]["dirty"] = True
r["output"]["sha256"] = "ab" * 32
del r["summary"]
r["created"] = "2026-11-04T12:00:00Z"
L = r["layers"]
p = L[0]
src = p["sources"][0]
p["sources"] = []
for i, (t, lib) in enumerate([("2025-09-21T20:44:00.000", True), ("2025-09-21T20:32:00.000", False),
                               ("2025-09-21T20:36:00.000", True), ("2025-09-21T20:40:00.000", False),
                               ("2025-09-21T20:48:00.000", True)]):
    s = dict(src); s["date_obs"] = t; s["in_library"] = lib; s["size"] = 25283520 + i
    s["original_name"] = f"PUNCH_L3_CAM_{t[:4]}{t[5:7]}{t[8:10]}{t[11:13]}{t[14:16]}00_v0{i}.fits"
    s["file_version"] = f"0{i % 2}"
    p["sources"].append(s)
p["source_count"] = 120
p["acknowledgement"] = "PUNCH is a NASA Small Explorer; 50% of credit & thanks to the \"PUNCH\" team #1."
a = L[1]
a["enabled"] = False
a["name"] = "193 O'Brien Å layer"
a["dataset"]["label"] = None
a["dataset"]["observatory"] = None
a["dataset"]["wavelength"] = 19.3
a["dataset"]["wavelength_unit"] = "nm"
a["steps"].insert(0, {"op": "warp_drive", "stage": "cpu", "automatic": True, "algorithm": None,
                      "params": {"factor": 1e-05, "big": 1e16, "huge": 12345678901234567890, "none": None,
                                 "list": [1, 2.5, "x\ty"], "nested": {"a": True, "b": "café \"q\""}},
                      "units": {"factor": "dimensionless"},
                      "varies": {"params": ["factor", "big"]},
                      "reference": {"kind": "running"}})
a["steps"].append({"op": "difference", "stage": "gpu", "algorithm": "base difference",
                   "reference": {"kind": "base", "source_index": 0}, "varies": {}})
a["steps"].append({"op": "feather", "reference": {"kind": "other", "x": 1}, "caveat": ""})
s = L[2]
s["source_spec"] = {"kind": "helioviewer_api"}
s["sources"] = [dict(s["sources"][0], source_url="https://example.invalid/a.jp2", original_name=None) for _ in range(2)]
s["sources"].append({"sha256": "0123456789abcdef0123", "date_obs": "2025-09-21T20:30:00.000"})
s["sources"].append({"sha256": "fedcba98765432100000"})
r["caveats"].append("A very long caveat " + "word " * 40 + "that has to wrap several times over the hundred column width")
r["caveats"].append("")
json.dump(r, open(sys.argv[2], "w"), indent=2, ensure_ascii=False)
