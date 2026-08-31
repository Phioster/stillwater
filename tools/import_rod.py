#!/usr/bin/env python3
"""Setzt eine gezeichnete Rute in alle Posen ein.

ZURZEIT NICHT IM EINSATZ. Die Rute im Spiel kommt aus
`gen_sprites.gd::_rod`, weil das Drehen eines fertigen Pixelbildes in zehn
Winkel es entweder verwaschen (weiche Abtastung) oder ausgefranst (harte
Abtastung) macht -- gerechnet ist jeder Pixel gesetzt statt abgetastet.

Dieses Werkzeug bleibt fuer den Tag, an dem es je Pose ein eigenes
gezeichnetes Bild gibt; dann faellt das Drehen weg.

Die Rute ist EIN Bild. Fuer jede der zehn Posen liest dieses Werkzeug Griff
und Spitze aus `core/angler_pose.gd` -- dieselbe Quelle, aus der das Spiel
die Schnur ansetzt -- dreht die Rute in den passenden Winkel, skaliert sie
auf die passende Laenge und legt sie in das Blatt.

    python3 tools/import_rod.py rute_roh.png

Gedreht wird im GROSSEN Bild und erst danach verkleinert: ein fertiges
Pixelbild zu drehen zerreisst die Kanten.
"""
import math
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POSE = os.path.join(ROOT, "core", "angler_pose.gd")
OUT = os.path.join(ROOT, "assets", "art")
FRAME = 64
## Dieselben drei Ruten wie bisher: Bambus, Eiche, Silber.
ROD_TONES = ["a5825a", "4a3626", "b9c3c8"]

def read_vectors(name):
    """Liest eine Vector2i-Liste aus der Pose-Datei."""
    text = open(POSE, encoding="utf-8").read()
    block = text.split("const %s: Array[Vector2i] = [" % name)[1].split("]")[0]
    return [(int(a), int(b)) for a, b in re.findall(r"Vector2i\((-?\d+),\s*(-?\d+)\)", block)]

def principal_angle(img):
    """In welche Richtung die Rute im Rohbild zeigt.

    Ueber die Hauptachse der sichtbaren Pixel und nicht ueber die Ecken der
    Bounding-Box: eine waagerechte Rute mit dicker Rolle hat eine Box, deren
    Diagonale in eine ganz andere Richtung zeigt als die Rute selbst.
    """
    px = img.load()
    pts = [(x, y) for y in range(img.size[1]) for x in range(img.size[0])
           if px[x, y][3] > 0]
    n = len(pts)
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    sxx = sum((p[0] - mx) ** 2 for p in pts) / n
    syy = sum((p[1] - my) ** 2 for p in pts) / n
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts) / n
    # Groesster Eigenvektor der Kovarianzmatrix.
    angle = 0.5 * math.atan2(2.0 * sxy, sxx - syy)
    return math.degrees(-angle)

def tip_is_right(img, angle):
    """Zeigt die duenne Spitze nach rechts? Sonst muss das Bild gespiegelt
    werden -- der Griff gehoert immer an den Anker."""
    rot = img.rotate(-angle, resample=Image.BICUBIC, expand=True)
    rot = rot.crop(rot.getbbox())
    px = rot.load()
    w, h = rot.size
    def mass(x0, x1):
        return sum(1 for y in range(h) for x in range(x0, x1) if px[x, y][3] > 0)
    return mass(0, max(1, w // 3)) > mass(w - max(1, w // 3), w)

def harden(img, keep_alpha=110):
    """Macht aus weichen Kanten wieder Pixelart.

    Drehen und Verkleinern erzeugen halbe Transparenz -- im Bild sieht das
    verwaschen aus. Also: Alpha auf ganz oder gar nicht. Die FARBEN bleiben,
    wie sie sind; sie zusaetzlich zu quantisieren zerlegte die Rute in
    Streifen, weil benachbarte Toene in verschiedene Faecher fielen.
    """
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            px[x, y] = (0, 0, 0, 0) if a < keep_alpha else (r, g, b, 255)
    return img

def thicken(img, angle):
    """Verdickt die Rute quer zu ihrer Achse.

    Auf 30 Pixel Laenge bleibt von einer Rute sonst ein Haar uebrig: sie
    ist im Rohbild funf Pixel stark, nach dem Verkleinern noch einer.
    """
    rad = math.radians(-angle)
    step = (round(-math.sin(rad)), round(math.cos(rad)))
    if step == (0, 0):
        step = (0, 1)
    grown = Image.new("RGBA", (img.size[0] + abs(step[0]), img.size[1] + abs(step[1])),
                      (0, 0, 0, 0))
    grown.alpha_composite(img, (max(0, step[0]), max(0, step[1])))
    grown.alpha_composite(img, (max(0, -step[0]), max(0, -step[1])))
    return grown

def outline(img, color=(26, 35, 32)):
    """Dunkle Kante -- die gezeichnete Figur hat ueberall eine."""
    w, h = img.size
    grown = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    grown.alpha_composite(img, (1, 1))
    src = grown.copy().load()
    dst = grown.load()
    for y in range(h + 2):
        for x in range(w + 2):
            if src[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w + 2 and 0 <= ny < h + 2 and src[nx, ny][3] > 0:
                    dst[x, y] = color + (255,)
                    break
    return grown

## Nur der echte Umriss bleibt schwarz. Bei der Kleidung liegt die Grenze
## hoeher, dort ist Dunkles Stoff -- bei der Rute ist Dunkles der Schaft.
DARK_KEEP = 0.09

def tint(pixel, target):
    r, g, b, a = pixel
    luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    if luma < DARK_KEEP:
        return pixel
    f = 0.55 + 0.9 * luma
    return (min(255, int(target[0] * f)), min(255, int(target[1] * f)),
            min(255, int(target[2] * f)), a)

def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    raw = Image.open(sys.argv[1]).convert("RGBA")
    box = raw.getbbox()
    if box is None:
        sys.exit("das Bild ist leer -- erst mit import_prop.py freistellen")
    raw = raw.crop(box)
    raw_angle = principal_angle(raw)

    if not tip_is_right(raw, raw_angle):
        raw = raw.transpose(Image.FLIP_LEFT_RIGHT)
        raw_angle = -raw_angle

    anchors = read_vectors("ROD_ANCHOR")
    tips = read_vectors("ROD_TIP_OFF")
    if len(anchors) != len(tips):
        sys.exit("Griffe und Spitzen zaehlen verschieden")

    for variant, tone in enumerate(ROD_TONES):
        sheet = Image.new("RGBA", (FRAME * len(anchors), FRAME), (0, 0, 0, 0))
        for f, (anchor, tip) in enumerate(zip(anchors, tips)):
            length = math.hypot(tip[0], tip[1])
            # Bildkoordinaten zeigen nach unten, Winkel nach oben.
            want = math.degrees(math.atan2(-tip[1], tip[0]))
            # Erst vierfach vergroessern, dann drehen, dann auf Groesse
            # bringen: eine Drehung auf dem kleinen Bild zerreisst die
            # Kanten, eine auf dem grossen laesst sich sauber zurueckrechnen.
            big = raw.resize((raw.size[0] * 4, raw.size[1] * 4), Image.NEAREST)
            rod = big.rotate(want - raw_angle, resample=Image.BICUBIC, expand=True)
            rod = rod.crop(rod.getbbox())
            scale = length / math.hypot(*rod.size)
            rod = rod.resize((max(1, round(rod.size[0] * scale)),
                              max(1, round(rod.size[1] * scale))), Image.BOX)
            # Nicht mehr verdicken: die Rohrute ist schon drei Pixel stark.
            rod = outline(harden(rod))
            if tone:
                target = tuple(int(tone[i:i + 2], 16) for i in (0, 2, 4))
                px = rod.load()
                for y in range(rod.size[1]):
                    for x in range(rod.size[0]):
                        if px[x, y][3] > 0:
                            px[x, y] = tint(px[x, y], target)
            # Der Griff der gedrehten Rute ist die Ecke, die zum Anker zeigt.
            gx = anchor[0] - (0 if tip[0] >= 0 else rod.size[0] - 1)
            gy = anchor[1] - (0 if tip[1] >= 0 else rod.size[1] - 1)
            sheet.alpha_composite(rod, (f * FRAME + gx, gy))
        sheet.save(os.path.join(OUT, "char_rod_%d.png" % variant))
    print("%d Rutenblaetter geschrieben" % len(ROD_TONES))

if __name__ == "__main__":
    main()
