"""Die Teileblaetter -- Rahmen, Zustaende und die Rueckbauprobe."""
import os
import unittest

from PIL import Image

from tools import figure_parts as fp
from tools import teile_bauen as tb

WURZEL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEILE = os.path.join(WURZEL, "assets", "source", "figure", "parts")


def _laden(name):
    return Image.open(os.path.join(TEILE, name)).convert("RGBA")


class TestRahmen(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ebenen = fp.split(_laden("sit3_rumpf.png"))
        cls.koepfe = {s: fp.eye_state(cls.ebenen["head"], s)
                      for s in ("open", "half", "closed")}
        cls.zustaende = tb.zustaende(cls.ebenen, cls.koepfe)

    def test_jedes_teil_hat_seine_zustaende(self):
        ## Die Zahlen stehen in der Spec und sind am Bild gemessen. Der Zopf
        ## haengt am PAAR aus Weite und Kopfversatz, weil seine Naht zum Kopf
        ## von beidem abhaengt und mitgebacken werden muss.
        self.assertEqual(11, len(self.zustaende["zopf"]))
        self.assertEqual(2, len(self.zustaende["kopf"]))
        self.assertEqual(2, len(self.zustaende["hals"]))
        self.assertEqual(1, len(self.zustaende["rumpf"]))
        self.assertEqual(13, len(self.zustaende["beine"]))
        self.assertEqual(11, len(self.zustaende["arm"]))
        self.assertEqual(1, len(self.zustaende["armfern"]))
        self.assertEqual(3, len(self.zustaende["auge"]))

    def test_der_rahmen_umschliesst_alle_zustaende(self):
        """Ein Teil, das aus seinem Rahmen faellt, waere abgeschnitten."""
        for name, bilder in self.zustaende.items():
            x, y, w, h = tb.rahmen(bilder)
            for i, bild in enumerate(bilder):
                kasten = bild.getbbox()
                if kasten is None:
                    continue
                self.assertGreaterEqual(kasten[0], x, "%s Bild %d links" % (name, i))
                self.assertGreaterEqual(kasten[1], y, "%s Bild %d oben" % (name, i))
                self.assertLessEqual(kasten[2], x + w, "%s Bild %d rechts" % (name, i))
                self.assertLessEqual(kasten[3], y + h, "%s Bild %d unten" % (name, i))

    def test_der_rahmen_ist_so_klein_wie_moeglich(self):
        """Sonst waere der Speichergewinn verschenkt -- er ist der Grund fuer
        diesen ganzen Umbau."""
        for name, bilder in self.zustaende.items():
            x, y, w, h = tb.rahmen(bilder)
            kanten = [False, False, False, False]
            for bild in bilder:
                kasten = bild.getbbox()
                if kasten is None:
                    continue
                kanten[0] |= kasten[0] == x
                kanten[1] |= kasten[1] == y
                kanten[2] |= kasten[2] == x + w
                kanten[3] |= kasten[3] == y + h
            self.assertEqual([True] * 4, kanten,
                             "%s: der Rahmen hat Luft an einer Kante" % name)


if __name__ == "__main__":
    unittest.main()
