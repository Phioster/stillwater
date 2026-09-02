#!/usr/bin/env python3
"""Friert die Zuordnung Farbe -> Koerperteil fuer diese Figur ein.

Gemessen ueber ALLE Bilder, nicht nur ueber eines: die Bewegungsbilder bringen
Zwischentoene mit, die in der Ruhepose nicht vorkommen. Faellt eine davon
spaeter durch, weil sie in der Tabelle fehlt, waere das ein Loch mitten in der
Animation.

Die geteilten Eintraege stehen hier von Hand drin. Der Sucher in
tools/character_ambiguity.py schlaegt an dieser Figur vierzehn vor, von denen
nur drei stimmen -- er kann das tuerkise Haargummi im Haar nicht von den
Hauttoenen im Gesicht unterscheiden, weil beides ein kleiner Fleck inmitten
von Haar ist. Drei Trennmasse wurden dagegen gemessen (Groesse des Haufens,
Reinheit des Einschlusses, Anteil der eigenen Familie in der Bildhaelfte);
keines trennt sauber. Also entscheidet hier ein Mensch, einmal.

    python3 -m tools.freeze_palette
"""
import glob
import json
import os

from PIL import Image

from tools.character_keys import assign
from tools.character_layers import PARTS, split

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "figure")

## Die Figur und ihre Bewegungen bei PixelLab -- damit nachvollziehbar bleibt,
## woraus diese Tabelle entstanden ist.
QUELLE = {
    "vorlage_stehend": "2ccebb26-7371-4660-96bb-cfd52ea6af98",
    "zustand_sitzend": "b0fa3377-766a-4c2b-ba6e-6ca41842787b",
    "richtung": "south",
    "atemzug": "79e47544-dcf1-4f59-8d5a-f4b7c79d4dc9",
    "wurf": "5913c433-e9dc-445c-910b-be6baeec3ba5",
}

## Farben, die an zwei Stellen vorkommen. Das tuerkise Haargummi traegt
## dieselben Toene wie die Stiefel; oberhalb der Grenze gehoeren sie zum Haar.
GETEILT = {
    (0x24, 0x6f, 0x86): {"grenze": 52, "oben": "hair", "unten": "boots"},
    (0x2f, 0x95, 0xa5): {"grenze": 51, "oben": "hair", "unten": "boots"},
    (0x14, 0x4c, 0x61): {"grenze": 51, "oben": "hair", "unten": "boots"},
}

def bilder():
    pfade = ([os.path.join(SRC, "sit3_south.png")]
             + sorted(glob.glob(os.path.join(SRC, "idle_*.png")))
             + sorted(glob.glob(os.path.join(SRC, "cast_*.png"))))
    return [(os.path.basename(p), Image.open(p).convert("RGBA")) for p in pfade]

def main():
    quellen = bilder()
    tabelle = {}
    je_bild = {}
    for name, img in quellen:
        px = img.load()
        w, h = img.size
        neu = 0
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a <= 128:
                    continue
                if (r, g, b) not in tabelle:
                    tabelle[(r, g, b)] = assign((r, g, b))
                    neu += 1
        je_bild[name] = neu
    print("%d Bilder, %d Farben insgesamt" % (len(quellen), len(tabelle)))
    for name, neu in je_bild.items():
        if neu:
            print("  %-16s bringt %2d neue Farben mit" % (name, neu))

    for farbe, eintrag in GETEILT.items():
        if farbe not in tabelle:
            raise SystemExit("geteilter Eintrag #%02x%02x%02x kommt in keinem Bild vor" % farbe)
        tabelle[farbe] = eintrag

    ausgabe = {"%02x%02x%02x" % f: t for f, t in tabelle.items()}
    ausgabe.update(QUELLE)
    ziel = os.path.join(SRC, "key_palette.json")
    with open(ziel, "w", encoding="utf-8") as fh:
        json.dump(ausgabe, fh, indent=1, sort_keys=True)
    print("geschrieben: %s" % ziel)

    ## Gegenprobe: die Ebenen muessen disjunkt und vollstaendig sein, sonst
    ## taugt die Tabelle nichts.
    from tools.character_keys import load_table
    geladen = load_table(ziel)
    for name, img in quellen:
        ebenen = split(img, geladen)
        sichtbar = sum(1 for p in img.get_flattened_data() if p[3] > 128)
        summe = sum(sum(1 for q in ebenen[t].get_flattened_data() if q[3] > 0) for t in PARTS)
        if summe != sichtbar:
            raise SystemExit("%s: %d Pixel in Ebenen, %d in der Figur" % (name, summe, sichtbar))
    print("Gegenprobe: alle %d Bilder zerfallen restlos und ueberschneidungsfrei" % len(quellen))

if __name__ == "__main__":
    main()
