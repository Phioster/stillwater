#!/usr/bin/env python3
"""Friert die Zuordnung Farbe -> Koerperteil fuer diese Figur ein.

Gemessen an den Bildern, aus denen die Figur im Spiel WIRKLICH besteht:
Rumpf und beide Arme liegen seit dem Umbau getrennt vor, dazu der
geschwenkte Arm der Wurfreihe. Die alten Ruhe- und Wurfbilder aus PixelLab
(sit3_south, idle_*, cast_*) stehen NICHT mehr drin -- sie sind als Vorlage
verworfen, und ihre 172 Farben, die in keinem heutigen Bild vorkommen,
machten die Tabelle nur unuebersichtlich. Umgekehrt fehlten 43 Farben, die
heute vorkommen; fuer die fiel das Trennen auf die Rechnung zurueck, also
genau auf das Raten, das die Tabelle abschaffen soll.

Die Rute ist nicht dabei. Sie ist ein eigenes Sprite und wird nie
umgefaerbt; ihre Korktoene stuenden sonst als HAUT in der Tabelle. Deshalb
taugen pose_raw und wurf_rute_* hier nicht als Quelle: in beiden ist die
Rute mitten in die Figur gezeichnet.

    python3 -m tools.freeze_palette
"""
import glob
import json
import os

from PIL import Image

from tools.character_keys import assign, load_table
from tools.character_layers import PARTS, split

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "figure")
TEILE = os.path.join(SRC, "parts")

## Die Figur und ihre Bewegungen bei PixelLab -- damit nachvollziehbar bleibt,
## woraus diese Tabelle entstanden ist.
QUELLE = {
    "vorlage_stehend": "2ccebb26-7371-4660-96bb-cfd52ea6af98",
    "zustand_sitzend": "b0fa3377-766a-4c2b-ba6e-6ca41842787b",
    "richtung": "south",
    "atemzug": "79e47544-dcf1-4f59-8d5a-f4b7c79d4dc9",
    "wurf": "5913c433-e9dc-445c-910b-be6baeec3ba5",
}

## --- Von Hand gesichtet ---------------------------------------------------
##
## Die Rechnung (character_keys.assign) ordnet nach Farbton. Das traegt, so
## lange eine Farbe nur an einer Stelle vorkommt. Beim Nachziehen des Rumpfes
## sind die Toene aber zusammengerueckt: siebzehn der zweiundfuenfzig Farben
## liegen jetzt an zwei Stellen oder zeigen in die falsche Familie.
##
## Gefunden hat sie ein Suchlauf (tools/character_ambiguity.py, dazu die
## Nachbarschaftsmehrheit je Haufen), GESICHTET sind sie von Hand am Bild.
## Die Grenzen liegen in echten Luecken: zwischen zwei Vorkommen derselben
## Farbe steht keine einzige belegte Zeile.
##
## Die Nachbarschaft allein taugt als Richter NICHT -- sie erklaert das
## Gesicht zu Haar, weil Pony und Zopf es umschliessen. Wo der Farbton
## eindeutig ist (Pfirsich ist Haut, Magenta ist Haar), bleibt er stehen.
GESICHTET = {
    ## Das Auge. Es gehoert zu keinem Kleidungsstueck: wer die Haut moosgruen
    ## faerbt, will kein moosgruenes Auge, und der Glanzpunkt darf nicht die
    ## Farbe des Pullovers annehmen. Also in die Grundebene, die nie
    ## umgefaerbt wird -- wie der Umriss. Iris 64-65/21, hinterer Winkel
    ## 66/21, Glanz 63/22.
    (0x32, 0x34, 0x5e): [(28, "base"), (76, "shirt"), (128, "pants")],
    (0x3e, 0x48, 0x71): [(28, "base"), (128, "shirt")],
    (0x89, 0x31, 0x54): [(28, "base"), (128, "skin")],

    ## Der Kragen. Er ist kein Teil des Pullovers, sondern das Hemd darunter,
    ## und soll weiss bleiben, egal welche Farbe der Pullover bekommt -- also
    ## in die Grundebene, die nie umgefaerbt wird. Sie liegt in der Szene
    ## ueber dem Pullover (angler.gd, LAYERS), der Kragen sitzt also vorn.
    ##
    ## Drei seiner Toene kommen in der ganzen Figur nur hier vor, deshalb
    ## reicht der Name ohne Band. #e7f6fe traegt zusaetzlich den Augenglanz --
    ## der gehoert ohnehin in dieselbe Ebene.
    (0xa7, 0xcc, 0xe8): "base",
    (0x8c, 0xb2, 0xd8): "base",
    (0xe7, 0xf6, 0xfe): "base",

    ## Dunkles Blau: oben ein paar Straehnen im Zopf, in der Mitte der
    ## Pullover, unter dem Saum sein Schatten, ganz unten ein Pixel Stiefel.
    (0x22, 0x1d, 0x4e): [(20, "hair"), (76, "shirt"), (100, "pants"),
                         (128, "boots")],
    (0x44, 0x4f, 0x7a): [(20, "hair"), (80, "shirt"), (128, "pants")],
    ## Der Kragenschatten aus tools/figur_nachziehen.py -- zwei Pixel davon
    ## liegen im Zopf, der Rest gehoert zum Kragen.
    (0x86, 0x99, 0xb9): [(20, "hair"), (128, "base")],

    ## Rotviolett: im Kopf Haar, an Knie und Wade der Schatten auf der Haut.
    ## Die Rechnung gibt beides dem Haar -- damit wanderte beim Umfaerben der
    ## Haare ein magentafarbener Fleck ueber das Bein.
    (0x73, 0x20, 0x6b): [(56, "hair"), (128, "skin")],
    (0x63, 0x16, 0x5d): [(58, "hair"), (128, "skin")],
    (0x4f, 0x0a, 0x33): [(60, "hair"), (128, "skin")],
    (0x61, 0x24, 0x34): "skin",          # drei Pixel Schatten an der Hand

    ## Tuerkis: #2f95a5 braucht keinen Eintrag mehr, seit der Kragen kein
    ## Tuerkis mehr traegt (tools/figur_nachziehen.py::KRAGEN_SPITZE). Es
    ## liegt nur noch im Stiefel, und dorthin zeigt schon die Rechnung.
    ## #284e59 ist auf ein einziges Pixel geschrumpft: den Schatten im
    ## Pullover bei 68,64. Er steckt unter dem nahen Arm -- am
    ## zusammengesetzten Koerper war er nicht zu sehen, geschnitten wird
    ## aber jedes Bild einzeln, also zaehlt er mit.
    (0x28, 0x4e, 0x59): "shirt",
    ## Die Falten im Rock sind so dunkel wie der Stiefelschaft.
    (0x12, 0x5d, 0x5d): [(90, "pants"), (128, "boots")],

    ## Olivgrau am Rocksaum. Der Farbton liegt zwischen Haut und Rock; die
    ## Nachbarschaft ist zu 50 von 76 Teilen Rock.
    (0x5e, 0x57, 0x4a): "pants",
    ## Fast schwarz: Helligkeit 0.1216 gegen die Umrissgrenze 0.12, um ein
    ## Tausendstel daran vorbei. Der Ton liegt in jedem Armbild zweimal --
    ## einmal auf der Hand, einmal am Aermel -- und ist ueber Farbe wie Zeile
    ## nicht zu trennen. Als Umriss bleibt er in beiden Faellen dunkel, und
    ## genau das soll er.
    (0x2c, 0x19, 0x12): "base",
}


def bilder():
    """Die Bilder, aus denen die Figur im Spiel besteht."""
    pfade = [os.path.join(TEILE, n) for n in
             ("sit3_rumpf.png", "sit3_arm_fern.png", "sit3_arm_nah.png")]
    pfade += sorted(glob.glob(os.path.join(SRC, "wurf_arm_*.png")))
    return [(os.path.relpath(p, SRC), Image.open(p).convert("RGBA"))
            for p in pfade]


def main():
    quellen = bilder()
    tabelle = {}
    je_bild = {}
    for name, img in quellen:
        px = img.load()
        w, h = img.size
        neu = 0
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a <= 128:
                    continue
                if (r, g, b) not in tabelle:
                    tabelle[(r, g, b)] = assign((r, g, b))
                    neu += 1
        je_bild[name] = neu
    print("%d Bilder, %d Farben insgesamt" % (len(quellen), len(tabelle)))
    for name, neu in je_bild.items():
        if neu:
            print("  %-22s bringt %2d neue Farben mit" % (name, neu))

    for farbe, eintrag in GESICHTET.items():
        if farbe not in tabelle:
            raise SystemExit("gesichteter Eintrag #%02x%02x%02x kommt in keinem "
                             "Bild vor" % farbe)
        tabelle[farbe] = eintrag
    print("%d Eintraege von Hand gesichtet" % len(GESICHTET))

    ausgabe = {
        "quelle": QUELLE,
        "farben": {"%02x%02x%02x" % f: t for f, t in sorted(tabelle.items())},
    }
    ziel = os.path.join(SRC, "key_palette.json")
    with open(ziel, "w", encoding="utf-8") as fh:
        json.dump(ausgabe, fh, indent=1, sort_keys=True)
    print("geschrieben: %s" % ziel)

    ## Gegenprobe: die Ebenen muessen disjunkt und vollstaendig sein, sonst
    ## taugt die Tabelle nichts.
    geladen = load_table(ziel)
    for name, img in quellen:
        ebenen = split(img, geladen)
        sichtbar = sum(1 for p in img.get_flattened_data() if p[3] > 128)
        summe = sum(sum(1 for q in ebenen[t].get_flattened_data() if q[3] > 0)
                    for t in PARTS)
        if summe != sichtbar:
            raise SystemExit("%s: %d Pixel in Ebenen, %d in der Figur"
                             % (name, summe, sichtbar))
    print("Gegenprobe: alle %d Bilder zerfallen restlos und "
          "ueberschneidungsfrei" % len(quellen))


if __name__ == "__main__":
    main()
