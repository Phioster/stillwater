"""Das Zusammensetzen der Teile -- was es darf und was nicht."""
import os
import unittest

from PIL import Image

from tools import figure_parts as fp
from tools import preview_parts as pp

WURZEL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEILE = os.path.join(WURZEL, "assets", "source", "figure", "parts")

## Alle Zustaende, die die Bewegung annehmen kann. Der Kopfversatz geht bis
## zwei Pixel, mehr macht wurf_lauf.kopf_im_wurf() nicht.
ZOPF_WEITEN = (-2, -1, 0, 1, 2)
ATEM = (0, 1)
BEIN_WEITEN = tuple(range(-6, 7))
KOPF_SEIT = (-2, -1, 0, 1, 2)
AUGEN = ("open", "half", "closed")


def _laden():
    return Image.open(os.path.join(TEILE, "sit3_rumpf.png")).convert("RGBA")


def faelle():
    """Die Zustaende, die geprueft werden.

    NICHT das volle Kreuzprodukt. Die Beine beruehren Kopf und Zopf nie -- der
    Beinschnitt liegt bei Zeile 89, der Kopf endet bei 32 --, ihre dreizehn
    Stellungen waeren mit jedem Kopfzustand zwoelfmal dasselbe. Deshalb zwei
    Faecher: einmal die Beine allein durch, einmal Kopf und Zopf allein durch.
    Das sind 63 Faelle statt 650 und derselbe Befund in einem Zehntel der Zeit.
    """
    for bein in BEIN_WEITEN:
        yield 0, 0, bein, 0
    for atem in ATEM:
        for zopf in ZOPF_WEITEN:
            for seit in KOPF_SEIT:
                yield atem, zopf, 0, seit


def _sichtbar(bild):
    px = bild.load()
    return {(x, y) for y in range(bild.size[1]) for x in range(bild.size[0])
            if px[x, y][3] > 128}


class TestZusammensetzen(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ebenen = fp.split(_laden())
        cls.koepfe = {s: fp.eye_state(cls.ebenen["head"], s) for s in AUGEN}

    def _erlaubt(self, atem, zopfweite, beinweite, kopf_seit):
        """Wo ein Pixel liegen DARF: die verschobenen Teile, sonst nichts."""
        felder = set()
        for x, y in pp._punkte(self.ebenen["ponytail"]):
            felder.add((x + kopf_seit + fp.swing(y, zopfweite, fp.ZOPF_GUMMI_Y,
                                                 fp.ZOPF_SPITZE_Y), y + atem))
        for x, y in pp._punkte(self.ebenen["legs"]):
            felder.add((x + fp.swing(y, beinweite, fp.BEIN_KNIE_Y,
                                     fp.BEIN_ZEH_Y), y))
        felder |= set(pp._punkte(self.ebenen["torso"]))
        for x, y in pp._punkte(self.ebenen["head"]):
            felder.add((x + kopf_seit, y + atem))
        return {p for p in felder
                if 0 <= p[0] < fp.FRAME and 0 <= p[1] < fp.FRAME}

    def test_die_rohe_lage_erfindet_keinen_pixel(self):
        """Uebereinanderlegen malt nichts dazu.

        Vorher fuellte das Zusammensetzen Haar nach, wo der Zopf wegschwang.
        Von den 17 gefuellten Stellen liegen 16 gar nicht auf Kopfpixeln --
        der Hinterkopf wurde also breiter gemalt, als er gezeichnet ist.
        """
        erfunden = []
        for atem, zopf, bein, seit in faelle():
            bild = pp.roh_zusammensetzen(self.ebenen, self.koepfe, atem, zopf,
                                         bein, "open", seit)
            fremd = _sichtbar(bild) - self._erlaubt(atem, zopf, bein, seit)
            if fremd:
                erfunden.append("Atem %d Zopf %+d Bein %+d Kopf %+d: %s"
                                % (atem, zopf, bein, seit, sorted(fremd)[:6]))
        self.assertEqual([], erfunden[:3])

    def test_nur_eingeschlossene_luecken_werden_geschlossen(self):
        """Der Schlitz am Hinterkopf bleibt offen.

        Er ist zum Rand hin offen, dort faellt Licht durch. Geschlossen wird
        nur, was ringsum zugedeckt ist -- sonst waere man wieder beim
        Nachmalen von Haar.
        """
        zuviel = []
        for atem, zopf, bein, seit in faelle():
            roh = pp.roh_zusammensetzen(self.ebenen, self.koepfe, atem, zopf,
                                        bein, "open", seit)
            fertig = pp.zusammensetzen(self.ebenen, self.koepfe, atem, zopf,
                                       bein, "open", seit)
            erlaubt = set(pp.naht(roh))
            dazu = _sichtbar(fertig) - _sichtbar(roh)
            if dazu - erlaubt:
                zuviel.append("Atem %d Zopf %+d Bein %+d Kopf %+d: %s"
                              % (atem, zopf, bein, seit,
                                 sorted(dazu - erlaubt)[:6]))
        self.assertEqual([], zuviel[:3])

    def test_kein_eingeschlossenes_loch(self):
        """Eine Stelle, die ringsum zugedeckt ist, darf nicht frei sein.

        Zwischen Zopf und Kopf bleibt beim Schwenken stellenweise eine Zeile
        leer. Auf dem dunklen Vorschaugrund sieht man das nicht; im Spiel
        liegt dort der See, und es blitzt hell durch die Naht.
        """
        loecher = []
        for atem, zopf, bein, seit in faelle():
            bild = pp.zusammensetzen(self.ebenen, self.koepfe, atem, zopf,
                                     bein, "open", seit)
            for feld in pp.naht(bild):
                loecher.append("Atem %d Zopf %+d Bein %+d Kopf %+d: %d,%d"
                               % (atem, zopf, bein, seit, feld[0], feld[1]))
        self.assertEqual([], sorted(set(loecher))[:5])


if __name__ == "__main__":
    unittest.main()
