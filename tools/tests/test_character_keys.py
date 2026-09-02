import unittest

from tools.character_keys import ANCHORS, assign


class TestAssign(unittest.TestCase):
    def test_die_ankerfarben_finden_sich_selbst(self):
        for part, rgb in ANCHORS.items():
            self.assertEqual(assign(rgb), part, "%s findet sich nicht selbst" % part)

    def test_ein_schatten_behaelt_sein_teil(self):
        ## Die halbe Helligkeit des Pullovers ist immer noch der Pullover.
        ## Genau hier ist die alte Zuordnung gescheitert: der Schatten war
        ## dunkel, also wurde er Umriss.
        self.assertEqual(assign((23, 55, 104)), "shirt")
        self.assertEqual(assign((23, 84, 39)), "pants")

    def test_haut_und_haar_werden_nicht_verwechselt(self):
        ## Beide sind hell -- getrennt werden sie ueber den Farbton, nicht
        ## ueber die Helligkeit.
        self.assertEqual(assign((240, 198, 155)), "skin")
        self.assertEqual(assign((243, 238, 210)), "hair")

    def test_haut_und_stiefel_werden_nicht_verwechselt(self):
        ## Pfirsich und Rot liegen im Farbton nah beieinander; die Saettigung
        ## trennt sie.
        self.assertEqual(assign((245, 203, 160)), "skin")
        self.assertEqual(assign((176, 48, 38)), "boots")

    def test_fast_schwarz_ist_immer_umriss(self):
        self.assertEqual(assign((26, 26, 34)), "base")
        self.assertEqual(assign((12, 10, 14)), "base")


if __name__ == "__main__":
    unittest.main()
