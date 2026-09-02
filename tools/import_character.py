#!/usr/bin/env python3
"""Baut die Figurenblaetter aus der PixelLab-Schluesselfigur.

Die Anglerin kommt aus `assets/source/figure/`: neun Ruhebilder und sechs
Wurfbilder, je 168x168, dazu die eingefrorene Farbtabelle `key_palette.json`.
Dieses Werkzeug macht daraus die 30 Blaetter, die das Spiel laedt -- je
128 * 24 Pixel breit, 128 hoch:

    0-8    Ruhelauf  -- idle_0 bis idle_8, als Schleife (kein Pingpong: der
                        Rundschluss aendert weniger Umrisspixel als jeder
                        Schritt innerhalb der Reihe, siehe main())
    9-17   Blinzeln  -- zu JEDEM Ruhebild eins, Augen zu, Koerper gleich
    18-23  Wurf      -- cast_0 bis cast_5

Jedes Ruhebild hat seinen eigenen Blinzelzwilling, weil der Kopf ueber den
Atemzug wandert: mit nur einem Blinzelbild spraenge er fuer den
Sekundenbruchteil des Blinzelns auf die Haltung von Bild 0 zurueck.

Die Bilder sind schon in der Groesse der Figur gezeichnet -- nur der Rand
ist breiter als das 128er Feld. Ausgerichtet wird deshalb ausschliesslich
durch Verschieben (an der Stiefelsohle, dem einzigen Punkt, der stillsteht),
nie durch Skalieren.

Die Ebenen kommen aus der eingefrorenen Palette (key_palette.json), nicht
aus geratenen Farbgrenzen: die Figur wurde absichtlich in weit auseinander-
liegenden Markerfarben erzeugt, damit Trennen Nachschlagen ist.

    python3 -m tools.import_character
"""
import os

from PIL import Image

from tools.character_blink import close_eye
from tools.character_keys import load_table
from tools.character_layers import split
from tools.frame_order import pingpong_order

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "figure")
OUT = os.path.join(ROOT, "assets", "art")

FRAME = 128
IDLE_FRAMES = 9
CAST_FRAMES = 6
BLINK_START = IDLE_FRAMES
CAST_START = IDLE_FRAMES * 2
FRAMES = IDLE_FRAMES * 2 + CAST_FRAMES

IDLE_ORDER = list(range(IDLE_FRAMES))

## Wo der Anker im 128er Feld landet -- an der Stiefelsohle nachgemessen,
## siehe anker(). Nachgemessen liegt der Anker in allen 15 Bewegungsbildern
## auf (102, 141) oder (102, 142), in zwei Wurfbildern auf (101, 142).
ANKER_X, ANKER_Y = 68, 124

## Farben, aus denen die Varianten gemacht werden. Reihenfolge wie in
## data/cosmetics/.
SKIN_TONES = ["e8be9a", "c68c63", "8d5a3c", "f6ddc4", "5c3826",
              "6f9455", "9fc7d6", "8f8a9c", "f4f6f7"]
SHIRT_TONES = ["3f6fb4", "b4523f", "4a9455", "c8913f", "6b4470",
               "6f7a75", "6b4326", "8f6a2c", "39537f"]
PANTS_TONES = ["6f7a75", "4a3626", "8f6a2c", "6b4470", "39537f", "b4523f"]
HAIR_STYLES = 5

## Wird in main() gemessen, nicht geraten -- siehe _augenfeld().
EYE_BOX = None

def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]

def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))

def anker(img):
    """Stiefelmitte und Sohle -- der einzige Punkt, der ueber alle Bilder
    stillsteht. Der Umriss oben wandert (Zopf, Arm), die Stiefel nicht."""
    px = img.load()
    bb = img.getbbox()
    unten = bb[3] - 1
    xs = [x for y in range(max(bb[1], unten - 5), unten + 1)
          for x in range(img.size[0]) if px[x, y][3] > 128]
    return (min(xs) + max(xs)) // 2, unten

def ins_feld(img):
    """Verschieben, nicht skalieren -- die Figur ist im Quellbild schon
    128er-gross, nur der Rand ist breiter."""
    ax, ay = anker(img)
    feld = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    feld.paste(img, (ANKER_X - ax, ANKER_Y - ay))
    return feld

def _sichtbare_pixel(img):
    px = img.load()
    return sum(1 for y in range(img.size[1]) for x in range(img.size[0])
               if px[x, y][3] > 128)

def ausrichten(img, name):
    """ins_feld() mit Pflichtpruefung: kein sichtbarer Pixel darf beim
    Verschieben verloren gehen. Lieber ein Abbruch als eine Figur, der die
    Fingerspitzen fehlen."""
    vorher = _sichtbare_pixel(img)
    feld = ins_feld(img)
    nachher = _sichtbare_pixel(feld)
    if nachher < vorher:
        raise SystemExit("%s: %d Pixel beim Verschieben verloren (%d -> %d)"
                          % (name, vorher - nachher, vorher, nachher))
    return feld

def _augenfeld(img, table):
    """Wo das Auge liegt -- an den Pixeln gemessen, die close_eye aendert."""
    zu = close_eye(img, table)
    px, qx = img.load(), zu.load()
    anders = [(x, y) for y in range(FRAME) for x in range(FRAME)
              if px[x, y] != qx[x, y]]
    if not anders:
        raise SystemExit("close_eye aendert nichts -- das Auge wurde nicht gefunden")
    xs = [p[0] for p in anders]
    ys = [p[1] for p in anders]
    return (min(xs) - 3, min(ys) - 3, max(xs) + 4, max(ys) + 4)

def _komponenten(img):
    """Zusammenhaengende Flaechen sichtbarer Pixel (8er-Nachbarschaft)."""
    px = img.load()
    w, h = img.size
    besucht = [[False] * w for _ in range(h)]
    blobs = []
    for y in range(h):
        for x in range(w):
            if besucht[y][x] or px[x, y][3] == 0:
                continue
            stapel = [(x, y)]
            besucht[y][x] = True
            punkte = []
            while stapel:
                cx, cy = stapel.pop()
                punkte.append((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if (0 <= nx < w and 0 <= ny < h
                                and not besucht[ny][nx] and px[nx, ny][3] > 0):
                            besucht[ny][nx] = True
                            stapel.append((nx, ny))
            blobs.append(punkte)
    return blobs

def _mitte(blob):
    return sum(p[0] for p in blob) / len(blob), sum(p[1] for p in blob) / len(blob)

def rod_grip(img, table, hinweis=None):
    """Der Griffpunkt dieser Pose, an der Hautebene gemessen.

    Beim Sitzen sind die Oberschenkel immer die groesste Hautflaeche (sie
    ruehren sich nicht), das Gesicht die zweitgroesste (am Hals befestigt).
    Die Hand ist, was danach kommt und mindestens 20 Pixel gross ist --
    gewaehlt wird die Flaeche am weitesten vom Gesicht weg. Verschmilzt sie
    beim Atmen mit den Oberschenkeln, wird an der letzten bekannten
    Handstelle (hinweis) nachgesehen.
    """
    blobs = _komponenten(split(img, table)["skin"])
    blobs = [b for b in blobs if len(b) >= 3]
    blobs.sort(key=len, reverse=True)
    if not blobs:
        raise SystemExit("rod_grip: keine Haut sichtbar")
    beine = blobs[0]
    rest = blobs[1:]
    gesicht = max(rest, key=len) if rest else None
    kandidaten = [b for b in rest if b is not gesicht and len(b) >= 20]
    if not kandidaten:
        ziel = hinweis or _mitte(beine)
        return min(beine, key=lambda p: (p[0] - ziel[0]) ** 2 + (p[1] - ziel[1]) ** 2)
    fx, fy = _mitte(gesicht)
    hand = max(kandidaten,
                key=lambda b: (lambda m: (m[0] - fx) ** 2 + (m[1] - fy) ** 2)(_mitte(b)))
    hx, hy = _mitte(hand)
    return min(hand, key=lambda p: (p[0] - hx) ** 2 + (p[1] - hy) ** 2)

def transplant_blink(base, drawn):
    """Nimmt NUR das Auge aus dem geschlossenen Bild.

    Erst die Koepfe zur Deckung bringen (Suchfenster an EYE_BOX
    ausgerichtet, nicht an festen Zahlen), dann das Augenfenster
    uebernehmen -- sonst spraenge beim Blinzeln die komplette Figur um.
    """
    pa, pb = base.load(), drawn.load()
    best, score = (0, 0), -1
    for dy in range(-10, 11):
        for dx in range(-10, 11):
            hit = 0
            for y in range(EYE_BOX[1] - 22, EYE_BOX[3] + 2, 2):
                for x in range(EYE_BOX[0] - 6, EYE_BOX[2] + 14, 2):
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

def head_shift(base, other, span=10):
    """Wie weit der Kopf zwischen zwei Ruhebildern verrutscht ist."""
    pa, pb = base.load(), other.load()
    x0, y0, x1, y1 = EYE_BOX
    best, score = (0, 0), -1
    for dy in range(-span, span + 1):
        for dx in range(-span, span + 1):
            hit = 0
            for y in range(y0 - 20, y1 + 10):
                for x in range(x0 - 20, x1 + 20):
                    bx, by = x + dx, y + dy
                    if not (0 <= bx < FRAME and 0 <= by < FRAME):
                        continue
                    if (pa[x, y][3] > 0) == (pb[bx, by][3] > 0):
                        hit += 1
            if hit > score:
                score, best = hit, (dx, dy)
    return best

def blink_series(idles, shut):
    """Zu jedem Ruhebild eins mit geschlossenem Auge.

    Das geschlossene Bild laesst sich nur auf die URSPRUENGLICHE
    Kopfhaltung ausrichten -- mitten im Atemzug steht der Kopf woanders.
    Also einmal sauber auf Bild 0 verpflanzen, den fertigen Augenbereich
    als Flicken nehmen und ihn fuer jedes weitere Bild dorthin schieben,
    wo dessen Kopf steht.
    """
    first = transplant_blink(idles[0], shut)
    pa, pb = idles[0].load(), first.load()
    patch = [(x, y, pb[x, y])
             for y in range(EYE_BOX[1], EYE_BOX[3])
             for x in range(EYE_BOX[0], EYE_BOX[2])
             if pa[x, y] != pb[x, y]]
    out = [first]
    for img in idles[1:]:
        dx, dy = head_shift(idles[0], img)
        copy = img.copy()
        q = copy.load()
        for x, y, color in patch:
            bx, by = x + dx, y + dy
            if 0 <= bx < FRAME and 0 <= by < FRAME:
                q[bx, by] = color
        out.append(copy)
    return out

def recolor(img, ziel):
    """Faerbt eine Ebene ein und behaelt ihre Schattierung."""
    px = img.load()
    out = img.copy()
    q = out.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if not a:
                continue
            f = 0.55 + 0.9 * (lum((r, g, b)) / 255.0)
            q[x, y] = (min(255, int(ziel[0] * f)), min(255, int(ziel[1] * f)),
                       min(255, int(ziel[2] * f)), a)
    return out

def blatt(ebenen, teil, ton=None):
    """Ein Blatt aus einer bereits geschnittenen Ebenenliste zusammensetzen."""
    out = Image.new("RGBA", (FRAME * len(ebenen), FRAME), (0, 0, 0, 0))
    for i, e in enumerate(ebenen):
        stueck = recolor(e[teil], ton) if ton else e[teil]
        out.alpha_composite(stueck, (i * FRAME, 0))
    return out

def _rand_frei(pfad, n):
    """Kein Bild darf seinen eigenen Rand beruehren -- sonst blutet es beim
    Zusammensetzen ins naechste Blatt."""
    img = Image.open(pfad).convert("RGBA")
    if img.size != (FRAME * n, FRAME):
        raise SystemExit("%s: Groesse %s statt (%d, %d)" % (pfad, img.size, FRAME * n, FRAME))
    px = img.load()
    for f in range(n):
        x0 = f * FRAME
        rand = ([(x0 + x, 0) for x in range(FRAME)]
                + [(x0 + x, FRAME - 1) for x in range(FRAME)]
                + [(x0, y) for y in range(FRAME)]
                + [(x0 + FRAME - 1, y) for y in range(FRAME)])
        for x, y in rand:
            if px[x, y][3] > 0:
                raise SystemExit("%s: Bild %d beruehrt den Rand bei (%d, %d)"
                                  % (pfad, f, x - x0, y))

def main():
    global EYE_BOX
    table = load_table(os.path.join(SRC, "key_palette.json"))

    idles = []
    for i in range(IDLE_FRAMES):
        name = "idle_%d" % i
        img = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
        vor = _sichtbare_pixel(img)
        feld = ausrichten(img, name)
        print("%s: Anker %s, %d -> %d sichtbare Pixel"
              % (name, anker(img), vor, _sichtbare_pixel(feld)))
        idles.append(feld)

    casts = []
    for i in range(CAST_FRAMES):
        name = "cast_%d" % i
        img = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
        vor = _sichtbare_pixel(img)
        feld = ausrichten(img, name)
        print("%s: Anker %s, %d -> %d sichtbare Pixel"
              % (name, anker(img), vor, _sichtbare_pixel(feld)))
        casts.append(feld)

    ## Nur zur Kontrolle ausgegeben, hier nicht verwendet: IDLE_ORDER laeuft
    ## als Schleife (siehe main-Docstring); pingpong_order() bliebe die
    ## richtige Wahl, wenn ein kuenftiger Bildersatz eine offene Schwingung
    ## liefert.
    pp = pingpong_order(idles)
    print("pingpong_order (nicht verwendet): %s" % pp)

    EYE_BOX = _augenfeld(idles[0], table)
    zu = close_eye(idles[0], table)
    px, qx = idles[0].load(), zu.load()
    anders = [(x, y) for y in range(FRAME) for x in range(FRAME)
              if px[x, y] != qx[x, y]]
    kopf_grenze = FRAME / 3.0
    im_kopf = all(y < kopf_grenze for _, y in anders)
    print("EYE_BOX gemessen: %s" % (EYE_BOX,))
    print("close_eye aendert %d Pixel (muss zweistellig sein): %s"
          % (len(anders), "OK" if 10 <= len(anders) <= 99 else "AUFLAGE VERLETZT"))
    print("alle im oberen Drittel (< %.1f): %s -- Pixel: %s"
          % (kopf_grenze, "OK" if im_kopf else "AUFLAGE VERLETZT", sorted(anders)))

    blinks = blink_series(idles, close_eye(idles[0], table))

    frames = idles + blinks + casts
    assert len(frames) == FRAMES, "%d Bilder statt %d" % (len(frames), FRAMES)

    ## Griff je Bild -- am tatsaechlichen Bild gemessen, NICHT fuer die
    ## Blinzelbilder vom Ruhebild uebernommen: EYE_BOX ist (siehe oben)
    ## ueberdimensioniert und veraendert dadurch auch Pixel weit ausserhalb
    ## des Auges. Auf einem Ruhebild traf das zufaellig den Handbereich und
    ## haette den gemessenen Griff eines Blinzelbilds sonst auf einen
    ## nicht mehr sichtbaren Hautpixel gelegt.
    griffe = []
    hinweis = None
    for f in frames:
        g = rod_grip(f, table, hinweis)
        hinweis = g
        griffe.append(g)

    ## Jedes Bild wird EINMAL geschnitten, danach fuer alle Blaetter
    ## wiederverwendet -- 31 Blaetter mal 24 Bilder waeren sonst 744
    ## Schnitte durch je 16384 Pixel.
    ebenen = [split(f, table) for f in frames]

    geschrieben = []
    for i, ton in enumerate(SKIN_TONES):
        pfad = os.path.join(OUT, "char_skin_%d.png" % i)
        blatt(ebenen, "skin", hexc(ton) if i else None).save(pfad)
        geschrieben.append(pfad)
    for i in range(HAIR_STYLES):
        pfad = os.path.join(OUT, "char_hair_%d.png" % i)
        blatt(ebenen, "hair").save(pfad)
        geschrieben.append(pfad)
    for i, ton in enumerate(SHIRT_TONES):
        pfad = os.path.join(OUT, "char_shirt_%d.png" % i)
        blatt(ebenen, "shirt", hexc(ton) if i else None).save(pfad)
        geschrieben.append(pfad)
    boots = blatt(ebenen, "boots")
    for i, ton in enumerate(PANTS_TONES):
        pfad = os.path.join(OUT, "char_pants_%d.png" % i)
        out = blatt(ebenen, "pants", hexc(ton) if i else None)
        out.alpha_composite(boots)
        out.save(pfad)
        geschrieben.append(pfad)
    pfad = os.path.join(OUT, "char_base_0.png")
    blatt(ebenen, "base").save(pfad)
    geschrieben.append(pfad)
    print("%d Blaetter geschrieben" % len(geschrieben))

    for pfad in geschrieben:
        _rand_frei(pfad, FRAMES)
    print("Randpruefung bestanden: kein Bild beruehrt seinen Rand")

    print("FRAMES = %d, IDLE_FRAMES = %d, BLINK_START = %d, CAST_START = %d"
          % (FRAMES, IDLE_FRAMES, BLINK_START, CAST_START))
    print("IDLE_ORDER = %s" % IDLE_ORDER)
    print("ROD_ANCHOR: %s" % ", ".join("Vector2i(%d, %d)" % g for g in griffe))

if __name__ == "__main__":
    main()
