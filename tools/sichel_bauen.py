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

## Windbilder: die Spitzen neigen sich von WIND_VON bis WIND_BIS, in
## WIND_SCHRITT-Stufen. Gebrochene Werte sind keine Spielerei -- halm() rundet
## je Bildzeile, eine Neigung von 1,2 biegt den Halm also an einer anderen
## Stelle als 1,0 und ergibt ein wirklich anderes Bild.
##
## Zwischenstellungen sind das, was in Pixelgrafik "interpolieren" heisst.
## Mit sechs Stellungen aenderten sich je Wechsel rund 390 Pixel -- mehr als
## die halbe Pflanze auf einmal, und das ruckelt. Mit den feinen Stufen sind
## es rund 100.
##
## Gezeichnete Bilder und KEIN verschobenes Bild: der Horst wurde vorher
## zeilenweise geschert, und weil dabei ganze waagerechte Baender gemeinsam
## ruecken, lief quer durch die Halme eine Naht. Das sah aus wie die
## verrutschten Bildzeilen eines alten Fernsehers, nicht wie Wind. Hier bewegt
## sich jeder Halm als durchgehende Linie, weil er neu gemalt wird.
##
## Der Wind draengt in eine Richtung, deshalb reicht die Reihe weiter nach
## rechts als nach links.
WIND_VON = -1.0
WIND_BIS = 4.0
WIND_SCHRITT = 0.2

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


def _neigungen(hoechster):
    """Die Neigungen, die wirklich verschiedene Bilder ergeben.

    Die feinen Stufen fallen nicht jedes Mal auf ein neues Pixelraster.
    Gemessen wird am VOLLEN Halm; die geschnittenen Stufen bekommen dieselbe
    Liste, damit alle drei Zeilen des Blattes spaltenweise zusammenpassen.
    """
    raus = []
    letzte = None
    n = int(round((WIND_BIS - WIND_VON) / WIND_SCHRITT)) + 1
    for i in range(n):
        neigen = WIND_VON + i * WIND_SCHRITT
        roh = _eine_stufe(0, neigen, hoechster).tobytes()
        if roh != letzte:
            raus.append(neigen)
            letzte = roh
    return raus


def _eine_stufe(stufe, neigen, hoechster):
    """Der Horst in einer Schnittstufe und einer Windstellung."""
    teil = Image.new("RGBA", (HORST_B, HORST_H), (0, 0, 0, 0))
    px = teil.load()
    # Fuer jede Stufe derselbe Samen: so bleibt ein Halm derselbe Halm, nur
    # gekappt, statt bei jedem Treffer die Farbe zu wechseln.
    rng = random.Random(SAAT)
    belegt = set()
    for dx, hoehe, neigung, fuss in HALME:
        gekappt = max(3, int(round(hoehe * RESTE[stufe])))
        # Hohe Halme geben mehr nach als kurze -- ein Stummel im selben Wind
        # bleibt fast gerade.
        schilf_bauen.halm(px, HORST_B // 2 + dx, gekappt,
                          neigung + neigen * gekappt / hoechster, rng, belegt,
                          kolben=gekappt >= 34, fuss=fuss)
    return teil


def horst():
    """Ein Blatt: Spalten sind Windstellungen, Zeilen die Schnittstufen.

    Beides in EINEM Blatt, weil es dieselbe Pflanze ist. Das Ufer nimmt die
    oberste Zeile (ungeschnitten), das Minispiel die Zeile zur jeweiligen
    Stufe -- und dort wiegt sich jeder Halm fuer sich, weil jeder seine
    eigene Zeit mitbringt.
    """
    alt = (schilf_bauen.BREITE, schilf_bauen.HOEHE, schilf_bauen.FUSS)
    schilf_bauen.BREITE = HORST_B
    schilf_bauen.HOEHE = HORST_H
    schilf_bauen.FUSS = HORST_H - 1
    try:
        hoechster = max(h for _, h, _, _ in HALME)
        neigungen = _neigungen(hoechster)
        bild = Image.new("RGBA",
                         (HORST_B * len(neigungen), HORST_H * STUFEN),
                         (0, 0, 0, 0))
        for stufe in range(STUFEN):
            for i, neigen in enumerate(neigungen):
                bild.paste(_eine_stufe(stufe, neigen, hoechster),
                           (i * HORST_B, stufe * HORST_H))
    finally:
        schilf_bauen.BREITE, schilf_bauen.HOEHE, schilf_bauen.FUSS = alt
    print("  %d Windstellungen x %d Schnittstufen" % (len(neigungen), STUFEN))
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
    for name, bild in (("schilf_horst.png", horst()),
                       ("sichel.png", sichel())):
        bild.save(os.path.join(KUNST, name))
        print("%s  %dx%d" % (name, bild.width, bild.height))


if __name__ == "__main__":
    main()
