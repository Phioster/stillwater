import os
import unittest

from fontTools.ttLib import TTFont

from tools import zeichen_bauen


W = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SILKSCREEN = os.path.join(W, "assets", "fonts", "Silkscreen.ttf")
QUELLEN = ("scenes", "autoload", "core", "data")
ENDUNGEN = (".gd", ".tscn", ".tres")


def zeichensatz(pfad):
    f = TTFont(pfad)
    s = set()
    for t in f["cmap"].tables:
        s |= set(t.cmap.keys())
    return s


def gebrauchte_zeichen():
    """Jedes Zeichen ueber ASCII, das auf dem Schirm landen kann. Reine
    Kommentarzeilen bleiben draussen -- dort steht Prosa."""
    out = set()
    for basis in QUELLEN:
        for wurzel, _, namen in os.walk(os.path.join(W, basis)):
            for name in namen:
                if not name.endswith(ENDUNGEN):
                    continue
                with open(os.path.join(wurzel, name), encoding="utf-8") as fh:
                    for zeile in fh:
                        if zeile.lstrip().startswith("#"):
                            continue
                        out |= {ord(c) for c in zeile if ord(c) > 127}
    return out


class TestZeichen(unittest.TestCase):
    def test_die_schrift_deckt_genau_die_luecke_von_silkscreen(self):
        ## Kein Zeichen zu wenig (dann stuende dort ein leeres Kaestchen) und
        ## keines zu viel (dann pflegen wir eine Glyphe, die niemand zeichnet).
        silk = zeichensatz(SILKSCREEN)
        gebraucht = gebrauchte_zeichen()
        self.assertGreater(len(gebraucht), 20, "die Suche greift ins Leere")
        luecke = gebraucht - silk
        self.assertEqual(set(zeichen_bauen.ZEICHEN), luecke,
                         "Zeichenschrift und Luecke laufen auseinander")

    def test_jedes_muster_ist_rechteckig_und_nicht_leer(self):
        for cp, (name, muster) in zeichen_bauen.ZEICHEN.items():
            self.assertTrue(muster, "%s ist leer" % name)
            breiten = {len(z) for z in muster}
            self.assertEqual(len(breiten), 1,
                             "%s hat verschieden lange Zeilen" % name)
            self.assertIn("#", "".join(muster), "%s zeichnet nichts" % name)
            self.assertLessEqual(len(muster), 8,
                                 "%s ist hoeher als die Zeile traegt" % name)

    def test_die_glyphen_sitzen_auf_silkscreens_raster(self):
        ## Ein Pixel sind 125 Einheiten -- an Silkscreen abgemessen. Laege ein
        ## Zeichen dazwischen, waere es das einzige unscharfe im Satz.
        f = TTFont(zeichen_bauen.BLATT)
        gs = f.getGlyphSet()
        from fontTools.pens.recordingPen import RecordingPen
        for name, _ in zeichen_bauen.ZEICHEN.values():
            stift = RecordingPen()
            gs[name].draw(stift)
            for _befehl, punkte in stift.value:
                for p in punkte:
                    self.assertEqual(p[0] % zeichen_bauen.PIXEL, 0,
                                     "%s liegt waagerecht zwischen zwei Pixeln" % name)
                    self.assertEqual(p[1] % zeichen_bauen.PIXEL, 0,
                                     "%s liegt senkrecht zwischen zwei Pixeln" % name)

    def test_die_glyphe_deckt_sich_mit_ihrem_muster(self):
        ## Die gebaute Glyphe muss genau dort sitzen, wo im Muster ein # steht.
        ## Leere Musterzeilen sind dabei ABSICHT und kein Versehen: sie heben
        ## das Minuszeichen auf Zeilenmitte -- auf der Grundlinie waere es ein
        ## Unterstrich. Keines der Zeichen darf aber darunter haengen.
        f = TTFont(zeichen_bauen.BLATT)
        gs = f.getGlyphSet()
        from fontTools.pens.boundsPen import BoundsPen
        P, L = zeichen_bauen.PIXEL, zeichen_bauen.LUFT
        for name, muster in zeichen_bauen.ZEICHEN.values():
            bp = BoundsPen(gs)
            gs[name].draw(bp)
            self.assertIsNotNone(bp.bounds, "%s ist leer" % name)
            hoch = len(muster)
            zeilen = [y for y, z in enumerate(muster) if "#" in z]
            spalten = [x for x in range(len(muster[0]))
                       if any(z[x] == "#" for z in muster)]
            erwartet = ((L + min(spalten)) * P, (hoch - 1 - max(zeilen)) * P,
                        (L + max(spalten) + 1) * P, (hoch - min(zeilen)) * P)
            self.assertEqual(tuple(bp.bounds), erwartet,
                             "%s sitzt nicht auf seinem Muster" % name)
            self.assertGreaterEqual(bp.bounds[1], 0,
                                    "%s haengt unter der Grundlinie" % name)

    def test_die_schrift_auf_der_platte_ist_aktuell(self):
        auf_platte = zeichensatz(zeichen_bauen.BLATT)
        self.assertEqual(auf_platte, set(zeichen_bauen.ZEICHEN),
                         "assets/fonts/StillwaterZeichen.ttf ist veraltet")


if __name__ == "__main__":
    unittest.main()
