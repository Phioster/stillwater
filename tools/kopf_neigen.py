"""Der gesenkte Kopf fuer die Does-Pose (volle Koedertasche).

Kopf, Hals und Zopf drehen sich als STARRE Stuecke -- keine Schwenkformel
wie beim Atmen, das ist eine einmalige, feste Neigung. Werte vom Nutzer
gemessen (Rutenpass-Sitzung 2026-09-13):

    Kopf  +18 Grad um (58,30), dazu 2 Pixel tiefer
    Zopf  -18 Grad um das Gummi (49,7) -- gegenlaeufig, haengt zurueck
          statt der Neigung zu folgen -- und vor dem Kopf statt dahinter

Rotiert wird das GESCHLOSSENE Auge direkt mit, nicht die offene Kopf-
Textur plus separate Augenauflage: die Auflage sitzt an festen,
UNGEDREHTEN Fensterkoordinaten und laege nach der Drehung daneben. Diese
Pose braucht deshalb kein Blinzeln und keine Augenauflage.

    python3 -m tools.kopf_neigen
"""
import math
import os
import sys

from PIL import Image

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
import rotsprite

W = os.path.dirname(S)
SRC = os.path.join(W, "assets", "source", "figure")
P = os.path.join(SRC, "parts")

from tools import figure_parts as fp
from tools import preview_parts as pp

KOPF_DREH = 18.0
KOPF_PIVOT = (58.0, 30.0)
KOPF_DY = 2
ZOPF_DREH = -18.0
ZOPF_PIVOT = (49.0, 7.0)
STUFEN, N = 4, 16


def _drehen_maskiert(bild, pixel, drehungen, versatz=(0, 0)):
    """Nur `pixel` aus `bild` rotieren, alles andere leer.

    `drehungen` ist eine Liste aus (Winkel-Grad, Drehpunkt) -- mehrere werden
    nacheinander angewandt, die erste zuerst (wie rotsprite.drehen_kette).
    """
    quelle = Image.new("RGBA", bild.size, (0, 0, 0, 0))
    qp, bp = quelle.load(), bild.load()
    for p in pixel:
        qp[p] = bp[p]
    gross = rotsprite.vergroessern(rotsprite._packen(
        __import__("numpy").array(quelle)), STUFEN)
    kette = [(math.radians(w), p) for w, p in drehungen]
    gedreht_gross = rotsprite.drehen_kette(gross, kette, N)
    gedreht = Image.fromarray(
        rotsprite._entpacken(rotsprite.verkleinern(gedreht_gross, N)), "RGBA")
    if versatz != (0, 0):
        verschoben = Image.new("RGBA", gedreht.size, (0, 0, 0, 0))
        verschoben.alpha_composite(gedreht, versatz)
        gedreht = verschoben
    return gedreht


def _dreh_punkt(p, winkel, pivot):
    r = math.radians(winkel)
    c, s = math.cos(r), math.sin(r)
    dx, dy = p[0] - pivot[0], p[1] - pivot[1]
    return (pivot[0] + dx * c - dy * s, pivot[1] + dx * s + dy * c)


def main():
    rumpf = Image.open(os.path.join(P, "sit3_rumpf.png")).convert("RGBA")
    ebenen = fp.split(rumpf)
    kopf_zu = fp.eye_state(ebenen["head"], "closed")

    kopf_felder = pp._punkte(ebenen["head"])
    hals_p = [p for p in kopf_felder if p in fp.HALS]
    rest_p = [p for p in kopf_felder if p not in fp.HALS]

    does_kopf = _drehen_maskiert(kopf_zu, rest_p, [(KOPF_DREH, KOPF_PIVOT)],
                                  (0, KOPF_DY))
    does_hals = _drehen_maskiert(kopf_zu, hals_p, [(KOPF_DREH, KOPF_PIVOT)],
                                  (0, KOPF_DY))

    ## Der Zopf haengt am Gummi, das Gummi haengt am Kopf: er muss die
    ## Kopfdrehung erst MITMACHEN, bevor er selbst gegenlaeufig zurueckfaellt
    ## -- sonst dreht er sich um einen Punkt, der laengst nicht mehr da ist,
    ## wo der Kopf inzwischen sitzt, und schwebt sichtbar daneben.
    zopf_p = pp._punkte(ebenen["ponytail"])
    zopf_kopf_mit = _drehen_maskiert(rumpf, zopf_p, [(KOPF_DREH, KOPF_PIVOT)],
                                      (0, KOPF_DY))
    gummi_neu = _dreh_punkt(ZOPF_PIVOT, KOPF_DREH, KOPF_PIVOT)
    gummi_neu = (gummi_neu[0], gummi_neu[1] + KOPF_DY)
    does_zopf = _drehen_maskiert(
        zopf_kopf_mit, pp._punkte(zopf_kopf_mit), [(ZOPF_DREH, gummi_neu)])

    does_kopf.save(os.path.join(SRC, "does_kopf.png"))
    does_hals.save(os.path.join(SRC, "does_hals.png"))
    does_zopf.save(os.path.join(SRC, "does_zopf.png"))

    # Kontrollbild: Kopf/Hals/Zopf auf dem Rumpf ohne Arme, damit sich Naht
    # und Gesicht pruefen lassen, ohne die Rutenpose zu brauchen.
    kontrolle = ebenen["torso"].copy()
    kontrolle.alpha_composite(does_hals)
    kontrolle.alpha_composite(does_zopf)
    kontrolle.alpha_composite(does_kopf)
    kontrolle.save(os.path.join(SRC, "does_kontrolle.png"))
    print("does_kopf/hals/zopf.png und does_kontrolle.png geschrieben")


if __name__ == "__main__":
    main()
