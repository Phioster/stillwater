import unittest

from PIL import Image

from tools import fische_bauen as fb

KLEIN = (48, 24)


class TestFischeBauen(unittest.TestCase):
    def test_silhouette_deckt_genau_den_fisch(self):
        bild = Image.new("RGBA", KLEIN, (0, 0, 0, 0))
        bild.putpixel((3, 4), (200, 100, 50, 255))
        s = fb.silhouette(bild)
        self.assertEqual(s.getpixel((3, 4)), fb.SCHATTEN + (255,))
        self.assertEqual(s.getpixel((0, 0))[3], 0)

    def test_eine_palette_je_zone(self):
        a = Image.new("RGBA", KLEIN, (10, 200, 30, 255))
        b = Image.new("RGBA", KLEIN, (200, 20, 30, 255))
        aus = fb.gemeinsame_palette([a, b])
        self.assertEqual([x.size for x in aus], [KLEIN, KLEIN])
        farben = set()
        for x in aus:
            farben |= {p[:3] for p in x.get_flattened_data()}
        self.assertLessEqual(len(farben), fb.FARBEN_JE_ZONE)

    def test_jede_zone_kennt_ihre_fische(self):
        z = fb.zonen()
        self.assertEqual(len(z), 7)
        self.assertEqual(sum(len(v) for v in z.values()), 114)

    def test_riesen_behalten_ihre_groesse(self):
        a = Image.new("RGBA", KLEIN, (10, 200, 30, 255))
        b = Image.new("RGBA", (96, 40), (200, 20, 30, 255))
        aus = fb.gemeinsame_palette([a, b])
        self.assertEqual([x.size for x in aus], [KLEIN, (96, 40)])

    def test_verzerren_bleibt_ganz_oder_gar_nicht(self):
        bild = Image.new("RGBA", KLEIN, (0, 0, 0, 0))
        for x in range(10, 38):
            for y in range(8, 16):
                bild.putpixel((x, y), (90, 90, 160, 255))
        aus = fb.verzerren(bild)
        self.assertEqual(aus.size, KLEIN)
        self.assertEqual({p[3] for p in aus.get_flattened_data()}, {0, 255})

    def test_eigene_palette_nennt_nur_echte_arten(self):
        alle = {f for ids in fb.zonen().values() for f in ids}
        self.assertEqual(fb.EIGENE_PALETTE - alle, set())
        self.assertEqual(fb.VERZERREN - alle, set())
