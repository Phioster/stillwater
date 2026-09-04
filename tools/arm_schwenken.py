"""Den vorderen Arm schwenken; der hintere bleibt liegen.

Der hintere Arm ist nur der schmale Streifen, der neben dem Rumpf sichtbar
ist -- 66 Pixel, von Hand nachgezeichnet. Er ruht auf dem Schoss und bewegt
sich nicht: geschwenkt wird der vordere.

Gedreht wird nach dem RotSprite-Verfahren (siehe rotsprite.py). Direkt
gedreht franst der Rand aus, weil sich jedes Zielfeld ein einzelnes Quellfeld
sucht; RotSprite laesst 64 Felder darueber abstimmen.
"""
import math
import os
import sys
import tempfile

import numpy as np
from PIL import Image

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
import rotsprite

W = os.path.dirname(S)
SRC = os.path.join(W, "assets", "source", "figure")
P = os.path.join(SRC, "parts")
# Die Bewegungsbilder gehoeren ins Projekt, die Kontrollbilder nicht.
VORSCHAU = os.environ.get("VORSCHAU", tempfile.gettempdir())

SCHULTER = (49.5, 41.0)
ELLBOGEN = (54.0, 60.0)
UEBERLAPP = 3.0
STUFEN = 4              # 16fach vergroessern statt 8fach: doppelt so viele
N = 2 ** STUFEN         # Stimmen je Zielpixel, sichtbar am staerksten Winkel

rumpf = Image.open(os.path.join(P, "sit3_rumpf.png")).convert("RGBA")
nah = np.array(Image.open(os.path.join(P, "sit3_arm_nah.png")).convert("RGBA"))
fern = np.array(Image.open(os.path.join(P, "sit3_arm_fern.png")).convert("RGBA"))

rx, ry = ELLBOGEN[0] - SCHULTER[0], ELLBOGEN[1] - SCHULTER[1]
lg = math.hypot(rx, ry)
rx, ry = rx / lg, ry / lg
yy, xx = np.mgrid[0:128, 0:128]


def zerlegen(bild, versatz=(0, 0)):
    """In Oberarm und Aermel schneiden, quer zum Oberarm durch den Ellenbogen."""
    s = (xx - ELLBOGEN[0] - versatz[0]) * rx + (yy - ELLBOGEN[1] - versatz[1]) * ry
    da = bild[:, :, 3] > 128
    return (rotsprite.vergroessern(rotsprite._packen(bild * ((da & (s <= 0))[:, :, None])), STUFEN),
            rotsprite.vergroessern(rotsprite._packen(bild * ((da & (s > -UEBERLAPP))[:, :, None])), STUFEN))


nah_oben, nah_unten = zerlegen(nah)
fern_bild = Image.fromarray(fern, "RGBA")


def malen(feld, kette):
    return Image.fromarray(rotsprite._entpacken(
        rotsprite.verkleinern(rotsprite.drehen_kette(feld, kette, N), N)), "RGBA")


def bauen(grad_schulter, grad_ellbogen):
    a, b = math.radians(grad_schulter), math.radians(grad_ellbogen)
    ganz = rumpf.copy()
    ganz.alpha_composite(fern_bild)
    for feld, kette in ((nah_unten, [(b, ELLBOGEN), (a, SCHULTER)]), (nah_oben, [(a, SCHULTER)])):
        ganz.alpha_composite(malen(feld, kette))
    return ganz


# Der Scheitel liegt bei -30/-44 statt -28/-46: bei diesem Winkelpaar faellt
# die Hand am saubersten ins Raster und bleibt am Aermel.
REIHE = [(0, 0), (-7, -11), (-15, -25), (-23, -36), (-30, -44), (-23, -33),
         (-13, -18), (-3, -4), (4, 8), (2, 4)]
bilder = [bauen(a, b) for a, b in REIHE]
# Nicht cast_*: die Namen gehoeren dem Importeur, der sie aus PixelLab neu
# schreiben wuerde.
for i, b in enumerate(bilder):
    b.save(os.path.join(SRC, "wurf_%d.png" % i))

from PIL import ImageDraw
Z = 9
X0, Y0, X1, Y1 = 40, 26, 84, 82
bw, bh = (X1 - X0) * Z, (Y1 - Y0) * Z
KOPF, SP = 30, 5
tafel = Image.new("RGBA", (SP * bw + (SP - 1) * 10, 2 * (bh + KOPF) + 10), (18, 18, 22, 255))
d = ImageDraw.Draw(tafel)
for i, b in enumerate(bilder):
    r, c = divmod(i, SP)
    x, y = c * (bw + 10), r * (bh + KOPF)
    g = b.crop((X0, Y0, X1, Y1)).resize((bw, bh), Image.NEAREST)
    u = Image.new("RGBA", g.size, (28, 32, 38, 255))
    u.alpha_composite(g)
    tafel.alpha_composite(u, (x, y + KOPF))
    d.rectangle([x, y, x + bw, y + KOPF - 4], fill=(40, 44, 52, 255))
    d.text((x + 8, y + 6), "Bild %d" % (i + 1), fill=(255, 235, 140, 255))
tafel.save(os.path.join(VORSCHAU, "reihe_nummern.png"))

Z2 = 4
folge = [b.crop((34, 20, 92, 90)).resize((58 * Z2, 70 * Z2), Image.NEAREST).convert("RGB")
         for b in bilder]
folge[0].save(os.path.join(VORSCHAU, "schwung.gif"), save_all=True,
              append_images=folge[1:], duration=110, loop=0)
print("geschrieben: %d Bilder in %s" % (len(bilder), SRC))
print("Kontrollbilder in %s" % VORSCHAU)
