"""Den Ruhelauf aus den Ebenen zusammensetzen und als GIF ausgeben.

    python3 -m tools.preview_parts [ziel.gif]

Drei Takte, absichtlich verschieden lang, damit sich das Bild nie wiederholt:
der Atem, das Baumeln der Beine, und das Blinzeln. Im Spiel zieht angler.gd
Blinzelabstand und Beinweite zufaellig; hier laeuft es mit festem Startwert,
damit die Vorschau vergleichbar bleibt.
"""
import math
import os
import random
import sys

from PIL import Image

from tools import figure_parts as fp

TEILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "assets", "source", "figure", "parts")
GRUND = (24, 28, 34)
ZOOM = 6
PRO_ZUG = 16        # Schritte je Atemzug
ZUEGE = 4
TAKT = 150          # Millisekunden je Schritt
BEIN_ZUG = 26       # Schritte je vollem Beinschwung -- laenger als ein Atemzug
BEIN_WEITEN = (2, 3, 4, 5, 6)
BLINZELN = ((20, "half", 55), (21, "closed", 90), (22, "half", 55),
            (50, "half", 55), (51, "closed", 90), (52, "half", 55))


def _punkte(img):
    px = img.load()
    return [(x, y) for y in range(fp.FRAME) for x in range(fp.FRAME)
            if px[x, y][3] > 128]


def zusammensetzen(ebenen, koepfe, atem, zopfweite, beinweite, auge,
                   kopf_seit=0):
    """Ein Bild. Reihenfolge: Zopf, Beine, Rumpf, Kopf.

    Der Kopf liegt OBEN. Lag der Rumpf oben, frass sein Schulterumriss beim
    Absenken die Kinnzeile. In Ruhe sind beide Reihenfolgen gleich, weil die
    Ebenen sich nicht ueberschneiden.
    """
    out = Image.new("RGBA", (fp.FRAME, fp.FRAME), (0, 0, 0, 0))
    op = out.load()
    zp = ebenen["ponytail"].load()
    bp = ebenen["legs"].load()
    rp = ebenen["torso"].load()
    kq = koepfe[auge].load()

    belegt = set()
    for x, y in _punkte(ebenen["ponytail"]):
        ## Der Zopf haengt am Kopf: geht der zur Seite, geht der ganze Zopf
        ## mit, und sein eigener Ausschlag kommt oben drauf.
        nx = x + kopf_seit + fp.swing(y, zopfweite, fp.ZOPF_GUMMI_Y,
                                      fp.ZOPF_SPITZE_Y)
        ny = y + atem
        if 0 <= nx < fp.FRAME and 0 <= ny < fp.FRAME:
            op[nx, ny] = zp[x, y]
            belegt.add((nx, ny))
    ## Wo der Zopf wegwandert und Kopfhaar anschliesst, mit dessen Ton fuellen.
    ## Nur dort -- an der Aussenkante wuechse sonst ihr Umriss.
    rumpf = set(_punkte(ebenen["torso"]))
    for x, y in _punkte(ebenen["ponytail"]):
        p = (x + kopf_seit, y + atem)
        if p in belegt or p in rumpf or not (0 <= p[1] < fp.FRAME):
            continue
        toene = {}
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (p[0] + dx - kopf_seit, p[1] + dy - atem)
                if 0 <= q[0] < fp.FRAME and 0 <= q[1] < fp.FRAME and kq[q][3] > 128:
                    toene[kq[q][:3]] = toene.get(kq[q][:3], 0) + 1
        if toene:
            op[p] = max(toene.items(), key=lambda t: t[1])[0] + (255,)

    for x, y in _punkte(ebenen["legs"]):
        nx = x + fp.swing(y, beinweite, fp.BEIN_KNIE_Y, fp.BEIN_ZEH_Y)
        if 0 <= nx < fp.FRAME:
            op[nx, y] = bp[x, y]
    for x, y in rumpf:
        op[x, y] = rp[x, y]
    for x, y in _punkte(ebenen["head"]):
        nx, ny = x + kopf_seit, y + atem
        if 0 <= nx < fp.FRAME and 0 <= ny < fp.FRAME:
            op[nx, ny] = kq[x, y]
    _luecken_schliessen(op)
    return out


def _luecken_schliessen(op):
    """Einzelne eingeschlossene Luecken mit der Nachbarfarbe fuellen.

    Geht der Kopf zur Seite, gibt er am Hals einen Pixel frei, unter dem der
    Rumpf nichts hat -- ein Loch mitten in der Figur. Betroffen ist nur, was
    ringsum zugedeckt ist; offene Flaechen bleiben offen.
    """
    loecher = []
    for y in range(1, fp.FRAME - 1):
        for x in range(1, fp.FRAME - 1):
            if op[x, y][3] > 128:
                continue
            nachbarn = [op[x - 1, y], op[x + 1, y], op[x, y - 1], op[x, y + 1]]
            if all(n[3] > 128 for n in nachbarn):
                loecher.append(((x, y), nachbarn))
    for feld, nachbarn in loecher:
        toene = {}
        for n in nachbarn:
            toene[n[:3]] = toene.get(n[:3], 0) + 1
        op[feld] = max(toene.items(), key=lambda t: t[1])[0] + (255,)


def ablauf(saat=7):
    """Die Schrittfolge: je Schritt Atem, Zopfweite, Beinweite, Augenstellung."""
    zufall = random.Random(saat)
    weite = zufall.choice(BEIN_WEITEN)
    vorzeichen = 0
    folge, dauer = [], []
    for i in range(ZUEGE * PRO_ZUG):
        t = (i % PRO_ZUG) / float(PRO_ZUG)
        atem = 1 if math.sin(2 * math.pi * t) < 0 else 0
        zopf = int(round(2 * math.sin(2 * math.pi * (t - 0.12))))
        schwung = math.sin(2 * math.pi * i / float(BEIN_ZUG) - 0.6)
        ## Neue Weite nur im Umkehrpunkt ziehen -- mittendrin spraenge das Bein.
        richtung = 1 if schwung >= 0 else -1
        if vorzeichen and richtung != vorzeichen:
            weite = zufall.choice(BEIN_WEITEN)
        vorzeichen = richtung
        folge.append((atem, zopf, int(round(weite * schwung)), "open"))
        dauer.append(TAKT)
    for i, auge, ms in BLINZELN:
        a, z, b, _ = folge[i]
        folge[i] = (a, z, b, auge)
        dauer[i] = ms
    return folge, dauer


def main(ziel):
    roh = Image.open(os.path.join(TEILE, "pose_raw.png")).convert("RGBA")
    rute = Image.open(os.path.join(TEILE, "rod.png")).convert("RGBA")
    ebenen = fp.split(fp.repair(roh), rute)
    koepfe = {s: fp.eye_state(ebenen["head"], s)
              for s in ("open", "half", "closed")}

    folge, dauer = ablauf()
    ## Gleiche Bilder selbst zusammenfassen und ihre Dauer addieren: der
    ## GIF-Schreiber wirft Wiederholungen weg, behaelt aber die Einzeldauern --
    ## und der Ablauf liefe zu schnell.
    bilder, zeiten = [], []
    for schritt, ms in zip(folge, dauer):
        img = zusammensetzen(ebenen, koepfe, *schritt)
        unten = Image.new("RGBA", img.size, GRUND + (255,))
        unten.alpha_composite(img)
        flach = unten.convert("RGB").resize(
            (fp.FRAME * ZOOM, fp.FRAME * ZOOM), Image.NEAREST)
        if bilder and flach.tobytes() == bilder[-1].tobytes():
            zeiten[-1] += ms
        else:
            bilder.append(flach)
            zeiten.append(ms)

    bilder[0].save(ziel, save_all=True, append_images=bilder[1:],
                   duration=zeiten, loop=0, optimize=False)
    print("%s: %d Bilder aus %d Schritten, %.1f s"
          % (ziel, len(bilder), len(folge), sum(zeiten) / 1000.0))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "idle.gif")
