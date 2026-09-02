"""Auge zu.

Das Auge ist die dunkle Insel INNERHALB der Haut -- der Umriss ist genauso
dunkel, liegt aber am Rand. Seit die Haut eine bekannte Schluesselfarbe hat,
ist das ohne Raten zu unterscheiden: ein dunkler Pixel gehoert zum Auge, wenn
in allen vier Richtungen Haut kommt, bevor Rand oder Transparenz erreicht wird.
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

def close_eye(img, table):
    layers = split(img, table)
    haut = layers["skin"].load()
    dunkel = layers["base"].load()
    sichtbar = img.load()
    w, h = img.size
    insel = [(x, y) for y in range(h) for x in range(w)
             if dunkel[x, y][3] > 0 and _ist_insel(haut, sichtbar, x, y, w, h)]
    if not insel:
        return img.copy()

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
    farbe = dunkel[insel[0][0], insel[0][1]]
    for x, y in strich:
        px[x, y] = farbe
    return out
