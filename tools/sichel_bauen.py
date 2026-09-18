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
## Der Horst muss so gross sein wie das Uferband daneben (schilf_bauen: Halme
## von 22 bis 56 Pixeln). Kleiner sah er aus wie Gras vor echtem Schilf.
HORST_B = 34
HORST_H = 62
STUFEN = 3
## Was nach dem jeweiligen Schnitt noch steht.
RESTE = (1.0, 0.6, 0.28)
SAAT = 4711

## Die Halme des Horsts: Versatz zur Mitte, volle Hoehe, Neigung, Fusshoehe.
## Die hinteren und kuerzeren zuerst, die hohen zuletzt -- wer zuletzt
## gezeichnet wird, steht vorn (_setz laesst belegte Pixel stehen).
HALME = ((-11, 24, -3, 4), (11, 26, 3, 3), (-8, 31, -3, 5), (8, 29, 3, 4),
         (-4, 38, -2, 3), (5, 36, 2, 2), (-9, 43, -2, 1), (9, 41, 2, 2),
         (-3, 49, -1, 0), (3, 47, 1, 1), (0, 52, 0, 0))

## Windbilder: wie weit die Spitzen in diesem Bild geneigt stehen, in Pixeln.
## Der Wind draengt in eine Richtung, deshalb reicht die Reihe weiter nach
## rechts als nach links.
##
## Gezeichnete Bilder und KEIN verschobenes Bild: der Horst wurde vorher
## zeilenweise geschert, und weil dabei ganze waagerechte Baender gemeinsam
## ruecken, lief quer durch die Halme eine Naht. Das sah aus wie die
## verrutschten Bildzeilen eines alten Fernsehers, nicht wie Wind. Hier bewegt
## sich jeder Halm als durchgehende Linie, weil er neu gemalt wird.
WIND = (-1, 0, 1, 2, 3, 4)

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
                                  belegt, kolben=gekappt >= 34, fuss=fuss)
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


def wind():
    """Der volle Horst in mehreren Windstellungen, nebeneinander."""
    bild = Image.new("RGBA", (HORST_B * len(WIND), HORST_H), (0, 0, 0, 0))
    alt = (schilf_bauen.BREITE, schilf_bauen.HOEHE, schilf_bauen.FUSS)
    schilf_bauen.BREITE = HORST_B
    schilf_bauen.HOEHE = HORST_H
    schilf_bauen.FUSS = HORST_H - 1
    hoechster = max(h for _, h, _, _ in HALME)
    try:
        for i, neigen in enumerate(WIND):
            teil = Image.new("RGBA", (HORST_B, HORST_H), (0, 0, 0, 0))
            px = teil.load()
            rng = random.Random(SAAT)
            belegt = set()
            for dx, hoehe, neigung, fuss in HALME:
                # Hohe Halme geben mehr nach als kurze -- ein Stummel im
                # selben Wind bleibt fast gerade.
                zu = int(round(neigen * hoehe / hoechster))
                schilf_bauen.halm(px, HORST_B // 2 + dx, hoehe, neigung + zu,
                                  rng, belegt, kolben=hoehe >= 34, fuss=fuss)
            bild.paste(teil, (i * HORST_B, 0))
    finally:
        schilf_bauen.BREITE, schilf_bauen.HOEHE, schilf_bauen.FUSS = alt
    return bild


def main():
    os.makedirs(KUNST, exist_ok=True)
    for name, bild in (("schilf_horst.png", horst()),
                       ("schilf_wind.png", wind()),
                       ("sichel.png", sichel())):
        bild.save(os.path.join(KUNST, name))
        print("%s  %dx%d" % (name, bild.width, bild.height))


if __name__ == "__main__":
    main()
