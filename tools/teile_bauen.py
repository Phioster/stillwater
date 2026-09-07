#!/usr/bin/env python3
"""Baut die Blaetter je Teil und Kosmetikebene.

Die Figur wird im Spiel nicht als fertige Bilderreihe gezeigt, sondern aus
beweglichen Teilen zusammengesetzt -- nur so kann die Weite des Beinschwungs
je Schwung neu gezogen werden. Gebacken wird deshalb je TEIL, auf seinen
eigenen Rahmen zugeschnitten: der Zopf ist 21 mal 33 Pixel gross, ihn als
volles 128er Bild abzulegen verschenkt das Sechzehnfache.

    python3 -m tools.teile_bauen
"""
import json
import os

from PIL import Image

from tools import figure_parts as fp
from tools import preview_parts as pp
from tools.character_keys import load_table
from tools.character_layers import PARTS, split as farben_schneiden

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(WURZEL, "assets", "source", "figure")
TEILE = os.path.join(SRC, "parts")

## Die Zustaende je Teil, alle am Bild gemessen (siehe die Spec vom
## 2026-09-07). Der Atemzug hat zwar 32 Schritte, aber nur acht verschiedene
## Atem/Zopf-Zustaende -- beide haengen an derselben Phase.
ATEM = (0, 1)
BEIN_WEITEN = tuple(range(-6, 7))
AUGEN = ("open", "half", "closed")


## Der Zopf haengt nicht nur an seiner eigenen Weite, sondern auch an Atem
## und Kopfversatz: die Naht zwischen ihm und dem Kopf liegt je nach allen
## dreien woanders, und sie muss ins Blatt gebacken werden -- im Spiel
## schliesst sie niemand zur Laufzeit. Sein Zustand ist deshalb das TRIPEL.
##
## Atem und Versatz werden trotzdem als Sprite-Versatz gesetzt, nicht ins
## Bild gerechnet; sie stehen hier nur, weil die Naht sie braucht. Gemessen
## wird am Ablauf selbst, nicht getippt: er erreicht vierzehn Tripel, und der
## Zopf schwingt im Wurf bis +5, nicht nur bis +2 wie im Ruhelauf.
def zopf_zustaende():
    from tools import wurf_lauf as wl
    return sorted({(atem, zopf, seit)
                   for _, _, atem, zopf, _, _, _, seit, _ in wl.ablauf()})


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


def _zopf_mit_naht(ebenen, koepfe, atem, zopfweite, kopf_seit):
    """Der geschorene Zopf, und die Naht zum Kopf gleich mit im Bild.

    Atem und Kopfversatz stecken NICHT im Bild -- sie werden beim
    Zusammensetzen als Versatz des Sprites gesetzt. Fuer die Naht braucht es
    sie trotzdem: sie liegt je nach beidem woanders. Deshalb wird sie hier
    zurueckgerechnet, in die Koordinaten des Zopfblatts.
    """
    aus = _verschoben(ebenen["ponytail"],
                      lambda x, y: (x + fp.swing(y, zopfweite,
                                                 fp.ZOPF_GUMMI_Y,
                                                 fp.ZOPF_SPITZE_Y), y))
    ap = aus.load()
    roh = pp.roh_zusammensetzen(ebenen, koepfe, atem, zopfweite, 0,
                                "open", kopf_seit)
    for (x, y), ton in pp.naht(roh).items():
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
        "zopf": [_zopf_mit_naht(ebenen, koepfe, atem, w, seit)
                 for atem, w, seit in zopf_zustaende()],
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

OUT = os.path.join(WURZEL, "assets", "art")

## Die Reihenfolge aus preview_parts.zusammensetzen, die Arme obenauf. Der
## Kopf liegt ueber dem Rumpf -- lag es umgekehrt, frass sein Schulterumriss
## beim Absenken die Kinnzeile. Der Hals gehoert dahinter, sonst schiebt er
## sich beim Neigen ueber den Kragen.
ZEICHENFOLGE = ("zopf", "beine", "hals", "rumpf", "kopf", "auge",
                "armfern", "arm")

## Diese Teile haengen am Kopf und gehen mit seinem Versatz mit.
AM_KOPF = ("zopf", "kopf", "hals", "auge")


def _index(name, zopf_zustand, beinweite, auge, arm):
    """Welcher Zustand eines Teils bei welchem Bewegungswert gilt."""
    if name == "zopf":
        return zopf_zustaende().index(zopf_zustand)
    if name in ("kopf", "hals"):
        return 0        # der Atem ist Versatz, nicht Bild
    if name == "auge":
        return AUGEN.index(auge)
    if name == "beine":
        return BEIN_WEITEN.index(beinweite)
    if name == "arm":
        return arm
    return 0


def blatt(bilder, kasten, tabelle, ebene):
    """Ein Blatt: alle Zustaende eines Teils, nur die Pixel EINER Ebene.

    Geschnitten wird das GANZE 128er Feld, zugeschnitten erst danach. Die
    Baender der Farbtabelle gelten je Bildzeile -- in einem Ausschnitt haette
    Zeile 0 eine andere Bedeutung, und die Beine bekaemen Haar und Pullover.
    """
    x, y, w, h = kasten
    aus = Image.new("RGBA", (w * len(bilder), h), (0, 0, 0, 0))
    for i, bild in enumerate(bilder):
        geschnitten = farben_schneiden(bild, tabelle)[ebene]
        aus.alpha_composite(geschnitten.crop((x, y, x + w, y + h)), (i * w, 0))
    return aus


def aufbauen(blaetter, kaesten, zopf_zustand, beinweite, auge="open",
             arm=None):
    """Die Blaetter wieder zu einem 128er Bild -- die Gegenprobe zur Vorschau.

    Atem und Kopfversatz stecken nicht in den Bildern, sondern kommen hier als
    Versatz obendrauf. Im Spiel tut das die Szene.

    arm=None laesst die Arme weg. Die Vorschau kennt sie nicht: ihr Rumpf
    kommt aus sit3_rumpf, und der ist ohne Arme gezeichnet.
    """
    atem, _, kopf_seit = zopf_zustand
    aus = _leer()
    for name in ZEICHENFOLGE:
        if arm is None and name in ("arm", "armfern"):
            continue
        x, y, w, h = kaesten[name]
        i = _index(name, zopf_zustand, beinweite, auge, arm or 0)
        versatz = (x + kopf_seit, y + atem) if name in AM_KOPF else (x, y)
        for ebene in PARTS:
            teil = blaetter[(name, ebene)].crop((i * w, 0, (i + 1) * w, h))
            aus.alpha_composite(teil, versatz)
    return aus


def main():
    ebenen = fp.split(Image.open(os.path.join(TEILE, "sit3_rumpf.png"))
                      .convert("RGBA"))
    koepfe = {s: fp.eye_state(ebenen["head"], s) for s in AUGEN}
    tabelle = load_table(os.path.join(SRC, "key_palette.json"))
    zust = zustaende(ebenen, koepfe)
    geschrieben = 0
    verzeichnis = {}
    for name in ZEICHENFOLGE:
        bilder = zust[name]
        kasten = rahmen(bilder)
        ebenen_hier = []
        for ebene in PARTS:
            bild = blatt(bilder, kasten, tabelle, ebene)
            if bild.getbbox() is None:
                continue        # diese Ebene kommt in diesem Teil nicht vor
            bild.save(os.path.join(OUT, "teil_%s_%s.png" % (name, ebene)))
            ebenen_hier.append(ebene)
            geschrieben += 1
        verzeichnis[name] = {
            "x": kasten[0], "y": kasten[1], "w": kasten[2], "h": kasten[3],
            "zustaende": len(bilder), "ebenen": ebenen_hier,
        }
        print("%-8s %2dx%-3d bei %2d,%-3d  %2d Zustaende, Ebenen: %s"
              % (name, kasten[2], kasten[3], kasten[0], kasten[1], len(bilder),
                 " ".join(ebenen_hier)))
    ## Jedes Teil hat seinen eigenen Rahmen -- das ist der ganze Sinn der
    ## Uebung, und es heisst, dass die Masse niemand raten kann. Sie stehen
    ## deshalb hier neben den Blaettern: der Sprite-Test prueft gegen sie,
    ## und Stufe 3 setzt die Teile mit x,y wieder an ihren Platz im Feld.
    with open(os.path.join(OUT, "teile.json"), "w") as f:
        json.dump({"rahmen": fp.FRAME, "zeichenfolge": list(ZEICHENFOLGE),
                   "teile": verzeichnis}, f, indent="\t", sort_keys=True)
        f.write("\n")
    print("%d Blaetter und teile.json geschrieben" % geschrieben)


if __name__ == "__main__":
    main()
