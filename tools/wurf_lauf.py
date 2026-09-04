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
from tools import rute_anheften as ra

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(WURZEL, "assets", "source", "figure")
TEILE = os.path.join(SRC, "parts")
GRUND = (24, 28, 34)
ZOOM = 4
## Beim Ausholen steht die Rute bis zu 21 Zeilen ueber dem Figurenfeld. Das
## Bild bekommt deshalb Luft nach oben; die Figur bleibt, wo sie ist.
OBEN = 24
## ... und Platz nach links und unten fuer den Steg, auf dem sie sitzt.
LINKS = 96
UNTEN = 26
## Wie in scenes/fishing/world.gd: ihr Rocksaum liegt auf der vorderen
## Deckoberkante, das Deck 40 Stegpixel ueber dem Wasser. Steg und Figur haben
## denselben Massstab, ein Pixel ist ein Pixel.
CHAR_SEAT = 84
DECK_UEBER_WASSER = 40
WASSER = (0x2f, 0x4a, 0x34)

PRO_ZUG = 32        # Schritte je Atemzug -- 3,2 s, ein ruhiger Zug
BEIN_ZUG = 24       # Schritte je vollem Beinschwung
SCHWUENGE = 4
PAUSE = 20          # Schritte zwischen den Wuerfen
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


def buehne():
    """Der Steg hinter ihr, davor das Wasser -- die Pfosten enden darin.

    Dieselbe Anordnung wie im Spiel: Steg, dann Wasserflaeche, dann Figur.
    """
    from tools import steg_bauen as steg
    holz = Image.open(os.path.join(WURZEL, "assets", "art",
                                   "dock.png")).convert("RGBA")
    aus = Image.new("RGBA", (LINKS + fp.FRAME, OBEN + fp.FRAME + UNTEN),
                    (0, 0, 0, 0))
    ## Die vordere Deckoberkante unter ihren Rocksaum, das Stegende unter die
    ## Stelle, an der die Beine frei haengen.
    dx = LINKS + 68 - (steg.BREITE - 1)
    dy = OBEN + CHAR_SEAT - steg.HOCH
    aus.alpha_composite(holz, (0, dy), (-dx, 0, holz.width, holz.height))
    wasser_y = OBEN + CHAR_SEAT + DECK_UEBER_WASSER
    aus.alpha_composite(Image.new("RGBA", (aus.width, aus.height - wasser_y),
                                  WASSER + (255,)), (0, wasser_y))
    return aus


def hoch(bild):
    """Ein 128er Bild auf das hohe Feld setzen, die Figur bleibt an ihrem Platz."""
    out = Image.new("RGBA", (fp.FRAME, fp.FRAME + OBEN), (0, 0, 0, 0))
    out.alpha_composite(bild, (0, OBEN))
    return out


def wurfbild(ebenen, koepfe, stab, anker, griff, arm, zustand):
    """Ein Wurfbild aus seinen Teilen.

    Reihenfolge: Koerper, Rute, Arm -- die Rute liegt vor dem Rumpf und hinter
    der Hand. Als eigenes Sprite in ihrem 320er Feld ist sie vollstaendig;
    zusammengerechnet im 128er Feld war ihre Spitze abgeschnitten.

    Der Koerper wird wie im Ruhelauf aus Ebenen gebaut, nicht flach genommen.
    Sonst steht der Zopf ausgerechnet beim Ausholen still -- da, wo der Kopf
    am meisten mitgeht.
    """
    atem, zopf, bein, auge = zustand
    out = Image.new("RGBA", (fp.FRAME, fp.FRAME + OBEN), (0, 0, 0, 0))
    out.alpha_composite(pp.zusammensetzen(ebenen, koepfe, atem, zopf, bein, auge),
                        (0, OBEN))
    vx, vy = griff[0] - anker[0], griff[1] - anker[1]
    out.alpha_composite(stab, (0, 0),
                        (vx, vy - OBEN, vx + fp.FRAME, vy + fp.FRAME))
    out.alpha_composite(arm, (0, OBEN))
    return out


def zopf_im_wurf(nummer):
    """Der Zopf haengt am Kopf, und der geht beim Ausholen mit.

    Gegenlaeufig zum Arm und ein Zehntel seines Winkels: beim weitesten
    Ausholen (Schulter -30 Grad) schwingt er drei Pixel nach vorn.
    """
    return int(round(-ra.REIHE[nummer][0] * 0.1))


def ablauf(saat=11):
    """Die Schrittfolge: erst der Ruhelauf, dann zwei Wuerfe."""
    zufall = random.Random(saat)
    weite = zufall.choice(BEIN_WEITEN)
    vorzeichen = 0
    schritte = []
    takt = [0]      # laeuft durch, damit der Atem nirgends springt

    def atemzug():
        t = (takt[0] % PRO_ZUG) / float(PRO_ZUG)
        takt[0] += 1
        return (1 if math.sin(2 * math.pi * t) < 0 else 0,
                int(round(2 * math.sin(2 * math.pi * (t - 0.12)))))

    for i in range(SCHWUENGE * BEIN_ZUG):
        atem, zopf = atemzug()
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
        for _ in range(anzahl):
            atem, zopf = atemzug()
            schritte.append(["ruhe", None, atem, zopf, 0, "open", TAKT])

    def beine_anhalten():
        """Nur die Beine auf null fuehren -- beim Werfen haelt sie sie still.
        Atem und Zopf laufen weiter, die kommen jetzt auch im Wurf aus den
        Ebenen."""
        bein = schritte[-1][4]
        while bein:
            bein -= 1 if bein > 0 else -1
            atem, zopf = atemzug()
            schritte.append(["ruhe", None, atem, zopf, bein, "open", TAKT])

    for _ in range(2):
        beine_anhalten()
        for i in range(10):
            atem, zopf = atemzug()
            schritte.append(["wurf", i, atem, zopf + zopf_im_wurf(i), 0,
                             "open", WURF_TAKT])
        pause(PAUSE)
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
    ## Der Koerper OHNE Rute und ohne Wurfarm, in dieselben Ebenen geschnitten
    ## wie der Ruhelauf -- damit Zopf, Kopf und Beine auch im Wurf leben.
    koerper = Image.open(os.path.join(TEILE, "sit3_rumpf.png")).convert("RGBA")
    koerper.alpha_composite(Image.open(
        os.path.join(TEILE, "sit3_arm_fern.png")).convert("RGBA"))
    wurf_ebenen = fp.split(koerper)
    wurf_koepfe = {s: fp.eye_state(wurf_ebenen["head"], s)
                   for s in ("open", "half", "closed")}

    szene = buehne()
    bilder, zeiten = [], []
    for art, nummer, atem, zopf, bein, auge, ms in ablauf():
        if art == "ruhe":
            img = hoch(pp.zusammensetzen(ebenen, koepfe, atem, zopf, bein, auge))
        else:
            img = wurfbild(wurf_ebenen, wurf_koepfe, staebe[nummer],
                           anker["anker"][nummer], anker["griff"],
                           arme[nummer], (atem, zopf, bein, auge))
        ganz = szene.copy()
        ganz.alpha_composite(img, (LINKS, 0))
        unten = Image.new("RGBA", ganz.size, GRUND + (255,))
        unten.alpha_composite(ganz)
        flach = unten.convert("RGB").resize(
            (ganz.width * ZOOM, ganz.height * ZOOM), Image.NEAREST)
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
