# Steine flitschen — Umsetzungsplan

> **Für agentische Bearbeiter:** ERFORDERLICHE UNTER-FÄHIGKEIT: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte benutzen Kästchen (`- [ ]`) zum Abhaken.

**Ziel:** Ein Zeitvertreib für die 30–60 Sekunden zwischen zwei Bissen — einen Kiesel vom Ufer nehmen, über einen Ladebalken Kraft aufbauen und den Stein übers Wasser flitschen lassen.

**Aufbau:** Die Regel liegt knotenfrei in `core/stones.gd` und ist damit genauso testbar wie `core/reeds.gd`. Die Form des Ladebalkens steht **nur** im Bild `assets/art/ladebalken.png`; daraus entsteht zur Laufzeit eine `BitMap`, durch die Füllung und goldenes Band gemalt werden — dieselbe Lehre wie bei der Klinge, es gibt die Form genau einmal. Der Kieselhaufen am Ufer folgt dem Vorbild `scenes/fishing/reed_patch.gd`.

**Werkzeuge:** Godot 4.7.2, GDScript, Python 3 mit Pillow für die Bilder. Tests laufen über `bash tools/test.sh`.

**Spec:** `docs/superpowers/specs/2026-09-19-steine-flitschen-design.md`

## Durchgehende Vorgaben

Diese vier Regeln stehen über jedem Detail. Jede Aufgabe muss sie einhalten:

1. **Kein Ertrag.** Ein Wurf ändert weder Münzen, Köder, Erfahrung noch Inventar.
2. **Nichts zu verpassen.** Nichts läuft ab, nichts sammelt sich an.
3. **Kein Nachteil.** Steine verscheuchen keine Fische; die Bisszeit wird nicht angefasst.
4. **Kein Fisch geht verloren.** Beim Anbiss verschwindet der Balken von selbst.

Weitere Vorgaben aus dem Projekt:

- **Weltmaßstab 2,16** (`DOCK_SCALE`/`ANGLER_SCALE`/`SKALA`) — ein Pixel ist ein Pixel. Nichts wird skaliert gezeichnet.
- **Pixelbilder werden nicht verschoben, geschert oder gedreht.** Bewegung entsteht aus gezeichneten Bildern oder aus gemalten Formen, nicht aus verzerrten.
- **Kommentare 1–2 Zeilen, das Warum statt des Was.**
- **Keine Secrets im Repo.** Keine Attributionszeilen in Commits.
- Farben ausschließlich aus `core/palette.gd`.

---

### Aufgabe 1: Die Regel

**Dateien:**
- Anlegen: `core/stones.gd`
- Anlegen: `tests/test_stones.gd`
- Ändern: `tests/run_tests.gd` (Datei in die Liste eintragen)

**Schnittstellen:**
- Verbraucht: nichts.
- Liefert: `Stones.ladung(zeit: float) -> float`, `Stones.band_mitte(zeit: float) -> float`, `Stones.im_band(ladung: float, zeit: float) -> bool`, `Stones.spruenge(ladung: float, im_band: bool) -> int`, sowie die Konstanten `ZYKLUS`, `BAND_WEG`, `BAND_HOEHE`, `BAND_UNTEN`, `BAND_OBEN`, `PLUMPS`, `GRUND_MAX`, `BAND_BONUS`.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

`tests/test_stones.gd`:

```gdscript
extends TestCase

## Steine flitschen. Geprueft wird die Rechnung, nicht das Bild: wie die
## Ladung schwingt, wo das goldene Band steht und was ein Wurf einbringt.

## Die Ladung schwingt dreieckig: gleichmaessig hoch, gleichmaessig runter.
## Ein Sinus haengt oben fest, und dann wird das Zielen zaeh.
func test_the_charge_rises_and_falls_evenly() -> void:
	assert_almost_eq(Stones.ladung(0.0), 0.0, 0.001, "faengt nicht unten an")
	assert_almost_eq(Stones.ladung(Stones.ZYKLUS * 0.5), 1.0, 0.001,
		"ist nach der halben Runde nicht oben")
	assert_almost_eq(Stones.ladung(Stones.ZYKLUS), 0.0, 0.001,
		"ist nach einer vollen Runde nicht wieder unten")
	# Gleichmaessig: ein Viertel hoch ist die Haelfte.
	assert_almost_eq(Stones.ladung(Stones.ZYKLUS * 0.25), 0.5, 0.001)
	assert_almost_eq(Stones.ladung(Stones.ZYKLUS * 0.75), 0.5, 0.001)

## Und sie bleibt oben nicht stehen -- wer zu spaet loslaesst, bekommt den
## naechsten Anlauf statt einer Strafe.
func test_the_charge_never_sticks_at_the_top() -> void:
	var oben := 0
	var schritte := 600
	for i in schritte:
		if Stones.ladung(float(i) * 0.01) > 0.98:
			oben += 1
	assert_true(oben < schritte / 8,
		"die Ladung steht in %d von %d Messungen oben" % [oben, schritte])

## Das Band wandert in seinem Bereich und kehrt an den Enden um.
func test_the_band_wanders_between_its_bounds() -> void:
	var tief := 2.0
	var hoch := -1.0
	for i in 400:
		var m := Stones.band_mitte(float(i) * 0.05)
		tief = minf(tief, m)
		hoch = maxf(hoch, m)
	assert_almost_eq(tief, Stones.BAND_UNTEN, 0.02, "kommt nicht tief genug")
	assert_almost_eq(hoch, Stones.BAND_OBEN, 0.02, "kommt nicht hoch genug")

## Und es wandert LANGSAMER als die Ladung schwingt -- sonst ist es Glueck
## statt Zielen.
func test_the_band_moves_slower_than_the_charge() -> void:
	assert_true(Stones.BAND_WEG * 2.0 > Stones.ZYKLUS * 2.0,
		"das Band ist nicht deutlich langsamer als die Ladung")

## Im Band heisst: die Ladung liegt hoechstens eine halbe Bandhoehe von
## seiner Mitte entfernt.
func test_the_band_catches_only_what_is_inside_it() -> void:
	var zeit := 3.0
	var m := Stones.band_mitte(zeit)
	assert_true(Stones.im_band(m, zeit), "die Mitte des Bandes zaehlt nicht")
	assert_true(Stones.im_band(m + Stones.BAND_HOEHE * 0.45, zeit),
		"der obere Rand zaehlt nicht")
	assert_false(Stones.im_band(m + Stones.BAND_HOEHE * 0.75, zeit),
		"knapp ausserhalb zaehlt trotzdem")

## Die Sprungtabelle aus der Spec, an jeder Grenze.
func test_the_skip_table_holds_at_every_edge() -> void:
	assert_eq(Stones.spruenge(0.0, false), 0, "ganz unten gibt es Spruenge")
	assert_eq(Stones.spruenge(Stones.PLUMPS - 0.01, false), 0,
		"knapp unter der Grenze gibt es Spruenge")
	assert_eq(Stones.spruenge(Stones.PLUMPS, false), 1,
		"an der Grenze gibt es keinen Sprung")
	assert_eq(Stones.spruenge(1.0, false), Stones.GRUND_MAX,
		"voll aufgeladen gibt nicht das Maximum")
	assert_eq(Stones.spruenge(1.0, true), Stones.GRUND_MAX + Stones.BAND_BONUS,
		"das Band gibt seinen Zuschlag nicht")

## Ein Plumps bleibt ein Plumps, auch im Band -- sonst waere die schwaechste
## Ladung die beste, wenn das Band gerade unten steht.
func test_a_dud_stays_a_dud_even_inside_the_band() -> void:
	assert_eq(Stones.spruenge(0.0, true), 0)

## Mehr Ladung gibt nie weniger Spruenge.
func test_more_charge_is_never_worse() -> void:
	var vorher := -1
	for i in 101:
		var s := Stones.spruenge(float(i) / 100.0, false)
		assert_true(s >= vorher, "bei Ladung %f faellt die Zahl" % (float(i) / 100.0))
		vorher = s
```

Eintragen in `tests/run_tests.gd`, in der Dateiliste hinter `"res://tests/test_reeds.gd"`:

```gdscript
	"res://tests/test_stones.gd",
```

- [ ] **Schritt 2: Test laufen lassen und das Fehlschlagen sehen**

Ausführen: `bash tools/test.sh`
Erwartet: `SUITE KAPUTT test_stones.gd` oder ein Parse-Fehler, weil `Stones` nicht existiert.

- [ ] **Schritt 3: Die Regel schreiben**

`core/stones.gd`:

```gdscript
## Steine flitschen: der Zeitvertreib fuer die Wartezeit zwischen zwei Bissen.
##
## Nur die Rechnung, keine Knoten -- damit die Tests nachrechnen koennen, was
## am fertigen Bild nicht zu pruefen waere (siehe core/reeds.gd).
##
## Vier Regeln stehen ueber allen Zahlen hier: kein Ertrag, nichts zu
## verpassen, kein Nachteil, kein verlorener Fisch. Wer eine davon aufweicht,
## macht aus einem Zeitvertreib eine Aufgabe.
class_name Stones
extends RefCounted

## Ein voller Weg der Ladung: hoch und wieder runter.
const ZYKLUS: float = 1.8
## Wie lange das Band fuer EINEN Weg braucht. Deutlich langsamer als die
## Ladung, sonst faengt man es nur zufaellig.
const BAND_WEG: float = 5.5
## Hoehe des Bandes als Anteil der Balkenhoehe.
const BAND_HOEHE: float = 0.12
const BAND_UNTEN: float = 0.25
const BAND_OBEN: float = 0.85

## Darunter plumpst der Stein nur.
const PLUMPS: float = 0.15
## Was die Ladung allein hoechstens einbringt.
const GRUND_MAX: int = 6
const BAND_BONUS: int = 2

## Dreieckig, nicht sinusfoermig: gleichmaessig hoch, gleichmaessig runter.
## Ein Sinus verweilt an den Enden, und dann haengt der Balken oben fest.
static func ladung(zeit: float) -> float:
	var p := fposmod(zeit / ZYKLUS, 1.0)
	return 1.0 - absf(p * 2.0 - 1.0)

## Die Mitte des goldenen Bandes. Kehrt an den Enden um, statt zurueckzu-
## springen -- ein Sprung sieht aus wie ein Fehler.
static func band_mitte(zeit: float) -> float:
	var p := fposmod(zeit / (BAND_WEG * 2.0), 1.0)
	return lerpf(BAND_UNTEN, BAND_OBEN, 1.0 - absf(p * 2.0 - 1.0))

static func im_band(wert: float, zeit: float) -> bool:
	return absf(wert - band_mitte(zeit)) <= BAND_HOEHE * 0.5

## Was ein Wurf einbringt -- eine Zahl, kein Gegenstand.
static func spruenge(wert: float, getroffen: bool) -> int:
	if wert < PLUMPS:
		return 0
	var anteil := (wert - PLUMPS) / (1.0 - PLUMPS)
	var grund := clampi(1 + int(round(anteil * float(GRUND_MAX - 1))),
		1, GRUND_MAX)
	return grund + (BAND_BONUS if getroffen else 0)
```

- [ ] **Schritt 4: Tests laufen lassen**

Ausführen: `bash tools/test.sh`
Erwartet: alle Tests grün, `0 fehlgeschlagen`.

- [ ] **Schritt 5: Committen**

```bash
git add core/stones.gd tests/test_stones.gd tests/run_tests.gd
git commit -m "Die Regel fuers Steineflitschen"
```

---

### Aufgabe 2: Die Bilder

**Dateien:**
- Anlegen: `tools/kiesel_bauen.py`
- Anlegen: `assets/art/ladebalken.png` (erzeugt)
- Anlegen: `assets/art/kiesel.png` (erzeugt)
- Vorhanden: `assets/source/steine/kiesel.png` (Rohbild von PixelLab, liegt schon im Repo)
- Ändern: `tests/test_sprite_assets.gd`

**Schnittstellen:**
- Verbraucht: nichts aus Aufgabe 1.
- Liefert: `assets/art/ladebalken.png` (38 × 56 Bildpunkte, Umriss in `stone_light`) und `assets/art/kiesel.png` (39 × 14 Bildpunkte).

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

In `tests/test_sprite_assets.gd`, in der Größentabelle (neben dem Eintrag für `klinge.png`):

```gdscript
	# Der Ladebalken haelt NUR den Umriss -- Fuellung und goldenes Band malt
	# stone_throw.gd zur Laufzeit durch seine Maske. Eine Form, ein Bild.
	if filename == "ladebalken.png":
		return Vector2i(38, 56)
	if filename == "kiesel.png":
		return Vector2i(39, 14)
```

- [ ] **Schritt 2: Test laufen lassen und das Fehlschlagen sehen**

Ausführen: `bash tools/test.sh`
Erwartet: `test_sprite_assets.gd::test_all_sprites_have_correct_size_and_are_not_empty` schlägt fehl, weil die beiden Dateien noch nicht existieren.

- [ ] **Schritt 3: Das Werkzeug schreiben**

`tools/kiesel_bauen.py`:

```python
"""Der Kieselhaufen am Ufer und der Ladebalken fuers Steineflitschen.

    python3 -m tools.kiesel_bauen

Der Haufen kommt von PixelLab und liegt roh unter
assets/source/steine/kiesel.png. Das genauere Modell dort nimmt KEINE
Zwangspalette, das Rohbild hat also einunddreissig eigene Farben -- hier
rasten sie auf die vier neutralen Grautoene der Spielpalette ein. Die
braeunlichen Steinfarben sind ausdruecklich nicht dabei: mit ihnen sah der
Haufen matschig aus statt steinern. Sonst wird nur beschnitten -- kein
Drehen, kein Verkleinern: ein Pixel bleibt ein Pixel.

Der Ladebalken ist eine Sichel -- Kreis minus versetzter Kreis --, oben
gerade gekappt und gespiegelt, also breit oben und spitz nach links unten.
Er haelt NUR den Umriss; Fuellung und goldenes Band malt das Spiel zur
Laufzeit durch seine Maske. Damit gibt es die Form genau einmal, und
Zeichnung und Rechnung koennen nicht auseinanderlaufen.
"""
import math
import os
import re

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PALETTE = os.path.join(WURZEL, "core", "palette.gd")
KUNST = os.path.join(WURZEL, "assets", "art")
ROH_KIESEL = os.path.join(WURZEL, "assets", "source", "steine", "kiesel.png")

## Die drei Kreiszahlen des Balkens. Muessen zu der Groesse passen, die
## tests/test_sprite_assets.gd festhaelt.
R = 58.0 * 0.62
VERSATZ = 26.0 * 0.62
R_SCHNITT = 62.0 * 0.62
## Wie viel der oberen Haelfte weggeschnitten wird -- das gibt die gerade
## breite Kante oben.
KAPPUNG = 0.55


def farbe(name):
    """Einen Farbnamen aus core/palette.gd nachschlagen."""
    with open(PALETTE, encoding="utf-8") as f:
        text = f.read()
    treffer = re.search(r'&"%s":\s*Color\("([0-9a-fA-F]{6})"\)' % name, text)
    if treffer is None:
        raise SystemExit("Farbe %s steht nicht in core/palette.gd" % name)
    h = treffer.group(1)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def _drin(x, y):
    return (math.hypot(x, y) <= R
            and math.hypot(x - VERSATZ, y) >= R_SCHNITT)


def ladebalken():
    """Der Umriss des Balkens, gespiegelt: Spitze nach links unten."""
    xh = (R * R - R_SCHNITT * R_SCHNITT + VERSATZ * VERSATZ) / (2.0 * VERSATZ)
    yh = math.sqrt(max(R * R - xh * xh, 0.0))
    y0 = -yh * KAPPUNG
    hoehe = int(round(yh - y0))
    spalten = [x for x in range(int(-R) - 2, int(R) + 2)
               if any(_drin(x + 0.5, y0 + y + 0.5) for y in range(hoehe))]
    x0 = min(spalten)
    breite = max(spalten) - x0 + 1
    bild = Image.new("RGBA", (breite, hoehe), (0, 0, 0, 0))
    umriss = farbe("stone_light")
    for y in range(hoehe):
        for x in range(breite):
            if _drin(x0 + x + 0.5, y0 + y + 0.5):
                # Gespiegelt: die Spitze zeigt nach links unten.
                bild.putpixel((breite - 1 - x, y), umriss)
    print("  ladebalken %dx%d" % (breite, hoehe))
    return bild


## Nur die neutralen Grautoene. stone und stone_light sind braeunlich und
## machten den Haufen matschig.
KIESEL_FARBEN = ("outline", "fur_dark", "fur", "fur_light")


def kiesel():
    """Das rohe Bild beschnitten und auf die Palette eingerastet."""
    bild = Image.open(ROH_KIESEL).convert("RGBA")
    zu = bild.crop(bild.getbbox())
    erlaubt = [farbe(n)[:3] for n in KIESEL_FARBEN]
    px = zu.load()
    for y in range(zu.height):
        for x in range(zu.width):
            q = px[x, y]
            if q[3] == 0:
                continue
            nah = min(erlaubt,
                      key=lambda c: sum((c[i] - q[i]) ** 2 for i in range(3)))
            px[x, y] = nah + (255,)
    print("  kiesel %dx%d" % (zu.width, zu.height))
    return zu


def main():
    os.makedirs(KUNST, exist_ok=True)
    for name, bild in (("ladebalken.png", ladebalken()),
                       ("kiesel.png", kiesel())):
        bild.save(os.path.join(KUNST, name))
        print("%s  %dx%d" % (name, bild.width, bild.height))


if __name__ == "__main__":
    main()
```

- [ ] **Schritt 4: Das Werkzeug laufen lassen und die Größen prüfen**

Ausführen: `python3 -m tools.kiesel_bauen`
Erwartet: `ladebalken 38x56` und `kiesel 39x14`.

Weichen die Zahlen ab, ist **der Test** die Wahrheit über die gewollte Größe — dann `R`, `VERSATZ`, `R_SCHNITT` nachziehen, nicht den Test.

- [ ] **Schritt 5: Tests laufen lassen**

Ausführen: `bash tools/test.sh`
Erwartet: alle grün.

- [ ] **Schritt 6: Committen**

```bash
git add tools/kiesel_bauen.py assets/art/ladebalken.png assets/art/kiesel.png tests/test_sprite_assets.gd
git commit -m "Ladebalken und Kieselhaufen"
```

---

### Aufgabe 3: Der Balken ist seine eigene Form

**Dateien:**
- Ändern: `core/stones.gd`
- Ändern: `tests/test_stones.gd`

**Schnittstellen:**
- Verbraucht: `assets/art/ladebalken.png` aus Aufgabe 2.
- Liefert: `Stones.maske() -> BitMap`, `Stones.balken_groesse() -> Vector2i`, `Stones.gefuellt(zeile: int, wert: float) -> bool`, Konstanten `BALKEN_BILD`, `MASKE_SCHWELLE`.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

An `tests/test_stones.gd` anhängen:

```gdscript
## Der gezeichnete Balken ist die Form, mit der gerechnet wird. Bei der
## Klinge hat genau das vier Anlaeufe gekostet, weil die Form zweimal
## gerechnet wurde -- hier gibt es sie von Anfang an nur einmal.
func test_the_bar_is_its_own_shape() -> void:
	var g := Stones.balken_groesse()
	assert_true(g.x > 8 and g.y > 8, "der Balken ist leer")
	var gemalt := 0
	for y in g.y:
		for x in g.x:
			if Stones.maske().get_bit(x, y):
				gemalt += 1
	assert_true(gemalt > 200, "der Balken hat fast keine Flaeche")

## Oben ist er breit, unten laeuft er spitz aus -- das ist die Form aus der
## Vorlage, und daran haengt, dass sich das Fuellen von unten gut liest.
func test_the_bar_is_wide_on_top_and_pointed_below() -> void:
	var g := Stones.balken_groesse()
	var oben := 0
	var unten := 0
	for x in g.x:
		if Stones.maske().get_bit(x, 0):
			oben += 1
		if Stones.maske().get_bit(x, g.y - 1):
			unten += 1
	assert_true(oben > unten,
		"oben %d Punkte breit, unten %d -- die Spitze sitzt falsch"
			% [oben, unten])

## Gefuellt wird von UNTEN nach oben: Zeile 0 ist oben im Bild.
func test_the_bar_fills_from_the_bottom() -> void:
	var g := Stones.balken_groesse()
	assert_true(Stones.gefuellt(g.y - 1, 0.5), "unten ist bei halb leer")
	assert_false(Stones.gefuellt(0, 0.5), "oben ist bei halb schon voll")
	assert_true(Stones.gefuellt(0, 1.0), "voll ist oben nicht gefuellt")
	assert_false(Stones.gefuellt(g.y - 1, 0.0), "leer ist unten gefuellt")
```

- [ ] **Schritt 2: Test laufen lassen und das Fehlschlagen sehen**

Ausführen: `bash tools/test.sh`
Erwartet: Parse-Fehler oder Laufzeitfehler, weil `Stones.maske` nicht existiert.

- [ ] **Schritt 3: Die Maske schreiben**

An `core/stones.gd` anhängen (vor den vorhandenen statischen Funktionen ist egal, GDScript ordnet nicht):

```gdscript
const BALKEN_BILD: String = "res://assets/art/ladebalken.png"
## Ab welcher Deckung ein Bildpunkt zum Balken zaehlt. Steht hier und nicht
## in der Voreinstellung, weil die Tests dieselbe Grenze brauchen: in der CI
## wird das PNG verlustbehaftet importiert.
const MASKE_SCHWELLE: float = 0.1

static var _maske: BitMap = null
static var _groesse: Vector2i = Vector2i.ZERO

static func maske() -> BitMap:
	if _maske != null:
		return _maske
	var bild := TextureLoader.load_texture(BALKEN_BILD).get_image()
	if bild.is_compressed():
		bild.decompress()
	if bild.get_format() != Image.FORMAT_RGBA8:
		bild.convert(Image.FORMAT_RGBA8)
	_groesse = Vector2i(bild.get_width(), bild.get_height())
	_maske = BitMap.new()
	_maske.create_from_image_alpha(bild, MASKE_SCHWELLE)
	return _maske

static func balken_groesse() -> Vector2i:
	maske()
	return _groesse

## Ob diese Bildzeile bei diesem Ladestand gefuellt ist. Zeile 0 ist oben,
## gefuellt wird von unten.
static func gefuellt(zeile: int, wert: float) -> bool:
	var g := balken_groesse()
	if g.y <= 0:
		return false
	var von_unten := 1.0 - (float(zeile) + 0.5) / float(g.y)
	return von_unten <= wert
```

- [ ] **Schritt 4: Tests laufen lassen**

Ausführen: `bash tools/test.sh`
Erwartet: alle grün.

- [ ] **Schritt 5: Committen**

```bash
git add core/stones.gd tests/test_stones.gd
git commit -m "Der Ladebalken ist seine eigene Form"
```

---

### Aufgabe 4: Einzelne Ringe auf dem Wasser

**Dateien:**
- Ändern: `scenes/fishing/water_view.gd`
- Ändern: `tests/test_water_rings.gd`

**Schnittstellen:**
- Verbraucht: nichts.
- Liefert: `WaterView.wirf_ring(anteil_x: float, tiefe: float) -> void` und die Erweiterung von `ring_rechtecke()` um die geworfenen Ringe.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

An `tests/test_water_rings.gd` anhängen:

```gdscript
## Der Stein macht seine eigenen Ringe, und die duerfen die Regenringe nicht
## verdraengen -- es sind zwei Quellen fuer dieselbe Zeichnung.
func test_a_thrown_ring_appears_without_rain() -> void:
	var w := load("res://scenes/fishing/water_view.gd").new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(w)
	w.size = Vector2(1280.0, 320.0)
	w.setze(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1280.0, 0.0)]),
		1280.0, 320.0, 0.0)
	w.regnet = false
	assert_eq(w.ring_rechtecke(w._laeufe()).size(), 0,
		"ohne Regen und ohne Wurf liegen Ringe auf dem Wasser")
	w.wirf_ring(0.5, 0.4)
	assert_true(w.ring_rechtecke(w._laeufe()).size() > 0,
		"der geworfene Ring erscheint nicht")
	w.free()

## Und ein alter Ring verschwindet wieder von selbst.
func test_a_thrown_ring_fades_away() -> void:
	var w := load("res://scenes/fishing/water_view.gd").new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(w)
	w.size = Vector2(1280.0, 320.0)
	w.setze(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1280.0, 0.0)]),
		1280.0, 320.0, 0.0)
	w.regnet = false
	w.wirf_ring(0.5, 0.4)
	for i in 120:
		w._process(0.05)
	assert_eq(w.ring_rechtecke(w._laeufe()).size(), 0,
		"der geworfene Ring bleibt liegen")
	w.free()
```

- [ ] **Schritt 2: Test laufen lassen und das Fehlschlagen sehen**

Ausführen: `bash tools/test.sh`
Erwartet: Laufzeitfehler, weil `wirf_ring` nicht existiert.

- [ ] **Schritt 3: Die Erweiterung schreiben**

In `scenes/fishing/water_view.gd` hinzufügen:

```gdscript
## Ausdruecklich gesetzte Ringe -- vom flitschenden Stein. Je Eintrag
## [anteil_x, tiefe, geburt]. Getrennt von den Regenringen, weil die aus der
## Uhr abgeleitet sind und keinen Platz fuer Fremdes haben.
var _geworfen: Array = []

func wirf_ring(anteil_x: float, tiefe: float) -> void:
	_geworfen.append([clampf(anteil_x, 0.0, 1.0),
		clampf(tiefe, 0.0, RING_FELD), _zeit])
```

In `ring_rechtecke()` die frühe Rückgabe so ändern, dass sie nur noch bei fehlenden Läufen greift, und die geworfenen Ringe mitzeichnen. Die vorhandene Zeile

```gdscript
	if not regnet or laeufe.is_empty():
		return stapel
```

ersetzen durch:

```gdscript
	if laeufe.is_empty():
		return stapel
```

und die vorhandene Schleife `for i in RINGE:` in eine Bedingung `if regnet:` einrücken. Danach, vor `return stapel`, die geworfenen Ringe anhängen:

```gdscript
	# Abgelaufene wegraeumen, bevor gezeichnet wird -- sonst waechst die
	# Liste eine Sitzung lang.
	while not _geworfen.is_empty() and _zeit - float(_geworfen[0][2]) > RING_LEBEN:
		_geworfen.remove_at(0)
	for eintrag in _geworfen:
		var alter := (_zeit - float(eintrag[2])) / RING_LEBEN
		_ring_rechteck(stapel, laeufe, float(eintrag[0]), float(eintrag[1]),
			alter)
	return stapel
```

Den Rumpf der bestehenden Regenschleife (von `var x := snappedf(...)` bis zum Ende) in eine eigene Methode ziehen, damit beide Quellen denselben Weg nehmen:

```gdscript
## Ein Ring als Rechtecke, an der Welle abgeschnitten. Regen und Stein gehen
## durch dieselbe Rechnung -- zwei Wege waeren zwei Formen.
func _ring_rechteck(stapel: Array, laeufe: Array, anteil_x: float,
		tiefe: float, alter: float) -> void:
```

Der Rumpf ist der bisherige Schleifeninhalt, mit `z[0]` → `anteil_x`, `z[1]` → `tiefe`, `z[2]` → `alter`.

- [ ] **Schritt 4: Tests laufen lassen**

Ausführen: `bash tools/test.sh`
Erwartet: alle grün, auch die vorhandenen Regenring-Tests (`test_no_ring_leaves_the_water`, `test_dry_weather_draws_nothing`).

- [ ] **Schritt 5: Committen**

```bash
git add scenes/fishing/water_view.gd tests/test_water_rings.gd
git commit -m "Einzelne Ringe auf Zuruf, nicht nur Regen"
```

---

### Aufgabe 5: Kieselhaufen und Ladebalken im Spiel

**Dateien:**
- Anlegen: `scenes/fishing/pebble_pile.gd`
- Anlegen: `scenes/fishing/stone_throw.gd`
- Ändern: `scenes/fishing/world.gd`
- Ändern: `tests/test_stones.gd`

**Schnittstellen:**
- Verbraucht: `Stones` (Aufgaben 1 und 3), `WaterView.wirf_ring` (Aufgabe 4), `assets/art/kiesel.png` und `assets/art/ladebalken.png` (Aufgabe 2).
- Liefert: `PebblePile` mit `signal tapped` und `setze(bild: Texture2D, skala: float) -> void`; `StoneThrow` mit `starte(bei: Vector2) -> void`, `wirf() -> void`, `signal aufsetzer(anteil_x: float, tiefe: float)`, `signal geworfen(spruenge: int, stelle: Vector2)`, den Feldern `_wert`, `_zeit`, `_laeuft`, `_balken_pos`.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

An `tests/test_stones.gd` anhängen:

```gdscript
## Der Balken laeuft erst, wenn man ihn startet, und ein zweiter Tipp wirft.
func test_the_bar_runs_only_after_it_is_started() -> void:
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	await tree.process_frame
	assert_false(wurf._laeuft, "der Balken laeuft ungefragt")
	wurf.starte(Vector2(200.0, 200.0))
	assert_true(wurf._laeuft, "der Balken laeuft nach dem Start nicht")
	wurf._process(0.1)
	assert_true(wurf._zeit > 0.0, "die Zeit steht still")
	wurf.free()

## Ein Wurf aendert nichts am Spielstand -- das ist die wichtigste
## Zusicherung des ganzen Zeitvertreibs.
func test_a_throw_changes_nothing_in_the_save() -> void:
	Game.new_game()
	var muenzen := Game.coins
	var koeder := Game.bait_used()
	var stufe: int = Game.ctx.player_level
	var fische: int = Game.ctx.inventory.fish.size()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	await tree.process_frame
	wurf.starte(Vector2(200.0, 200.0))
	for i in 30:
		wurf._process(0.05)
	wurf.wirf()
	assert_eq(Game.coins, muenzen, "ein Wurf kostet oder bringt Muenzen")
	assert_eq(Game.bait_used(), koeder, "ein Wurf aendert die Koeder")
	assert_eq(Game.ctx.player_level, stufe, "ein Wurf gibt Erfahrung")
	assert_eq(Game.ctx.inventory.fish.size(), fische,
		"ein Wurf aendert das Inventar")
	wurf.free()

## Und beim Anbiss verschwindet der Balken, ohne zu werfen.
func test_a_bite_closes_the_bar_without_throwing() -> void:
	Game.new_game()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	await tree.process_frame
	wurf.starte(Vector2(200.0, 200.0))
	Game.sim.state = FishingSim.State.FIGHT
	wurf._process(0.05)
	assert_false(wurf._laeuft, "der Balken laeuft im Kampf weiter")
	assert_false(wurf.visible, "der Balken bleibt im Kampf sichtbar")
	wurf.free()
```

- [ ] **Schritt 2: Test laufen lassen und das Fehlschlagen sehen**

Ausführen: `bash tools/test.sh`
Erwartet: Fehler, weil `scenes/fishing/stone_throw.gd` nicht existiert.

- [ ] **Schritt 3: Den Kieselhaufen schreiben**

`scenes/fishing/pebble_pile.gd`:

```gdscript
## Der Kieselhaufen am Ufer. Antippbar, sonst stumm -- wie der Schilfhorst
## (scenes/fishing/reed_patch.gd), nur ohne Windstellungen: Steine bewegen
## sich nicht.
class_name PebblePile
extends Control

signal tapped

var _bild: Texture2D
var _skala := 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setze(bild: Texture2D, skala: float) -> void:
	_bild = bild
	_skala = skala
	if _bild != null:
		size = Vector2(_bild.get_width(), _bild.get_height()) * skala
	queue_redraw()

func _draw() -> void:
	if _bild == null:
		return
	draw_texture_rect(_bild, Rect2(Vector2.ZERO, size), false)

func _gui_input(event: InputEvent) -> void:
	var tipp := event is InputEventScreenTouch \
		and (event as InputEventScreenTouch).pressed
	var klick := event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed
	if tipp or klick:
		tapped.emit()
		accept_event()
```

- [ ] **Schritt 4: Den Ladebalken schreiben**

`scenes/fishing/stone_throw.gd`:

```gdscript
## Der Ladebalken und der Flug des Steins.
##
## Die Form des Balkens steht NUR im Bild (Stones.maske()); Fuellung und
## goldenes Band werden hier durch diese Maske gemalt. Es gibt die Form also
## genau einmal -- bei der Klinge hat dieselbe Lehre vier Anlaeufe gekostet.
##
## Der Knoten liegt ueber der ganzen Szene und nimmt den zweiten Tipp selbst
## entgegen. Das ist gefahrlos: Tipps erreichen die Simulation ausschliesslich
## ueber die Orbs (scenes/fishing/catch_view.gd), es gibt keinen
## bildschirmweiten Tipp, den wir hier abfangen wuerden. Und beim Anbiss macht
## sich der Knoten von selbst wieder durchlaessig.
class_name StoneThrow
extends Control

## Ein Aufsetzer des Steins auf dem Wasser -- world.gd macht daraus einen Ring.
signal aufsetzer(anteil_x: float, tiefe: float)
## Der Stein ist versunken: Sprungzahl und die Stelle, an der sie aufsteigt.
signal geworfen(spruenge: int, stelle: Vector2)

const SKALA := 2.16
## Abstand zwischen zwei Aufsetzern.
const SPRUNG_ABSTAND := 0.13
## Wie weit der Stein je Sprung nach rechts kommt, als Anteil der Breite.
const SPRUNG_WEITE := 0.055

var _bild: Texture2D
var _zeit := 0.0
var _wert := 0.0
var _laeuft := false
## Wo der Balken gezeichnet wird -- der Knoten selbst deckt die ganze Szene.
var _balken_pos := Vector2.ZERO

## Der Flug, nachdem geworfen wurde.
var _fliegt := false
var _flug_zeit := 0.0
var _offen := 0
var _gesamt := 0
var _start_x := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_bild = TextureLoader.load_texture(Stones.BALKEN_BILD)

func starte(bei: Vector2) -> void:
	_balken_pos = bei
	_zeit = 0.0
	_wert = 0.0
	_laeuft = true
	_fliegt = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func schliesse() -> void:
	_laeuft = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _fliegt:
		visible = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _laeuft:
		return
	var tipp := event is InputEventScreenTouch \
		and (event as InputEventScreenTouch).pressed
	var klick := event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed
	if tipp or klick:
		wirf()
		accept_event()

func _process(delta: float) -> void:
	if _laeuft:
		# Beim Anbiss gehoert der Finger den Orbs, nicht den Steinen.
		if Game.sim != null and Game.sim.state == FishingSim.State.FIGHT:
			schliesse()
			return
		_zeit += delta
		_wert = Stones.ladung(_zeit)
		queue_redraw()
	elif _fliegt:
		_flug(delta)

## Wirft den Stein mit dem gerade anliegenden Ladestand.
func wirf() -> void:
	if not _laeuft:
		return
	var treffer := Stones.im_band(_wert, _zeit)
	_gesamt = Stones.spruenge(_wert, treffer)
	_offen = maxi(_gesamt, 1)
	_flug_zeit = 0.0
	_start_x = clampf(_balken_pos.x / maxf(size.x, 1.0), 0.0, 1.0)
	_fliegt = true
	schliesse()

## Je SPRUNG_ABSTAND ein Aufsetzer, jeder weiter draussen und flacher. Ein
## Plumps hat genau einen.
func _flug(delta: float) -> void:
	_flug_zeit += delta
	while _offen > 0 and _flug_zeit >= SPRUNG_ABSTAND:
		_flug_zeit -= SPRUNG_ABSTAND
		var nummer := maxi(_gesamt, 1) - _offen
		var x := clampf(_start_x + float(nummer + 1) * SPRUNG_WEITE, 0.0, 1.0)
		var tiefe := clampf(0.15 + float(nummer) * 0.12, 0.0, 0.8)
		aufsetzer.emit(x, tiefe)
		_offen -= 1
	if _offen <= 0:
		_fliegt = false
		visible = false
		geworfen.emit(_gesamt, Vector2(_start_x * size.x, _balken_pos.y))

func _draw() -> void:
	if _bild == null or not _laeuft:
		return
	var g := Stones.balken_groesse()
	var band := Stones.band_mitte(_zeit)
	var leer := Palette.get_color(&"peat_dark")
	var voll := Palette.get_color(&"torch")
	var gold := Palette.get_color(&"rod_brass")
	for y in g.y:
		var von_unten := 1.0 - (float(y) + 0.5) / float(g.y)
		var f := gold if absf(von_unten - band) <= Stones.BAND_HOEHE * 0.5 \
			else (voll if Stones.gefuellt(y, _wert) else leer)
		# Waagerechte Laeufe statt einzelner Punkte: eine Zeile des Balkens
		# ist hoechstens ein zusammenhaengendes Stueck breit.
		var start := -1
		for x in g.x + 1:
			var drin := x < g.x and Stones.maske().get_bit(x, y)
			if drin and start < 0:
				start = x
			elif not drin and start >= 0:
				draw_rect(Rect2(_balken_pos.x + float(start) * SKALA,
					_balken_pos.y + float(y) * SKALA,
					float(x - start) * SKALA, SKALA), f)
				start = -1
```

- [ ] **Schritt 5: Tests laufen lassen**

Ausführen: `bash tools/test.sh`
Erwartet: alle grün.

- [ ] **Schritt 6: In der Welt anbinden**

In `scenes/fishing/world.gd`, neben den vorhandenen Schilf-Konstanten:

```gdscript
## Links neben dem Schilf -- der Steg steht ganz links, das Schilf ganz
## rechts, dazwischen ist Platz.
const KIESEL_X := 0.62
```

Feld dazu:

```gdscript
var _kiesel: PebblePile = null
var _wurf: StoneThrow = null
```

Im Aufbau, direkt nach der Schilf-Anbindung:

```gdscript
	_kiesel = PebblePile.new()
	_kiesel.setze(TextureLoader.load_texture("res://assets/art/kiesel.png"),
		SCHILF_KNOPF_SKALA)
	_kiesel.visible = false
	$Visitors.add_child(_kiesel)
	_kiesel.tapped.connect(_on_pebbles_pressed)

	_wurf = StoneThrow.new()
	add_child(_wurf)
	_wurf.aufsetzer.connect(_on_stone_skip)
	_wurf.geworfen.connect(_on_stone_thrown)
```

Im selben Block, in dem `_schilf_knopf.position` gesetzt wird:

```gdscript
	if _kiesel != null:
		_kiesel.position = Vector2(size.x * KIESEL_X,
			schilf_fuss - _kiesel.size.y)
```

Und die zwei Handler:

```gdscript
## Ein Tipp auf die Kiesel nimmt einen Stein auf. Im Kampf nicht -- dort
## gehoert der Finger den Orbs.
func _on_pebbles_pressed() -> void:
	if Game.sim.state == FishingSim.State.FIGHT:
		return
	# Der Balken steht ueber dem Haufen, nicht darauf.
	var hoch := float(Stones.balken_groesse().y) * StoneThrow.SKALA
	_wurf.starte(_kiesel.position + Vector2(0.0, -hoch - 12.0))

func _on_stone_skip(anteil_x: float, tiefe: float) -> void:
	_water_view.wirf_ring(anteil_x, tiefe)

func _on_stone_thrown(_spruenge: int, _stelle: Vector2) -> void:
	pass
```

- [ ] **Schritt 7: Tests laufen lassen und committen**

Ausführen: `bash tools/test.sh`
Erwartet: alle grün.

```bash
git add scenes/fishing/pebble_pile.gd scenes/fishing/stone_throw.gd scenes/fishing/world.gd tests/test_stones.gd
git commit -m "Kieselhaufen am Ufer und der Ladebalken"
```

---

### Aufgabe 6: Der Flug, die Ringe und die Zahl

**Dateien:**
- Ändern: `scenes/fishing/stone_throw.gd`
- Ändern: `scenes/fishing/world.gd`
- Ändern: `core/records.gd`
- Ändern: `tests/test_stones.gd`
- Ändern: `tests/test_save_manager.gd`

**Schnittstellen:**
- Verbraucht: alles aus den Aufgaben 1 bis 5.
- Liefert: `Records.best_skips` (int) und die Anzeige der Sprungzahl über `scenes/effects/pop_text.gd`.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

An `tests/test_stones.gd` anhängen:

```gdscript
## Der beste Wurf wird still mitgezaehlt -- und nur er.
func test_the_best_throw_is_remembered() -> void:
	Game.new_game()
	assert_eq(Game.records.best_skips, 0, "ein neues Spiel kennt schon Wuerfe")
	Game.melde_wurf(5)
	assert_eq(Game.records.best_skips, 5)
	Game.melde_wurf(3)
	assert_eq(Game.records.best_skips, 5, "ein schlechterer Wurf zaehlt mit")
	Game.melde_wurf(8)
	assert_eq(Game.records.best_skips, 8, "ein besserer Wurf zaehlt nicht")
```

An `tests/test_save_manager.gd` anhängen:

```gdscript
## Ein Spielstand von vor dem Steineflitschen laedt weiter -- Records
## ueberspringt fehlende Felder.
func test_an_old_save_without_best_skips_still_loads() -> void:
	Game.new_game()
	var blob := SaveManager.serialize()
	blob["records"].erase("best_skips")
	SaveManager.deserialize(blob)
	assert_eq(Game.records.best_skips, 0,
		"ein alter Stand bekommt keinen sauberen Anfangswert")
```

- [ ] **Schritt 2: Test laufen lassen und das Fehlschlagen sehen**

Ausführen: `bash tools/test.sh`
Erwartet: Laufzeitfehler, weil `Records.best_skips` und `Game.melde_wurf` fehlen.

- [ ] **Schritt 3: Den Rekord anlegen**

In `core/records.gd`, das Feld neben den anderen:

```gdscript
var best_skips: int = 0
```

und in `FIELDS` am Ende ergänzen:

```gdscript
	"quests_done", "casts", "best_skips"]
```

In `autoload/Game.gd`:

```gdscript
## Meldet einen geflitschten Stein. Aendert NICHTS am Spielstand ausser dem
## Bestwert -- kein Ertrag ist die Bedingung dafuer, dass das ein
## Zeitvertreib bleibt und keine Aufgabe wird.
func melde_wurf(spruenge: int) -> void:
	if spruenge > records.best_skips:
		records.best_skips = spruenge
```

- [ ] **Schritt 4: Flug, Ringe und Zahl anbinden**

In `scenes/fishing/world.gd` den Handler ausfüllen. Die Wasseransicht heißt dort `_water_view`, die Effekte hängen unter `$Effects`:

Die Ringe macht schon der Flug (`_on_stone_skip` aus Aufgabe 5). Hier bleibt
nur der Bestwert und die Zahl, die kurz aufsteigt:

```gdscript
## Der Stein ist versunken. Mehr passiert nicht -- kein Ertrag, nur der
## Bestwert und eine Zahl, die sich selbst wieder wegraeumt.
func _on_stone_thrown(spruenge: int, stelle: Vector2) -> void:
	Game.melde_wurf(spruenge)
	var text := "%d" % spruenge if spruenge > 0 else "plumps"
	$Effects._spawn_text(text, stelle, Palette.get_color(&"foam"))
```

`_spawn_text` ist in `scenes/effects/effects.gd` bereits vorhanden und legt
eine `pop_text.tscn` an, die nach 1,1 Sekunden von selbst verschwindet.

- [ ] **Schritt 5: Tests laufen lassen**

Ausführen: `bash tools/test.sh`
Erwartet: alle grün.

- [ ] **Schritt 6: Committen**

```bash
git add core/records.gd autoload/Game.gd scenes/fishing/world.gd tests/test_stones.gd tests/test_save_manager.gd
git commit -m "Der Stein springt, und die Zahl steigt kurz auf"
```

---

### Aufgabe 7: Auf dem Gerät ansehen

**Dateien:** keine.

- [ ] **Schritt 1: Alle Tests laufen lassen**

Ausführen: `bash tools/test.sh`
Erwartet: `0 fehlgeschlagen`.

- [ ] **Schritt 2: Bauen und installieren**

```bash
git push origin master
gh workflow run build.yml --ref master
```

Beide Arbeitsabläufe abwarten (`build.yml` UND `test.yml`), dann:

```bash
gh run download -R Phioster/stillwater -n stillwater-debug-apk
bash tools/sign.sh stillwater-debug.apk --install
```

- [ ] **Schritt 3: Dem Menschen vorlegen**

Fünf Zahlen lassen sich nur am Gerät beurteilen und gehören **ihm**, nicht dem Bearbeiter:

| Zahl | Vorschlag | Wo |
|---|---|---|
| Zyklus der Ladung | 1,8 s | `Stones.ZYKLUS` |
| Weg des Bandes | 5,5 s | `Stones.BAND_WEG` |
| Höhe des Bandes | 0,12 | `Stones.BAND_HOEHE` |
| Höchste Sprungzahl | 8 | `Stones.GRUND_MAX + BAND_BONUS` |
| Wo der Haufen liegt | 0,62 der Breite | `World.KIESEL_X` |

Mit Bild vorlegen und nach dem Gefühl fragen. Nichts davon selbst festzurren.
