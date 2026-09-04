"""Ruhelauf und Wurf in einem Ablauf, als GIF.

    python3 -m tools.wurf_lauf [ziel.gif]

Der Ruhelauf kommt aus den Ebenen (Atem, Zopf, Beine, Blinzeln), der Wurf
aus den zehn fertigen Bildern. Damit beides dieselbe Figur zeigt, werden die
Ebenen aus wurf_rute_0 geschnitten -- dem Ruhebild der Wurfreihe -- und nicht
aus pose_raw: dort steckt noch die alte Rute mit der Rolle.

Beim Wurf haengen die Beine still. Sie schwingen genau vier Mal, weil der
Ruhelauf auf 4 x BEIN_ZUG Schritte gelegt ist und der Schwung bei null
anfaengt und aufhoert -- so ist der Uebergang in den Wurf kein Sprung.
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image

from tools import figure_parts as fp
from tools import preview_parts as pp

SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "source", "figure")
TEILE = os.path.join(SRC, "parts")
GRUND = (24, 28, 34)
ZOOM = 5
## Beim Ausholen steht die Rute bis zu 21 Zeilen ueber dem Figurenfeld. Das
## Bild bekommt deshalb Luft nach oben; die Figur bleibt, wo sie ist.
OBEN = 24

PRO_ZUG = 16        # Schritte je Atemzug
BEIN_ZUG = 24       # Schritte je vollem Beinschwung
SCHWUENGE = 4
PAUSE = 16          # Schritte zwischen den Wuerfen, ein Atemzug
TAKT = 100          # Millisekunden je Ruheschritt
WURF_TAKT = 80      # der Wurf laeuft schneller
BEIN_WEITEN = (2, 3, 4, 5, 6)
## Drei Blinzler, verteilt ueber die vier Schwuenge. Die Zahl ist der
## Schritt, an dem das Lid halb zufaellt.
BLINZLER = (10, 42, 74)
BLINZELN = ((0, "half", 55), (1, "closed", 90), (2, "half", 55))


def rutenebene(bild):
    """Was die Rute im fertigen Bild ausmacht -- gegen die nackten Ebenen."""
    ohne = Image.open(os.path.join(TEILE, "sit3_rumpf.png")).convert("RGBA")
    for teil in ("sit3_arm_fern.png", "sit3_arm_nah.png"):
        ohne.alpha_composite(Image.open(os.path.join(TEILE, teil)).convert("RGBA"))
    a = np.array(bild).astype(int)
    b = np.array(ohne).astype(int)
    anders = (np.abs(a - b).sum(2) > 30) | ((a[:, :, 3] > 128) & (b[:, :, 3] <= 128))
    out = Image.new("RGBA", bild.size, (0, 0, 0, 0))
    op, bp = out.load(), bild.load()
    for y in range(fp.FRAME):
        for x in range(fp.FRAME):
            if anders[y, x]:
                op[x, y] = bp[x, y]
    return out


def hoch(bild):
    """Ein 128er Bild auf das hohe Feld setzen, die Figur bleibt an ihrem Platz."""
    out = Image.new("RGBA", (fp.FRAME, fp.FRAME + OBEN), (0, 0, 0, 0))
    out.alpha_composite(bild, (0, OBEN))
    return out


def wurfbild(koerper, stab, anker, griff, arm, beine, beinweite):
    """Ein Wurfbild aus seinen Teilen, mit ausgetauschten Beinen.

    Reihenfolge: Koerper, Rute, Arm -- die Rute liegt vor dem Rumpf und hinter
    der Hand. Als eigenes Sprite in ihrem 320er Feld ist sie vollstaendig;
    zusammengerechnet im 128er Feld war ihre Spitze abgeschnitten.

    Unterhalb des Knieschnitts sind alle zehn Wurfbilder gleich -- nachgemessen
    null Unterschied. Also darf die Beinebene sie ersetzen.
    """
    out = Image.new("RGBA", (fp.FRAME, fp.FRAME + OBEN), (0, 0, 0, 0))
    op, kp, bp = out.load(), koerper.load(), beine.load()
    for y in range(fp.FRAME):
        for x in range(fp.FRAME):
            if fp.layer_of(x, y) != "legs" and kp[x, y][3] > 128:
                op[x, y + OBEN] = kp[x, y]
    for y in range(fp.FRAME):
        for x in range(fp.FRAME):
            if bp[x, y][3] <= 128:
                continue
            nx = x + fp.swing(y, beinweite, fp.BEIN_KNIE_Y, fp.BEIN_ZEH_Y)
            if 0 <= nx < fp.FRAME:
                op[nx, y + OBEN] = bp[x, y]
    vx, vy = griff[0] - anker[0], griff[1] - anker[1]
    out.alpha_composite(stab, (0, 0),
                        (vx, vy - OBEN, vx + fp.FRAME, vy + fp.FRAME))
    out.alpha_composite(arm, (0, OBEN))
    return out


def ablauf(saat=11):
    """Die Schrittfolge: erst der Ruhelauf, dann zwei Wuerfe."""
    zufall = random.Random(saat)
    weite = zufall.choice(BEIN_WEITEN)
    vorzeichen = 0
    schritte = []

    for i in range(SCHWUENGE * BEIN_ZUG):
        t = (i % PRO_ZUG) / float(PRO_ZUG)
        atem = 1 if math.sin(2 * math.pi * t) < 0 else 0
        zopf = int(round(2 * math.sin(2 * math.pi * (t - 0.12))))
        schwung = math.sin(2 * math.pi * i / float(BEIN_ZUG))
        ## Neue Weite nur im Umkehrpunkt ziehen -- mittendrin spraenge das Bein.
        richtung = 1 if schwung >= 0 else -1
        if vorzeichen and richtung != vorzeichen:
            weite = zufall.choice(BEIN_WEITEN)
        vorzeichen = richtung
        schritte.append(["ruhe", None, atem, zopf,
                         int(round(weite * schwung)), "open", TAKT])

    for start in BLINZLER:
        for weiter, auge, ms in BLINZELN:
            schritte[start + weiter][5] = auge
            schritte[start + weiter][6] = ms

    def pause(anzahl):
        for i in range(anzahl):
            t = (i % PRO_ZUG) / float(PRO_ZUG)
            atem = 1 if math.sin(2 * math.pi * t) < 0 else 0
            zopf = int(round(2 * math.sin(2 * math.pi * (t - 0.12))))
            schritte.append(["ruhe", None, atem, zopf, 0, "open", TAKT])

    def beruhigen():
        """Kopf, Zopf und Beine auf null fuehren -- der Wurf beginnt aus der
        Ruhe, und im Wurfbild sind sie fest eingezeichnet. Ohne das springt
        der Zopf beim ersten Wurfbild um zwei Pixel."""
        _, _, _, zopf, bein, _, _ = schritte[-1]
        while zopf or bein:
            zopf -= (1 if zopf > 0 else -1) if zopf else 0
            bein -= (1 if bein > 0 else -1) if bein else 0
            schritte.append(["ruhe", None, 0, zopf, bein, "open", TAKT])

    for wurf in range(2):
        beruhigen()
        for i in range(10):
            schritte.append(["wurf", i, 0, 0, 0, "open", WURF_TAKT])
        pause(PAUSE)
    beruhigen()
    return schritte


def main(ziel):
    ruhe = Image.open(os.path.join(SRC, "wurf_rute_0.png")).convert("RGBA")
    ebenen = fp.split(ruhe, rutenebene(ruhe))
    koepfe = {s: fp.eye_state(ebenen["head"], s)
              for s in ("open", "half", "closed")}
    anker = json.load(open(os.path.join(SRC, "wurf_anker.json")))
    staebe = [Image.open(os.path.join(SRC, "wurf_stab_%d.png" % i)).convert("RGBA")
              for i in range(10)]
    arme = [Image.open(os.path.join(SRC, "wurf_arm_%d.png" % i)).convert("RGBA")
            for i in range(10)]
    koerper = Image.open(os.path.join(TEILE, "sit3_rumpf.png")).convert("RGBA")
    koerper.alpha_composite(Image.open(
        os.path.join(TEILE, "sit3_arm_fern.png")).convert("RGBA"))

    bilder, zeiten = [], []
    for art, nummer, atem, zopf, bein, auge, ms in ablauf():
        if art == "ruhe":
            img = hoch(pp.zusammensetzen(ebenen, koepfe, atem, zopf, bein, auge))
        else:
            img = wurfbild(koerper, staebe[nummer], anker["anker"][nummer],
                           anker["griff"], arme[nummer], ebenen["legs"], bein)
        unten = Image.new("RGBA", img.size, GRUND + (255,))
        unten.alpha_composite(img)
        flach = unten.convert("RGB").resize(
            (img.width * ZOOM, img.height * ZOOM), Image.NEAREST)
        ## Gleiche Bilder zusammenfassen: der GIF-Schreiber wirft
        ## Wiederholungen weg, behaelt aber die Einzeldauern.
        if bilder and flach.tobytes() == bilder[-1].tobytes():
            zeiten[-1] += ms
        else:
            bilder.append(flach)
            zeiten.append(ms)

    bilder[0].save(ziel, save_all=True, append_images=bilder[1:],
                   duration=zeiten, loop=0, optimize=True)
    print("%s: %d Bilder, %.1f s, %d kB"
          % (ziel, len(bilder), sum(zeiten) / 1000.0,
             os.path.getsize(ziel) // 1024))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "wurf_lauf.gif")
