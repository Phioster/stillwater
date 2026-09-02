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


AUGE_ANDERSFARBIG = (0x22, 0x1d, 0x4e, 255)  # assign() stuft das als "shirt" ein


def _gesicht_farbiges_auge():
    """Wie _gesicht(), aber das Auge liegt in der Pullover-Familie, nicht im
    Umriss -- der Fall, den eine auf die Umriss-Ebene beschraenkte Suche
    nicht findet."""
    img = _gesicht()
    px = img.load()
    for x, y in ((4, 4), (5, 4), (4, 5), (5, 5)):
        px[x, y] = AUGE_ANDERSFARBIG
    return img


class TestBlinzelnAndersfarbigesAuge(unittest.TestCase):
    def test_auge_ausserhalb_der_umrissfamilie_wird_trotzdem_gefunden(self):
        zu = close_eye(_gesicht_farbiges_auge(), None)
        px = zu.load()
        self.assertNotEqual(px[4, 4][:3], AUGE_ANDERSFARBIG[:3])
        self.assertNotEqual(px[5, 5][:3], AUGE_ANDERSFARBIG[:3])


SCHOSSFLECK = (60, 140, 60, 255)  # assign() stuft das als "pants" ein


def _gesicht_mit_ablenkung():
    """Ein kleines Gesicht oben (Hautflaeche mit Augen-Insel), eine groessere
    Nicht-Haut-Insel weiter unten in einer eigenen, getrennten Hautflaeche
    (z. B. eine Straehne im Schoss). Ohne Gesichtsbeschraenkung gewinnt die
    groessere untere Insel -- mit ihr nicht, weil die Suche gar nicht erst
    ausserhalb des Gesichtsrechtecks nachsieht."""
    img = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    px = img.load()
    for y in range(1, 10):          # Gesicht: 10x9 Haut, Auge 2x2 (4 Px)
        for x in range(3, 13):
            px[x, y] = HAUT
    for x, y in ((7, 4), (8, 4), (7, 5), (8, 5)):
        px[x, y] = DUNKEL
    for y in range(15, 21):         # Schoss: 12x6 Haut, Fleck 4x3 (12 Px)
        for x in range(2, 14):
            px[x, y] = HAUT
    for y in range(17, 20):
        for x in range(6, 10):
            px[x, y] = SCHOSSFLECK
    return img


class TestBlinzelnMitAblenkung(unittest.TestCase):
    def test_die_groessere_insel_im_schoss_gewinnt_nicht(self):
        zu = close_eye(_gesicht_mit_ablenkung(), None)
        px = zu.load()
        self.assertNotEqual(px[7, 4][:3], DUNKEL[:3], "das Auge blieb offen")
        self.assertNotEqual(px[8, 5][:3], DUNKEL[:3], "das Auge blieb offen")
        for x in range(6, 10):
            for y in range(17, 20):
                self.assertEqual(px[x, y][:3], SCHOSSFLECK[:3],
                                 "die Ablenkung im Schoss wurde faelschlich geschlossen")


if __name__ == "__main__":
    unittest.main()
