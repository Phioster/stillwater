"""Zwei Stellen der Vorlage nachziehen, die der Generator liegengelassen hat.

    python3 -m tools.figur_nachziehen

Zopf: der Bildgenerator hat ihn bei Spalte 38 gerade abgeschnitten: keine
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

## --- Der Kragen unter dem Kinn -------------------------------------------
##
## Zeile 32 lief ueber drei Felder in EINEM Ton durch -- ein flacher Streifen
## statt eines Kragens. Jetzt drei Toene: von der hellen Kante links in den
## Kinnschatten und rechts wieder heraus.
##
## 60,32 bleibt unberuehrt: dort liegt die Spitze der Haarstraehne, die
## gehoert zum Kopf und liegt oben. Was ihr fehlte, war eine Unterlage --
## die steht jetzt in figure_parts.RUMPF_UNTERLAGE.
HELL = (0xa7, 0xcc, 0xe8)
MITTE = (0x8c, 0xb2, 0xd8)
SCHATTEN = (0x86, 0x99, 0xb9)

KRAGEN = [((57, 32), HELL), ((58, 32), MITTE), ((59, 32), SCHATTEN),
          ((61, 32), MITTE), ((60, 33), MITTE)]


def main():
    for name in VORLAGEN:
        pfad = os.path.join(TEILE, name)
        bild = Image.open(pfad).convert("RGBA")
        px = bild.load()
        for feld, ton in ZOPF + KRAGEN:
            px[feld] = ton + (255,)
        bild.save(pfad)
        print("%s: %d Pixel gesetzt" % (name, len(ZOPF) + len(KRAGEN)))


if __name__ == "__main__":
    main()
