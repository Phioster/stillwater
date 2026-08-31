#!/usr/bin/env python3
"""Macht aus einem erzeugten Bild ein Sprite in unserem Stil.

Bildmodelle liefern ein grosses Bild auf einfarbigem Grund -- kein
Pixelbild und keine Transparenz. Dieses Werkzeug macht daraus, was das Spiel
braucht: freigestellt, auf Sprite-Groesse gerechnet, auf wenige Farben
reduziert und mit dunklem Umriss.

    python3 tools/import_prop.py roh.png ziel.png --hoehe 40
    python3 tools/import_prop.py roh.png ziel.png --hoehe 40 --winkel -45

Die Reihenfolge ist Absicht: erst DREHEN, dann verkleinern. Ein fertiges
Pixelbild zu drehen zerreisst die Kanten; ein grosses Bild vertraegt es.
"""
import argparse
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def palette_of(gd_file):
    """Liest die Farben aus core/palette.gd -- eine Quelle, nicht zwei."""
    colors = []
    with open(gd_file, encoding="utf-8") as fh:
        for line in fh:
            if 'Color("' not in line:
                continue
            hexval = line.split('Color("')[1].split('"')[0]
            colors.append(tuple(int(hexval[i:i + 2], 16) for i in (0, 2, 4)))
    return colors

def key_out(img, tolerance):
    """Entfernt den einfarbigen Hintergrund -- gemessen an den vier Ecken,
    nicht geraten: welche Farbe der Prompt bekommen hat, weiss das Bild."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = max(set(c[:3] for c in corners), key=[c[:3] for c in corners].count)
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if sum(abs(a - b) for a, b in zip(p[:3], bg)) <= tolerance:
                px[x, y] = (0, 0, 0, 0)
    return img

def snap(img, colors):
    """Jede Farbe auf die naechste Palettenfarbe ziehen."""
    px = img.load()
    cache = {}
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            p = px[x, y]
            if p[3] < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            key = p[:3]
            if key not in cache:
                cache[key] = min(colors, key=lambda c: sum(
                    (a - b) ** 2 for a, b in zip(c, key)))
            px[x, y] = cache[key] + (255,)
    return img

def outline(img, color):
    """Dunkle Kante aussen herum. Ohne sie sieht jedes Teil aufgeklebt aus --
    die gezeichnete Figur hat ueberall eine."""
    w, h = img.size
    out = img.copy()
    src = img.load()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                    dst[x, y] = color + (255,)
                    break
    return out

def block_size(img, limit=16):
    """Wie gross ein gemalter "Pixel" im erzeugten Bild ist.

    Pixelart-Modelle arbeiten auf 512 und malen dort Bloecke. Wer das
    ignoriert und einfach skaliert, trifft die Blockkanten nicht und bekommt
    Matsch.

    Gemessen wird, ob die FARBWECHSEL auf ein Raster fallen: bei der
    richtigen Blockgroesse liegen fast alle Wechsel auf Vielfachen davon.
    (Die Wechsel bloss zu zaehlen bevorzugt immer die kleinste Groesse --
    darauf bin ich einmal hereingefallen.)
    """
    px = img.convert("RGB").load()
    w, h = img.size
    changes = set()
    for y in range(0, h, max(1, h // 96)):
        for x in range(1, w):
            if px[x, y] != px[x - 1, y]:
                changes.add(x)
    for y in range(1, h):
        for x in range(0, w, max(1, w // 96)):
            if px[x, y] != px[x, y - 1]:
                changes.add(y)
    if not changes:
        return 1
    best = 1
    for b in range(2, limit + 1):
        if w % b or h % b:
            continue
        aligned = sum(1 for c in changes if c % b == 0)
        if aligned / len(changes) > 0.95:
            best = b            # groesstes Raster gewinnt, das noch passt
    return best

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("quelle")
    ap.add_argument("ziel")
    ap.add_argument("--hoehe", type=int, default=48,
                    help="Zielhoehe in Pixeln (Breite folgt dem Seitenverhaeltnis)")
    ap.add_argument("--winkel", type=float, default=0.0,
                    help="Drehung in Grad, gegen den Uhrzeigersinn")
    ap.add_argument("--toleranz", type=int, default=90,
                    help="wie grosszuegig der Hintergrund entfernt wird")
    ap.add_argument("--ohne-umriss", action="store_true")
    ap.add_argument("--bloecke", action="store_true",
                    help="Blockgroesse des erzeugten Bildes erkennen und exakt "
                         "darauf herunterrechnen (fuer 512er Pixelart-Modelle)")
    args = ap.parse_args()

    img = Image.open(args.quelle)
    if args.bloecke:
        b = block_size(img)
        print("Blockgroesse erkannt: %d" % b)
        img = img.resize((img.size[0] // b, img.size[1] // b), Image.NEAREST)
    img = key_out(img, args.toleranz)
    if args.winkel:
        img = img.rotate(args.winkel, resample=Image.BICUBIC, expand=True)
    box = img.getbbox()
    if box is None:
        sys.exit("nach dem Freistellen ist nichts uebrig -- Toleranz zu hoch?")
    img = img.crop(box)
    scale = args.hoehe / img.size[1]
    img = img.resize((max(1, round(img.size[0] * scale)), args.hoehe), Image.LANCZOS)
    img = snap(img, palette_of(os.path.join(ROOT, "core", "palette.gd")))
    if not args.ohne_umriss:
        img = outline(img, (26, 35, 32))
    img.save(args.ziel)
    print("%s -> %s  %dx%d" % (args.quelle, args.ziel, img.size[0], img.size[1]))

if __name__ == "__main__":
    main()
