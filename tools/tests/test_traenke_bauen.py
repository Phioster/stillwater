import unittest

from PIL import Image

from tools import traenke_bauen as tb


class TestZuschneiden(unittest.TestCase):
    def test_inhalt_landet_mittig_auf_32(self):
        bild = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        for x in range(10, 20):
            for y in range(5, 25):
                bild.putpixel((x, y), (200, 10, 10, 255))
        aus = tb.zuschneiden(bild)
        self.assertEqual(aus.size, (32, 32))
        self.assertEqual(aus.getbbox(), (11, 6, 21, 26))

    def test_zu_grosser_inhalt_bricht_ab(self):
        bild = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        bild = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        for x in range(0, 38):
            bild.putpixel((x, 10), (200, 10, 10, 255))
        with self.assertRaises(ValueError):
            tb.zuschneiden(bild)


class TestFaerben(unittest.TestCase):
    def test_rot_wird_zur_zielfarbe_helligkeit_bleibt(self):
        bild = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        bild.putpixel((0, 0), (200, 20, 20, 255))   # Fluessigkeit
        bild.putpixel((1, 0), (90, 60, 49, 255))    # Korkholz, braun
        aus = tb.faerben(bild, "#4fb8c8")
        r, g, b, a = aus.getpixel((0, 0))
        self.assertTrue(b > r and g > r, "Tuerkis erwartet, bekam %s" % ((r, g, b),))
        self.assertEqual(max(r, g, b), 200, "Helligkeit muss bleiben")
        self.assertEqual(aus.getpixel((1, 0)), (90, 60, 49, 255))


class TestTabelle(unittest.TestCase):
    def test_jeder_trank_hat_eine_zeile(self):
        import glob, os
        ids = {os.path.basename(p)[:-5]
               for p in glob.glob(os.path.join(tb.WURZEL, "data", "consumables", "*.tres"))}
        self.assertEqual(ids, set(tb.TRAENKE))
