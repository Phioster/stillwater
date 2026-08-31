#!/usr/bin/env python3
"""Baut die Figurenebenen aus dem erzeugten Ausgangsbild.

Die Anglerin kommt seit 2026-08-31 nicht mehr aus `gen_sprites.gd`, sondern
aus `assets/source/angler_frames.png` -- zehn 64x64-Posen nebeneinander
(sechs Ruhebilder, vier Wurfbilder), mit PixelLab erzeugt: eine Pose gezeichnet, die
beiden anderen daraus animiert. Zwei prozedurale Anlaeufe mit Ellipsen sahen
nach zusammengesteckten Formen aus; das hier ist gezeichnete Figur.

Ein flaches Bild kennt aber keine Ebenen, und unser Kosmetiksystem lebt
davon. Also zerlegt dieses Werkzeug das Bild anhand seiner Farbfamilien in
Haut, Haare, Oberteil und Hose und faerbt daraus die Varianten ein -- mit
DERSELBEN Formel wie der Toenungs-Shader (assets/art/palette_swap.gdshader),
damit ein umgefaerbtes Oberteil genauso aussieht wie umgetoente Haare.

    python3 tools/import_character.py

Huete und Ruten bleiben vorerst in gen_sprites.gd: sie sind eigene Formen,
keine Umfaerbung.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "source", "angler_frames.png")
OUT = os.path.join(ROOT, "assets", "art")

FRAME = 64
FRAMES = 10
## Wie weit die Figur nach links rueckt. Ohne das sitzt die Hand so weit
## rechts, dass keine Rute mehr in den Rahmen passt (siehe AnglerPose).
SHIFT_X = -8

## Die Farbfamilien des Ausgangsbildes. Alles, was hier nicht steht, wird
## ueber seine Lage zugeordnet -- und reine Umrisspixel bekommen die Ebene
## ihrer Nachbarn.
SKIN_COLORS = {(255, 203, 182), (237, 196, 175), (206, 165, 148), (183, 133, 131),
               (240, 174, 155), (255, 225, 208), (229, 149, 128), (174, 106, 90)}
SHIRT_COLORS = {(236, 220, 193), (199, 180, 159), (174, 159, 148), (234, 211, 187),
                (207, 200, 171), (133, 127, 125)}
## Unter dieser Zeile ist Rock, darunter Stiefel.
SKIRT_TOP = 43
BOOT_TOP = 52

def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))

## Dieselben Werte wie core/palette.gd -- die Palette ist dort die Quelle.
SKIN_TONES = ["e8be9a", "c68c63", "8d5a3c", "f6ddc4", "5c3826",
              "6f9455", "9fc7d6", "8f8a9c", "f4f6f7"]
SHIRT_TONES = ["3f6fb4", "b4523f", "4a9455", "c8913f", "6b4470",
               "6f7a75", "6b4326", "8f6a2c", "39537f"]
PANTS_TONES = ["6f7a75", "4a3626", "8f6a2c", "6b4470", "39537f", "b4523f"]

## Dunkler als das bleibt, wie es ist: Auge, Wimpern und Umriss. Ohne die
## Grenze verblasst bei heller Haut das halbe Gesicht mit.
DARK_KEEP = 0.22

def tint(pixel, target):
    """Farbton ersetzen, Helligkeit behalten -- exakt die Shader-Formel."""
    r, g, b, a = pixel
    luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    if luma < DARK_KEEP:
        return pixel
    f = 0.55 + 0.9 * luma
    return (min(255, int(target[0] * f)), min(255, int(target[1] * f)),
            min(255, int(target[2] * f)), a)

def split(img):
    """Ordnet jedes Pixel einer Ebene zu."""
    px = img.load()
    base, outline = {}, []
    for y in range(FRAME):
        for x in range(FRAME):
            p = px[x, y]
            if p[3] == 0:
                continue
            c = p[:3]
            if c in SKIN_COLORS:
                base[(x, y)] = "skin"
            elif c in SHIRT_COLORS:
                base[(x, y)] = "shirt"
            elif sum(c) < 40:
                outline.append((x, y))
            elif 15 <= y <= 24 and x >= 37:
                base[(x, y)] = "skin"          # Auge und Wimpern im Gesicht
            elif y <= 42 and not (26 <= y <= 42 and x >= 33):
                base[(x, y)] = "hair"
            elif y <= 42:
                base[(x, y)] = "shirt"         # dunkle Falten im Pullover
            else:
                base[(x, y)] = "pants"
    layers = dict(base)
    # Umrisspixel stimmen ueber ihre ECHTEN Nachbarn ab, nicht ueber schon
    # zugewiesene Umrisse -- sonst frisst sich eine Ebene durchs ganze Bild.
    for (x, y) in outline:
        votes = {}
        for radius in (1, 2, 3):
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    lay = base.get((x + dx, y + dy))
                    if lay:
                        votes[lay] = votes.get(lay, 0) + 1
            if votes:
                break
        layers[(x, y)] = max(votes, key=votes.get) if votes else "pants"
    return layers

def sheet(frames, name, target=None, only=None):
    """Ein Blatt aus allen Posen -- jede Pose ist ein eigenes Bild mit eigener
    Zerlegung, sonst haette die Figur beim Wurf denselben Arm wie im Stand."""
    out = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    for f, (img, layers) in enumerate(frames):
        px = img.load()
        single = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        q = single.load()
        for (x, y), lay in layers.items():
            if lay != name:
                continue
            if only == "skirt" and y >= BOOT_TOP:
                continue
            if only == "boots" and y < BOOT_TOP:
                continue
            nx = x + SHIFT_X
            if 0 <= nx < FRAME:
                q[nx, y] = tint(px[x, y], target) if target else px[x, y]
        out.alpha_composite(single, (f * FRAME, 0))
    return out

def main():
    if not os.path.exists(SOURCE):
        sys.exit("Ausgangsbild fehlt: %s" % SOURCE)
    strip = Image.open(SOURCE).convert("RGBA")
    if strip.size != (FRAME * FRAMES, FRAME):
        sys.exit("Ausgangsbild muss %dx%d sein, ist %s"
                 % (FRAME * FRAMES, FRAME, strip.size))
    frames = []
    for f in range(FRAMES):
        img = strip.crop((f * FRAME, 0, (f + 1) * FRAME, FRAME))
        frames.append((img, split(img)))

    written = 0
    for i, tone in enumerate(SKIN_TONES):
        sheet(frames, "skin", hexc(tone) if i else None).save(
            os.path.join(OUT, "char_skin_%d.png" % i))
        written += 1
    # Die Haarfarbe macht der Shader zur Laufzeit; die Frisuren sind noch
    # alle dieselbe -- eine zweite Frisur ist ein zweites Ausgangsbild.
    for i in range(5):
        sheet(frames, "hair").save(os.path.join(OUT, "char_hair_%d.png" % i))
        written += 1
    for i, tone in enumerate(SHIRT_TONES):
        sheet(frames, "shirt", hexc(tone) if i else None).save(
            os.path.join(OUT, "char_shirt_%d.png" % i))
        written += 1
    # Der Rock nimmt die Farbe an, die Stiefel bleiben dunkel: eine
    # pflaumenfarbene Hose faerbt keine Schuhe mit ein.
    boots = sheet(frames, "pants", None, only="boots")
    for i, tone in enumerate(PANTS_TONES):
        skirt = sheet(frames, "pants", hexc(tone) if i else None, only="skirt")
        skirt.alpha_composite(boots)
        skirt.save(os.path.join(OUT, "char_pants_%d.png" % i))
        written += 1
    print("%d Blaetter geschrieben nach %s" % (written, OUT))

if __name__ == "__main__":
    main()
