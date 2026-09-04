"""Den Zopf an seiner Spitze weiterzeichnen.

    python3 -m tools.zopf_ergaenzen

Der Bildgenerator hat den Zopf bei Spalte 38 gerade abgeschnitten: keine
Kante, kein Auslauf, in beiden Vorlagen dieselbe senkrechte Wand. In der
Ansicht sah er dadurch aus, als waere er beschnitten worden.

Die sieben Pixel sind am Rasterblatt abgenommen, nicht geschaetzt: die
Unterkante im dunklen Lila der Haarschatten, der Rest im normalen Ton der
beschatteten Seite. Beide Toene stehen schon in der Palette.

Das Werkzeug darf mehrfach laufen -- es setzt Farben, es addiert nichts.
"""
import os
import sys

from PIL import Image

W = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEILE = os.path.join(W, "assets", "source", "figure", "parts")
## pose_raw traegt den Ruhelauf im Spiel, sit3_rumpf die Wurfreihe. Der Zopf
## ist in beiden gleich abgeschnitten, also bekommen beide dieselben Pixel.
VORLAGEN = ("pose_raw.png", "sit3_rumpf.png")

NORMAL = (0xab, 0x3b, 0x8f)     # beschattete Seite des Zopfs
UNTEN = (0x58, 0x11, 0x53)      # dunkles Lila, wie die Kante bei 38,19

## Eine Spalte, kein Wulst: zwei nebeneinander liessen den Zopf dicker
## werden, statt ihn auslaufen zu lassen.
ZOPF = ([((37, y), NORMAL) for y in range(12, 18)] + [((37, 18), UNTEN)])


def main():
    for name in VORLAGEN:
        pfad = os.path.join(TEILE, name)
        bild = Image.open(pfad).convert("RGBA")
        px = bild.load()
        for feld, ton in ZOPF:
            px[feld] = ton + (255,)
        bild.save(pfad)
        print("%s: %d Pixel gesetzt" % (name, len(ZOPF)))


if __name__ == "__main__":
    main()
