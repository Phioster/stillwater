"""Das Uferschilf als eigenes Blatt bauen.

    python3 -m tools.schilf_bauen

Schreibt assets/art/schilf.png: einen in der Breite kachelbaren Streifen,
den scenes/fishing/world.gd im MASSSTAB DER FIGUR ueber die Uferlinie
legt.

Warum ein eigenes Blatt und nicht mehr im Hintergrundbild: dort ist ein
Pixel rund sechs Bildschirmpixel breit (die Figur hat gut zwei). Ein Halm
war damit dreimal so grob wie alles andere und wirkte viel zu gross fuers
Spiel, und weil er im Hintergrund steckte, konnte auch keine Wolke
dahinter ziehen. Im Figurenmassstab stimmen beide Punkte.

Deterministisch (fester Zufallssamen) und wiederholbar.

Der Streifen endet UNTEN an der Standlinie: darunter ist nichts, damit er
nichts verdeckt. Genau daran ist ein frueherer Versuch gescheitert -- der
hatte ein durchgehendes Fussband und legte sich als Balken ueber Welle und
Steg.
"""
import os
import random
import sys

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLATT = os.path.join(WURZEL, "assets", "art", "schilf.png")

## Kachelbreite in Figurpixeln. Breit genug, dass sich die Wiederholung
## ueber die Bildbreite nicht als Muster liest.
BREITE = 192
HOEHE = 72
## Die Standlinie ist die unterste Zeile.
FUSS = HOEHE - 1

## Die drei Schilftoene aus core/palette.gd, dazu drei abgeleitete: eine
## Schattenseite fuer dicke Halme, ein helles Gruen fuer frische Spitzen
## und ein trockenes Olivgelb fuer alte Halme.
DARK = (47, 74, 52, 255)
SCHATTEN = (58, 94, 60, 255)
MID = (77, 122, 74, 255)
LIGHT = (123, 168, 95, 255)
FRISCH = (163, 199, 112, 255)
TROCKEN = (152, 148, 88, 255)
TROCKEN_HELL = (186, 178, 116, 255)
## Rohrkolben in den Holztoenen des Stegs (leather, wood).
KOLBEN = (106, 67, 38, 255)
KOLBEN_HELL = (122, 90, 60, 255)

## (Koerper, Spitze, Schatten)
SORTEN = (
    (MID, LIGHT, SCHATTEN),
    (LIGHT, FRISCH, MID),
    (MID, FRISCH, SCHATTEN),
    (TROCKEN, TROCKEN_HELL, MID),
)


def _setz(px, x, y, farbe, belegt):
    x %= BREITE                      # umlaufend: der Streifen kachelt
    if 0 <= y < HOEHE and (x, y) not in belegt:
        px[x, y] = farbe
        belegt.add((x, y))


def halm(px, x0, hoehe, neigung, rng, belegt, kolben=False, fuss=0):
    """Ein Halm. Hohe Halme sind zwei Pixel breit, mit Schattenseite.

    `fuss` hebt ihn um ein paar Pixel an: stuenden alle auf derselben Zeile,
    zoege sich eine zweite schnurgerade Linie durchs Bild. Ein angehobener
    Halm liest sich als einer, der weiter hinten auf der Boeschung steht.
    """
    koerper, spitze, schatten = SORTEN[rng.randrange(len(SORTEN))]
    dick = hoehe >= 30
    spur = []
    for i in range(hoehe):
        t = i / max(1, hoehe - 1)
        x = x0 + int(round(neigung * t ** 1.7))
        y = FUSS - fuss - i
        spur.append((x, y))
        if t > 0.88 and hoehe > 10:
            ton = spitze
        elif i < 2:
            ton = schatten
        else:
            ton = koerper
        _setz(px, x, y, ton, belegt)
        # Schattenseite rechts: das Licht kommt von links, wie beim Steg.
        if dick and i >= 2:
            _setz(px, x + 1, y, schatten, belegt)
    if hoehe >= 14:
        for _ in range(rng.randint(1, 3)):
            i = rng.randint(int(hoehe * 0.35), int(hoehe * 0.85))
            bx, by = spur[i]
            richtung = rng.choice((-1, 1))
            laenge = rng.randint(3, 7)
            y = by
            for k in range(1, laenge + 1):
                # Nach aussen OBEN und erst an der Spitze abknickend --
                # andersherum haengt es wie ein Tannenzweig.
                if k >= 2:
                    y -= 1
                if k >= laenge - 1 and laenge >= 5:
                    y += 1
                _setz(px, bx + richtung * k, y,
                      spitze if k == laenge else koerper, belegt)
    if kolben:
        kx, ky = spur[-1]
        for k in range(5):
            _setz(px, kx, ky - k, KOLBEN, belegt)
            _setz(px, kx + 1, ky - k, KOLBEN if k else KOLBEN_HELL, belegt)
        _setz(px, kx, ky - 4, KOLBEN_HELL, belegt)
    return spur


def zeichnen(px, saat=11):
    rng = random.Random(saat)
    belegt = set()
    x = 0
    while x < BREITE:
        # Ein Bueschel steht als Ganzes etwas hoeher oder tiefer an der
        # Boeschung; innerhalb streuen die einzelnen Halme noch einmal.
        boden = rng.randint(0, 5)
        gross = rng.randint(22, 56)
        halm(px, x, gross, rng.choice((-3, -2, -1, 0, 1, 2, 3)), rng, belegt,
             kolben=gross >= 34 and rng.random() < 0.7, fuss=boden)
        for _ in range(rng.randint(2, 5)):
            dx = rng.randint(-7, 7)
            klein = rng.randint(8, max(10, gross - 8))
            halm(px, x + dx, klein, rng.choice((-2, -1, 0, 1, 2)), rng, belegt,
                 kolben=klein >= 30 and rng.random() < 0.4,
                 fuss=max(0, boden + rng.randint(-2, 2)))
        x += rng.randint(11, 26)


def main(ziel=BLATT):
    im = Image.new("RGBA", (BREITE, HOEHE), (0, 0, 0, 0))
    zeichnen(im.load())
    im.save(ziel)
    print("Schilfblatt geschrieben:", ziel)


if __name__ == "__main__":
    main(*sys.argv[1:])
