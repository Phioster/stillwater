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
        ## Die Zahlen sind am Bild gemessen. Der Zopf haengt am TRIPEL aus
        ## Atem, Weite und Kopfversatz, weil seine Naht zum Kopf von allen
        ## dreien abhaengt und mitgebacken werden muss -- 28 erreichbare.
        ## Kopf und Hals haben EINEN Zustand: der Atem ist ein Versatz.
        self.assertEqual(28, len(self.zustaende["zopf"]))
        self.assertEqual(1, len(self.zustaende["kopf"]))
        self.assertEqual(1, len(self.zustaende["hals"]))
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



class TestRueckbau(unittest.TestCase):
    """Aus den Blaettern muss wieder genau das Bild der Vorschau werden.

    Das ist die eigentliche Zusicherung dieses Umbaus: solange der Rueckbau
    stimmt, ist der Weg ueber die Teile nur eine andere Ablage derselben
    Figur -- kein neues Aussehen, das man nachpflegen muesste.
    """

    @classmethod
    def setUpClass(cls):
        from tools.character_keys import load_table
        from tools.character_layers import PARTS
        cls.ebenen = fp.split(_laden("sit3_rumpf.png"))
        cls.koepfe = {s: fp.eye_state(cls.ebenen["head"], s)
                      for s in ("open", "half", "closed")}
        tabelle = load_table(os.path.join(os.path.dirname(TEILE),
                                          "key_palette.json"))
        cls.zust = tb.zustaende(cls.ebenen, cls.koepfe)
        cls.kaesten = {n: tb.rahmen(b) for n, b in cls.zust.items()}
        cls.blaetter = {(n, e): tb.blatt(cls.zust[n], cls.kaesten[n], tabelle, e)
                        for n in cls.zust for e in PARTS}

    def test_die_ebenen_stimmen_mit_dem_ganzen_feld_ueberein(self):
        """Ein Blatt traegt genau die Pixel, die die Farbtabelle dem Teil gibt.

        Die Baender der Tabelle gelten je Bildzeile. Wer erst den Rahmen
        ausschneidet und dann die Farben trennt, fragt sie nach der falschen
        Zeile -- die Beine bekamen so Haar und Pullover. Der Rueckbautest
        sieht das nicht: er legt alle Ebenen wieder uebereinander, und der
        Fehler hebt sich auf.
        """
        from tools.character_keys import load_table
        from tools.character_layers import PARTS, split as farben_schneiden
        tabelle = load_table(os.path.join(os.path.dirname(TEILE),
                                          "key_palette.json"))
        falsch = []
        for name, bilder in self.zust.items():
            x, y, w, h = self.kaesten[name]
            for i, bild in enumerate(bilder):
                erwartet = farben_schneiden(bild, tabelle)
                for ebene in PARTS:
                    soll = erwartet[ebene].crop((x, y, x + w, y + h))
                    ist = self.blaetter[(name, ebene)].crop(
                        (i * w, 0, (i + 1) * w, h))
                    if (list(soll.get_flattened_data())
                            != list(ist.get_flattened_data())):
                        falsch.append("%s Bild %d Ebene %s" % (name, i, ebene))
        self.assertEqual([], falsch[:5])

    def test_zusammengesetzt_ergibt_sich_die_vorschau(self):
        from tools import preview_parts as pp
        abweichungen = []
        for zustand in tb.zopf_zustaende():
            atem, zopf, seit = zustand
            for bein in (-6, 0, 6):
                for auge in ("open", "half", "closed"):
                    erwartet = pp.zusammensetzen(self.ebenen, self.koepfe,
                                                 atem, zopf, bein, auge, seit)
                    gebaut = tb.aufbauen(self.blaetter, self.kaesten, zustand,
                                         bein, auge)
                    if (list(erwartet.get_flattened_data())
                            != list(gebaut.get_flattened_data())):
                        abweichungen.append(
                            "Atem %d Zopf %+d Kopf %+d Bein %+d Auge %s"
                            % (atem, zopf, seit, bein, auge))
        self.assertEqual([], abweichungen[:5])

if __name__ == "__main__":
    unittest.main()


class TestZopfZustaende(unittest.TestCase):
    """Jeder Zustand, den das Spiel erreichen kann, muss gebacken sein.

    Die alte Fassung sammelte die Tripel aus EINEM Durchlauf von
    wurf_lauf.ablauf(). Dort fiel der Wurf zufaellig auf bestimmte
    Atemphasen. Im Spiel faengt er bei jeder an -- die Haelfte der
    erreichbaren Zustaende fehlte, und die Szene faende sie nicht.
    """

    @staticmethod
    def _erreichbar():
        from tools import wurf_lauf as wl
        aus = set()
        for schritt in range(wl.PRO_ZUG):
            atem, zopf = wl.atem_und_zopf(schritt)
            aus.add((atem, zopf, 0))                # Ruhelauf
            for i in range(len(wl.BEIN_WURF)):      # Wurf, jede Phase
                aus.add((atem, zopf + wl.zopf_im_wurf(i), wl.kopf_im_wurf(i)))
        return aus

    def test_jeder_erreichbare_zustand_ist_gebacken(self):
        fehlt = self._erreichbar() - set(tb.zopf_zustaende())
        self.assertEqual(set(), fehlt, "nicht gebacken: %s" % sorted(fehlt))

    def test_kein_zustand_zuviel(self):
        """Jedes ueberzaehlige Bild ist verschenkter Speicher."""
        zuviel = set(tb.zopf_zustaende()) - self._erreichbar()
        self.assertEqual(set(), zuviel, "unerreichbar: %s" % sorted(zuviel))

    def test_kopf_und_hals_haben_einen_zustand(self):
        """Der Atem ist ein Versatz, kein Bild. Zwei gleiche Bilder abzulegen
        war toter Speicher -- _index() gab fuer beide immer 0 zurueck."""
        ebenen = fp.split(_laden("sit3_rumpf.png"))
        koepfe = {s: fp.eye_state(ebenen["head"], s)
                  for s in ("open", "half", "closed")}
        z = tb.zustaende(ebenen, koepfe)
        self.assertEqual(1, len(z["kopf"]))
        self.assertEqual(1, len(z["hals"]))


class TestErzeugteDatei(unittest.TestCase):
    """core/angler_parts.gd wird erzeugt und darf nicht veralten.

    Godot kann das Bauwerkzeug nicht aufrufen; die Zahlen muessen also als
    Konstanten dort liegen. Damit sie nicht auseinanderlaufen, prueft dieser
    Test, dass ein Neuerzeugen die Datei unveraendert laesst.
    """

    def test_die_datei_ist_auf_dem_stand_des_werkzeugs(self):
        pfad = os.path.join(WURZEL, "core", "angler_parts.gd")
        with open(pfad, encoding="utf-8") as f:
            auf_platte = f.read()
        self.assertEqual(auf_platte, tb.gdscript_text(),
                         "core/angler_parts.gd ist veraltet -- "
                         "python3 -m tools.teile_bauen laufen lassen")
