"""Fischbilder aus den PixelLab-Rohbildern bauen.

    python3 -m tools.fische_bauen

Je Art ein Rohbild in assets/source/fische/<id>.png (48x24). Hier wird nur
gespiegelt (Kopf muss links sein: world.gd haengt den Fisch am Maul auf),
je Zone auf eine gemeinsame Palette gebracht und die Silhouette gerechnet.
"""
import glob
import os
import re

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUELLE = os.path.join(WURZEL, "assets", "source", "fische")
ZIEL = os.path.join(WURZEL, "assets", "art")
GROESSE = (48, 24)
## Farben je Zone -- genug fuer Schuppen und Glanz, wenig genug fuer eine Linie.
FARBEN_JE_ZONE = 64
SCHATTEN = (0x14, 0x1c, 0x1a)   # Palette: shadow

## PixelLab hat diese Arten nach rechts schauend gezeichnet.
SPIEGELN = {"bluegill", "hollowfin", "sunhat_bream"}


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
    if bild.size != GROESSE:
        raise ValueError("%s ist %dx%d statt %dx%d" % ((fid,) + bild.size + GROESSE))
    if fid in SPIEGELN:
        bild = bild.transpose(Image.FLIP_LEFT_RIGHT)
    return bild


def gemeinsame_palette(bilder):
    """Alle Bilder einer Zone gemeinsam quantisieren -- eine Palette je Zone."""
    b, h = GROESSE
    bogen = Image.new("RGB", (b * len(bilder), h), (0, 0, 0))
    for i, bild in enumerate(bilder):
        bogen.paste(bild.convert("RGB"), (i * b, 0))
    klein = bogen.quantize(FARBEN_JE_ZONE, method=Image.Quantize.MEDIANCUT)
    zurueck = klein.convert("RGB")
    aus = []
    for i, bild in enumerate(bilder):
        stueck = zurueck.crop((i * b, 0, (i + 1) * b, h)).convert("RGBA")
        stueck.putalpha(bild.getchannel("A").point(lambda a: 255 if a > 128 else 0))
        aus.append(stueck)
    return aus


def silhouette(bild):
    aus = Image.new("RGBA", bild.size, (0, 0, 0, 0))
    px, sp = bild.load(), aus.load()
    for y in range(bild.height):
        for x in range(bild.width):
            if px[x, y][3] > 0:
                sp[x, y] = SCHATTEN + (255,)
    return aus


def main():
    fertig = 0
    for zid, ids in zonen().items():
        da = [f for f in ids if os.path.exists(os.path.join(QUELLE, f + ".png"))]
        if not da:
            continue
        for fid, bild in zip(da, gemeinsame_palette([roh(f) for f in da])):
            bild.save(os.path.join(ZIEL, "fish_%s.png" % fid))
            silhouette(bild).save(os.path.join(ZIEL, "fish_%s_silhouette.png" % fid))
            fertig += 1
        print("%s: %d von %d Arten" % (zid, len(da), len(ids)))
    print("%d Fischbilder geschrieben" % fertig)


if __name__ == "__main__":
    main()
