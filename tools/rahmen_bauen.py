"""Den Panelrahmen aus dem Steg schneiden.

    python3 -m tools.rahmen_bauen [ziel.png]

Der Rahmen wird NICHT neu gezeichnet, sondern aus assets/art/dock.png
geschnitten: waagerechte Kanten sind das Deck, senkrechte ein Pfosten, und
die Ecke ist die Stelle, an der beide aufeinandertreffen. Damit stammt die
Oberflaeche nachweislich aus derselben Hand wie der Steg im Bild -- ein frei
erfundener Holzrahmen daneben faellt sofort auf, und sei es nur an einem
anderen Braunton.

Das Ergebnis ist ein 9-Slice: die Ecken bleiben stehen, die Kanten
wiederholen sich. Beide Kachelmasse sind am Bild gemessen und nicht geraten
(tools/tests/test_rahmen.py rechnet sie nach): der Pfosten wiederholt sich
alle 24 Zeilen praktisch fugenlos, das Deck alle 56 Spalten -- das ist genau
der Pfostenabstand.
"""
import os
import re
import sys

from PIL import Image

W = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEG = os.path.join(W, "assets", "art", "dock.png")
PALETTE = os.path.join(W, "core", "palette.gd")
BLATT = os.path.join(W, "assets", "art", "panel_rahmen.png")

## Womit die Mitte gefuellt wird. Der Name wird in core/palette.gd
## nachgeschlagen statt hier als Hexwert zu stehen -- dieselbe Regel wie in
## den anderen Werkzeugen: eine Quelle fuer die Farbe, nicht zwei.
FUELLUNG = "water_deep"
## Wie deckend. Nicht ganz: durch das Panel schimmert der See, sonst klebt
## ein schwarzes Brett vor der Welt.
DECKUNG = 235

## Das Deck im Stegbild: die obersten Zeilen, ueber die ganze Breite gefuellt.
DECK_HOCH = 16
## Der erste Pfosten, erste und letzte Spalte. 14 Spalten breit.
PFOSTEN_VON, PFOSTEN_BIS = 12, 25
## Die gemessenen Kachelmasse.
DECK_PERIODE = 56
PFOSTEN_PERIODE = 24
## Aus welchen Zeilen der Pfosten geschnitten wird: unterhalb der Querlatte
## (Zeile 46-50), damit die nicht mitten in der Kante klebt.
PFOSTEN_AB = 56

RAND_SEITE = PFOSTEN_BIS - PFOSTEN_VON + 1  # 14
RAND_OBEN = DECK_HOCH


def farbe(name):
    """Einen Farbnamen aus core/palette.gd nachschlagen."""
    text = open(PALETTE, encoding="utf-8").read()
    treffer = re.search(r'&"%s":\s*Color\("([0-9a-fA-F]{6})"\)' % name, text)
    if treffer is None:
        raise SystemExit("Farbe %s steht nicht in core/palette.gd" % name)
    h = treffer.group(1)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def schneide(steg):
    """Die fuenf Bausteine: Ecke, Deckkachel, Pfostenkachel."""
    ecke = steg.crop((PFOSTEN_VON, 0, PFOSTEN_BIS + 1, DECK_HOCH))
    # Die Deckkachel beginnt NEBEN dem Pfosten -- ueber dem Pfosten sitzt die
    # Ecke, und dieselbe Stelle zweimal im Bild sieht man als Wiederholung.
    deck = steg.crop((PFOSTEN_BIS + 1, 0,
                      PFOSTEN_BIS + 1 + DECK_PERIODE, DECK_HOCH))
    pfosten = steg.crop((PFOSTEN_VON, PFOSTEN_AB, PFOSTEN_BIS + 1,
                         PFOSTEN_AB + PFOSTEN_PERIODE))
    return ecke, deck, pfosten


def bauen(steg):
    ecke, deck, pfosten = schneide(steg)
    breite = RAND_SEITE * 2 + DECK_PERIODE
    hoehe = RAND_OBEN * 2 + PFOSTEN_PERIODE
    im = Image.new("RGBA", (breite, hoehe), (0, 0, 0, 0))
    rechts = breite - RAND_SEITE
    unten = hoehe - RAND_OBEN
    # Die Mitte, die der 9-Slice aufzieht. Ohne sie waere das Panel ein
    # Rahmen um nichts, und der Text staende auf dem blanken See.
    im.paste(Image.new("RGBA", (breite - 2 * RAND_SEITE, hoehe - 2 * RAND_OBEN),
                       farbe(FUELLUNG) + (DECKUNG,)), (RAND_SEITE, RAND_OBEN))
    # Waagerechte Kanten. Die untere wird gespiegelt: das Deck ist oben hell
    # und unten beschattet, ungespiegelt saehe der untere Balken aus, als
    # kaeme das Licht von unten.
    im.paste(deck, (RAND_SEITE, 0))
    im.paste(deck.transpose(Image.FLIP_TOP_BOTTOM), (RAND_SEITE, unten))
    # Senkrechte Kanten. Der Pfosten ist links beleuchtet; rechts gespiegelt,
    # damit das Licht auch dort von derselben Seite kommt.
    im.paste(pfosten, (0, RAND_OBEN))
    im.paste(pfosten.transpose(Image.FLIP_LEFT_RIGHT), (rechts, RAND_OBEN))
    # Die vier Ecken, jeweils in ihre Richtung gespiegelt.
    im.paste(ecke, (0, 0))
    im.paste(ecke.transpose(Image.FLIP_LEFT_RIGHT), (rechts, 0))
    im.paste(ecke.transpose(Image.FLIP_TOP_BOTTOM), (0, unten))
    im.paste(ecke.transpose(Image.ROTATE_180), (rechts, unten))
    return im


def main(ziel=BLATT):
    steg = Image.open(STEG).convert("RGBA")
    im = bauen(steg)
    im.save(ziel)
    print("Rahmen geschrieben: %s (%dx%d, Rand %d/%d)"
          % (ziel, im.width, im.height, RAND_SEITE, RAND_OBEN))


if __name__ == "__main__":
    main(*sys.argv[1:])
