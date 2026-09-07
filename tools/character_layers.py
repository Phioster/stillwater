"""Ein Bild in seine Ebenen schneiden.

Jeder sichtbare Pixel landet in genau einer Ebene -- nachgeschlagen in der
eingefrorenen Palette, nicht abgestimmt. Wer keine Tabelle mitgibt, bekommt
die gerechnete Zuordnung; im Bauweg wird immer die eingefrorene benutzt.
"""
from PIL import Image

from tools.character_keys import assign

PARTS = ("skin", "hair", "shirt", "pants", "boots", "base")


def teil_in_zeile(eintrag, y):
    """Das Koerperteil eines Tabelleneintrags in dieser Bildzeile.

    Ein Name gilt im ganzen Bild. Eine Liste von Baendern [(bis_zeile, teil)]
    gilt zeilenweise, denn dieselbe Farbe dient an zwei Stellen: das dunkle
    Blau liegt oben als Strahne im Zopf und darunter im Pullover, das
    Tuerkis im Kragen und im Stiefel. Das letzte Band muss bis zum unteren
    Bildrand reichen -- sonst faellt ein Pixel durch, und das soll auffallen.
    """
    if isinstance(eintrag, str):
        return eintrag
    for bis, teil in eintrag:
        if y < bis:
            return teil
    raise ValueError("Baender enden vor Zeile %d: %s" % (y, eintrag))


def split(img, table):
    layers = {p: Image.new("RGBA", img.size, (0, 0, 0, 0)) for p in PARTS}
    src = img.load()
    dst = {p: layers[p].load() for p in PARTS}
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = src[x, y]
            if a <= 128:
                continue
            eintrag = (table or {}).get((r, g, b))
            part = teil_in_zeile(eintrag, y) if eintrag else assign((r, g, b))
            dst[part][x, y] = (r, g, b, 255)
    return layers
