"""Die Uferbande von Willow Lake faerben.

    python3 -m tools.ufer_bauen

Die sechs Zeilen zwischen Himmel und Wasser (78 bis 83) waren ein
einfarbiger Balken. Im Spiel ist eine davon rund sechs Bildschirmpixel
hoch -- als Flaeche von vierzig Pixeln Hoehe in genau einem Ton las sie
sich als Balken und nicht als Wiese.

Jetzt: oben eine belichtete Kante, nach unten hin dunkler zum Wasser, und
dazwischen gestreute hellere Pixel als Grasnarbe. Deterministisch
(fester Zufallssamen), ein zweiter Lauf liefert dasselbe Bild.
"""
import os
import random
import sys

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BILD = os.path.join(WURZEL, "assets", "art", "bg_lake.png")

## Erste und letzte Zeile der Bande.
OBEN = 78
UNTEN = 83

## Von der belichteten Oberkante bis zum Schatten am Wasser. Die mittleren
## Toene sind reed_dark und reed aus core/palette.gd, die aeusseren daraus
## aufgehellt beziehungsweise abgedunkelt.
ZEILEN = (
    (77, 122, 74, 255),
    (58, 94, 60, 255),
    (47, 74, 52, 255),
    (47, 74, 52, 255),
    (40, 64, 46, 255),
    (34, 55, 40, 255),
)
## Streupixel je Zeile: (Ton, Wahrscheinlichkeit).
NARBE = (
    ((123, 168, 95, 255), 0.22),
    ((77, 122, 74, 255), 0.18),
    ((58, 94, 60, 255), 0.14),
    ((40, 64, 46, 255), 0.10),
    ((47, 74, 52, 255), 0.10),
    ((40, 64, 46, 255), 0.08),
)


def main(quelle=BILD, ziel=None):
    ziel = ziel or quelle
    im = Image.open(quelle).convert("RGBA")
    w, _ = im.size
    px = im.load()
    rng = random.Random(5)
    for i, y in enumerate(range(OBEN, UNTEN + 1)):
        grund = ZEILEN[i]
        streu, wahrscheinlich = NARBE[i]
        for x in range(w):
            px[x, y] = streu if rng.random() < wahrscheinlich else grund
    im.save(ziel)
    print("Ufer gefaerbt:", ziel)


if __name__ == "__main__":
    main(*sys.argv[1:])
