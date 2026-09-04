"""Die Anglerin in bewegliche Teile zerlegen.

Der Bildgenerator taugt nicht fuer feine Bewegung: ueber neun erzeugte
Ruhebilder wechselten 22 verschiedene Hauttoene im Gesicht, die Gesichtsflaeche
schwankte zwischen 69 und 112 Pixeln, und in fuenf der neun Bilder war das Auge
zu, ohne dass es jemand verlangt haette. Statt daraus eine Animation zu
retten, wird EINE gepruefte Haltung in Ebenen zerlegt und rechnerisch bewegt.

Alle Zahlen hier sind am Bild abgenommen und von Hand bestaetigt, keine ist
geschaetzt. Die Grenzen liegen als Konstanten offen, damit eine Korrektur eine
Zahl ist und keine neue Suchheuristik.

Ebenen und ihre Bewegung:
    Zopf     schwingt am Haargummi -- oben null, an der Spitze voller Ausschlag
    Kopf     sinkt beim Atmen um ein Pixel, traegt die drei Augenstellungen
    Beine    baumeln am Knie, Ausschlag im Spiel je Schwung neu gezogen
    Rumpf    steht, traegt die Rute
"""
import os

from PIL import Image

from tools.character_keys import assign

FRAME = 128

## --- Ausbesserungen an der Vorlage ---------------------------------------
##
## Erzeugungsreste: einzelne Pixel in einer fremden Farbfamilie, die beim
## Trennen in der falschen Ebene landen und beim Umfaerben als Fleck auffallen.
## Ersetzt wird nie durch eine gemischte Farbe, sondern durch die haeufigste
## Farbe der Nachbarschaft aus deren vorherrschender Familie -- so bleibt die
## Palette geschlossen, und daran haengt die ganze Ebenentrennung.

SPRENKEL = [
    (43, 5), (41, 6), (40, 7), (43, 7), (42, 8), (42, 12),
    (71, 12), (37, 28), (68, 22),
] + [(49, y) for y in range(25, 32)]

## Stellen im Stiefel, die haut- oder haarfarben sind. Die Ersatzfarbe kommt
## wie sonst aus der Nachbarschaft, aber nur aus dieser Familie.
## 79,100 und 79,101 lagen zwischen 78 und 80 und fielen durch jede Pruefung,
## solange deren Nachbarn selbst falsch waren -- erst danach zeigen sie 88
## Prozent Stiefelnachbarschaft.
FAMILIE = {
    (86, 98): "boots", (87, 98): "boots", (87, 99): "boots",
    (78, 100): "boots", (79, 100): "boots", (80, 100): "boots",
    (78, 101): "boots", (79, 101): "boots", (80, 101): "boots",
    (70, 102): "boots", (80, 102): "boots",
}

## Ausdruecklich gesetzte Farben statt Nachbarschaftsmehrheit.
FEST = {
    (69, 26): (0x03, 0x02, 0x01),    # Gesichtsumriss, nicht weiss
    (66, 20): (0x03, 0x02, 0x01),    # setzt die Umrisslinie 64,20-65,20 fort
    (95, 113): (0x03, 0x02, 0x01),   # Schuhspitze: schliesst den Umriss 93,112-95,114
}

## Ausdruecklich BEHALTEN, obwohl ein Suchlauf sie meldet: 47-49/7-10 ist das
## Haargummi, 65-67/21-23 das Auge, 63,22 sein Glanzpunkt, 61,36 der hellste
## Kragenton -- und 66,21 der hintere Augenwinkel. Ohne ihn ist das Auge ein
## Schlitz statt einer Form.

## --- Ebenen, deren Farbe in die falsche Richtung zeigt ---------------------
##
## Schattierungspixel: farblich tuerkis oder rotbraun, tatsaechlich aber Rock,
## Haut oder Stiefel. Umfaerben wuerde das Bild veraendern, deshalb wird statt
## der Farbe die Ebene festgelegt. Jede Zuordnung ist die Mehrheit der
## Nachbarschaft, gemessen, nicht geschaetzt.
EBENEN_AUSNAHMEN = {
    (58, 71): "pants", (58, 72): "pants", (58, 73): "pants",   # Falten im Rock
    (74, 74): "pants", (81, 75): "pants", (72, 77): "pants",
    (73, 78): "pants",
    (72, 71): "skin",                                          # Schatten auf der Hand
    (80, 82): "skin",                                          # Schatten am Bein
    (82, 87): "skin", (88, 87): "skin",                        # Kante am hinteren Knie
    (82, 88): "skin", (88, 88): "skin",
    (81, 89): "skin", (82, 89): "skin",                        # Linie zwischen den Waden
    (81, 90): "skin", (82, 90): "skin",
    (81, 91): "skin", (82, 91): "skin",
    (81, 92): "skin", (82, 92): "skin",
    (81, 93): "skin", (80, 95): "skin",
}

## --- Der Zopf -------------------------------------------------------------
##
## Zopf und Hinterkopf beruehren sich entlang einer gezeichneten Kante, ein
## Pixel breit. Ein zusammenhaengender Suchlauf lief dort aus und nahm den
## halben Hinterkopf mit; eine Grenze JE ZEILE kann das nicht. Der Wert ist
## die erste Spalte, die NICHT mehr zum Zopf gehoert.
ZOPF_GRENZE = {
    5: 51, 6: 52, 7: 51, 8: 50, 9: 50, 10: 49, 11: 49, 12: 49,
    13: 48, 14: 48, 15: 48, 16: 47, 17: 47, 18: 47, 19: 47, 20: 47,
    21: 48, 22: 48, 23: 49, 24: 50, 25: 50, 26: 51, 27: 52, 28: 52,
    29: 52, 30: 52, 31: 52, 32: 51, 33: 50, 34: 49, 35: 48, 36: 47,
    37: 46,
}
ZOPF_GUMMI_Y = 7        # hier haengt er fest, hier ist der Ausschlag null
ZOPF_SPITZE_Y = 37      # und hier haengt er frei

## --- Der Kopf -------------------------------------------------------------
## Die Linie unter dem Kinn ist schwarz und faellt damit in die Umriss-
## Familie -- die Farbregel gibt sie dem Rumpf. Sie gehoert aber zum Kopf und
## muss beim Atmen mitsinken, sonst haengen schwarze Pixel am Koerper.
KINNLINIE = {(62, 31), (63, 31), (64, 31), (65, 31), (66, 31)}

## Pixel, die nur der Rumpf bekommt, obwohl oben der Kopf liegt: die Spitze
## der Haarstraehne deckt 60,32 zu und wandert mit dem Kopf weg -- ohne
## Unterlage klafft dort im Wurf ein Loch mitten im Kragen.
RUMPF_UNTERLAGE = {(60, 32): (0x86, 0x99, 0xb9)}

## Der Hals: die Hautzeilen unter dem Kinn, links von der Haarstraehne. Sie
## gehoeren zum Kopf und wandern mit ihm, werden beim Zusammensetzen aber VOR
## dem Rumpf gezeichnet -- sonst schiebt sich beim Neigen der Hals ueber den
## Kragen statt hinter ihn. Alles andere am Kopf bleibt oben, sonst frisst der
## Schulterumriss beim Atmen wieder die Kinnlinie.
HALS = {(55, 30), (56, 30), (57, 30), (57, 31), (58, 31), (59, 31)}
KOPF_SCHNITT = 32       # letzte Zeile, die noch zum Kopf gehoert
KOPF_SCHULTER = 30      # erste Zeile, in der ueberhaupt Oberteil vorkommt
KOPF_HALSBAND = 31      # ab hier liegen Kragen und Schulterumriss neben dem Hals
NUR_KOPF = ("skin", "hair")

## --- Die Beine ------------------------------------------------------------
##
## Der Schnitt ist keine gerade Zeile: das hintere Bein sitzt hoeher, sein
## Knieknick liegt zwei Zeilen ueber dem vorderen.
BEIN_SCHNITT = 89
BEIN_STUFE_AB_X = 82
BEIN_SCHNITT_RECHTS = 87
BEIN_KNIE_Y = 89        # Drehpunkt beim Baumeln
BEIN_ZEH_Y = 122
## Getrennt schwenken koennen die beiden Beine nicht: zwischen y=98 und y=110
## liegt kein einziger Pixel Kante dazwischen, die Stiefelschaefte sind als
## eine Masse gezeichnet. Dafuer muesste der hintere Schaft erst erzeugt werden.

## --- Das Blinzeln ---------------------------------------------------------
##
## Von Hand gezeichnet. Beim Schliessen wandert die Wimper von y=20 nach unten
## und trifft bei y=22 auf das Unterlid; was sie freigibt, wird Lidhaut. Alle
## Toene stehen schon in der Palette.
_HAUT = (0xe8, 0x84, 0x74)          # Wangenton auf Augenhoehe, wie 66,21 und 67,21
_HAUT_SCHATTEN = (0xd8, 0x7a, 0x6a)  # etwas dunkler, wie 67,20 am Haaransatz
_WIMPER = (0x03, 0x02, 0x01)

AUGE_HALB = {
    (64, 20): _HAUT, (65, 20): _HAUT, (66, 20): _HAUT_SCHATTEN,
    (63, 21): _WIMPER, (64, 21): _WIMPER, (65, 21): _WIMPER, (66, 21): _WIMPER,
}
AUGE_ZU = {
    (64, 20): _HAUT, (65, 20): _HAUT, (66, 20): _HAUT_SCHATTEN,
    (63, 21): _HAUT, (64, 21): _HAUT, (65, 21): _HAUT, (66, 21): _HAUT,
    (63, 22): _WIMPER, (64, 22): _WIMPER, (65, 22): _WIMPER,
}


def _sichtbar(px):
    return {(x, y) for y in range(FRAME) for x in range(FRAME)
            if px[x, y][3] > 128}


def repair(img):
    """Die Erzeugungsreste ausbessern. Bringt keine neue Farbe ins Bild."""
    px = img.load()
    out = img.copy()
    qx = out.load()
    verboten = set(SPRENKEL) | set(FEST) | set(FAMILIE)

    for x, y in SPRENKEL + list(FEST) + list(FAMILIE):
        if (x, y) in FEST:
            qx[x, y] = FEST[(x, y)] + (255,)
            continue
        nachbarn, familien = {}, {}
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if (dx, dy) == (0, 0) or p in verboten or px[p][3] <= 128:
                    continue
                farbe = px[p][:3]
                nachbarn[farbe] = nachbarn.get(farbe, 0) + 1
                fam = assign(farbe)
                familien[fam] = familien.get(fam, 0) + 1
        if not nachbarn:
            continue
        haupt = FAMILIE.get((x, y)) or max(familien.items(),
                                           key=lambda t: t[1])[0]
        passend = [(n, c) for c, n in nachbarn.items() if assign(c) == haupt]
        if not passend:
            raise ValueError("%d,%d: keine %s-Farbe in der Nachbarschaft"
                             % (x, y, haupt))
        qx[x, y] = max(passend)[1] + (255,)
    return out


def layer_of(x, y):
    """Zu welcher Ebene ein Pixel gehoert -- ohne die Rute, die eigen ist."""
    if y >= (BEIN_SCHNITT_RECHTS if x >= BEIN_STUFE_AB_X else BEIN_SCHNITT):
        return "legs"
    if y in ZOPF_GRENZE and x < ZOPF_GRENZE[y]:
        return "ponytail"
    return None     # Kopf oder Rumpf, das entscheidet erst die Farbe


def _kopf_pixel(px, sichtbar, x, y):
    familie = assign(px[x, y][:3])
    if y >= KOPF_HALSBAND:
        ## Kragen und Schulterumriss liegen hier neben dem Hals -- nur was
        ## Kopf sein KANN, bleibt.
        return familie in NUR_KOPF
    if y == KOPF_SCHULTER and familie == "base":
        ## Der Umriss traegt keine eigene Zugehoerigkeit: derselbe Schwarzton
        ## umrandet Kinn und Schulter. Entschieden wird nach der Nachbarschaft.
        kopfhaft = rumpfhaft = 0
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if (dx, dy) == (0, 0) or p not in sichtbar:
                    continue
                f = assign(px[p][:3])
                if f in NUR_KOPF:
                    kopfhaft += 1
                elif f in ("shirt", "boots"):
                    rumpfhaft += 1
        return kopfhaft > rumpfhaft
    if y == KOPF_SCHULTER:
        return familie != "shirt"
    ## Darueber gibt es keinen Rumpf. Wichtig: die Iris faellt in die
    ## Pullover-Familie, eine Familienregel verloere hier die Wimper.
    return True


def split(img, rod=None):
    """Die geprueften Ebenen als Bilder.

    rod: die Rutenebene. Ihre Pixel bleiben im Rumpf, wandern also weder mit
    dem Kopf noch mit den Beinen -- im Spiel ist die Rute ein eigenes Sprite.
    """
    px = img.load()
    sichtbar = _sichtbar(px)
    rutenfeld = _sichtbar(rod.load()) if rod is not None else set()

    ebenen = {"ponytail": set(), "head": set(), "legs": set(), "torso": set()}
    for x, y in sichtbar:
        wohin = layer_of(x, y)
        if (x, y) in KINNLINIE and (x, y) not in rutenfeld:
            wohin = "head"
        elif wohin is None:
            wohin = ("head" if y <= KOPF_SCHNITT and (x, y) not in rutenfeld
                     and _kopf_pixel(px, sichtbar, x, y) else "torso")
        ebenen[wohin].add((x, y))
    ebenen["torso"] |= set(RUMPF_UNTERLAGE)

    bilder = {}
    for name, menge in ebenen.items():
        ebene = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        ep = ebene.load()
        for p in menge:
            ep[p] = px[p]
        if name == "torso":
            for p, farbe in RUMPF_UNTERLAGE.items():
                ep[p] = farbe + (255,)
        bilder[name] = ebene
    return bilder


def eye_state(head, state):
    """Die Kopfebene mit offenem, halb geschlossenem oder zugefallenem Auge."""
    muster = {"open": {}, "half": AUGE_HALB, "closed": AUGE_ZU}[state]
    out = head.copy()
    px = out.load()
    for p, farbe in muster.items():
        if px[p][3] > 128:
            px[p] = farbe + (255,)
    return out


def swing(y, amount, pivot, tip):
    """Ausschlag an dieser Zeile: null am Drehpunkt, voll an der Spitze.

    Ein starrer Seitwaertsschub saehe aus, als waere das Teil verrutscht --
    Zopf wie Bein haengen fest und drehen.
    """
    if y <= pivot:
        return 0
    return int(round(amount * min(1.0, (y - pivot) / float(tip - pivot))))
