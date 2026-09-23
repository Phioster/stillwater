# Tränke: Bilder und Anzeige — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 18 Trankbilder aus 7 PixelLab-Grundbildern, eine Trankreihe links
unter der Kopfzeile, und Fanganzeige/Kampfleiste oben mittig, bei offenem
Menü ausgeblendet.

**Architecture:** PixelLab liefert Rohbilder nach `assets/source/potions/`,
`tools/traenke_bauen.py` schneidet und färbt daraus `assets/art/potion_<id>.png`.
Die Trankreihe ist ein eigener Knoten `BuffBar` in `main.tscn`, gesetzt von
`main.gd::_layout`. Die Sichtbarkeit bei offenem Menü läuft über eine
Eigenschaft `menu_offen`, die `main.gd::show_tab` über `world.gd` verteilt.

**Tech Stack:** Godot 4.7.2 / GDScript, Python 3 + Pillow, PixelLab-MCP.

**Spec:** `docs/superpowers/specs/2026-09-23-traenke-bilder-und-anzeige-design.md`

## Global Constraints

- Testtor ist `bash tools/test.sh` (Godot-Suite UND Python-Tests); nur grün,
  wenn es mit 0 endet. Rückgabewert prüfen, nicht durch eine Pipe schicken.
- Neue Godot-Testdateien in `tests/run_tests.gd` eintragen, sonst laufen sie nicht.
- Bildtests prüfen die **Silhouette** (`a > 0`), nie Farbwerte.
- Masse stehen im **Code**, nicht in der `.tscn`; je ein Test hält beide zusammen.
  Anker einer Szenenwurzel überleben den Export nicht — in `_ready()` setzen.
- Antippbares: Doppel-Tipp-Falle (Maus-Emulation) — `TapButton` benutzen.
- Kommentare kurz: 1–2 Zeilen, das Warum.
- Keine Secrets, keine Attribution-Zeilen in Commits.
- Bildschirm 1280×720; `main.gd::RAIL_WIDTH = 140`, `PANEL_WIDTH = 520`.

---

### Task 1: Sieben Grundbilder mit PixelLab

**Files:**
- Create: `assets/source/potions/{phiole,trank,elixier,kristall,mondglas,sparhaken,senkblei}.png`

**Interfaces:**
- Produces: sieben 32×32-PNGs mit transparentem Grund, eine gemeinsame
  Palette; bei den ersten vier ist die Flüssigkeit **rot**.

- [ ] **Step 1: Generieren.** Je ein `create_image_pixflux` mit
  `width=32, height=32, no_background=True, view="side", outline="single color black outline", shading="medium shading", detail="medium detail"`
  und diesen Beschreibungen:
  - phiole: `small narrow glass vial with cork stopper, filled with red liquid, game item icon`
  - trank: `round-bellied glass potion flask with cork, filled with red liquid, game item icon`
  - elixier: `ornate tall glass elixir bottle with gold filigree and stopper, filled with red liquid, game item icon`
  - kristall: `faceted crystal bottle with a star-shaped stopper, filled with red liquid, game item icon`
  - mondglas: `small glass jar containing a glowing crescent moon, game item icon`
  - sparhaken: `single steel fishing hook with a small brass ring, game item icon`
  - senkblei: `teardrop-shaped lead fishing sinker on a short line, game item icon`

  Mit `get_image` abholen, nach `assets/source/potions/` speichern.
- [ ] **Step 2: Prüfen.** Jedes Bild: Inhalt ≤ 24×24 (Bounding Box von
  `alpha > 0`), bei den vier Flaschen ist die Flüssigkeit sichtbar rot.
  Verfehlt eins das, mit anderem `seed` neu erzeugen (höchstens zweimal je Bild).
- [ ] **Step 3: Eine Palette.** Alle sieben in EINEM `reduce_colors`-Aufruf
  (ohne `num_colors`), Ergebnisse über die alten Dateien schreiben.
- [ ] **Step 4: Nutzer abnehmen lassen.** Die sieben Bilder (8-fach, `NEAREST`)
  auf die Vorschauseite `https://claude.ai/artifact/TxUivQBKPnNeZNgGKmpxDq`
  stellen und auf Zustimmung warten. Ohne Zustimmung nicht weiter.
- [ ] **Step 5: Commit**

```bash
git add assets/source/potions
git commit -m "Traenke: sieben Grundbilder aus PixelLab"
```

### Task 2: Bauwerkzeug und die 18 Trankbilder

**Files:**
- Create: `tools/traenke_bauen.py`, `tools/tests/test_traenke_bauen.py`,
  `tests/test_potion_icons.gd`, `assets/art/potion_<id>.png` (18 Stück)
- Modify: `tests/run_tests.gd` (Eintrag `res://tests/test_potion_icons.gd`)

**Interfaces:**
- Consumes: `assets/source/potions/*.png` aus Task 1.
- Produces: `res://assets/art/potion_<id>.png`, 24×24, für jede Kennung in
  `data/consumables/`.

- [ ] **Step 1: Python-Test schreiben** — `tools/tests/test_traenke_bauen.py`:

```python
import unittest

from PIL import Image

from tools import traenke_bauen as tb


class TestZuschneiden(unittest.TestCase):
    def test_inhalt_landet_mittig_auf_24(self):
        bild = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        for x in range(10, 20):
            for y in range(5, 25):
                bild.putpixel((x, y), (200, 10, 10, 255))
        aus = tb.zuschneiden(bild)
        self.assertEqual(aus.size, (24, 24))
        self.assertEqual(aus.getbbox(), (7, 2, 17, 22))

    def test_zu_grosser_inhalt_bricht_ab(self):
        bild = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        for x in range(0, 30):
            bild.putpixel((x, 10), (200, 10, 10, 255))
        with self.assertRaises(ValueError):
            tb.zuschneiden(bild)


class TestFaerben(unittest.TestCase):
    def test_rot_wird_zur_zielfarbe_helligkeit_bleibt(self):
        bild = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        bild.putpixel((0, 0), (200, 20, 20, 255))   # Fluessigkeit
        bild.putpixel((1, 0), (90, 90, 90, 255))    # Glas, grau
        aus = tb.faerben(bild, "#4fb8c8")
        r, g, b, a = aus.getpixel((0, 0))
        self.assertTrue(b > r and g > r, "Tuerkis erwartet, bekam %s" % ((r, g, b),))
        self.assertEqual(max(r, g, b), 200, "Helligkeit muss bleiben")
        self.assertEqual(aus.getpixel((1, 0)), (90, 90, 90, 255))


class TestTabelle(unittest.TestCase):
    def test_jeder_trank_hat_eine_zeile(self):
        import glob, os
        ids = {os.path.basename(p)[:-5]
               for p in glob.glob(os.path.join(tb.WURZEL, "data", "consumables", "*.tres"))}
        self.assertEqual(ids, set(tb.TRAENKE))
```

- [ ] **Step 2: Laufen lassen, muss rot sein**

Run: `cd ~/stillwater && python3 -m unittest tools.tests.test_traenke_bauen`
Expected: FAIL (`No module named tools.traenke_bauen`)

- [ ] **Step 3: `tools/traenke_bauen.py` schreiben**

```python
"""Die 18 Trankbilder aus sieben Grundbildern schneiden und faerben.

    python3 -m tools.traenke_bauen

Flaschenform = Stufe, Fluessigkeitsfarbe = Wirkung. Die Grundbilder kommen
aus PixelLab mit ROTER Fluessigkeit; hier wird nur umgefaerbt.
"""
import colorsys
import os
import re

from PIL import Image

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUELLE = os.path.join(WURZEL, "assets", "source", "potions")
ZIEL = os.path.join(WURZEL, "assets", "art")
GROESSE = 24


def seltenheit(rid):
    """Die Farbe steht schon in den Seltenheitsdaten -- nicht ein zweites Mal hier."""
    s = open(os.path.join(WURZEL, "data", "rarities", rid + ".tres")).read()
    r, g, b = (float(v) for v in re.search(r"color = Color\(([\d.]+), ([\d.]+), ([\d.]+)", s).groups())
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


SCHIMMER, LOCKSTOFF, ERFAHRUNG, HANDEL = "#d8c8f0", "#6fae4f", "#4fb8c8", "#f0c05a"

## Kennung -> (Grundbild, Farbe oder None fuer "nicht faerben").
TRAENKE = {
    "schimmer_phiole": ("phiole", SCHIMMER), "schimmer_trank": ("trank", SCHIMMER),
    "schimmer_elixier": ("elixier", SCHIMMER),
    "koeder_phiole": ("phiole", LOCKSTOFF), "koeder_trank": ("trank", LOCKSTOFF),
    "koeder_elixier": ("elixier", LOCKSTOFF),
    "erfahrung_phiole": ("phiole", ERFAHRUNG), "erfahrung_trank": ("trank", ERFAHRUNG),
    "erfahrung_elixier": ("elixier", ERFAHRUNG),
    "wert_phiole": ("phiole", HANDEL), "wert_trank": ("trank", HANDEL),
    "wert_elixier": ("elixier", HANDEL),
    "selten_elixier": ("kristall", "rare"), "episch_elixier": ("kristall", "epic"),
    "legendaer_elixier": ("kristall", "legendary"),
    "mondglas": ("mondglas", None), "sparhaken": ("sparhaken", None),
    "tiefenlot": ("senkblei", None),
}


def zuschneiden(bild):
    """Inhalt mittig auf 24x24 -- nie skalieren, sonst verschwimmen die Pixel."""
    box = bild.getchannel("A").getbbox()
    b, h = box[2] - box[0], box[3] - box[1]
    if b > GROESSE or h > GROESSE:
        raise ValueError("Inhalt %dx%d passt nicht auf %d" % (b, h, GROESSE))
    aus = Image.new("RGBA", (GROESSE, GROESSE), (0, 0, 0, 0))
    aus.alpha_composite(bild.crop(box), ((GROESSE - b) // 2, (GROESSE - h) // 2))
    return aus


def _ist_fluessigkeit(r, g, b):
    h, s, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s > 0.35 and (h < 0.05 or h > 0.93)


def faerben(bild, farbe):
    """Farbton und Saettigung der Wirkung, Helligkeit bleibt -- wie palette_swap."""
    zh, zs, _ = colorsys.rgb_to_hsv(*(int(farbe[i:i + 2], 16) / 255 for i in (1, 3, 5)))
    aus = bild.copy()
    px = aus.load()
    for y in range(aus.height):
        for x in range(aus.width):
            r, g, b, a = px[x, y]
            if a and _ist_fluessigkeit(r, g, b):
                v = max(r, g, b) / 255
                nr, ng, nb = colorsys.hsv_to_rgb(zh, zs, v)
                px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return aus


def main():
    for tid, (grund, farbe) in TRAENKE.items():
        bild = zuschneiden(Image.open(os.path.join(QUELLE, grund + ".png")).convert("RGBA"))
        if farbe is not None:
            bild = faerben(bild, seltenheit(farbe) if not farbe.startswith("#") else farbe)
        bild.save(os.path.join(ZIEL, "potion_%s.png" % tid))
    print("%d Trankbilder geschrieben" % len(TRAENKE))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Python-Test grün**

Run: `cd ~/stillwater && python3 -m unittest tools.tests.test_traenke_bauen`
Expected: `OK`

- [ ] **Step 5: Bilder bauen**

Run: `cd ~/stillwater && python3 -m tools.traenke_bauen`
Expected: `18 Trankbilder geschrieben`

- [ ] **Step 6: Godot-Test** — `tests/test_potion_icons.gd` (und in `tests/run_tests.gd` eintragen):

```gdscript
extends TestCase

## Jeder Trank braucht ein Bild -- ein fehlendes faellt sonst erst als leere
## Stelle in der Trankreihe auf.
func test_jeder_trank_hat_ein_bild() -> void:
	assert_true(Database.consumables.size() >= 18, "Traenke nicht geladen")
	for id in Database.consumables:
		var tex := TextureLoader.load_texture("res://assets/art/potion_%s.png" % id)
		assert_true(tex != null, "%s: kein Bild" % id)
		if tex == null:
			continue
		var img := tex.get_image()
		assert_eq(img.get_size(), Vector2i(24, 24), "%s: falsche Groesse" % id)
		var voll := 0
		for y in 24:
			for x in 24:
				if img.get_pixel(x, y).a > 0.0:
					voll += 1
		assert_true(voll > 40, "%s: fast leer (%d Pixel)" % [id, voll])
```

- [ ] **Step 7: Gesamttor**

Run: `cd ~/stillwater && timeout 400 bash tools/test.sh > /tmp/t.log 2>&1; echo rc=$?`
Expected: `rc=0`

- [ ] **Step 8: Commit**

```bash
git add tools/traenke_bauen.py tools/tests/test_traenke_bauen.py tests/test_potion_icons.gd tests/run_tests.gd assets/art/potion_*.png
git commit -m "Traenke: Bauwerkzeug und 18 Trankbilder"
```

### Task 3: Fanganzeige und Kampfleiste oben mittig, bei offenem Menü aus

**Files:**
- Modify: `scenes/ui/catch_toast.gd`, `scenes/ui/catch_toast.tscn`,
  `scenes/fishing/catch_view.gd`, `scenes/fishing/catch_view.tscn`,
  `scenes/fishing/world.gd`, `scenes/main.gd`
- Test: `tests/test_ui_theme.gd` (zwei Tests ersetzen, zwei neue)

**Interfaces:**
- Produces: `catch_toast.gd::MASS: Vector2 = Vector2(360, 86)`,
  `catch_toast.gd::OBEN: float = 16.0`; `catch_view.gd::MASS: Vector2 = Vector2(360, 80)`,
  `catch_view.gd::OBEN: float = 16.0`; Eigenschaft `menu_offen: bool` an beiden;
  `world.gd::set_menu_open(offen: bool) -> void`.

- [ ] **Step 1: Tests schreiben.** In `tests/test_ui_theme.gd`
  `test_the_catch_panel_never_hides_behind_the_hud`,
  `test_the_catch_toast_code_and_scene_agree` und
  `test_the_catch_toast_stays_in_the_free_column` löschen und ersetzen durch:

```gdscript
## Fanganzeige und Kampfleiste stehen oben mittig in der freien Flaeche
## (links der Reiterleiste). Die Kopfzeile ist schmaler als 390.
func _mittig_frei(links: float, breite: float, was: String) -> void:
	var frei := 1280.0 - MAIN.RAIL_WIDTH
	assert_almost_eq(links + breite * 0.5, frei * 0.5, 1.0, "%s nicht mittig" % was)
	assert_true(links >= 380.0, "%s beruehrt die Kopfzeile" % was)
	assert_true(links + breite <= frei, "%s ragt in die Reiterleiste" % was)

func _in_welt(szene: String) -> Control:
	var welt := Control.new()
	welt.size = Vector2(1280.0 - MAIN.RAIL_WIDTH, 720.0)
	(Engine.get_main_loop() as SceneTree).root.add_child(welt)
	var k: Control = load(szene).instantiate()
	welt.add_child(k)
	return k

func test_die_fanganzeige_steht_oben_mittig() -> void:
	var k := _in_welt("res://scenes/ui/catch_toast.tscn")
	_mittig_frei(k.position.x, k.size.x, "Fanganzeige")
	assert_almost_eq(k.position.y, k.OBEN, 0.5)
	assert_almost_eq(k.size.x, k.MASS.x, 0.5, "Code und Szene laufen auseinander")
	k.get_parent().free()

func test_die_kampfleiste_steht_oben_mittig() -> void:
	var cv := _in_welt("res://scenes/fishing/catch_view.tscn")
	var p: Control = cv.get_node("Panel")
	_mittig_frei(p.position.x, p.size.x, "Kampfleiste")
	assert_almost_eq(p.position.y, cv.OBEN, 0.5)
	cv.get_parent().free()

func test_bei_offenem_menue_ist_die_fanganzeige_weg_und_kommt_wieder() -> void:
	Game.new_game()
	var k := _in_welt("res://scenes/ui/catch_toast.tscn")
	var fisch: FishData = Database.fish.values()[0]
	k.show_catch(CaughtFish.make(fisch.id, 0.0), fisch, false, false)
	assert_true(k.visible)
	k.menu_offen = true
	assert_false(k.visible, "unter dem Menue sichtbar")
	k.menu_offen = false
	assert_true(k.visible, "kommt nach dem Schliessen nicht wieder")
	k.get_parent().free()

func test_bei_offenem_menue_ist_die_kampfleiste_weg() -> void:
	Game.new_game()
	var cv := _in_welt("res://scenes/fishing/catch_view.tscn")
	Game.sim.state = FishingSim.State.FIGHT
	cv._process(0.0)
	assert_true(cv.get_node("Panel").visible)
	cv.menu_offen = true
	cv._process(0.0)
	assert_false(cv.get_node("Panel").visible)
	Game.sim.state = FishingSim.State.IDLE
	cv.get_parent().free()
```

- [ ] **Step 2: Rot laufen lassen** — `bash tools/test.sh`, erwartet: die vier
  neuen Tests FAIL (`MASS`/`OBEN`/`menu_offen` fehlen).

- [ ] **Step 3: `catch_toast.gd`** — `RECT` ersetzen:

```gdscript
## Oben mittig in der Welt; bei offenem Menue ausgeblendet, weil es die rechte
## Haelfte zudeckt. Mass im Code: Anker der Szenenwurzel ueberleben den Export nicht.
const MASS := Vector2(360.0, 86.0)
const OBEN: float = 16.0

var menu_offen: bool = false:
	set(v):
		menu_offen = v
		_zeigen()
var _hat_fang: bool = false
```

  In `_ready()` die Offsets ersetzen durch:

```gdscript
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -MASS.x * 0.5
	offset_right = MASS.x * 0.5
	offset_top = OBEN
	offset_bottom = OBEN + MASS.y
```

  `visible = true` in `show_catch` → `_hat_fang = true` + `_zeigen()`;
  `_hide()` → `_hat_fang = false` + `_zeigen()`; neu:

```gdscript
func _zeigen() -> void:
	visible = _hat_fang and not menu_offen
```

  `catch_toast.tscn`: Wurzel auf `anchor_left = 0.5`, `anchor_right = 0.5`,
  `offset_left = -180`, `offset_right = 180`, `offset_top = 16`, `offset_bottom = 102`.
  Den alten Kommentar über die linke Spalte durch den neuen ersetzen.

- [ ] **Step 4: `catch_view.gd`** — oben ergänzen:

```gdscript
## Kampfleiste oben mittig, wie die Fanganzeige; beide zeigen sich nie gleichzeitig.
const MASS := Vector2(360.0, 80.0)
const OBEN: float = 16.0
var menu_offen: bool = false
```

  In `_ready()` nach `set_anchors_and_offsets_preset(...)`:

```gdscript
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -MASS.x * 0.5
	_panel.offset_right = MASS.x * 0.5
	_panel.offset_top = OBEN
	_panel.offset_bottom = OBEN + MASS.y
```

  In `_process`: `_panel.visible = fighting` → `_panel.visible = fighting and not menu_offen`.
  (Orbs laufen unverändert weiter.) `catch_view.tscn`, Knoten `Panel`:
  dieselben Anker/Offsets wie oben (`-180/180/16/96`).

- [ ] **Step 5: `world.gd`** ergänzen:

```gdscript
## Das offene Menue deckt die rechte Haelfte -- Fang- und Kampfanzeige weichen.
func set_menu_open(offen: bool) -> void:
	$CatchToast.menu_offen = offen
	$CatchView.menu_offen = offen
```

  `main.gd::show_tab`, nach `_side.visible = valid`:

```gdscript
	var welt := $Row/World
	if welt.has_method("set_menu_open"):
		welt.set_menu_open(valid)
```

- [ ] **Step 6: Grün** — `bash tools/test.sh`, `rc=0`.
- [ ] **Step 7: Commit**

```bash
git add scenes/ui/catch_toast.gd scenes/ui/catch_toast.tscn scenes/fishing/catch_view.gd scenes/fishing/catch_view.tscn scenes/fishing/world.gd scenes/main.gd tests/test_ui_theme.gd
git commit -m "Fang- und Kampfanzeige oben mittig, bei offenem Menue ausgeblendet"
```

### Task 4: Die Trankreihe

**Files:**
- Create: `scenes/ui/buff_bar.gd`, `tests/test_buff_bar.gd`
- Modify: `scenes/main.tscn` (Knoten `BuffBar` nach `Hud`), `scenes/main.gd`,
  `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Game.buffs.active` (Dictionary id → Restsekunden, Einfügereihenfolge
  = Trinkreihenfolge), `Game.buffs.remaining(id)`, `Database.consumables[id].duration`,
  `potion_<id>.png` aus Task 2.
- Produces: `class_name BuffBar extends HBoxContainer`; `signal tapped`;
  `func refresh() -> void`; `static func zeit(sekunden: float) -> String`;
  `const ICON: int = 48`; `const EINTRAG_BREITE: float = 56.0`;
  `main.gd::BUFF_TOP: float = 132.0`; `main.gd::FISH_SUB_POTION := 2`.

- [ ] **Step 1: Test** — `tests/test_buff_bar.gd` (in `run_tests.gd` eintragen):

```gdscript
extends TestCase

const MAIN := preload("res://scenes/main.gd")

func _bar() -> BuffBar:
	var b := BuffBar.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	return b

func test_zeit_format() -> void:
	assert_eq(BuffBar.zeit(760.0), "12:40")
	assert_eq(BuffBar.zeit(59.2), "1:00")
	assert_eq(BuffBar.zeit(5.0), "0:05")

func test_ohne_trank_unsichtbar() -> void:
	Game.new_game()
	var b := _bar()
	b.refresh()
	assert_false(b.visible)
	b.free()

func test_zeigt_die_laufenden_in_trinkreihenfolge() -> void:
	Game.new_game()
	Game.buffs.apply(Database.consumables[&"wert_trank"])
	Game.buffs.apply(Database.consumables[&"mondglas"])
	var b := _bar()
	b.refresh()
	assert_true(b.visible)
	assert_eq(b.ids(), [&"wert_trank", &"mondglas"])
	b.free()

## Alle acht Gruppen gleichzeitig -- mehr geht nicht, gleiche Gruppe ersetzt.
func test_passt_links_neben_das_offene_menue() -> void:
	var frei := 1280.0 - MAIN.RAIL_WIDTH - MAIN.PANEL_WIDTH
	assert_true(16.0 + 8.0 * BuffBar.EINTRAG_BREITE + 7.0 * 8.0 <= frei,
		"acht Eintraege reichen bis unter das Menue")
	assert_true(MAIN.BUFF_TOP >= 116.0, "liegt in der Kopfzeile")
```

- [ ] **Step 2: Rot** — `bash tools/test.sh`, erwartet SUITE KAPUTT (BuffBar fehlt).

- [ ] **Step 3: `scenes/ui/buff_bar.gd`**

```gdscript
## Die laufenden Traenke: Bild, Restzeit, leerlaufender Balken. Links unter der
## Kopfzeile, weil das Menue rechts haengt und sie dort nie zudeckt.
class_name BuffBar
extends HBoxContainer

signal tapped

const ICON: int = 48
const EINTRAG_BREITE: float = 56.0

var _takt: float = 0.0

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	if not Game.state_changed.is_connected(refresh):
		Game.state_changed.connect(refresh)
	refresh()

## Einmal je Sekunde reicht: die Anzeige hat Sekunden als kleinste Einheit.
func _process(delta: float) -> void:
	_takt += delta
	if _takt >= 1.0:
		_takt = 0.0
		refresh()

func ids() -> Array:
	return Game.buffs.active.keys()

static func zeit(sekunden: float) -> String:
	var s := int(ceil(sekunden))
	return "%d:%02d" % [s / 60, s % 60]

func refresh() -> void:
	for k in get_children():
		k.queue_free()
	visible = not Game.buffs.active.is_empty()
	for id in Game.buffs.active:
		var c: ConsumableData = Database.consumables.get(id)
		if c != null:
			add_child(_eintrag(c))

## Ein TapButton je Eintrag: er faengt den Doppel-Tipp der Maus-Emulation ab.
func _eintrag(c: ConsumableData) -> Control:
	var knopf := TapButton.new()
	knopf.flat = true
	knopf.custom_minimum_size = Vector2(EINTRAG_BREITE, 0)
	knopf.tapped.connect(func() -> void: tapped.emit())
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	knopf.add_child(box)
	var bild := TextureRect.new()
	bild.texture = TextureLoader.load_texture("res://assets/art/potion_%s.png" % c.id)
	bild.custom_minimum_size = Vector2(ICON, ICON)
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bild)
	var rest := Game.buffs.remaining(c.id)
	var text := Label.new()
	text.text = zeit(rest)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text)
	var balken := ProgressBar.new()
	balken.show_percentage = false
	balken.custom_minimum_size = Vector2(ICON, 4)
	balken.max_value = maxf(c.duration, 1.0)
	balken.value = rest
	balken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(balken)
	knopf.custom_minimum_size.y = box.get_combined_minimum_size().y
	return knopf
```

- [ ] **Step 4: Einhängen.** `scenes/main.tscn`: nach dem `Hud`-Knoten

```
[node name="BuffBar" type="HBoxContainer" parent="."]
script = ExtResource("<id von buff_bar.gd>")
```

  (ext_resource `type="Script" path="res://scenes/ui/buff_bar.gd"` ergänzen).
  `scenes/main.gd`: Konstanten

```gdscript
## Die Trankreihe steht, wo frueher die Fanganzeige stand: unter der Kopfzeile.
const BUFF_TOP := 132.0
const FISH_TAB := 0
const FISH_SUB_POTION := 2
```

  in `_layout` nach den `$Hud`-Zeilen:

```gdscript
	$BuffBar.offset_left = left + 16.0
	$BuffBar.offset_top = top + BUFF_TOP
```

  in `_ready` (neben den anderen `connect`s):

```gdscript
	if not $BuffBar.tapped.is_connected(_open_potions):
		$BuffBar.tapped.connect(_open_potions)
```

  und

```gdscript
func _open_potions() -> void:
	_rail.select(FISH_TAB)
	_fish_group.select_sub(FISH_SUB_POTION)
```

- [ ] **Step 5: Test ergänzen**, der Szene und Konstante zusammenhält, in
  `tests/test_buff_bar.gd`:

```gdscript
func test_main_haengt_die_reihe_an_die_konstante() -> void:
	var m: Control = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	m.size = Vector2(1280, 720)
	m._layout()
	var b: Control = m.get_node("BuffBar")
	assert_true(b is BuffBar)
	assert_true(b.offset_top >= MAIN.BUFF_TOP - 0.5)
	m.free()
```

  (Falls `_layout` anders heißt: in `main.gd` nachsehen, die Funktion mit den
  `$Hud.offset_*`-Zeilen.)

- [ ] **Step 6: Grün** — `bash tools/test.sh`, `rc=0`.
- [ ] **Step 7: Commit**

```bash
git add scenes/ui/buff_bar.gd scenes/main.tscn scenes/main.gd tests/test_buff_bar.gd tests/run_tests.gd
git commit -m "Trankreihe: laufende Traenke mit Restzeit unter der Kopfzeile"
```

### Task 5: Bilder im Tränke-Reiter

**Files:**
- Modify: `scenes/ui/panels/potion_panel.gd` (`_row`)
- Test: `tests/test_potion_icons.gd`

**Interfaces:**
- Consumes: `potion_<id>.png`.

- [ ] **Step 1: Test** in `tests/test_potion_icons.gd`:

```gdscript
func test_der_beutel_zeigt_das_bild() -> void:
	Game.new_game()
	Game.consumable_counts[&"wert_trank"] = 1
	var p = load("res://scenes/ui/panels/potion_panel.gd").new()
	(Engine.get_main_loop() as SceneTree).root.add_child(p)
	p.refresh()
	var bilder := p.find_children("*", "TextureRect", true, false)
	assert_true(bilder.size() >= 1, "kein Trankbild im Beutel")
	p.free()
```


- [ ] **Step 2: Rot**, dann in `_row(c)` die Titelzeile in eine `HBoxContainer`
  mit einem `TextureRect` (48×48, `EXPAND_IGNORE_SIZE`, `TEXTURE_FILTER_NEAREST`,
  `potion_<id>.png`) vor dem `title`-Label packen.
- [ ] **Step 3: Grün** — `bash tools/test.sh`, `rc=0`.
- [ ] **Step 4: Commit**

```bash
git add scenes/ui/panels/potion_panel.gd tests/test_potion_icons.gd
git commit -m "Traenke-Reiter zeigt die Bilder"
```

### Task 6: Auf dem Gerät

- [ ] Push, `gh workflow run build.yml --ref master`, Tests- und Build-Lauf
  abwarten (beide `success`), APK laden, `bash tools/sign.sh <apk> --install`.
- [ ] Nutzer bitten, einen Trank zu trinken und einen Fisch zu fangen; die
  Reihe links, die Karte oben mittig, das Ausblenden bei offenem Menü prüfen.
