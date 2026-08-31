#!/usr/bin/env python3
"""Baut die Rutenblaetter aus der gezeichneten Vorlage.

Die Rute kommt aus `assets/source/rod_45.png` -- einem 100x100-Sprite, das
diagonal von unten links (Korkgriff) nach oben rechts (Spitze) laeuft.

Die sechs RUHEPOSEN bekommen dieses Bild **eins zu eins**: die Vorlage ist
genau so lang wie die Rute im Spiel, es wird nichts skaliert und nichts
gedreht. Die vier WURFPOSEN zeigen in andere Richtungen; die werden in
denselben Farben nachgezeichnet. Ein fertiges Pixelbild in einen anderen
Winkel zu drehen macht es verwaschen oder ausgefranst -- drei Anlaeufe,
alle verworfen.

    python3 tools/import_rod.py
"""
import math
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSE = os.path.join(ROOT, "core", "angler_pose.gd")
SOURCE = os.path.join(ROOT, "assets", "source", "rod_45.png")
OUT = os.path.join(ROOT, "assets", "art")

## Die drei Varianten faerben nur den Schaft um. Kork und Messing bleiben --
## eine Silberrute mit silbernem Griff waere ein Barren, keine Rute.
SHAFT_TONES = [None, "6b4a2c", "b9c3c8"]

def read_ints(name):
    head = "const %s: Array[Vector2i] = [" % name
    text = open(POSE, encoding="utf-8").read()
    i = text.index(head) + len(head)
    j = text.index("]", i)
    return [(int(a), int(b)) for a, b in
            re.findall(r"Vector2i\((-?\d+),\s*(-?\d+)\)", text[i:j])]

def read_int(name):
    text = open(POSE, encoding="utf-8").read()
    return int(re.search(r"const %s: int = (\d+)" % name, text).group(1))

def classify(img):
    """Teilt die Palette der Vorlage in Kork, Messing, Umriss und Schaft.

    Ueber Farbton und Helligkeit statt ueber eine Liste: die Vorlage kann
    neu erzeugt werden, ohne dass hier Werte nachgetragen werden muessen.
    """
    px = img.load()
    groups = {"cork": [], "brass": [], "outline": [], "shaft": []}
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            warm = r - b
            if lum < 45:
                groups["outline"].append((r, g, b))
            elif warm > 55 and lum < 120:
                groups["cork"].append((r, g, b))
            elif warm > 45:
                groups["brass"].append((r, g, b))
            else:
                groups["shaft"].append((r, g, b))
    return groups

def grip_of(img):
    """Das Griffende der Vorlage: der Punkt, der auf der Rutenachse am
    weitesten unten links liegt."""
    px = img.load()
    best, low = (0, img.size[1] - 1), None
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if px[x, y][3] == 0:
                continue
            if low is None or x - y < low:
                low, best = x - y, (x, y)
    return best

def average(colors, fallback):
    if not colors:
        return fallback
    n = len(colors)
    return tuple(sum(c[i] for c in colors) // n for i in range(3))

def tint(pixel, target):
    r, g, b, a = pixel
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    f = 0.55 + 0.9 * lum
    return (min(255, int(target[0] * f)), min(255, int(target[1] * f)),
            min(255, int(target[2] * f)), a)

def is_shaft(pixel):
    r, g, b, a = pixel
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    return a > 0 and lum >= 45 and (r - b) <= 45

def draw_cast(sheet, frame, anchor, tip, size, tones):
    """Zeichnet die Rute fuer eine Wurfpose -- Pixel fuer Pixel."""
    ox = frame * size
    a = complex(*anchor)
    b = complex(anchor[0] + tip[0], anchor[1] + tip[1])
    direction = (b - a) / abs(b - a)
    down = complex(-direction.imag, direction.real)
    if down.imag < 0:
        down = -down
    length = abs(b - a)
    px = sheet.load()

    def put(p, color):
        x, y = int(round(p.real)), int(round(p.imag))
        if 0 <= x < size and 0 <= y < size:
            px[ox + x, y] = color + (255,)

    steps = int(length * 3)
    for i in range(steps + 1):
        t = i / steps
        p = a + (b - a) * t
        thick = 8 if t < 0.6 else 6
        for k in range(thick):
            q = p + down * k
            if t < 0.20:
                put(q, tones["cork"])
            elif k == 0:
                put(q, tones["shine"])
            elif k == thick - 1:
                put(q, tones["shadow"])
            else:
                put(q, tones["shaft"])
        put(p - down, tones["outline"])
        put(p + down * thick, tones["outline"])
    for r in (0.42, 0.62, 0.82):
        p = a + (b - a) * r
        for k in range(4):
            put(p + down * k, tones["brass"])
    reel = a + (b - a) * 0.24 + down * 10
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            d = math.hypot(dx, dy)
            if d <= 7.5:
                put(reel + complex(dx, dy),
                    tones["outline"] if d > 5.5 else tones["shaft"])

def main():
    rod = Image.open(SOURCE).convert("RGBA")
    size = read_int("FRAME_SIZE")
    frames = read_int("FRAMES")
    idle = read_int("IDLE_FRAMES")
    anchors = read_ints("ROD_ANCHOR")
    tips = read_ints("ROD_TIP_OFF")
    groups = classify(rod)
    base = {
        "cork": average(groups["cork"], (140, 90, 50)),
        "brass": average(groups["brass"], (200, 160, 70)),
        "outline": average(groups["outline"], (16, 16, 20)),
        "shaft": average(groups["shaft"], (70, 76, 86)),
    }

    for variant, tone in enumerate(SHAFT_TONES):
        target = tuple(int(tone[i:i + 2], 16) for i in (0, 2, 4)) if tone else None
        sheet = Image.new("RGBA", (size * frames, size), (0, 0, 0, 0))
        art = rod.copy()
        if target:
            px = art.load()
            for y in range(art.size[1]):
                for x in range(art.size[0]):
                    if is_shaft(px[x, y]):
                        px[x, y] = tint(px[x, y], target)
        # Ruheposen: die Vorlage sitzt mit ihrem GRIFF auf dem Ankerpunkt --
        # nicht mit ihrer Bildecke. Die Rolle steht unten aus dem Bild
        # heraus, die Ecke liegt also woanders als das Griffende.
        gx, gy = grip_of(art)
        for f in range(idle):
            ax, ay = anchors[f]
            sheet.alpha_composite(art, (f * size + ax - gx, ay - gy))
        tones = dict(base)
        if target:
            tones["shaft"] = target
        tones["shine"] = tuple(min(255, int(c * 1.25)) for c in tones["shaft"])
        tones["shadow"] = tuple(int(c * 0.6) for c in tones["shaft"])
        for f in range(idle, frames):
            draw_cast(sheet, f, anchors[f], tips[f], size, tones)
        sheet.save(os.path.join(OUT, "char_rod_%d.png" % variant))
    print("%d Rutenblaetter geschrieben" % len(SHAFT_TONES))

if __name__ == "__main__":
    main()
