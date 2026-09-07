"""Die eingefrorene Farbtabelle gegen die Bilder, aus denen sie stammt.

Der Grund fuer diese Datei: die Tabelle stand einmal auf Bildern, die als
Vorlage laengst verworfen waren. Sie kannte 172 Farben, die nirgends mehr
vorkamen, und 43, die vorkamen, fehlten ihr -- fuer die fiel das Trennen auf
die Rechnung zurueck. Das faellt nicht auf, solange niemand nachzaehlt.
"""
import os
import unittest
from collections import Counter

from tools.character_keys import load_table
from tools.character_layers import PARTS, split, teil_in_zeile
from tools.freeze_palette import SRC, bilder

TABELLE = load_table(os.path.join(SRC, "key_palette.json"))


class TestKeyPalette(unittest.TestCase):
    def test_die_tabelle_kennt_jede_farbe_der_quellbilder(self):
        fehlend = Counter()
        for name, img in bilder():
            px = img.load()
            for y in range(img.size[1]):
                for x in range(img.size[0]):
                    if px[x, y][3] > 128 and px[x, y][:3] not in TABELLE:
                        fehlend["%s #%02x%02x%02x" % (name, *px[x, y][:3])] += 1
        self.assertEqual({}, dict(fehlend))

    def test_jedes_bild_zerfaellt_restlos_und_ueberschneidungsfrei(self):
        for name, img in bilder():
            ebenen = split(img, TABELLE)
            sichtbar = sum(1 for p in img.get_flattened_data() if p[3] > 128)
            summe = sum(sum(1 for q in ebenen[t].get_flattened_data() if q[3] > 0)
                        for t in PARTS)
            self.assertEqual(sichtbar, summe, name)

    def test_kein_pixel_liegt_allein_in_seiner_ebene(self):
        """Ein Pixel, dessen Ebene KEIN Nachbar teilt, ist ein Fehler.

        Genau so sind drei falsche Eintraege aufgefallen: ein Rockpixel mitten
        im Pullover, ein Rocksaumton auf dem Bein und ein dunkles Blau in der
        Zopfspitze. Der Umriss zaehlt nicht mit -- er umrandet alles und sagt
        deshalb nichts ueber die Zugehoerigkeit.
        """
        allein = []
        for name, img in bilder():
            px = img.load()
            w, h = img.size
            for y in range(h):
                for x in range(w):
                    if px[x, y][3] <= 128:
                        continue
                    teil = teil_in_zeile(TABELLE[px[x, y][:3]], y)
                    if teil == "base":
                        continue
                    nachbarn = set()
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = x + dx, y + dy
                            if (dx, dy) == (0, 0) or not (0 <= nx < w and 0 <= ny < h):
                                continue
                            if px[nx, ny][3] <= 128:
                                continue
                            t = teil_in_zeile(TABELLE[px[nx, ny][:3]], ny)
                            if t != "base":
                                nachbarn.add(t)
                    if nachbarn and teil not in nachbarn:
                        allein.append("%s %d,%d -> %s, Nachbarn %s"
                                      % (name, x, y, teil, sorted(nachbarn)))
        self.assertEqual([], allein)


if __name__ == "__main__":
    unittest.main()
