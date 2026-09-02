import unittest

from PIL import Image

from tools.character_layers import PARTS, split


def _figur():
    """Vier Farbfelder und ein durchsichtiger Rand."""
    img = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    px = img.load()
    px[0, 0] = (245, 203, 160, 255)   # skin
    px[1, 0] = (239, 232, 200, 255)   # hair
    px[0, 1] = (46, 111, 208, 255)    # shirt
    px[1, 1] = (26, 26, 34, 255)      # base
    return img


class TestSplit(unittest.TestCase):
    def test_jede_ebene_kommt_vor(self):
        layers = split(_figur(), None)
        self.assertEqual(sorted(layers), sorted(PARTS))

    def test_die_ebenen_ueberlappen_sich_nirgends(self):
        ## Der eigentliche Punkt: ein Pixel gehoert genau EINER Ebene. Beim
        ## alten Mehrheitsvotum lag derselbe Pixel in zweien.
        layers = split(_figur(), None)
        for y in range(4):
            for x in range(4):
                treffer = [p for p in PARTS if layers[p].load()[x, y][3] > 0]
                self.assertLessEqual(len(treffer), 1,
                                     "Pixel %d,%d liegt in %s" % (x, y, treffer))

    def test_uebereinandergelegt_ergeben_sie_wieder_die_figur(self):
        ## Nichts darf unterwegs verlorengehen.
        original = _figur()
        zurueck = Image.new("RGBA", original.size, (0, 0, 0, 0))
        layers = split(original, None)
        for p in PARTS:
            zurueck.alpha_composite(layers[p])
        self.assertEqual(list(zurueck.getdata()), list(original.getdata()))

    def test_eine_eingefrorene_tabelle_schlaegt_die_rechnung(self):
        ## Die gemessene Tabelle ist die Wahrheit -- sonst koennte sich das
        ## Ergebnis zwischen zwei Laeufen aendern.
        table = {(46, 111, 208): "boots"}
        layers = split(_figur(), table)
        self.assertEqual(layers["boots"].load()[0, 1][3], 255)
        self.assertEqual(layers["shirt"].load()[0, 1][3], 0)


if __name__ == "__main__":
    unittest.main()
