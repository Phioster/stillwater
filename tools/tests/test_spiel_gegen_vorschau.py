"""Das Spiel muss dasselbe Bild ergeben wie die Vorschau.

Das ist die staerkste Zusicherung dieses Umbaus. Die Vorschau
(tools/wurf_lauf.py) ist das, was der Mensch abnimmt; das Spiel setzt die
Figur aus Teileblaettern zusammen und kennt die Vorschau nicht. Laufen beide
auseinander, sieht der Mensch etwas anderes ab, als er spaeter spielt.

Genau das ist mehrfach passiert:

* pose_raw.png gegen sit3_rumpf.png -- zwei verschiedene Zeichnungen derselben
  Pose, 1685 von 3100 Pixeln verschieden.
* rod_45.png gegen rute_mit_griff.png -- zwei verschiedene Ruten, 150 gegen
  76 Pixel lang.
* wurf_rute_0.png im Ruhelauf -- eine fertig zusammengesetzte Zeichnung, die
  tools/figur_nachziehen.py nie gesehen hatte: 34 Pixel alter Stand.
* Die Rute lag vor dem nahen Arm statt dahinter -- 13 Pixel an der Faust.

Jeder dieser Faelle ist erst aufgefallen, als jemand hingesehen hat. Dieser
Test sieht bei jedem Lauf hin.
"""
import json
import os
import re
import unittest

from PIL import Image

from tools import figure_parts as fp
from tools import teile_bauen as tb
from tools import wurf_lauf as wl
from tools.character_keys import load_table
from tools.character_layers import PARTS

WURZEL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(WURZEL, "assets", "source", "figure")
TEILE = os.path.join(SRC, "parts")
POSE = os.path.join(WURZEL, "core", "angler_pose.gd")


def _laden(pfad):
    return Image.open(pfad).convert("RGBA")


def _anker():
    """ROD_ANCHOR aus core/angler_pose.gd -- die Zahlen, die das Spiel nutzt."""
    text = open(POSE, encoding="utf-8").read()
    block = re.search(r"const ROD_ANCHOR: Array\[Vector2i\] = \[(.*?)\]\n",
                      text, re.S).group(1)
    return [(int(a), int(b)) for a, b in
            re.findall(r"Vector2i\((-?\d+),\s*(-?\d+)\)", block)]


def _griff():
    text = open(POSE, encoding="utf-8").read()
    m = re.search(r"const ROD_GRIP: Vector2i = Vector2i\((\d+),\s*(\d+)\)", text)
    return (int(m.group(1)), int(m.group(2)))


def _rahmen():
    text = open(POSE, encoding="utf-8").read()
    return int(re.search(r"const ROD_FRAME_SIZE: int = (\d+)", text).group(1))


class TestSpielGegenVorschau(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        ## --- die Vorschau ------------------------------------------------
        koerper = _laden(os.path.join(TEILE, "sit3_rumpf.png"))
        koerper.alpha_composite(_laden(os.path.join(TEILE, "sit3_arm_fern.png")))
        cls.v_ebenen = fp.split(koerper)
        cls.v_koepfe = {s: fp.eye_state(cls.v_ebenen["head"], s)
                        for s in ("open", "half", "closed")}
        cls.anker = json.load(open(os.path.join(SRC, "wurf_anker.json")))
        cls.staebe = [_laden(os.path.join(SRC, "wurf_stab_%d.png" % i))
                      for i in range(10)]
        cls.arme = [_laden(os.path.join(SRC, "wurf_arm_%d.png" % i))
                    for i in range(10)]

        ## --- das Spiel ---------------------------------------------------
        ebenen = fp.split(_laden(os.path.join(TEILE, "sit3_rumpf.png")))
        koepfe = {s: fp.eye_state(ebenen["head"], s)
                  for s in ("open", "half", "closed")}
        tabelle = load_table(os.path.join(SRC, "key_palette.json"))
        zust = tb.zustaende(ebenen, koepfe)
        cls.kaesten = {n: tb.rahmen(b) for n, b in zust.items()}
        cls.blaetter = {(n, e): tb.blatt(zust[n], cls.kaesten[n], tabelle, e)
                        for n in zust for e in PARTS}
        cls.rute = _laden(os.path.join(WURZEL, "assets", "art", "char_rod_0.png"))
        cls.rod_anker = _anker()
        cls.rod_griff = _griff()
        cls.rod_rahmen = _rahmen()

    def _vorschau(self, nummer, atem, zopf, bein, auge, seit):
        bild = wl.wurfbild(self.v_ebenen, self.v_koepfe, self.staebe[nummer],
                           self.anker["anker"][nummer], self.anker["griff"],
                           self.arme[nummer], (atem, zopf, bein, auge, seit))
        return bild.crop((0, wl.OBEN, fp.FRAME, wl.OBEN + fp.FRAME))

    def _spiel(self, arm, atem, zopf, bein, auge, seit):
        """Genau das, was scenes/fishing/angler.gd::set_pose tut.

        Reihenfolge: die Teile aus ZEICHENFOLGE, die Rute VOR dem nahen Arm.
        Atem und Kopfversatz sind Versatz der Gruppe, nicht Bild.
        """
        aus = Image.new("RGBA", (fp.FRAME, fp.FRAME), (0, 0, 0, 0))
        for name in tb.ZEICHENFOLGE:
            if name == "arm":
                r = 0 if arm == 0 else arm - 1
                ax, ay = self.rod_anker[arm]
                aus.alpha_composite(
                    self.rute.crop((r * self.rod_rahmen, 0,
                                    (r + 1) * self.rod_rahmen, self.rod_rahmen)),
                    (ax - self.rod_griff[0], ay - self.rod_griff[1] + atem))
            x, y, w, h = self.kaesten[name]
            i = tb._index(name, (atem, zopf, seit), bein, auge, arm)
            vx, vy = (x + seit, y + atem) if name in tb.AM_KOPF else (x, y)
            for ebene in PARTS:
                aus.alpha_composite(
                    self.blaetter[(name, ebene)].crop((i * w, 0, (i + 1) * w, h)),
                    (vx, vy))
        return aus

    def _vergleichen(self, faelle):
        abweichungen = []
        for nummer, arm, atem, zopf, bein, auge, seit in faelle:
            a = self._vorschau(nummer, atem, zopf, bein, auge, seit)
            b = self._spiel(arm, atem, zopf, bein, auge, seit)
            ap, bp = a.load(), b.load()
            anders = [(x, y) for y in range(fp.FRAME) for x in range(fp.FRAME)
                      if ap[x, y] != bp[x, y]]
            if anders:
                abweichungen.append(
                    "Arm %d Atem %d Zopf %+d Bein %+d Auge %s Kopf %+d: "
                    "%d Pixel, z.B. %s"
                    % (arm, atem, zopf, bein, auge, seit, len(anders),
                       anders[:4]))
        self.assertEqual([], abweichungen[:3])

    def test_der_ruhelauf_stimmt_ueberein(self):
        """Jede vierte Atemphase, drei Beinweiten, alle drei Augenstellungen.

        Nicht jede Phase: der Atem hat nur zwei Zustaende und der Zopf fuenf,
        die 32 Schritte sind also weit weniger als 32 verschiedene Bilder.
        """
        faelle = []
        for schritt in range(0, wl.PRO_ZUG, 4):
            atem, zopf = wl.atem_und_zopf(schritt)
            for bein in (-6, 0, 6):
                for auge in ("open", "half", "closed"):
                    faelle.append((0, 0, atem, zopf, bein, auge, 0))
        self._vergleichen(faelle)

    def test_der_wurf_stimmt_ueberein(self):
        """Alle zehn Wurfbilder, in vier Atemphasen.

        Der Wurf kann bei jeder Phase anfangen -- deshalb mehrere. Genau hier
        war die Rute vor dem nahen Arm statt dahinter, und es fiel an drei
        Pixeln an der Faust auf.
        """
        faelle = []
        for nummer in range(10):
            for schritt in (0, 8, 16, 24):
                atem, z = wl.atem_und_zopf(schritt)
                faelle.append((nummer, nummer + 1, atem,
                               z + wl.zopf_im_wurf(nummer),
                               wl.BEIN_WURF[nummer], "open",
                               wl.kopf_im_wurf(nummer)))
        self._vergleichen(faelle)


if __name__ == "__main__":
    unittest.main()
