# Die Anglerin im Spiel aus Teilen — Umsetzungsplan (Stufe 3)

> **Für agentische Bearbeiter:** ERFORDERLICHE UNTERFÄHIGKEIT: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, Aufgabe für Aufgabe. Die Schritte tragen Kästchen (`- [ ]`).

**Ziel:** Das Spiel setzt die Anglerin zur Laufzeit aus den Teileblättern zusammen, statt eine von 24 gebackenen Posen zu zeigen — damit die Weite des Beinschwungs je Schwung neu gezogen werden kann.

**Aufbau:** `tools/teile_bauen.py` erzeugt die Blätter und schreibt die gemessene Geometrie als GDScript-Konstanten nach `core/angler_parts.gd`. `scenes/fishing/angler.tscn` bekommt je Teil eine Gruppe mit je Kosmetikebene einem Sprite. `scenes/fishing/angler.gd` rechnet Atem, Zopf, Beine, Blinzeln und Wurf aus der Uhr und setzt Bildnummern und Versätze. Die alten `char_*`-Reihen fallen weg.

**Werkzeuge:** Godot 4.7.2, GDScript; Python 3 mit Pillow 12.3.0 und numpy 2.4.4.

**Spec:** `docs/superpowers/specs/2026-09-07-figur-aus-teilen-im-spiel-design.md`

## Weltweite Vorgaben

- Godot **4.7.2**, Python-Bildwerkzeuge mit **Pillow 12.3.0** und **numpy 2.4.4** (in `.github/workflows/test.yml` festgenagelt).
- **`bash tools/test.sh` läuft vollständig durch, bevor committet oder gepusht wird.** Nicht „unbetroffen" annehmen — das ist hier schon zweimal schiefgegangen.
- Zeichenreihenfolge der Teile, aus `preview_parts.zusammensetzen` übernommen: **Zopf, Beine, Hals, Rumpf, Kopf, Auge, Arm fern, Rute, Arm nah, Hut.** Der Kopf liegt über dem Rumpf; der Hals dahinter, weil er in den Kragen hineingeht. Der Hut liegt **hinter der Rute und vor dem Arm** — er ist deshalb kein Kind der Kopfgruppe, sondern folgt ihr rechnerisch.
- Reihenfolge innerhalb eines Teils: **Haut, Hose, Pullover, Haar, Grundebene.** Die Grundebene liegt über der Kleidung, weil sie Umriss, Auge und Kragen trägt.
- **Gemessen, nicht getippt.** Rahmen, Anker, Zustandszahlen und Zustandslisten kommen aus dem Bauwerkzeug in eine erzeugte Datei. Keine dieser Zahlen wird von Hand in GDScript geschrieben.
- Kommentare auf Deutsch, ohne Umlaute im Code (der Bestand macht es so). Commit-Nachrichten ohne Zuschreibungszeilen.
- Hüte und Frisuren bleiben, was sie sind (Spec, „Ausdrücklich später"). Dieser Umbau ändert nur, **woran** der Hut hängt.

---

## Ausgangslage

Stufe 2 ist fertig und liegt auf dem Zweig `figur-aus-teilen`:

- `assets/art/teil_<teil>_<ebene>.png` — 23 Blätter, je Teil auf seinen Rahmen zugeschnitten.
- `assets/art/teile.json` — Rahmen, Anker, Zustandszahl, Ebenen je Teil.
- `tools/teile_bauen.py` — erzeugt beides. `aufbauen()` setzt sie testweise wieder zusammen; `tools/tests/test_teile_bauen.py` vergleicht das Ergebnis Pixel für Pixel mit `preview_parts.zusammensetzen`.
- Das Spiel lädt davon **nichts**. `angler.gd` zeigt weiter `char_skin_0.png` und Geschwister mit 24 Bildern.

### Zwei Funde, die diesen Plan prägen

**1. Das Zopfblatt ist unvollständig.** `teile_bauen.zopf_zustaende()` sammelt die Tripel `(atem, zopf, kopf_seit)` aus **einem** Durchlauf von `wurf_lauf.ablauf()` — und in diesem Durchlauf fiel der Wurf zufällig auf bestimmte Atemphasen. Im Spiel kann der Wurf bei jeder Phase beginnen. Nachgerechnet über alle 32 Atemschritte × (Ruhe plus zehn Wurfbilder):

```
gebacken : 14 Tripel
erreichbar: 28 Tripel
es fehlen : 14
```

Alle 14 gebackenen liegen innerhalb der 28 — es ist reine Erweiterung, kein Widerspruch. Ohne die Ergänzung findet die Szene bei jedem zweiten Wurf keinen Zustand. Das ist ein Sperrgrund und wird in Aufgabe 1 behoben.

**2. Kopf und Hals tragen einen toten Zwilling.** `zustaende()` legt für beide je zwei Bilder an (`for _ in ATEM`), aber `_index()` gibt für sie immer `0` zurück — und beide Bilder sind byteweise gleich (nachgeprüft). Der Kommentar begründet die Zwei damit, dass der gesenkte Kopf ein anderer sei; der Code macht das nicht, und er muss es auch nicht: der Atem ist ein Sprite-Versatz, und das Auge ist ein eigenes Teil. Die Zwillinge fallen in Aufgabe 1 weg.

---

## Dateien

| Datei | Zuständig für |
|---|---|
| `tools/wurf_lauf.py` | **ändern**: die Atemformel als Modulfunktion `atem_und_zopf(schritt)` herausziehen, damit sie nicht in einer Closure eingesperrt bleibt |
| `tools/teile_bauen.py` | **ändern**: Zopfzustände vollständig aufzählen, Kopf/Hals-Zwilling raus, `core/angler_parts.gd` schreiben statt `teile.json` |
| `core/angler_parts.gd` | **neu, erzeugt**: Rahmen, Anker, Zustandslisten, Referenzreihen. Einzige Quelle der Teilegeometrie für Godot |
| `core/angler_pose.gd` | **ändern**: die 24er-Posengeometrie fällt weg, die Rutenkonstanten schrumpfen auf elf Einträge |
| `scenes/fishing/angler.tscn` | **ändern**: je Teil eine Gruppe, je Ebene ein Sprite |
| `scenes/fishing/angler.gd` | **ändern**: Bewegung rechnen statt Bildnummer setzen |
| `tools/import_rod.py` | **ändern**: elf Rutenzustände statt sieben; die Hand kommt aus dem Armblatt |
| `tools/gen_sprites.gd` | **ändern**: ein Hutbild statt 24, ohne gemessene Kopfmitten |
| `tests/test_angler_parts.gd` | **neu**: die Szene trägt die Teile an ihren Ankern |
| `tests/test_angler_motion.gd` | **neu**: die Zahlenreihen des Spiels decken sich mit denen der Vorschau |
| `tests/test_sprite_assets.gd` | **ändern**: liest `AnglerParts` statt `teile.json`; die Rutenprüfungen laufen über elf statt 24 |
| `tests/test_character_layers.gd` | **ändern**: prüft die Teileblätter statt der alten `char_*` |
| `tools/tests/test_teile_bauen.py` | **ändern**: die Vollständigkeit der Zopfzustände, die erzeugte Datei ist aktuell |

---

## Aufgabe 1: Die Zopfzustände vollständig, die Geometrie als GDScript

Das Zopfblatt bekommt alle 28 erreichbaren Zustände, Kopf und Hals verlieren ihren toten Zwilling, und die gemessene Geometrie wandert aus `teile.json` in eine erzeugte GDScript-Datei — dorthin, wo Godot sie ohne Dateizugriff lesen kann.

**Dateien:**
- Ändern: `tools/wurf_lauf.py` (die Atemformel herausziehen)
- Ändern: `tools/teile_bauen.py` (`zopf_zustaende`, `zustaende`, `main`)
- Erstellen: `core/angler_parts.gd` (erzeugt)
- Löschen: `assets/art/teile.json`
- Ändern: `tools/tests/test_teile_bauen.py`
- Ändern: `tests/test_sprite_assets.gd`

**Schnittstellen:**
- Nutzt: `wurf_lauf.zopf_im_wurf(i)`, `wurf_lauf.kopf_im_wurf(i)`, `wurf_lauf.BEIN_WURF`, `wurf_lauf.PRO_ZUG`
- Liefert:
  - `wurf_lauf.atem_und_zopf(schritt: int) -> tuple[int, int]`
  - `teile_bauen.zopf_zustaende() -> list[tuple[int, int, int]]` — jetzt 28 Tripel
  - `AnglerParts.BOX: Dictionary` — `StringName -> Rect2i`
  - `AnglerParts.STATES: Dictionary` — `StringName -> int`
  - `AnglerParts.LAYERS: Dictionary` — `StringName -> Array[StringName]`
  - `AnglerParts.ORDER: Array[StringName]`, `AnglerParts.AT_HEAD: Array[StringName]`
  - `AnglerParts.ZOPF_INDEX: Dictionary` — `Vector3i(atem, zopf, seit) -> int`
  - `AnglerParts.LEG_SPREADS: Array[int]`, `AnglerParts.EYES: Array[StringName]`
  - `AnglerParts.BREATH_REF: Array[Vector2i]`, `AnglerParts.CAST_ZOPF/CAST_HEAD/CAST_LEGS: Array[int]`
  - `AnglerParts.zopf_index(atem, zopf, seit) -> int`, `AnglerParts.leg_index(spread) -> int`, `AnglerParts.eye_index(name) -> int`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

In `tools/tests/test_teile_bauen.py` anfügen:

```python
class TestZopfZustaende(unittest.TestCase):
    """Jeder Zustand, den das Spiel erreichen kann, muss gebacken sein.

    Die alte Fassung sammelte die Tripel aus EINEM Durchlauf von
    wurf_lauf.ablauf(). Dort fiel der Wurf zufaellig auf bestimmte
    Atemphasen. Im Spiel faengt er bei jeder an -- die Haelfte der
    erreichbaren Zustaende fehlte, und die Szene faende sie nicht.
    """

    def test_jeder_erreichbare_zustand_ist_gebacken(self):
        from tools import wurf_lauf as wl
        gebacken = set(tb.zopf_zustaende())
        noetig = set()
        for schritt in range(wl.PRO_ZUG):
            atem, zopf = wl.atem_und_zopf(schritt)
            noetig.add((atem, zopf, 0))                 # Ruhelauf
            for i in range(len(wl.BEIN_WURF)):          # Wurf, jede Phase
                noetig.add((atem, zopf + wl.zopf_im_wurf(i),
                            wl.kopf_im_wurf(i)))
        self.assertEqual(set(), noetig - gebacken,
                         "nicht gebacken: %s" % sorted(noetig - gebacken))

    def test_kein_zustand_zuviel(self):
        """Jedes ueberzaehlige Bild ist verschenkter Speicher."""
        from tools import wurf_lauf as wl
        noetig = set()
        for schritt in range(wl.PRO_ZUG):
            atem, zopf = wl.atem_und_zopf(schritt)
            noetig.add((atem, zopf, 0))
            for i in range(len(wl.BEIN_WURF)):
                noetig.add((atem, zopf + wl.zopf_im_wurf(i),
                            wl.kopf_im_wurf(i)))
        self.assertEqual(set(), set(tb.zopf_zustaende()) - noetig)

    def test_kopf_und_hals_haben_einen_zustand(self):
        """Der Atem ist ein Versatz, kein Bild. Zwei gleiche Bilder abzulegen
        war toter Speicher -- _index() gab fuer beide immer 0 zurueck."""
        ebenen = fp.split(_laden("sit3_rumpf.png"))
        koepfe = {s: fp.eye_state(ebenen["head"], s)
                  for s in ("open", "half", "closed")}
        z = tb.zustaende(ebenen, koepfe)
        self.assertEqual(1, len(z["kopf"]))
        self.assertEqual(1, len(z["hals"]))
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
python3 -m unittest tools.tests.test_teile_bauen.TestZopfZustaende -v
```

Erwartet: `AttributeError: module 'tools.wurf_lauf' has no attribute 'atem_und_zopf'`.

- [ ] **Schritt 3: Die Atemformel aus der Closure holen**

In `tools/wurf_lauf.py`, direkt vor `def ablauf(`, einfügen:

```python
def atem_und_zopf(schritt):
    """Atem und Zopfweite in diesem Schritt des Atemzugs.

    Stand als Closure in ablauf() und war damit nur dort zu haben. Das
    Bauwerkzeug braucht sie aber auch: es muss aufzaehlen, welche Zustaende
    ueberhaupt vorkommen koennen, und darf sie dafuer nicht abtippen.
    """
    t = (schritt % PRO_ZUG) / float(PRO_ZUG)
    return (1 if math.sin(2 * math.pi * t) < 0 else 0,
            int(round(2 * math.sin(2 * math.pi * (t - 0.12)))))
```

Und in `ablauf()` die Closure darauf zurückführen:

```python
    def atemzug():
        wert = atem_und_zopf(takt[0])
        takt[0] += 1
        return wert
```

- [ ] **Schritt 4: Die Zopfzustände aufzählen statt abtasten**

In `tools/teile_bauen.py` `zopf_zustaende()` ersetzen:

```python
## Der Zopf haengt nicht nur an seiner eigenen Weite, sondern auch an Atem
## und Kopfversatz: die Naht zwischen ihm und dem Kopf liegt je nach allen
## dreien woanders, und sie muss ins Blatt gebacken werden -- im Spiel
## schliesst sie niemand zur Laufzeit. Sein Zustand ist deshalb das TRIPEL.
##
## AUFGEZAEHLT, nicht abgetastet: frueher stand hier ein Durchlauf von
## wurf_lauf.ablauf(). In dem faellt der Wurf auf die Atemphasen, die sich
## zufaellig ergeben -- vierzehn Tripel. Im Spiel faengt der Wurf bei jeder
## Phase an, und dann sind es achtundzwanzig. Die Haelfte fehlte.
def zopf_zustaende():
    from tools import wurf_lauf as wl
    aus = set()
    for schritt in range(wl.PRO_ZUG):
        atem, zopf = wl.atem_und_zopf(schritt)
        aus.add((atem, zopf, 0))                    # Ruhelauf: Kopf gerade
        for i in range(len(wl.BEIN_WURF)):          # Wurf: Kopf lehnt zurueck
            aus.add((atem, zopf + wl.zopf_im_wurf(i), wl.kopf_im_wurf(i)))
    return sorted(aus)
```

- [ ] **Schritt 5: Den toten Zwilling entfernen**

In `tools/teile_bauen.py`, in `zustaende()`, die beiden Kopfzeilen ersetzen:

```python
        ## Ein Bild je Teil: der Atem ist ein Versatz des Sprites, kein
        ## anderes Bild, und das Auge ist ein eigenes Teil. Hier standen
        ## zwei byteweise gleiche Bilder, und _index() gab immer 0 zurueck.
        "kopf": [kopfteil(rest, koepfe["open"])],
        "hals": [kopfteil(hals, koepfe["open"])],
```

- [ ] **Schritt 6: Test laufen lassen, Erfolg bestätigen**

```
python3 -m unittest tools.tests.test_teile_bauen -v
```

Erwartet: PASS. `TestRahmen::test_jedes_teil_hat_seine_zustaende` schlägt jetzt fehl, weil es 14, 2 und 2 erwartet. Die Zahlen dort auf `28`, `1` und `1` setzen — sie sind gemessen, und die Messung hat sich geändert:

```python
        self.assertEqual(28, len(self.zustaende["zopf"]))
        self.assertEqual(1, len(self.zustaende["kopf"]))
        self.assertEqual(1, len(self.zustaende["hals"]))
```

- [ ] **Schritt 7: Den Test für die erzeugte Datei schreiben**

In `tools/tests/test_teile_bauen.py` anfügen:

```python
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
```

- [ ] **Schritt 8: Test laufen lassen, Fehlschlag bestätigen**

```
python3 -m unittest tools.tests.test_teile_bauen.TestErzeugteDatei -v
```

Erwartet: `AttributeError: module 'tools.teile_bauen' has no attribute 'gdscript_text'`.

- [ ] **Schritt 9: Den Erzeuger schreiben**

In `tools/teile_bauen.py`, `main()` ersetzen und `gdscript_text()` davor einfügen:

```python
def _messen():
    """Rahmen, Zustandszahl und Ebenen je Teil -- einmal gerechnet."""
    ebenen = fp.split(Image.open(os.path.join(TEILE, "sit3_rumpf.png"))
                      .convert("RGBA"))
    koepfe = {s: fp.eye_state(ebenen["head"], s) for s in AUGEN}
    tabelle = load_table(os.path.join(SRC, "key_palette.json"))
    zust = zustaende(ebenen, koepfe)
    aus = {}
    for name in ZEICHENFOLGE:
        kasten = rahmen(zust[name])
        ebenen_hier = [e for e in PARTS
                       if blatt(zust[name], kasten, tabelle, e).getbbox()]
        aus[name] = (kasten, len(zust[name]), ebenen_hier)
    return zust, tabelle, aus


def gdscript_text(gemessen=None):
    """Der Inhalt von core/angler_parts.gd.

    Als Text und nicht direkt geschrieben, damit ein Test ihn mit der Datei
    auf der Platte vergleichen kann, ohne sie zu ueberschreiben.
    """
    from tools import wurf_lauf as wl
    if gemessen is None:
        _, _, gemessen = _messen()

    z = ["## ERZEUGT von tools/teile_bauen.py -- nicht von Hand aendern.",
         "##",
         "## Die Geometrie der Teileblaetter. Jedes Teil ist auf seinen eigenen",
         "## Rahmen zugeschnitten -- das ist der Sinn des Umbaus, und es heisst,",
         "## dass niemand die Masse raten kann. Sie werden am Bild gemessen und",
         "## hier abgelegt, weil Godot das Bauwerkzeug nicht aufrufen kann.",
         "class_name AnglerParts",
         "extends RefCounted",
         "",
         "const FRAME: int = %d" % fp.FRAME,
         "",
         "## Zeichenreihenfolge der Teile. Der Kopf liegt ueber dem Rumpf: lag",
         "## es umgekehrt, frass sein Schulterumriss beim Absenken die",
         "## Kinnzeile. Der Hals gehoert dahinter, sonst schiebt er sich beim",
         "## Neigen ueber den Kragen.",
         "const ORDER: Array[StringName] = [%s]"
         % ", ".join('&"%s"' % n for n in ZEICHENFOLGE),
         "",
         "## Diese Teile haengen am Kopf und gehen mit seinem Versatz mit.",
         "const AT_HEAD: Array[StringName] = [%s]"
         % ", ".join('&"%s"' % n for n in AM_KOPF),
         "",
         "## Rahmen und Anker im 128er Feld, je Teil.",
         "const BOX := {"]
    for name in ZEICHENFOLGE:
        (x, y, w, h), _, _ = gemessen[name]
        z.append('\t&"%s": Rect2i(%d, %d, %d, %d),' % (name, x, y, w, h))
    z += ["}", "",
          "## Wieviele Bilder ein Blatt traegt.",
          "const STATES := {"]
    for name in ZEICHENFOLGE:
        _, n, _ = gemessen[name]
        z.append('\t&"%s": %d,' % (name, n))
    z += ["}", "",
          "## Welche Kosmetikebenen in diesem Teil ueberhaupt vorkommen. Eine",
          "## Ebene ohne Pixel bekommt kein Blatt und braucht kein Sprite.",
          "const LAYERS := {"]
    for name in ZEICHENFOLGE:
        _, _, ebs = gemessen[name]
        z.append('\t&"%s": [%s],'
                 % (name, ", ".join('&"%s"' % e for e in ebs)))
    z += ["}", "",
          "## Der Zustand des Zopfs ist das Tripel aus Atem, Zopfweite und",
          "## Kopfversatz: seine Naht zum Kopf liegt je nach allen dreien",
          "## woanders und ist ins Blatt gebacken.",
          "const ZOPF_INDEX := {"]
    for i, (atem, weite, seit) in enumerate(zopf_zustaende()):
        z.append("\tVector3i(%d, %d, %d): %d," % (atem, weite, seit, i))
    z += ["}", "",
          "const LEG_SPREADS: Array[int] = [%s]"
          % ", ".join(str(w) for w in BEIN_WEITEN),
          "const EYES: Array[StringName] = [%s]"
          % ", ".join('&"%s"' % s for s in AUGEN),
          "",
          "## --- Vergleichsreihen fuer den Bewegungstest ---------------------",
          "##",
          "## Die Formeln stehen zweimal: in Python fuer die Vorschau, in",
          "## GDScript fuers Spiel. Das ist bewusst in Kauf genommen -- es sind",
          "## fuenf Zeilen Arithmetik ohne Pixelzugriff. Damit sie nicht",
          "## auseinanderlaufen, liegen die Zahlen der Vorschau hier, und",
          "## tests/test_angler_motion.gd rechnet sie nach.",
          "const BREATH_STEPS: int = %d" % wl.PRO_ZUG,
          "const LEG_STEPS: int = %d" % wl.BEIN_ZUG,
          "## (Atem, Zopfweite) je Schritt des Atemzugs.",
          "const BREATH_REF: Array[Vector2i] = [%s]"
          % ", ".join("Vector2i(%d, %d)" % wl.atem_und_zopf(s)
                      for s in range(wl.PRO_ZUG)),
          "## Der Beinschwung bei Weite 4, je Schritt -- die Weite selbst wird",
          "## im Umkehrpunkt neu gezogen und ist deshalb nicht vergleichbar.",
          "const LEG_REF: Array[int] = [%s]"
          % ", ".join(str(int(round(4 * math.sin(2 * math.pi * i
                                                 / float(wl.BEIN_ZUG)))))
                      for i in range(wl.BEIN_ZUG)),
          "## Was der Wurf je Bild an Zopf, Kopf und Beinen setzt.",
          "const CAST_ZOPF: Array[int] = [%s]"
          % ", ".join(str(wl.zopf_im_wurf(i))
                      for i in range(len(wl.BEIN_WURF))),
          "const CAST_HEAD: Array[int] = [%s]"
          % ", ".join(str(wl.kopf_im_wurf(i))
                      for i in range(len(wl.BEIN_WURF))),
          "const CAST_LEGS: Array[int] = [%s]"
          % ", ".join(str(v) for v in wl.BEIN_WURF),
          "",
          "static func zopf_index(atem: int, weite: int, seit: int) -> int:",
          "\treturn int(ZOPF_INDEX.get(Vector3i(atem, weite, seit), -1))",
          "",
          "static func leg_index(spread: int) -> int:",
          "\treturn LEG_SPREADS.find(clampi(spread, LEG_SPREADS[0],",
          "\t\tLEG_SPREADS[LEG_SPREADS.size() - 1]))",
          "",
          "static func eye_index(name: StringName) -> int:",
          "\treturn maxi(0, EYES.find(name))",
          ""]
    return "\n".join(z)


def main():
    zust, tabelle, gemessen = _messen()
    geschrieben = 0
    for name in ZEICHENFOLGE:
        kasten, anzahl, ebenen_hier = gemessen[name]
        for ebene in ebenen_hier:
            bild = blatt(zust[name], kasten, tabelle, ebene)
            bild.save(os.path.join(OUT, "teil_%s_%s.png" % (name, ebene)))
            geschrieben += 1
        print("%-8s %2dx%-3d bei %2d,%-3d  %2d Zustaende, Ebenen: %s"
              % (name, kasten[2], kasten[3], kasten[0], kasten[1], anzahl,
                 " ".join(ebenen_hier)))
    with open(os.path.join(WURZEL, "core", "angler_parts.gd"), "w",
              encoding="utf-8") as f:
        f.write(gdscript_text(gemessen))
    print("%d Blaetter und core/angler_parts.gd geschrieben" % geschrieben)
```

Oben in der Datei `import math` ergänzen (`json` wird nicht mehr gebraucht und fliegt raus).

- [ ] **Schritt 10: Erzeugen und ansehen**

```
python3 -m tools.teile_bauen
head -40 core/angler_parts.gd
```

Erwartet: 23 Blätter, der Zopf mit 28 Zuständen, Kopf und Hals mit einem. Die Ausgabe dem Menschen vorlegen.

- [ ] **Schritt 11: Den Sprite-Test auf `AnglerParts` umstellen**

In `tests/test_sprite_assets.gd` den JSON-Weg ersetzen. `_teile_cache`, `_teile()` und `_teil_eintrag()` fallen weg; stattdessen:

```gdscript
func _teil_name(filename: String) -> StringName:
	var rest := filename.trim_prefix("teil_").trim_suffix(".png")
	for name in AnglerParts.ORDER:
		if rest.begins_with("%s_" % name):
			return name
	return &""
```

In `_expected_size` den `teil_`-Zweig ersetzen:

```gdscript
	if filename.begins_with("teil_"):
		var name := _teil_name(filename)
		if name == &"":
			return Vector2i(-1, -1)
		var box: Rect2i = AnglerParts.BOX[name]
		return Vector2i(box.size.x * int(AnglerParts.STATES[name]), box.size.y)
```

Und im Leerlauf-Zweig `var t := _teil_eintrag(file)` / `var w: int = t["w"]` ersetzen durch:

```gdscript
			var name := _teil_name(file)
			var w: int = AnglerParts.BOX[name].size.x
			for i in int(AnglerParts.STATES[name]):
```

- [ ] **Schritt 12: `teile.json` löschen**

```bash
git rm assets/art/teile.json
```

- [ ] **Schritt 13: Ganze Suite**

```
bash tools/test.sh
```

Erwartet: alles grün. Das Zopfblatt ist jetzt 588×33 statt 294×33 (28 statt 14 Zustände), das Kopfblatt 25×28 statt 50×28.

- [ ] **Schritt 14: Commit**

```bash
git add tools/wurf_lauf.py tools/teile_bauen.py tools/tests/test_teile_bauen.py \
        core/angler_parts.gd tests/test_sprite_assets.gd assets/art/teil_*.png
git commit -m "Alle erreichbaren Zopfzustaende, Geometrie als erzeugtes GDScript"
```

---

## Aufgabe 2: Die Szene aus Teilen

`angler.tscn` bekommt je Teil eine Gruppe mit je Kosmetikebene einem Sprite, und `angler.gd` setzt sie an ihre Anker. Die Bewegung bleibt in dieser Aufgabe stehen — die Figur zeigt einen festen Zustand, aber aus den neuen Blättern.

**Dateien:**
- Ändern: `scenes/fishing/angler.tscn`
- Ändern: `scenes/fishing/angler.gd`
- Erstellen: `tests/test_angler_parts.gd`

**Schnittstellen:**
- Nutzt: `AnglerParts.ORDER`, `AnglerParts.LAYERS`, `AnglerParts.BOX`, `AnglerParts.STATES`, `AnglerParts.AT_HEAD`, `AnglerParts.zopf_index()`, `AnglerParts.leg_index()`, `AnglerParts.eye_index()`
- Liefert:
  - `Angler.set_pose(atem: int, zopf: int, seit: int, bein: int, auge: StringName, arm: int) -> void`
  - `Angler.LAYER_ORDER: Array[StringName]` — `[&"skin", &"pants", &"shirt", &"hair", &"base"]`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

`tests/test_angler_parts.gd` anlegen:

```gdscript
extends TestCase

## Die Figur wird aus Teilen zusammengesetzt. Jedes Teil muss an der Stelle
## sitzen, an der das Bauwerkzeug es gemessen hat -- sonst steht der Kopf
## neben dem Hals, und zwar in jedem einzelnen Bild.

func _angler() -> Node2D:
	## TestCase erbt von RefCounted und hat kein get_tree(). Der Baum kommt
	## deshalb ueber die Hauptschleife -- wie in tests/test_cosmetics.gd.
	var a: Node2D = load("res://scenes/fishing/angler.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(a)
	return a

func test_jedes_teil_hat_seine_gruppe_mit_seinen_ebenen() -> void:
	var a := _angler()
	for name in AnglerParts.ORDER:
		var gruppe := a.get_node_or_null(NodePath(String(name)))
		assert_true(gruppe != null, "Gruppe %s fehlt" % name)
		if gruppe == null:
			continue
		for ebene in AnglerParts.LAYERS[name]:
			var sprite := gruppe.get_node_or_null(NodePath(String(ebene)))
			assert_true(sprite is Sprite2D,
				"%s/%s fehlt oder ist kein Sprite2D" % [name, ebene])
	a.free()

func test_jedes_teil_sitzt_auf_seinem_anker() -> void:
	var a := _angler()
	a.set_pose(0, 0, 0, 0, &"open", 0)
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = a.get_node(NodePath(String(name)))
		var box: Rect2i = AnglerParts.BOX[name]
		assert_eq(gruppe.position, Vector2(box.position),
			"%s sitzt nicht auf seinem Anker" % name)
	a.free()

func test_die_am_kopf_haengenden_teile_gehen_mit_dem_atem_mit() -> void:
	## Ein Pixel Atem und zwei Pixel Kopfversatz: Zopf, Kopf, Hals und Auge
	## muessen beides mitmachen, der Rumpf keines von beidem.
	var a := _angler()
	a.set_pose(1, 0, -2, 0, &"open", 0)
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = a.get_node(NodePath(String(name)))
		var box: Rect2i = AnglerParts.BOX[name]
		var erwartet := Vector2(box.position)
		if AnglerParts.AT_HEAD.has(name):
			erwartet += Vector2(-2, 1)
		assert_eq(gruppe.position, erwartet, "%s steht falsch" % name)
	a.free()

func test_die_blaetter_haengen_an_den_sprites() -> void:
	var a := _angler()
	a.set_pose(0, 0, 0, 0, &"open", 0)
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = a.get_node(NodePath(String(name)))
		for ebene in AnglerParts.LAYERS[name]:
			var s: Sprite2D = gruppe.get_node(NodePath(String(ebene)))
			assert_true(s.texture != null, "%s/%s ohne Textur" % [name, ebene])
			assert_eq(s.hframes, int(AnglerParts.STATES[name]),
				"%s/%s: falsche Bildzahl" % [name, ebene])
			assert_false(s.centered, "%s/%s muss centered=false sein"
				% [name, ebene])
	a.free()

## Die Reihenfolge im Baum IST die Zeichenreihenfolge. Steht sie falsch,
## liegt der Zopf ueber dem Gesicht -- und das faellt erst im Spiel auf.
func test_die_zeichenreihenfolge_stimmt() -> void:
	var a := _angler()
	var gesehen: Array[StringName] = []
	for kind in a.get_children():
		var n := StringName(kind.name)
		if AnglerParts.ORDER.has(n):
			gesehen.append(n)
	assert_eq(gesehen, AnglerParts.ORDER, "die Teile stehen falsch im Baum")
	a.free()
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
bash tools/test.sh
```

Erwartet: `test_angler_parts.gd` rot mit „Gruppe zopf fehlt".

- [ ] **Schritt 3: Die Szene umbauen**

`scenes/fishing/angler.tscn` ersetzen. Je Teil ein `Node2D`, darin je Ebene ein `Sprite2D` mit `centered = false`. Die Reihenfolge im Baum ist die Zeichenreihenfolge; `Hat` und `Rod` stehen am Ende.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/fishing/angler.gd" id="1"]

[node name="Angler" type="Node2D"]
script = ExtResource("1")

[node name="zopf" type="Node2D" parent="."]
[node name="hair" type="Sprite2D" parent="zopf"]
centered = false
[node name="base" type="Sprite2D" parent="zopf"]
centered = false

[node name="beine" type="Node2D" parent="."]
[node name="skin" type="Sprite2D" parent="beine"]
centered = false
[node name="boots" type="Sprite2D" parent="beine"]
centered = false
[node name="base" type="Sprite2D" parent="beine"]
centered = false

[node name="hals" type="Node2D" parent="."]
[node name="skin" type="Sprite2D" parent="hals"]
centered = false
[node name="base" type="Sprite2D" parent="hals"]
centered = false

[node name="rumpf" type="Node2D" parent="."]
[node name="skin" type="Sprite2D" parent="rumpf"]
centered = false
[node name="pants" type="Sprite2D" parent="rumpf"]
centered = false
[node name="shirt" type="Sprite2D" parent="rumpf"]
centered = false
[node name="base" type="Sprite2D" parent="rumpf"]
centered = false

[node name="kopf" type="Node2D" parent="."]
[node name="skin" type="Sprite2D" parent="kopf"]
centered = false
[node name="hair" type="Sprite2D" parent="kopf"]
centered = false
[node name="base" type="Sprite2D" parent="kopf"]
centered = false

[node name="auge" type="Node2D" parent="."]
[node name="skin" type="Sprite2D" parent="auge"]
centered = false
[node name="hair" type="Sprite2D" parent="auge"]
centered = false
[node name="base" type="Sprite2D" parent="auge"]
centered = false

[node name="armfern" type="Node2D" parent="."]
[node name="skin" type="Sprite2D" parent="armfern"]
centered = false
[node name="shirt" type="Sprite2D" parent="armfern"]
centered = false
[node name="base" type="Sprite2D" parent="armfern"]
centered = false

[node name="arm" type="Node2D" parent="."]
[node name="skin" type="Sprite2D" parent="arm"]
centered = false
[node name="shirt" type="Sprite2D" parent="arm"]
centered = false
[node name="base" type="Sprite2D" parent="arm"]
centered = false

[node name="Hat" type="Sprite2D" parent="."]
centered = false

[node name="Rod" type="Sprite2D" parent="."]
hframes = 7
centered = false
```

Die Ebenennamen je Gruppe müssen mit `AnglerParts.LAYERS` übereinstimmen — die Liste oben ist der heutige Stand (`zopf: hair base`, `beine: skin boots base`, `hals: skin base`, `rumpf: skin shirt pants base`, `kopf: skin hair base`, `auge: skin hair base`, `armfern: skin shirt base`, `arm: skin shirt base`). Weicht die erzeugte Datei ab, gilt sie.

- [ ] **Schritt 4: `angler.gd` auf Teile umstellen**

In `scenes/fishing/angler.gd` `LAYERS`, `TEX_PREFIX`, `_set_layer`, `play_state` und `_place_rod` ersetzen:

```gdscript
## Reihenfolge innerhalb eines Teils: Haut, Hose, Pullover, Haar, Grundebene.
## "base" traegt Umriss, Auge und Kragen und wird nie umgefaerbt -- deshalb
## liegt es ueber der Kleidung. Die Ebenen eines Teils ueberschneiden sich
## nicht (tests/test_character_layers.gd), die Reihenfolge ist also eine
## Frage der Lesbarkeit und keine der Deckung.
const LAYER_ORDER: Array[StringName] = [&"skin", &"pants", &"shirt", &"hair",
	&"base"]

var _atem: int = 0
var _zopf: int = 0
var _seit: int = 0
var _bein: int = 0
var _auge: StringName = &"open"
var _arm: int = 0

func _load_parts() -> void:
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = get_node(NodePath(String(name)))
		for ebene in AnglerParts.LAYERS[name]:
			var s: Sprite2D = gruppe.get_node(NodePath(String(ebene)))
			s.texture = TextureLoader.load_texture(
				"res://assets/art/teil_%s_%s.png" % [name, ebene])
			s.hframes = int(AnglerParts.STATES[name])

## Die Bewegung in Zahlen, und daraus die Bildnummern und Versaetze. Atem und
## Kopfversatz stecken NICHT in den Blaettern: sie sind Versatz der Gruppe.
## Nur die Scherungen von Zopf und Beinen sind gebacken -- eine Scherung
## verschiebt jede Zeile anders und laesst sich nicht als Position ausdruecken.
func set_pose(atem: int, zopf: int, seit: int, bein: int, auge: StringName,
		arm: int) -> void:
	_atem = atem
	_zopf = zopf
	_seit = seit
	_bein = bein
	_auge = auge
	_arm = arm
	var zopf_i := AnglerParts.zopf_index(atem, zopf, seit)
	if zopf_i < 0:
		# Darf nicht vorkommen: das Bauwerkzeug zaehlt alle erreichbaren
		# Tripel auf. Wenn doch, lieber der naechstbeste Zustand als ein
		# leerer Kopf -- und eine Meldung, die den Fall benennt.
		push_error("Zopfzustand %d/%d/%d nicht gebacken" % [atem, zopf, seit])
		zopf_i = AnglerParts.zopf_index(atem, clampi(zopf, -2, 2), 0)
		zopf_i = maxi(zopf_i, 0)
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = get_node(NodePath(String(name)))
		var box: Rect2i = AnglerParts.BOX[name]
		var versatz := Vector2(box.position)
		if AnglerParts.AT_HEAD.has(name):
			versatz += Vector2(seit, atem)
		gruppe.position = versatz
		var i := 0
		match name:
			&"zopf": i = zopf_i
			&"beine": i = AnglerParts.leg_index(bein)
			&"auge": i = AnglerParts.eye_index(auge)
			&"arm": i = clampi(arm, 0, int(AnglerParts.STATES[name]) - 1)
		for ebene in AnglerParts.LAYERS[name]:
			(gruppe.get_node(NodePath(String(ebene))) as Sprite2D).frame = i
	_place_rod()
```

`set_cosmetics` verliert die Teilezeilen und behält nur Hut, Rute und Tönung:

```gdscript
func set_cosmetics(c: Dictionary) -> void:
	_load_parts()
	_set_single(&"Hat", "char_hat", int(c.get("hat", 0)))
	_set_single(&"Rod", "char_rod", int(c.get("rod", 0)))
	_tint_hair(int(c.get("hair_color", 0)))

func _set_single(node: StringName, prefix: String, index: int) -> void:
	var sprite: Sprite2D = get_node(NodePath(String(node)))
	var tex := TextureLoader.load_texture(
		"res://assets/art/%s_%d.png" % [prefix, index])
	if tex != null:
		sprite.texture = tex
```

`_tint_hair` färbt jetzt jedes Haarblatt, nicht ein einzelnes Sprite:

```gdscript
func _tint_hair(color_index: int) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/art/palette_swap.gdshader")
	mat.set_shader_parameter("tint", Palette.get_color(
		HAIR_TINTS[clampi(color_index, 0, HAIR_TINTS.size() - 1)]))
	mat.set_shader_parameter("strength", 1.0)
	for name in AnglerParts.ORDER:
		if not AnglerParts.LAYERS[name].has(&"hair"):
			continue
		var s: Sprite2D = get_node(NodePath("%s/hair" % name))
		s.material = mat
```

`_place_rod()` bleibt vorerst, wie es ist — die Rute kommt in Aufgabe 5 dran. Damit sie in dieser Aufgabe nicht abstürzt, nimmt sie den Armzustand als Posenindex:

```gdscript
## Vorlaeufig: die Rute haengt noch an der alten 24er-Posengeometrie. Aufgabe
## 5 stellt sie auf die elf Armzustaende um.
func _place_rod() -> void:
	var rod: Sprite2D = $Rod
	var pose := 0 if _arm == 0 else AnglerPose.CAST_START
	rod.frame = AnglerPose.ROD_FRAME[pose]
	rod.position = Vector2(AnglerPose.rod_offset(pose))
```

Und `play_state`/`_process`/`rod_tip` fürs Erste auf `set_pose` zurückführen, damit die Datei übersetzt:

```gdscript
func play_state(frame: int) -> void:
	## Bleibt bis Aufgabe 3, damit die alten Aufrufer nicht brechen.
	set_pose(0, 0, 0, 0, &"open", 0 if frame < AnglerPose.CAST_START else 1)

func rod_tip() -> Vector2:
	var pose := 0 if _arm == 0 else AnglerPose.CAST_START
	return position + Vector2(AnglerPose.rod_tip(pose)) * scale
```

- [ ] **Schritt 5: Test laufen lassen, Erfolg bestätigen**

```
bash tools/test.sh
```

Erwartet: `test_angler_parts.gd` grün. `test_cosmetics.gd::test_die_getragene_rute_wird_gezeigt` muss weiter grün sein — es liest `angler.get_node("Rod").texture`, und das setzt `_set_single` weiter.

- [ ] **Schritt 6: Ansehen**

Das Spiel starten und einen Bildschirmabzug machen:

```
bash tools/godot.sh --headless --quit-after 120 2>&1 | tail -5
```

Die Figur steht still, aber vollständig. Sieht sie zerfallen aus, stimmt ein Anker nicht — die Zahlen in `core/angler_parts.gd` gegen die Ausgabe von `python3 -m tools.teile_bauen` halten. **Dem Menschen vorlegen.**

- [ ] **Schritt 7: Commit**

```bash
git add scenes/fishing/angler.tscn scenes/fishing/angler.gd tests/test_angler_parts.gd
git commit -m "Die Anglerin als Teilegruppen in der Szene"
```

---

## Aufgabe 3: Die Bewegung

`angler.gd` rechnet Atem, Zopf, Beine, Blinzeln und Wurf aus der Uhr, statt eine Bildnummer nachzuschlagen. Hier kommt zurück, was der ganze Umbau bezweckt: die **Weite des Beinschwungs wird im Umkehrpunkt neu gezogen**.

**Dateien:**
- Ändern: `scenes/fishing/angler.gd`
- Erstellen: `tests/test_angler_motion.gd`

**Schnittstellen:**
- Nutzt: `AnglerParts.BREATH_REF`, `AnglerParts.LEG_REF`, `AnglerParts.BREATH_STEPS`, `AnglerParts.LEG_STEPS`, `AnglerParts.CAST_ZOPF`, `AnglerParts.CAST_HEAD`, `AnglerParts.CAST_LEGS`, `Angler.set_pose()`
- Liefert:
  - `Angler.breath_at(t: float) -> Vector2i` — (Atem, Zopfweite) bei Phase `t` in [0,1)
  - `Angler.leg_at(spread: int, t: float) -> int`
  - `Angler.BREATH_TIME: float`, `Angler.LEG_TIME: float`
  - `Angler.LEG_SPREAD_MIN: int`, `Angler.LEG_SPREAD_MAX: int`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

`tests/test_angler_motion.gd` anlegen:

```gdscript
extends TestCase

## Die Formeln stehen zweimal: in Python fuer die Vorschau (tools/wurf_lauf.py)
## und hier fuers Spiel. Das ist bewusst in Kauf genommen -- es sind fuenf
## Zeilen Arithmetik ohne Pixelzugriff. Damit sie nicht auseinanderlaufen,
## legt das Bauwerkzeug seine Zahlen in AnglerParts ab, und diese Tests
## rechnen sie nach. Laufen sie auseinander, atmet die Figur im Spiel anders
## als in der Vorschau -- und die Vorschau ist das, was der Mensch abnimmt.

func _angler() -> Node2D:
	## TestCase erbt von RefCounted und hat kein get_tree(). Der Baum kommt
	## deshalb ueber die Hauptschleife -- wie in tests/test_cosmetics.gd.
	var a: Node2D = load("res://scenes/fishing/angler.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(a)
	return a

func test_der_atem_stimmt_mit_der_vorschau_ueberein() -> void:
	var a := _angler()
	for i in AnglerParts.BREATH_STEPS:
		var t := float(i) / float(AnglerParts.BREATH_STEPS)
		assert_eq(a.breath_at(t), AnglerParts.BREATH_REF[i],
			"Schritt %d: Atem und Zopf laufen auseinander" % i)
	a.free()

func test_der_beinschwung_stimmt_mit_der_vorschau_ueberein() -> void:
	var a := _angler()
	for i in AnglerParts.LEG_STEPS:
		var t := float(i) / float(AnglerParts.LEG_STEPS)
		assert_eq(a.leg_at(4, t), AnglerParts.LEG_REF[i],
			"Schritt %d: der Beinschwung laeuft auseinander" % i)
	a.free()

## Jeder Zustand, den die Bewegung erreicht, muss ein Blatt haben. Das ist
## dieselbe Zusicherung wie in tools/tests/test_teile_bauen.py, nur von der
## anderen Seite: dort wird aufgezaehlt, hier wird gefahren.
func test_kein_zustand_ohne_blatt() -> void:
	var a := _angler()
	for i in AnglerParts.BREATH_STEPS:
		var t := float(i) / float(AnglerParts.BREATH_STEPS)
		var b: Vector2i = a.breath_at(t)
		assert_true(AnglerParts.zopf_index(b.x, b.y, 0) >= 0,
			"Ruhe, Schritt %d: %s fehlt" % [i, b])
		for f in AnglerParts.CAST_ZOPF.size():
			var w: int = b.y + AnglerParts.CAST_ZOPF[f]
			var s: int = AnglerParts.CAST_HEAD[f]
			assert_true(AnglerParts.zopf_index(b.x, w, s) >= 0,
				"Wurf %d bei Schritt %d: %d/%d/%d fehlt" % [f, i, b.x, w, s])
	a.free()

func test_der_beinausschlag_bleibt_im_gebackenen_bereich() -> void:
	var a := _angler()
	for spread in range(a.LEG_SPREAD_MIN, a.LEG_SPREAD_MAX + 1):
		for i in AnglerParts.LEG_STEPS:
			var v: int = a.leg_at(spread, float(i) / float(AnglerParts.LEG_STEPS))
			assert_true(AnglerParts.LEG_SPREADS.has(v),
				"Weite %d, Schritt %d: %d ist nicht gebacken" % [spread, i, v])
	for f in AnglerParts.CAST_LEGS.size():
		assert_true(AnglerParts.LEG_SPREADS.has(int(AnglerParts.CAST_LEGS[f])),
			"Wurfbild %d: Beinwert nicht gebacken" % f)
	a.free()
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
bash tools/test.sh
```

Erwartet: rot mit „Invalid call. Nonexistent function 'breath_at'".

- [ ] **Schritt 3: Die Bewegung schreiben**

In `scenes/fishing/angler.gd` den Uhrenblock ersetzen. `IDLE_FPS` fällt weg — der Ruhelauf ist keine Bilderreihe mehr, sondern eine Phase.

```gdscript
## Ein Atemzug dauert so lange wie in der Vorschau: 32 Schritte zu 100 ms.
## Frueher standen hier neun Bilder zu drei je Sekunde; die Zahl kam aus der
## Bilderreihe, nicht aus der Figur.
const BREATH_TIME: float = 3.2
## Ein voller Beinschwung: 24 Schritte zu 100 ms.
const LEG_TIME: float = 2.4
## Wie weit die Beine schwingen. Im Umkehrpunkt neu gezogen -- DAS ist der
## Grund, warum im Spiel gerechnet und nicht gebacken wird. Ein fester Wert
## sieht nach Uhrwerk aus.
const LEG_SPREAD_MIN: int = 2
const LEG_SPREAD_MAX: int = 6

## Wie lange ein Blinzeln dauert und wie oft es kommt. Nicht im Atemtakt:
## ein Atemzug dauert gut drei Sekunden, so oft blinzelt niemand.
const BLINK_MIN: float = 2.5
const BLINK_MAX: float = 6.0
## Halb, zu, halb -- dieselben Zeiten wie tools/wurf_lauf.BLINZELN.
const BLINK_PHASES: Array[float] = [0.055, 0.090, 0.055]
const BLINK_EYES: Array[StringName] = [&"half", &"closed", &"half"]

var _idle_time: float = 0.0
var _leg_time: float = 0.0
var _leg_spread: int = 4
var _leg_sign: int = 0
var _blink_in: float = 3.0
var _blink_left: float = 0.0

## Atem und Zopfweite aus der Phase des Atemzugs. Dieselben Formeln wie
## tools/wurf_lauf.atem_und_zopf() -- tests/test_angler_motion.gd haelt beide
## Reihen gegeneinander.
func breath_at(t: float) -> Vector2i:
	var p := fposmod(t, 1.0)
	return Vector2i(1 if sin(TAU * p) < 0.0 else 0,
		int(round(2.0 * sin(TAU * (p - 0.12)))))

func leg_at(spread: int, t: float) -> int:
	return int(round(float(spread) * sin(TAU * fposmod(t, 1.0))))

## Der Beinschwung, und die Weite im Umkehrpunkt neu gezogen. Mittendrin
## gezogen spraenge das Bein sichtbar.
func _legs(delta: float) -> int:
	_leg_time += delta
	var t := fposmod(_leg_time / LEG_TIME, 1.0)
	var schwung := sin(TAU * t)
	var richtung := 1 if schwung >= 0.0 else -1
	if _leg_sign != 0 and richtung != _leg_sign:
		_leg_spread = randi_range(LEG_SPREAD_MIN, LEG_SPREAD_MAX)
	_leg_sign = richtung
	return leg_at(_leg_spread, t)

## Welches Auge gerade dran ist. Gibt &"open" zurueck, wenn gerade nicht
## geblinzelt wird.
func _blink(delta: float) -> StringName:
	if _blink_left > 0.0:
		_blink_left -= delta
		var rest := _blink_left
		for i in range(BLINK_PHASES.size() - 1, -1, -1):
			if rest <= BLINK_PHASES[i]:
				return BLINK_EYES[i]
			rest -= BLINK_PHASES[i]
		return BLINK_EYES[0]
	_blink_in -= delta
	if _blink_in <= 0.0:
		var ganz := 0.0
		for p in BLINK_PHASES:
			ganz += p
		_blink_left = ganz
		_blink_in = randf_range(BLINK_MIN, BLINK_MAX)
	return &"open"

func _process(delta: float) -> void:
	_idle_time += delta
	var atem := breath_at(_idle_time / BREATH_TIME)
	match Game.sim.state:
		FishingSim.State.CASTING:
			var left: float = clampf(Game.sim.timer / FishingSim.CAST_TIME,
				0.0, 1.0)
			var n := AnglerParts.CAST_ZOPF.size()
			var f: int = clampi(int((1.0 - left) * float(n)), 0, n - 1)
			_cast_pose(atem, f)
		FishingSim.State.FIGHT:
			# Arm vorn, Rute unter Zug -- das letzte Wurfbild.
			_cast_pose(atem, AnglerParts.CAST_ZOPF.size() - 1)
		_:
			# Stillstehen sieht tot aus: ein Atemzug hin und zurueck, die
			# Beine baumeln, und hin und wieder ein Blinzeln dazwischen.
			set_pose(atem.x, atem.y, 0, _legs(delta), _blink(delta), 0)

## Beim Werfen haelt sie die Beine nicht still, sie schwingen nach dem
## gemessenen Muster; Atem und Zopf laufen weiter, und der Kopf lehnt zurueck.
func _cast_pose(atem: Vector2i, f: int) -> void:
	set_pose(atem.x, atem.y + int(AnglerParts.CAST_ZOPF[f]),
		int(AnglerParts.CAST_HEAD[f]), int(AnglerParts.CAST_LEGS[f]),
		&"open", f + 1)
```

`play_state()` fällt weg. Die drei Signalhandler darauf umstellen:

```gdscript
func _on_bite(_fish: FishData) -> void:
	_cast_pose(breath_at(_idle_time / BREATH_TIME),
		AnglerParts.CAST_ZOPF.size() - 1)

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	set_pose(0, 0, 0, 0, &"open", 0)

func _on_escaped(_f: FishData) -> void:
	set_pose(0, 0, 0, 0, &"open", 0)
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

```
bash tools/test.sh
```

Erwartet: `test_angler_motion.gd` grün. Schlägt `test_kein_zustand_ohne_blatt` fehl, ist Aufgabe 1 unvollständig — **nicht** hier die Formel biegen, sondern dort die Aufzählung nachziehen.

- [ ] **Schritt 5: Die Bewegung ansehen**

```
python3 -m tools.wurf_lauf /tmp/vergleich.gif
```

Das GIF ist die Vorschau derselben Bewegung. Es und einen Bildschirmabzug des laufenden Spiels **dem Menschen nebeneinander vorlegen**: der Atem muss gleich schnell gehen, der Zopf gleich weit schwingen, die Beine unterschiedlich weit von Schwung zu Schwung.

- [ ] **Schritt 6: Commit**

```bash
git add scenes/fishing/angler.gd tests/test_angler_motion.gd
git commit -m "Atem, Zopf, Beine und Blinzeln gerechnet statt nachgeschlagen"
```

---

## Aufgabe 4: Der Hut an die Kopfgruppe

Der Hut wird nicht mehr für 24 Bilder gemalt, sondern einmal — und folgt dem Kopf, weil der Kopf jetzt eine Gruppe mit einer Position ist.

**Dateien:**
- Ändern: `tools/gen_sprites.gd` (`_hat`, `HAT_CENTERS_X`, `HAT_TOPS`)
- Ändern: `scenes/fishing/angler.gd` (`_place_hat`)
- Ändern: `tests/test_sprite_assets.gd` (`_expected_size` für `char_hat_`)

**Schnittstellen:**
- Nutzt: `AnglerParts.BOX[&"kopf"]`
- Liefert: `Angler.HAT_OFFSET: Vector2i` — wohin der Hut relativ zum Kopfanker gehört

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

In `tests/test_angler_parts.gd` anfügen:

```gdscript
## Der Hut sitzt auf dem Kopf und geht mit dem Atem mit. Er ist trotzdem kein
## Kind der Kopfgruppe: er wird NACH den Armen gezeichnet, die Gruppe aber
## davor. Also folgt er ihr rechnerisch.
func test_der_hut_folgt_dem_kopf() -> void:
	var a := _angler()
	var kopf: Node2D = a.get_node("kopf")
	var hut: Sprite2D = a.get_node("Hat")
	a.set_pose(0, 0, 0, 0, &"open", 0)
	var ruhe := hut.position - kopf.position
	a.set_pose(1, 0, -2, 0, &"open", 0)
	assert_eq(hut.position - kopf.position, ruhe,
		"der Hut haelt seinen Abstand zum Kopf nicht")
	assert_eq(hut.position - Vector2(AnglerParts.BOX[&"kopf"].position),
		Vector2(a.HAT_OFFSET) + Vector2(-2, 1),
		"der Hut geht nicht mit Atem und Kopfversatz mit")
	a.free()
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
bash tools/test.sh
```

Erwartet: rot mit „Invalid access to constant 'HAT_OFFSET'".

- [ ] **Schritt 3: Den Hut auf ein Bild bringen**

In `tools/gen_sprites.gd` die beiden Messreihen ersetzen:

```gdscript
## Der Hut wird einmal gemalt, nicht je Bild. Er haengt am Kopf, und der Kopf
## ist im Spiel eine Gruppe mit einer Position -- er geht also von selbst mit
## Atem und Wurf mit. Hier standen 24 gemessene Kopfmitten; sie waren nur
## noetig, solange jede Pose ein eigenes Bild war.
## Die Mitte im HAT_FRAME-Raster: der Kopf steht in AnglerParts.BOX bei
## 47,5 und ist 25x28 gross, seine Mitte also bei 59,5 im 128er Feld.
const HAT_CENTER_X: int = 12
const HAT_TOP: int = 0
```

Und `const FRAMES := AnglerPose.FRAMES` (Zeile 269) loeschen: `_hat()` war
sein einziger Nutzer. **Das muss hier geschehen und nicht spaeter** — die
naechste Aufgabe entfernt `AnglerPose.FRAMES`, und bliebe die Zeile stehen,
liesse sich `gen_sprites.gd` nicht mehr uebersetzen.

Dann `_hat()` auf ein Bild zusammenziehen — die Schleife `for f in FRAMES` und `ox` fallen weg, `cx` wird `HAT_CENTER_X`, `top` wird `HAT_TOP`:

```gdscript
func _hat(index: int) -> void:
	var img := _new_image(HAT_FRAME, HAT_FRAME)
	var cx := HAT_CENTER_X
	var top := HAT_TOP
	match index:
		1:  # Kappe: Schirm nach vorn
			_limb(img, cx - 8, top + 1, 16, 5, _c(&"cloth_grey"))
			_limb(img, cx + 6, top + 5, 9, 2, _c(&"cloth_grey"))
		2:  # Strohhut: breite Krempe
			_limb(img, cx - 13, top + 6, 27, 2, _c(&"accent"))
			_limb(img, cx - 7, top + 1, 14, 5, _c(&"accent"))
		3:  # Suedwester: Krempe hinten lang
			_limb(img, cx - 11, top + 5, 23, 3, _c(&"cloth_ochre"))
			_limb(img, cx - 7, top + 1, 14, 4, _c(&"cloth_ochre"))
			_limb(img, cx - 15, top + 8, 6, 3, _c(&"cloth_ochre"))
		4:  # Wollmuetze: keine Krempe, Bommel
			_limb(img, cx - 8, top, 16, 7, _c(&"cloth_red"))
			_bulb(img, cx, top - 1, 3.0, 2.0, _c(&"foam"))
		5:  # Filzhut: breite Krempe, hoher Kopf
			_limb(img, cx - 13, top + 6, 26, 3, _c(&"wood_dark"))
			_limb(img, cx - 7, top, 14, 6, _c(&"wood_dark"))
		6:  # Teufelshoerner: kurz, spitz, nach aussen
			_limb(img, cx - 9, top + 1, 3, 6, _c(&"cloth_red"))
			_limb(img, cx + 6, top + 1, 3, 6, _c(&"cloth_red"))
			_rect(img, cx - 11, top - 1, 2, 4, _c(&"cloth_red"))
			_rect(img, cx + 9, top - 1, 2, 4, _c(&"cloth_red"))
		7:  # Ziegenhoerner: dicker, nach hinten gebogen
			_limb(img, cx - 9, top, 4, 5, _c(&"bone"))
			_limb(img, cx + 5, top, 4, 5, _c(&"bone"))
			_limb(img, cx - 13, top + 1, 4, 4, _c(&"bone"))
			_limb(img, cx + 9, top + 1, 4, 4, _c(&"bone"))
			_rect(img, cx - 15, top + 5, 3, 4, _c(&"bone"))
		8:  # Heiligenschein: schwebt frei ueber dem Kopf
			_ellipse(img, cx, top, 8.5, 2.5, _c(&"accent"))
			_erase(img, cx, top, 6.0, 1.2)
		9:  # Kopfhoerer: Buegel oben, Muschel am Ohr
			_limb(img, cx - 8, top, 16, 3, _c(&"outline"))
			_limb(img, cx + 4, top + 10, 5, 7, _c(&"outline"))
			_rect(img, cx + 5, top + 12, 3, 3, _c(&"cloth_blue"))
		10:  # Eimerhut: gerade Krempe, hoher Topf
			_limb(img, cx - 12, top + 6, 24, 3, _c(&"reed"))
			_limb(img, cx - 7, top + 1, 14, 5, _c(&"reed"))
	img.resize(FRAME, FRAME, Image.INTERPOLATE_NEAREST)
	_save(img, "char_hat_%d" % index)
```

- [ ] **Schritt 4: Den Hut in der Szene an den Kopf hängen**

In `scenes/fishing/angler.gd`:

```gdscript
## Wohin der Hut relativ zum Kopfanker gehoert. Der Kopf ist 25 Pixel breit,
## seine Mitte liegt also 12 Pixel rechts vom Anker; der Hut sitzt oben auf.
## Am Bild abgenommen, nicht gerechnet -- die Kruempe verschiedener Huete
## sitzt verschieden tief, und dieser Wert passt sie gemeinsam an.
const HAT_OFFSET: Vector2i = Vector2i(-12, -2)
```

und am Ende von `set_pose()`, vor `_place_rod()`:

```gdscript
	_place_hat()
```

dazu:

```gdscript
## Der Hut folgt dem Kopf, ist aber kein Kind von ihm: gezeichnet wird er
## NACH den Armen, die Kopfgruppe aber davor.
func _place_hat() -> void:
	var kopf: Node2D = get_node("kopf")
	($Hat as Sprite2D).position = kopf.position + Vector2(HAT_OFFSET)
```

- [ ] **Schritt 5: Den Sprite-Test nachziehen**

In `tests/test_sprite_assets.gd` in `_expected_size` einen Zweig **vor** dem `char_`-Zweig einfügen:

```gdscript
	# Der Hut wird einmal gemalt und haengt am Kopf -- kein Bilderstreifen.
	if filename.begins_with("char_hat_"):
		return Vector2i(AnglerPose.FRAME_SIZE, AnglerPose.FRAME_SIZE)
```

- [ ] **Schritt 6: Bauen, prüfen, ansehen**

```
bash tools/godot.sh --headless --script tools/gen_sprites.gd --quit
bash tools/test.sh
```

Einen Bildschirmabzug mit gesetztem Hut **dem Menschen vorlegen**: sitzt er schief, ist `HAT_OFFSET` die eine Zahl, die es richtet.

- [ ] **Schritt 7: Commit**

```bash
git add tools/gen_sprites.gd scenes/fishing/angler.gd tests/test_angler_parts.gd \
        tests/test_sprite_assets.gd assets/art/char_hat_*.png
git commit -m "Der Hut haengt am Kopf und wird einmal gemalt"
```

---

## Aufgabe 5: Die gezeichnete Rute an die elf Armzustände

Der Griff sitzt an der Hand, und die Hand ist jetzt der Arm mit elf Zuständen. Dazu wechselt die Rute: das Spiel zeigt bis heute eine andere Zeichnung als die Vorschau.

> **Entschieden am 2026-09-07.** Es lagen zwei Ruten vor:
>
> | | Quelle | Länge | Ruhewinkel | Stil |
> |---|---|---|---|---|
> | Vorschau | `parts/rute_mit_griff.png` → `wurf_stab_0..9.png` | 76 px | 55,6° | Kupfer/Holz, Korkgriff, 19 Farben |
> | Spiel | `assets/source/rod_45.png` → `import_rod.py` | 150 px | 21,9° | grauer Schaft, große Rolle |
>
> **Die gezeichnete gilt** — sie ist die Rute der Figur, und die Vorschau zeigt sie seit je. `rute_mit_griff.png` ist bereits in die zehn Wurfwinkel gedreht (`tools/rute_anheften.py` schreibt `wurf_stab_0..9.png`); es gibt also nichts zu rechnen, nur einzusammeln.
>
> Die drei Kosmetikvarianten überleben: `rod_0` heißt **Bambusrute**, und die gezeichnete Rute ist braun in 19 Tönen — sie IST die Bambusrute. `rod_1` (Eichenrute) und `rod_2` (Silberrute) entstehen wie bisher durch Umfärben des Schafts. Eine frühere Notiz in diesem Plan behauptete, ein Umstieg koste die Varianten; das war falsch.
>
> `tools/import_rod.py` und `assets/source/rod_45.png` werden damit überflüssig und fallen in Aufgabe 6.

Nebenbei schrumpft das Rutenraster: vom Griff aus reicht die Rute höchstens 75 Pixel nach oben, 58 nach rechts, 47 nach links und 15 nach unten. Ein Feld von **160** fasst das mit Rand; heute sind es 320.

**Dateien:**
- Erstellen: `tools/rute_bauen.py`
- Löschen: `tools/tests/…` (nichts) — die Probe steht in `tests/test_sprite_assets.gd`
- Ändern: `core/angler_pose.gd`
- Ändern: `scenes/fishing/angler.gd` (`_place_rod`, `rod_tip`)
- Ändern: `scenes/fishing/angler.tscn` (`Rod.hframes`)
- Ändern: `tests/test_sprite_assets.gd`

**Schnittstellen:**
- Nutzt: `assets/source/figure/wurf_anker.json` — `{"griff": [160.0, 160.0], "feld": 320, "anker": [[70,68], …]}`, zehn Anker im 320er Feld; `assets/source/figure/wurf_stab_0..9.png`
- Liefert:
  - `AnglerPose.ROD_STATES: int = 11` (Ruhe plus zehn Wurfbilder)
  - `AnglerPose.ROD_FRAMES: int = 10`, `ROD_FRAME_SIZE: int = 160`, `ROD_GRIP := Vector2i(80, 80)`
  - `AnglerPose.ROD_ANCHOR/ROD_TIP_OFF/ROD_FRAME` mit elf Einträgen
  - `Angler.ROD_BREATH: int = 1`
  - `tools/rute_bauen.py`: `main()` schreibt `assets/art/char_rod_<v>.png`, 1600×160 je Variante

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

In `tests/test_sprite_assets.gd` anfügen:

```gdscript
## Der Griff der Rute muss in der Hand des ARMS liegen -- der Arm ist das
## Teil, das die Hand traegt, und er hat elf Zustaende. Frueher wurde gegen
## char_skin_0.png geprueft, die gebackene 24er-Reihe; die gibt es nicht mehr.
func test_der_griff_sitzt_in_der_hand_jedes_armzustands() -> void:
	var tex := TextureLoader.load_texture("%s/teil_arm_skin.png" % ART_DIR)
	assert_true(tex != null, "teil_arm_skin.png nicht ladbar")
	if tex == null:
		return
	var img := tex.get_image()
	var box: Rect2i = AnglerParts.BOX[&"arm"]
	for f in AnglerPose.ROD_STATES:
		var grip: Vector2i = AnglerPose.rod_grip(f)
		var p := Vector2i(f * box.size.x + grip.x - box.position.x,
			grip.y - box.position.y)
		assert_true(p.x >= 0 and p.x < img.get_width()
			and p.y >= 0 and p.y < img.get_height(),
			"Zustand %d: der Griff %s liegt ausserhalb des Armblatts" % [f, grip])
		if p.x < 0 or p.x >= img.get_width() or p.y < 0 or p.y >= img.get_height():
			continue
		# Um den Griff herum, nicht auf ihm: dort ist die Faust, und die Rute
		# wird darunter weggenommen.
		var herum := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q := Vector2i(p.x + dx, p.y + dy)
				if q.x < 0 or q.x >= img.get_width() \
					or q.y < 0 or q.y >= img.get_height():
					continue
				if img.get_pixel(q.x, q.y).a > 0.0:
					herum += 1
		assert_true(herum > 8,
			"Zustand %d: um den Griff liegt kaum Hand (%d Pixel)" % [f, herum])

func test_die_rute_hat_elf_zustaende() -> void:
	assert_eq(AnglerPose.ROD_ANCHOR.size(), AnglerPose.ROD_STATES)
	assert_eq(AnglerPose.ROD_TIP_OFF.size(), AnglerPose.ROD_STATES)
	assert_eq(AnglerPose.ROD_FRAME.size(), AnglerPose.ROD_STATES)

## Es ist EINE gezeichnete Rute, nur anders gehalten -- alle Zustaende tragen
## dieselbe Laenge. Frueher streckte jede Wurfpose sie auf ihren eigenen
## Versatz, und sie wurde waehrend des Wurfs sichtbar laenger und kuerzer.
func test_die_rute_behaelt_ihre_laenge() -> void:
	var erste := Vector2(AnglerPose.ROD_TIP_OFF[0]).length()
	for f in AnglerPose.ROD_STATES:
		assert_between(Vector2(AnglerPose.ROD_TIP_OFF[f]).length(),
			erste - 1.5, erste + 1.5,
			"Zustand %d: die Rute ist %.1f statt %.1f Pixel lang"
			% [f, Vector2(AnglerPose.ROD_TIP_OFF[f]).length(), erste])
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
bash tools/test.sh
```

Erwartet: rot mit „Invalid access to constant 'ROD_STATES'".

- [ ] **Schritt 3: Die Zahlen nachmessen**

Die Zahlen unten sind schon gemessen. Dieser Schritt rechnet sie nach — läuft etwas anderes heraus, hat sich die Quellkunst geändert, und dann gilt die neue Messung:

```bash
python3 - <<'ENDE'
import json, math, os
from PIL import Image
from tools import wurf_lauf as wl
SRC = "assets/source/figure"
d = json.load(open(os.path.join(SRC, "wurf_anker.json")))
griff = tuple(int(v) for v in d["griff"])
werte = [d["anker"][0]] + d["anker"]      # Ruhe = Wurfbild 0
print("ROD_ANCHOR:")
print("\t" + ", ".join("Vector2i(%d, %d)" % (a, b) for a, b in werte))
spitzen = []
for i, anker in enumerate(werte):
    stab = Image.open(os.path.join(SRC, "wurf_stab_%d.png"
                                   % (0 if i == 0 else i - 1))).convert("RGBA")
    sx, sy = wl.rutenspitze(stab, griff, anker)
    spitzen.append((sx - anker[0], sy - anker[1]))
print("ROD_TIP_OFF:")
print("\t" + ", ".join("Vector2i(%d, %d)" % p for p in spitzen))
print("Laengen:", [round(math.hypot(*p)) for p in spitzen])
li = re = ob = un = 0
for i in range(10):
    k = Image.open(os.path.join(SRC, "wurf_stab_%d.png" % i)).convert("RGBA").getbbox()
    li = max(li, griff[0]-k[0]); re = max(re, k[2]-griff[0])
    ob = max(ob, griff[1]-k[1]); un = max(un, k[3]-griff[1])
print("vom Griff: links %d rechts %d oben %d unten %d" % (li, re, ob, un))
ENDE
```

Erwartete Ausgabe (am 2026-09-07 gemessen):

```
ROD_ANCHOR:
	Vector2i(70, 68), Vector2i(70, 68), Vector2i(74, 63), Vector2i(76, 54), Vector2i(76, 47), Vector2i(75, 42), Vector2i(77, 48), Vector2i(76, 57), Vector2i(72, 66), Vector2i(67, 71), Vector2i(68, 70)
ROD_TIP_OFF:
	Vector2i(43, -63), Vector2i(43, -63), Vector2i(24, -72), Vector2i(-12, -75), Vector2i(-40, -65), Vector2i(-47, -60), Vector2i(-34, -68), Vector2i(14, -75), Vector2i(40, -65), Vector2i(56, -51), Vector2i(45, -61)
Laengen: [76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76]
vom Griff: links 47 rechts 58 oben 75 unten 15
```

Alle elf Längen sind gleich — `test_die_rute_behaelt_ihre_laenge` ist damit von selbst grün. Und 75 Pixel nach oben ist der weiteste Ausschlag: ein Feld von 160 mit dem Griff bei (80, 80) lässt an jeder Seite Rand.

- [ ] **Schritt 4: `angler_pose.gd` umstellen**

`core/angler_pose.gd` ganz ersetzen. Alles, was die 24er-Posenreihe beschrieb — `FRAMES`, `IDLE_FRAMES`, `BLINK_START`, `CAST_START`, `IDLE_ORDER` — fällt weg; es gibt keine Posenreihe mehr. `ROD_BEND` und `rod_point()` fallen ebenfalls: sie bogen eine gerechnete Rute nach, und die gezeichnete bringt ihre Biegung mit.

```gdscript
## Die Geometrie der Rute -- an EINER Stelle.
##
## Sie stand doppelt: der Bilderzeuger zeichnete die Rute, und die Welt hatte
## eine Konstante fuer deren Spitze. Beim Verschieben der Rute wurde die
## Konstante nicht mitgezogen, und die Schnur begann daneben.
##
## Die Rute ist gezeichnet (assets/source/figure/parts/rute_mit_griff.png) und
## von tools/rute_anheften.py in die zehn Wurfwinkel gedreht. Jeder Zustand
## hat seinen EIGENEN Griff und seine eigene Richtung: beim Ausholen zeigt sie
## nach hinten, beim Wurf nach vorn.
class_name AnglerPose
extends RefCounted

## 128 ist die Arbeitsgroesse des Figurenfelds.
const FRAME_SIZE: int = 128

## Elf Zustaende: Ruhe plus zehn Wurfbilder. Die Rute folgt dem ARM, denn dort
## ist die Faust. Zustand 0 teilt sich Bild und Griff mit Wurfbild 0 --
## sit3_arm_nah.png und wurf_arm_0.png sind byteweise dasselbe Bild.
const ROD_STATES: int = 11

## Wo der Griff im 128er Figurenfeld liegt, je Zustand. Gemessen an
## assets/source/figure/wurf_anker.json.
const ROD_ANCHOR: Array[Vector2i] = [
	Vector2i(70, 68), Vector2i(70, 68), Vector2i(74, 63), Vector2i(76, 54),
	Vector2i(76, 47), Vector2i(75, 42), Vector2i(77, 48), Vector2i(76, 57),
	Vector2i(72, 66), Vector2i(67, 71), Vector2i(68, 70)]

## Die Spitze, relativ zum Griff -- am gezeichneten Rutenbild abgenommen.
## Alle elf Zustaende tragen dieselbe Laenge: 76 Pixel.
const ROD_TIP_OFF: Array[Vector2i] = [
	Vector2i(43, -63), Vector2i(43, -63), Vector2i(24, -72),
	Vector2i(-12, -75), Vector2i(-40, -65), Vector2i(-47, -60),
	Vector2i(-34, -68), Vector2i(14, -75), Vector2i(40, -65),
	Vector2i(56, -51), Vector2i(45, -61)]

## --- Die Rute hat ihr EIGENES Bildraster ------------------------------------
##
## Beim Ausholen sitzt die Faust neben dem Kopf, und die Rute zeigt von dort
## nach hinten oben. Im 128er Feld der Figur ist an dieser Stelle wenig Platz.
## Vom Griff aus reicht sie hoechstens 75 Pixel nach oben, 58 nach rechts, 47
## nach links und 15 nach unten -- 160 fasst das mit Rand. Frueher standen
## hier 320, gerechnet fuer eine doppelt so lange Rute.
const ROD_FRAME_SIZE: int = 160
const ROD_GRIP: Vector2i = Vector2i(80, 80)
## Zehn gezeichnete Winkel; Ruhe und Wurfbild 0 teilen sich einen.
const ROD_FRAMES: int = 10
const ROD_FRAME: Array[int] = [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

static func frame_of(frame: int) -> int:
	return clampi(frame, 0, ROD_STATES - 1)

## Die Spitze fuer diesen Zustand -- dort setzt die Schnur an.
static func rod_tip(frame: int) -> Vector2i:
	var f := frame_of(frame)
	return ROD_ANCHOR[f] + ROD_TIP_OFF[f]

## Der Griff fuer diesen Zustand.
static func rod_grip(frame: int) -> Vector2i:
	return ROD_ANCHOR[frame_of(frame)]

## Wohin das Rutensprite muss, damit sein Griff auf dem Anker dieses Zustands
## liegt. Das Sprite ist groesser als das Figurenfeld und haengt deshalb an
## einer eigenen Position, nicht am gemeinsamen Bildindex.
static func rod_offset(frame: int) -> Vector2i:
	return ROD_ANCHOR[frame_of(frame)] - ROD_GRIP
```

- [ ] **Schritt 5: Das Bauwerkzeug schreiben**

`tools/rute_bauen.py` anlegen. Es sammelt nur ein und färbt um — gedreht ist schon:

```python
#!/usr/bin/env python3
"""Baut die Rutenblaetter aus der gezeichneten Rute.

    python3 -m tools.rute_bauen

Die Rute ist gezeichnet (parts/rute_mit_griff.png) und von
tools/rute_anheften.py in die zehn Wurfwinkel gedreht (wurf_stab_0..9.png).
Hier wird sie nur noch auf das Rutenraster geschnitten und fuer die drei
Kosmetikvarianten umgefaerbt.

Frueher stand hier tools/import_rod.py: es rechnete eine ANDERE Rute aus
assets/source/rod_45.png -- grauer Schaft, grosse Rolle, doppelt so lang.
Das Spiel zeigte damit eine andere Rute als die Vorschau.
"""
import os
import re

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(WURZEL, "assets", "source", "figure")
OUT = os.path.join(WURZEL, "assets", "art")
POSE = os.path.join(WURZEL, "core", "angler_pose.gd")

## Die gezeichnete Rute IST die Bambusrute (rod_0) -- braun in neunzehn
## Toenen. Eiche ist dunkler und roter, Silber ist entfaerbt und hell.
## Umgefaerbt wird wie in assets/art/palette_swap.gdshader: der Zielton mal
## der Helligkeit des Pixels, damit Maserung und Umriss erhalten bleiben.
VARIANTEN = [None, (0x6b, 0x4a, 0x2c), (0xb9, 0xc3, 0xc8)]


def _zahl(name):
    text = open(POSE, encoding="utf-8").read()
    return int(re.search(r"const %s: int = (\d+)" % name, text).group(1))


def _vektor(name):
    text = open(POSE, encoding="utf-8").read()
    m = re.search(r"const %s: Vector2i = Vector2i\((-?\d+),\s*(-?\d+)\)"
                  % name, text)
    return (int(m.group(1)), int(m.group(2)))


def faerben(bild, ton):
    """Den Schaft auf diesen Ton bringen, Helligkeit behalten."""
    if ton is None:
        return bild.copy()
    aus = bild.copy()
    px = aus.load()
    for y in range(aus.size[1]):
        for x in range(aus.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            ## Dieselbe Kurve wie der Shader: 0.55 + 0.9 * Helligkeit.
            luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            k = 0.55 + 0.9 * luma
            px[x, y] = (min(255, int(ton[0] * k)), min(255, int(ton[1] * k)),
                        min(255, int(ton[2] * k)), a)
    return aus


def main():
    feld = _zahl("ROD_FRAME_SIZE")
    bilder = _zahl("ROD_FRAMES")
    gx, gy = _vektor("ROD_GRIP")
    ## Im Quellbild liegt der Griff in der Mitte des 320er Felds.
    qx = qy = 160
    for v, ton in enumerate(VARIANTEN):
        blatt = Image.new("RGBA", (feld * bilder, feld), (0, 0, 0, 0))
        for i in range(bilder):
            stab = Image.open(os.path.join(SRC, "wurf_stab_%d.png" % i)) \
                .convert("RGBA")
            ## Den Griff des Quellbilds auf den Griff des Zielrasters legen.
            aus = stab.crop((qx - gx, qy - gy, qx - gx + feld,
                             qy - gy + feld))
            blatt.alpha_composite(faerben(aus, ton), (i * feld, 0))
        blatt.save(os.path.join(OUT, "char_rod_%d.png" % v))
        print("char_rod_%d.png  %dx%d" % (v, blatt.size[0], blatt.size[1]))
    print("%d Rutenblaetter geschrieben" % len(VARIANTEN))


if __name__ == "__main__":
    main()
```

- [ ] **Schritt 6: Die Rutenblätter bauen und ansehen**

```
python3 -m tools.rute_bauen
```

Erwartet: drei Blätter 1600×160. Ein Bild aller drei Varianten nebeneinander erzeugen und **dem Menschen vorlegen** — Bambus, Eiche, Silber müssen unterscheidbar sein und alle drei wie dieselbe Rute aussehen.

- [ ] **Schritt 7: Die Szene und `angler.gd` nachziehen**

In `scenes/fishing/angler.tscn` beim Rod-Knoten `hframes = 10`.

In `scenes/fishing/angler.gd` `_place_rod` und `rod_tip` ersetzen:

```gdscript
## Ein Pixel Atem. Im Ruhelauf hat der Arm nur einen Zustand, die Faust steht
## also still -- ohne diesen Versatz haengt die Rute reglos an einer atmenden
## Figur. Weil die Spitze 76 Pixel entfernt liegt, wird aus dem einen Pixel am
## Griff eine sichtbare Bewegung am Ende.
const ROD_BREATH: int = 1

func _place_rod() -> void:
	var rod: Sprite2D = $Rod
	rod.frame = AnglerPose.ROD_FRAME[AnglerPose.frame_of(_arm)]
	rod.position = Vector2(AnglerPose.rod_offset(_arm)) \
		+ Vector2(0, float(_atem * ROD_BREATH))

func rod_tip() -> Vector2:
	return position + (Vector2(AnglerPose.rod_tip(_arm))
		+ Vector2(0, float(_atem * ROD_BREATH))) * scale
```

- [ ] **Schritt 8: Die alten Rutentests anpassen**

In `tests/test_sprite_assets.gd`:

- `test_the_rod_keeps_its_length_in_every_pose` löschen — Schritt 1 hat es als `test_die_rute_behaelt_ihre_laenge` ersetzt.
- `test_the_grip_sits_in_the_hand_in_every_frame` löschen — Schritt 1 hat es ersetzt.
- `test_the_rod_fits_inside_its_own_frame` löschen: es lief über `rod_point()`, das mit `ROD_BEND` weggefallen ist. Der Rahmen wird stattdessen von `test_no_rod_frame_bleeds_into_the_next` geprüft, das den Rand selbst ansieht.
- In `test_no_rod_frame_bleeds_into_the_next`, `test_the_rod_tip_is_where_the_pixels_are_in_every_frame` und `test_the_rod_is_an_unbroken_line` jedes `AnglerPose.FRAMES` durch `AnglerPose.ROD_STATES` ersetzen und `AnglerPose.ROD_FRAME[f]` als Bildindex nehmen.

- [ ] **Schritt 9: Ganze Suite**

```
bash tools/test.sh
```

- [ ] **Schritt 10: Commit**

```bash
git add core/angler_pose.gd tools/rute_bauen.py scenes/fishing/angler.gd \
        scenes/fishing/angler.tscn tests/test_sprite_assets.gd assets/art/char_rod_*.png
git commit -m "Die gezeichnete Rute im Spiel, an den elf Armzustaenden"
```

---

## Aufgabe 6: Die alten Blätter weg

Die gebackenen `char_*`-Reihen lädt niemand mehr. Sie fallen, und mit ihnen das Werkzeug, das sie erzeugt hat.

**Dateien:**
- Löschen: `assets/art/char_skin_*.png`, `char_shirt_*.png`, `char_pants_*.png`, `char_hair_*.png`, `char_base_*.png`
- Löschen: `tools/import_character.py`, `tools/import_rod.py`, `assets/source/rod_45.png`
- Ändern: `tests/test_character_layers.gd`
- Ändern: `tests/test_sprite_assets.gd`

**Schnittstellen:**
- Nutzt: `AnglerParts.ORDER`, `AnglerParts.LAYERS`, `AnglerParts.BOX`, `AnglerParts.STATES`

- [ ] **Schritt 1: Den Test umschreiben**

`tests/test_character_layers.gd` ersetzen. Die Zusicherung bleibt dieselbe — ein Pixel gehört genau einer Ebene —, aber sie gilt jetzt je Teil und je Zustand:

```gdscript
extends TestCase

const ART_DIR := "res://assets/art"

## Ein Pixel gehoert genau EINER Kosmetikebene. Vorher lag derselbe Pixel in
## mehreren: der Rock steckte gleichzeitig in "hair" und in "base", weil die
## Zuordnung ueber Bildzeilen abgestimmt statt nachgeschlagen wurde.
##
## Geprueft wird jetzt je TEIL und je ZUSTAND: die Blaetter sind auf ihren
## Rahmen zugeschnitten, ein gemeinsames Feld gibt es nicht mehr.
func test_die_ebenen_eines_teils_ueberlappen_sich_nirgends() -> void:
	for name in AnglerParts.ORDER:
		var bilder: Array[Image] = []
		for ebene in AnglerParts.LAYERS[name]:
			var tex := TextureLoader.load_texture(
				"%s/teil_%s_%s.png" % [ART_DIR, name, ebene])
			assert_true(tex != null, "teil_%s_%s.png nicht ladbar"
				% [name, ebene])
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
		assert_eq(doppelt, 0,
			"%s: %d Pixel liegen in mehr als einer Ebene" % [name, doppelt])

## Die Grundebene traegt Umriss, Auge und Kragen -- nicht die halbe Figur.
## Sie wird nie umgefaerbt; was in ihr liegt, bleibt bei jeder Kosmetik gleich.
func test_die_grundebene_ist_nicht_die_halbe_figur() -> void:
	var gesamt := 0
	var basis := 0
	for name in AnglerParts.ORDER:
		for ebene in AnglerParts.LAYERS[name]:
			var tex := TextureLoader.load_texture(
				"%s/teil_%s_%s.png" % [ART_DIR, name, ebene])
			if tex == null:
				continue
			var img := tex.get_image()
			var sichtbar := 0
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).a > 0.0:
						sichtbar += 1
			gesamt += sichtbar
			if ebene == &"base":
				basis += sichtbar
	assert_true(gesamt > 0, "keine Teileblaetter gefunden")
	assert_true(float(basis) / float(gesamt) < 0.35,
		"die Grundebene traegt %d von %d Pixeln" % [basis, gesamt])
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```
bash tools/test.sh
```

Erwartet: grün, denn die Blätter liegen schon. Bleibt `test_die_grundebene_ist_nicht_die_halbe_figur` rot, den Anteil an der gemessenen Zahl ausrichten und den Wert im Kommentar nennen — nicht raten.

- [ ] **Schritt 3: Die alten Blätter löschen**

```bash
git rm assets/art/char_skin_*.png assets/art/char_shirt_*.png \
       assets/art/char_pants_*.png assets/art/char_hair_*.png \
       assets/art/char_base_*.png
git rm tools/import_character.py tools/import_rod.py assets/source/rod_45.png
```

`import_rod.py` rechnete die Rute aus `rod_45.png` — eine andere Zeichnung als die der Figur. Seit Aufgabe 5 kommt die Rute aus `tools/rute_bauen.py`.

`char_rod_*.png` und `char_hat_*.png` **bleiben** — die Rute und der Hut sind eigene Sprites.

- [ ] **Schritt 4: Den Sprite-Test aufräumen**

In `tests/test_sprite_assets.gd` `test_no_character_frame_bleeds_into_the_next` löschen: es lief über `char_*`-Dateien mit dem 128er Raster, und die gibt es nicht mehr. Die Teileblätter berühren ihren Rand **absichtlich** — sie sind auf ihn zugeschnitten.

Der allgemeine `char_`-Zweig fällt ersatzlos:

```gdscript
	if filename.begins_with("char_"):
		return Vector2i(AnglerPose.FRAME_SIZE * AnglerPose.FRAMES, AnglerPose.FRAME_SIZE)
```

Die Zweige für `char_rod_` und `char_hat_` stehen schon darüber — der eine seit
je, der andere aus Aufgabe 4. Nach dem Umbau tragen nur noch diese beiden den
`char_`-Namen; die Figur selbst liegt in `teil_*.png`, je Teil auf ihren
eigenen Rahmen geschnitten.

- [ ] **Schritt 5: Die Speicherbilanz messen**

```bash
python3 -c "
from PIL import Image
import glob, os
def summe(m):
    px = n = 0
    for p in glob.glob(m):
        b = Image.open(p); px += b.size[0]*b.size[1]; n += 1
    return n, px
print('teil_*:', summe('assets/art/teil_*.png'))
print('char_*:', summe('assets/art/char_*.png'))
"
```

Die Zahlen **dem Menschen vorlegen** und in der Spec unter „Die Blätter" nachtragen.

- [ ] **Schritt 6: Ganze Suite und Spiel**

```
bash tools/test.sh
bash tools/godot.sh --headless --quit-after 300 2>&1 | tail -5
```

- [ ] **Schritt 7: Commit**

```bash
git add -A assets/art tests tools
git commit -m "Die gebackenen Posenreihen fallen weg"
```

---

## Selbstprüfung gegen die Spec

| Anforderung der Spec | Aufgabe |
|---|---|
| Je Teil eine Gruppe, je Ebene ein Sprite | 2 |
| Zeichenreihenfolge Zopf…Rute, Kopf über Rumpf, Hals dahinter | 2 (Test `test_die_zeichenreihenfolge_stimmt`) |
| Reihenfolge im Teil: Haut, Hose, Pullover, Haar, Grundebene | 2 (`LAYER_ORDER`) |
| Hut an der Kopfgruppe, Kopfmitten in `gen_sprites.gd` entfallen | 4 |
| `ROD_ANCHOR` von 24 auf 11 | 5 |
| Atem und Zopf aus der Atemphase, dieselben Formeln | 3 |
| Beinweite im Umkehrpunkt neu gezogen, 2…6 | 3 |
| Blinzeln halb/zu/halb, 55/90/55 ms | 3 |
| Wurf über `CAST_TIME`, Kopf zurück, Beine nach `BEIN_WURF` | 3 |
| Rute atmet mit, ein Pixel als Startwert | 5 |
| `import_character.py` fällt weg | 6 |
| `char_skin_1..8` usw. fallen weg | 6 |
| Kein Loch über alle Kombinationen | steht seit Stufe 1 in `tools/tests/test_preview_parts.py` |
| Kein Pixel doppelt | 6 (`test_character_layers.gd`, jetzt je Teil) |
| Vorschau und Spiel stimmen überein | 3 (`test_angler_motion.gd`) |
| Anker sitzen, wo gemessen | 2 (`test_jedes_teil_sitzt_auf_seinem_anker`) |
| `test_sprite_assets.gd` wächst mit | 1, 4, 5, 6 |

**Reihenfolge, entschieden am 2026-09-07:** erst die Figur und ihre Bewegung
vollständig, Kosmetik danach. Die Rute bleibt in diesem Plan — sie hängt an der
Hand, und die Schnur hängt an ihrer Spitze, also ist sie Bewegung und nicht
Schmuck. Ihre drei Varianten, die Hutgrößen und Stufe 4 sind Kosmetik.

**Nicht in diesem Plan, ausdrücklich:**

- **Die Hutgrößen.** Aufgabe 4 hat sie vom doppelten auf das einfache Raster
  gebracht, weil sie sonst doppelt so breit wie der Kopf standen. Die Höhe
  stimmt; abgenommen am 2026-09-07 mit dem Vermerk „eventuell etwas größer".
  Das hieße, die Zahlen in `gen_sprites.gd::_hat` einzeln um rund 1,4
  hochzuziehen — eine Kosmetikarbeit, und die kommt später.

- **Stufe 4 (Varianten als Tönung).** `char_skin_1..8` und Geschwister fallen in Aufgabe 6 weg; die Tönung der Haut-, Pullover- und Hosenebene ist eine eigene Stufe, weil sie die Kosmetikdaten berührt.
- **Welche Rute gilt — entschieden am 2026-09-07:** die gezeichnete. Sie steht in Aufgabe 5. `tools/import_rod.py` und `assets/source/rod_45.png` fallen damit in Aufgabe 6.
- **Die Blinzelfarben.** `figure_parts.AUGE_HALB` und `AUGE_ZU` malen `#e88474` und `#030201` — Töne, die in `sit3_rumpf.png` vorkommen (23- bzw. 121-mal), dort aber die selteneren sind; die Nachbarn des Auges tragen `#e48c79` und `#05000a`. Fünf Pixel, eine Aussehensfrage.
