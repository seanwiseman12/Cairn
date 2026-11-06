"""Turn the ETOPO1 ESRI ASCII grid into the globe's relief texture.

The signed elevation is smoothed once, then stored as a 16-bit number split
across two 8-bit channels (about 0.3 m precision):
  value = (elevation + 11000 m) / 20000 m * 65535,  R = high byte, G = low byte.
The shader reads raw texels, rebuilds the 16-bit value and blends neighbours itself.

Usage:
  curl -o etopo.asc "https://coastwatch.pfeg.noaa.gov/erddap/griddap/etopo180.esriAscii?altitude%5B(-90.0):10:(90.0)%5D%5B(-180.0):10:(179.99)%5D"
  python3 tools/make_relief.py etopo.asc Cairn/Resources/Globe/globe-relief.png
Needs Pillow (pip install pillow)."""
import math
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
BLUR_SIGMA = 1.6  # in texels

with open(src) as f:
    header = dict(f.readline().split() for _ in range(6))
    cols, rows = int(header['ncols']), int(header['nrows']) - 1  # drop duplicate pole row
    grid = [[float(v) for v in f.readline().split()] for _ in range(rows)]

radius = int(math.ceil(BLUR_SIGMA * 3))
kernel = [math.exp(-(i * i) / (2 * BLUR_SIGMA ** 2)) for i in range(-radius, radius + 1)]
total = sum(kernel)
kernel = [k / total for k in kernel]

# Horizontal pass wraps around (longitude is continuous); vertical pass clamps at the poles.
tmp = []
for row in grid:
    tmp.append([sum(kernel[k] * row[(x + k - radius) % cols] for k in range(len(kernel))) for x in range(cols)])
smooth = [[0.0] * cols for _ in range(rows)]
for y in range(rows):
    out_row = smooth[y]
    for k, weight in enumerate(kernel):
        src_row = tmp[min(rows - 1, max(0, y + k - radius))]
        for x in range(cols):
            out_row[x] += weight * src_row[x]

r = bytearray(); g = bytearray(); b = bytearray(cols * rows)
for row in smooth:
    for e in row:
        v = max(0, min(65535, round((e + 11000) / 20000 * 65535)))
        r.append(v >> 8)
        g.append(v & 0xFF)

size = (cols, rows)
Image.merge('RGB', [Image.frombytes('L', size, bytes(c)) for c in (r, g, b)]).save(out, optimize=True)
print('wrote', out, size)
