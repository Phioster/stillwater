import os
import unittest

from PIL import Image

from tools import figure_parts as fp
from tools.character_keys import assign

TEILE = os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), "assets", "source", "figure", "parts")


def _laden(name):
    return Image.open(os.path.join(TEILE, name)).convert("RGBA")


def _farben(img):
    px = img.load()
    return {px[x, y][:3] for y in range(img.height) for x in range(img.width)
            if px[x, y][3] > 128}


def _punkte(img):
    px = img.load()
    return {(x, y) for y in range(img.height) for x in range(img.width)
            if px[x, y][3] > 128}


class TestTrennen(unittest.TestCase):
    def setUp(self):
        self.pose = _laden("sit3_rumpf.png")
        self.ebenen = fp.split(self.pose)

    def test_keine_ueberschneidung(self):
        ## Einzige erlaubte Doppelung ist die Unterlage: dort liegt der Kopf
        ## oben und der Rumpf muss trotzdem etwas darunter haben.
        mengen = {n: _punkte(b) for n, b in self.ebenen.items()}
        namen = sorted(mengen)
        unterlage = set(fp.RUMPF_UNTERLAGE)
        for i, a in enumerate(namen):
            for b in namen[i + 1:]:
                gemeinsam = mengen[a] & mengen[b]
                erlaubt = unterlage if {a, b} == {"head", "torso"} else set()
                self.assertEqual(gemeinsam - erlaubt, set(),
                                 "%s und %s teilen %d Pixel" % (a, b, len(gemeinsam)))

    def test_rueckbau_ist_das_original(self):
        ## In der Zeichenreihenfolge aus preview_parts -- der Kopf liegt oben,
        ## sonst deckte die Unterlage die Haarspitze zu.
        zurueck = Image.new("RGBA", self.pose.size, (0, 0, 0, 0))
        for name in ("ponytail", "legs", "torso", "head"):
            zurueck.alpha_composite(self.ebenen[name])
        a, b = zurueck.load(), self.pose.load()
        anders = [(x, y) for y in range(fp.FRAME) for x in range(fp.FRAME)
                  if a[x, y] != b[x, y]]
        self.assertEqual(anders, [], "%d Pixel weichen ab" % len(anders))

    def test_der_zopf_endet_vor_dem_hinterkopf(self):
        ## Der erste Versuch nahm den halben Hinterkopf mit -- das faellt an
        ## der Breite auf.
        zopf = _punkte(self.ebenen["ponytail"])
        self.assertTrue(zopf)
        self.assertLessEqual(max(x for x, _ in zopf), 50)

    def test_die_beine_beginnen_unter_dem_rock(self):
        beine = _punkte(self.ebenen["legs"])
        for x, y in beine:
            grenze = (fp.BEIN_SCHNITT_RECHTS if x >= fp.BEIN_STUFE_AB_X
                      else fp.BEIN_SCHNITT)
            self.assertGreaterEqual(y, grenze, "%d,%d liegt ueber dem Schnitt" % (x, y))

    def test_der_kopf_traegt_kein_oberteil(self):
        px = self.ebenen["head"].load()
        for x, y in _punkte(self.ebenen["head"]):
            if y >= fp.KOPF_HALSBAND and (x, y) not in fp.KINNLINIE:
                self.assertIn(assign(px[x, y][:3]), fp.NUR_KOPF,
                              "%d,%d im Kopf, ist aber %s"
                              % (x, y, assign(px[x, y][:3])))


    def test_die_kinnlinie_haengt_am_kopf(self):
        """Sonst bleibt beim Atmen ein schwarzer Strich am Rumpf stehen."""
        kopf = _punkte(self.ebenen["head"])
        rumpf = _punkte(self.ebenen["torso"])
        for p in fp.KINNLINIE:
            self.assertIn(p, kopf, "%d,%d fehlt im Kopf" % p)
            self.assertNotIn(p, rumpf, "%d,%d liegt doppelt" % p)


class TestBlinzeln(unittest.TestCase):
    def setUp(self):
        self.kopf = fp.split(_laden("sit3_rumpf.png"))["head"]

    def test_offen_ist_unveraendert(self):
        offen = fp.eye_state(self.kopf, "open")
        self.assertEqual(_punkte(offen), _punkte(self.kopf))
        a, b = offen.load(), self.kopf.load()
        self.assertTrue(all(a[x, y] == b[x, y]
                            for y in range(fp.FRAME) for x in range(fp.FRAME)))

    def test_zu_bringt_keine_neue_farbe(self):
        for stellung in ("half", "closed"):
            neu = _farben(fp.eye_state(self.kopf, stellung)) - _farben(self.kopf)
            self.assertEqual(neu, set(), "%s: neue Farben %s" % (stellung, sorted(neu)))

    def test_das_auge_ist_wirklich_zu(self):
        ## Kein Dunklerwerden, sondern Lidhaut da, wo Iris war.
        zu = fp.eye_state(self.kopf, "closed").load()
        for p in ((64, 21), (65, 21)):
            self.assertEqual(zu[p][:3], (0xe8, 0x84, 0x74),
                             "%d,%d ist keine Lidhaut" % p)
        for p in ((63, 22), (64, 22), (65, 22)):
            self.assertEqual(zu[p][:3], (0x03, 0x02, 0x01),
                             "%d,%d ist kein Lidstrich" % p)

    def test_die_silhouette_bleibt(self):
        for stellung in ("half", "closed"):
            self.assertEqual(_punkte(fp.eye_state(self.kopf, stellung)),
                             _punkte(self.kopf))


class TestSchwingen(unittest.TestCase):
    def test_am_drehpunkt_bewegt_sich_nichts(self):
        self.assertEqual(fp.swing(fp.ZOPF_GUMMI_Y, 4, fp.ZOPF_GUMMI_Y,
                                  fp.ZOPF_SPITZE_Y), 0)
        self.assertEqual(fp.swing(fp.BEIN_KNIE_Y, 6, fp.BEIN_KNIE_Y,
                                  fp.BEIN_ZEH_Y), 0)

    def test_an_der_spitze_voller_ausschlag(self):
        self.assertEqual(fp.swing(fp.ZOPF_SPITZE_Y, 2, fp.ZOPF_GUMMI_Y,
                                  fp.ZOPF_SPITZE_Y), 2)
        self.assertEqual(fp.swing(fp.BEIN_ZEH_Y, -6, fp.BEIN_KNIE_Y,
                                  fp.BEIN_ZEH_Y), -6)

    def test_dazwischen_waechst_er_gleichmaessig(self):
        werte = [fp.swing(y, 4, fp.BEIN_KNIE_Y, fp.BEIN_ZEH_Y)
                 for y in range(fp.BEIN_KNIE_Y, fp.BEIN_ZEH_Y + 1)]
        self.assertEqual(werte, sorted(werte), "der Ausschlag springt zurueck")
        self.assertEqual(werte[0], 0)
        self.assertEqual(werte[-1], 4)

    def test_ueber_die_spitze_hinaus_nicht_weiter(self):
        ## Die Stiefelsohle liegt unter ZEH_Y -- ohne Deckel liefe sie davon.
        self.assertEqual(fp.swing(fp.BEIN_ZEH_Y + 5, 4, fp.BEIN_KNIE_Y,
                                  fp.BEIN_ZEH_Y), 4)


if __name__ == "__main__":
    unittest.main()
