# Writes a copy of a processing record with a small synthetic `preview` (pyHelioFITS
# hfrecord-1.schema.json) appended last:  python3 make_preview.py <fixture> <out>
# The picture is drawn here (a limb-darkened disk on black, 64 x 64 RGB PNG), not mission data.
import base64, json, struct, sys, zlib

W = H = 64
rows = []
for y in range(H):
    row = bytearray([0])                      # PNG filter type 0 (none) for this row
    for x in range(W):
        r2 = ((x - 31.5) ** 2 + (y - 31.5) ** 2) / 26.0 ** 2
        v = (1 - r2) ** 0.35 if r2 < 1 else 0.0
        row += bytes([round(250 * v), round(190 * v), round(50 * v)])
    rows.append(bytes(row))

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))
assert len(png) <= 2048, len(png)
r = json.load(open(sys.argv[1]))
r["preview"] = {"media_type": "image/png", "width": W, "height": H,
                "data": base64.b64encode(png).decode(), "frame": None}
open(sys.argv[2], "w").write(json.dumps(r, indent=2, ensure_ascii=False) + "\n")
print(len(png), "bytes of PNG")
