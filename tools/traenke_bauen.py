"""Die 18 Trankbilder aus sieben Grundbildern schneiden und faerben.

    python3 -m tools.traenke_bauen

Flaschenform = Stufe, Fluessigkeitsfarbe = Wirkung. Die Grundbilder kommen
aus PixelLab mit ROTER Fluessigkeit; hier wird nur umgefaerbt.
"""
import colorsys
import os
import re

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUELLE = os.path.join(WURZEL, "assets", "source", "potions")
ZIEL = os.path.join(WURZEL, "assets", "art")
GROESSE = 32


def seltenheit(rid):
    """Die Farbe steht schon in den Seltenheitsdaten -- nicht ein zweites Mal hier."""
    s = open(os.path.join(WURZEL, "data", "rarities", rid + ".tres")).read()
    r, g, b = (float(v) for v in re.search(r"color = Color\(([\d.]+), ([\d.]+), ([\d.]+)", s).groups())
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


SCHIMMER, LOCKSTOFF, ERFAHRUNG, HANDEL = "#e890c8", "#6fae4f", "#4fb8c8", "#f0c05a"

## Kennung -> (Grundbild, Farbe oder None fuer "nicht faerben").
TRAENKE = {
    "schimmer_phiole": ("phiole", SCHIMMER), "schimmer_trank": ("trank", SCHIMMER),
    "schimmer_elixier": ("elixier", SCHIMMER),
    "koeder_phiole": ("phiole", LOCKSTOFF), "koeder_trank": ("trank", LOCKSTOFF),
    "koeder_elixier": ("elixier", LOCKSTOFF),
    "erfahrung_phiole": ("phiole", ERFAHRUNG), "erfahrung_trank": ("trank", ERFAHRUNG),
    "erfahrung_elixier": ("elixier", ERFAHRUNG),
    "wert_phiole": ("phiole", HANDEL), "wert_trank": ("trank", HANDEL),
    "wert_elixier": ("elixier", HANDEL),
    "selten_elixier": ("kristall", "rare"), "episch_elixier": ("kristall", "epic"),
    "legendaer_elixier": ("kristall", "legendary"),
    "mondglas": ("mondglas", None), "sparhaken": ("sparhaken", None),
    "tiefenlot": ("senkblei", None),
}


def zuschneiden(bild):
    """Inhalt mittig auf 32x32 -- nie skalieren, sonst verschwimmen die Pixel."""
    box = bild.getchannel("A").getbbox()
    b, h = box[2] - box[0], box[3] - box[1]
    if b > GROESSE or h > GROESSE:
        raise ValueError("Inhalt %dx%d passt nicht auf %d" % (b, h, GROESSE))
    aus = Image.new("RGBA", (GROESSE, GROESSE), (0, 0, 0, 0))
    aus.alpha_composite(bild.crop(box), ((GROESSE - b) // 2, (GROESSE - h) // 2))
    return aus


def _ist_fluessigkeit(r, g, b):
    """Pink bis tiefrot. Reines Rot nur kraeftig oder hell -- Korkholz liegt knapp daneben."""
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if s <= 0.3:
        return False
    return h > 0.9 or (h < 0.03 and (s > 0.8 or v > 0.85))


def faerben(bild, farbe):
    """Farbton und Saettigung der Wirkung, Helligkeit bleibt -- wie palette_swap."""
    zh, zs, _ = colorsys.rgb_to_hsv(*(int(farbe[i:i + 2], 16) / 255 for i in (1, 3, 5)))
    aus = bild.copy()
    px = aus.load()
    for y in range(aus.height):
        for x in range(aus.width):
            r, g, b, a = px[x, y]
            if a and _ist_fluessigkeit(r, g, b):
                v = max(r, g, b) / 255
                nr, ng, nb = colorsys.hsv_to_rgb(zh, zs, v)
                px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return aus


def main():
    for tid, (grund, farbe) in TRAENKE.items():
        bild = zuschneiden(Image.open(os.path.join(QUELLE, grund + ".png")).convert("RGBA"))
        if farbe is not None:
            bild = faerben(bild, seltenheit(farbe) if not farbe.startswith("#") else farbe)
        bild.save(os.path.join(ZIEL, "potion_%s.png" % tid))
    print("%d Trankbilder geschrieben" % len(TRAENKE))


if __name__ == "__main__":
    main()
