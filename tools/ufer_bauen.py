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

## Erste und letzte Zeile der Bande. Sie waechst nach OBEN: die Wasserlinie
## (Zeile 84) und damit die ganze Bildkomposition bleibt, wo sie ist. Mit
## sechs Zeilen war sie ein schmales Band zwischen Schilffuss und Wasser.
OBEN = 73
UNTEN = 83
## Wieviele Zeilen die Oberkante hoechstens ausfranst. Schnurgerade lief sie
## als Lineal durchs Bild -- das faellt bei voller Bildbreite auf.
FRANSE = 3

## Je Zeile drei Toene: Grundton, ein hellerer und ein dunklerer, jeweils
## mit ihrer Haeufigkeit. Die mittleren sind reed_dark und reed aus
## core/palette.gd, die uebrigen daraus auf- und abgedunkelt.
##
## Auch die unteren Zeilen streuen kraeftig: mit zwei fast einfarbigen
## Zeilen am Wasser las sich die untere Haelfte wieder als Balken, und
## genau den sollte die Bande loswerden.
ZEILEN = (
    ((92, 140, 82, 255), ((133, 178, 100, 255), 0.32), ((70, 110, 66, 255), 0.16)),
    ((84, 130, 78, 255), ((123, 168, 95, 255), 0.30), ((64, 102, 62, 255), 0.16)),
    ((77, 122, 74, 255), ((116, 160, 92, 255), 0.30), ((58, 94, 60, 255), 0.16)),
    ((68, 108, 66, 255), ((100, 146, 86, 255), 0.28), ((52, 84, 54, 255), 0.18)),
    ((58, 94, 60, 255), ((92, 140, 82, 255), 0.28), ((47, 74, 52, 255), 0.18)),
    ((52, 84, 56, 255), ((78, 122, 72, 255), 0.26), ((43, 68, 48, 255), 0.18)),
    ((47, 74, 52, 255), ((70, 110, 66, 255), 0.26), ((40, 64, 46, 255), 0.18)),
    ((43, 68, 48, 255), ((60, 96, 60, 255), 0.24), ((36, 58, 42, 255), 0.18)),
    ((38, 60, 44, 255), ((52, 84, 54, 255), 0.22), ((32, 52, 38, 255), 0.16)),
    ((36, 57, 41, 255), ((48, 78, 50, 255), 0.20), ((31, 50, 37, 255), 0.15)),
    ((34, 54, 38, 255), ((46, 74, 48, 255), 0.20), ((30, 48, 36, 255), 0.14)),
)


def _kante(w, rng):
    """Die ausgefranste Oberkante als Zufallslauf, Spalte fuer Spalte.

    Ein Wurf je Spalte waere Salz und Pfeffer; der Lauf haelt benachbarte
    Spalten beieinander und ergibt Buescheln statt Rauschen.
    """
    hoehe = [0] * w
    h = rng.randint(0, FRANSE)
    for x in range(w):
        h = min(max(h + rng.choice((-1, 0, 0, 0, 1)), 0), FRANSE)
        hoehe[x] = h
    return hoehe


def main(quelle=BILD, ziel=None):
    ziel = ziel or quelle
    im = Image.open(quelle).convert("RGBA")
    w, _ = im.size
    px = im.load()
    rng = random.Random(5)
    kante = _kante(w, rng)
    for i, y in enumerate(range(OBEN, UNTEN + 1)):
        grund, (hell, p_hell), (dunkel, p_dunkel) = ZEILEN[i]
        for x in range(w):
            if i < kante[x]:
                continue                 # hier steht noch Himmel
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
