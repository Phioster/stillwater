import unittest

from PIL import Image

from tools.frame_order import pingpong_order, silhouette_delta, turning_point


def _balken(hoehe):
    """Ein Bild, dessen Umriss sich mit der Hoehe aendert."""
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    px = img.load()
    for y in range(hoehe):
        for x in range(8):
            px[x, y] = (255, 255, 255, 255)
    return img


class TestReihenfolge(unittest.TestCase):
    def test_der_abstand_zaehlt_unterschiedliche_umrisspixel(self):
        self.assertEqual(silhouette_delta(_balken(2), _balken(2)), 0)
        self.assertEqual(silhouette_delta(_balken(2), _balken(3)), 8)

    def test_umkehrpunkt_einer_geschlossenen_schleife(self):
        ## Eine Template-Animation kehrt zum Anfang zurueck. Der Umkehrpunkt
        ## ist das Bild, das am weitesten von Bild 0 entfernt ist.
        frames = [_balken(h) for h in (1, 2, 3, 4, 5, 4, 3, 2)]
        self.assertEqual(turning_point(frames), 4)

    def test_geschlossene_schleife_wird_hinter_dem_umkehrpunkt_gekappt(self):
        ## Ohne Kappen liefe die Schwingung im Pingpong zweimal -- hin,
        ## zurueck, nochmal zurueck, nochmal hin.
        frames = [_balken(h) for h in (1, 2, 3, 4, 5, 4, 3, 2)]
        self.assertEqual(pingpong_order(frames), [0, 1, 2, 3, 4, 3, 2, 1])

    def test_offene_schwingung_wird_gespiegelt(self):
        frames = [_balken(h) for h in (1, 2, 3, 4, 5)]
        self.assertEqual(pingpong_order(frames), [0, 1, 2, 3, 4, 3, 2, 1])

    def test_kein_schritt_springt_um_mehr_als_ein_bild(self):
        ## Dieselbe Zusicherung, die der Godot-Test stellt.
        frames = [_balken(h) for h in (1, 2, 3, 4, 5, 4, 3, 2)]
        order = pingpong_order(frames)
        for i in range(len(order)):
            a, b = order[i], order[(i + 1) % len(order)]
            self.assertEqual(abs(a - b), 1, "Sprung von %d auf %d" % (a, b))


if __name__ == "__main__":
    unittest.main()
