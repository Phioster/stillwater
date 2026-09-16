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

## Je Zeile drei Toene: Grundton, ein hellerer und ein dunklerer, jeweils
## mit ihrer Haeufigkeit. Die mittleren sind reed_dark und reed aus
## core/palette.gd, die uebrigen daraus auf- und abgedunkelt.
##
## Auch die unteren Zeilen streuen kraeftig: mit zwei fast einfarbigen
## Zeilen am Wasser las sich die untere Haelfte wieder als Balken, und
## genau den sollte die Bande loswerden.
ZEILEN = (
    ((77, 122, 74, 255), ((123, 168, 95, 255), 0.30), ((58, 94, 60, 255), 0.16)),
    ((58, 94, 60, 255), ((92, 140, 82, 255), 0.28), ((47, 74, 52, 255), 0.18)),
    ((47, 74, 52, 255), ((70, 110, 66, 255), 0.26), ((40, 64, 46, 255), 0.18)),
    ((43, 68, 48, 255), ((60, 96, 60, 255), 0.24), ((36, 58, 42, 255), 0.18)),
    ((38, 60, 44, 255), ((52, 84, 54, 255), 0.22), ((32, 52, 38, 255), 0.16)),
    ((34, 54, 38, 255), ((46, 74, 48, 255), 0.20), ((30, 48, 36, 255), 0.14)),
)


def main(quelle=BILD, ziel=None):
    ziel = ziel or quelle
    im = Image.open(quelle).convert("RGBA")
    w, _ = im.size
    px = im.load()
    rng = random.Random(5)
    for i, y in enumerate(range(OBEN, UNTEN + 1)):
        grund, (hell, p_hell), (dunkel, p_dunkel) = ZEILEN[i]
        for x in range(w):
            wurf = rng.random()
            if wurf < p_hell:
                px[x, y] = hell
            elif wurf < p_hell + p_dunkel:
                px[x, y] = dunkel
            else:
                px[x, y] = grund
    im.save(ziel)
    print("Ufer gefaerbt:", ziel)


if __name__ == "__main__":
    main(*sys.argv[1:])
