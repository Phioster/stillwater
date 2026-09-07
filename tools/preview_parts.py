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


def naht(bild):
    """Die eingeschlossenen Luecken eines Bildes und ihr Fuellton.

    Eingeschlossen heisst: alle vier Nachbarn sind belegt. Beim Schwenken
    bleibt zwischen Zopf und Kopf stellenweise eine Zeile leer -- links der
    Kopf, rechts der Zopf, dazwischen nichts. Auf dem dunklen Vorschaugrund
    faellt das nicht auf; im Spiel liegt dort der See, und es blitzt hell
    durch die Naht.

    Der Zopf allein reisst nie, gemessen ueber alle acht Weiten. Es ist also
    keine Frage der Zeichnung, sondern der Naht zwischen zwei Teilen -- und
    deshalb wird sie hier geschlossen und nicht in der Vorlage.

    Was zum Rand hin OFFEN ist, bleibt offen: die Luecke, die der schwingende
    Zopf am Hinterkopf freigibt, gehoert zum Bild.
    """
    px = bild.load()
    gefunden = {}
    for y in range(1, fp.FRAME - 1):
        for x in range(1, fp.FRAME - 1):
            if px[x, y][3] > 128:
                continue
            nachbarn = [px[x - 1, y], px[x + 1, y], px[x, y - 1], px[x, y + 1]]
            if not all(n[3] > 128 for n in nachbarn):
                continue
            toene = {}
            for n in nachbarn:
                toene[n[:3]] = toene.get(n[:3], 0) + 1
            gefunden[(x, y)] = max(toene.items(), key=lambda t: t[1])[0]
    return gefunden


def roh_zusammensetzen(ebenen, koepfe, atem, zopfweite, beinweite, auge,
                       kopf_seit=0):
    """Die Teile uebereinander, ohne jede Naht.

    Reihenfolge: Zopf, Beine, Hals, Rumpf, restlicher Kopf. Der Kopf liegt
    OBEN -- lag der Rumpf oben, frass sein Schulterumriss beim Absenken die
    Kinnzeile. Ausgenommen ist der Hals: der gehoert hinter den Kragen, sonst
    schiebt er sich beim Neigen darueber.

    Gemalt wird hier nichts. Was diese Funktion zeigt, stammt Pixel fuer
    Pixel aus einem Teil.
    """
    out = Image.new("RGBA", (fp.FRAME, fp.FRAME), (0, 0, 0, 0))
    op = out.load()
    zp = ebenen["ponytail"].load()
    bp = ebenen["legs"].load()
    rp = ebenen["torso"].load()
    kq = koepfe[auge].load()

    for x, y in _punkte(ebenen["ponytail"]):
        ## Der Zopf haengt am Kopf: geht der zur Seite, geht der ganze Zopf
        ## mit, und sein eigener Ausschlag kommt oben drauf.
        nx = x + kopf_seit + fp.swing(y, zopfweite, fp.ZOPF_GUMMI_Y,
                                      fp.ZOPF_SPITZE_Y)
        ny = y + atem
        if 0 <= nx < fp.FRAME and 0 <= ny < fp.FRAME:
            op[nx, ny] = zp[x, y]

    for x, y in _punkte(ebenen["legs"]):
        nx = x + fp.swing(y, beinweite, fp.BEIN_KNIE_Y, fp.BEIN_ZEH_Y)
        if 0 <= nx < fp.FRAME:
            op[nx, y] = bp[x, y]

    kopf = _punkte(ebenen["head"])

    def kopf_setzen(felder):
        for x, y in felder:
            nx, ny = x + kopf_seit, y + atem
            if 0 <= nx < fp.FRAME and 0 <= ny < fp.FRAME:
                op[nx, ny] = kq[x, y]

    kopf_setzen([p for p in kopf if p in fp.HALS])
    for x, y in _punkte(ebenen["torso"]):
        op[x, y] = rp[x, y]
    kopf_setzen([p for p in kopf if p not in fp.HALS])
    return out


def zusammensetzen(ebenen, koepfe, atem, zopfweite, beinweite, auge,
                   kopf_seit=0):
    """Die Teile uebereinander, Naht geschlossen.

    Frueher fuellte diese Funktion auch OFFENE Stellen: Haar dort, wo der
    Zopf wegschwang. Von den 17 gefuellten Stellen lagen 16 gar nicht auf
    Kopfpixeln -- der Hinterkopf wurde breiter gemalt, als er gezeichnet ist.
    Was der Zopf freigibt, ist Hintergrund und bleibt Luecke; dort faellt in
    der Seitenansicht Licht durch. Geschlossen wird nur, was ringsum
    zugedeckt ist (siehe naht()).
    """
    out = roh_zusammensetzen(ebenen, koepfe, atem, zopfweite, beinweite,
                             auge, kopf_seit)
    op = out.load()
    for feld, ton in naht(out).items():
        op[feld] = ton + (255,)
    return out


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
    ## Die Vorschau zeigt, was das Spiel baut -- also dieselbe Zeichnung, aus
    ## der tools/teile_bauen.py die Blaetter schneidet.
    ##
    ## Vorher stand hier pose_raw.png. Das ist eine ANDERE Zeichnung derselben
    ## Pose, kein anderer Farbauszug: von 3100 gemeinsam belegten Pixeln
    ## unterscheiden sich 1685, und keine ihrer Farben hat eine eindeutige
    ## Entsprechung -- #030201 trifft auf sieben verschiedene Toene. Dazu 402
    ## Pixel, die es nur dort gibt: die alte Rute mit der Rolle. Die Vorschau
    ## log damit ueber das Ergebnis.
    ##
    ## Kein fp.repair und keine Rutenebene mehr: repair arbeitet mit
    ## Koordinatenlisten, die an pose_raw abgemessen sind, und die Rute
    ## brauchte split nur, um ihre Pixel aus dem Kopf zu halten. In
    ## sit3_rumpf liegt keine.
    roh = Image.open(os.path.join(TEILE, "sit3_rumpf.png")).convert("RGBA")
    ebenen = fp.split(roh)
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
