"""Prueft, ob jedes Bild einer Animation noch strenge Seitenansicht ist.

PixelLab kann das nicht zusichern: der Bildgenerator versucht von sich aus,
Tiefe zu erzeugen, und dreht den Rumpf dabei zur Kamera. Einen Schalter
dagegen gibt es nicht (beim Hersteller nachgefragt, 2026-09-03). Bleibt, die
Drehung zu MESSEN und gedrehte Bilder gar nicht erst zu verwenden.

Gemessen wird die Breite des Oberteils in einem Band auf Brusthoehe, geteilt
durch die Figurenhoehe. Ein flaches Profil ist schmal; dreht sich der Rumpf,
wird er breiter, ohne dass die Figur groesser wird. An dieser Figur gemessen:
0,19 im Profil, 0,24 bei zur Kamera gedrehtem Rumpf.

    python3 -m tools.profil_pruefen bild0.png bild1.png ...
"""

import sys

from PIL import Image

from tools.character_keys import assign

## Anteil der Figurenhoehe, ab dem der Rumpf als gedreht gilt. Zwischen den
## beiden gemessenen Werten, naeher am Profil -- lieber ein grenzwertiges Bild
## verwerfen als eine gedrehte Figur im Ruhelauf.
GRENZE = 0.215
## Das Messband, als Anteil der Figurenhoehe unterhalb des Scheitels. Oberhalb
## sitzt der Kopf, unterhalb beginnen Huefte und Rock.
BAND = (0.30, 0.45)


def rumpfbreite(img):
    """Mittlere Breite der Oberteil-Pixel im Brustband, und die Figurenhoehe."""
    px = img.load()
    bb = img.getbbox()
    if bb is None:
        raise SystemExit("leeres Bild")
    kopf, hoehe = bb[1], bb[3] - bb[1]
    breiten = []
    for y in range(kopf + int(hoehe * BAND[0]), kopf + int(hoehe * BAND[1])):
        xs = [x for x in range(img.size[0])
              if px[x, y][3] > 128 and assign(px[x, y][:3]) == "shirt"]
        if xs:
            breiten.append(max(xs) - min(xs) + 1)
    if not breiten:
        raise SystemExit("kein Oberteil im Brustband gefunden")
    return sum(breiten) / len(breiten), hoehe


def pruefe(pfade):
    """Jedes Bild messen. Gibt die Liste der gedrehten Bilder zurueck."""
    schlecht = []
    for i, p in enumerate(pfade):
        breite, hoehe = rumpfbreite(Image.open(p).convert("RGBA"))
        anteil = breite / hoehe
        ok = anteil <= GRENZE
        if not ok:
            schlecht.append((i, p, anteil))
        print("Bild %2d  Rumpf %5.1f px auf %3d Hoehe -> %.3f   %s"
              % (i, breite, hoehe, anteil, "ok" if ok else "GEDREHT"))
    return schlecht


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    schlecht = pruefe(argv[1:])
    print()
    if schlecht:
        print("%d von %d Bildern sind gedreht (Grenze %.3f):"
              % (len(schlecht), len(argv) - 1, GRENZE))
        for i, p, a in schlecht:
            print("   Bild %d (%s) bei %.3f" % (i, p, a))
        raise SystemExit(1)
    print("Alle %d Bilder sind strenge Seitenansicht." % (len(argv) - 1))


if __name__ == "__main__":
    main(sys.argv)
