"""Den Himmelverlauf von Willow Lake faerben.

    python3 -m tools.himmel_bauen

Schreibt assets/art/bg_lake.png an Ort und Stelle um: jede Zeile oberhalb
der Uferbande bekommt ihre Farbe aus `farbe(y)` -- restlos, auch dort, wo
Schilf stand. Die Halme zeichnet danach tools/schilf_bauen.py neu; das
ruft diesen Schritt ohnehin selbst auf, ein einzelner Lauf von
`python3 -m tools.schilf_bauen` baut also den ganzen Hintergrund.

Der Verlauf wird aus festen Endpunkten gerechnet und nicht aus dem
vorhandenen Bild verschoben: dadurch liefert ein zweiter Lauf dasselbe
Ergebnis, statt die Farben jedes Mal weiterzudrehen.

Vorher lief er von (47,72,88) nach (105,138,159) -- ein entsaettigtes
Schiefergrau, neben dem das Wasser bunter aussah als der Himmel darueber.
Jetzt kraeftiger blau und eine Spur heller.
"""
import os
import sys

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BILD = os.path.join(WURZEL, "assets", "art", "bg_lake.png")

## Erste Zeile der Uferbande -- ab hier ist Land, kein Himmel mehr.
UFER_OBEN = 78
## Oben dunkel und satt, am Horizont hell und luftig.
OBEN = (50, 92, 146)
UNTEN = (130, 178, 214)


def farbe(y):
    """Die Himmelfarbe dieser Bildzeile."""
    t = min(max(y, 0), UFER_OBEN - 1) / float(UFER_OBEN - 1)
    return tuple(int(round(a + (b - a) * t))
                 for a, b in zip(OBEN, UNTEN)) + (255,)


def main(quelle=BILD, ziel=None):
    ziel = ziel or quelle
    im = Image.open(quelle).convert("RGBA")
    w, _ = im.size
    px = im.load()
    for y in range(UFER_OBEN):
        ton = farbe(y)
        for x in range(w):
            px[x, y] = ton
    im.save(ziel)
    print("Himmel gefaerbt:", ziel)


if __name__ == "__main__":
    main(*sys.argv[1:])
