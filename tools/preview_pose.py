"""Die Figur ansehen, ohne Godot zu starten und ohne etwas zu generieren.

Alles an Rute und Aufbau sind Zahlen in core/angler_pose.gd und
scenes/fishing/world.gd. Dieses Werkzeug liest sie und malt daraus ein Bild --
eine Aenderung ist damit in Sekunden sichtbar statt in Minuten.

    python3 -m tools.preview_pose bilder 18 19 20 21 22 23
    python3 -m tools.preview_pose welt
    python3 -m tools.preview_pose laenge 150

`bilder` zeigt einzelne Posen gross, mit Griff (rot) und Spitze (gruen).
`welt` setzt Steg, Figur, Rute, Schnur und Schwimmer in den echten Massstaeben
zusammen -- daran sieht man Proportionen, die in der Einzelpose niemand sieht.
`laenge` schreibt ROD_TIP_OFF auf eine neue Rutenlaenge um; danach muss
tools/import_rod.py laufen, damit die Blaetter dazu passen.
"""

import os
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")
POSE = os.path.join(ROOT, "core", "angler_pose.gd")
WORLD = os.path.join(ROOT, "scenes", "fishing", "world.gd")
OUT = os.path.join(ROOT, "vorschau.png")

## Von hinten nach vorn, wie die Szene die Ebenen stapelt.
EBENEN = ["char_base_0", "char_skin_0", "char_pants_0", "char_shirt_0",
          "char_hair_0"]

def _text(pfad):
    with open(pfad, encoding="utf-8") as fh:
        return fh.read()

def vektoren(name, quelle=None):
    """Ein Array[Vector2i] aus dem GDScript lesen."""
    text = quelle if quelle is not None else _text(POSE)
    treffer = re.search(r"const %s: Array\[Vector2i\] = \[(.*?)\]\n" % name,
                        text, re.S)
    if treffer is None:
        raise SystemExit("%s steht nicht in %s" % (name, POSE))
    return [(int(a), int(b)) for a, b in
            re.findall(r"Vector2i\((-?\d+),\s*(-?\d+)\)", treffer.group(1))]

def zahlen(name, quelle=None):
    text = quelle if quelle is not None else _text(POSE)
    treffer = re.search(r"const %s: Array\[(?:int|float)\] = \[(.*?)\]" % name,
                        text, re.S)
    roh = treffer.group(1).replace("\n", " ").split(",")
    return [float(x) for x in roh if x.strip()]

def konstante(name, pfad=POSE):
    treffer = re.search(r"const %s(?::\s*\w+)? :?= (-?[\d.]+)" % name,
                        _text(pfad))
    if treffer is None:
        raise SystemExit("%s steht nicht in %s" % (name, pfad))
    return float(treffer.group(1))

def blaetter():
    return [Image.open(os.path.join(ART, n + ".png")).convert("RGBA")
            for n in EBENEN]

def figur(f, teile, feld):
    """Eine Pose, alle Ebenen uebereinander."""
    img = Image.new("RGBA", (feld, feld), (0, 0, 0, 0))
    for s in teile:
        img.alpha_composite(s.crop((f * feld, 0, f * feld + feld, feld)))
    return img

def rute_bild(f, sheet, rod_frame, raster):
    r = int(rod_frame[f])
    return sheet.crop((r * raster, 0, r * raster + raster, raster))

# --- bilder ----------------------------------------------------------------

def zeige_bilder(welche):
    feld = int(konstante("FRAME_SIZE"))
    raster = int(konstante("ROD_FRAME_SIZE"))
    griff = vektoren("ROD_GRIP_ARRAY") if False else None
    anker = vektoren("ROD_ANCHOR")
    spitze = vektoren("ROD_TIP_OFF")
    rod_frame = zahlen("ROD_FRAME")
    g = re.search(r"const ROD_GRIP: Vector2i = Vector2i\((\d+),\s*(\d+)\)",
                  _text(POSE))
    gx, gy = int(g.group(1)), int(g.group(2))
    teile = blaetter()
    sheet = Image.open(os.path.join(ART, "char_rod_1.png")).convert("RGBA")

    # Genug Rand, dass auch eine lange Rute vollstaendig im Bild bleibt.
    rand = max(abs(x) for v in spitze for x in v) + 12
    w = h = feld + 2 * rand
    spalten = min(3, len(welche))
    zeilen = (len(welche) + spalten - 1) // spalten
    out = Image.new("RGBA", (w * spalten, h * zeilen), (26, 26, 34, 255))
    for i, f in enumerate(welche):
        zelle = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ox, oy = anker[f][0] - gx, anker[f][1] - gy
        stueck = rute_bild(f, sheet, rod_frame, raster)
        # paste vertraegt negative Koordinaten, alpha_composite nicht.
        unten = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        unten.paste(stueck, (rand + ox, rand + oy), stueck)
        zelle.alpha_composite(unten)
        zelle.alpha_composite(figur(f, teile, feld), (rand, rand))
        d = ImageDraw.Draw(zelle)
        ax, ay = rand + anker[f][0], rand + anker[f][1]
        d.ellipse([ax - 2, ay - 2, ax + 2, ay + 2], outline=(255, 60, 60, 255))
        tx, ty = ax + spitze[f][0], ay + spitze[f][1]
        d.ellipse([tx - 2, ty - 2, tx + 2, ty + 2], outline=(90, 255, 90, 255))
        laenge = (spitze[f][0] ** 2 + spitze[f][1] ** 2) ** 0.5
        d.text((4, 4), "Bild %d  Rute %.0f px" % (f, laenge),
               fill=(230, 230, 230, 255))
        out.alpha_composite(zelle, ((i % spalten) * w, (i // spalten) * h))
    return out

# --- welt ------------------------------------------------------------------

def zeige_welt(f=0):
    """Steg, Figur, Rute, Schnur und Schwimmer in den echten Massstaeben."""
    feld = int(konstante("FRAME_SIZE"))
    raster = int(konstante("ROD_FRAME_SIZE"))
    dock_s = konstante("DOCK_SCALE", WORLD)
    ang_s = konstante("ANGLER_SCALE", WORLD)
    auf_steg = konstante("ANGLER_ON_DECK", WORLD)
    fuesse = konstante("CHAR_FEET", WORLD)
    ab_steg = konstante("BOBBER_OFF_DOCK", WORLD)
    anker = vektoren("ROD_ANCHOR")
    spitze = vektoren("ROD_TIP_OFF")
    rod_frame = zahlen("ROD_FRAME")
    g = re.search(r"const ROD_GRIP: Vector2i = Vector2i\((\d+),\s*(\d+)\)",
                  _text(POSE))
    gx, gy = int(g.group(1)), int(g.group(2))

    steg = Image.open(os.path.join(ART, "dock.png")).convert("RGBA")
    teile = blaetter()
    sheet = Image.open(os.path.join(ART, "char_rod_1.png")).convert("RGBA")

    W, H = 1100, 620
    out = Image.new("RGBA", (W, H), (18, 40, 58, 255))
    d = ImageDraw.Draw(out)
    wasser_y = 300
    d.rectangle([0, wasser_y, W, H], fill=(24, 62, 84, 255))

    steg_w = int(steg.width * dock_s)
    steg_h = int(steg.height * dock_s)
    steg_x, steg_y = 40, wasser_y - int(16 * dock_s)
    out.alpha_composite(steg.resize((steg_w, steg_h), Image.NEAREST),
                        (steg_x, steg_y))

    fx = steg_x + int(auf_steg * dock_s)
    fy = steg_y - int(fuesse * ang_s)
    gross = int(feld * ang_s)
    ox, oy = anker[f][0] - gx, anker[f][1] - gy
    stueck = rute_bild(f, sheet, rod_frame, raster)
    rg = int(raster * ang_s)
    unten = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    unten.paste(stueck.resize((rg, rg), Image.NEAREST),
                (fx + int(ox * ang_s), fy + int(oy * ang_s)),
                stueck.resize((rg, rg), Image.NEAREST))
    out.alpha_composite(unten)
    out.alpha_composite(figur(f, teile, feld).resize((gross, gross),
                                                     Image.NEAREST), (fx, fy))

    # Schnur von der Rutenspitze zum Schwimmer.
    sx = fx + int((anker[f][0] + spitze[f][0]) * ang_s)
    sy = fy + int((anker[f][1] + spitze[f][1]) * ang_s)
    bx = min(steg_x + steg_w + int(ab_steg * dock_s), int(W * 0.75))
    d.line([sx, sy, bx, wasser_y], fill=(235, 235, 220, 255), width=2)
    d.ellipse([bx - 5, wasser_y - 5, bx + 5, wasser_y + 5],
              fill=(220, 70, 60, 255))
    d.ellipse([sx - 4, sy - 4, sx + 4, sy + 4], outline=(90, 255, 90, 255))

    figur_h = figur(f, teile, feld).getbbox()
    hoch = (figur_h[3] - figur_h[1]) * ang_s
    lang = (spitze[f][0] ** 2 + spitze[f][1] ** 2) ** 0.5 * ang_s
    d.text((10, 10), "Figur %.0f px hoch, Rute %.0f px lang (%.0f %%),"
           " Steg %.0f px breit" % (hoch, lang, 100.0 * lang / hoch, steg_w),
           fill=(235, 235, 235, 255))
    return out

# --- laenge ----------------------------------------------------------------

def setze_laenge(ziel):
    """ROD_TIP_OFF auf eine neue Rutenlaenge umschreiben, Richtungen behalten.

    Die Laenge steckt allein im Betrag dieser Vektoren -- import_rod.py streckt
    die Vorlage genau darauf. Der Test laesst 1,5 Pixel Streuung zu, gerundet
    wird deshalb einfach.
    """
    text = _text(POSE)
    alt = vektoren("ROD_TIP_OFF", text)
    neu = []
    for x, y in alt:
        laenge = (x * x + y * y) ** 0.5
        neu.append((round(x * ziel / laenge), round(y * ziel / laenge)))

    grenze = konstante("ROD_FRAME_SIZE") / 2.0 - 2
    zu_weit = [(i, v) for i, v in enumerate(neu)
               if max(abs(v[0]), abs(v[1])) > grenze]
    if zu_weit:
        raise SystemExit(
            "Rute passt nicht mehr in ihr Raster (%d Pixel Halbfeld): %s.\n"
            "Entweder kuerzer, oder ROD_FRAME_SIZE vergroessern."
            % (grenze, zu_weit[:3]))

    zeilen = []
    for i in range(0, len(neu), 3):
        gruppe = ", ".join("Vector2i(%d, %d)" % v for v in neu[i:i + 3])
        zeilen.append("\t" + gruppe + ",")
    block = "const ROD_TIP_OFF: Array[Vector2i] = [\n" + "\n".join(zeilen)
    block = block[:-1] + "]\n"
    text = re.sub(r"const ROD_TIP_OFF: Array\[Vector2i\] = \[.*?\]\n",
                  block, text, flags=re.S)
    with open(POSE, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("ROD_TIP_OFF auf %d Pixel gesetzt. Jetzt tools/import_rod.py laufen"
          " lassen, sonst passen die Blaetter nicht dazu." % ziel)

def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    befehl = argv[1]
    if befehl == "laenge":
        setze_laenge(int(argv[2]))
        return
    if befehl == "bilder":
        welche = [int(x) for x in argv[2:]] or [0]
        bild = zeige_bilder(welche)
    elif befehl == "welt":
        bild = zeige_welt(int(argv[2]) if len(argv) > 2 else 0)
    else:
        raise SystemExit(__doc__)
    if befehl == "bilder":
        bild = bild.resize((bild.width * 3, bild.height * 3), Image.NEAREST)
    bild.save(OUT)
    print(OUT)

if __name__ == "__main__":
    main(sys.argv)
