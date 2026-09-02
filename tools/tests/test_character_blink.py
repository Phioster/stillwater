import unittest

from PIL import Image

from tools.character_blink import close_eye

HAUT = (245, 203, 160, 255)
DUNKEL = (26, 26, 34, 255)


def _gesicht():
    """Ein Hautfeld mit einem dunklen Auge darin und einem Umriss aussen."""
    img = Image.new("RGBA", (9, 9), (0, 0, 0, 0))
    px = img.load()
    for y in range(1, 8):
        for x in range(1, 8):
            px[x, y] = HAUT
    for i in range(9):
        px[i, 0] = DUNKEL
        px[i, 8] = DUNKEL
    for x, y in ((4, 4), (5, 4), (4, 5), (5, 5)):
        px[x, y] = DUNKEL
    return img


class TestBlinzeln(unittest.TestCase):
    def test_das_auge_verschwindet(self):
        zu = close_eye(_gesicht(), None)
        px = zu.load()
        self.assertNotEqual(px[4, 4], DUNKEL)
        self.assertNotEqual(px[5, 5], DUNKEL)

    def test_ein_wimpernstrich_bleibt_stehen(self):
        ## Ohne Strich sieht es aus, als fehle das Auge.
        zu = close_eye(_gesicht(), None)
        px = zu.load()
        dunkel_im_gesicht = [(x, y) for y in range(1, 8) for x in range(1, 8)
                             if px[x, y][:3] == DUNKEL[:3]]
        self.assertTrue(dunkel_im_gesicht, "kein Wimpernstrich")
        self.assertLessEqual(len(dunkel_im_gesicht), 2,
                             "der Strich ist dicker als eine Zeile: %s" % dunkel_im_gesicht)

    def test_der_umriss_bleibt_unangetastet(self):
        ## Der Rand ist genauso dunkel wie das Auge -- und darf nicht mit
        ## zugemalt werden. Genau daran ist die alte Suche gescheitert.
        zu = close_eye(_gesicht(), None)
        px = zu.load()
        for i in range(9):
            self.assertEqual(px[i, 0], DUNKEL)
            self.assertEqual(px[i, 8], DUNKEL)


if __name__ == "__main__":
    unittest.main()
