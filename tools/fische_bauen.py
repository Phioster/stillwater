"""Fischbilder aus den PixelLab-Rohbildern bauen.

    python3 -m tools.fische_bauen

Je Art ein Rohbild in assets/source/fische/<id>.png: 48x24, die Riesen
groesser (bis GROSS). Hier wird nur gespiegelt (Kopf muss links sein: world.gd
haengt den Fisch am Maul auf), je Zone auf eine gemeinsame Palette gebracht und
die Silhouette gerechnet.
"""
import glob
import os
import random
import re

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUELLE = os.path.join(WURZEL, "assets", "source", "fische")
ZIEL = os.path.join(WURZEL, "assets", "art")
## Groesstes erlaubtes Rohbild -- die Wale und die Hydra.
GROSS = (96, 48)
## Farben je Zone -- genug fuer Schuppen und Glanz, wenig genug fuer eine Linie.
FARBEN_JE_ZONE = 64
SCHATTEN = (0x14, 0x1c, 0x1a)   # Palette: shadow

## PixelLab hat diese Arten nach rechts schauend gezeichnet.
SPIEGELN = {"bluegill", "hollowfin", "sunhat_bream",
            "peat_warden", "eternal_light", "sky_anchor", "black_hole"}
## Bildfehler kann PixelLab nicht zeichnen; sie kommen hier dazu, NACH der
## Zonenpalette, damit Magenta und Cyan nicht weggerechnet werden.
VERZERREN = {"glitch_fish"}
## Die abgedrehten Wesen bekommen je eine eigene Palette: in der Zonenpalette
## verschoeben ihre knalligen Farben die schon abgenommenen Fische der Zone.
EIGENE_PALETTE = {
    "horizon_whale", "zenith_wing", "blackwater_sturgeon", "aurora_salmon",
    "duskfin", "bog_pike", "glitch_fish", "black_hole",
    "blackfin", "star_ray", "ring_tench", "thunder_catfish", "altitude_ray",
    "gust_tench", "well_king", "vault_catfish", "jug_pike", "frost_ray",
    "mirefin", "ember_ray", "ice_block_fish", "cottage_fish", "pirate_shark",
    "moss_turtle",
}


def zonen():
    """Zone -> Fisch-IDs, aus dem zone_id jeder Art -- so liest es auch das
    Spiel (Database.fish_of_zone). Die Listen in data/zones sind unvollstaendig."""
    aus = {}
    for pfad in sorted(glob.glob(os.path.join(WURZEL, "data", "fish", "*.tres"))):
        with open(pfad) as f:
            s = f.read()
        zid = re.search(r'^zone_id = &"([a-z_]+)"', s, re.M).group(1)
        aus.setdefault(zid, []).append(os.path.basename(pfad)[:-5])
    return aus


def roh(fid):
    bild = Image.open(os.path.join(QUELLE, fid + ".png")).convert("RGBA")
    if bild.width > GROSS[0] or bild.height > GROSS[1]:
        raise ValueError("%s ist %dx%d, erlaubt bis %dx%d" % ((fid,) + bild.size + GROSS))
    if fid in SPIEGELN:
        bild = bild.transpose(Image.FLIP_LEFT_RIGHT)
    return bild


def gemeinsame_palette(bilder):
    """Alle Bilder einer Zone gemeinsam quantisieren -- eine Palette je Zone."""
    xs = [0]
    for bild in bilder:
        xs.append(xs[-1] + bild.width)
    bogen = Image.new("RGB", (xs[-1], max(b.height for b in bilder)), (0, 0, 0))
    for x, bild in zip(xs, bilder):
        bogen.paste(bild.convert("RGB"), (x, 0))
    klein = bogen.quantize(FARBEN_JE_ZONE, method=Image.Quantize.MEDIANCUT)
    zurueck = klein.convert("RGB")
    aus = []
    for x, bild in zip(xs, bilder):
        stueck = zurueck.crop((x, 0, x + bild.width, bild.height)).convert("RGBA")
        stueck.putalpha(bild.getchannel("A").point(lambda a: 255 if a > 128 else 0))
        aus.append(stueck)
    return aus


def verzerren(bild, saat=7):
    """Glitch: Farbgeister links/rechts, verschobene Zeilen, ein Stueck
    fehlende Textur (Magenta-Schachbrett) und Streupixel."""
    rnd = random.Random(saat)
    w, h = bild.size
    aus = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    alpha = bild.getchannel("A")
    for dx, farbe in ((-2, (255, 40, 200)), (2, (40, 240, 255))):
        geist = Image.new("RGBA", (w, h), farbe + (0,))
        geist.putalpha(alpha.point(lambda a: 170 if a > 128 else 0))
        aus.alpha_composite(geist, (dx, 0))
    aus.alpha_composite(bild)
    px = aus.load()
    neu = aus.copy()
    np_ = neu.load()
    y = 0
    while y < h:
        band = rnd.randint(1, 3)
        schub = rnd.choice([0, 0, -4, -3, 3, 5, -6])
        for yy in range(y, min(h, y + band)):
            for x in range(w):
                sx = x - schub
                np_[x, yy] = px[sx, yy] if 0 <= sx < w else (0, 0, 0, 0)
        y += band
    bb = bild.getbbox()
    cx, cy = bb[0] + (bb[2] - bb[0]) * 55 // 100, bb[1] + 2
    for yy in range(cy, min(h, cy + 6)):
        for x in range(cx, min(w, cx + 8)):
            if np_[x, yy][3] > 0:
                np_[x, yy] = (255, 0, 220, 255) if (x // 2 + yy // 2) % 2 == 0 else (10, 0, 20, 255)
    for _ in range(10):
        x, yy = rnd.randrange(bb[0], bb[2]), rnd.randrange(0, h)
        np_[x, yy] = rnd.choice([(80, 255, 80, 255), (255, 255, 255, 255), (40, 240, 255, 255)])
    # Halbdurchsichtige Geisterpixel: das Spiel kennt nur ganz oder gar nicht.
    neu.putalpha(neu.getchannel("A").point(lambda a: 255 if a > 0 else 0))
    return neu


def silhouette(bild):
    aus = Image.new("RGBA", bild.size, (0, 0, 0, 0))
    px, sp = bild.load(), aus.load()
    for y in range(bild.height):
        for x in range(bild.width):
            if px[x, y][3] > 0:
                sp[x, y] = SCHATTEN + (255,)
    return aus


## Willow Lake wurde als ganzer Bogen samt Geheimfischen abgenommen -- dort
## teilen sie weiter die Zonenpalette.
GEHEIM_IN_ZONENPALETTE = {"willow_lake"}


def geheimfische():
    """Geheimfische wurden einzeln abgenommen; neue Zonenfische sollen ihre
    Farben nicht mehr verschieben, deshalb je eine eigene Palette."""
    aus = set()
    for pfad in glob.glob(os.path.join(WURZEL, "data", "fish", "*.tres")):
        with open(pfad) as f:
            if re.search(r"^is_secret = true", f.read(), re.M):
                aus.add(os.path.basename(pfad)[:-5])
    return aus


def main():
    geheim = geheimfische()
    fertig = 0
    for zid, ids in zonen().items():
        da = [f for f in ids if os.path.exists(os.path.join(QUELLE, f + ".png"))]
        if not da:
            continue
        allein = EIGENE_PALETTE | (set() if zid in GEHEIM_IN_ZONENPALETTE else geheim)
        zone = [f for f in da if f not in allein]
        bilder = dict(zip(zone, gemeinsame_palette([roh(f) for f in zone]))) if zone else {}
        for f in da:
            if f in allein:
                bilder[f] = gemeinsame_palette([roh(f)])[0]
        for fid, bild in ((f, bilder[f]) for f in da):
            if fid in VERZERREN:
                bild = verzerren(bild)
            bild.save(os.path.join(ZIEL, "fish_%s.png" % fid))
            silhouette(bild).save(os.path.join(ZIEL, "fish_%s_silhouette.png" % fid))
            fertig += 1
        print("%s: %d von %d Arten" % (zid, len(da), len(ids)))
    print("%d Fischbilder geschrieben" % fertig)


if __name__ == "__main__":
    main()
