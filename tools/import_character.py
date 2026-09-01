#!/usr/bin/env python3
"""Baut die Figurenebenen aus den gezeichneten Vorlagen.

Die Anglerin kommt aus `assets/source/`: ein Ruhebild und fuenf Wurfbilder,
gezeichnete Pixelart in etwa 1400 Pixel Hoehe. Dieses Werkzeug macht daraus
die zwoelf Bilder, die das Spiel braucht:

    0-5   Ruhelauf  -- aus dem Ruhebild abgeleitet (Atmen, Zopf schwingt)
    6     Blinzeln  -- ebenfalls abgeleitet
    7-11  Wurf      -- die fuenf gezeichneten Posen

Der Ruhelauf wird GERECHNET und nicht gezeichnet: ein Bildmodell zeichnet
dieselbe Pose jedes Mal minimal anders, und diese zufaelligen ein bis zwei
Pixel an der Kontur sehen in Bewegung aus, als koche die Figur. Was sich
hier bewegt, bewegt sich absichtlich; der Rest steht bombenfest.

Die Kosmetik braucht Ebenen, das flache Bild hat keine. Zerlegt wird
deshalb ueber die PALETTE, nicht ueber die Pixel: achtzehn der dreissig
Farben lassen sich eindeutig einem Koerperteil zuordnen (eine Farbe, die zu
615 von 635 Teilen im Pullover liegt, IST die Pulloverfarbe). Die uebrigen
sind Umriss und Schatten und kommen ueberall vor -- die bekommen eine
eigene Ebene, die nie umgefaerbt wird. Das ist kein Notbehelf: ein Umriss
soll dunkel bleiben, egal welche Farbe der Pullover hat.

    python3 tools/import_character.py
"""
import os
from collections import Counter, defaultdict

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source")
OUT = os.path.join(ROOT, "assets", "art")

FRAME = 256
IDLE = 6
BLINK = 6
CAST = 5
FRAMES = IDLE + 1 + CAST

## Koerpermass, an dem alle Posen ausgerichtet werden: Scheitel bis Sohle.
## Nicht die Bildhoehe -- der Zopf steht je nach Pose verschieden weit ab.
BODY = 216
SOLE_ROW = 247
SOLE_X = 118

## Farben, aus denen die Varianten gemacht werden. Reihenfolge wie in
## data/cosmetics/.
SKIN_TONES = ["e8be9a", "c68c63", "8d5a3c", "f6ddc4", "5c3826",
              "6f9455", "9fc7d6", "8f8a9c", "f4f6f7"]
SHIRT_TONES = ["3f6fb4", "b4523f", "4a9455", "c8913f", "6b4470",
               "6f7a75", "6b4326", "8f6a2c", "39537f"]
PANTS_TONES = ["6f7a75", "4a3626", "8f6a2c", "6b4470", "39537f", "b4523f"]
HAIR_STYLES = 5

def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]

def is_skin(c):
    return c[0] - c[2] > 48 and lum(c) > 130

def measure(img):
    """Scheitel, Sohle und Sohlenmitte. Der Scheitel wird in der rechten
    Bildhaelfte gesucht -- links haengt der Zopf und der wandert."""
    px = img.load()
    w, h = img.size
    top = next(y for y in range(h)
               if any(px[x, y][3] > 128 for x in range(int(w * 0.45), w)))
    sole = next(y for y in range(h - 1, -1, -1)
                if any(px[x, y][3] > 128 for x in range(w)))
    xs = [x for x in range(w)
          if px[x, sole][3] > 128 or px[x, max(0, sole - 2)][3] > 128]
    return top, sole, (min(xs) + max(xs)) // 2

def prepare(path):
    """Vorlage -> 256er Rahmen: freistellen, auf Koerpermass bringen,
    auf die Fusszeile setzen, Farben zusammenziehen."""
    img = Image.open(path).convert("RGBA")
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a > 128 else (0, 0, 0, 0)
    img = img.crop(img.getbbox())
    top, sole, mid = measure(img)
    scale = BODY / (sole - top)
    img = img.resize((max(1, round(img.size[0] * scale)),
                      max(1, round(img.size[1] * scale))), Image.LANCZOS)
    top, sole, mid = measure(img)
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    frame.alpha_composite(img, (SOLE_X - mid, SOLE_ROW - sole))
    return frame

def shared_palette(frames, colors=30):
    """EINE Palette fuer alle Bilder.

    Jedes Bild fuer sich zu quantisieren gibt jedem seine eigenen Toene --
    in Bewegung flackert die Figur dann, weil dieselbe Stelle von Bild zu
    Bild eine leicht andere Farbe hat.
    """
    strip = Image.new("RGB", (FRAME * len(frames), FRAME), (0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f.convert("RGB"), (i * FRAME, 0), f)
    return strip.quantize(colors=colors, method=Image.MEDIANCUT,
                          dither=Image.NONE)

def apply_palette(img, palette):
    alpha = img.getchannel("A")
    flat = img.convert("RGB").quantize(palette=palette, dither=Image.NONE).convert("RGB")
    flat.putalpha(alpha)
    px = flat.load()
    for y in range(FRAME):
        for x in range(FRAME):
            r, g, b, a = px[x, y]
            px[x, y] = (0, 0, 0, 0) if a < 128 else (r, g, b, 255)
    return flat

## Bis zu dieser Zeile hebt und senkt sich der Oberkoerper beim Atmen.
BREATH_BOUND = 150
## Das Band, in dem der Zopf schwingt: unterhalb des Kinns und oberhalb des
## Rocks. Waagerecht bis zur Koerpermitte -- eine engere Grenze schneidet
## mitten durch die Straehnen und hinterlaesst einen hellen Spalt.
TAIL_BOX = (30, 96, 128, 152)

def breathe(base, step):
    """Ein Ruhebild. Der Oberkoerper hebt und senkt sich um einen Pixel, der
    Zopf schwingt hinterher -- eine Bewegung, kein Zittern."""
    # Deutlich genug, um es zu sehen, klein genug, um nicht zu zappeln:
    # der Oberkoerper geht zwei Pixel hoch und wieder herunter, der Zopf
    # schwingt vier hinterher und laeuft dabei der Brust nach.
    lift = [0, -1, -2, -2, -1, 0][step]
    sway = [0, 2, 3, 4, 3, 1][step]
    img = base.copy()
    if lift:
        # Versetzt DARUEBERKOPIEREN statt die alte Stelle zu leeren: sonst
        # bleibt an der Naht eine leere Zeile stehen, und die sieht im Spiel
        # aus wie ein Riss quer durch die Figur.
        src = base.load()
        dst = img.load()
        for y in range(BREATH_BOUND):
            ty = y + lift
            if 0 <= ty < FRAME:
                for x in range(FRAME):
                    dst[x, ty] = src[x, y]
    if sway:
        # Den Zopf NICHT als Block verschieben -- dann reisst er an der
        # Ansatzstelle vom Kopf weg und hinterlaesst einen hellen Spalt.
        # Stattdessen biegen: oben null Versatz, zur Spitze hin voller.
        x0, y0, x1, y1 = TAIL_BOX
        src = img.load()
        strands = [(x, y) for y in range(y0, y1) for x in range(x0, x1)
                   if src[x, y][3] and lum(src[x, y][:3]) < 110]
        moved = {}
        for x, y in strands:
            t = (y - y0) / float(y1 - y0 - 1)
            dx = int(round(-sway * t))
            moved[(x + dx, y)] = src[x, y]
        for x, y in strands:
            src[x, y] = (0, 0, 0, 0)
        for (x, y), c in moved.items():
            if 0 <= x < FRAME and 0 <= y < FRAME:
                src[x, y] = c
        _close_holes(img)
    return img

def _close_holes(img):
    """Schliesst Loecher, die der schwingende Zopf freilegt.

    In einem flachen Bild verdeckt der Zopf den Koerper dahinter -- schwingt
    er weg, ist dort schlicht nichts gezeichnet. Sichtbar wird das als
    heller Spalt. Gefuellt wird mit der Mehrheitsfarbe der Nachbarn, also
    mit dem Pullover, wenn Pullover drumherum ist.
    """
    px = img.load()
    for _ in range(4):
        holes = []
        for y in range(1, FRAME - 1):
            for x in range(1, FRAME - 1):
                if px[x, y][3]:
                    continue
                near = [px[x + dx, y + dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                        if (dx or dy) and px[x + dx, y + dy][3]]
                if len(near) >= 5:
                    holes.append(((x, y), Counter(near).most_common(1)[0][0]))
        if not holes:
            break
        for (x, y), c in holes:
            px[x, y] = c

## Das Fenster, in dem das Auge sitzt (Rahmenkoordinaten).
EYE_BOX = (108, 52, 168, 98)

def transplant_blink(base, drawn):
    """Nimmt NUR das Auge aus dem gezeichneten Blinzelbild.

    Ein Bildmodell zeichnet auf Zuruf die ganze Figur neu -- gemessen 4838
    abweichende Pixel, davon nur 13 Prozent am Auge. Wuerde man das Bild
    ganz nehmen, sprAenge beim Blinzeln die komplette Figur um. Also erst
    die Koepfe zur Deckung bringen, dann das Augenfenster uebernehmen.
    """
    pa, pb = base.load(), drawn.load()
    best, score = (0, 0), -1
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            hit = 0
            for y in range(30, 100, 2):
                for x in range(96, 176, 2):
                    bx, by = x + dx, y + dy
                    if not (0 <= bx < FRAME and 0 <= by < FRAME):
                        continue
                    if (pa[x, y][3] > 0) == (pb[bx, by][3] > 0):
                        hit += 1
            if hit > score:
                score, best = hit, (dx, dy)
    dx, dy = best
    out = base.copy()
    q = out.load()
    for y in range(EYE_BOX[1], EYE_BOX[3]):
        for x in range(EYE_BOX[0], EYE_BOX[2]):
            bx, by = x + dx, y + dy
            if 0 <= bx < FRAME and 0 <= by < FRAME and pb[bx, by][3]:
                q[x, y] = pb[bx, by]
    return out

def blink(base):
    """Auge zu: die dunkle Flaeche im Gesicht wird Haut, darueber kommt ein
    Wimpernstrich. Ohne den Strich sieht es aus, als fehle das Auge."""
    img = base.copy()
    px = img.load()
    face = [(x, y) for y in range(55, 95) for x in range(110, 160)
            if px[x, y][3] and is_skin(px[x, y])]
    if not face:
        return img
    tone = Counter(px[x, y][:3] for x, y in face).most_common(1)[0][0]
    xs = [p[0] for p in face]
    ys = [p[1] for p in face]
    # Nur die untere Haelfte des Gesichts absuchen: darueber sitzt der Pony,
    # der ist genauso dunkel wie das Auge und wuerde mitgeloescht.
    y0 = (min(ys) + max(ys)) // 2 - 4
    eye = [(x, y) for y in range(y0, max(ys) + 1)
           for x in range(min(xs), max(xs) + 1)
           if px[x, y][3] and lum(px[x, y][:3]) < 90]
    if not eye:
        return img
    # Zusammenhaengende Flaeche um den dunkelsten Punkt -- sonst faengt man
    # den Mundschatten mit ein.
    seed = min(eye, key=lambda p: lum(px[p[0], p[1]][:3]))
    known = set(eye)
    blob = {seed}
    stack = [seed]
    while stack:
        x, y = stack.pop()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n in known and n not in blob:
                    blob.add(n)
                    stack.append(n)
    for x, y in blob:
        px[x, y] = tone + (255,)
    ey = sum(p[1] for p in blob) // len(blob)
    for x in sorted({p[0] for p in blob}):
        px[x, ey] = (46, 30, 30, 255)
    return img

def classify(frames):
    """Ordnet jede Palettenfarbe einem Koerperteil zu -- oder der
    Grundebene, wenn sie ueberall vorkommt."""
    def zone(y):
        if y < 92:
            return "hair"
        if y < 150:
            return "shirt"
        if y < 182:
            return "pants"          # Rock
        if y < 200:
            return "skin"           # nacktes Bein
        return "pants"              # Stiefel gehoeren zur Hosenebene
    votes = defaultdict(Counter)
    for img in frames:
        px = img.load()
        for y in range(FRAME):
            for x in range(FRAME):
                p = px[x, y]
                if p[3]:
                    votes[p[:3]][zone(y)] += 1
    groups = {}
    for col, z in votes.items():
        total = sum(z.values())
        top, share = z.most_common(1)[0]
        if is_skin(col):
            groups[col] = "skin"
        elif lum(col) >= 38 and share / total >= 0.55:
            groups[col] = top
        else:
            groups[col] = "base"
    return groups

def tint(pixel, target):
    r, g, b, a = pixel
    l = lum((r, g, b)) / 255.0
    if l < 0.22:
        return pixel
    f = 0.55 + 0.9 * l
    return (min(255, int(target[0] * f)), min(255, int(target[1] * f)),
            min(255, int(target[2] * f)), a)

def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))

def sheet(frames, groups, want, target=None):
    out = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    for f, img in enumerate(frames):
        px = img.load()
        single = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        q = single.load()
        for y in range(FRAME):
            for x in range(FRAME):
                p = px[x, y]
                if p[3] and groups.get(p[:3]) == want:
                    q[x, y] = tint(p, target) if target else p
        out.alpha_composite(single, (f * FRAME, 0))
    return out

def main():
    idle = prepare(os.path.join(SRC, "angler_idle.png"))
    frames = [breathe(idle, i) for i in range(IDLE)]
    drawn_blink = os.path.join(SRC, "angler_blink.png")
    if os.path.exists(drawn_blink):
        frames.append(transplant_blink(idle, prepare(drawn_blink)))
    else:
        frames.append(blink(idle))
    for i in range(1, CAST + 1):
        frames.append(prepare(os.path.join(SRC, "angler_cast_%d.png" % i)))
    palette = shared_palette(frames)
    frames = [apply_palette(f, palette) for f in frames]
    groups = classify(frames)
    print("Farben: %s" % Counter(groups.values()))

    written = 0
    for i, tone in enumerate(SKIN_TONES):
        sheet(frames, groups, "skin", hexc(tone) if i else None).save(
            os.path.join(OUT, "char_skin_%d.png" % i)); written += 1
    for i in range(HAIR_STYLES):
        sheet(frames, groups, "hair").save(
            os.path.join(OUT, "char_hair_%d.png" % i)); written += 1
    for i, tone in enumerate(SHIRT_TONES):
        sheet(frames, groups, "shirt", hexc(tone) if i else None).save(
            os.path.join(OUT, "char_shirt_%d.png" % i)); written += 1
    for i, tone in enumerate(PANTS_TONES):
        sheet(frames, groups, "pants", hexc(tone) if i else None).save(
            os.path.join(OUT, "char_pants_%d.png" % i)); written += 1
    sheet(frames, groups, "base").save(os.path.join(OUT, "char_base_0.png"))
    written += 1
    print("%d Blaetter geschrieben" % written)

if __name__ == "__main__":
    main()
