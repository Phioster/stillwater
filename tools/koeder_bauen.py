"""Schwimmer und Starterkoeder als Spielsprites bauen.

    python3 -m tools.koeder_bauen

Der Schwimmer kam aus PixelLab mit erzwungener Palette; hier wird nur sein
Koerper ausgeschnitten. Die Schnur, die mitgezeichnet wurde, faellt weg --
im Spiel ist sie eine Line2D von der Rutenspitze zum Schwimmer.

Die Teichmade ist von Hand gesetzt. Verkleinert sah die erzeugte Vorlage aus
wie ein Klumpen: bei fuenf Pixeln Hoehe entscheidet jedes einzelne, ob man
eine Made sieht oder einen Fleck. Der Umriss wird gerechnet, nicht gemalt --
so ist er garantiert geschlossen.

Beide laufen im Massstab der Figur (2.16). Das alte bobber.png war 20x20 bei
Massstab 1 -- gleich gross auf dem Schirm, aber mit doppelt so feinen Pixeln.
"""
import os
import sys

from PIL import Image

W = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROH = os.path.join(W, "assets", "source", "koeder")
ZIEL = os.path.join(W, "assets", "art")

## Der Koerper im erzeugten Bild. Darueber steht nur die Schnur.
SCHWIMMER_FELD = (12, 13, 22, 26)

## PixelLab hat den Schwimmer hell oben und rot unten gezeichnet. Im Wasser
## steht aber die obere Haelfte heraus, und die soll die rote sein -- so herum
## ist es auch die klassische Pose.
##
## Getauscht wird nach Zeile, nicht nach Farbe: das dunkle Rot kam oben als
## Kante der hellen Kuppel vor und unten als Schatten des roten Koerpers. Eine
## reine Farbtabelle haette daraus oben eine graue Kante gemacht.
TRENNZEILE = 6
TAUSCH_OBEN = {
    (0xbc, 0xd9, 0xd2): (0xb4, 0x52, 0x3f),   # foam      -> cloth_red
    (0x8c, 0x90, 0xa0): (0x85, 0x3c, 0x2e),   # rod_steel -> dunkles Rot
}
TAUSCH_UNTEN = {
    (0xb4, 0x52, 0x3f): (0xbc, 0xd9, 0xd2),   # cloth_red -> foam
    (0x85, 0x3c, 0x2e): (0x8c, 0x90, 0xa0),   # dunkles Rot -> rod_steel
    (0xc3, 0x74, 0x65): (0xdb, 0xe9, 0xf2),   # Glanz auf Rot -> Glanz auf Weiss
}

UMRISS = (0x1a, 0x23, 0x20)     # Palette: outline
HELL = (0xf6, 0xdd, 0xc4)       # skin_0
MITTE = (0xe8, 0xbe, 0x9a)      # skin_1
SCHATTEN = (0xc6, 0x8c, 0x63)   # skin_2

## Die Made von der Seite, Kopf rechts. Die Ringe laufen senkrecht durch den
## Koerper, sonst liest sie sich als Bohne.
MADE = [
    ".hmhm...",
    "hhmhmhs.",
    "hhmhmhss",
    ".mmhms..",
]
TOENE = {"h": HELL, "m": MITTE, "s": SCHATTEN}


def umranden(bild):
    """Einen geschlossenen Umriss um alles Sichtbare legen.

    Das Bild waechst dabei um je ein Pixel nach allen Seiten. Gerechnet statt
    gemalt: bei dieser Groesse ist eine Luecke im Umriss sofort ein Loch.
    """
    aus = Image.new("RGBA", (bild.width + 2, bild.height + 2), (0, 0, 0, 0))
    aus.alpha_composite(bild, (1, 1))
    px = aus.load()
    rand = []
    for y in range(aus.height):
        for x in range(aus.width):
            if px[x, y][3] > 128:
                continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if (0 <= nx < aus.width and 0 <= ny < aus.height
                            and px[nx, ny][3] > 128):
                        rand.append((x, y))
                        break
                else:
                    continue
                break
    for p in rand:
        px[p] = UMRISS + (255,)
    return aus


def made_bauen():
    kern = Image.new("RGBA", (len(MADE[0]), len(MADE)), (0, 0, 0, 0))
    px = kern.load()
    for y, zeile in enumerate(MADE):
        for x, z in enumerate(zeile):
            if z in TOENE:
                px[x, y] = TOENE[z] + (255,)
    return umranden(kern)


def schwimmer_bauen():
    roh = Image.open(os.path.join(ROH, "schwimmer_roh.png")).convert("RGBA")
    aus = roh.crop(SCHWIMMER_FELD)
    px = aus.load()
    for y in range(aus.height):
        tabelle = TAUSCH_OBEN if y < TRENNZEILE else TAUSCH_UNTEN
        for x in range(aus.width):
            if px[x, y][3] > 128 and px[x, y][:3] in tabelle:
                px[x, y] = tabelle[px[x, y][:3]] + (255,)
    return aus


def main():
    for name, bild in (("bobber", schwimmer_bauen()),
                       ("bait_pond_grub", made_bauen())):
        pfad = os.path.join(ZIEL, "%s.png" % name)
        bild.save(pfad)
        px = bild.load()
        farben = {px[x, y][:3] for y in range(bild.height)
                  for x in range(bild.width) if px[x, y][3] > 128}
        print("%s.png: %d x %d, %d Farben"
              % (name, bild.width, bild.height, len(farben)))


if __name__ == "__main__":
    main()
