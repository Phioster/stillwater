"""Der Kieselhaufen am Ufer und der Ladebalken fuers Steineflitschen.

    python3 -m tools.kiesel_bauen

Der Haufen kommt von PixelLab und liegt roh unter
assets/source/steine/kiesel.png. Das genauere Modell dort nimmt KEINE
Zwangspalette, das Rohbild hat also einunddreissig eigene Farben -- hier
rasten sie auf die vier neutralen Grautoene der Spielpalette ein. Die
braeunlichen Steinfarben sind ausdruecklich nicht dabei: mit ihnen sah der
Haufen matschig aus statt steinern. Sonst wird nur beschnitten -- kein
Drehen, kein Verkleinern: ein Pixel bleibt ein Pixel.

Der Ladebalken ist eine Sichel -- Kreis minus versetzter Kreis --, oben
gerade gekappt und gespiegelt, also breit oben und spitz nach links unten.
Er haelt NUR den Umriss; Fuellung und goldenes Band malt das Spiel zur
Laufzeit durch seine Maske. Damit gibt es die Form genau einmal, und
Zeichnung und Rechnung koennen nicht auseinanderlaufen.
"""
import math
import os
import re

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PALETTE = os.path.join(WURZEL, "core", "palette.gd")
KUNST = os.path.join(WURZEL, "assets", "art")
ROH_KIESEL = os.path.join(WURZEL, "assets", "source", "steine", "kiesel.png")

## Die drei Kreiszahlen des Balkens. Muessen zu der Groesse passen, die
## tests/test_sprite_assets.gd festhaelt.
R = 58.0 * 0.62
VERSATZ = 26.0 * 0.62
R_SCHNITT = 62.0 * 0.62
## Wie viel der oberen Haelfte weggeschnitten wird -- das gibt die gerade
## breite Kante oben.
KAPPUNG = 0.55


def farbe(name):
    """Einen Farbnamen aus core/palette.gd nachschlagen."""
    with open(PALETTE, encoding="utf-8") as f:
        text = f.read()
    treffer = re.search(r'&"%s":\s*Color\("([0-9a-fA-F]{6})"\)' % name, text)
    if treffer is None:
        raise SystemExit("Farbe %s steht nicht in core/palette.gd" % name)
    h = treffer.group(1)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def _drin(x, y):
    return (math.hypot(x, y) <= R
            and math.hypot(x - VERSATZ, y) >= R_SCHNITT)


def ladebalken():
    """Der Umriss des Balkens, gespiegelt: Spitze nach links unten."""
    xh = (R * R - R_SCHNITT * R_SCHNITT + VERSATZ * VERSATZ) / (2.0 * VERSATZ)
    yh = math.sqrt(max(R * R - xh * xh, 0.0))
    y0 = -yh * KAPPUNG
    hoehe = int(round(yh - y0))
    spalten = [x for x in range(int(-R) - 2, int(R) + 2)
               if any(_drin(x + 0.5, y0 + y + 0.5) for y in range(hoehe))]
    x0 = min(spalten)
    breite = max(spalten) - x0 + 1
    bild = Image.new("RGBA", (breite, hoehe), (0, 0, 0, 0))
    umriss = farbe("stone_light")
    for y in range(hoehe):
        for x in range(breite):
            if _drin(x0 + x + 0.5, y0 + y + 0.5):
                # Gespiegelt: die Spitze zeigt nach links unten.
                bild.putpixel((breite - 1 - x, y), umriss)
    print("  ladebalken %dx%d" % (breite, hoehe))
    return bild


## Nur die neutralen Grautoene. stone und stone_light sind braeunlich und
## machten den Haufen matschig.
KIESEL_FARBEN = ("outline", "fur_dark", "fur", "fur_light")


def kiesel():
    """Das rohe Bild beschnitten und auf die Palette eingerastet."""
    bild = Image.open(ROH_KIESEL).convert("RGBA")
    zu = bild.crop(bild.getbbox())
    erlaubt = [farbe(n)[:3] for n in KIESEL_FARBEN]
    px = zu.load()
    for y in range(zu.height):
        for x in range(zu.width):
            q = px[x, y]
            if q[3] == 0:
                continue
            nah = min(erlaubt,
                      key=lambda c: sum((c[i] - q[i]) ** 2 for i in range(3)))
            px[x, y] = nah + (255,)
    print("  kiesel %dx%d" % (zu.width, zu.height))
    return zu


## Wie flach der geworfene Stein wird. Ein Flitschstein ist eine Scheibe --
## ungestaucht sah der ausgeschnittene Brocken aus wie ein Findling in der
## Luft.
WURFSTEIN_GROESSE = (11, 5)


def wurfstein():
    """Ein einzelner Stein aus dem Haufen, flachgedrueckt.

    Der Umriss trennt die drei Steine sauber voneinander, der mittlere laesst
    sich also fuellen und freistellen. Er wird als einziges Bild hier
    verkleinert -- ein Stein in der Luft darf nicht so gross sein wie der
    Haufen, aus dem er kommt.
    """
    haufen = kiesel()
    px = haufen.load()
    umriss = farbe("outline")[:3]
    # Fuellung ab einem Punkt im mittleren Stein, dann sein Umriss dazu.
    koerper = set()
    stapel = [(haufen.width // 2, haufen.height // 2)]
    while stapel:
        x, y = stapel.pop()
        if not (0 <= x < haufen.width and 0 <= y < haufen.height):
            continue
        if (x, y) in koerper:
            continue
        q = px[x, y]
        if q[3] == 0 or q[:3] == umriss:
            continue
        koerper.add((x, y))
        stapel += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    stein = set(koerper)
    for x, y in koerper:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if not (0 <= n[0] < haufen.width and 0 <= n[1] < haufen.height):
                    continue
                if px[n][3] and px[n][:3] == umriss:
                    stein.add(n)
    x0 = min(p[0] for p in stein)
    y0 = min(p[1] for p in stein)
    x1 = max(p[0] for p in stein)
    y1 = max(p[1] for p in stein)
    frei = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1), (0, 0, 0, 0))
    for x, y in stein:
        frei.putpixel((x - x0, y - y0), px[x, y])
    klein = frei.resize(WURFSTEIN_GROESSE, Image.BOX)
    erlaubt = [farbe(n)[:3] for n in KIESEL_FARBEN]
    kp = klein.load()
    for y in range(klein.height):
        for x in range(klein.width):
            q = kp[x, y]
            # Halbe Deckung gibt es im Spiel nicht -- entweder Stein oder Luft.
            if q[3] < 128:
                kp[x, y] = (0, 0, 0, 0)
                continue
            kp[x, y] = min(erlaubt,
                           key=lambda c: sum((c[i] - q[i]) ** 2
                                             for i in range(3))) + (255,)
    print("  wurfstein %dx%d" % klein.size)
    return klein


def main():
    os.makedirs(KUNST, exist_ok=True)
    for name, bild in (("ladebalken.png", ladebalken()),
                       ("kiesel.png", kiesel()),
                       ("wurfstein.png", wurfstein())):
        bild.save(os.path.join(KUNST, name))
        print("%s  %dx%d" % (name, bild.width, bild.height))


if __name__ == "__main__":
    main()
