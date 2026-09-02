# Die Figur aus PixelLab — Umsetzungsplan

> **Für agentische Arbeiter:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte tragen Kästchen (`- [ ]`) zum Abhaken.

**Ziel:** Die Anglerin entsteht als PixelLab-Charakter in Schlüsselfarben, sitzt am Steg, und ihre Ebenen werden per Farbtabelle exakt geschnitten statt aus einem heruntergerechneten Bild geraten.

**Aufbau:** Eine Figur wird stehend als `create_character` (v3, 128 px, Seitenansicht) in weit auseinanderliegenden Farben erzeugt und per `create_character_state` in die Sitzhaltung gebracht. Aus dem erzeugten Bild wird die tatsächliche Palette EINMAL gemessen und als `key_palette.json` eingefroren; danach ist Ebenentrennung reines Nachschlagen. Atemzug und Wurf kommen als v3-Animationen derselben Figur, ihre Abspielreihenfolge wird aus den Bildern gemessen.

**Technik:** Python 3 + Pillow (Werkzeuge unter `tools/`), Godot 4 / GDScript (Spiel und Tests), PixelLab über MCP (nur der Mensch bzw. die Sitzung mit MCP-Zugang kann diese Schritte ausführen — sie sind eigens markiert).

**Spec:** `docs/superpowers/specs/2026-09-02-figur-aus-pixellab-design.md`

## Globale Vorgaben

- **Bildfeld 128×128.** Jedes Figurenblatt ist `128 * FRAMES` breit und 128 hoch.
- **Blickrichtung:** die Drehung, die nach RECHTS schaut. Welche der acht das ist, wird in Aufgabe 2 am Bild bestimmt und in `key_palette.json` unter `"direction"` festgehalten.
- **Die Figur sitzt** am Steg, Beine über die Kante. Entschieden 2026-09-02; deshalb kein `breathing-idle`-Template (das ist eine stehende Skelett-Animation), sondern v3-Animationen.
- **Schlüsselanker** — Zielfarben für den Prompt, nicht die erwartete Ausgabe:

  | Teil | Anker | |
  |---|---|---|
  | `skin` | `#F5CBA0` | helles Pfirsich |
  | `hair` | `#EFE8C8` | hellblond, fast weiß |
  | `shirt` | `#2E6FD0` | kräftiges Blau |
  | `pants` | `#2FA84F` | kräftiges Grün |
  | `boots` | `#C0392B` | kräftiges Rot |
  | `base` | `#1A1A22` | Umriss, Gesichtszüge, alles Übrige |

- **Die echte Zuordnung wird gemessen, nicht angenommen.** Die Anker sind Zielvorgabe; welche Farbe im erzeugten Bild zu welchem Teil gehört, misst Aufgabe 2 einmal und friert es in `assets/source/figure/key_palette.json` ein. Alle späteren Schritte lesen diese Datei.
- **Reihenfolgen werden gemessen, nie übernommen.** Was der Generator liefert, ist ein Bilderstapel. `IDLE_ORDER`, `ROD_ANCHOR` und `ROD_TIP_OFF` entstehen aus den Bildern.
- **Kommentare 1–2 Zeilen, das Warum statt des Was.** Hausregel dieses Projekts, siehe die vorhandenen Werkzeuge.
- **Keine Attributions-Trailer** in Commit-Nachrichten (kein `Co-Authored-By`).
- **Budget:** 1911 Generierungen bis 2026-10-01. Jeder erzeugende Schritt nennt seinen Preis; die Summe dieses Plans liegt bei ~60.
- **Godot-Tests:** `bash tools/test.sh` muss grün sein. Der Läufer ist nur grün, wenn es AUCH keinen Laufzeitfehler gab.
- **Python-Tests:** `python3 -m unittest discover -s tools/tests -t .` (neu in diesem Plan, Aufgabe 1 legt den Ordner an).

## Nicht anfassen

Im Arbeitsverzeichnis liegt unfertige Arbeit von jemand anderem: `tools/import_rod.py` (492 geänderte Zeilen), `tools/pose_split/`, `assets/source/sit_*.png` und die geänderten `char_rod_*.png`. **Nichts davon wird in diesem Plan geändert, verschoben oder gelöscht.** Aufgabe 8 fasst die Rute an — und zwar auf dem Stand, den `tools/import_rod.py` dann hat, ohne die laufende Umarbeitung zurückzudrehen. Commits immer mit ausdrücklicher Dateiliste (`git add <pfad>`), nie `git add -A`.

## Dateien

| Datei | Zuständigkeit |
|---|---|
| `tools/character_keys.py` | NEU — Ankertabelle, Farbe → Körperteil, Palette messen und laden |
| `tools/character_layers.py` | NEU — ein Bild in disjunkte Ebenen schneiden |
| `tools/frame_order.py` | NEU — Umkehrpunkt finden, Pingpong-Reihenfolge bauen |
| `tools/character_blink.py` | NEU — Auge schließen anhand der Schlüsselfarben |
| `tools/import_character.py` | UMBAU — Blätter bauen, Konstanten ausgeben; `head_shift`/`transplant_blink`/`rod_grip` bleiben |
| `tools/tests/` | NEU — Python-Tests zu den vier Werkzeugen |
| `assets/source/figure/` | NEU — was von PixelLab kommt, roh: Drehungen, Animationsbilder, `key_palette.json` |
| `core/angler_pose.gd` | Maße und gemessene Konstanten auf 128 |
| `scenes/fishing/world.gd` | `PIXEL_SCALE`, `CHAR_SIZE`, `CHAR_FEET` |
| `scenes/fishing/angler.tscn` | `hframes` je Ebene |
| `tests/test_character_layers.gd` | NEU — Godot-Test: die Ebenen überlappen sich nirgends |

---

### Aufgabe 1: Farbe → Körperteil

Die Grundlage. Ohne verlässliche Zuordnung ist alles danach wieder Raterei.

**Dateien:**
- Anlegen: `tools/character_keys.py`
- Anlegen: `tools/tests/__init__.py` (leer)
- Test: `tools/tests/test_character_keys.py`

**Schnittstellen:**
- Liefert: `ANCHORS: dict[str, tuple[int,int,int]]`, `assign(rgb) -> str`, `measure(image) -> dict[tuple, str]`, `save_table(path, table)`, `load_table(path) -> dict[tuple, str]`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

```python
# tools/tests/test_character_keys.py
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
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m unittest discover -s tools/tests -t . -v`
Erwartet: FEHLER — `ModuleNotFoundError: No module named 'tools.character_keys'`

- [ ] **Schritt 3: Die kleinste Umsetzung schreiben**

```python
# tools/character_keys.py
"""Welche Farbe zu welchem Koerperteil gehoert.

Die Figur wird absichtlich in weit auseinanderliegenden Farben erzeugt --
darum ist Trennen hier Nachschlagen und nicht Raten. Die Anker sind die
Zielfarben fuer den Prompt; welche Farben das Modell WIRKLICH gemalt hat,
misst measure() einmal am fertigen Bild.
"""
import colorsys
import json

ANCHORS = {
    "skin": (0xF5, 0xCB, 0xA0),
    "hair": (0xEF, 0xE8, 0xC8),
    "shirt": (0x2E, 0x6F, 0xD0),
    "pants": (0x2F, 0xA8, 0x4F),
    "boots": (0xC0, 0x39, 0x2B),
    "base": (0x1A, 0x1A, 0x22),
}

## Unterhalb davon ist eine Farbe Umriss, egal welchen Farbton sie hat.
## Tief angesetzt: der Schatten eines blauen Pullovers ist dunkel, aber
## immer noch Pullover -- ihn dem Umriss zuzuschlagen war der alte Fehler.
DARK = 0.12

def _hsl(rgb):
    r, g, b = (c / 255.0 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h, s, l

def _distance(a, b):
    """Abstand zweier Farben, Farbton am schwersten gewichtet.

    Der Farbton trennt Blau von Gruen von Rot; Saettigung trennt das blasse
    Pfirsich der Haut vom satten Rot der Stiefel. Helligkeit zaehlt am
    wenigsten, damit Licht und Schatten desselben Teils zusammenbleiben.
    """
    ha, sa, la = _hsl(a)
    hb, sb, lb = _hsl(b)
    dh = abs(ha - hb)
    dh = min(dh, 1.0 - dh)          # der Farbkreis schliesst sich
    ## Bei blassen Farben sagt der Farbton wenig -- dort zaehlt er weniger.
    weight = 4.0 * min(sa, sb) + 0.5
    return (dh * weight) ** 2 + (abs(sa - sb) * 0.8) ** 2 + (abs(la - lb) * 0.3) ** 2

def assign(rgb):
    """Das Koerperteil, zu dem diese Farbe gehoert."""
    if _hsl(rgb)[2] < DARK:
        return "base"
    return min((p for p in ANCHORS if p != "base"),
               key=lambda p: _distance(rgb, ANCHORS[p]))

def measure(img):
    """Jede sichtbare Farbe des Bildes einem Teil zuordnen."""
    px = img.load()
    w, h = img.size
    table = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 128 and (r, g, b) not in table:
                table[(r, g, b)] = assign((r, g, b))
    return table

def save_table(path, table):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"%02x%02x%02x" % c: p for c, p in sorted(table.items())},
                  fh, indent=1, sort_keys=True)

def load_table(path):
    with open(path, encoding="utf-8") as fh:
        raw = json.load(fh)
    return {tuple(int(k[i:i + 2], 16) for i in (0, 2, 4)): v
            for k, v in raw.items() if len(k) == 6}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m unittest discover -s tools/tests -t . -v`
Erwartet: BESTANDEN, 5 Tests

Schlägt `test_haut_und_stiefel_werden_nicht_verwechselt` fehl, sind die Gewichte in `_distance` zu justieren — NICHT der Test. Die beiden Farben müssen auseinandergehalten werden, sonst trägt die Figur später Hautstiefel.

- [ ] **Schritt 5: Committen**

```bash
git add tools/character_keys.py tools/tests/__init__.py tools/tests/test_character_keys.py
git commit -m "Farbe zu Koerperteil: Zuordnung ueber gewichteten Farbabstand"
```

---

### Aufgabe 2: Die Schlüsselfigur erzeugen und abnehmen

**Nur mit MCP-Zugang ausführbar.** Kostet Generierungen und braucht die Abnahme durch den Menschen — nicht ohne Rückfrage weiterlaufen.

**Dateien:**
- Anlegen: `assets/source/figure/base_<richtung>.png`, `assets/source/figure/sit_<richtung>.png`
- Anlegen: `assets/source/figure/key_palette.json`
- Anlegen: `tools/check_key_palette.py`

**Schnittstellen:**
- Verbraucht: `tools.character_keys.measure`, `save_table`
- Liefert: `assets/source/figure/key_palette.json` mit den Schlüsseln `"direction"` (z. B. `"east"`), `"colors"` (Farbe → Teil), `"character_id"`, `"state_id"`

- [ ] **Schritt 1: Die Figur erzeugen** (2–9 Generierungen)

```
create_character(
  description="side view of a young woman angler, bright peach skin, very light
    almost white blonde hair in a ponytail, strong blue sweater, strong green
    skirt, strong red rubber boots, near-black outline, flat colors, each
    garment a clearly different hue",
  name="Stillwater Anglerin",
  mode="v3",
  view="side",
  size=128,
  outline="single color black outline",
  detail="medium detail")
```

Dann `get_character(character_id)` abfragen, bis der Status `completed` ist (~1–5 Minuten).

- [ ] **Schritt 2: Die Richtung bestimmen und beide Kandidaten herunterladen**

Die Drehungen `east` und `west` ansehen und die nehmen, die nach RECHTS schaut — die Rute zeigt im Spiel nach rechts. Die gewählte Richtung nach `assets/source/figure/base_<richtung>.png` speichern.

```bash
mkdir -p assets/source/figure
curl -sL "<rotation-url>" -o assets/source/figure/base_east.png
python3 -c "from PIL import Image; i=Image.open('assets/source/figure/base_east.png'); print(i.size, i.mode)"
```
Erwartet: `(128, 128) RGBA`

- [ ] **Schritt 3: Die Sitzhaltung als Zustand erzeugen** (20–40 Generierungen)

```
create_character_state(
  character_id="<id aus Schritt 1>",
  edit_description="sitting on the edge of a wooden dock, legs hanging over
    the edge, side view",
  state_name="Sitzend",
  use_color_palette_from_reference=true)
```

`use_color_palette_from_reference` ist hier nicht Kosmetik, sondern der Kern: es hält die Schlüsselfarben über den Zustand hinweg fest. Bringt der Zustand neue Farben mit, ist die Trennung dahin.

Das gewählte Richtungsbild nach `assets/source/figure/sit_<richtung>.png` herunterladen.

- [ ] **Schritt 4: Den Prüfer schreiben**

```python
# tools/check_key_palette.py
"""Sitzen die sechs Schluesselfarben sauber getrennt im Bild?

Wird VOR allem anderen ausgefuehrt: stimmt die Palette nicht, ist jede
spaetere Ebene falsch, und das faellt sonst erst am fertigen Blatt auf.
"""
import sys
from collections import Counter

from PIL import Image

sys.path.insert(0, ".")
from tools.character_keys import assign

def report(path):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    counts = Counter()
    per_part = {}
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a <= 128:
                continue
            part = assign((r, g, b))
            counts[part] += 1
            per_part.setdefault(part, Counter())[(r, g, b)] += 1
    print("%s  %d Farben, %d sichtbare Pixel"
          % (path, sum(len(c) for c in per_part.values()), sum(counts.values())))
    for part in sorted(per_part):
        tones = per_part[part].most_common()
        print("  %-6s %5d Pixel  %2d Toene  %s"
              % (part, counts[part], len(tones),
                 " ".join("#%02x%02x%02x" % c for c, _ in tones[:6])))
    missing = [p for p in ("skin", "hair", "shirt", "pants", "boots", "base")
               if counts[p] == 0]
    if missing:
        print("FEHLT: %s -- die Figur traegt dieses Teil nicht in seiner Schluesselfarbe"
              % ", ".join(missing))
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(max(report(p) for p in sys.argv[1:]))
```

- [ ] **Schritt 5: Prüfen und abnehmen lassen**

Ausführen: `python3 tools/check_key_palette.py assets/source/figure/base_east.png assets/source/figure/sit_east.png`
Erwartet: sechs Zeilen, keine `FEHLT:`-Zeile, und je Teil eine Handvoll Töne (Licht und Schatten), nicht dreißig.

**Abnahme durch den Menschen — hier anhalten und fragen.** Zwei Dinge zeigen: das Sitzbild selbst und die Ausgabe des Prüfers. Sitzt die Figur richtig, sind die Farben getrennt? Falls nicht: `create_character` mit anderem Beschreibungstext neu (2–9 Generierungen, deshalb ist Neuwürfeln billiger als Nachbessern). Erst nach dem Ja weiter.

- [ ] **Schritt 6: Die Tabelle einfrieren und committen**

```bash
python3 -c "
import json, sys
sys.path.insert(0, '.')
from PIL import Image
from tools.character_keys import measure, save_table
t = measure(Image.open('assets/source/figure/sit_east.png').convert('RGBA'))
save_table('assets/source/figure/key_palette.json', t)
import json
d = json.load(open('assets/source/figure/key_palette.json'))
d['direction'] = 'east'
d['character_id'] = '<id>'
d['state_id'] = '<zustands-id>'
json.dump(d, open('assets/source/figure/key_palette.json','w'), indent=1, sort_keys=True)
print(len(t), 'Farben eingefroren')
"
git add assets/source/figure tools/check_key_palette.py
git commit -m "Schluesselfigur: sitzende Anglerin in 128 Pixeln, Palette gemessen und eingefroren"
```

---

### Aufgabe 3: Ebenen schneiden

**Dateien:**
- Anlegen: `tools/character_layers.py`
- Test: `tools/tests/test_character_layers.py`

**Schnittstellen:**
- Verbraucht: `tools.character_keys.load_table`
- Liefert: `split(img, table) -> dict[str, Image]`, `PARTS: tuple[str, ...]`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

```python
# tools/tests/test_character_layers.py
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
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m unittest discover -s tools/tests -t . -v`
Erwartet: FEHLER — `ModuleNotFoundError: No module named 'tools.character_layers'`

- [ ] **Schritt 3: Die kleinste Umsetzung schreiben**

```python
# tools/character_layers.py
"""Ein Bild in seine Ebenen schneiden.

Jeder sichtbare Pixel landet in genau einer Ebene -- nachgeschlagen in der
gemessenen Palette, nicht abgestimmt. Wer keine Tabelle mitgibt, bekommt
die gerechnete Zuordnung; im Bauweg wird immer die eingefrorene benutzt.
"""
from PIL import Image

from tools.character_keys import assign

PARTS = ("skin", "hair", "shirt", "pants", "boots", "base")

def split(img, table):
    layers = {p: Image.new("RGBA", img.size, (0, 0, 0, 0)) for p in PARTS}
    src = img.load()
    dst = {p: layers[p].load() for p in PARTS}
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = src[x, y]
            if a <= 128:
                continue
            part = (table or {}).get((r, g, b)) or assign((r, g, b))
            dst[part][x, y] = (r, g, b, 255)
    return layers
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m unittest discover -s tools/tests -t . -v`
Erwartet: BESTANDEN, 9 Tests

- [ ] **Schritt 5: An der echten Figur nachmessen**

```bash
python3 -c "
import sys; sys.path.insert(0, '.')
from PIL import Image
from tools.character_keys import load_table
from tools.character_layers import PARTS, split
img = Image.open('assets/source/figure/sit_east.png').convert('RGBA')
layers = split(img, load_table('assets/source/figure/key_palette.json'))
sichtbar = sum(1 for p in img.getdata() if p[3] > 128)
summe = 0
for p in PARTS:
    n = sum(1 for q in layers[p].getdata() if q[3] > 0)
    summe += n
    print('%-6s %5d' % (p, n))
print('Summe %d, Figur %d' % (summe, sichtbar))
assert summe == sichtbar, 'Pixel verloren oder doppelt'
"
```
Erwartet: `Summe` == `Figur`, und `base` deutlich KLEINER als die Summe der übrigen — genau umgekehrt zum alten Weg, wo `base` fast die halbe Figur trug.

- [ ] **Schritt 6: Committen**

```bash
git add tools/character_layers.py tools/tests/test_character_layers.py
git commit -m "Ebenen schneiden: ein Pixel, eine Ebene, nachgeschlagen statt abgestimmt"
```

---

### Aufgabe 4: Die Abspielreihenfolge messen

**Dateien:**
- Anlegen: `tools/frame_order.py`
- Test: `tools/tests/test_frame_order.py`

**Schnittstellen:**
- Liefert: `silhouette_delta(a, b) -> int`, `turning_point(frames) -> int`, `pingpong_order(frames) -> list[int]`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

```python
# tools/tests/test_frame_order.py
import unittest

from PIL import Image

from tools.frame_order import pingpong_order, silhouette_delta, turning_point


def _balken(hoehe):
    """Ein Bild, dessen Umriss sich mit der Hoehe aendert."""
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    px = img.load()
    for y in range(hoehe):
        for x in range(8):
            px[x, y] = (255, 255, 255, 255)
    return img


class TestReihenfolge(unittest.TestCase):
    def test_der_abstand_zaehlt_unterschiedliche_umrisspixel(self):
        self.assertEqual(silhouette_delta(_balken(2), _balken(2)), 0)
        self.assertEqual(silhouette_delta(_balken(2), _balken(3)), 8)

    def test_umkehrpunkt_einer_geschlossenen_schleife(self):
        ## Eine Template-Animation kehrt zum Anfang zurueck. Der Umkehrpunkt
        ## ist das Bild, das am weitesten von Bild 0 entfernt ist.
        frames = [_balken(h) for h in (1, 2, 3, 4, 5, 4, 3, 2)]
        self.assertEqual(turning_point(frames), 4)

    def test_geschlossene_schleife_wird_hinter_dem_umkehrpunkt_gekappt(self):
        ## Ohne Kappen liefe die Schwingung im Pingpong zweimal -- hin,
        ## zurueck, nochmal zurueck, nochmal hin.
        frames = [_balken(h) for h in (1, 2, 3, 4, 5, 4, 3, 2)]
        self.assertEqual(pingpong_order(frames), [0, 1, 2, 3, 4, 3, 2, 1])

    def test_offene_schwingung_wird_gespiegelt(self):
        frames = [_balken(h) for h in (1, 2, 3, 4, 5)]
        self.assertEqual(pingpong_order(frames), [0, 1, 2, 3, 4, 3, 2, 1])

    def test_kein_schritt_springt_um_mehr_als_ein_bild(self):
        ## Dieselbe Zusicherung, die der Godot-Test stellt.
        frames = [_balken(h) for h in (1, 2, 3, 4, 5, 4, 3, 2)]
        order = pingpong_order(frames)
        for i in range(len(order)):
            a, b = order[i], order[(i + 1) % len(order)]
            self.assertEqual(abs(a - b), 1, "Sprung von %d auf %d" % (a, b))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m unittest discover -s tools/tests -t . -v`
Erwartet: FEHLER — `ModuleNotFoundError: No module named 'tools.frame_order'`

- [ ] **Schritt 3: Die kleinste Umsetzung schreiben**

```python
# tools/frame_order.py
"""Aus einem Bilderstapel eine Abspielreihenfolge machen.

Was der Generator liefert, ist ein Stapel. Der Ruhelauf laeuft hier als
Pingpong -- und eine erzeugte Animation ist meist schon eine geschlossene
Schleife. Wuerde man die ungekappt spiegeln, liefe die Schwingung zweimal
und die Figur stuende an beiden Enden kurz still.
"""

def silhouette_delta(a, b):
    """Wie viele Pixel in genau einem der beiden Bilder sichtbar sind."""
    pa, pb = a.load(), b.load()
    n = 0
    for y in range(a.size[1]):
        for x in range(a.size[0]):
            if (pa[x, y][3] > 0) != (pb[x, y][3] > 0):
                n += 1
    return n

def turning_point(frames):
    """Das Bild, das am weitesten von Bild 0 entfernt ist."""
    return max(range(len(frames)), key=lambda i: silhouette_delta(frames[0], frames[i]))

def pingpong_order(frames):
    """Hin bis zum Umkehrpunkt und denselben Weg zurueck."""
    k = turning_point(frames)
    return list(range(k + 1)) + list(range(k - 1, 0, -1))
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m unittest discover -s tools/tests -t . -v`
Erwartet: BESTANDEN, 14 Tests

- [ ] **Schritt 5: Committen**

```bash
git add tools/frame_order.py tools/tests/test_frame_order.py
git commit -m "Abspielreihenfolge: Umkehrpunkt messen statt die Schleife zu spiegeln"
```

---

### Aufgabe 5: Atemzug und Wurf erzeugen

**Nur mit MCP-Zugang ausführbar.** ~6 Generierungen.

**Dateien:**
- Anlegen: `assets/source/figure/idle_*.png`, `assets/source/figure/cast_*.png`

- [ ] **Schritt 1: Den Atemzug erzeugen** (~3 Generierungen)

Die Sitzfigur ist ein eigener Charakter (eigene `character_id` aus Aufgabe 2, Schritt 3). Sie wird animiert, nicht die stehende:

```
animate_character(
  character_id="<zustands-id>",
  mode="v3",
  action_description="breathing calmly while sitting, shoulders rising and falling",
  animation_name="sit_idle",
  directions=["<richtung aus key_palette.json>"],
  frame_count=8,
  keep_first_frame=true)
```

Kein Template: `breathing-idle` ist eine stehende Skelett-Animation und passt auf eine sitzende Figur nicht. Preis bei 128 px: `ceil(128*128*9/65536)` = 3 pro Richtung, und wir brauchen eine.

- [ ] **Schritt 2: Den Wurf erzeugen** (~3 Generierungen)

```
animate_character(
  character_id="<zustands-id>",
  mode="v3",
  action_description="casting a fishing rod forward while sitting",
  animation_name="sit_cast",
  directions=["<richtung>"],
  frame_count=6,
  keep_first_frame=false)
```

- [ ] **Schritt 3: Bilder herunterladen und zählen**

```bash
# je Bild eine Datei, durchnummeriert in Reihenfolge der Ausgabe
curl -sL "<frame-url>" -o assets/source/figure/idle_0.png   # usw.
python3 -c "
import glob
from PIL import Image
for muster in ('idle', 'cast'):
    dateien = sorted(glob.glob('assets/source/figure/%s_*.png' % muster))
    print(muster, len(dateien), {Image.open(f).size for f in dateien})
"
```
Erwartet: `idle 9 {(128, 128)}` und `cast 6 {(128, 128)}` — weichen die Zahlen ab, gilt die gemessene Zahl, nicht die geplante. Sie fließt in Aufgabe 7 in die Konstanten.

- [ ] **Schritt 4: Die Reihenfolge messen**

```bash
python3 -c "
import glob, sys; sys.path.insert(0, '.')
from PIL import Image
from tools.frame_order import pingpong_order, silhouette_delta
f = [Image.open(p).convert('RGBA') for p in sorted(glob.glob('assets/source/figure/idle_*.png'))]
order = pingpong_order(f)
print('IDLE_ORDER =', order)
print('Schleife geschlossen:', silhouette_delta(f[0], f[-1]) < silhouette_delta(f[0], f[len(f)//2]))
"
```
Die ausgegebene Liste wird in Aufgabe 7 nach `AnglerPose.IDLE_ORDER` übernommen — abgeschrieben, nicht neu erfunden.

- [ ] **Schritt 5: Abnehmen lassen und committen**

**Hier anhalten:** dem Menschen den Atemzug als Bilderreihe zeigen. Sieht die Bewegung nach Atmen aus oder nach Zucken? Ist sie schlecht, erst `delete_animation`, dann mit anderem `action_description` neu (~3 Generierungen).

```bash
git add assets/source/figure
git commit -m "Atemzug und Wurf der sitzenden Anglerin, Reihenfolge gemessen"
```

---

### Aufgabe 6: Blinzeln aus den Schlüsselfarben

Kostet keine Generierung: das Auge ist die dunkle Insel im Hautbereich, und seit die Haut eine bekannte Schlüsselfarbe hat, ist sie ohne Raten zu finden.

**Dateien:**
- Anlegen: `tools/character_blink.py`
- Test: `tools/tests/test_character_blink.py`

**Schnittstellen:**
- Verbraucht: `tools.character_layers.split`
- Liefert: `close_eye(img, table) -> Image`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

```python
# tools/tests/test_character_blink.py
import unittest

from PIL import Image

from tools.character_blink import close_eye

HAUT = (245, 203, 160, 255)
DUNKEL = (26, 26, 34, 255)


def _gesicht():
    """Ein Hautfeld mit einem dunklen Auge darin und einem Umriss aussen."""
    img = Image.new("RGBA", (9, 9), (0, 0, 0, 0))
    px = img.load()
    for y in range(1, 8):
        for x in range(1, 8):
            px[x, y] = HAUT
    for i in range(9):
        px[i, 0] = DUNKEL
        px[i, 8] = DUNKEL
    for x, y in ((4, 4), (5, 4), (4, 5), (5, 5)):
        px[x, y] = DUNKEL
    return img


class TestBlinzeln(unittest.TestCase):
    def test_das_auge_verschwindet(self):
        zu = close_eye(_gesicht(), None)
        px = zu.load()
        self.assertNotEqual(px[4, 4], DUNKEL)
        self.assertNotEqual(px[5, 5], DUNKEL)

    def test_ein_wimpernstrich_bleibt_stehen(self):
        ## Ohne Strich sieht es aus, als fehle das Auge.
        zu = close_eye(_gesicht(), None)
        px = zu.load()
        dunkel_im_gesicht = [(x, y) for y in range(1, 8) for x in range(1, 8)
                             if px[x, y][:3] == DUNKEL[:3]]
        self.assertTrue(dunkel_im_gesicht, "kein Wimpernstrich")
        self.assertLessEqual(len(dunkel_im_gesicht), 2,
                             "der Strich ist dicker als eine Zeile: %s" % dunkel_im_gesicht)

    def test_der_umriss_bleibt_unangetastet(self):
        ## Der Rand ist genauso dunkel wie das Auge -- und darf nicht mit
        ## zugemalt werden. Genau daran ist die alte Suche gescheitert.
        zu = close_eye(_gesicht(), None)
        px = zu.load()
        for i in range(9):
            self.assertEqual(px[i, 0], DUNKEL)
            self.assertEqual(px[i, 8], DUNKEL)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m unittest discover -s tools/tests -t . -v`
Erwartet: FEHLER — `ModuleNotFoundError: No module named 'tools.character_blink'`

- [ ] **Schritt 3: Die kleinste Umsetzung schreiben**

```python
# tools/character_blink.py
"""Auge zu.

Das Auge ist die dunkle Insel INNERHALB der Haut -- der Umriss ist genauso
dunkel, liegt aber am Rand. Seit die Haut eine bekannte Schluesselfarbe hat,
ist das ohne Raten zu unterscheiden: gesucht werden dunkle Pixel, die
ringsum von Haut umgeben sind.
"""
from tools.character_layers import split

def _umgeben_von_haut(haut_px, x, y, w, h):
    ringsum = 0
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            bx, by = x + dx, y + dy
            if 0 <= bx < w and 0 <= by < h and haut_px[bx, by][3] > 0:
                ringsum += 1
    return ringsum >= 8

def close_eye(img, table):
    layers = split(img, table)
    haut = layers["skin"].load()
    dunkel = layers["base"].load()
    w, h = img.size
    insel = [(x, y) for y in range(h) for x in range(w)
             if dunkel[x, y][3] > 0 and _umgeben_von_haut(haut, x, y, w, h)]
    if not insel:
        return img.copy()

    ## Der haeufigste Hautton ringsum, nicht ein gewaehlter: das Gesicht ist
    ## schattiert, und ein fester Ton saehe wie ein Fleck aus.
    from collections import Counter
    toene = Counter()
    for x, y in insel:
        for dy in (-2, -1, 1, 2):
            if 0 <= y + dy < h and haut[x, y + dy][3] > 0:
                toene[haut[x, y + dy][:3]] += 1
    ton = toene.most_common(1)[0][0]

    out = img.copy()
    px = out.load()
    for x, y in insel:
        px[x, y] = ton + (255,)
    ## Der Wimpernstrich liegt auf der Mittelzeile der Insel.
    strich_y = sum(p[1] for p in insel) // len(insel)
    farbe = dunkel[insel[0][0], insel[0][1]]
    for x in sorted({p[0] for p in insel}):
        px[x, strich_y] = farbe
    return out
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m unittest discover -s tools/tests -t . -v`
Erwartet: BESTANDEN, 17 Tests

- [ ] **Schritt 5: Am echten Bild ansehen**

```bash
python3 -c "
import sys; sys.path.insert(0, '.')
from PIL import Image
from tools.character_keys import load_table
from tools.character_blink import close_eye
img = Image.open('assets/source/figure/idle_0.png').convert('RGBA')
zu = close_eye(img, load_table('assets/source/figure/key_palette.json'))
anders = sum(1 for a, b in zip(img.getdata(), zu.getdata()) if a != b)
print('%d Pixel geaendert' % anders)
zu.resize((512, 512), Image.NEAREST).save('/tmp/blink.png')
"
```
Erwartet: eine zweistellige Zahl. Sind es hunderte, hat die Suche mehr als das Auge erwischt — dann den Radius in `_umgeben_von_haut` enger ziehen.

- [ ] **Schritt 6: Committen**

```bash
git add tools/character_blink.py tools/tests/test_character_blink.py
git commit -m "Blinzeln ohne Generierung: das Auge ist die dunkle Insel in der Haut"
```

---

### Aufgabe 7: Die Blätter bauen

**Dateien:**
- Umbauen: `tools/import_character.py`

**Schnittstellen:**
- Verbraucht: `character_keys.load_table`, `character_layers.split`, `character_blink.close_eye`, `frame_order.pingpong_order`, sowie `head_shift`/`transplant_blink`/`rod_grip` aus der bisherigen Datei
- Liefert: `assets/art/char_{skin,hair,shirt,pants,base}_*.png` mit `128 * FRAMES` × 128, plus die Konstanten auf der Standardausgabe

- [ ] **Schritt 1: Die alten Wege ausbauen, die neuen einhängen**

Aus `tools/import_character.py` ersatzlos entfernen: `prepare`, `prepare_image`, `measure`, `idle_frames`, `shared_palette`, `apply_palette`, `classify`, `is_skin`, `blink`, `tint`, `SKIN_TONES`/`SHIRT_TONES`/`PANTS_TONES` als Weg zur Ebene.

Behalten: `head_shift`, `transplant_blink`, `blink_series`, `rod_grip`, `lum`, `hexc`.

Eine Stelle darin muss trotzdem angefasst werden: `EYE_BOX = (114, 60, 136, 84)` sind Koordinaten im 256er Feld einer STEHENDEN Figur. `head_shift` richtet sein Suchfenster daran aus, `blink_series` schneidet daran seinen Flicken. Beides zeigt sonst auf die Wange oder ins Leere. Neu messen statt halbieren — die Figur sitzt jetzt, der Kopf steht woanders:

```python
def _eye_box(img, table):
    """Wo das Auge liegt -- an der Insel gemessen, die close_eye findet."""
    zu = close_eye(img, table)
    px, qx = img.load(), zu.load()
    anders = [(x, y) for y in range(FRAME) for x in range(FRAME)
              if px[x, y] != qx[x, y]]
    xs = [p[0] for p in anders]
    ys = [p[1] for p in anders]
    return (min(xs) - 3, min(ys) - 3, max(xs) + 4, max(ys) + 4)
```

`EYE_BOX` wird damit beim Bauen gesetzt (`character.EYE_BOX = _eye_box(idles[0], table)`), nicht mehr als feste Zahl gepflegt.

Neuer Kopf und neues `main()`:

```python
"""Baut die Figurenblaetter aus dem, was PixelLab geliefert hat.

Die Bilder liegen fertig im 128er Feld unter assets/source/figure/ -- kein
Freistellen, kein Herunterrechnen, kein Quantisieren. Getrennt wird ueber
die eingefrorene Palette (key_palette.json), nicht ueber Zonen und
Mehrheiten: der alte Weg schob fast die halbe Figur in eine Ebene, die
niemand umfaerben darf.

Als Modul aufrufen, sonst findet es die Schwesterdateien unter tools/ nicht:

    python3 -m tools.import_character
"""
import glob
import os

from PIL import Image

from tools.character_blink import close_eye
from tools.character_keys import load_table
from tools.character_layers import PARTS, split
from tools.frame_order import pingpong_order

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source", "figure")
OUT = os.path.join(ROOT, "assets", "art")

FRAME = 128

## Wie viele Varianten je Kategorie das Spiel erwartet (data/cosmetics/).
## Die Zahlen bleiben, damit gespeicherte Staende weiter passen; die Blaetter
## dahinter sind jetzt Faerbungen EINER Ebene.
SKIN_TONES = ["e8be9a", "c68c63", "8d5a3c", "f6ddc4", "5c3826",
              "6f9455", "9fc7d6", "8f8a9c", "f4f6f7"]
SHIRT_TONES = ["3f6fb4", "b4523f", "4a9455", "c8913f", "6b4470",
               "6f7a75", "6b4326", "8f6a2c", "39537f"]
PANTS_TONES = ["6f7a75", "4a3626", "8f6a2c", "6b4470", "39537f", "b4523f"]
HAIR_STYLES = 5

def _load(muster):
    dateien = sorted(glob.glob(os.path.join(SRC, muster)))
    bilder = [Image.open(p).convert("RGBA") for p in dateien]
    for b in bilder:
        if b.size != (FRAME, FRAME):
            raise SystemExit("%s liegt nicht im %der Feld: %s" % (muster, FRAME, b.size))
    return bilder

def recolor(img, target):
    """Eine Ebene einfaerben und dabei ihre Schattierung behalten."""
    px = img.load()
    out = img.copy()
    q = out.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if not a:
                continue
            f = 0.55 + 0.9 * (lum((r, g, b)) / 255.0)
            q[x, y] = (min(255, int(target[0] * f)), min(255, int(target[1] * f)),
                       min(255, int(target[2] * f)), a)
    return out
```

- [ ] **Schritt 2: `main()` schreiben**

```python
def sheet(frames, part, table, target=None):
    out = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for i, img in enumerate(frames):
        ebene = split(img, table)[part]
        out.alpha_composite(recolor(ebene, target) if target else ebene, (i * FRAME, 0))
    return out

def main():
    table = load_table(os.path.join(SRC, "key_palette.json"))
    idles = _load("idle_*.png")
    casts = _load("cast_*.png")
    ## Zu JEDEM Ruhebild ein Blinzelbild: mit nur einem spraenge der Kopf
    ## fuer den Augenblick des Blinzelns auf die Haltung von Bild 0 zurueck.
    blinks = blink_series(idles, close_eye(idles[0], table))
    frames = idles + blinks + casts

    ## Stiefel wandern unten in die Hosenebene -- das Spiel kennt keine
    ## eigene Kategorie dafuer. Getrennt sind sie trotzdem; eine eigene
    ## Kategorie waere jetzt eine Zeile.
    written = 0
    for i, tone in enumerate(SKIN_TONES):
        sheet(frames, "skin", table, hexc(tone) if i else None).save(
            os.path.join(OUT, "char_skin_%d.png" % i)); written += 1
    for i in range(HAIR_STYLES):
        sheet(frames, "hair", table).save(
            os.path.join(OUT, "char_hair_%d.png" % i)); written += 1
    for i, tone in enumerate(SHIRT_TONES):
        sheet(frames, "shirt", table, hexc(tone) if i else None).save(
            os.path.join(OUT, "char_shirt_%d.png" % i)); written += 1
    for i, tone in enumerate(PANTS_TONES):
        hose = sheet(frames, "pants", table, hexc(tone) if i else None)
        hose.alpha_composite(sheet(frames, "boots", table))
        hose.save(os.path.join(OUT, "char_pants_%d.png" % i)); written += 1
    sheet(frames, "base", table).save(os.path.join(OUT, "char_base_0.png"))
    written += 1

    print("%d Blaetter, %d Bilder je Blatt" % (written, len(frames)))
    print("FRAMES = %d, IDLE_FRAMES = %d, BLINK_START = %d, CAST_START = %d"
          % (len(frames), len(idles), len(idles), len(idles) * 2))
    print("IDLE_ORDER = %s" % pingpong_order(idles))
    print("ROD_ANCHOR:\n\t%s," % ", ".join(
        "Vector2i(%d, %d)" % rod_grip(f) for f in frames))

if __name__ == "__main__":
    main()
```

`rod_grip` misst die Faust in festen Zeilen (110–150 im 256er Feld) — diese Zahlen müssen halbiert werden, und weil die Figur jetzt sitzt, gehören sie ohnehin neu gemessen. Vorgehen: die Zeilen aus dem Hautblatt ablesen, in denen die Hand liegt, und die Konstanten in `rod_grip` darauf setzen.

- [ ] **Schritt 3: Bauen lassen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 -m tools.import_character`
Erwartet: `31 Blaetter, 24 Bilder je Blatt` (die genauen Zahlen ergeben sich aus Aufgabe 5) und darunter die Konstanten. Die Ausgabe aufheben — Aufgabe 8 schreibt sie ab.

- [ ] **Schritt 4: Nachsehen**

```bash
python3 -c "
from PIL import Image
i = Image.open('assets/art/char_skin_0.png')
print(i.size, i.size[0] // 128, 'Bilder')
"
```
Erwartet: Breite = 128 × Bilderzahl, Höhe 128.

- [ ] **Schritt 5: Committen**

```bash
git add tools/import_character.py assets/art/char_skin_*.png assets/art/char_hair_*.png \
        assets/art/char_shirt_*.png assets/art/char_pants_*.png assets/art/char_base_0.png
git commit -m "Figurenblaetter aus der Schluesselfigur, 128 Pixel"
```

---

### Aufgabe 8: Das Spiel auf 128 umstellen

**Dateien:**
- Ändern: `core/angler_pose.gd` (`FRAME_SIZE`, `FRAMES`, `IDLE_FRAMES`, `BLINK_START`, `CAST_START`, `IDLE_ORDER`, `ROD_ANCHOR`, `ROD_TIP_OFF`, `ROD_BEND`, `ROD_FRAME`, `ROD_FRAME_SIZE`, `ROD_GRIP`)
- Ändern: `scenes/fishing/world.gd:29` (`PIXEL_SCALE`), `CHAR_SIZE`, `CHAR_FEET`
- Ändern: `scenes/fishing/angler.tscn` (`hframes` je Sprite)
- Anlegen: `tests/test_character_layers.gd`

- [ ] **Schritt 1: Den fehlschlagenden Godot-Test schreiben**

```gdscript
# tests/test_character_layers.gd
extends TestCase

const ART_DIR := "res://assets/art"

## Ein Pixel gehoert genau EINER Ebene. Vorher lag derselbe Pixel in
## mehreren: der Rock steckte gleichzeitig in "hair" und in "base", weil die
## Zuordnung ueber Bildzeilen abgestimmt statt nachgeschlagen wurde.
func test_die_ebenen_ueberlappen_sich_nirgends() -> void:
	var namen := ["char_skin_0.png", "char_shirt_0.png", "char_pants_0.png",
		"char_hair_0.png", "char_base_0.png"]
	var bilder: Array[Image] = []
	for n in namen:
		var tex := TextureLoader.load_texture("%s/%s" % [ART_DIR, n])
		assert_true(tex != null, "%s nicht ladbar" % n)
		if tex == null:
			return
		bilder.append(tex.get_image())
	var doppelt := 0
	for y in bilder[0].get_height():
		for x in bilder[0].get_width():
			var treffer := 0
			for img in bilder:
				if img.get_pixel(x, y).a > 0.0:
					treffer += 1
			if treffer > 1:
				doppelt += 1
	assert_eq(doppelt, 0, "%d Pixel liegen in mehr als einer Ebene" % doppelt)

## Die Grundebene traegt Umriss und Gesichtszuege -- nicht die halbe Figur.
## Gemessen am alten Weg: 98.199 von rund 224.000 Pixeln lagen dort.
func test_die_grundebene_ist_nicht_die_halbe_figur() -> void:
	var gesamt := 0
	var basis := 0
	for n in ["char_skin_0.png", "char_shirt_0.png", "char_pants_0.png",
			"char_hair_0.png", "char_base_0.png"]:
		var tex := TextureLoader.load_texture("%s/%s" % [ART_DIR, n])
		if tex == null:
			continue
		var img := tex.get_image()
		var sichtbar := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					sichtbar += 1
		gesamt += sichtbar
		if n == "char_base_0.png":
			basis = sichtbar
	assert_true(gesamt > 0, "keine Figurenpixel gefunden")
	assert_true(float(basis) / float(gesamt) < 0.35,
		"die Grundebene traegt %.0f%% der Figur" % (100.0 * float(basis) / float(gesamt)))
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && bash tools/test.sh 2>&1 | tail -30`
Erwartet: ROT. Die Größenprüfung in `test_sprite_assets.gd` schlägt zuerst fehl, weil `AnglerPose.FRAME_SIZE` noch 256 sagt, die Blätter aber 128 sind.

- [ ] **Schritt 3: Die Konstanten setzen**

In `core/angler_pose.gd` die Werte aus der Ausgabe von Aufgabe 7, Schritt 3 eintragen — abschreiben, nicht umrechnen:

```gdscript
const FRAME_SIZE: int = 128
const FRAMES: int = <aus der Ausgabe>
const IDLE_FRAMES: int = <aus der Ausgabe>
const BLINK_START: int = <aus der Ausgabe>
const CAST_START: int = <aus der Ausgabe>
const IDLE_ORDER: Array[int] = [<aus der Ausgabe>]
const ROD_ANCHOR: Array[Vector2i] = [<aus der Ausgabe>]
const ROD_FRAME_SIZE: int = 160
const ROD_GRIP: Vector2i = Vector2i(80, 80)
```

Den Kommentar über `FRAME_SIZE` mitziehen: er begründet noch die 256 und wäre sonst eine Lüge im Quelltext. Neue Begründung: 128 ist PixelLabs Arbeitsgröße und kostet bei Animationen ein Viertel dessen, was 256 kosten würde; bei Vergrößerung 2 steht die Figur genauso groß da.

`ROD_TIP_OFF`, `ROD_BEND` und `ROD_FRAME` haben je einen Eintrag pro Bild und müssen auf die neue Bilderzahl gebracht werden. Die Rute selbst wird in Aufgabe 9 neu gebaut; bis dahin reichen halbierte Werte, damit die Suite läuft.

In `scenes/fishing/world.gd`:

```gdscript
const PIXEL_SCALE := 2.16   # war 1.08 bei 256er Feld: gleiche Groesse auf dem Schirm
const CHAR_SIZE := 128.0
const CHAR_FEET := <Zeile der Stiefelsohle im 128er Feld, am Bild gemessen>
```

In `scenes/fishing/angler.tscn` jedes `hframes = 23` auf die neue Bilderzahl, beim Rod-Sprite auf die Zahl der Rutenbilder.

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && bash tools/test.sh 2>&1 | tail -30`
Erwartet: `Alles gruen, keine Laufzeitfehler.`

Bleibt `test_the_grip_sits_in_the_hand_in_every_frame` rot, stimmen die Griffzahlen in `rod_grip` nicht — die Faustzeilen aus Aufgabe 7, Schritt 2 nachmessen, nicht den Test entschärfen.

- [ ] **Schritt 5: Committen**

```bash
git add core/angler_pose.gd scenes/fishing/world.gd scenes/fishing/angler.tscn \
        tests/test_character_layers.gd
git commit -m "Spiel auf das 128er Feld: Masse und gemessene Konstanten"
```

---

### Aufgabe 9: Die Rute nachziehen und im Spiel ansehen

**Dateien:**
- Ändern: `assets/art/char_rod_*.png` (neu gebaut auf 160er Feld)
- Ändern: `core/angler_pose.gd` (`ROD_TIP_OFF`, `ROD_BEND`, `ROD_FRAME` endgültig)

Achtung: `tools/import_rod.py` trägt unfertige Arbeit von jemand anderem. Auf dem Stand aufsetzen, der dann dort liegt, und die laufende Umarbeitung nicht zurückdrehen.

- [ ] **Schritt 1: Die Rute im 160er Feld bauen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && python3 tools/import_rod.py` (Aufrufform aus dem Kopf der Datei ablesen — sie hat sich gerade geändert)
Erwartet: `assets/art/char_rod_0.png` mit `160 * ROD_FRAMES` × 160.

- [ ] **Schritt 2: Anker und Winkel neu messen**

Die sitzende Figur hält die Rute anders als die stehende: der Unterarm liegt tiefer, und die alten Winkel zeigen ins Leere. `ROD_TIP_OFF` je Bild aus der Handhaltung ableiten, `ROD_BEND` zunächst auf den bisherigen Ruhewert `3.0` für alle Ruhebilder setzen und für die Wurfbilder am Bild anpassen.

- [ ] **Schritt 3: Test laufen lassen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && bash tools/test.sh 2>&1 | tail -30`
Erwartet: `Alles gruen`. Diese vier Tests prüfen die Rute und müssen ohne Nachhelfen bestehen: `test_the_rod_tip_is_where_the_pixels_are_in_every_frame`, `test_the_rod_is_an_unbroken_line`, `test_the_rod_keeps_its_length_in_every_pose`, `test_the_rod_fits_inside_its_own_frame`.

- [ ] **Schritt 4: Die Figur im Spiel ansehen**

**Hier anhalten und dem Menschen zeigen.** Sitzt sie auf dem Steg statt daneben oder darin? Atmet sie? Geht die Schnur von der Rutenspitze aus? Das beantwortet keine Testsuite.

- [ ] **Schritt 5: Committen**

```bash
git add assets/art/char_rod_*.png core/angler_pose.gd
git commit -m "Rute fuer die sitzende Anglerin im 160er Feld"
```

---

### Aufgabe 10: Aufräumen

Erst wenn alles davor grün ist und die Figur im Spiel steht.

- [ ] **Schritt 1: Die alten Vorlagen wegräumen**

```bash
git rm assets/source/angler_idle_frames.png assets/source/angler_blink.png \
       assets/source/angler_idle.png assets/source/angler_cast_*.png
```

`assets/source/sit_*.png`, `assets/source/rod_*.png` und `tools/pose_split/` bleiben — das ist fremde, unfertige Arbeit.

- [ ] **Schritt 2: Test laufen lassen**

Ausführen: `cd /data/data/com.termux/files/home/stillwater && bash tools/test.sh 2>&1 | tail -20`
Erwartet: `Alles gruen, keine Laufzeitfehler.`

- [ ] **Schritt 3: Committen**

```bash
git commit -m "Die gemalten Vorlagen der alten Figur entfernen"
```

---

## Was dieser Plan nicht macht

- **Outfits als Zustände.** Das ist der zweite Teil und bekommt einen eigenen Plan: `create_character_state` je Kleidungsstück, ein Blatt je Outfit, dazu die Umstellung der Kosmetik-Kategorien von „Farbe je Ebene" auf „Outfit je Blatt" samt Wanderung gespeicherter Stände. Erst wenn die Maschinerie hier bewiesen ist.
- **Echte Frisuren.** `char_hair_0` bis `char_hair_4` bleiben fünf gleiche Blätter — genau wie heute. Das ist keine Verschlechterung, nur eine ungelöste Sache, die ungelöst bleibt; Frisuren als Zustände gehören in denselben zweiten Plan.
- **Hüte.** `char_hat_*` bleibt unangetastet und muss lediglich auf das 128er Feld passen. Passt es nicht, ist das ein Fund für Aufgabe 8 — dann werden die Hutblätter mit `tools/import_prop.py` neu gebaut.
