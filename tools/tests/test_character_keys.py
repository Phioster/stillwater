import unittest

from tools.character_keys import ANCHORS, _hsl, assign


class TestAssign(unittest.TestCase):
    def test_die_ankerfarben_finden_sich_selbst(self):
        for part, rgb in ANCHORS.items():
            self.assertEqual(assign(rgb), part, "%s findet sich nicht selbst" % part)

    def test_ein_schatten_behaelt_sein_teil(self):
        ## Die halbe Helligkeit des Pullovers ist immer noch der Pullover.
        ## Genau hier ist die alte Zuordnung gescheitert: der Schatten war
        ## dunkel, also wurde er Umriss.
        self.assertEqual(assign((25, 28, 102)), "shirt")
        self.assertEqual(assign((49, 85, 21)), "pants")

    def test_haut_und_haar_werden_nicht_verwechselt(self):
        ## Beide sind hell -- getrennt werden sie ueber den Farbton, nicht
        ## ueber die Helligkeit.
        self.assertEqual(assign((229, 187, 164)), "skin")
        self.assertEqual(assign((225, 152, 213)), "hair")

    def test_haut_und_stiefel_werden_nicht_verwechselt(self):
        ## Auch eine leicht abweichende Fassung darf Pfirsich und Tuerkis
        ## nicht durcheinanderbringen.
        self.assertEqual(assign((229, 187, 164)), "skin")
        self.assertEqual(assign((30, 173, 139)), "boots")

    def test_fast_schwarz_ist_immer_umriss(self):
        self.assertEqual(assign((26, 26, 34)), "base")
        self.assertEqual(assign((12, 10, 14)), "base")

    def test_die_anker_liegen_weit_auseinander(self):
        ## Drei Figuren sind an zu dicht beieinanderliegenden Ankern
        ## gescheitert. Unter 0.15 Farbtonabstand faengt das Raten wieder an.
        farbig = [p for p in ANCHORS if p != "base"]
        for i, a in enumerate(farbig):
            for b in farbig[i + 1:]:
                ha, hb = _hsl(ANCHORS[a])[0], _hsl(ANCHORS[b])[0]
                d = abs(ha - hb)
                d = min(d, 1.0 - d)
                self.assertGreaterEqual(round(d, 2), 0.15,
                                        "%s und %s liegen nur %.2f auseinander" % (a, b, d))


if __name__ == "__main__":
    unittest.main()
