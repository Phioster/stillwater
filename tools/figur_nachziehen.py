"""Stellen der Vorlage nachziehen, die der Generator liegengelassen hat.

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
## sit3_rumpf ist die Vorlage: aus ihr schneidet tools/teile_bauen.py die
## Blaetter, und tools/preview_parts.py zeigt sie. Frueher stand hier auch
## pose_raw.png -- eine zweite Zeichnung derselben Pose, aus der der Ruhelauf
## kam. Sie ist raus, und die Teilung der Listen unten mit ihr.
VORLAGE = "sit3_rumpf.png"

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

## --- Erzeugungsreste ---------------------------------------------------
##
## Zwei einzelne Pixel in einer fremden Farbfamilie. Beim Trennen fallen sie
## in die falsche Ebene, und keine Regel der Farbtabelle bekommt sie: dieselbe
## Farbe liegt in DERSELBEN Zeile auch dort, wo sie hingehoert. Also wird
## nicht die Zuordnung ausgenommen, sondern der Pixel berichtigt.
UMRISS = (0x05, 0x00, 0x0a)         # der Umrisston der Figur
BEINSCHATTEN = (0x89, 0x31, 0x54)   # wie 80,81 gleich daneben

## --- Der Rocksaum ---------------------------------------------------------
##
## Am unteren Rand des Rocks stehen siebzehn Pixel in Pullover- und
## Umrisstoenen. Sie liegen im Rock, tragen aber die Farbe des Oberteils --
## beim Umfaerben des Pullovers waere sein Ton auf den Saum gewandert, und
## drei davon (81-83/77) lagen sogar in der Pulloverebene.
##
## Ersetzt wird je Pixel durch den haeufigsten der vier Rocktoene aus seinen
## acht Nachbarn, wie tools/figure_parts.py::repair es tut. Nur 78,79 hat
## dort ueberhaupt kein Gruen; bei ihm entscheidet der zweite Ring.
GRUEN_HELL = (0xc0, 0xda, 0x31)
GRUEN_MITTE = (0x83, 0x97, 0x44)
GRUEN_DUNKEL = (0x6f, 0x9d, 0x32)

SAUM = [((64, 86), GRUEN_HELL), ((64, 87), GRUEN_HELL),
        ((65, 85), GRUEN_HELL), ((65, 86), GRUEN_HELL),
        ((67, 81), GRUEN_MITTE), ((67, 83), GRUEN_HELL),
        ((68, 82), GRUEN_MITTE), ((69, 81), GRUEN_HELL),
        ((70, 80), GRUEN_HELL), ((77, 78), GRUEN_HELL),
        ((78, 78), GRUEN_HELL), ((78, 79), GRUEN_HELL),
        ((79, 78), GRUEN_DUNKEL), ((80, 77), GRUEN_MITTE),
        ((81, 77), GRUEN_MITTE), ((82, 77), GRUEN_MITTE),
        ((83, 77), GRUEN_MITTE)]

## --- Der Kragen ausformen -------------------------------------------------
##
## Der Kragen ist das Hemd unter dem Pullover und liegt deshalb in der
## Grundebene (siehe tools/freeze_palette.py). Zwei Stellen stoerten daran:
##
## Hinten brach er bei 53-54/33 in einer geraden Kante ab. Die zwei Pixel
## trugen Pullovertoene; als Kragentoene laeuft die Ecke treppenfoermig aus.
##
## Vorn lag der Abschluss in Tuerkis (#2f95a5, #284e59) -- neben dem Weiss
## las sich das gruenlich. Jetzt tragen auch diese Pixel Kragentoene, dazu
## die zwei Umrisspixel bei 63/34-35, damit die Spitze durchgeht. Der Umriss
## bleibt: Spalte 64 ist in beiden Zeilen schwarz.
##
## Kein Pixel kommt hinzu, alle zehn waren belegt -- der Umriss der Figur
## aendert sich nicht.
KRAGEN_HELL = HELL          # #a7cce8
KRAGEN_MITTE = MITTE        # #8cb2d8
KRAGEN_SCHATTEN = SCHATTEN  # #8699b9

## Die hintere Ecke: der Kragen endet in Zeile 32 mit dem mittleren Ton und
## bricht darunter hart ab.
KRAGEN_ECKE = [((53, 33), KRAGEN_SCHATTEN), ((54, 33), KRAGEN_MITTE)]

## Die Spitze vorn:
KRAGEN_SPITZE = [((63, 34), KRAGEN_HELL), ((63, 35), KRAGEN_HELL),
                 ((60, 36), KRAGEN_HELL), ((62, 36), KRAGEN_HELL),
                 ((63, 36), KRAGEN_MITTE), ((62, 37), KRAGEN_HELL),
                 ((63, 37), KRAGEN_MITTE), ((63, 38), KRAGEN_MITTE)]

## --- Der Zopfumriss ------------------------------------------------------
##
## Der innere Umriss des Zopfs laeuft Spalte 47 hinunter, wechselt aber
## mittendrin auf zwei hellere Toene (#170e10 und #221d4e) und liest sich
## dort graulila statt schwarz. Er bekommt durchgehend #05000a -- den Ton,
## den 33 der 48 Umrisspixel des Zopfs schon tragen und der direkt darueber
## bei 47,11 steht.
ZOPF_UMRISS = [((47, y), UMRISS) for y in range(12, 16)]

## Und ein Umrisspixel, das INNEN im Zopf sitzt statt auf seiner Kante: bei
## 48,24 ist der rechte Umriss zwei Pixel breit, wo er sonst einer ist.
## Schwingt der Zopf zum Kopf hin, fuellt dessen Haar dahinter, und der
## Doppelpixel steht als dunkler Fleck mitten im Haar. Ohne ihn bleibt der
## Umriss ueber 48,23 -> 49,24 -> 49,25 diagonal verbunden. Vier seiner acht
## Nachbarn tragen #581153.
ZOPF_INNEN = [((48, 24), (0x58, 0x11, 0x53))]

ALLE = (ZOPF + KRAGEN + KRAGEN_ECKE
        + [((37, 28), UMRISS),          # Zopfspitze: Umriss, nicht Pullover
           ((79, 81), BEINSCHATTEN)]
        + SAUM + KRAGEN_SPITZE + ZOPF_UMRISS + ZOPF_INNEN)


def main():
    pfad = os.path.join(TEILE, VORLAGE)
    bild = Image.open(pfad).convert("RGBA")
    px = bild.load()
    for feld, ton in ALLE:
        px[feld] = ton + (255,)
    bild.save(pfad)
    print("%s: %d Pixel gesetzt" % (VORLAGE, len(ALLE)))


if __name__ == "__main__":
    main()
