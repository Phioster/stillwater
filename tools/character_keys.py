"""Welche Farbe zu welchem Koerperteil gehoert.

Die Figur wird absichtlich in weit auseinanderliegenden Farben erzeugt --
darum ist Trennen hier Nachschlagen und nicht Raten. Die Anker sind die
Zielfarben fuer den Prompt; welche Farben das Modell WIRKLICH gemalt hat,
misst measure() einmal am fertigen Bild.
"""
import colorsys
import json

ANCHORS = {
    "skin": (0xE7, 0xC1, 0xAC),
    "hair": (0xDF, 0x90, 0xD2),
    "shirt": (0x33, 0x39, 0xCC),
    "pants": (0x63, 0xAB, 0x2B),
    "boots": (0x20, 0xB6, 0x92),
    "base": (0x1A, 0x1A, 0x22),
}

## Unterhalb davon ist eine Farbe Umriss, egal welchen Farbton sie hat.
## Tief angesetzt: der Schatten eines blauen Pullovers ist dunkel, aber
## immer noch Pullover -- ihn dem Umriss zuzuschlagen war der alte Fehler.
DARK = 0.12

def _hsl(rgb):
    r, g, b = (c / 255.0 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h, s, l

def _distance(a, b):
    """Abstand zweier Farben, Farbton am schwersten gewichtet.

    Der Farbton trennt Blau von Gruen von Rot; Saettigung trennt das blasse
    Pfirsich der Haut vom satten Tuerkis der Stiefel. Helligkeit zaehlt am
    wenigsten, damit Licht und Schatten desselben Teils zusammenbleiben.
    """
    ha, sa, la = _hsl(a)
    hb, sb, lb = _hsl(b)
    dh = abs(ha - hb)
    dh = min(dh, 1.0 - dh)          # der Farbkreis schliesst sich
    ## Bei blassen Farben sagt der Farbton wenig -- dort zaehlt er weniger.
    weight = 4.0 * min(sa, sb) + 0.5
    return (dh * weight) ** 2 + (abs(sa - sb) * 0.8) ** 2 + (abs(la - lb) * 0.3) ** 2

def assign(rgb):
    """Das Koerperteil, zu dem diese Farbe gehoert."""
    if _hsl(rgb)[2] < DARK:
        return "base"
    return min((p for p in ANCHORS if p != "base"),
               key=lambda p: _distance(rgb, ANCHORS[p]))

def load_table(path):
    with open(path, encoding="utf-8") as fh:
        raw = json.load(fh)
    result = {}
    for k, v in raw.items():
        # Nur Hex-Farbschluessel verarbeiten (Laenge 6)
        if len(k) == 6:
            rgb_key = tuple(int(k[i:i + 2], 16) for i in (0, 2, 4))
            # Part ist entweder ein String oder ein geteilter Eintrag (dict)
            result[rgb_key] = v
    return result
