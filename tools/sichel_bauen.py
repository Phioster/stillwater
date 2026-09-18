"""Der schneidbare Schilfhorst und die Sichel fuers Schilfschneiden.

    python3 -m tools.sichel_bauen

Der Horst wird NICHT neu gezeichnet. Er benutzt schilf_bauen.halm(), also
denselben Halm wie das Uferband -- die beiden stehen im selben Spiel, und zwei
verschiedene Schilfsorten waeren zwei Zeichnungen. Dafuer werden die Masse des
Blattes dort kurz umgebogen: _setz() liest sie beim Zeichnen aus dem Modul.

Drei Bilder nebeneinander: voll, angeschnitten, Stummel. Ein Halm, der nach
jedem Treffer gleich aussieht und dann verschwindet, gibt keine Rueckmeldung --
man weiss nicht, ob man ihn schon hat.

Die Sichel ist ein grosser Kreis minus einem versetzten Kreis. Der Ausschnitt
sitzt genau nach links, damit der BAUCH der Klinge dorthin zeigt, wo die
Trefferzone liegt (core/reeds.gd). Ihre Schneide liegt auf dem AEUSSEREN Bogen
-- der Seite, die beim Kreisen durchs Schilf faehrt.
"""
import os
import random
import re

from PIL import Image

from tools import schilf_bauen

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PALETTE = os.path.join(WURZEL, "core", "palette.gd")
KUNST = os.path.join(WURZEL, "assets", "art")

## Muessen zu Reeds.HALM_B und Reeds.HALM_STUFEN passen.
HORST_B = 30
HORST_H = 34
STUFEN = 3
## Was nach dem jeweiligen Schnitt noch steht.
RESTE = (1.0, 0.6, 0.28)
SAAT = 4711

## Die Halme des Horsts: Versatz zur Mitte, volle Hoehe, Neigung, Fusshoehe.
## Die hinteren und kuerzeren zuerst, die hohen zuletzt -- wer zuletzt
## gezeichnet wird, steht vorn (_setz laesst belegte Pixel stehen).
HALME = ((-9, 13, -3, 3), (9, 14, 3, 2), (-6, 17, -2, 4), (6, 16, 2, 3),
         (-3, 21, -1, 2), (4, 20, 1, 1), (-7, 23, -2, 0), (7, 22, 2, 1),
         (-2, 26, -1, 0), (2, 25, 1, 0), (0, 24, 0, 1))

SICHEL = 44
SICHEL_VERSATZ = 0.34
SICHEL_RADIUS = 0.92


def farbe(name):
    """Einen Farbnamen aus core/palette.gd nachschlagen."""
    with open(PALETTE, encoding="utf-8") as f:
        text = f.read()
    treffer = re.search(r'&"%s":\s*Color\("([0-9a-fA-F]{6})"\)' % name, text)
    if treffer is None:
        raise SystemExit("Farbe %s steht nicht in core/palette.gd" % name)
    h = treffer.group(1)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def horst():
    bild = Image.new("RGBA", (HORST_B * STUFEN, HORST_H), (0, 0, 0, 0))
    # schilf_bauen zeichnet auf sein eigenes Blattmass. Hier wird es kurz auf
    # das des Horsts gesetzt und danach zurueckgegeben -- sonst kachelt _setz
    # ueber die falsche Breite und schneidet an der falschen Hoehe ab.
    alt = (schilf_bauen.BREITE, schilf_bauen.HOEHE, schilf_bauen.FUSS)
    schilf_bauen.BREITE = HORST_B
    schilf_bauen.HOEHE = HORST_H
    schilf_bauen.FUSS = HORST_H - 1
    try:
        for stufe in range(STUFEN):
            # Jede Stufe auf ihr EIGENES Blatt: _setz kachelt umlaufend, auf
            # dem gemeinsamen Blatt wuechse ein Halm in die Nachbarstufe hinein.
            teil = Image.new("RGBA", (HORST_B, HORST_H), (0, 0, 0, 0))
            px = teil.load()
            # Fuer jede Stufe derselbe Samen: so bleibt ein Halm derselbe
            # Halm, nur gekappt, statt bei jedem Treffer die Farbe zu wechseln.
            rng = random.Random(SAAT)
            belegt = set()
            for dx, hoehe, neigung, fuss in HALME:
                gekappt = max(3, int(round(hoehe * RESTE[stufe])))
                schilf_bauen.halm(px, HORST_B // 2 + dx, gekappt, neigung, rng,
                                  belegt, kolben=gekappt >= 24, fuss=fuss)
            bild.paste(teil, (stufe * HORST_B, 0))
    finally:
        schilf_bauen.BREITE, schilf_bauen.HOEHE, schilf_bauen.FUSS = alt
    return bild


def sichel():
    bild = Image.new("RGBA", (SICHEL, SICHEL), (0, 0, 0, 0))
    m = SICHEL / 2.0
    r = m - 1.0
    versatz = SICHEL_VERSATZ * r
    r_schnitt = SICHEL_RADIUS * r
    schneide, silber = farbe("rod_shine"), farbe("silver")
    stahl, ruecken = farbe("rod_steel"), farbe("outline")
    for y in range(SICHEL):
        for x in range(SICHEL):
            dx, dy = x + 0.5 - m, y + 0.5 - m
            aussen = (dx * dx + dy * dy) ** 0.5
            innen = ((dx + versatz) ** 2 + dy * dy) ** 0.5
            if aussen > r or innen < r_schnitt:
                continue
            zur_schneide = r - aussen
            zum_ruecken = innen - r_schnitt
            if zur_schneide < 1.2:
                f = schneide
            elif zum_ruecken < 1.2:
                f = ruecken
            elif zur_schneide < 3.2:
                f = silber
            elif zum_ruecken < 3.0:
                f = stahl
            else:
                f = silber
            bild.putpixel((x, y), f)
    return bild


def main():
    os.makedirs(KUNST, exist_ok=True)
    for name, bild in (("schilf_horst.png", horst()), ("sichel.png", sichel())):
        bild.save(os.path.join(KUNST, name))
        print("%s  %dx%d" % (name, bild.width, bild.height))


if __name__ == "__main__":
    main()
