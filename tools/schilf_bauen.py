"""Die Schilfhalme im Hintergrund von Willow Lake zeichnen.

    python3 -m tools.schilf_bauen

Schreibt assets/art/bg_lake.png an Ort und Stelle um: alles oberhalb der
Uferbande in den drei Schilftoenen wird durch neu gezeichnete Halme
ersetzt. Deterministisch (fester Zufallssamen) und wiederholbar -- ein
zweiter Lauf liefert dasselbe Bild.

Vorher standen dort 40 gleich verteilte Ein-Pixel-Striche in fuenf
Hoehen mit Periode 46. Im Spiel ist ein Hintergrundpixel rund sechs
Bildschirmpixel breit, sie lasen sich deshalb als Balken statt als
Schilf. Jetzt: gestreute Bueschel, geneigte Halme, haengende Blaetter
und Rohrkolben.

Nur Willow Lake hat Schilf; die uebrigen Zonenbilder enthalten keinen
einzigen Halmpixel und werden nicht angefasst.

WICHTIG: reed_dark ist die Farbe der UFERBANDE. Vor dem Himmel liest
sie sich als Schwarz -- sie darf nur in den untersten Zeilen liegen,
wo sie mit der Bande verschmilzt, nie im freien Halm.
"""
import os
import random
import sys
from collections import Counter
from PIL import Image

DARK = (47, 74, 52, 255)        # reed_dark -- nur im Ufer
MID = (77, 122, 74, 255)        # reed
LIGHT = (123, 168, 95, 255)     # reed_light
KOLBEN = (106, 67, 38, 255)     # leather -- Rohrkolben, wie das Stegholz
KOLBEN_HELL = (122, 90, 60, 255)  # wood
GRUEN = {DARK, MID, LIGHT, KOLBEN, KOLBEN_HELL}
UFER_OBEN = 78


def leeren(px, w):
    """Die alten Halme mit der Himmelfarbe IHRER Zeile uebermalen.

    Auf durchsichtig geloescht schienen an ihrer Stelle die dunklen
    Bildschirmraender durch -- als schwarze Balken vor dem Himmel. Der
    Himmel ist ein reiner Zeilenverlauf, seine Farbe ist also je Zeile
    eindeutig die haeufigste.
    """
    for y in range(UFER_OBEN):
        zaehler = Counter(px[x, y] for x in range(w) if px[x, y] not in GRUEN)
        if not zaehler:
            continue
        himmel = zaehler.most_common(1)[0][0]
        for x in range(w):
            if px[x, y] in GRUEN:
                px[x, y] = himmel


def _setz(px, x, y, farbe, w, belegt):
    if 0 <= x < w and 0 <= y < UFER_OBEN and (x, y) not in belegt:
        px[x, y] = farbe
        belegt.add((x, y))


def halm(px, x0, hoehe, neigung, w, rng, belegt, kolben=False):
    """Fuss im Ufergruen, Halm satt, Spitze hell."""
    hell = rng.random() < 0.4
    koerper = LIGHT if hell else MID
    spitze = MID if hell else LIGHT
    spur = []
    for i in range(hoehe):
        t = i / max(1, hoehe - 1)
        x = x0 + int(round(neigung * t ** 1.7))
        y = UFER_OBEN - 1 - i
        spur.append((x, y))
        # Dunkel nur ganz unten, wo die Uferbande direkt anschliesst.
        if i < 2:
            farbe = DARK
        elif hoehe > 7 and t > 0.85:
            farbe = spitze
        else:
            farbe = koerper
        _setz(px, x, y, farbe, w, belegt)
    # Blaetter: durchgehender, haengender Bogen, am Halm angewachsen.
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
                _setz(px, bx + richtung * k, y, koerper, w, belegt)
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


WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BILD = os.path.join(WURZEL, "assets", "art", "bg_lake.png")


def main(quelle=BILD, ziel=None):
    ziel = ziel or quelle
    im = Image.open(quelle).convert("RGBA")
    w, _ = im.size
    px = im.load()
    leeren(px, w)
    zeichnen(px, w)
    im.save(ziel)
    print("geschrieben:", ziel)


if __name__ == "__main__":
    main(*sys.argv[1:])
