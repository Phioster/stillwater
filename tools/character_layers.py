"""Ein Bild in seine Ebenen schneiden.

Jeder sichtbare Pixel landet in genau einer Ebene -- nachgeschlagen in der
gemessenen Palette, nicht abgestimmt. Wer keine Tabelle mitgibt, bekommt
die gerechnete Zuordnung; im Bauweg wird immer die eingefrorene benutzt.
"""
from PIL import Image

from tools.character_keys import assign

PARTS = ("skin", "hair", "shirt", "pants", "boots", "base")

def split(img, table):
    layers = {p: Image.new("RGBA", img.size, (0, 0, 0, 0)) for p in PARTS}
    src = img.load()
    dst = {p: layers[p].load() for p in PARTS}
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = src[x, y]
            if a <= 128:
                continue
            part = (table or {}).get((r, g, b)) or assign((r, g, b))
            dst[part][x, y] = (r, g, b, 255)
    return layers
