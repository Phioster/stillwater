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
SOURCE = os.path.join(ROOT, "assets", "source", "rod_45.png")
OUT = os.path.join(ROOT, "assets", "art")

## Die drei Varianten faerben nur den Schaft um. Kork und Messing bleiben --
## eine Silberrute mit silbernem Griff waere ein Barren, keine Rute.
SHAFT_TONES = [None, "6b4a2c", "b9c3c8"]

## So weit wird die Faust in Rutenrichtung abgetastet. Keine Hand ist
## breiter; ein groesseres Fenster liefe beim Wurf in die Haare weiter.
HAND_REACH = 14
## Die Vorlage ist als eigenstaendiges Bild gezeichnet und fuellt ihre
## Leinwand -- der Korkgriff war zehn Pixel dick, die ganze Faust nur zwoelf.
## Auf 0.7 verkleinert sind es sieben, und die Rute liegt IN der Hand statt
## neben ihr. Weiter herunter ging nicht: bei 0.6 zerfaellt die Rolle.
SCALE = 0.7
## Verkleinern kuerzt die Rute mit, und kurz sah sie falsch aus. Der Schaft
## wird deshalb entlang seiner Achse wieder gestreckt -- nur der Schaft, die
## Dicke bleibt. Fuenfundzwanzig Schritte bringen sie auf ihre alte Laenge.
STRETCH = 25
## Wo gestreckt wird: drei Stellen im glatten Schaft, zwischen den Ringen.
## An einer Stelle allein klafft eine Luecke, und ueber Ring oder Rolle
## gestreckt werden die oval.
STRETCH_CUTS = [15, 42, 59]
## Wie weit das Griffende hinten aus der Faust schaut.
STUB = 5
## Getastet wird NUR auf der Hautebene. Beim Wurf haelt sie die Rute neben
## dem Kopf, und ueber den ganzen Umriss zu tasten lief durch den Zopf
## weiter -- dann wurde die halbe Rute abgeschnitten.
SKIN = ["char_skin_0"]
## Beschnitten wird dagegen am ganzen Umriss: das Griffende laeuft hinter der
## Faust ueber den Unterarm, und dort gehoert es nach HINTEN.
SILHOUETTE = ["char_skin_0", "char_pants_0", "char_shirt_0",
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

def shrink(img):
    """Verkleinert die Vorlage und holt die Farben zurueck.

    Beim Verkleinern mischt LANCZOS Zwischentoene an jede Kante. Jeder Pixel
    wird deshalb auf die naechste Farbe der Vorlage zurueckgesetzt, und was
    halb durchsichtig geworden ist, faellt weg -- sonst franst die Rute aus.
    """
    palette = [c for n, c in img.convert("RGB").getcolors(1 << 16) if n]
    n = max(1, round(img.size[0] * SCALE))
    m = max(1, round(img.size[1] * SCALE))
    out = img.resize((n, m), Image.LANCZOS)
    px = out.load()
    for y in range(m):
        for x in range(n):
            r, g, b, a = px[x, y]
            if a < 110:
                px[x, y] = (0, 0, 0, 0)
                continue
            best = min(palette, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2
                       + (c[2] - b) ** 2)
            px[x, y] = best + (255,)
    return out

def shade_cork(img, cork):
    """Gibt dem Korkgriff eine zweite, dunklere Farbe an der Unterseite.

    Die Vorlage hat fuer den Kork genau EINEN Ton -- als Block sieht der
    flach aus, waehrend der Schaft schon Glanz und Schatten hat.
    """
    dark = tuple(int(c * 0.68) for c in cork)
    px = img.load()
    w, h = img.size
    slices = {}
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and px[x, y][:3] == cork:
                slices.setdefault(x - y, []).append((x, y))
    for pts in slices.values():
        # Quer zur Rute ist "unten" die Richtung wachsender Summe x+y.
        for x, y in sorted(pts, key=lambda p: -(p[0] + p[1]))[:2]:
            px[x, y] = dark + (255,)
    return img

def shade_tip(img, thin, mid, dark):
    """Nimmt der Spitze das Grelle.

    Wo die Rute nur noch zwei Pixel dick ist, war einer davon der HELLSTE
    Schaftton -- und er sprang von Scheibe zu Scheibe die Seite. Als duenne
    Linie gelesen war das ein helles Flimmern statt einer Rutenspitze. Jetzt
    liegt oben der mittlere Ton und unten der dunkle, in jeder Scheibe
    gleich: eine Lichtrichtung, zwei Farben, dunkler als vorher.
    """
    px = img.load()
    w, h = img.size
    slices = {}
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                slices.setdefault(x - y, []).append((x, y))
    for pts in slices.values():
        if len(pts) != 2:
            continue
        if any(px[x, y][:3] not in thin for x, y in pts):
            continue
        top, bottom = sorted(pts, key=lambda p: p[0] + p[1])
        px[top] = mid + (255,)
        px[bottom] = dark + (255,)
        # Und darueber der Umriss. Unten steht er schon (der dunkle Ton IST
        # der Umrisston); oben lag der Schaft blank am Hintergrund. Innerhalb
        # einer Scheibe geht "hoeher" um (-1,-1).
        ax, ay = top[0] - 1, top[1] - 1
        if 0 <= ax < w and 0 <= ay < h and px[ax, ay][3] == 0:
            px[ax, ay] = dark + (255,)
    return img

def gild_tip(img, gold, gold_dark, span=9):
    """Faerbt den vordersten Ring gelbgold statt braun.

    Der Ring an der Spitze trug in der Vorlage die braunen Toene der
    Wicklung und verschwand dadurch fast im Schaft.
    """
    px = img.load()
    w, h = img.size
    warm = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and r - b > 25 and 0.299 * r + 0.587 * g + 0.114 * b > 30:
                warm.append((x, y))
    if not warm:
        return img
    edge = max(x - y for x, y in warm)
    ring = [(x, y) for x, y in warm if x - y > edge - span]
    for x, y in ring:
        # Oben hell, unten dunkel -- dieselbe Lichtrichtung wie am Schaft.
        above = px[x - 1, y - 1] if x and y else (0, 0, 0, 0)
        px[x, y] = (gold if above[3] == 0 else gold_dark) + (255,)
    return img

def lengthen(img, steps, cuts):
    """Streckt die Rute entlang ihrer Achse, ohne sie dicker zu machen.

    Die Rute laeuft genau diagonal, also ist eine Scheibe quer zu ihr die
    Menge der Pixel mit gleichem x-y. Gestreckt wird, indem an ein paar
    Stellen solche Scheiben verdoppelt werden und alles dahinter um (1,-1)
    weiterrueckt. Ringe, Rolle und Kork bleiben dabei Pixel fuer Pixel wie
    gezeichnet -- ein Verzerren des ganzen Bildes haette die Rolle zum Ei
    gemacht.
    """
    if steps <= 0:
        return img
    share = [steps // len(cuts)] * len(cuts)
    for i in range(steps - sum(share)):
        share[i] += 1
    px = img.load()
    w, h = img.size
    src = {}
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                src.setdefault(x - y, []).append((x, y, px[x, y]))
    out = Image.new("RGBA", (w + 2 * steps, h + 2 * steps), (0, 0, 0, 0))
    q = out.load()

    def put(x, y, color):
        bx, by = x + steps, y + steps
        if 0 <= bx < out.size[0] and 0 <= by < out.size[1]:
            q[bx, by] = color

    for c in sorted(src):
        moved = sum(t for cut, t in zip(cuts, share) if cut < c - 1)
        for x, y, color in src[c]:
            put(x + moved, y - moved, color)
    for cut, count in zip(cuts, share):
        base = sum(t for other, t in zip(cuts, share) if other < cut)
        for j in range(1, count + 1):
            for c in (cut, cut + 1):
                for x, y, color in src.get(c, []):
                    put(x + base + j, y - base - j, color)
    return out

def tip_of(img):
    """Die Spitze: der Punkt, der auf der Rutenachse am weitesten oben
    rechts liegt."""
    px = img.load()
    best, high = (img.size[0] - 1, 0), None
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if px[x, y][3] == 0:
                continue
            if high is None or x - y > high:
                high, best = x - y, (x, y)
    return best

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

def figure_layers(names):
    """Fertige Figurenblaetter laden."""
    out = []
    for name in names:
        path = os.path.join(OUT, "%s.png" % name)
        if os.path.exists(path):
            img = Image.open(path).convert("RGBA")
            out.append((img, img.load()))
    return out

def skin_run(layers, frame, anchor, step, size):
    """Wie weit die Hand ab dem Anker in Richtung `step` reicht.

    Getastet und nicht geschaetzt: die Hand steht in jeder Pose woanders und
    ist beim Wurf anders gedreht.
    """
    ax, ay = anchor
    reach, miss = 0, 0
    for k in range(HAND_REACH + 1):
        x = int(round(ax + step.real * k))
        y = int(round(ay + step.imag * k))
        if not (0 <= x < size and 0 <= y < size):
            break
        if any(lp[frame * size + x, y][3] > 0 for _, lp in layers):
            reach, miss = k, 0
        else:
            # Ein Loch ueberspringen (der Umriss hat Luecken), zwei nicht:
            # sonst laeuft der Taster durch die Luft weiter in den naechsten
            # Koerperteil und schneidet die halbe Rute ab.
            miss += 1
            if miss > 1:
                break
    return reach

def cut_at_hand(sheet, frame, anchor, direction, front, back, size, body):
    """Nimmt die Rute dort weg, wo die Faust sie verdeckt.

    Zwei Schnitte, beide senkrecht auf der Rute und deshalb gerade: vor der
    Faust steht die Rute, hinter ihr schaut ein kurzer Stummel Griffende
    heraus. Ohne Stummel steckt der Griff ganz in der Faust; mit dem ganzen
    Griffende lag er quer ueber dem Unterarm.
    """
    ox = frame * size
    ax, ay = anchor
    px = sheet.load()
    for y in range(size):
        for x in range(size):
            if px[ox + x, y][3] == 0:
                continue
            along = (x - ax) * direction.real + (y - ay) * direction.imag
            if back <= along < front or along < back - STUB:
                px[ox + x, y] = (0, 0, 0, 0)
            elif along < back and any(lp[ox + x, y][3] > 0 for _, lp in body):
                # Der Stummel liegt hinter der Figur, nicht auf ihr. Pixel
                # fuer Pixel am Umriss beschnitten -- ein gerader Schnitt
                # koennte das nicht, der Unterarm laeuft ja quer dazu.
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

    steps = int(length * 3)
    for i in range(steps + 1):
        t = i / steps
        p = a + (b - a) * t
        thick = 6 if t < 0.6 else 4
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
        for k in range(3):
            put(p + down * k, tones["brass"])
    reel = a + (b - a) * 0.24 + down * 7
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            d = math.hypot(dx, dy)
            if d <= 5.5:
                put(reel + complex(dx, dy),
                    tones["outline"] if d > 4.0 else tones["shaft"])

def main():
    rod = Image.open(SOURCE).convert("RGBA")
    size = read_int("FRAME_SIZE")
    frames = read_int("FRAMES")
    idle = read_int("CAST_START")   # Ruhelauf UND Blinzeln tragen die Vorlage
    anchors = read_ints("ROD_ANCHOR")
    tips = read_ints("ROD_TIP_OFF")
    skin = figure_layers(SKIN)
    body = figure_layers(SILHOUETTE)
    groups = classify(rod)
    base = {
        "cork": average(groups["cork"], (140, 90, 50)),
        "brass": average(groups["brass"], (200, 160, 70)),
        "outline": average(groups["outline"], (16, 16, 20)),
        "shaft": average(groups["shaft"], (70, 76, 86)),
    }

    thin = set(groups["shaft"]) | set(groups["outline"])
    mid = Counter(groups["shaft"]).most_common(1)[0][0]
    dark = Counter(groups["outline"]).most_common(1)[0][0]
    golds = Counter(groups["brass"]).most_common()
    gold = max(g for g, _ in golds)          # der hellste Messington
    gold_dark = min(g for g, _ in golds)
    small = lengthen(
        gild_tip(shade_tip(shade_cork(shrink(rod), base["cork"]),
                           thin, mid, dark), gold, gold_dark),
        STRETCH, STRETCH_CUTS)
    gx, gy = grip_of(small)
    tx, ty = tip_of(small)
    print("ROD_TIP_OFF Ruhelauf: Vector2i(%d, %d)" % (tx - gx, ty - gy))

    for variant, tone in enumerate(SHAFT_TONES):
        target = tuple(int(tone[i:i + 2], 16) for i in (0, 2, 4)) if tone else None
        sheet = Image.new("RGBA", (size * frames, size), (0, 0, 0, 0))
        art = small.copy()
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
            d = complex(tips[f][0], tips[f][1])
            d = d / abs(d)
            front = skin_run(skin, f, anchors[f], d, size)
            back = -skin_run(skin, f, anchors[f], -d, size)
            cut_at_hand(sheet, f, anchors[f], d, front, back, size, body)
        sheet.save(os.path.join(OUT, "char_rod_%d.png" % variant))
    print("%d Rutenblaetter geschrieben" % len(SHAFT_TONES))

if __name__ == "__main__":
    main()
