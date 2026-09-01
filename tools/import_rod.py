#!/usr/bin/env python3
"""Baut die Rutenblaetter aus der gezeichneten Vorlage.

Die Rute kommt aus `assets/source/rod_45.png` -- einem 100x100-Sprite, das
diagonal von unten links (Korkgriff) nach oben rechts (Spitze) laeuft.

Die Ruheposen und das Blinzeln bekommen dieses Bild **eins zu eins**: die Vorlage ist
genau so lang wie die Rute im Spiel, es wird nichts skaliert und nichts
gedreht. Die vier WURFPOSEN zeigen in andere Richtungen; die werden in
denselben Farben nachgezeichnet. Ein fertiges Pixelbild in einen anderen
Winkel zu drehen macht es verwaschen oder ausgefranst -- drei Anlaeufe,
alle verworfen.

Die Hand fasst die Rute in der MITTE des Korkgriffs, nicht an ihrem Ende:
der Ankerpunkt traegt den Schwerpunkt des Korks, das Griffende steht hinten
aus der Faust heraus. Und sie fasst DURCH: wo die Figur eine Faust hat, wird
die Rute weggenommen, sonst liegt sie wie ein Brett obenauf statt in der
Hand. Dafuer liest dieses Werkzeug die fertigen Figurenblaetter --
tools/import_character.py muss also vorher gelaufen sein.

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

## Wie weit die Faust um den Ankerpunkt herum reicht -- an der gezeichneten
## Figur abgelesen (nach hinten sechs Pixel, nach vorn acht, oben und unten
## je sieben). Nur in diesem Fenster wird die Rute weggenommen: weiter unten
## kreuzt sie beim Wurf den Koerper, und dort gehoert sie nach vorn.
HAND_BOX = (-6, -7, 8, 7)
## Wie weit das Griffende bei den gemalten Wurfposen hinter der Hand steht.
## Bei der gezeichneten Vorlage sind es fuenfzehn Pixel.
BUTT = 15
## Aus diesen Blaettern entsteht der Umriss der Figur.
LAYER_SHEETS = ["char_skin_0", "char_pants_0", "char_shirt_0",
                "char_hair_0", "char_base_0"]

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

def butt_of(img):
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

def grip_of(img):
    """Die Mitte des Korkgriffs -- dort liegt die Hand.

    Nicht ueber die Farbe allein: die Messingringe am Schaft sind genauso
    warm wie der Kork. Vom Griffende aus durch die warmen Pixel fluten
    findet den zusammenhaengenden Korkblock und sonst nichts.
    """
    px = img.load()
    w, h = img.size
    warm = {(x, y) for y in range(h) for x in range(w)
            if px[x, y][3] and (px[x, y][0] - px[x, y][2]) > 45}
    if not warm:
        return butt_of(img)
    bx, by = butt_of(img)
    start = min(warm, key=lambda p: (p[0] - bx) ** 2 + (p[1] - by) ** 2)
    blob, stack = {start}, [start]
    while stack:
        x, y = stack.pop()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n in warm and n not in blob:
                    blob.add(n)
                    stack.append(n)
    return (round(sum(p[0] for p in blob) / len(blob)),
            round(sum(p[1] for p in blob) / len(blob)))

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

def figure_layers():
    """Die fertigen Figurenblaetter -- fuer den Umriss der Faust."""
    out = []
    for name in LAYER_SHEETS:
        path = os.path.join(OUT, "%s.png" % name)
        if os.path.exists(path):
            img = Image.open(path).convert("RGBA")
            out.append((img, img.load()))
    return out

def cut_hand(sheet, frame, anchor, size, layers):
    """Nimmt die Rute dort weg, wo die Faust ist.

    Die Rute liegt als oberste Ebene ueber der Figur. Ohne diesen Schnitt
    liegt sie auch ueber den Fingern -- und dann haelt die Anglerin sie
    nicht, sie klebt an ihr.
    """
    ox = frame * size
    ax, ay = anchor
    px = sheet.load()
    x0, y0, x1, y1 = HAND_BOX
    for y in range(ay + y0, ay + y1 + 1):
        for x in range(ax + x0, ax + x1 + 1):
            if not (0 <= x < size and 0 <= y < size):
                continue
            if any(lp[ox + x, y][3] > 0 for _, lp in layers):
                px[ox + x, y] = (0, 0, 0, 0)

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

    # Das Griffende steht hinten aus der Faust heraus, wie bei der
    # gezeichneten Vorlage. Ohne das waechst die Rute aus der Faust heraus.
    butt = a - direction * BUTT
    steps_butt = BUTT * 3
    for i in range(steps_butt + 1):
        p = butt + (a - butt) * (i / steps_butt)
        for k in range(8):
            put(p + down * k, tones["cork"])
        put(p - down, tones["outline"])
        put(p + down * 8, tones["outline"])

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
    idle = read_int("CAST_START")   # Ruhelauf UND Blinzeln tragen die Vorlage
    anchors = read_ints("ROD_ANCHOR")
    tips = read_ints("ROD_TIP_OFF")
    layers = figure_layers()
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
        for f in range(frames):
            cut_hand(sheet, f, anchors[f], size, layers)
        sheet.save(os.path.join(OUT, "char_rod_%d.png" % variant))
    print("%d Rutenblaetter geschrieben" % len(SHAFT_TONES))

if __name__ == "__main__":
    main()
