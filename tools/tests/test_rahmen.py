import os
import unittest

from PIL import Image

from tools import rahmen_bauen


W = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def steg():
    return Image.open(rahmen_bauen.STEG).convert("RGBA")


def fehler(im, versatz, waagerecht, bereich):
    """Mittlerer Farbabstand zwischen einem Ausschnitt und sich selbst,
    um `versatz` verschoben. Klein heisst: die Kachel schliesst an sich an."""
    px = im.load()
    x0, y0, x1, y1 = bereich
    summe = anzahl = 0
    for x in range(x0, x1):
        for y in range(y0, y1):
            bx, by = (x + versatz, y) if waagerecht else (x, y + versatz)
            a, b = px[x, y], px[bx, by]
            summe += sum(abs(a[i] - b[i]) for i in range(3))
            anzahl += 1
    return summe / max(anzahl, 1)


class TestRahmen(unittest.TestCase):
    def test_der_rahmen_stammt_wirklich_aus_dem_steg(self):
        ## Der ganze Sinn der Uebung: kein frisch erfundenes Holz. Jede Kachel
        ## muss sich Pixel fuer Pixel im Stegbild wiederfinden.
        ecke, deck, pfosten = rahmen_bauen.schneide(steg())
        rahmen = rahmen_bauen.bauen(steg())
        self.assertEqual(list(rahmen.crop((0, 0, ecke.width, ecke.height))
                              .getdata()), list(ecke.getdata()))
        oben = rahmen.crop((rahmen_bauen.RAND_SEITE, 0,
                            rahmen_bauen.RAND_SEITE + deck.width, deck.height))
        self.assertEqual(list(oben.getdata()), list(deck.getdata()))
        links = rahmen.crop((0, rahmen_bauen.RAND_OBEN, pfosten.width,
                             rahmen_bauen.RAND_OBEN + pfosten.height))
        self.assertEqual(list(links.getdata()), list(pfosten.getdata()))

    def test_die_pfostenkachel_schliesst_an_sich_selbst_an(self):
        ## Sonst zeigt jede lange Panelkante eine Naht. 24 ist gemessen und
        ## nicht geraten -- der Fehler muss deutlich unter dem der Nachbarn
        ## liegen, sonst stimmt die Periode nicht mehr.
        im = steg()
        bereich = (rahmen_bauen.PFOSTEN_VON, rahmen_bauen.PFOSTEN_AB,
                   rahmen_bauen.PFOSTEN_BIS + 1, rahmen_bauen.PFOSTEN_AB + 8)
        gut = fehler(im, rahmen_bauen.PFOSTEN_PERIODE, False, bereich)
        self.assertLess(gut, 5.0, "die Pfostenkachel hat eine sichtbare Naht")
        for daneben in (rahmen_bauen.PFOSTEN_PERIODE - 3,
                        rahmen_bauen.PFOSTEN_PERIODE + 3):
            self.assertLess(gut, fehler(im, daneben, False, bereich),
                            "Periode %d waere nicht besser" % daneben)

    def test_die_deckkachel_ist_der_pfostenabstand(self):
        ## Das Deck wiederholt sich mit den Pfosten darunter. Faende man eine
        ## andere Periode, waere die Kachel aus zwei halben Brettern.
        im = steg()
        bereich = (30, 0, 150, rahmen_bauen.DECK_HOCH)
        gut = fehler(im, rahmen_bauen.DECK_PERIODE, True, bereich)
        for daneben in (rahmen_bauen.DECK_PERIODE - 12,
                        rahmen_bauen.DECK_PERIODE + 12):
            self.assertLess(gut, fehler(im, daneben, True, bereich),
                            "Periode %d waere nicht besser" % daneben)

    def test_die_mitte_traegt_die_farbe_aus_der_palette(self):
        ## Die Farbe steht in core/palette.gd und soll nicht ein zweites Mal
        ## im Bild kleben -- der Test haelt beide zusammen.
        rahmen = rahmen_bauen.bauen(steg())
        mitte = rahmen.getpixel((rahmen.width // 2, rahmen.height // 2))
        self.assertEqual(mitte[:3], rahmen_bauen.farbe(rahmen_bauen.FUELLUNG))
        self.assertEqual(mitte[3], rahmen_bauen.DECKUNG)

    def test_die_ecken_sind_gespiegelt_und_nicht_vier_mal_dieselbe(self):
        ## Vier gleiche Ecken hiessen: an drei von ihnen kommt das Licht aus
        ## der falschen Richtung.
        r = rahmen_bauen.bauen(steg())
        s, o = rahmen_bauen.RAND_SEITE, rahmen_bauen.RAND_OBEN
        lo = r.crop((0, 0, s, o))
        ro = r.crop((r.width - s, 0, r.width, o))
        self.assertNotEqual(list(lo.getdata()), list(ro.getdata()))
        self.assertEqual(list(lo.transpose(Image.FLIP_LEFT_RIGHT).getdata()),
                         list(ro.getdata()))

    def test_das_bild_auf_der_platte_ist_aktuell(self):
        ## Wer das Werkzeug aendert und das Bild nicht neu erzeugt, merkt es
        ## sonst erst auf dem Geraet.
        auf_platte = Image.open(rahmen_bauen.BLATT).convert("RGBA")
        self.assertEqual(list(auf_platte.getdata()),
                         list(rahmen_bauen.bauen(steg()).getdata()))


if __name__ == "__main__":
    unittest.main()
