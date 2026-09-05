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
der Ankerpunkt traegt den Schwerpunkt des Korks. Alles, was hinter der Faust
liegt, wird abgeschnitten -- mit EINEM geraden Schnitt quer zur Rute, dort
wo die Faust in Rutenrichtung endet. Ein Schnitt entlang des Figurenumrisses
sah aus wie abgenagt, und das Griffende lag dann quer ueber dem Unterarm.
Wie weit die Faust reicht, wird an den fertigen Figurenblaettern abgetastet
-- tools/import_character.py muss also vorher gelaufen sein.

    python3 tools/import_rod.py
"""
import math
import os
import re
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSE = os.path.join(ROOT, "core", "angler_pose.gd")
SOURCE = os.path.join(ROOT, "assets", "source", "rod_flat_raw.png")
OUT = os.path.join(ROOT, "assets", "art")

## Die drei Varianten faerben nur den Schaft um. Kork und Messing bleiben --
## eine Silberrute mit silbernem Griff waere ein Barren, keine Rute.
SHAFT_TONES = [None, "6b4a2c", "b9c3c8"]

## Halbe Faustbreite: so weit deckt die Hand die Rute ab.
HAND = 7
## Wie weit das Griffende hinten aus der Faust schaut.
STUB = 4
## Griff bis Spitze im fertigen Bild -- siebzig Prozent der Koerperhoehe.
## Die Vorlage ist gut zwei Meter lang gezeichnet; hier wird sie darauf
## gebracht, und zwar EINMAL: alle sechs Winkel tragen dieselbe Laenge.
## Frueher streckte jede Wurfpose die Rute auf ihren eigenen Versatz, und
## sie wurde waehrend des Wurfs sichtbar laenger und wieder kuerzer.
LENGTH = 140
## Wie viele Farben die verkleinerte Rute behaelt. Das Verkleinern mischt
## Zwischentoene an jede Kante; ohne das Zurueckbinden franst sie aus.
COLORS = 10

def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]

def read_ints(name):
    head = "const %s: Array[Vector2i] = [" % name
    text = open(POSE, encoding="utf-8").read()
    i = text.index(head) + len(head)
    j = text.index("]", i)
    return [(int(a), int(b)) for a, b in
            re.findall(r"Vector2i\((-?\d+),\s*(-?\d+)\)", text[i:j])]

def read_vec(name):
    text = open(POSE, encoding="utf-8").read()
    m = re.search(r"const %s: Vector2i = Vector2i\((-?\d+),\s*(-?\d+)\)" % name, text)
    return (int(m.group(1)), int(m.group(2)))

def read_flat(name):
    """Eine flache Array[int]-Konstante lesen."""
    head = "const %s: Array[int] = [" % name
    text = open(POSE, encoding="utf-8").read()
    i = text.index(head) + len(head)
    return [int(v) for v in re.findall(r"-?\d+", text[i:text.index("]", i)])]

def read_int(name):
    text = open(POSE, encoding="utf-8").read()
    return int(re.search(r"const %s: int = (\d+)" % name, text).group(1))

def palette_of(img, k):
    """k-Means ueber die deckenden Pixel -- die Palette der Rute."""
    px = img.load()
    pts = [px[x, y][:3] for y in range(img.size[1]) for x in range(img.size[0])
           if px[x, y][3] > 128]
    step = max(1, len(pts) // 4000)
    sample = pts[::step]
    centres = [sample[i * len(sample) // k] for i in range(k)]
    for _ in range(20):
        buckets = [[] for _ in range(k)]
        for c in sample:
            j = min(range(k), key=lambda i: sum(
                (c[t] - centres[i][t]) ** 2 for t in range(3)))
            buckets[j].append(c)
        for i, b in enumerate(buckets):
            if b:
                centres[i] = tuple(round(sum(c[t] for c in b) / len(b))
                                   for t in range(3))
    return centres

def snap(img, scale):
    """Verkleinern und auf wenige Farben binden -- das gibt die harten
    Pixelkanten zurueck, die das Verkleinern verwischt."""
    small = img.resize((max(1, round(img.size[0] * scale)),
                        max(1, round(img.size[1] * scale))), Image.LANCZOS)
    pal = palette_of(small, COLORS)
    out = Image.new("RGBA", small.size, (0, 0, 0, 0))
    sp, op = small.load(), out.load()
    for y in range(small.size[1]):
        for x in range(small.size[0]):
            r, g, b, a = sp[x, y]
            if a <= 128:
                continue
            near = min(pal, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2
                       + (c[2] - b) ** 2)
            op[x, y] = (near[0], near[1], near[2], 255)
    return out

def prepare(img):
    """Die gezeichnete Rute auf Spielgroesse bringen.

    Die Vorlage ist gemalt und nicht gerastert: weiche Kanten, zehntausende
    Zwischentoene. Verkleinern allein macht daraus keine Pixelart -- erst das
    Binden auf wenige Farben gibt wieder harte Kanten. Halb durchsichtige
    Pixel fallen dabei ganz weg, sonst franst die Rute aus.
    """
    px = img.load()
    xs = [x for y in range(img.size[1]) for x in range(img.size[0])
          if px[x, y][3] > 128]
    ys = [y for y in range(img.size[1]) for x in range(img.size[0])
          if px[x, y][3] > 128]
    img = img.crop((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    gx, gy = grip_of(img)
    tx, ty = tip_of(img)
    scale = LENGTH / math.hypot(tx - gx, ty - gy)
    # Nachgemessen und korrigiert, und zwar am FERTIGEN Bild: Verkleinern und
    # Farbbinden verschieben Griff und Spitze um ein paar Pixel, und der
    # erste Massstab traf die Laenge um acht Prozent daneben. Ungenau bliebe
    # sie nicht -- sweep_rod streckt sie sonst nachtraeglich, und dabei
    # wuerden Kork und Rolle mitgezerrt.
    out = None
    for _ in range(8):
        out = snap(img, scale)
        ax, ay = grip_of(out)
        bx, by = tip_of(out)
        got = math.hypot(bx - ax, by - ay)
        if abs(got - LENGTH) <= 0.5:
            break
        scale *= LENGTH / got
    return out

def tip_of(img):
    """Die Spitze: das rechte Ende. Die Vorlage liegt waagerecht (siehe
    check_flat), der Griff links, die Spitze rechts."""
    px = img.load()
    for x in range(img.size[0] - 1, -1, -1):
        col = [y for y in range(img.size[1]) if px[x, y][3] > 128]
        if col:
            return (x, sum(col) // len(col))
    return (img.size[0] - 1, img.size[1] // 2)

def butt_of(img):
    """Das Griffende: das linke Ende."""
    px = img.load()
    for x in range(img.size[0]):
        col = [y for y in range(img.size[1]) if px[x, y][3] > 128]
        if col:
            return (x, sum(col) // len(col))
    return (0, img.size[1] // 2)

def check_flat(img):
    """Bricht ab, wenn die Vorlage nicht waagerecht liegt.

    Die ganze Rechnung darunter -- Profil, Griff, Spitze -- setzt das voraus.
    Eine schraege Vorlage wuerde stillschweigend eine krumme Rute ergeben,
    und das faellt erst im Spiel auf.
    """
    px = img.load()
    mids = []
    for x in range(img.size[0]):
        col = [y for y in range(img.size[1]) if px[x, y][3] > 128]
        if col:
            mids.append((x, (col[0] + col[-1]) / 2.0))
    xs = [m[0] for m in mids]
    ys = [m[1] for m in mids]
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    var = sum((x - mx) ** 2 for x in xs)
    slope = sum((x - mx) * (y - my) for x, y in mids) / var
    angle = math.degrees(math.atan(slope))
    if abs(angle) > 2.0:
        raise SystemExit(
            "Die Vorlage liegt %.1f Grad schraeg. Sie muss waagerecht "
            "gezeichnet sein -- siehe assets/source/rod_flat_raw.png." % angle)
    return angle

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

def close_gaps(sheet, frame, grip, tip_off, size):
    """Schliesst Ein-Pixel-Loecher auf der Rutenachse.

    Vorne ist der Schaft nur noch einen Pixel dick, und eine Ein-Pixel-Linie
    zerfaellt beim Drehen in einzelne Punkte -- gemessen: die letzten zwanzig
    Pixel jeder gedrehten Rute hatten drei bis vier Loecher. Aufgefuellt wird
    mit der Farbe des vorigen Achsenpunktes, die Rute wird dadurch nirgends
    dicker.
    """
    ox = frame * size
    gx, gy = grip
    length = math.hypot(tip_off[0], tip_off[1])
    ux, uy = tip_off[0] / length, tip_off[1] / length
    px = sheet.load()
    last = None
    for k in range(int(length) + 1):
        x, y = int(round(gx + ux * k)), int(round(gy + uy * k))
        if not (0 <= x < size and 0 <= y < size):
            break
        here = [px[ox + x + dx, y + dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                if 0 <= x + dx < size and 0 <= y + dy < size
                and px[ox + x + dx, y + dy][3] > 0]
        if here:
            last = here[len(here) // 2]
        elif last is not None:
            px[ox + x, y] = last

def cut_hand(sheet, frame, grip, direction, size):
    """Nimmt die Rute dort weg, wo die Faust sie verdeckt.

    Zwei gerade Schnitte, beide senkrecht auf der Rute: vor der Faust steht
    die Rute, dahinter schaut ein kurzer Stummel Griffende heraus.
    Frueher musste das Skript dafuer in jeder Pose die Hand abtasten -- im
    eigenen Rutenbild liegt der Griff immer auf ROD_GRIP, und dort IST die
    Faust. Ein fester Schnitt reicht deshalb fuer alle Posen.
    """
    ox = frame * size
    gx, gy = grip
    px = sheet.load()
    for y in range(size):
        for x in range(size):
            if px[ox + x, y][3] == 0:
                continue
            along = (x - gx) * direction.real + (y - gy) * direction.imag
            if -HAND <= along < HAND or along < -HAND - STUB:
                px[ox + x, y] = (0, 0, 0, 0)

def rod_profile(art):
    """Die Rute als Querschnitt statt als Bild.

    Jeder Pixel bekommt zwei Zahlen: wie weit er auf der Rutenachse vom Griff
    entfernt liegt (t) und wie weit quer dazu (s). In dieser Form laesst sie
    sich in JEDEM Winkel neu zeichnen. Ein fertiges Bild zu drehen macht es
    verwaschen oder ausgefranst -- drei Anlaeufe von Hand, alle verworfen, und
    ein Bildmodell hat die Rute auf Zuruf nicht gedreht, sondern verschoben
    (13 Bilder, Winkel durchgehend 45 bis 49 Grad).

    Der Kork, die Ringe und die Rolle kommen dabei von selbst mit: die Rolle
    haengt im Profil zwanzig Pixel quer zur Achse und bleibt dort, egal wohin
    die Rute zeigt.
    """
    px = art.load()
    w, h = art.size
    gx, gy = grip_of(art)
    tx, ty = tip_of(art)
    length = math.hypot(tx - gx, ty - gy)
    ux, uy = (tx - gx) / length, (ty - gy) / length
    nx, ny = -uy, ux
    grid = {}
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 128:
                vx, vy = x - gx, y - gy
                t = vx * ux + vy * uy
                sp = vx * nx + vy * ny
                grid.setdefault((int(round(t)), int(round(sp))), []).append(
                    (t, sp, px[x, y]))
    return grid, length

## Wie nah ein Zielpixel an einem Profilpunkt liegen muss. Die Profilpunkte
## bilden ein gedrehtes Einheitsgitter, der groesste Abstand ist also die
## halbe Diagonale: 0,71. Etwas Reserve, damit keine Loecher bleiben.
NEAR = 0.8

def sweep_rod(sheet, frame, anchor, tip_off, grid, src_len, size):
    """Zeichnet die Rute in der Richtung dieser Pose.

    Rueckwaerts abgebildet -- fuer jeden Zielpixel wird der naechste
    Profilpunkt gesucht. Vorwaerts blieben Luecken, wo die Achse sich dreht.
    """
    ox = frame * size
    ax, ay = anchor
    length = math.hypot(tip_off[0], tip_off[1])
    ux, uy = tip_off[0] / length, tip_off[1] / length
    nx, ny = -uy, ux
    stretch = length / src_len
    px = sheet.load()
    reach = int(src_len * max(stretch, 1.0)) + 26
    for y in range(max(0, ay - reach), min(size, ay + reach + 1)):
        for x in range(max(0, ax - reach), min(size, ax + reach + 1)):
            vx, vy = x - ax, y - ay
            t = (vx * ux + vy * uy) / stretch
            sp = vx * nx + vy * ny
            best, dist = None, NEAR
            ti, si = int(round(t)), int(round(sp))
            for dt in (-1, 0, 1):
                for ds in (-1, 0, 1):
                    for pt, ps, color in grid.get((ti + dt, si + ds), ()):
                        d = math.hypot(pt - t, ps - sp)
                        if d < dist:
                            dist, best = d, color
            if best is not None:
                px[ox + x, y] = best

def main():
    rod = Image.open(SOURCE).convert("RGBA")
    angle = check_flat(rod)
    art = prepare(rod)
    frames = read_int("FRAMES")
    tips = read_ints("ROD_TIP_OFF")
    size = read_int("ROD_FRAME_SIZE")
    grip_at = read_vec("ROD_GRIP")
    rod_frames = read_int("ROD_FRAMES")
    rod_of = read_flat("ROD_FRAME")

    # Welcher Rutenwinkel zu welchem Rutenbild gehoert. Achtzehn Figurenposen
    # zeigen auf Bild 0 -- im Ruhelauf wandert nur die Hand, nicht der Winkel.
    tip_for = {}
    for f in range(frames):
        tip_for.setdefault(rod_of[f], tips[f])

    for variant, tone in enumerate(SHAFT_TONES):
        target = tuple(int(tone[i:i + 2], 16) for i in (0, 2, 4)) if tone else None
        shown = art.copy()
        if target:
            px = shown.load()
            for y in range(shown.size[1]):
                for x in range(shown.size[0]):
                    if is_shaft(px[x, y]):
                        px[x, y] = tint(px[x, y], target)
        grid, src_len = rod_profile(shown)
        sheet = Image.new("RGBA", (size * rod_frames, size), (0, 0, 0, 0))
        for r in range(rod_frames):
            # JEDES Bild wird aus dem Querschnitt neu gezeichnet, auch das
            # Ruhebild: eine fertige Zeichnung zu drehen macht sie verwaschen.
            sweep_rod(sheet, r, grip_at, tip_for[r], grid, src_len, size)
            close_gaps(sheet, r, grip_at, tip_for[r], size)
            d = complex(tip_for[r][0], tip_for[r][1])
            cut_hand(sheet, r, grip_at, d / abs(d), size)
        sheet.save(os.path.join(OUT, "char_rod_%d.png" % variant))
        if variant == 0:
            print("Vorlage %.1f Grad schief, auf %dx%d gebracht, "
                  "Griff bis Spitze %.1f Px"
                  % (angle, art.size[0], art.size[1], src_len))
    print("%d Rutenblaetter geschrieben, je %d Bilder à %dx%d"
          % (len(SHAFT_TONES), rod_frames, size, size))

if __name__ == "__main__":
    main()
