"""Die Rute an die Faust haengen -- Schaft gedreht, Rolle nur verschoben.

Der Schaft ist eine lange Diagonale, den kann RotSprite drehen. Die Rolle
ist ein dichter Klumpen aus zwoelf Farben auf zwanzig Pixeln; gedreht wird
daraus braunes Geflimmer. Sie haengt am Griff, macht also nur die
Ortsaenderung mit und behaelt ihr Bild -- dieselbe Regel wie bei der Hand.

Gezeichnet wird die Rute vor den Rumpf, aber hinter den vorderen Arm: so
liegt der Griff in der Faust und nicht darueber.
"""
import math
import os
import sys
import tempfile

import numpy as np
from PIL import Image

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
import rotsprite

W = os.path.dirname(S)
SRC = os.path.join(W, "assets", "source", "figure")
P = os.path.join(SRC, "parts")
VORSCHAU = os.environ.get("VORSCHAU", tempfile.gettempdir())

SCHULTER = (49.5, 41.0)
ELLBOGEN = (54.0, 60.0)
UEBERLAPP = 3.0
STUFEN, N = 4, 16
FAUST = (70.0, 68.0)          # Mitte der Faust im Ruhebild
GRIFF = (160.0, 160.0)        # ROD_GRIP im 320er Rutenraster
QUER = 3.0                    # ab diesem Abstand zur Rutenachse: Rolle
KORK = 0.0                    # die Rute bringt ihr Griffende schon mit
## Feinkorrektur je Bild: Winkel in Grad, dann Versatz in Feldern. Wird
## Bild fuer Bild abgenommen, nicht ueber die ganze Reihe gemittelt -- die
## Rute sitzt in jeder Pose anders in der Faust.
KORREKTUR = [(0.0, (0, 0))] * 10
KORREKTUR[1] = (2.5, (0, 1))
KORREKTUR[3] = (-13.6, (0, 0))   # eingezeichnete Richtung: -121.4 Grad
KORREKTUR[4] = (-8.3, (0, 0))    # Umkehrpunkt bleibt hinter Pose 4: -128.0 Grad
KORREKTUR[5] = (-7.4, (0, 0))    # eingezeichnete Richtung: -116.4 Grad
KORREKTUR[7] = (8.3, (0, 0))     # eingezeichnete Richtung: -58.3 Grad
KORREKTUR[8] = (5.5, (0, 0))     # eingezeichnete Richtung: -43.7 Grad

## Der Griff, wo Aermel und Rute sich ueberschneiden: von Hand gesetzt, Bild
## fuer Bild. Automatisch gefuellt sah es wie ein Klotz aus -- der Griff hat
## eine obere Kante, eine Flaeche mit zwei Tonwerten und eine dunkle
## Unterkante, und wo die liegen, entscheidet die Pose.
HOLZ_DUNKEL = (0x44, 0x25, 0x19)
HOLZ = (0x6a, 0x3a, 0x22)
HOLZ_HELL = (0x7d, 0x46, 0x27)
SCHWARZ = (0x00, 0x00, 0x00)
HAUT_DUNKEL = (0x9e, 0x3f, 0x51)   # die Kante unten an der Hand
## Kein Ton, sondern eine Anweisung: nimm, was hinter der Rute liegt (Rock,
## Aermel). None loescht dagegen wirklich -- nur dort, wo nichts dahinter ist.
DAHINTER = "dahinter"
GRIFF_FLICKEN = [[] for _ in range(10)]
GRIFF_FLICKEN[1] = (
    [((72, 67), HOLZ_DUNKEL), ((72, 68), HOLZ_DUNKEL)]
    + [((x, y), HOLZ) for x, y in ((73, 67), (74, 67), (74, 68), (75, 68), (72, 69))]
    + [((73, 68), HOLZ_HELL), ((74, 69), HOLZ_HELL)]
    + [((76, 68), SCHWARZ), ((75, 69), SCHWARZ)]
)
## Pose 3 steht fast senkrecht: hier fehlt der Schaft im Faustschluss und das
## Stueck zwischen Handkante und Griff.
GRIFF_FLICKEN[2] = (
    [((x, y), HOLZ) for x, y in ((77, 50), (76, 51), (77, 51),
                                 (77, 59), (78, 59), (79, 59), (77, 60))]
    + [((76, 60), HOLZ_DUNKEL), ((80, 59), SCHWARZ)]
)
## Pose 4 liegt am weitesten hinten: Schaft in die Faust, und der schwarze
## Zipfel bei 80/42 muss weg (None = Feld leeren).
GRIFF_FLICKEN[3] = [((75, 44), HOLZ), ((76, 44), SCHWARZ), ((80, 42), None)]
## Pose 5, Umkehrpunkt: dunkle Griffkante an der Handunterseite entlang.
GRIFF_FLICKEN[4] = (
    [((x, y), HOLZ_DUNKEL) for x, y in ((74, 39), (80, 46), (79, 47), (79, 48), (79, 49))]
    + [((79, 45), HAUT_DUNKEL), ((80, 45), SCHWARZ)]
)
## Pose 6, Arm kommt vor: Schaft bis in die Faust, Griff unten angesetzt.
GRIFF_FLICKEN[5] = (
    [((x, y), HOLZ) for x, y in ((77, 41), (77, 43), (77, 44), (76, 45),
                                 (81, 52), (80, 53))]
    + [((x, y), HOLZ_DUNKEL) for x, y in ((75, 45), (79, 53), (79, 54), (79, 55))]
    + [((x, y), SCHWARZ) for x, y in ((78, 41), (78, 42), (78, 43), (80, 52))]
    + [((81, 44), None), ((82, 51), None)]
)
## Pose 7: Schaft schliesst an die Faust an, Handkante unten ergaenzt.
GRIFF_FLICKEN[6] = (
    [((x, y), HOLZ) for x, y in ((77, 53), (79, 53), (77, 54), (78, 54), (75, 63))]
    + [((76, 54), HOLZ_DUNKEL), ((80, 53), SCHWARZ), ((77, 62), HAUT_DUNKEL)]
    + [((80, 62), None)]
)
## Pose 8, fast wieder in Ruhe: Schaftkante vor der Hand, Griff im Gras.
GRIFF_FLICKEN[7] = (
    [((69, 71), HOLZ), ((70, 71), HOLZ)]
    + [((x, y), HOLZ_DUNKEL) for x, y in ((73, 62), (73, 63), (68, 70))]
    + [((71, 71), HAUT_DUNKEL), ((72, 72), SCHWARZ), ((78, 66), None)]
)
## Pose 9, tiefster Punkt: der Schaft lief durchs Gras, hier wieder geschlossen.
GRIFF_FLICKEN[8] = (
    [((x, y), HOLZ) for x, y in ((69, 69), (70, 69), (70, 70), (71, 70), (72, 70))]
    + [((64, 77), SCHWARZ), ((72, 71), SCHWARZ), ((61, 80), SCHWARZ)]
    + [((71, 73), HAUT_DUNKEL)]
    + [((72, 74), DAHINTER), ((62, 80), DAHINTER)]
)
## Pose 10, zurueck in Ruhe: Schaft in die Faust, Griff am Rock entlang.
GRIFF_FLICKEN[9] = (
    [((x, y), HOLZ) for x, y in ((71, 68), (72, 68), (65, 74), (65, 75), (66, 75))]
    + [((64, 74), HOLZ_DUNKEL), ((67, 76), SCHWARZ), ((67, 75), HAUT_DUNKEL)]
    + [((74, 71), DAHINTER)]
)

## Schulter- und Ellbogenwinkel je Bild -- die Wurfreihe.
REIHE = [(0, 0), (-7, -11), (-15, -25), (-23, -36), (-30, -44),
         (-23, -33), (-13, -18), (-3, -4), (4, 8), (2, 4)]
WINKEL = [-55.9, -74.8, -99.0, -107.8, -119.7, -109.0, -79.5, -66.6, -49.2, -53.6]


def teile_rute(bild):
    """Rolle vom Rest trennen: der groesste Klumpen abseits der Achse."""
    a = np.array(bild)
    m = a[:, :, 3] > 128
    ys, xs = np.where(m)
    # Achse an der duennen Haelfte messen, sonst kippt sie die Rolle mit.
    weit = np.hypot(xs - GRIFF[0], ys - GRIFF[1]) > 40
    p = np.stack([xs[weit], ys[weit]], 1).astype(float)
    mitte = p.mean(0)
    quer = np.linalg.svd(p - mitte, full_matrices=False)[2][1]
    abstand = (np.stack([xs, ys], 1).astype(float) - mitte) @ quer

    kandidaten = {(int(x), int(y)) for x, y, d in zip(xs, ys, abstand) if abs(d) > QUER}
    teile, rest = [], set(kandidaten)
    while rest:
        keim = rest.pop()
        stapel, teil = [keim], {keim}
        while stapel:
            x, y = stapel.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in rest:
                        rest.discard(n)
                        teil.add(n)
                        stapel.append(n)
        teile.append(teil)
    rolle = max(teile, key=len)

    rb = Image.new("RGBA", bild.size, (0, 0, 0, 0))
    sb = bild.copy()
    rp, sp = rb.load(), sb.load()
    for x, y in rolle:
        rp[x, y] = sp[x, y]
        sp[x, y] = (0, 0, 0, 0)
    anker = (sum(x for x, _ in rolle) / len(rolle), sum(y for _, y in rolle) / len(rolle))
    print("Rolle %d Px, Anker %.1f/%.1f" % (len(rolle), anker[0], anker[1]))
    return sb, rb, anker


TOENE = [(0x10, 0x0f, 0x14), (0x23, 0x29, 0x32), (0x47, 0x4b, 0x53),
         (0x7c, 0x84, 0x8f), (0x47, 0x35, 0x2c), (0x60, 0x35, 0x0c), (0xb1, 0x84, 0x47)]
BRAUN = {(0x47, 0x35, 0x2c), (0x60, 0x35, 0x0c), (0xb1, 0x84, 0x47)}
DUNKEL = {(0x10, 0x0f, 0x14), (0x23, 0x29, 0x32)}


def saeubern(bild):
    """Nach dem Drehen wieder auf sieben Toene bringen und Kruemel wegnehmen.

    Dieselben drei Schritte, mit denen die Rolle von Hand aufgeraeumt wurde:
    Toene zusammenlegen, einzelne Pixel an die Nachbarschaft angleichen, und
    schwarze Loecher mitten in der Spule mit ihrem Braun fuellen.
    """
    a = np.array(bild)
    h, b = a.shape[:2]

    def farbe(x, y):
        return tuple(int(v) for v in a[y, x, :3])

    for y in range(h):
        for x in range(b):
            if a[y, x, 3] > 128:
                f = farbe(x, y)
                a[y, x, :3] = min(TOENE, key=lambda t: sum((t[i] - f[i]) ** 2 for i in range(3)))

    def nachbarn(x, y):
        c = {}
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < b and 0 <= ny < h and a[ny, nx, 3] > 128:
                    f = farbe(nx, ny)
                    c[f] = c.get(f, 0) + 1
        return c

    neu = a.copy()
    for y in range(h):
        for x in range(b):
            if a[y, x, 3] <= 128:
                continue
            c = nachbarn(x, y)
            eigen = farbe(x, y)
            if c and c.get(eigen, 0) == 0:
                neu[y, x, :3] = max(c, key=c.get)
    a = neu

    for y in range(h):
        for x in range(b):
            if a[y, x, 3] <= 128 or farbe(x, y) not in DUNKEL:
                continue
            c = nachbarn(x, y)
            if sum(n for f, n in c.items() if f in BRAUN) >= 4:
                a[y, x, :3] = max((f for f in c if f in BRAUN), key=lambda f: c[f])
    return Image.fromarray(a, "RGBA")


def drehen(p, w, um):
    c, s = math.cos(w), math.sin(w)
    dx, dy = p[0] - um[0], p[1] - um[1]
    return (um[0] + dx * c - dy * s, um[1] + dx * s + dy * c)


def main():
    rumpf = Image.open(os.path.join(P, "sit3_rumpf.png")).convert("RGBA")
    fern = Image.open(os.path.join(P, "sit3_arm_fern.png")).convert("RGBA")
    nah = np.array(Image.open(os.path.join(P, "sit3_arm_nah.png")).convert("RGBA"))
    # Die Rute, die es im Projekt schon gab: sie hat das Griffende unter der
    # Faust, das im gebauten Rutenblatt abgeschnitten war. Ins 320er Raster
    # gesetzt, damit die Spitze beim Schwenken nicht aus dem Bild laeuft.
    blatt = Image.open(os.path.join(P, "rute_mit_griff.png")).convert("RGBA")
    schaft = blatt
    schaft_gross = rotsprite.vergroessern(rotsprite._packen(np.array(schaft)), STUFEN)

    rx, ry = ELLBOGEN[0] - SCHULTER[0], ELLBOGEN[1] - SCHULTER[1]
    lg = math.hypot(rx, ry)
    rx, ry = rx / lg, ry / lg
    yy, xx = np.mgrid[0:128, 0:128]
    s = (xx - ELLBOGEN[0]) * rx + (yy - ELLBOGEN[1]) * ry
    da = nah[:, :, 3] > 128
    oben = rotsprite.vergroessern(rotsprite._packen(nah * ((da & (s <= 0))[:, :, None])), STUFEN)
    unten = rotsprite.vergroessern(rotsprite._packen(nah * ((da & (s > -UEBERLAPP))[:, :, None])), STUFEN)

    # Wie die gezeichnete Rute selbst liegt, gemessen von Griff zu Spitze.
    ys, xs = np.where(np.array(blatt.crop((0, 0, 320, 320)))[:, :, 3] > 128)
    sp = max(zip(xs, ys), key=lambda q: (q[0] - GRIFF[0]) ** 2 + (q[1] - GRIFF[1]) ** 2)
    grund = math.degrees(math.atan2(sp[1] - GRIFF[1], sp[0] - GRIFF[0]))
    print("Rute zeigt von Haus aus auf %.1f Grad" % grund)

    bilder = []
    for i, (((ga, gb), soll)) in enumerate(zip(REIHE, WINKEL)):
        a, b = math.radians(ga), math.radians(gb)
        nach, VERSATZ = KORREKTUR[i]
        soll = soll + nach
        dreh_rute = math.radians(soll - grund)
        achse = (math.cos(math.radians(soll)), math.sin(math.radians(soll)))
        ganz = rumpf.copy()
        ganz.alpha_composite(fern)
        untergrund = ganz.copy()   # fuer DAHINTER: Rumpf und hinterer Arm ohne Rute
        hinten = untergrund.load()

        faust = drehen(drehen(FAUST, b, ELLBOGEN), a, SCHULTER)
        # Der Griff steckt ein Stueck in der Faust, sonst klebt die Rute daneben.
        sitz = (faust[0] - achse[0] * KORK, faust[1] - achse[1] * KORK)
        vx = int(round(GRIFF[0] - sitz[0] - VERSATZ[0]))
        vy = int(round(GRIFF[1] - sitz[1] - VERSATZ[1]))
        gedreht = Image.fromarray(rotsprite._entpacken(rotsprite.verkleinern(
            rotsprite.drehen_kette(schaft_gross, [(dreh_rute, GRIFF)], N), N)), "RGBA")
        rutenebene = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        rutenebene.alpha_composite(gedreht, (0, 0), (vx, vy, vx + 128, vy + 128))
        ganz.alpha_composite(rutenebene)

        for feld, kette in ((unten, [(b, ELLBOGEN), (a, SCHULTER)]), (oben, [(a, SCHULTER)])):
            ganz.alpha_composite(Image.fromarray(rotsprite._entpacken(
                rotsprite.verkleinern(rotsprite.drehen_kette(feld, kette, N), N)), "RGBA"))

        # Zuletzt, damit die Handpixel den Griff nicht wieder ueberdecken.
        gp = ganz.load()
        for feld, ton in GRIFF_FLICKEN[i]:
            if ton is DAHINTER:
                gp[feld] = hinten[feld]
            else:
                gp[feld] = (0, 0, 0, 0) if ton is None else ton + (255,)
        bilder.append(ganz)

    # Die fertigen Bilder gehoeren ins Projekt, nicht nur in die Vorschau.
    for i, bild in enumerate(bilder):
        bild.save(os.path.join(SRC, "wurf_rute_%d.png" % i))

    Z = 4
    folge = [b.resize((128 * Z, 128 * Z), Image.NEAREST).convert("RGB") for b in bilder]
    folge[0].save(os.path.join(VORSCHAU, "rute.gif"), save_all=True,
                  append_images=folge[1:], duration=110, loop=0)
    Z2 = 7
    t = Image.new("RGBA", (128 * Z2 * 4 + 24, 128 * Z2), (18, 18, 22, 255))
    for i, k in enumerate((0, 2, 4, 6)):
        g = bilder[k].resize((128 * Z2, 128 * Z2), Image.NEAREST)
        u = Image.new("RGBA", g.size, (28, 32, 38, 255))
        u.alpha_composite(g)
        t.alpha_composite(u, (i * (128 * Z2 + 8), 0))
    t.save(os.path.join(VORSCHAU, "rute_vier.png"))
    print("Kontrollbilder in %s" % VORSCHAU)
    return bilder


if __name__ == "__main__":
    main()
