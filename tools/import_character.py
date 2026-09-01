#!/usr/bin/env python3
"""Baut die Figurenebenen aus den gezeichneten Vorlagen.

Die Anglerin kommt aus `assets/source/`: ein Streifen mit vier Ruhebildern,
ein Blinzelbild und fuenf Wurfbilder. Dieses Werkzeug macht daraus die zehn
Bilder, die das Spiel braucht:

    0-3   Ruhelauf  -- die vier gezeichneten Bilder des Atemzugs
    4     Blinzeln  -- Auge aus dem gezeichneten Blinzelbild, Rest wie 0
    5-9   Wurf      -- die fuenf gezeichneten Posen

Der Ruhelauf laeuft als Pingpong 0-1-2-3-2-1 (siehe AnglerPose.IDLE_ORDER):
Bild 3 ist der Umkehrpunkt, nicht die Rueckkehr zum Anfang. Direkt von 3 auf
0 zu springen aendert dreimal so viele Umrisspixel wie jeder andere Schritt,
und der Zopf wird sichtbar zurueckgerissen.

Die vier Ruhebilder entstehen in EINER Generierung als ein Streifen. Vier
getrennte Bilder waeren vier leicht verschiedene Figuren -- andere Palette,
andere Proportionen -- und das flackert in Bewegung.

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
IDLE = 4
CAST = 5
FRAMES = IDLE + 1 + CAST

## Koerpermass, an dem alle Posen ausgerichtet werden: Scheitel bis Sohle.
## Nicht die Bildhoehe -- der Zopf steht je nach Pose verschieden weit ab.
## Das faengt nebenbei ab, dass das Bildmodell die Figur von Bild zu Bild
## groesser zeichnet: im Streifen wuchsen selbst die Stiefel um drei Prozent,
## obwohl sie stillstehen sollten. Nach dem Normieren stimmen sie auf ein bis
## zwei Pixel ueberein.
BODY = 216
SOLE_ROW = 247
## Nicht die Rahmenmitte: der Rahmen traegt Figur UND Rute, und die
## gezeichnete Rute steht 97 Pixel rechts von der Hand. Bei 118 stiess sie
## im zweiten Ruhebild aus dem Rahmen und blutete ins naechste Bild.
SOLE_X = 112

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

def split_figures(path, count):
    """Zerlegt einen Streifen in seine Figuren.

    Nicht in gleich breite Felder schneiden: die Zoepfe schwingen ueber die
    Feldgrenze hinweg, im Streifen bis zu 60 Pixel weit. Jede Figur ist aber
    eine zusammenhaengende Flaeche, also wird gefuellt statt geschnitten --
    dann kommt der Zopf mit, egal wo er hinreicht.
    """
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    solid = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 128:
                solid[y * w + x] = 1
    seen = bytearray(w * h)
    blobs = []
    for sy in range(h):
        for sx in range(w):
            if not solid[sy * w + sx] or seen[sy * w + sx]:
                continue
            stack = [(sx, sy)]
            seen[sy * w + sx] = 1
            pts = []
            while stack:
                x, y = stack.pop()
                pts.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and solid[ny * w + nx] \
                            and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            if len(pts) > 5000:
                blobs.append(pts)
    if len(blobs) != count:
        raise SystemExit("%s: %d Figuren gefunden, %d erwartet"
                         % (os.path.basename(path), len(blobs), count))
    # Nach der Sohlenmitte sortieren, nicht nach dem linken Rand: der Zopf
    # der rechten Figur reicht weiter nach links als der Koerper der linken.
    def sole_mid(pts):
        bottom = max(p[1] for p in pts)
        row = [p[0] for p in pts if p[1] > bottom - 20]
        return (min(row) + max(row)) // 2
    blobs.sort(key=sole_mid)
    out = []
    for pts in blobs:
        x0 = min(p[0] for p in pts)
        y0 = min(p[1] for p in pts)
        x1 = max(p[0] for p in pts)
        y1 = max(p[1] for p in pts)
        cut = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1), (0, 0, 0, 0))
        cp = cut.load()
        for x, y in pts:
            cp[x - x0, y - y0] = px[x, y]
        out.append(cut)
    return out

def prepare(path):
    """Vorlage -> 256er Rahmen."""
    return prepare_image(Image.open(path).convert("RGBA"))

def prepare_image(img):
    """Vorlage -> 256er Rahmen: freistellen, auf Koerpermass bringen,
    auf die Fusszeile setzen, Farben zusammenziehen."""
    img = img.copy()
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

## Das Fenster, in dem das Auge sitzt (Rahmenkoordinaten).
EYE_BOX = (102, 52, 162, 98)

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
    face = [(x, y) for y in range(55, 95) for x in range(104, 154)
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

def rod_grip(img):
    """Der Griffpunkt dieser Pose, an der geschlossenen Faust gemessen.

    Die Faust ist der rechteste Punkt im Armband; der Griff sitzt sieben
    Pixel dahinter und zwei tiefer. Gemessen und nicht gewaehlt: die Hand
    wandert von Bild zu Bild, im Streifen bis zu zehn Pixel. Ein fester
    Ankerpunkt haette die Rute aus der Hand rutschen lassen. Die Werte
    gehoeren nach core/angler_pose.gd, ROD_ANCHOR.
    """
    px = img.load()
    band = [(x, y) for y in range(110, 150) for x in range(FRAME)
            if px[x, y][3]]
    right = max(p[0] for p in band)
    ys = [p[1] for p in band if p[0] >= right - 2]
    return (right - 7, (min(ys) + max(ys)) // 2 + 2)

def main():
    idles = [prepare_image(f) for f in
             split_figures(os.path.join(SRC, "angler_idle_frames.png"), IDLE)]
    frames = list(idles)
    drawn_blink = os.path.join(SRC, "angler_blink.png")
    if os.path.exists(drawn_blink):
        frames.append(transplant_blink(idles[0], prepare(drawn_blink)))
    else:
        frames.append(blink(idles[0]))
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
    print("ROD_ANCHOR 0-%d: %s" % (IDLE, ", ".join(
        "Vector2i(%d, %d)" % rod_grip(f) for f in frames[:IDLE + 1])))

if __name__ == "__main__":
    main()
