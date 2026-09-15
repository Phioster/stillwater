"""Himmel und Schilf von Willow Lake bauen.

    python3 -m tools.schilf_bauen

Faerbt zuerst den Himmel (tools/himmel_bauen) und zeichnet danach die
Halme neu. Beides deterministisch und wiederholbar: ein zweiter Lauf
liefert dasselbe Bild.

Vorher standen dort 40 gleich verteilte Ein-Pixel-Striche in fuenf Hoehen
mit Periode 46. Im Spiel ist ein Hintergrundpixel rund sechs
Bildschirmpixel breit, sie lasen sich deshalb als Balken statt als
Schilf. Jetzt: gestreute Bueschel, kraeftige Halme mit Schattenseite,
Blaetter, die nach aussen OBEN wegwachsen, trockene Halme dazwischen und
Rohrkolben.

Nur Willow Lake hat Schilf; die uebrigen Zonenbilder enthalten keinen
einzigen Halmpixel und werden nicht angefasst.

WICHTIG: reed_dark ist die Farbe der UFERBANDE. Vor dem Himmel liest sie
sich als Schwarz -- sie darf nur in den untersten Zeilen liegen, wo sie
mit der Bande verschmilzt, nie im freien Halm.
"""
import os
import random
import sys

from PIL import Image

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(S))

from tools import himmel_bauen

WURZEL = os.path.dirname(S)
BILD = os.path.join(WURZEL, "assets", "art", "bg_lake.png")
UFER_OBEN = himmel_bauen.UFER_OBEN

## Die drei Schilftoene aus core/palette.gd, dazu drei, die daraus
## abgeleitet sind: eine Schattenseite fuer dicke Halme, ein helles
## Gruen fuer frische Spitzen und ein trockenes Olivgelb fuer alte Halme.
DARK = (47, 74, 52, 255)          # reed_dark -- nur im Ufer
SCHATTEN = (58, 94, 60, 255)
MID = (77, 122, 74, 255)          # reed
LIGHT = (123, 168, 95, 255)       # reed_light
FRISCH = (163, 199, 112, 255)
TROCKEN = (152, 148, 88, 255)
TROCKEN_HELL = (186, 178, 116, 255)
## Rohrkolben in den Holztoenen des Stegs (leather, wood).
KOLBEN = (106, 67, 38, 255)
KOLBEN_HELL = (122, 90, 60, 255)

## (Koerper, Spitze, Schatten) -- die Halme eines Bueschels ziehen daraus.
SORTEN = (
    (MID, LIGHT, SCHATTEN),
    (LIGHT, FRISCH, MID),
    (MID, FRISCH, SCHATTEN),
    (TROCKEN, TROCKEN_HELL, MID),
)


def _setz(px, x, y, farbe, w, belegt):
    if 0 <= x < w and 0 <= y < UFER_OBEN and (x, y) not in belegt:
        px[x, y] = farbe
        belegt.add((x, y))


def leeren(px, w):
    """Den Himmel ueber alles legen, was vom letzten Lauf stehen blieb."""
    for y in range(UFER_OBEN):
        ton = himmel_bauen.farbe(y)
        for x in range(w):
            px[x, y] = ton


def halm(px, x0, hoehe, neigung, w, rng, belegt, kolben=False):
    """Ein Halm. Ab mittlerer Hoehe zwei Pixel breit, mit Schattenseite."""
    koerper, spitze, schatten = SORTEN[rng.randrange(len(SORTEN))]
    dick = hoehe >= 16
    spur = []
    for i in range(hoehe):
        t = i / max(1, hoehe - 1)
        x = x0 + int(round(neigung * t ** 1.7))
        y = UFER_OBEN - 1 - i
        spur.append((x, y))
        if i < 2:
            ton = DARK
        elif hoehe > 7 and t > 0.85:
            ton = spitze
        else:
            ton = koerper
        _setz(px, x, y, ton, w, belegt)
        # Die Schattenseite steht rechts: das Licht kommt von links, wie
        # beim Steg (tools/steg_bauen.py zieht seine Kante genauso).
        if dick and i >= 2:
            _setz(px, x + 1, y, DARK if i < 3 else schatten, w, belegt)
    if hoehe >= 9:
        for _ in range(1 if hoehe < 15 else 2):
            i = rng.randint(int(hoehe * 0.4), int(hoehe * 0.8))
            bx, by = spur[i]
            richtung = rng.choice((-1, 1))
            laenge = rng.randint(2, 3 if hoehe < 16 else 4)
            y = by
            for k in range(1, laenge + 1):
                if k >= 2:
                    # Nach aussen OBEN: ein Blatt waechst vom Halm weg nach
                    # oben und knickt erst an der Spitze ab. Andersherum
                    # haengt es wie ein Tannenzweig nach unten.
                    y -= 1
                if k == laenge and laenge >= 4:
                    y += 1
                _setz(px, bx + richtung * k, y,
                      spitze if k == laenge else koerper, w, belegt)
    if kolben:
        # Zwei Pixel breit und vier hoch: schmaler liest er sich als
        # versprengter Farbpunkt statt als Rohrkolben.
        kx, ky = spur[-1]
        for k in range(4):
            _setz(px, kx, ky - k, KOLBEN, w, belegt)
            _setz(px, kx + 1, ky - k, KOLBEN if k else KOLBEN_HELL, w, belegt)
        _setz(px, kx, ky - 3, KOLBEN_HELL, w, belegt)
    return spur


def zeichnen(px, w, saat=11):
    rng = random.Random(saat)
    belegt = set()
    x = rng.randint(0, 6)
    while x < w + 6:
        gross = rng.randint(10, 28)
        halm(px, x, gross, rng.choice((-2, -1, 0, 1, 2)), w, rng, belegt,
             kolben=gross >= 14 and rng.random() < 0.8)
        for _ in range(rng.randint(2, 4)):
            dx = rng.randint(-4, 4)
            klein = rng.randint(4, max(5, gross - 4))
            halm(px, x + dx, klein, rng.choice((-1, 0, 1)), w, rng, belegt,
                 kolben=klein >= 13 and rng.random() < 0.45)
        x += rng.randint(6, 16)


def main(quelle=BILD, ziel=None):
    ziel = ziel or quelle
    himmel_bauen.main(quelle, ziel)
    im = Image.open(ziel).convert("RGBA")
    w, _ = im.size
    px = im.load()
    leeren(px, w)
    zeichnen(px, w)
    im.save(ziel)
    print("Schilf gezeichnet:", ziel)


if __name__ == "__main__":
    main(*sys.argv[1:])
