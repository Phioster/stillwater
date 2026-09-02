import unittest

from PIL import Image

from tools.character_ambiguity import finde_mehrdeutige, zweigeteilt


class TestZweigeteilt(unittest.TestCase):
    def test_ein_zusammenhaengender_haufen_ist_nicht_geteilt(self):
        self.assertIsNone(zweigeteilt([10, 11, 12, 13, 14]))

    def test_zwei_haufen_ergeben_die_mitte_der_luecke(self):
        ## Oben Zeile 8-12, unten Zeile 100-104: die Grenze gehoert dazwischen.
        self.assertEqual(zweigeteilt([8, 9, 10, 11, 12, 100, 101, 102, 103, 104]), 56)

    def test_eine_kleine_luecke_zaehlt_nicht(self):
        ## Ein Auge unterbricht die Haut, das ist noch dieselbe Stelle.
        self.assertIsNone(zweigeteilt([20, 21, 22, 26, 27, 28]))


class TestFindeMehrdeutige(unittest.TestCase):
    def test_findet_farben_an_zwei_stellen(self):
        ## Ein gebautes Bild: oben ein Haar-Feld, unten ein Stiefel-Feld.
        ## Darin eine gemeinsame Farbe an zwei Stellen. Erwartet: ein Eintrag
        ## fuer diese Farbe mit oben="hair", unten="boots", und Grenze dazwischen.

        # Baue ein Bild.
        img = Image.new("RGBA", (30, 80), (0, 0, 0, 0))
        px = img.load()

        # Farben
        hair_color = (0xDF, 0x90, 0xD2)
        shared_color = (0x20, 0xB6, 0x92)
        boots_color_alt = (0x1A, 0x9D, 0x7F)  # andere Stiefelfarbe

        # Oben (Zeilen 0-25): Haarfeld
        for y in range(25):
            for x in range(30):
                px[x, y] = hair_color + (255,)

        # Oben: ein paar Pixel der gemeinsamen Farbe
        px[10, 10] = shared_color + (255,)
        px[11, 10] = shared_color + (255,)
        px[10, 11] = shared_color + (255,)
        px[11, 11] = shared_color + (255,)
        px[12, 12] = shared_color + (255,)

        # Unten (Zeilen 50-79): Stiefelfeld mit zwei Stiefelfarben
        # Ein Rand aus boots_color_alt
        for y in range(50, 80):
            for x in range(30):
                px[x, y] = boots_color_alt + (255,)

        # Dann ein Kern aus shared_color
        for y in range(55, 75):
            for x in range(8, 22):
                px[x, y] = shared_color + (255,)

        result = finde_mehrdeutige(img)

        # Erwartet: genau ein Eintrag fuer die gemeinsame Farbe
        self.assertIn(shared_color, result)
        entry = result[shared_color]

        # Kontrolliere Struktur
        self.assertIn("grenze", entry)
        self.assertIn("oben", entry)
        self.assertIn("unten", entry)

        # Oben sollte hair sein (umgeben von hair_color)
        # Unten sollte boots sein (umgeben von boots_color_alt, das assign() als boots erkennt)
        self.assertEqual(entry["oben"], "hair")
        self.assertEqual(entry["unten"], "boots")

        # Die Grenze sollte zwischen den beiden Feldern liegen
        self.assertGreater(entry["grenze"], 25)
        self.assertLess(entry["grenze"], 50)

    def test_umriss_nachbarn_zaehlen_nicht(self):
        ## Ein Haufen, dessen Nachbarn mehrheitlich Umriss sind, aber unter
        ## den Nicht-Umriss-Nachbarn eindeutig zu einem Teil gehoeren, soll
        ## dieses Teil bekommen, nicht "base".

        # Baue ein Bild: oben Haare, unten Stiefel, beide vom Umriss umrandet.
        img = Image.new("RGBA", (30, 80), (0, 0, 0, 0))
        px = img.load()

        # Farben
        hair_color = (0xDF, 0x90, 0xD2)
        shared_color = (0x20, 0xB6, 0x92)
        boots_color_alt = (0x1A, 0x9D, 0x7F)
        outline_color = (0x1A, 0x1A, 0x22)  # sehr dunkel -> assign() gibt "base"

        # Oben (0-25): Haarfeld
        for y in range(25):
            for x in range(30):
                px[x, y] = hair_color + (255,)

        # Oben: Umriss umrandet die Haare an den Kanten
        for x in range(30):
            px[x, 0] = outline_color + (255,)
            px[x, 1] = outline_color + (255,)

        # Oben: ein paar Pixel der gemeinsamen Farbe, umgeben von Haaren
        # und oben viel Umriss (kante)
        px[10, 2] = shared_color + (255,)
        px[11, 2] = shared_color + (255,)
        px[12, 2] = shared_color + (255,)

        # Unten (50-79): Stiefelfeld, auch vom Umriss umrandet
        for y in range(50, 80):
            for x in range(30):
                px[x, y] = boots_color_alt + (255,)

        # Unten: Umriss umrandet die Stiefel
        for x in range(30):
            px[x, 79] = outline_color + (255,)
            px[x, 78] = outline_color + (255,)

        # Unten: Pixel der gemeinsamen Farbe
        px[10, 65] = shared_color + (255,)
        px[11, 65] = shared_color + (255,)
        px[12, 65] = shared_color + (255,)

        result = finde_mehrdeutige(img)

        # Die gemeinsame Farbe sollte gefunden werden
        self.assertIn(shared_color, result)
        entry = result[shared_color]

        # Oben sollte hair sein (trotz Umriss-Nachbarn)
        self.assertEqual(entry["oben"], "hair")

        # Unten sollte boots sein (trotz Umriss-Nachbarn), nicht "base"
        self.assertEqual(entry["unten"], "boots")


if __name__ == "__main__":
    unittest.main()
