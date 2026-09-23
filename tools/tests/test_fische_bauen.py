import unittest

from PIL import Image

from tools import fische_bauen as fb


class TestFischeBauen(unittest.TestCase):
    def test_silhouette_deckt_genau_den_fisch(self):
        bild = Image.new("RGBA", fb.GROESSE, (0, 0, 0, 0))
        bild.putpixel((3, 4), (200, 100, 50, 255))
        s = fb.silhouette(bild)
        self.assertEqual(s.getpixel((3, 4)), fb.SCHATTEN + (255,))
        self.assertEqual(s.getpixel((0, 0))[3], 0)

    def test_eine_palette_je_zone(self):
        a = Image.new("RGBA", fb.GROESSE, (10, 200, 30, 255))
        b = Image.new("RGBA", fb.GROESSE, (200, 20, 30, 255))
        aus = fb.gemeinsame_palette([a, b])
        self.assertEqual([x.size for x in aus], [fb.GROESSE, fb.GROESSE])
        farben = set()
        for x in aus:
            farben |= {p[:3] for p in x.get_flattened_data()}
        self.assertLessEqual(len(farben), fb.FARBEN_JE_ZONE)

    def test_jede_zone_kennt_ihre_fische(self):
        z = fb.zonen()
        self.assertEqual(len(z), 7)
        self.assertEqual(sum(len(v) for v in z.values()), 107)
