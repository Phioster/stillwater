"""Auge zu.

Das Auge ist keine Haut und liegt ringsum von Haut eingeschlossen -- nicht
"dunkel": bei dieser Figur ist es dunkelblau und faellt damit in die
Pullover-Familie, nicht in den Umriss. Seit die Haut eine bekannte
Schluesselfarbe hat, ist "keine Haut, ringsum Haut" ohne Raten zu pruefen:
ein Pixel gehoert zum Auge, wenn in allen vier Richtungen Haut kommt, bevor
Rand oder Transparenz erreicht wird.
"""
from collections import Counter

from tools.character_layers import split

_RICHTUNGEN = ((0, -1), (0, 1), (-1, 0), (1, 0))

def _erreicht_haut(haut_px, sichtbar_px, x, y, dx, dy, w, h):
    """Laeuft von (x, y) in eine Richtung, bis Haut, Rand oder Transparenz kommt."""
    x, y = x + dx, y + dy
    while 0 <= x < w and 0 <= y < h and sichtbar_px[x, y][3] > 128:
        if haut_px[x, y][3] > 0:
            return True
        x, y = x + dx, y + dy
    return False

def _ist_insel(haut_px, sichtbar_px, x, y, w, h):
    ## Der Umriss hat immer mindestens eine Richtung, in der es sofort nach
    ## draussen geht -- das Auge nicht, egal wie die Insel geformt ist.
    return all(_erreicht_haut(haut_px, sichtbar_px, x, y, dx, dy, w, h)
               for dx, dy in _RICHTUNGEN)

def _komponenten(punkte):
    """Zusammenhaengende Teilmengen von punkte (8er-Nachbarschaft)."""
    menge = set(punkte)
    besucht = set()
    bloecke = []
    for start in punkte:
        if start in besucht:
            continue
        stapel = [start]
        besucht.add(start)
        block = []
        while stapel:
            x, y = stapel.pop()
            block.append((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if n in menge and n not in besucht:
                        besucht.add(n)
                        stapel.append(n)
        bloecke.append(block)
    return bloecke

def _helligkeit(farbe):
    r, g, b = farbe
    return 0.299 * r + 0.587 * g + 0.114 * b

def close_eye(img, table):
    haut = split(img, table)["skin"].load()
    sichtbar = img.load()
    w, h = img.size
    ## Kandidaten: sichtbar, aber keine Haut -- die Farbe des Augen-Tons
    ## selbst spielt keine Rolle, nur seine Lage zaehlt.
    kandidaten = [(x, y) for y in range(h) for x in range(w)
                  if sichtbar[x, y][3] > 128 and haut[x, y][3] == 0
                  and _ist_insel(haut, sichtbar, x, y, w, h)]
    if not kandidaten:
        return img.copy()
    ## Die Figur hat ein Auge -- also nur die groesste zusammenhaengende
    ## Insel nehmen. Falsche Einzeltreffer anderswo im Bild (Naht, Saum)
    ## verlieren damit von selbst, ohne dass eine Bildzeile vorgegeben wird.
    insel = max(_komponenten(kandidaten), key=len)

    ## Der haeufigste Hautton ringsum, nicht ein gewaehlter: das Gesicht ist
    ## schattiert, und ein fester Ton saehe wie ein Fleck aus.
    toene = Counter()
    for x, y in insel:
        for dy in (-2, -1, 1, 2):
            if 0 <= y + dy < h and haut[x, y + dy][3] > 0:
                toene[haut[x, y + dy][:3]] += 1
    ton = toene.most_common(1)[0][0]

    out = img.copy()
    px = out.load()
    for x, y in insel:
        px[x, y] = ton + (255,)

    ## Bei ungerader Hoehe gibt es eine echte Mittelzeile -- die bleibt als
    ## Strich stehen. Bei gerader Hoehe gibt es keine (zwei Zeilen liegen
    ## gleich nah dran); dann bleibt nur der mittlere Punkt der sortierten
    ## Insel als einzelner Wimpernpunkt.
    lo = min(p[1] for p in insel)
    hi = max(p[1] for p in insel)
    if (hi - lo) % 2 == 0:
        strich_y = (lo + hi) // 2
        strich = [(x, y) for x, y in insel if y == strich_y]
    else:
        strich = [sorted(insel)[len(insel) // 2]]
    ## Die dunkelste Farbe der Insel selbst -- keine Umriss-Ebene noetig,
    ## die kann bei einem farbigen Auge wie diesem fehlen.
    dunkelste = min(insel, key=lambda p: _helligkeit(sichtbar[p[0], p[1]][:3]))
    farbe = sichtbar[dunkelste[0], dunkelste[1]][:3] + (255,)
    for x, y in strich:
        px[x, y] = farbe
    return out
