"""Rabe und Waschbaer aus den PixelLab-Rohbildern fertig bauen.

    python3 -m tools.besucher_bauen

Quellen liegen in assets/source/besucher/, das Ergebnis in
assets/art/raven.png und trader.png.

Warum ueberhaupt neu: die alten Bilder waren 18x15 beziehungsweise
18x13 Pixel und wurden im Spiel auf eine 96er-Box gestreckt, also 5,33
mal vergroessert -- waehrend Figur, Steg und Schilf auf 2,16 laufen.
Ihre Pixel waren damit zweieinhalb Mal so grob wie alles andere, und
ein Waschbaer mit Maske, Ringelschwanz und Pfoten hatte auf 18x13
schlicht keinen Platz. Bei 48x48 und 2,16 stimmt beides.

Vier Schritte, jeder aus einem konkreten Fehler im Rohbild:

1. Loecher fuellen -- dem Waschbaer fehlten sechs Pixel an der
   Schnauzenspitze, sie waren durchsichtig.
2. Palette angleichen -- ein Ton lag nicht in core/palette.gd.
3. Den Waschbaer spiegeln -- er lief nach links, der Rabe nach rechts.
4. Die Fuesse auf die unterste Zeile schieben, damit world.gd die
   Standlinie nicht aus dem Bildinhalt raten muss.
"""
import os
import re
import sys
from collections import Counter, deque

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUELLE = os.path.join(WURZEL, "assets", "source", "besucher")
ZIEL = os.path.join(WURZEL, "assets", "art")
PALETTE_GD = os.path.join(WURZEL, "core", "palette.gd")

## (Rohbild, Zielbild, spiegeln)
BESUCHER = (
    ("rabe_roh.png", "raven.png", False),
    ("waschbaer_roh.png", "trader.png", True),
)

## Bildreihen: (Namensmuster, Bildzahl, Zielblatt).
##
## Sie sind mit PixelLab AUS den fertigen Standbildern entstanden, liegen
## also schon gespiegelt und auf der Standlinie -- hier wird nur noch die
## Palette angeglichen und nebeneinandergelegt.
REIHEN = (
    ("rabe_flug_%d.png", 8, "raven_fly.png"),
    ("waschbaer_lauf_%d.png", 8, "trader_walk.png"),
)


def palette():
    text = open(PALETTE_GD, encoding="utf-8").read()
    return [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
            for h in re.findall(r'Color\("([0-9a-fA-F]{6})"\)', text)]


def _loecher(px, w, h):
    """Durchsichtige Pixel, die RINGSUM vom Bild eingeschlossen sind.

    Vom Rand aus geflutet: was die Flut nicht erreicht, ist kein
    Hintergrund, sondern ein Loch im Tier.
    """
    aussen = [[False] * h for _ in range(w)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if px[x, y][3] == 0 and not aussen[x][y]:
                aussen[x][y] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if px[x, y][3] == 0 and not aussen[x][y]:
                aussen[x][y] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0 \
                    and not aussen[nx][ny]:
                aussen[nx][ny] = True
                q.append((nx, ny))
    return [(x, y) for x in range(w) for y in range(h)
            if px[x, y][3] == 0 and not aussen[x][y]]


def fuellen(px, w, h):
    """Loecher mit dem haeufigsten Ton ihrer Nachbarschaft schliessen."""
    offen = _loecher(px, w, h)
    while offen:
        rest = []
        for x, y in offen:
            nachbarn = Counter()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                    nachbarn[px[nx, ny]] += 1
            if nachbarn:
                px[x, y] = nachbarn.most_common(1)[0][0]
            else:
                rest.append((x, y))
        if len(rest) == len(offen):
            break                      # kommt nicht weiter, lieber abbrechen
        offen = rest
    return len(_loecher(px, w, h))


def angleichen(px, w, h, pal):
    """Fremde Toene auf den naechstliegenden Palettenton ziehen."""
    erlaubt = set(pal)
    geaendert = 0
    for x in range(w):
        for y in range(h):
            p = px[x, y]
            if p[3] == 0 or p[:3] in erlaubt:
                continue
            nah = min(pal, key=lambda c: sum((a - b) ** 2
                                             for a, b in zip(c, p[:3])))
            px[x, y] = nah + (p[3],)
            geaendert += 1
    return geaendert


def auf_standlinie(im):
    """Das Tier so schieben, dass seine unterste Zeile die Bildkante ist.

    Dann ist die Standlinie die Bildunterkante, und world.gd setzt es
    einfach dorthin, wo das Deck liegt -- statt den Fuss im Bild zu suchen.
    """
    kasten = im.getbbox()
    if kasten is None:
        return im
    unten = kasten[3]
    versatz = im.height - unten
    if versatz == 0:
        return im
    neu = Image.new("RGBA", im.size, (0, 0, 0, 0))
    neu.alpha_composite(im, (0, versatz))
    return neu


def main():
    pal = palette()
    for roh, fertig, spiegeln in BESUCHER:
        im = Image.open(os.path.join(QUELLE, roh)).convert("RGBA")
        w, h = im.size
        px = im.load()
        offen = fuellen(px, w, h)
        fremd = angleichen(px, w, h, pal)
        if spiegeln:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im = auf_standlinie(im)
        im.save(os.path.join(ZIEL, fertig))
        print("%s -> %s  (%d Loecher offen, %d Toene angeglichen%s)"
              % (roh, fertig, offen, fremd, ", gespiegelt" if spiegeln else ""))
    for muster, zahl, blatt in REIHEN:
        bilder = []
        fremd = 0
        for i in range(zahl):
            im = Image.open(os.path.join(QUELLE, muster % i)).convert("RGBA")
            px = im.load()
            fuellen(px, im.width, im.height)
            fremd += angleichen(px, im.width, im.height, pal)
            bilder.append(im)
        breit, hoch = bilder[0].size
        streifen = Image.new("RGBA", (breit * zahl, hoch), (0, 0, 0, 0))
        for i, im in enumerate(bilder):
            streifen.alpha_composite(im, (i * breit, 0))
        streifen.save(os.path.join(ZIEL, blatt))
        print("%s -> %s  (%d Bilder, %d Toene angeglichen)"
              % (muster % 0, blatt, zahl, fremd))


if __name__ == "__main__":
    main()
