#!/usr/bin/env python3
"""Baut die Rutenblaetter aus der gezeichneten Rute.

    python3 -m tools.rute_bauen

Die Rute ist gezeichnet (parts/rute_mit_griff.png) und von
tools/rute_anheften.py in die zehn Wurfwinkel gedreht (wurf_stab_0..9.png).
Hier wird sie nur noch auf das Rutenraster geschnitten und fuer die drei
Kosmetikvarianten umgefaerbt -- gedreht ist schon.

Frueher stand hier tools/import_rod.py: es rechnete eine ANDERE Rute aus
assets/source/rod_45.png -- grauer Schaft, grosse Rolle, doppelt so lang. Das
Spiel zeigte damit eine andere Rute als die Vorschau.
"""
import os
import re

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(WURZEL, "assets", "source", "figure")
OUT = os.path.join(WURZEL, "assets", "art")
POSE = os.path.join(WURZEL, "core", "angler_pose.gd")

## Im Quellbild liegt der Griff in der Mitte des 320er Felds
## (assets/source/figure/wurf_anker.json: "griff": [160, 160]).
QUELL_GRIFF = (160, 160)

## Die gezeichnete Rute IST die Bambusrute (rod_0) -- braun in neunzehn
## Toenen. Eiche ist dunkler und roter, Silber entfaerbt und hell. Die Toene
## sind die von tools/import_rod.py::SHAFT_TONES, damit die gekauften Ruten
## aussehen wie bisher.
##
## Umgefaerbt wird wie in assets/art/palette_swap.gdshader: der Zielton mal
## der Helligkeit des Pixels, damit Maserung, Wicklungen und Umriss bleiben.
VARIANTEN = [None, (0x6b, 0x4a, 0x2c), (0xb9, 0xc3, 0xc8)]


def _zahl(name):
    """Eine int-Konstante aus core/angler_pose.gd -- nicht abgetippt."""
    text = open(POSE, encoding="utf-8").read()
    return int(re.search(r"const %s: int = (\d+)" % name, text).group(1))


def _vektor(name):
    text = open(POSE, encoding="utf-8").read()
    m = re.search(r"const %s: Vector2i = Vector2i\((-?\d+),\s*(-?\d+)\)"
                  % name, text)
    return (int(m.group(1)), int(m.group(2)))


def faerben(bild, ton):
    """Den Schaft auf diesen Ton bringen, Helligkeit behalten."""
    if ton is None:
        return bild
    aus = bild.copy()
    px = aus.load()
    for y in range(aus.size[1]):
        for x in range(aus.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            ## Dieselbe Kurve wie der Shader: 0.55 + 0.9 * Helligkeit.
            luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            k = 0.55 + 0.9 * luma
            px[x, y] = (min(255, int(ton[0] * k)), min(255, int(ton[1] * k)),
                        min(255, int(ton[2] * k)), a)
    return aus


def main():
    feld = _zahl("ROD_FRAME_SIZE")
    bilder = _zahl("ROD_FRAMES")
    gx, gy = _vektor("ROD_GRIP")
    qx, qy = QUELL_GRIFF
    staebe = [Image.open(os.path.join(SRC, "wurf_stab_%d.png" % i))
              .convert("RGBA") for i in range(bilder)]
    for v, ton in enumerate(VARIANTEN):
        blatt = Image.new("RGBA", (feld * bilder, feld), (0, 0, 0, 0))
        for i, stab in enumerate(staebe):
            ## Den Griff des Quellbilds auf den Griff des Zielrasters legen.
            aus = stab.crop((qx - gx, qy - gy, qx - gx + feld, qy - gy + feld))
            blatt.alpha_composite(faerben(aus, ton), (i * feld, 0))
        blatt.save(os.path.join(OUT, "char_rod_%d.png" % v))
        print("char_rod_%d.png  %dx%d" % (v, blatt.size[0], blatt.size[1]))
    print("%d Rutenblaetter geschrieben" % len(VARIANTEN))


if __name__ == "__main__":
    main()
