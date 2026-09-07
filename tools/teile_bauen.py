#!/usr/bin/env python3
"""Baut die Blaetter je Teil und Kosmetikebene.

Die Figur wird im Spiel nicht als fertige Bilderreihe gezeigt, sondern aus
beweglichen Teilen zusammengesetzt -- nur so kann die Weite des Beinschwungs
je Schwung neu gezogen werden. Gebacken wird deshalb je TEIL, auf seinen
eigenen Rahmen zugeschnitten: der Zopf ist 19 mal 34 Pixel gross, ihn als
volles 128er Bild abzulegen verschenkt das Sechzehnfache.

    python3 -m tools.teile_bauen
"""
import os

from PIL import Image

from tools import figure_parts as fp
from tools import preview_parts as pp

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(WURZEL, "assets", "source", "figure")
TEILE = os.path.join(SRC, "parts")

## Die Zustaende je Teil, alle am Bild gemessen (siehe die Spec vom
## 2026-09-07). Der Atemzug hat zwar 32 Schritte, aber nur acht verschiedene
## Atem/Zopf-Zustaende -- beide haengen an derselben Phase.
ATEM = (0, 1)
BEIN_WEITEN = tuple(range(-6, 7))
AUGEN = ("open", "half", "closed")


## Der Zopf haengt nicht nur an seiner eigenen Weite, sondern auch am
## Kopfversatz: die Naht zwischen ihm und dem Kopf liegt je nach beidem
## woanders, und sie muss ins Blatt gebacken werden -- im Spiel schliesst sie
## niemand zur Laufzeit. Sein Zustand ist deshalb das PAAR. Gemessen wird es
## am Ablauf selbst, nicht getippt: er erreicht elf davon, und der Zopf
## schwingt im Wurf bis +5, nicht nur bis +2 wie im Ruhelauf.
def zopf_paare():
    from tools import wurf_lauf as wl
    return sorted({(zopf, seit)
                   for _, _, _, zopf, _, _, _, seit, _ in wl.ablauf()})


def _leer():
    return Image.new("RGBA", (fp.FRAME, fp.FRAME), (0, 0, 0, 0))


def _verschoben(ebene, versatz):
    """Ein Teil an seine Stelle im 128er Feld, ohne Rand zu verlieren."""
    aus = _leer()
    ap, ep = aus.load(), ebene.load()
    for x, y in pp._punkte(ebene):
        nx, ny = versatz(x, y)
        if 0 <= nx < fp.FRAME and 0 <= ny < fp.FRAME:
            ap[nx, ny] = ep[x, y]
    return aus


def _zopf_mit_naht(ebenen, koepfe, zopfweite, kopf_seit):
    """Der geschorene Zopf, und die Naht zum Kopf gleich mit im Bild.

    Der Kopfversatz steckt NICHT im Bild -- er wird beim Zusammensetzen als
    Versatz des Sprites gesetzt, wie der Atem. Fuer die Naht braucht es ihn
    trotzdem: sie liegt je nach Versatz woanders.
    """
    aus = _verschoben(ebenen["ponytail"],
                      lambda x, y: (x + fp.swing(y, zopfweite,
                                                 fp.ZOPF_GUMMI_Y,
                                                 fp.ZOPF_SPITZE_Y), y))
    ap = aus.load()
    for atem in ATEM:
        roh = pp.roh_zusammensetzen(ebenen, koepfe, atem, zopfweite, 0,
                                    "open", kopf_seit)
        for (x, y), ton in pp.naht(roh).items():
            ## Zurueck in die Koordinaten des Zopfblatts: ohne Kopfversatz,
            ## ohne Atem.
            fx, fy = x - kopf_seit, y - atem
            if 0 <= fx < fp.FRAME and 0 <= fy < fp.FRAME:
                ap[fx, fy] = ton + (255,)
    return aus


## Das Fenster, in dem sich beim Blinzeln ueberhaupt etwas aendert -- aus
## figure_parts.AUGE_HALB und AUGE_ZU abgeleitet, nicht getippt.
def _augenfenster():
    felder = set(fp.AUGE_HALB) | set(fp.AUGE_ZU)
    xs = [p[0] for p in felder]
    ys = [p[1] for p in felder]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def _augenauflage(kopf):
    """Nur das Augenfenster dieses Kopfes, sonst durchsichtig."""
    x0, y0, x1, y1 = _augenfenster()
    aus = _leer()
    ap, kp = aus.load(), kopf.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if kp[x, y][3] > 128:
                ap[x, y] = kp[x, y]
    return aus


def zustaende(ebenen, koepfe):
    """Je Teil die Bilder aller seiner Zustaende, im 128er Feld.

    Der Kopf zerfaellt in zwei Teile: der Hals gehoert hinter den Kragen, der
    Rest davor. Sie bewegen sich gemeinsam, werden aber getrennt gezeichnet --
    deshalb sind es zwei Blaetter.

    Atem und Kopfversatz stecken NICHT in den Bildern: sie werden beim
    Zusammensetzen als Versatz des Sprites gesetzt. Nur die Scherungen von
    Zopf und Beinen sind gebacken, denn eine Scherung verschiebt jede Zeile
    anders und laesst sich nicht als Sprite-Position ausdruecken.
    """
    kopf_felder = pp._punkte(ebenen["head"])
    hals = [p for p in kopf_felder if p in fp.HALS]
    rest = [p for p in kopf_felder if p not in fp.HALS]

    def kopfteil(felder, quelle):
        aus = _leer()
        ap, qp = aus.load(), quelle.load()
        for x, y in felder:
            ap[x, y] = qp[x, y]
        return aus

    aus = {
        "zopf": [_zopf_mit_naht(ebenen, koepfe, w, seit)
                 for w, seit in zopf_paare()],
        ## Zwei Kopfbilder, obwohl der Atem als Versatz gesetzt wird: der
        ## Kopf ist im gesenkten Zustand nicht derselbe wie im gehobenen --
        ## eye_state() sitzt an festen Zeilen, und die Kinnlinie gehoert dem
        ## Kopf, nicht dem Rumpf.
        "kopf": [kopfteil(rest, koepfe["open"]) for _ in ATEM],
        "hals": [kopfteil(hals, koepfe["open"]) for _ in ATEM],
        "rumpf": [_verschoben(ebenen["torso"], lambda x, y: (x, y))],
        "beine": [_verschoben(ebenen["legs"],
                              lambda x, y, w=w: (x + fp.swing(y, w,
                                                              fp.BEIN_KNIE_Y,
                                                              fp.BEIN_ZEH_Y),
                                                 y))
                  for w in BEIN_WEITEN],
        ## Das Auge ist keine eigene Kopfhaltung, sondern eine Auflage weniger
        ## Pixel, die NACH dem Kopf gezeichnet wird. So kostet das Blinzeln
        ## nicht drei Kopfblaetter, sondern eines von vier mal drei Pixeln.
        "auge": [_augenauflage(koepfe[s]) for s in AUGEN],
    }
    aus["arm"] = [Image.open(os.path.join(TEILE, "sit3_arm_nah.png")).convert("RGBA")]
    aus["arm"] += [Image.open(os.path.join(SRC, "wurf_arm_%d.png" % i)).convert("RGBA")
                   for i in range(10)]
    aus["armfern"] = [Image.open(os.path.join(TEILE, "sit3_arm_fern.png")).convert("RGBA")]
    return aus


def rahmen(bilder):
    """Der kleinste Rahmen, der alle Zustaende eines Teils fasst."""
    kaesten = [b.getbbox() for b in bilder if b.getbbox() is not None]
    if not kaesten:
        raise ValueError("Teil ohne einen einzigen sichtbaren Pixel")
    x = min(k[0] for k in kaesten)
    y = min(k[1] for k in kaesten)
    return (x, y,
            max(k[2] for k in kaesten) - x,
            max(k[3] for k in kaesten) - y)
