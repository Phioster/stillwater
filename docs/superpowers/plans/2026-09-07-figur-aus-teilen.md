# Die Figur aus Teilen — Umsetzungsplan, Stufe 1 und 2

> **Für agentische Arbeiter:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte tragen Kästchen (`- [ ]`) zum Abhaken.

**Ziel:** Die Teile der Anglerin stapeln sich ohne nachgemalte Pixel, und ein Werkzeug baut daraus die Blätter, die das Spiel später lädt.

**Aufbau:** Zwei Stufen. Zuerst hört `preview_parts.zusammensetzen()` auf, Pixel zu erfinden — die Zopflücke bleibt offen, die drei Löcher am Hals bekommen eine gemessene Unterlage. Danach schneidet ein neues Werkzeug jedes Teil auf seinen eigenen Rahmen und schreibt je Teil und Kosmetikebene ein Blatt; die Rückbauprobe vergleicht es Pixel für Pixel mit der Vorschau.

**Werkzeuge:** Python 3 mit Pillow 12.3.0, Godot 4.7.2 für die Suite. Testlauf: `bash tools/test.sh`, Python allein: `python3 -m unittest discover -s tools/tests -t .`

**Spec:** `docs/superpowers/specs/2026-09-07-figur-aus-teilen-im-spiel-design.md`

## Weltweite Vorgaben

- Kommentare und Namen auf Deutsch, in Quelltext **ohne Umlaute** (ae/oe/ue) — so hält es das ganze Repo. Markdown und Commit-Bodies dürfen Umlaute tragen, Commit-Betreffs nicht.
- Jeder Kommentar sagt **warum**, nicht was. Zahlen sind gemessen, nie geschätzt; wo eine Zahl steht, steht daneben, woran sie abgenommen wurde.
- Keine neue Farbe darf ins Bild kommen. Was gesetzt wird, steht schon in `assets/source/figure/key_palette.json` (52 Farben).
- Bildfeld der Figur: 128×128 (`figure_parts.FRAME`).
- Vor jedem Commit läuft `bash tools/test.sh` **ganz** durch — Godot-Suite *und* Python-Tests. Nur die Python-Tests zu fahren hat schon einmal ein Rot in die CI gelassen.
- Keine Attributionszeilen in Commit-Nachrichten.

## Dateien

| Datei | Zuständigkeit |
|---|---|
| `tools/preview_parts.py` | setzt die Teile zu einem Bild zusammen — **ändert sich in Stufe 1** |
| `tools/figure_parts.py` | Ebenengrenzen, Ausbesserungen, Unterlagen — `RUMPF_UNTERLAGE` wächst |
| `tools/teile_bauen.py` | **neu**: schneidet die Teile zu und schreibt die Blätter |
| `tools/tests/test_preview_parts.py` | **neu**: das Zusammensetzen erfindet nichts, und es bleibt kein Loch |
| `tools/tests/test_teile_bauen.py` | **neu**: Rückbauprobe gegen die Vorschau |

---

## Stufe 1 — Die Teile stapeln sich

> **Erledigt am 2026-09-07.** `e68d795` (Zeichnung), `ef437fb` (Aufgabe 1), `b775c3b` (Aufgabe 2).

### Aufgabe 1: Das Zusammensetzen erfindet keinen Pixel

`zusammensetzen()` malt heute zweierlei nach: Haar dort, wo der Zopf wegschwingt, und Füllfarbe in eingeschlossenen Lücken. Beides muss weg — nachgemessen liegen 16 der 17 gefüllten Stellen gar nicht auf Kopfpixeln, die Füllung verbreitert also den Hinterkopf über das Gezeichnete hinaus.

**Dateien:**
- Erstellen: `tools/tests/test_preview_parts.py`
- Ändern: `tools/preview_parts.py` (Funktion `zusammensetzen`, Funktion `_luecken_schliessen` entfällt)

**Schnittstellen:**
- Nutzt: `figure_parts.split()`, `figure_parts.eye_state()`, `figure_parts.swing()`, `preview_parts._punkte()`
- Liefert: `zusammensetzen()` mit unveränderter Signatur, aber ohne jede Füllung. Aufgabe 2 und Stufe 2 bauen darauf auf.

- [x] **Schritt 1: Den fehlschlagenden Test schreiben**

Neue Datei `tools/tests/test_preview_parts.py`:

```python
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

    def test_jeder_pixel_stammt_aus_einem_teil(self):
        """Nichts wird nachgemalt.

        Vorher fuellte das Zusammensetzen Haar nach, wo der Zopf wegschwang.
        Von den 17 gefuellten Stellen liegen 16 gar nicht auf Kopfpixeln -- der
        Hinterkopf wurde also breiter gemalt, als er gezeichnet ist.
        """
        erfunden = []
        for atem, zopf, bein, seit in faelle():
            bild = pp.zusammensetzen(self.ebenen, self.koepfe, atem, zopf,
                                     bein, "open", seit)
            fremd = _sichtbar(bild) - self._erlaubt(atem, zopf, bein, seit)
            if fremd:
                erfunden.append("Atem %d Zopf %+d Bein %+d Kopf %+d: %s"
                                % (atem, zopf, bein, seit, sorted(fremd)[:6]))
        self.assertEqual([], erfunden[:3])


if __name__ == "__main__":
    unittest.main()
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
python3 -m unittest tools.tests.test_preview_parts -v
```

Erwartet: FAIL in `test_jeder_pixel_stammt_aus_einem_teil`, mit Stellen um x 46–49 / y 15–27 — dort füllt die Zopfregel.

- [x] **Schritt 3: Die Füllungen entfernen**

In `tools/preview_parts.py` `zusammensetzen()` ganz durch diese Fassung ersetzen und `_luecken_schliessen()` samt Aufruf löschen:

```python
def zusammensetzen(ebenen, koepfe, atem, zopfweite, beinweite, auge,
                   kopf_seit=0):
    """Ein Bild. Reihenfolge: Zopf, Beine, Hals, Rumpf, restlicher Kopf.

    Der Kopf liegt OBEN. Lag der Rumpf oben, frass sein Schulterumriss beim
    Absenken die Kinnzeile. Ausgenommen ist der Hals: der gehoert hinter den
    Kragen, sonst schiebt er sich beim Neigen darueber. In Ruhe sind alle
    Reihenfolgen gleich, weil die Ebenen sich nicht ueberschneiden.

    Gemalt wird NICHTS. Frueher fuellte diese Funktion zweierlei nach: Haar
    dort, wo der Zopf wegschwang, und Farbe in eingeschlossenen Luecken. Das
    erste erfand Haar am Hinterkopf -- 16 der 17 Stellen liegen gar nicht auf
    Kopfpixeln, der Kopf schliesst nur rechts an. Das zweite deckte drei
    Loecher am Hals zu; die traegt jetzt figure_parts.RUMPF_UNTERLAGE.
    """
    out = Image.new("RGBA", (fp.FRAME, fp.FRAME), (0, 0, 0, 0))
    op = out.load()
    zp = ebenen["ponytail"].load()
    bp = ebenen["legs"].load()
    rp = ebenen["torso"].load()
    kq = koepfe[auge].load()

    for x, y in _punkte(ebenen["ponytail"]):
        ## Der Zopf haengt am Kopf: geht der zur Seite, geht der ganze Zopf
        ## mit, und sein eigener Ausschlag kommt oben drauf.
        nx = x + kopf_seit + fp.swing(y, zopfweite, fp.ZOPF_GUMMI_Y,
                                      fp.ZOPF_SPITZE_Y)
        ny = y + atem
        if 0 <= nx < fp.FRAME and 0 <= ny < fp.FRAME:
            op[nx, ny] = zp[x, y]

    for x, y in _punkte(ebenen["legs"]):
        nx = x + fp.swing(y, beinweite, fp.BEIN_KNIE_Y, fp.BEIN_ZEH_Y)
        if 0 <= nx < fp.FRAME:
            op[nx, y] = bp[x, y]

    kopf = _punkte(ebenen["head"])

    def kopf_setzen(felder):
        for x, y in felder:
            nx, ny = x + kopf_seit, y + atem
            if 0 <= nx < fp.FRAME and 0 <= ny < fp.FRAME:
                op[nx, ny] = kq[x, y]

    kopf_setzen([p for p in kopf if p in fp.HALS])
    for x, y in _punkte(ebenen["torso"]):
        op[x, y] = rp[x, y]
    kopf_setzen([p for p in kopf if p not in fp.HALS])
    return out
```

- [x] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

```
python3 -m unittest tools.tests.test_preview_parts -v
```

Erwartet: PASS.

- [x] **Schritt 5: Nachsehen, was sich am Bild geändert hat**

```
python3 -m tools.preview_parts
```

Der Hinterkopf wird an der Zopfkante um bis zu vier Pixel schmaler, und bei Kopf +1 / Atem 0 stehen drei Löcher offen. Beides ist erwartet; die Löcher schließt Aufgabe 2. Das GIF dem Menschen vorlegen.

- [x] **Schritt 6: Ganze Suite und Commit**

```bash
bash tools/test.sh
git add tools/preview_parts.py tools/tests/test_preview_parts.py
git commit -m "Das Zusammensetzen malt nichts mehr nach"
```

Commit-Body: warum die Zopffüllung falsch war (16 von 17 Stellen ohne Kopf dahinter), und dass drei Löcher am Hals jetzt offenstehen, bis die Unterlage kommt.

---

### Aufgabe 2: Kein eingeschlossenes Loch

> **Erledigt am 2026-09-07 (`b775c3b`), aber anders als hier geplant.** Die
> Schritte unten stehen als Beleg dafür, was versucht wurde. Beim Ausführen
> waren es **acht** Löcher statt drei, und keines war mit festen
> Unterlagepixeln zu schließen: an fünf Stellen liegt im Ruhezustand gar
> nichts, ein Unterlagepixel machte die Figur dort im Stand größer. Gemessen
> wurde außerdem, dass der Zopf allein bei keiner seiner Weiten reißt — es
> ist eine Naht zwischen zwei Teilen. Gebaut ist deshalb die Unterscheidung
> *offen bleibt offen, eingeschlossen wird geschlossen*:
> `roh_zusammensetzen()` legt übereinander, `naht()` findet die
> eingeschlossenen Lücken, `zusammensetzen()` setzt beides zusammen.
> `RUMPF_UNTERLAGE` blieb bei einem Eintrag.

Die drei Löcher am Hals bekommen eine Unterlage im Rumpf — dieselbe Bauart wie das schon vorhandene `(60, 32)`.

**Dateien:**
- Ändern: `tools/tests/test_preview_parts.py` (ein Test dazu)
- Ändern: `tools/figure_parts.py` (`RUMPF_UNTERLAGE`)

**Schnittstellen:**
- Nutzt: `figure_parts.RUMPF_UNTERLAGE`, von `figure_parts.split()` in die Rumpfebene gelegt
- Liefert: eine Figur ohne eingeschlossene Löcher in jedem Zustand

- [x] **Schritt 1: Den fehlschlagenden Test schreiben**

In `tools/tests/test_preview_parts.py` in die Klasse `TestZusammensetzen` einfügen:

```python
    def test_kein_eingeschlossenes_loch(self):
        """Eine Stelle, die ringsum zugedeckt ist, darf nicht frei sein.

        Geht der Kopf zur Seite, gibt er am Hals Pixel frei, unter denen der
        Rumpf nichts hat -- ein Loch mitten in der Figur. Offene Flaechen
        bleiben offen; die Luecke, die der schwingende Zopf freigibt, ist
        gewollt und faellt hier nicht auf, weil sie zum Rand hin offen ist.
        """
        loecher = []
        for atem, zopf, bein, seit in faelle():
            bild = pp.zusammensetzen(self.ebenen, self.koepfe, atem, zopf,
                                     bein, "open", seit)
            px = bild.load()
            for y in range(1, fp.FRAME - 1):
                for x in range(1, fp.FRAME - 1):
                    if px[x, y][3] > 128:
                        continue
                    if all(px[q][3] > 128 for q in
                           ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                        loecher.append("Atem %d Zopf %+d Bein %+d Kopf %+d: %d,%d"
                                       % (atem, zopf, bein, seit, x, y))
        self.assertEqual([], sorted(set(loecher))[:5])
```

- [x] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
python3 -m unittest tools.tests.test_preview_parts.TestZusammensetzen.test_kein_eingeschlossenes_loch -v
```

Erwartet: FAIL mit genau drei verschiedenen Stellen — `49,23`, `55,30` und `57,31`, alle bei Kopf +1 / Atem 0.

- [x] **Schritt 3: Die Unterlage eintragen**

In `tools/figure_parts.py` `RUMPF_UNTERLAGE` ersetzen:

```python
## Pixel, die nur der Rumpf bekommt, obwohl oben der Kopf liegt. Ohne sie
## klafft dort ein Loch, sobald der Kopf sich bewegt -- gemessen ueber alle
## Kopfversaetze -2..+2 bleiben genau diese vier uebrig, und zwar bei Kopf
## +1 / Atem 0. Jede traegt den Ton, den der KOPF an ihrer Stelle traegt:
## was der Kopf freigibt, ist mehr vom Selben dahinter.
##   60,32  die Spitze der Haarstraehne deckt sie zu und wandert mit dem Kopf
##          weg -- ohne Unterlage klafft im Wurf ein Loch mitten im Kragen
##   49,23  Haaransatz an der Zopfnaht
##   55,30  und 57,31  der Hals unter dem Kinn
RUMPF_UNTERLAGE = {
    (60, 32): (0x86, 0x99, 0xb9),
    (49, 23): (0x58, 0x11, 0x53),
    (55, 30): (0xd8, 0x7a, 0x6a),
    (57, 31): (0xe4, 0x8c, 0x79),
}
```

- [x] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

```
python3 -m unittest tools.tests.test_preview_parts -v
```

Erwartet: beide Tests PASS. Der Test aus Aufgabe 1 muss **mitgrün bleiben** — die Unterlage liegt in der Rumpfebene und zählt damit als Teil, nicht als Erfindung.

- [x] **Schritt 5: Nachsehen und ganze Suite**

```
python3 -m tools.preview_parts
bash tools/test.sh
```

Die Löcher sind zu, der schmalere Hinterkopf bleibt. GIF vorlegen.

- [x] **Schritt 6: Commit**

```bash
git add tools/figure_parts.py tools/tests/test_preview_parts.py
git commit -m "Vier Unterlagepixel schliessen die Loecher am Hals"
```

---

## Stufe 2 — Die Blätter je Teil

### Aufgabe 3: Die Teile messen

Jedes Teil bekommt seinen eigenen Rahmen und einen Anker — die Stelle, an der der Rahmen im 128er Feld sitzt. Der Anker ist gemessen, nicht getippt; er wandert später nach `AnglerPose`.

**Dateien:**
- Erstellen: `tools/teile_bauen.py`
- Erstellen: `tools/tests/test_teile_bauen.py`

**Schnittstellen:**
- Nutzt: `figure_parts.split()`, `figure_parts.eye_state()`, `figure_parts.swing()`
- Liefert:
  - `teile_bauen.zustaende(ebenen, koepfe)` → `dict[str, list[Image]]`, je Teil eine Liste von 128×128-Bildern, jedes Teil schon an seiner Stelle
  - `teile_bauen.rahmen(bilder)` → `(x, y, w, h)`, der kleinste Rahmen über alle Zustände eines Teils
  - Teilnamen: `"zopf"`, `"kopf"`, `"hals"`, `"rumpf"`, `"beine"`, `"arm"`, `"armfern"`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

Neue Datei `tools/tests/test_teile_bauen.py`:

```python
"""Die Teileblaetter -- Rahmen, Anker und die Rueckbauprobe."""
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
        ## Die Zahlen stehen in der Spec und sind am Bild gemessen.
        self.assertEqual(11, len(self.zustaende["zopf"]))
        self.assertEqual(2, len(self.zustaende["kopf"]))
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
                bb = bild.getbbox()
                if bb is None:
                    continue
                self.assertGreaterEqual(bb[0], x, "%s Bild %d links" % (name, i))
                self.assertGreaterEqual(bb[1], y, "%s Bild %d oben" % (name, i))
                self.assertLessEqual(bb[2], x + w, "%s Bild %d rechts" % (name, i))
                self.assertLessEqual(bb[3], y + h, "%s Bild %d unten" % (name, i))

    def test_der_rahmen_ist_so_klein_wie_moeglich(self):
        """Sonst waere der Speichergewinn verschenkt -- er ist der Grund fuer
        diesen ganzen Umbau."""
        for name, bilder in self.zustaende.items():
            x, y, w, h = tb.rahmen(bilder)
            kanten = [False, False, False, False]
            for bild in bilder:
                bb = bild.getbbox()
                if bb is None:
                    continue
                kanten[0] |= bb[0] == x
                kanten[1] |= bb[1] == y
                kanten[2] |= bb[2] == x + w
                kanten[3] |= bb[3] == y + h
            self.assertEqual([True] * 4, kanten,
                             "%s: der Rahmen hat Luft an einer Kante" % name)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
python3 -m unittest tools.tests.test_teile_bauen -v
```

Erwartet: `ModuleNotFoundError: No module named 'tools.teile_bauen'`.

- [ ] **Schritt 3: Die kleinste Umsetzung schreiben**

Neue Datei `tools/teile_bauen.py`:

```python
#!/usr/bin/env python3
"""Baut die Blaetter je Teil und Kosmetikebene.

Die Figur wird im Spiel nicht als fertige Bilderreihe gezeigt, sondern aus
beweglichen Teilen zusammengesetzt -- nur so kann die Weite des Beinschwungs
je Schwung neu gezogen werden. Gebacken wird deshalb je TEIL, auf seinen
eigenen Rahmen zugeschnitten: der Zopf ist 19x33 Pixel gross, ihn als volles
128er Bild abzulegen verschenkt das Sechzehnfache.

    python3 -m tools.teile_bauen
"""
import os

from PIL import Image

from tools import figure_parts as fp
from tools import preview_parts as pp

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(WURZEL, "assets", "source", "figure")
TEILE = os.path.join(SRC, "parts")

## Die Zustaende je Teil, alle am Bild gemessen (siehe die Spec vom
## 2026-09-07). Der Atemzug hat zwar 32 Schritte, aber nur acht verschiedene
## Atem/Zopf-Zustaende -- beide haengen an derselben Phase.
## Der Zopf haengt nicht nur an seiner eigenen Weite, sondern auch am
## Kopfversatz: die Naht zwischen ihm und dem Kopf liegt je nach beidem
## woanders, und sie muss ins Blatt gebacken werden -- im Spiel schliesst sie
## niemand zur Laufzeit. Sein Zustand ist deshalb das PAAR. Gemessen wird es
## am Ablauf selbst, nicht getippt: er erreicht elf davon, und der Zopf
## schwingt im Wurf bis +5, nicht nur bis +2 wie im Ruhelauf.
def zopf_paare():
    from tools import wurf_lauf as wl
    return sorted({(zopf, seit)
                   for _, _, _, zopf, _, _, _, seit, _ in wl.ablauf()})


ATEM = (0, 1)
BEIN_WEITEN = tuple(range(-6, 7))
AUGEN = ("open", "half", "closed")


def _leer():
    return Image.new("RGBA", (fp.FRAME, fp.FRAME), (0, 0, 0, 0))


def _verschoben(ebene, versatz):
    """Ein Teil an seine Stelle im 128er Feld, ohne Rand zu verlieren."""
    aus = _leer()
    ap, ep = aus.load(), ebene.load()
    for x, y in pp._punkte(ebene):
        nx, ny = versatz(x, y)
        if 0 <= nx < fp.FRAME and 0 <= ny < fp.FRAME:
            ap[nx, ny] = ep[x, y]
    return aus


## Das Fenster, in dem sich beim Blinzeln ueberhaupt etwas aendert -- aus
## figure_parts.AUGE_HALB und AUGE_ZU abgeleitet, nicht getippt.
def _augenfenster():
    felder = set(fp.AUGE_HALB) | set(fp.AUGE_ZU)
    xs = [p[0] for p in felder]
    ys = [p[1] for p in felder]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def _augenauflage(kopf):
    """Nur das Augenfenster dieses Kopfes, sonst durchsichtig."""
    x0, y0, x1, y1 = _augenfenster()
    aus = _leer()
    ap, kp = aus.load(), kopf.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if kp[x, y][3] > 128:
                ap[x, y] = kp[x, y]
    return aus


def _zopf_mit_naht(ebenen, koepfe, zopfweite, kopf_seit):
    """Der geschorene Zopf, und die Naht zum Kopf gleich mit im Bild.

    Der Kopfversatz steckt NICHT im Bild -- er wird beim Zusammensetzen als
    Versatz des Sprites gesetzt, wie der Atem. Fuer die Naht braucht es ihn
    trotzdem: sie liegt je nach Versatz woanders.
    """
    aus = _verschoben(ebenen["ponytail"],
                      lambda x, y: (x + fp.swing(y, zopfweite,
                                                 fp.ZOPF_GUMMI_Y,
                                                 fp.ZOPF_SPITZE_Y), y))
    ap = aus.load()
    for atem in ATEM:
        roh = pp.roh_zusammensetzen(ebenen, koepfe, atem, zopfweite, 0,
                                    "open", kopf_seit)
        for (x, y), ton in pp.naht(roh).items():
            ## Zurueck in die Koordinaten des Zopfblatts: ohne Kopfversatz,
            ## ohne Atem.
            fx, fy = x - kopf_seit, y - atem
            if 0 <= fx < fp.FRAME and 0 <= fy < fp.FRAME:
                ap[fx, fy] = ton + (255,)
    return aus


def zustaende(ebenen, koepfe):
    """Je Teil die Bilder aller seiner Zustaende, im 128er Feld.

    Der Kopf zerfaellt in zwei Teile: der Hals gehoert hinter den Kragen,
    der Rest davor. Sie bewegen sich gemeinsam, werden aber getrennt
    gezeichnet -- deshalb sind es zwei Blaetter.
    """
    kopf_felder = pp._punkte(ebenen["head"])
    hals = [p for p in kopf_felder if p in fp.HALS]
    rest = [p for p in kopf_felder if p not in fp.HALS]

    def kopfteil(felder, quelle, atem):
        aus = _leer()
        ap, qp = aus.load(), quelle.load()
        for x, y in felder:
            if 0 <= y + atem < fp.FRAME:
                ap[x, y + atem] = qp[x, y]
        return aus

    aus = {
        "zopf": [_zopf_mit_naht(ebenen, koepfe, w, seit)
                 for w, seit in zopf_paare()],
        "kopf": [kopfteil(rest, koepfe["open"], a) for a in ATEM],
        "hals": [kopfteil(hals, koepfe["open"], a) for a in ATEM],
        "rumpf": [_verschoben(ebenen["torso"], lambda x, y: (x, y))],
        "beine": [_verschoben(ebenen["legs"],
                              lambda x, y, w=w: (x + fp.swing(y, w,
                                                              fp.BEIN_KNIE_Y,
                                                              fp.BEIN_ZEH_Y),
                                                 y))
                  for w in BEIN_WEITEN],
    }
    ## Das Auge ist keine eigene Kopfhaltung, sondern eine Auflage weniger
    ## Pixel, die NACH dem Kopf gezeichnet wird. So kostet das Blinzeln nicht
    ## drei Kopfblaetter, sondern eines von vier mal drei Pixeln. Es liegt in
    ## der Grundebene und wird nie umgefaerbt.
    aus["auge"] = [_augenauflage(koepfe[s]) for s in AUGEN]
    aus["arm"] = [Image.open(os.path.join(TEILE, "sit3_arm_nah.png")).convert("RGBA")]
    aus["arm"] += [Image.open(os.path.join(SRC, "wurf_arm_%d.png" % i)).convert("RGBA")
                   for i in range(10)]
    aus["armfern"] = [Image.open(os.path.join(TEILE, "sit3_arm_fern.png")).convert("RGBA")]
    return aus


def rahmen(bilder):
    """Der kleinste Rahmen, der alle Zustaende eines Teils fasst."""
    kaesten = [b.getbbox() for b in bilder if b.getbbox() is not None]
    if not kaesten:
        raise ValueError("Teil ohne einen einzigen sichtbaren Pixel")
    x = min(k[0] for k in kaesten)
    y = min(k[1] for k in kaesten)
    return (x, y,
            max(k[2] for k in kaesten) - x,
            max(k[3] for k in kaesten) - y)
```

Hinweis für den Umsetzer: die Zustände des Zopfs und der Beine tragen den Atem **nicht** — der wird beim Zusammensetzen als Versatz des ganzen Sprites gesetzt, nicht in die Pixel gebacken. Der Zopf hängt am Kopf und geht mit dessen Versatz mit; das erledigt später die Szene, hier bleibt er auf seiner Zeile.

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

```
python3 -m unittest tools.tests.test_teile_bauen -v
```

Erwartet: PASS. Die Rahmen müssen den Zahlen der Spec entsprechen — Zopf 19×34, Kopf 25×28, Rumpf 45×59, Beine 39×36, Arm 32×36, Arm fern 7×19. Weicht einer ab, **nicht den Test anpassen**, sondern melden: dann stimmt eine Annahme der Spec nicht mehr.

- [ ] **Schritt 5: Commit**

```bash
git add tools/teile_bauen.py tools/tests/test_teile_bauen.py
git commit -m "Die Teile messen: Rahmen und Zustaende je Teil"
```

---

### Aufgabe 4: Die Blätter schreiben und zurückbauen

Aus den Zuständen werden Blätter — je Teil und Kosmetikebene eines, Bildgröße gleich dem Rahmen des Teils. Die Rückbauprobe setzt sie wieder zusammen und vergleicht Pixel für Pixel mit der Vorschau.

**Dateien:**
- Ändern: `tools/teile_bauen.py` (`blatt()`, `main()`)
- Ändern: `tools/tests/test_teile_bauen.py` (Rückbauprobe)

**Schnittstellen:**
- Nutzt: `character_keys.load_table()`, `character_layers.split()`, `teile_bauen.zustaende()`, `teile_bauen.rahmen()`
- Liefert:
  - `teile_bauen.blatt(bilder, kasten, tabelle, ebene)` → `Image` der Breite `w * len(bilder)`
  - `teile_bauen.aufbauen(blaetter, kaesten, atem, zopfweite, beinweite, auge="open", arm=0)` → `Image` 128×128
  - `teile_bauen.ZEICHENFOLGE` → `("zopf", "beine", "hals", "rumpf", "kopf", "auge", "armfern", "arm")` — die Reihenfolge aus `preview_parts.zusammensetzen`, das Auge unmittelbar nach dem Kopf

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

In `tools/tests/test_teile_bauen.py` anfügen:

```python
class TestRueckbau(unittest.TestCase):
    """Aus den Blaettern muss wieder genau das Bild der Vorschau werden.

    Das ist die eigentliche Zusicherung dieses Umbaus: solange der Rueckbau
    stimmt, ist der Weg ueber die Teile nur eine andere Ablage derselben
    Figur -- kein neues Aussehen, das man nachpflegen muesste.
    """

    def test_zusammengesetzt_ergibt_sich_die_vorschau(self):
        from tools import preview_parts as pp
        from tools.character_keys import load_table
        from tools.character_layers import PARTS

        ebenen = fp.split(_laden("sit3_rumpf.png"))
        koepfe = {s: fp.eye_state(ebenen["head"], s)
                  for s in ("open", "half", "closed")}
        tabelle = load_table(os.path.join(os.path.dirname(TEILE),
                                          "key_palette.json"))
        zust = tb.zustaende(ebenen, koepfe)
        kaesten = {n: tb.rahmen(b) for n, b in zust.items()}
        blaetter = {(n, e): tb.blatt(zust[n], kaesten[n], tabelle, e)
                    for n in zust for e in PARTS}

        for atem in (0, 1):
            for zopf in (-2, 0, 2):
                for bein in (-6, 0, 6):
                    for auge in ("open", "half", "closed"):
                        erwartet = pp.zusammensetzen(ebenen, koepfe, atem,
                                                     zopf, bein, auge)
                        gebaut = tb.aufbauen(blaetter, kaesten, atem, zopf,
                                             bein, auge)
                        self.assertEqual(list(erwartet.getdata()),
                                         list(gebaut.getdata()),
                                         "Atem %d Zopf %+d Bein %+d Auge %s"
                                         % (atem, zopf, bein, auge))
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
python3 -m unittest tools.tests.test_teile_bauen.TestRueckbau -v
```

Erwartet: `AttributeError: module 'tools.teile_bauen' has no attribute 'blatt'`.

- [ ] **Schritt 3: Blatt, Aufbau und main schreiben**

In `tools/teile_bauen.py` anfügen:

```python
from tools.character_keys import load_table
from tools.character_layers import PARTS, split as farben_schneiden

OUT = os.path.join(WURZEL, "assets", "art")

## Die Reihenfolge aus preview_parts.zusammensetzen. Der Kopf liegt oben,
## der Hals dahinter -- sonst frisst der Schulterumriss die Kinnzeile.
ZEICHENFOLGE = ("zopf", "beine", "hals", "rumpf", "kopf", "auge",
                "armfern", "arm")

## Welcher Zustand eines Teils bei welchem Bewegungswert gilt.
def _index(name, atem, zopfweite, beinweite, auge="open", arm=0):
    if name == "zopf":
        return ZOPF_WEITEN.index(zopfweite)
    if name in ("kopf", "hals"):
        return ATEM.index(atem)
    if name == "auge":
        return AUGEN.index(auge)
    if name == "beine":
        return BEIN_WEITEN.index(beinweite)
    if name == "arm":
        return arm
    return 0


def blatt(bilder, kasten, tabelle, ebene):
    """Ein Blatt: alle Zustaende eines Teils, nur die Pixel EINER Ebene."""
    x, y, w, h = kasten
    aus = Image.new("RGBA", (w * len(bilder), h), (0, 0, 0, 0))
    for i, bild in enumerate(bilder):
        ausschnitt = bild.crop((x, y, x + w, y + h))
        aus.alpha_composite(farben_schneiden(ausschnitt, tabelle)[ebene],
                            (i * w, 0))
    return aus


def aufbauen(blaetter, kaesten, atem, zopfweite, beinweite, auge="open",
             arm=0):
    """Die Blaetter wieder zu einem 128er Bild -- die Gegenprobe zur Vorschau.

    Der Zopf und der Kopf tragen den Atem als VERSATZ, nicht in den Pixeln:
    im Spiel verschiebt die Szene das Sprite, hier tut es diese Funktion.
    """
    aus = _leer()
    for name in ZEICHENFOLGE:
        x, y, w, h = kaesten[name]
        i = _index(name, atem, zopfweite, beinweite, auge, arm)
        versatz = ((x, y + atem)
                   if name in ("zopf", "kopf", "hals", "auge") else (x, y))
        for ebene in PARTS:
            teil = blaetter[(name, ebene)].crop((i * w, 0, (i + 1) * w, h))
            aus.alpha_composite(teil, versatz)
    return aus


def main():
    ebenen = fp.split(Image.open(os.path.join(TEILE, "sit3_rumpf.png"))
                      .convert("RGBA"))
    koepfe = {s: fp.eye_state(ebenen["head"], s) for s in AUGEN}
    tabelle = load_table(os.path.join(SRC, "key_palette.json"))
    zust = zustaende(ebenen, koepfe)
    geschrieben = 0
    for name, bilder in zust.items():
        kasten = rahmen(bilder)
        print("%-8s Rahmen %dx%d bei %d,%d, %d Zustaende"
              % (name, kasten[2], kasten[3], kasten[0], kasten[1], len(bilder)))
        for ebene in PARTS:
            bild = blatt(bilder, kasten, tabelle, ebene)
            if bild.getbbox() is None:
                continue        # diese Ebene kommt in diesem Teil nicht vor
            pfad = os.path.join(OUT, "char_%s_%s.png" % (name, ebene))
            bild.save(pfad)
            geschrieben += 1
    print("%d Blaetter geschrieben" % geschrieben)


if __name__ == "__main__":
    main()
```

Der Zopf trägt im Blatt seine Scherung, aber nicht den Atem — `aufbauen()` und später die Szene setzen ihn als Versatz. Das spart die Hälfte der Zopf- und Kopfbilder.

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

```
python3 -m unittest tools.tests.test_teile_bauen -v
```

Erwartet: PASS. Schlägt der Rückbau fehl, ist die Meldung eine Bildnummer und ein Zustand — die Abweichung sichtbar machen mit einem Wegwerf-Schnipsel, der beide Bilder nebeneinander speichert, und dem Menschen vorlegen. **Nicht** die Vorschau an den Rückbau anpassen: die Vorschau ist die Wahrheit.

- [ ] **Schritt 5: Die Blätter erzeugen und ansehen**

```
python3 -m tools.teile_bauen
ls -la assets/art/char_*_*.png
```

Die Ausgabe nennt je Teil Rahmen und Anker. Diese Zahlen wandern in Stufe 3 nach `AnglerPose` — sie hier mitschreiben und dem Menschen vorlegen.

- [ ] **Schritt 6: Ganze Suite und Commit**

```bash
bash tools/test.sh
git add tools/teile_bauen.py tools/tests/test_teile_bauen.py assets/art/char_*_*.png
git commit -m "Blaetter je Teil, mit Rueckbauprobe gegen die Vorschau"
```

Die alten `char_skin_*` und so weiter bleiben vorerst liegen — das Spiel lädt sie noch. Sie fallen in Stufe 3.

---

## Danach

**Stufe 3 (Szene und Bewegung)** und **Stufe 4 (Varianten als Tönung)** bekommen einen eigenen Plan. Grund: die Konstanten, die Stufe 3 nach `core/angler_pose.gd` schreibt — Rahmen und Anker je Teil — sind Ausgaben von Aufgabe 4. Sie jetzt in einen Plan zu schreiben hieße, sie zu raten.

Wenn Stufe 2 steht, liegt alles bereit: die Blätter, die Anker, und eine Rückbauprobe, die beweist, dass die Zusammensetzung im Spiel dasselbe Bild ergeben muss wie die Vorschau.
