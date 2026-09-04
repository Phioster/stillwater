"""Den Steg aus dem erzeugten Rohbild fertig bauen.

    python3 -m tools.steg_bauen [ziel.png]

PixelLab hat die Textur gezeichnet -- auf eine Vorzeichnung, die den Aufbau
vorgab (Deck oben, Pfosten darunter, Kopfbaender). Was es nicht liefert, ist
Laenge: die Pfosten hoeren nach zwoelf Zeilen auf. Hier werden sie mit ihrer
eigenen Maserung bis zum Bildrand weitergefuehrt, damit sie im Spiel bis ins
Wasser reichen.

Das Rohbild kam mit erzwungener Palette und hat acht Toene, alle aus dem Holz
der Rute. Dieses Werkzeug bringt keine neue Farbe hinein.

Der Steg laeuft im Pixelmass der Figur: 256 x 96 bei Massstab 2.16 ist auf dem
Schirm so gross wie der alte 512 x 96 bei 1.08 -- aber ein Pixel ist ein Pixel.
"""
import os
import random
import sys

from PIL import Image

W = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROH = os.path.join(W, "assets", "source", "steg", "steg_roh.png")

BREITE, HOEHE = 256, 96
## Der Steg wird zweimal gezeichnet: einmal dunkel, einmal darueber um TIEFE
## Spalten nach links versetzt. Was vom dunklen Bild rechts stehen bleibt, ist
## die hintere Haelfte -- die Tiefe laeuft nach rechts, nicht nach oben, und
## der Steg endet schraeg statt an einer Kante.
TIEFE = 6
## ... und dabei um HOCH Zeilen hoeher: die Tiefe laeuft nach hinten oben,
## nicht nur zur Seite.
HOCH = 2
## Die letzte Zeile des Decks. Darunter faengt die Luft an.
DECK_BIS = 13
## Die Pfosten im Rohbild, jeweils erste und letzte Spalte.
PFOSTEN = ((12, 19), (68, 75), (124, 131), (180, 187), (236, 243))
## Diese Zeilen des Rohbilds werden nach unten fortgesetzt. Der Lauf geht hin
## und zurueck durch sie durch, sonst sieht man alle acht Zeilen dieselbe Kante.
MUSTER_VON, MUSTER_BIS = 18, 25
## Ab hier ist der Pfosten im Schatten des Decks; die zwei hellsten Toene
## werden ersetzt, damit er nicht bis unten in der Sonne steht.
SCHATTEN_AB = 40
DUNKLER = {(0xc3, 0x8e, 0x5b): (0x9a, 0x60, 0x3a),
           (0xa8, 0x67, 0x3c): (0x7d, 0x46, 0x27),
           (0x9a, 0x60, 0x3a): (0x6a, 0x3a, 0x22)}
## Die Querlatte haelt die Pfosten zusammen und bricht die leere Flaeche.
LATTE_VON, LATTE_BIS = 46, 50
LATTE = (0x6a, 0x3a, 0x22)
LATTE_KANTE = (0x44, 0x25, 0x19)


def _saeule(px, x):
    """Der haeufigste Ton dieser Spalte im Muster -- der Grundton des Pfostens.

    Das Rohbild hat zwischen den Kopfbaendern durchsichtige Stellen. Ohne
    einen Grundton je Spalte bleiben die als Loecher stehen, und der Pfosten
    faellt in Stuecke.
    """
    zaehler = {}
    for y in range(MUSTER_VON, MUSTER_BIS + 1):
        f = px[x, y]
        if f[3] > 128:
            zaehler[f[:3]] = zaehler.get(f[:3], 0) + 1
    if not zaehler:
        return None
    return max(zaehler.items(), key=lambda t: t[1])[0]


def pfosten_fuellen(px):
    """Die Pfosten durchgehend fuellen und ihre Maserung neu ziehen.

    Erst wurde das Muster des Rohbilds nach unten wiederholt -- das ergab
    ueber achtzig Zeilen dieselben acht, und das sah man. Jetzt steht der
    Pfosten in seinem Grundton, und die Maserung wird gestreut: kurze
    Striche, je Pfosten aus eigenem Zufall, keine Zeile wie die andere.
    """
    for nr, (von, bis) in enumerate(PFOSTEN):
        grund = {x: _saeule(px, x) for x in range(von, bis + 1)}
        zufall = random.Random(100 + nr)
        for y in range(DECK_BIS + 1, HOEHE):
            for x in range(von, bis + 1):
                if grund[x] is None:
                    continue
                ton = grund[x]
                if y >= SCHATTEN_AB:
                    ton = DUNKLER.get(ton, ton)
                px[x, y] = ton + (255,)
        ## Maserung: kurze senkrechte Striche einen Ton tiefer, nie auf der
        ## Lichtkante links und nie auf der Schattenkante rechts.
        y = DECK_BIS + 3
        while y < HOEHE - 2:
            x = zufall.randint(von + 1, bis - 2)
            laenge = zufall.randint(2, 5)
            for i in range(laenge):
                if y + i >= HOEHE:
                    break
                f = px[x, y + i][:3]
                if f in RAMPE:
                    px[x, y + i] = RAMPE[min(RAMPE.index(f) + 1,
                                             len(RAMPE) - 1)] + (255,)
            y += zufall.randint(4, 11)
        ## Ein Astloch je Pfosten, damit die Flaeche einen Halt bekommt.
        ay = zufall.randint(DECK_BIS + 8, HOEHE - 12)
        ax = zufall.randint(von + 2, bis - 3)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            px[ax + dx, ay + dy] = RAMPE[-2] + (255,)


def latte_ziehen(px):
    """Eine Querlatte hinter den Pfosten, von der ersten bis zur letzten."""
    for x in range(PFOSTEN[0][0], PFOSTEN[-1][1] + 1):
        for y in range(LATTE_VON, LATTE_BIS + 1):
            if px[x, y][3] > 128:        # der Pfosten steht davor
                continue
            px[x, y] = (LATTE_KANTE if y == LATTE_BIS else LATTE) + (255,)


## Ein Ton weiter unten im Holz, zweimal -- so weit, dass die hintere Haelfte
## als Tiefe liest und nicht als zweiter Steg.
RAMPE = [(0xc3, 0x8e, 0x5b), (0xa8, 0x67, 0x3c), (0x9a, 0x60, 0x3a),
         (0x8b, 0x5a, 0x3e), (0x7d, 0x46, 0x27), (0x6a, 0x3a, 0x22),
         (0x58, 0x2f, 0x1e), (0x44, 0x25, 0x19), (0x2c, 0x19, 0x12)]


def abdunkeln(bild, stufen=2):
    """Dasselbe Bild, jeder Ton um Stufen dunkler in derselben Holzrampe."""
    out = bild.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            f = px[x, y]
            if f[3] <= 128:
                continue
            if f[:3] in RAMPE:
                px[x, y] = RAMPE[min(RAMPE.index(f[:3]) + stufen,
                                     len(RAMPE) - 1)] + (255,)
    return out


def oberkante_verblenden(px, zeile, breite):
    """Die oberste Deckzeile aufbrechen.

    Ueber die ganze Laenge derselbe helle Ton ergibt eine gezogene Linie, und
    die liest sich als Kante statt als Licht auf Holz. Die Sonne trifft aber
    nur die Bretter, die etwas hoeher stehen -- also bleibt der helle Ton in
    Stuecken stehen und faellt dazwischen zwei Toene ab.
    """
    zufall = random.Random(23)
    x = 0
    while x < breite:
        laenge = zufall.randint(2, 6)
        ton = RAMPE[zufall.choice((0, 1, 1, 2))]
        for i in range(laenge):
            if x + i >= breite:
                break
            if px[x + i, zeile][3] > 128:
                px[x + i, zeile] = ton + (255,)
        x += laenge


def anfang_schliessen(bild, dunkel):
    """Die Stufe am linken Ende schliessen.

    Der hintere Steg sitzt um TIEFE nach rechts versetzt, oben links blieb
    deshalb eine Ecke offen. Dort werden seine ersten Spalten noch einmal
    gesetzt -- am linken Bildrand laeuft der Steg ohnehin aus dem Bild.
    """
    bild.alpha_composite(dunkel.crop((0, 0, TIEFE, HOCH)), (0, 0))


def bauen():
    roh = Image.open(ROH).convert("RGBA")
    if roh.size != (BREITE, HOEHE):
        raise ValueError("Rohbild ist %dx%d, erwartet %dx%d"
                         % (roh.size + (BREITE, HOEHE)))
    vorn = roh.copy()
    px = vorn.load()
    pfosten_fuellen(px)
    latte_ziehen(px)
    ## Das Rohbild wieder darueber: Deck, Kopfbaender und die gezeichnete
    ## Oberkante der Pfosten bleiben so, wie PixelLab sie gesetzt hat.
    vorn.alpha_composite(roh.crop((0, 0, BREITE, MUSTER_BIS + 1)), (0, 0))
    oberkante_verblenden(px, 0, BREITE)

    dunkel = abdunkeln(vorn)
    bild = Image.new("RGBA", (BREITE + TIEFE, HOEHE + HOCH), (0, 0, 0, 0))
    bild.alpha_composite(dunkel, (TIEFE, 0))
    anfang_schliessen(bild, dunkel)
    bild.alpha_composite(vorn, (0, HOCH))
    return bild


def main(ziel):
    bild = bauen()
    bild.save(ziel)
    px = bild.load()
    farben = {px[x, y][:3] for y in range(bild.height) for x in range(BREITE)
              if px[x, y][3] > 128}
    print("%s: %d x %d, %d Farben, Tiefe %d Spalten nach rechts"
          % (ziel, bild.width, bild.height, len(farben), TIEFE))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1
         else os.path.join(W, "assets", "art", "dock.png"))
