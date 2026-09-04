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
from PIL import Image, ImageDraw

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
## ... und offenes Wasser nach rechts, damit der Koeder irgendwo hinfliegen
## kann. Ohne das endet das Bild eine Handbreit hinter der Rutenspitze.
RECHTS = 64
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

## --- Schwimmer und Koeder -------------------------------------------------
##
## Wie im Spiel (scenes/fishing/world.gd): der Koeder haengt am Vorfach unter
## dem Schwimmer, beide haengen bis zur Freigabe an der Rutenspitze, fliegen
## dann einen Bogen und setzen auf dem Wasser auf. Danach ist der Koeder unter
## Wasser und nur der Schwimmer wippt noch.
WURF_LOESUNG = 8       # ab diesem Wurfbild ist die Schnur draussen
FLUG = 12              # Schritte, die der Flug dauert
KOEDER_HANG = 10       # wie weit der Koeder unter dem Schwimmer haengt
BOGEN = 26             # wie hoch der Flug ueber die Verbindungslinie geht
SCHNUR = (0xeb, 0xe6, 0xd1, 217)
## Wo der Schwimmer aufsetzt, in Buehnenkoordinaten. Rechts vom Stegende, und
## zwei Zeilen ueber der Wasserlinie: er liegt IM Wasser, nicht darauf.
ZIEL = (LINKS + fp.FRAME + 20, OBEN + CHAR_SEAT + DECK_UEBER_WASSER - 2)


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
    aus = Image.new("RGBA", (LINKS + fp.FRAME + RECHTS,
                             OBEN + fp.FRAME + UNTEN), (0, 0, 0, 0))
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
    atem, zopf, bein, auge, seit = zustand
    out = Image.new("RGBA", (fp.FRAME, fp.FRAME + OBEN), (0, 0, 0, 0))
    out.alpha_composite(
        pp.zusammensetzen(ebenen, koepfe, atem, zopf, bein, auge, seit),
        (0, OBEN))
    vx, vy = griff[0] - anker[0], griff[1] - anker[1]
    out.alpha_composite(stab, (0, 0),
                        (vx, vy - OBEN, vx + fp.FRAME, vy + fp.FRAME))
    out.alpha_composite(arm, (0, OBEN))
    return out


## Die Beine gehen beim Ausholen nach vorn und schwingen beim Auswerfen
## zurueck -- das Gegengewicht zum Arm. Von Hand gesetzt, ein Wert je
## Wurfbild, positiv ist in Blickrichtung.
BEIN_WURF = (0, 2, 4, 5, 6, 3, -1, -4, -3, -1)
## Am weitesten Punkt haelt sie kurz -- ohne das wirkt der Wurf wie ein
## Durchrutschen statt wie Schwungholen.
WURF_HALT = {4: 220}


def zopf_im_wurf(nummer):
    """Der Zopf haengt am Kopf, und der geht beim Ausholen mit.

    Gegenlaeufig zum Arm und ein Zehntel seines Winkels: beim weitesten
    Ausholen (Schulter -30 Grad) schwingt er drei Pixel nach vorn.
    """
    return int(round(-ra.REIHE[nummer][0] * 0.1))


def kopf_im_wurf(nummer):
    """Der Kopf lehnt beim Ausholen zurueck -- ein Zwanzigstel des
    Schulterwinkels, also hoechstens zwei Pixel. Mehr sieht nach Nicken aus
    statt nach Schwungholen."""
    return int(round(ra.REIHE[nummer][0] * 0.05))


def rutenspitze(stab, griff, anker):
    """Wo die Rutenspitze in Figurkoordinaten liegt.

    Der am weitesten vom Griff entfernte Punkt des Rutenbilds -- die Rute ist
    eine Linie, ihr fernstes Ende ist die Spitze. Das Rutenbild hat ein
    eigenes, groesseres Feld; hier wird es auf das Figurfeld zurueckgerechnet.
    """
    gx, gy = griff
    px = stab.load()
    weit, spitze = -1, (0, 0)
    for y in range(stab.height):
        for x in range(stab.width):
            if px[x, y][3] > 128:
                d = (x - gx) ** 2 + (y - gy) ** 2
                if d > weit:
                    weit, spitze = d, (x, y)
    return (spitze[0] - (gx - anker[0]), spitze[1] - (gy - anker[1]))


def flugbahn(von, nach, t):
    """Quadratische Bezierkurve mit Scheitel darueber -- wie world.gd."""
    scheitel = ((von[0] + nach[0]) * 0.5, (von[1] + nach[1]) * 0.5 - BOGEN)
    g = 1.0 - t
    return (g * g * von[0] + 2 * g * t * scheitel[0] + t * t * nach[0],
            g * g * von[1] + 2 * g * t * scheitel[1] + t * t * nach[1])


def _setzen(bild, teil, mitte):
    """Ein Sprite mit seiner Mitte auf diesen Punkt."""
    bild.alpha_composite(teil, (int(round(mitte[0] - teil.width / 2.0)),
                                int(round(mitte[1] - teil.height / 2.0))))


def koeder_zeichnen(bild, zustand, spitze, abwurf, schwimmer, made):
    """Schnur, Schwimmer und Koeder in dieses Buehnenbild.

    Die Schnur laeuft von der Rutenspitze ueber den Schwimmer zum Koeder und
    wird zuerst gezeichnet -- die beiden Sprites decken sie dort zu, wo sie
    ansetzt. Nach dem Aufsetzen ist der Koeder unter Wasser und damit weg.
    """
    art, wert = zustand
    if art == "haengt":
        mitte = (spitze[0], spitze[1] + schwimmer.height / 2.0)
    elif art == "flug":
        mitte = flugbahn(abwurf, ZIEL, wert)
    else:
        mitte = (ZIEL[0], ZIEL[1] + round(math.sin(wert * 0.6)))
    am_haken = art != "schwimmt"
    schnur = Image.new("RGBA", bild.size, (0, 0, 0, 0))
    punkte = [spitze, mitte]
    if am_haken:
        punkte.append((mitte[0], mitte[1] + KOEDER_HANG))
    ImageDraw.Draw(schnur).line(punkte, fill=SCHNUR, width=1)
    bild.alpha_composite(schnur)
    _setzen(bild, schwimmer, mitte)
    if am_haken:
        _setzen(bild, made, (mitte[0], mitte[1] + KOEDER_HANG))


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
                         int(round(weite * schwung)), "open", TAKT, 0, None])

    for start in BLINZLER:
        for weiter, auge, ms in BLINZELN:
            schritte[start + weiter][5] = auge
            schritte[start + weiter][6] = ms

    def pause(anzahl):
        for _ in range(anzahl):
            atem, zopf = atemzug()
            schritte.append(["ruhe", None, atem, zopf, 0, "open", TAKT, 0,
                             koeder()])

    flug = [None]       # laeuft ab der Freigabe, dann bleibt der Schwimmer

    def koeder(nummer=None):
        """Der Zustand von Schwimmer und Koeder in diesem Schritt.

        Bis zur Freigabe haengen sie an der Rutenspitze des Wurfbilds, danach
        laeuft der Flug los und mit ihm die Landung -- unabhaengig davon, ob
        gerade noch ein Wurfbild oder schon die Pause laeuft.
        """
        if flug[0] is None:
            if nummer is None:
                return None
            if nummer < WURF_LOESUNG:
                return ("haengt", nummer)
            flug[0] = 0
        schritt = flug[0]
        flug[0] += 1
        if schritt < FLUG:
            return ("flug", schritt / float(FLUG - 1))
        return ("schwimmt", schritt - FLUG)

    def beine_anhalten():
        """Nur die Beine auf null fuehren -- beim Werfen haelt sie sie still.
        Atem und Zopf laufen weiter, die kommen jetzt auch im Wurf aus den
        Ebenen."""
        bein = schritte[-1][4]
        while bein:
            bein -= 1 if bein > 0 else -1
            atem, zopf = atemzug()
            schritte.append(["ruhe", None, atem, zopf, bein, "open", TAKT, 0,
                             None])

    for _ in range(2):
        flug[0] = None
        beine_anhalten()
        for i in range(10):
            atem, zopf = atemzug()
            schritte.append(["wurf", i, atem, zopf + zopf_im_wurf(i),
                             BEIN_WURF[i], "open",
                             WURF_HALT.get(i, WURF_TAKT), kopf_im_wurf(i),
                             koeder(i)])
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

    ## Schwimmer und Koeder sind dieselben Sprites wie im Spiel.
    kunst = os.path.join(WURZEL, "assets", "art")
    schwimmer = Image.open(os.path.join(kunst, "bobber.png")).convert("RGBA")
    made = Image.open(os.path.join(kunst, "bait_pond_grub.png")).convert("RGBA")
    spitzen = [rutenspitze(staebe[i], anker["griff"], anker["anker"][i])
               for i in range(10)]
    ## Von hier laeuft der Flug: die Spitze im Moment der Freigabe.
    abwurf = (spitzen[WURF_LOESUNG][0] + LINKS,
              spitzen[WURF_LOESUNG][1] + OBEN + schwimmer.height / 2.0)

    szene = buehne()
    bilder, zeiten = [], []
    for art, nummer, atem, zopf, bein, auge, ms, seit, koeder in ablauf():
        if art == "ruhe":
            img = hoch(pp.zusammensetzen(ebenen, koepfe, atem, zopf, bein,
                                         auge, seit))
        else:
            img = wurfbild(wurf_ebenen, wurf_koepfe, staebe[nummer],
                           anker["anker"][nummer], anker["griff"],
                           arme[nummer], (atem, zopf, bein, auge, seit))
        ganz = szene.copy()
        ganz.alpha_composite(img, (LINKS, 0))
        if koeder is not None:
            ## Im Ruhelauf steht die Rute wie in Wurfbild 0.
            sx, sy = spitzen[nummer if art == "wurf" else 0]
            koeder_zeichnen(ganz, koeder, (sx + LINKS, sy + OBEN), abwurf,
                            schwimmer, made)
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
