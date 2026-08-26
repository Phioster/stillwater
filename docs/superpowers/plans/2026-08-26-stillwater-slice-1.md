# Stillwater Slice 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein spielbarer Vertical Slice von Stillwater — automatisches Angeln, Biss, Auto- und Orb-Fang, Inventar, Verkauf, Upgrades, zwei Zonen, Journal, Charakteranpassung, Save und Offline-Fortschritt — als Android-APK.

**Architecture:** Simulationskern plus dünne Ansicht. Die gesamte Spiellogik liegt in `core/` als reine `RefCounted`-Klassen ohne Nodes und ohne Szenenbezug; Szenen und UI zeigen sie nur an. Der Offline-Fortschritt ist kein zweites System, sondern derselbe `FishingSim.tick()` mit einem großen Delta — deshalb ist `tick()` von Anfang an deltaunabhängig und segmentweise geschlossen gerechnet.

**Tech Stack:** Godot 4.7.2 stable · GDScript · Godot-`Resource` als Datenformat · Godots eigener `SceneTree`-Skriptmodus als Testrunner · GitHub Actions für Tests und APK-Bau

**Spec:** `docs/superpowers/specs/2026-08-26-stillwater-design.md`

## Global Constraints

- Godot **4.7.2 stable**, GDScript, reines 2D. Keine externen Plugins, kein Test-Framework von außen.
- Vor jeder technischen Entscheidung erst prüfen, ob Godot selbst bereits eine Lösung mitbringt.
- **Landscape**, Basisauflösung **1280 × 720**, `stretch_mode = canvas_items`, `stretch_aspect = expand`.
- In `core/` gibt es **kein** `extends Node`, **kein** `get_node`, **kein** `await get_tree()`. Wer dort Zeit braucht, bekommt sie als Parameter.
- Kein Sammelbecken-`GameManager`. Autoloads in Slice 1: `Database`, `Game`, `SaveManager`. Der in der Spec
  genannte `AudioManager` entsteht erst mit dem Audio-Ausbau (siehe TODO) — ein leerer Autoload wäre nur Ballast.
- Dateien bleiben unter **400 Zeilen**.
- Fische, Köder, Zonen, Upgrades und Raritäten stehen ausschließlich in `.tres`-Dateien. Keine hartcodierten Fischdaten, Preise oder Drop-Chancen.
- Preise werden **ausschließlich** in `Economy.sell_price()` berechnet.
- **Namensregel:** Reale Fischarten (Bluegill, Rotauge, Flussbarsch, Spiegelkarpfen, Makrele, Hornhecht, Meerbarbe, Wolfsbarsch) sind frei. Erfundene Namen (Laternenschleie, Glutrochen, Hohlflosse, Teichmade, Eintagsfliegen-Nymphe) sind eigene Erfindungen. Nichts aus Cornerpond übernehmen: keine Grafiken, Sprites, Namen, Texte, UI-Entwürfe, Sounds, Musik.
- Anzeigenamen deutsch, IDs englisch und `snake_case` als `StringName`.
- **Keine Secrets oder Tokens im Repo.** Keine `Co-Authored-By`-Trailer in Commits. Commit-Identität: `Phioster <165709682+Phioster@users.noreply.github.com>` (bereits in `~/stillwater/.git/config` gesetzt).
- Feste Konstanten aus der Spec: Kampffenster 20 s · Bisszeit Willow Lake 25–45 s · Sunset Coast 35–60 s · Shiny-Basis 1/800 · Offline-Deckel 12 h · Qualitätsschwellen 0.12 / 0.30 / 0.55 / 0.75 / 0.89 / 0.97 · Qualitätsmultiplikatoren 0.6 / 0.8 / 1.0 / 1.3 / 1.7 / 2.4 / 3.5 · Gewichtsexponent 1.6 · Shiny-Verkaufsmultiplikator 4.0 · `xp_needed(n) = round(80 · n^1.55)`.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `core/still_rng.gd` | Gesetzter Zufall, speicherbarer Zustand, gewichtete Auswahl |
| `core/fish_roll.gd` | Gewicht, Perzentil, Qualität, Shiny, Fischstärke — reine Statik |
| `core/caught_fish.gd` | Ein gefangenes Exemplar samt Serialisierung |
| `core/economy.gd` | Verkaufspreis — die einzige Preisformel im Projekt |
| `core/progression.gd` | XP pro Fang, XP-Kurve, Levelaufstieg |
| `core/inventory.gd` | Kapazität, Hinzufügen, Verkaufen, Favoriten |
| `core/journal.gd` | Einträge pro Fischart, Entdeckung, Vollendungsgrad |
| `core/sim_context.gd` | Alles, was `FishingSim` zum Rechnen braucht |
| `core/fishing_sim.gd` | Zustandsautomat, Fischauswahl, Kampf, Entkommen |
| `core/offline_sim.gd` | Deckel plus ein einziger großer `tick()` |
| `resources/*.gd` | Die sechs Datenklassen |
| `autoload/Database.gd` | Lädt und indiziert alle `.tres` |
| `autoload/Game.gd` | Spielzustand, Takt, Signale an die UI |
| `autoload/SaveManager.gd` | Serialisieren, Migration, Autosave |
| `scenes/` | Welt, Charakter, Fangansicht, UI-Panels |
| `tools/gen_sprites.py` | Platzhalter-Sprites erzeugen |
| `tests/` | Testrunner und Testfälle |

---

## Task 1: Umgebung, leeres Projekt, Testrunner

**Files:**
- Create: `project.godot`
- Create: `tests/test_case.gd`
- Create: `tests/run_tests.gd`
- Create: `tests/test_smoke.gd`
- Create: `.gitignore`
- Create: `tools/godot.sh`
- Create: `tools/gen_class_cache.py`

**Interfaces:**
- Consumes: nichts
- Produces: `TestCase` mit `assert_eq(actual, expected, msg := "")`, `assert_true(value: bool, msg := "")`, `assert_false(value: bool, msg := "")`, `assert_almost_eq(a: float, b: float, eps := 0.0001, msg := "")`, `assert_between(v: float, lo: float, hi: float, msg := "")` und `var failures: Array[String]`. Testdateien erweitern `TestCase`, Methoden mit Präfix `test_` werden gefunden. `tools/godot.sh` startet Godot headless im proot-Debian und erneuert vorher den Script-Class-Cache.

- [ ] **Step 1: Godot im proot-Debian bereitstellen**

```bash
proot-distro install debian
proot-distro login debian -- /bin/bash -lc '
  apt-get update -qq && apt-get install -y -qq wget unzip ca-certificates libfontconfig1
  mkdir -p /opt/godot && cd /opt/godot
  wget -q https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.arm64.zip
  unzip -o -q Godot_v4.7.2-stable_linux.arm64.zip
  chmod +x Godot_v4.7.2-stable_linux.arm64
  ln -sf /opt/godot/Godot_v4.7.2-stable_linux.arm64 /usr/local/bin/godot
  godot --headless --version
'
```

Erwartet: `4.7.2.stable.official.ed1daf0bf`. `libfontconfig1` ist Pflicht — ohne
das Paket meldet Godot `libfontconfig.so.1: cannot open shared object file`.
Dieser Schritt wurde am 2026-08-26 auf dem Zielgerät verifiziert.

- [ ] **Step 2: Startskript anlegen**

`tools/godot.sh`:

```bash
#!/usr/bin/env bash
# Startet Godot headless im proot-Debian mit dem Projekt aus dem Termux-Home.
#
# Erzeugt vorher den Script-Class-Cache neu. Das uebernimmt sonst der Godot-
# Editor, der auf diesem Geraet aber deterministisch abstuerzt (siehe
# tools/gen_class_cache.py). Ohne den Cache loest kein `class_name` auf.
set -euo pipefail
PROJECT="${PROJECT:-$HOME/stillwater}"
python3 "$PROJECT/tools/gen_class_cache.py" "$PROJECT" >/dev/null
exec proot-distro login debian --bind "$PROJECT:/work" -- \
  /bin/bash -lc 'export GODOT_SILENCE_ROOT_WARNING=1; cd /work && godot --headless "$@"' -- "$@"
```

Dazu gehoert `tools/gen_class_cache.py`, das `.godot/global_script_class_cache.cfg`
aus dem Quellcode erzeugt: es sucht in allen `.gd`-Dateien nach `class_name` und
dem zugehoerigen `extends` und schreibt Godots Cache-Format. Notwendig, weil auf
diesem Geraet jeder Editor-Modus abstuerzt -- `--editor` ebenso wie
`--headless --import`, beide mit `signal 11` in `__libc_free`. In der CI
(x86_64) erzeugt Godot die Datei selbst per `--headless --import`; das Skript
ist reine Geraete-Hilfe und die erzeugte Datei liegt unter dem gitignorierten
`.godot/`.

```bash
chmod +x tools/godot.sh
```

- [ ] **Step 3: Projektdatei anlegen**

`project.godot`:

```ini
config_version=5

[application]
config/name="Stillwater"
config/version="0.1.0"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
```

`window/handheld/orientation=1` ist Landscape. `default_texture_filter=0` ist Nearest — Pflicht für Pixel-Art, sonst verwischt jedes Sprite.

- [ ] **Step 4: `.gitignore` anlegen**

```
.godot/
.import/
export_presets.cfg
build/
*.apk
*.aab
*.keystore
```

- [ ] **Step 5: Testbasis schreiben**

`tests/test_case.gd`:

```gdscript
class_name TestCase
extends RefCounted

var failures: Array[String] = []

func assert_eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		failures.append("erwartet %s, bekommen %s %s" % [expected, actual, msg])

func assert_true(value: bool, msg: String = "") -> void:
	if not value:
		failures.append("erwartet true %s" % msg)

func assert_false(value: bool, msg: String = "") -> void:
	if value:
		failures.append("erwartet false %s" % msg)

func assert_almost_eq(a: float, b: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(a - b) > eps:
		failures.append("erwartet %f ± %f, bekommen %f %s" % [b, eps, a, msg])

func assert_between(v: float, lo: float, hi: float, msg: String = "") -> void:
	if v < lo or v > hi:
		failures.append("erwartet %f..%f, bekommen %f %s" % [lo, hi, v, msg])
```

- [ ] **Step 6: Testrunner schreiben**

`tests/run_tests.gd`:

```gdscript
extends SceneTree

const SUITES := [
	"res://tests/test_smoke.gd",
]

func _init() -> void:
	# Autoloads existieren in _init() noch NICHT — sie werden erst beim ersten
	# Frame in den Baum gehängt. Ohne dieses await sind Database, Game und
	# SaveManager in den Tests null. Empirisch bestätigt mit Godot 4.7.2.
	await process_frame
	# Die Simulation darf während der Tests nicht nebenher weiterlaufen.
	Game.paused = true

	var total := 0
	var failed := 0
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null:
			push_error("Testdatei nicht ladbar: %s" % path)
			failed += 1
			continue
		var suite: TestCase = script.new()
		for method in suite.get_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			suite.call(name)
			if suite.failures.is_empty():
				print("  ok    %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [path.get_file(), name])
				for f in suite.failures:
					print("        %s" % f)
	print("")
	print("%d Tests, %d fehlgeschlagen" % [total, failed])
	quit(1 if failed > 0 else 0)
```

`SUITES` wird in jedem folgenden Task um die neue Testdatei erweitert.

- [ ] **Step 7: Rauchtest schreiben, der fehlschlägt**

`tests/test_smoke.gd`:

```gdscript
extends TestCase

func test_runner_reports_failures() -> void:
	assert_eq(1, 2, "absichtlicher Fehlschlag")
```

- [ ] **Step 8: Testlauf — muss rot sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `FAIL  test_smoke.gd::test_runner_reports_failures`, Schlusszeile `1 Tests, 1 fehlgeschlagen`, Exit-Code 1.

- [ ] **Step 9: Rauchtest auf grün drehen**

```gdscript
extends TestCase

func test_runner_reports_passes() -> void:
	assert_eq(1, 1)

func test_assert_between_accepts_bounds() -> void:
	assert_between(0.5, 0.0, 1.0)
```

- [ ] **Step 10: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `2 Tests, 0 fehlgeschlagen`, Exit-Code 0.

- [ ] **Step 11: Commit**

```bash
cd ~/stillwater
git add project.godot .gitignore tools/godot.sh tools/gen_class_cache.py tests/
git commit -m "Godot-Projekt, Testrunner und Testbasis"
```

---

## Task 2: Zufall mit speicherbarem Zustand

**Files:**
- Create: `core/still_rng.gd`
- Create: `tests/test_still_rng.gd`
- Modify: `tests/run_tests.gd` (SUITES erweitern)

**Interfaces:**
- Consumes: `TestCase` aus Task 1
- Produces: `StillRNG` mit `_init(seed_value: int = 0)`, `randf() -> float`, `randf_range(a: float, b: float) -> float`, `randfn(mean: float, deviation: float) -> float`, `weighted_pick(weights: PackedFloat64Array) -> int`, `get_state() -> int`, `set_state(s: int) -> void`

- [ ] **Step 1: Failing test schreiben**

`tests/test_still_rng.gd`:

```gdscript
extends TestCase

func test_same_seed_gives_same_sequence() -> void:
	var a := StillRNG.new(1234)
	var b := StillRNG.new(1234)
	for i in 20:
		assert_almost_eq(a.randf(), b.randf(), 0.0, "Schritt %d" % i)

func test_state_roundtrip_resumes_sequence() -> void:
	var a := StillRNG.new(99)
	for i in 5:
		a.randf()
	var state := a.get_state()
	var expected := a.randf()
	var b := StillRNG.new(99)
	b.set_state(state)
	assert_almost_eq(b.randf(), expected, 0.0)

func test_weighted_pick_respects_weights() -> void:
	var rng := StillRNG.new(7)
	var counts := [0, 0, 0]
	var weights := PackedFloat64Array([0.0, 90.0, 10.0])
	for i in 2000:
		counts[rng.weighted_pick(weights)] += 1
	assert_eq(counts[0], 0, "Gewicht 0 darf nie gezogen werden")
	assert_between(float(counts[1]) / 2000.0, 0.85, 0.95)

func test_weighted_pick_returns_minus_one_on_empty() -> void:
	var rng := StillRNG.new(1)
	assert_eq(rng.weighted_pick(PackedFloat64Array([0.0, 0.0])), -1)
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

`tests/run_tests.gd` SUITES um `"res://tests/test_still_rng.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: Parse-Fehler oder `Identifier "StillRNG" not declared`.

- [ ] **Step 3: Implementieren**

`core/still_rng.gd`:

```gdscript
class_name StillRNG
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

func get_state() -> int:
	return int(_rng.state)

func set_state(s: int) -> void:
	_rng.state = s

func randf() -> float:
	return _rng.randf()

func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)

func randfn(mean: float, deviation: float) -> float:
	return _rng.randfn(mean, deviation)

## Zieht einen Index proportional zu den Gewichten.
## Gibt -1 zurück, wenn die Summe aller Gewichte 0 oder kleiner ist.
func weighted_pick(weights: PackedFloat64Array) -> int:
	var total := 0.0
	for w in weights:
		if w > 0.0:
			total += w
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		if weights[i] <= 0.0:
			continue
		acc += weights[i]
		if roll < acc:
			return i
	return weights.size() - 1
```

- [ ] **Step 4: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `6 Tests, 0 fehlgeschlagen`.

- [ ] **Step 5: Commit**

```bash
cd ~/stillwater
git add core/still_rng.gd tests/test_still_rng.gd tests/run_tests.gd
git commit -m "StillRNG mit speicherbarem Zustand und gewichteter Auswahl"
```

---

## Task 3: Die sechs Datenklassen

**Files:**
- Create: `resources/rarity_data.gd`
- Create: `resources/fish_data.gd`
- Create: `resources/bait_data.gd`
- Create: `resources/zone_data.gd`
- Create: `resources/upgrade_data.gd`
- Create: `resources/catch_condition.gd`
- Create: `resources/bait_condition.gd`
- Create: `resources/level_condition.gd`
- Create: `tests/test_conditions.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: nichts
- Produces: `RarityData`, `FishData`, `BaitData`, `ZoneData`, `UpgradeData`, `CatchCondition` mit `is_met(state: Dictionary) -> bool`, `BaitCondition`, `LevelCondition`. Der `state`-Dictionary hat die Schlüssel `bait_id: StringName`, `player_level: int`, `cosmetics: Dictionary`, `zone_id: StringName`.

- [ ] **Step 1: Failing test schreiben**

`tests/test_conditions.gd`:

```gdscript
extends TestCase

func _state(bait: StringName, level: int) -> Dictionary:
	return {"bait_id": bait, "player_level": level, "cosmetics": {}, "zone_id": &"willow_lake"}

func test_bait_condition_matches_exact_bait() -> void:
	var c := BaitCondition.new()
	c.bait_id = &"mayfly_nymph"
	assert_true(c.is_met(_state(&"mayfly_nymph", 1)))
	assert_false(c.is_met(_state(&"pond_grub", 1)))

func test_level_condition_is_inclusive() -> void:
	var c := LevelCondition.new()
	c.min_level = 5
	assert_false(c.is_met(_state(&"pond_grub", 4)))
	assert_true(c.is_met(_state(&"pond_grub", 5)))
	assert_true(c.is_met(_state(&"pond_grub", 9)))

func test_base_condition_is_always_met() -> void:
	var c := CatchCondition.new()
	assert_true(c.is_met(_state(&"pond_grub", 1)))

func test_fish_data_defaults_are_sane() -> void:
	var f := FishData.new()
	assert_false(f.is_secret)
	assert_almost_eq(f.preferred_bait_mult, 2.0)
	assert_almost_eq(f.secret_chance, 0.0)
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_conditions.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "BaitCondition" not declared`.

- [ ] **Step 3: Bedingungen implementieren**

`resources/catch_condition.gd`:

```gdscript
## Basisklasse aller Fangbedingungen. Erfüllt sich selbst immer.
## Der state-Dictionary enthält: bait_id, player_level, cosmetics, zone_id.
class_name CatchCondition
extends Resource

func is_met(_state: Dictionary) -> bool:
	return true

func describe() -> String:
	return ""
```

`resources/bait_condition.gd`:

```gdscript
class_name BaitCondition
extends CatchCondition

@export var bait_id: StringName = &""

func is_met(state: Dictionary) -> bool:
	return state.get("bait_id", &"") == bait_id

func describe() -> String:
	return "Verlangt einen bestimmten Köder"
```

`resources/level_condition.gd`:

```gdscript
class_name LevelCondition
extends CatchCondition

@export var min_level: int = 1

func is_met(state: Dictionary) -> bool:
	return int(state.get("player_level", 1)) >= min_level

func describe() -> String:
	return "Ab Level %d" % min_level
```

- [ ] **Step 4: Datenklassen implementieren**

`resources/rarity_data.gd`:

```gdscript
class_name RarityData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var value_mult: float = 1.0
@export var xp_mult: float = 1.0
@export var strength_mult: float = 1.0
@export var quality_bias: float = 0.0
```

`resources/fish_data.gd`:

```gdscript
class_name FishData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var zone_id: StringName = &""
@export var rarity_id: StringName = &"common"
@export var base_value: int = 1
@export var strength: float = 10.0
@export var xp: int = 1
@export var sprite: Texture2D
@export var spawn_weight: float = 1.0
@export var preferred_baits: Array[StringName] = []
@export var preferred_bait_mult: float = 2.0
@export var weight_min: float = 0.1
@export var weight_max: float = 1.0

@export_group("Secret")
@export var is_secret: bool = false
@export var secret_chance: float = 0.0
@export var secret_hint: String = ""
@export var conditions: Array[CatchCondition] = []
```

`resources/bait_data.gd`:

```gdscript
class_name BaitData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var cost: int = 0
@export var max_stack: int = 99
@export var unlimited: bool = false
@export var unlock_level: int = 1
## rarity_id -> Faktor auf das Raritätsgewicht der Zone. Fehlende Einträge = 1.0
@export var rarity_weight_bonus: Dictionary = {}
## zone_id -> Faktor. Fehlende Einträge = 1.0
@export var zone_bonus: Dictionary = {}
@export var unlocks_fish: Array[StringName] = []
```

`resources/zone_data.gd`:

```gdscript
class_name ZoneData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var fish: Array[FishData] = []
@export var background: Texture2D
@export var music: AudioStream
@export var bite_time_min: float = 25.0
@export var bite_time_max: float = 45.0
@export var fight_window: float = 20.0
## rarity_id -> Gewicht
@export var rarity_weights: Dictionary = {}
@export var unlock_cost: int = 0
@export var unlock_level: int = 1
```

`resources/upgrade_data.gd`:

```gdscript
class_name UpgradeData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var max_level: int = 50
@export var base_cost: int = 50
@export var cost_growth: float = 1.6
@export var value_base: float = 0.0
@export var value_per_level: float = 1.0

func cost_at(level: int) -> int:
	return int(floor(float(base_cost) * pow(cost_growth, float(level))))

func value_at(level: int) -> float:
	return value_base + value_per_level * float(level)
```

- [ ] **Step 5: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `10 Tests, 0 fehlgeschlagen`.

- [ ] **Step 6: Commit**

```bash
cd ~/stillwater
git add resources/ tests/test_conditions.gd tests/run_tests.gd
git commit -m "Datenklassen und Bedingungssystem als Resources"
```

---

## Task 4: Wurfmechanik — Gewicht, Qualität, Shiny, Stärke

**Files:**
- Create: `core/fish_roll.gd`
- Create: `tests/test_fish_roll.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `StillRNG`, `FishData`, `RarityData`
- Produces: `FishRoll` mit den Konstanten `QUALITY_NAMES: Array[String]`, `QUALITY_THRESHOLDS: Array[float]`, `QUALITY_MULTS: Array[float]`, `WEIGHT_EXPONENT: float`, `SHINY_BASE: float` und den statischen Methoden `roll_weight(fish: FishData, rng: StillRNG) -> float`, `percentile(fish: FishData, weight: float) -> float`, `roll_quality(pct: float, rarity: RarityData, rng: StillRNG) -> int`, `roll_shiny(fish_level: int, consumable_bonus: float, rng: StillRNG) -> bool`, `strength_for(fish: FishData, rarity: RarityData, pct: float) -> float`

- [ ] **Step 1: Failing test schreiben**

`tests/test_fish_roll.gd`:

```gdscript
extends TestCase

func _fish() -> FishData:
	var f := FishData.new()
	f.weight_min = 1.0
	f.weight_max = 5.0
	f.strength = 40.0
	return f

func _rarity(bias: float, strength_mult: float = 1.0) -> RarityData:
	var r := RarityData.new()
	r.quality_bias = bias
	r.strength_mult = strength_mult
	return r

func test_weight_stays_in_bounds() -> void:
	var rng := StillRNG.new(3)
	var f := _fish()
	for i in 500:
		assert_between(FishRoll.roll_weight(f, rng), 1.0, 5.0)

func test_weight_is_biased_towards_light() -> void:
	var rng := StillRNG.new(11)
	var f := _fish()
	var heavy := 0
	for i in 2000:
		if FishRoll.percentile(f, FishRoll.roll_weight(f, rng)) > 0.5:
			heavy += 1
	# Exponent 1.6 heißt: rund 33 % liegen über der Mitte.
	assert_between(float(heavy) / 2000.0, 0.25, 0.42)

func test_percentile_endpoints() -> void:
	var f := _fish()
	assert_almost_eq(FishRoll.percentile(f, 1.0), 0.0)
	assert_almost_eq(FishRoll.percentile(f, 5.0), 1.0)
	assert_almost_eq(FishRoll.percentile(f, 3.0), 0.5)

func test_percentile_handles_zero_span() -> void:
	var f := FishData.new()
	f.weight_min = 2.0
	f.weight_max = 2.0
	assert_almost_eq(FishRoll.percentile(f, 2.0), 0.0)

func test_quality_index_in_range() -> void:
	var rng := StillRNG.new(5)
	var r := _rarity(0.0)
	for i in 500:
		var q := FishRoll.roll_quality(rng.randf(), r, rng)
		assert_between(float(q), 0.0, 6.0)

func test_rarity_bias_lifts_average_quality() -> void:
	var rng := StillRNG.new(21)
	var plain := 0
	var biased := 0
	for i in 3000:
		plain += FishRoll.roll_quality(0.5, _rarity(0.0), rng)
		biased += FishRoll.roll_quality(0.5, _rarity(0.30), rng)
	assert_true(biased > plain, "Bias muss die Qualität heben")

func test_shiny_base_rate() -> void:
	var rng := StillRNG.new(77)
	var hits := 0
	for i in 80000:
		if FishRoll.roll_shiny(0, 1.0, rng):
			hits += 1
	# 80000 / 800 = 100 erwartet
	assert_between(float(hits), 70.0, 135.0)

func test_fish_level_raises_shiny_chance() -> void:
	var rng := StillRNG.new(78)
	var low := 0
	var high := 0
	for i in 80000:
		if FishRoll.roll_shiny(0, 1.0, rng):
			low += 1
		if FishRoll.roll_shiny(20, 1.0, rng):
			high += 1
	assert_true(high > low, "Level 20 muss häufiger shiny sein als Level 0")

func test_strength_scales_with_weight_and_rarity() -> void:
	var f := _fish()
	var r := _rarity(0.0, 2.0)
	# 40 * 2.0 * (0.75 + 0.5 * 0.0) = 60
	assert_almost_eq(FishRoll.strength_for(f, r, 0.0), 60.0)
	# 40 * 2.0 * (0.75 + 0.5 * 1.0) = 100
	assert_almost_eq(FishRoll.strength_for(f, r, 1.0), 100.0)
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_fish_roll.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "FishRoll" not declared`.

- [ ] **Step 3: Implementieren**

`core/fish_roll.gd`:

```gdscript
## Alle Würfe, die aus einer Fischart ein konkretes Exemplar machen.
## Rein statisch und ohne Zustand, damit jeder Wurf einzeln testbar ist.
class_name FishRoll
extends RefCounted

const QUALITY_NAMES: Array[String] = ["E", "D", "C", "B", "A", "S", "S+"]
const QUALITY_THRESHOLDS: Array[float] = [0.12, 0.30, 0.55, 0.75, 0.89, 0.97]
const QUALITY_MULTS: Array[float] = [0.6, 0.8, 1.0, 1.3, 1.7, 2.4, 3.5]
const WEIGHT_EXPONENT: float = 1.6
const SHINY_BASE: float = 1.0 / 800.0
const QUALITY_SPREAD: float = 0.18

static func roll_weight(fish: FishData, rng: StillRNG) -> float:
	var span := fish.weight_max - fish.weight_min
	return fish.weight_min + span * pow(rng.randf(), WEIGHT_EXPONENT)

static func percentile(fish: FishData, weight: float) -> float:
	var span := fish.weight_max - fish.weight_min
	if span <= 0.0:
		return 0.0
	return clampf((weight - fish.weight_min) / span, 0.0, 1.0)

static func roll_quality(pct: float, rarity: RarityData, rng: StillRNG) -> int:
	var q := clampf(0.5 * pct + rarity.quality_bias + rng.randfn(0.0, QUALITY_SPREAD), 0.0, 1.0)
	for i in QUALITY_THRESHOLDS.size():
		if q < QUALITY_THRESHOLDS[i]:
			return i
	return QUALITY_NAMES.size() - 1

static func roll_shiny(fish_level: int, consumable_bonus: float, rng: StillRNG) -> bool:
	return rng.randf() < SHINY_BASE * (1.0 + 0.05 * float(fish_level)) * consumable_bonus

static func strength_for(fish: FishData, rarity: RarityData, pct: float) -> float:
	return fish.strength * rarity.strength_mult * (0.75 + 0.5 * pct)
```

- [ ] **Step 4: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `19 Tests, 0 fehlgeschlagen`.

- [ ] **Step 5: Commit**

```bash
cd ~/stillwater
git add core/fish_roll.gd tests/test_fish_roll.gd tests/run_tests.gd
git commit -m "Wurfmechanik für Gewicht, Qualität, Shiny und Fischstärke"
```

---

## Task 5: Gefangener Fisch, Preis und Fortschritt

**Files:**
- Create: `core/caught_fish.gd`
- Create: `core/economy.gd`
- Create: `core/progression.gd`
- Create: `tests/test_economy.gd`
- Create: `tests/test_progression.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `FishData`, `RarityData`, `FishRoll`
- Produces:
  - `CaughtFish` mit den Feldern `fish_id: StringName`, `weight: float`, `quality: int`, `is_shiny: bool`, `is_favorite: bool`; statisch `make(id: StringName, w: float, q: int, shiny: bool) -> CaughtFish` und `from_dict(d: Dictionary) -> CaughtFish`; Instanzmethode `to_dict() -> Dictionary`
  - `Economy.sell_price(caught: CaughtFish, fish: FishData, rarity: RarityData, consumable_bonus: float = 1.0) -> int` und `Economy.SHINY_MULT: float`
  - `Progression.xp_needed(level: int) -> int`, `Progression.xp_for_catch(fish: FishData, rarity: RarityData, quality: int) -> int`, `Progression.apply_xp(level: int, xp: int, gained: int) -> Dictionary` mit den Schlüsseln `level`, `xp`, `levels_gained`

- [ ] **Step 1: Failing tests schreiben**

`tests/test_economy.gd`:

```gdscript
extends TestCase

func _fish() -> FishData:
	var f := FishData.new()
	f.id = &"test_fish"
	f.base_value = 100
	f.weight_min = 0.0
	f.weight_max = 10.0
	return f

func _rarity(mult: float) -> RarityData:
	var r := RarityData.new()
	r.value_mult = mult
	return r

func test_price_uses_every_factor() -> void:
	var f := _fish()
	var c := CaughtFish.make(&"test_fish", 10.0, 2, false)  # Perzentil 1.0, Qualität C = 1.0
	# 100 * 2.0 * 1.0 * (0.5 + 1.0) = 300
	assert_eq(Economy.sell_price(c, f, _rarity(2.0)), 300)

func test_shiny_quadruples_price() -> void:
	var f := _fish()
	var plain := CaughtFish.make(&"test_fish", 10.0, 2, false)
	var shiny := CaughtFish.make(&"test_fish", 10.0, 2, true)
	assert_eq(Economy.sell_price(shiny, f, _rarity(1.0)), Economy.sell_price(plain, f, _rarity(1.0)) * 4)

func test_quality_multiplier_applies() -> void:
	var f := _fish()
	var c_quality := CaughtFish.make(&"test_fish", 10.0, 2, false)   # C = 1.0
	var s_plus := CaughtFish.make(&"test_fish", 10.0, 6, false)      # S+ = 3.5
	assert_eq(Economy.sell_price(s_plus, f, _rarity(1.0)), int(floor(float(Economy.sell_price(c_quality, f, _rarity(1.0))) * 3.5)))

func test_lightest_fish_is_worth_half_the_weight_factor() -> void:
	var f := _fish()
	var c := CaughtFish.make(&"test_fish", 0.0, 2, false)  # Perzentil 0.0
	# 100 * 1.0 * 1.0 * 0.5 = 50
	assert_eq(Economy.sell_price(c, f, _rarity(1.0)), 50)

func test_consumable_bonus_applies() -> void:
	var f := _fish()
	var c := CaughtFish.make(&"test_fish", 0.0, 2, false)
	assert_eq(Economy.sell_price(c, f, _rarity(1.0), 2.0), 100)

func test_caught_fish_dict_roundtrip() -> void:
	var c := CaughtFish.make(&"bluegill", 0.42, 4, true)
	c.is_favorite = true
	var back := CaughtFish.from_dict(c.to_dict())
	assert_eq(back.fish_id, c.fish_id)
	assert_almost_eq(back.weight, c.weight)
	assert_eq(back.quality, c.quality)
	assert_eq(back.is_shiny, c.is_shiny)
	assert_eq(back.is_favorite, c.is_favorite)
```

`tests/test_progression.gd`:

```gdscript
extends TestCase

func _fish(xp: int) -> FishData:
	var f := FishData.new()
	f.xp = xp
	return f

func _rarity(mult: float) -> RarityData:
	var r := RarityData.new()
	r.xp_mult = mult
	return r

func test_xp_curve_matches_spec() -> void:
	assert_eq(Progression.xp_needed(1), 80)
	assert_eq(Progression.xp_needed(2), int(round(80.0 * pow(2.0, 1.55))))
	assert_true(Progression.xp_needed(10) > Progression.xp_needed(9))

func test_xp_for_catch_scales_with_quality() -> void:
	var f := _fish(100)
	var r := _rarity(1.0)
	# Qualität 0: 100 * 1.0 * 0.75 = 75
	assert_eq(Progression.xp_for_catch(f, r, 0), 75)
	# Qualität 6: 100 * 1.0 * (0.75 + 0.5) = 125
	assert_eq(Progression.xp_for_catch(f, r, 6), 125)

func test_apply_xp_levels_up_once() -> void:
	var out := Progression.apply_xp(1, 0, 80)
	assert_eq(out["level"], 2)
	assert_eq(out["xp"], 0)
	assert_eq(out["levels_gained"], 1)

func test_apply_xp_can_level_up_multiple_times() -> void:
	var out := Progression.apply_xp(1, 0, 100000)
	assert_true(out["levels_gained"] > 5)

func test_apply_xp_keeps_remainder() -> void:
	var out := Progression.apply_xp(1, 0, 90)
	assert_eq(out["level"], 2)
	assert_eq(out["xp"], 10)
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_economy.gd"` und `"res://tests/test_progression.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "CaughtFish" not declared`.

- [ ] **Step 3: `CaughtFish` implementieren**

`core/caught_fish.gd`:

```gdscript
## Ein konkret gefangenes Exemplar. Bewusst nicht als Resource, sondern als
## leichte Instanz — davon liegen hunderte im Inventar und im Spielstand.
class_name CaughtFish
extends RefCounted

var fish_id: StringName = &""
var weight: float = 0.0
var quality: int = 0
var is_shiny: bool = false
var is_favorite: bool = false

static func make(id: StringName, w: float, q: int, shiny: bool) -> CaughtFish:
	var c := CaughtFish.new()
	c.fish_id = id
	c.weight = w
	c.quality = q
	c.is_shiny = shiny
	return c

func to_dict() -> Dictionary:
	return {
		"fish_id": String(fish_id),
		"weight": weight,
		"quality": quality,
		"is_shiny": is_shiny,
		"is_favorite": is_favorite,
	}

static func from_dict(d: Dictionary) -> CaughtFish:
	var c := CaughtFish.new()
	c.fish_id = StringName(d.get("fish_id", ""))
	c.weight = float(d.get("weight", 0.0))
	c.quality = int(d.get("quality", 0))
	c.is_shiny = bool(d.get("is_shiny", false))
	c.is_favorite = bool(d.get("is_favorite", false))
	return c
```

- [ ] **Step 4: `Economy` implementieren**

`core/economy.gd`:

```gdscript
## Die einzige Preisformel des Projekts. Wer anderswo einen Preis rechnet,
## macht einen Fehler.
class_name Economy
extends RefCounted

const SHINY_MULT: float = 4.0

static func sell_price(caught: CaughtFish, fish: FishData, rarity: RarityData, consumable_bonus: float = 1.0) -> int:
	var pct := FishRoll.percentile(fish, caught.weight)
	var price := float(fish.base_value)
	price *= rarity.value_mult
	price *= FishRoll.QUALITY_MULTS[clampi(caught.quality, 0, FishRoll.QUALITY_MULTS.size() - 1)]
	price *= (0.5 + pct)
	if caught.is_shiny:
		price *= SHINY_MULT
	price *= consumable_bonus
	return int(floor(price))
```

- [ ] **Step 5: `Progression` implementieren**

`core/progression.gd`:

```gdscript
## XP-Vergabe und Levelkurve. Bewusst flach: ein Idle-Spiel soll regelmäßig
## kleine Fortschritte zeigen, nicht wenige große.
class_name Progression
extends RefCounted

const XP_BASE: float = 80.0
const XP_EXPONENT: float = 1.55

static func xp_needed(level: int) -> int:
	return int(round(XP_BASE * pow(float(maxi(level, 1)), XP_EXPONENT)))

static func xp_for_catch(fish: FishData, rarity: RarityData, quality: int) -> int:
	var q := clampi(quality, 0, FishRoll.QUALITY_NAMES.size() - 1)
	return int(floor(float(fish.xp) * rarity.xp_mult * (0.75 + 0.5 * float(q) / 6.0)))

## Verrechnet gewonnene XP und gibt den neuen Stand zurück.
static func apply_xp(level: int, xp: int, gained: int) -> Dictionary:
	var l := maxi(level, 1)
	var x := xp + gained
	var gained_levels := 0
	while x >= xp_needed(l):
		x -= xp_needed(l)
		l += 1
		gained_levels += 1
	return {"level": l, "xp": x, "levels_gained": gained_levels}
```

- [ ] **Step 6: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `30 Tests, 0 fehlgeschlagen`.

- [ ] **Step 7: Commit**

```bash
cd ~/stillwater
git add core/caught_fish.gd core/economy.gd core/progression.gd tests/
git commit -m "Gefangener Fisch, Preisformel und XP-Fortschritt"
```

---

## Task 6: Inventar und Journal

**Files:**
- Create: `core/inventory.gd`
- Create: `core/journal.gd`
- Create: `tests/test_inventory.gd`
- Create: `tests/test_journal.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `CaughtFish`, `FishData`, `FishRoll`
- Produces:
  - `Inventory` mit `capacity: int`, `fish: Array[CaughtFish]`, `is_full() -> bool`, `add(c: CaughtFish) -> bool`, `remove_at(i: int) -> CaughtFish`, `sellable() -> Array[CaughtFish]`, `take_sellable() -> Array[CaughtFish]`, `to_array() -> Array`, `load_array(a: Array) -> void`
  - `Journal` mit `entries: Dictionary`, `record(c: CaughtFish, is_secret: bool = false) -> bool`, `is_discovered(id: StringName) -> bool`, `entry(id: StringName) -> Dictionary`, `completion(all_fish: Array[FishData]) -> float`, `has_any_secret() -> bool`, `to_dict() -> Dictionary`, `load_dict(d: Dictionary) -> void`

- [ ] **Step 1: Failing tests schreiben**

`tests/test_inventory.gd`:

```gdscript
extends TestCase

func test_add_until_full() -> void:
	var inv := Inventory.new()
	inv.capacity = 3
	for i in 3:
		assert_true(inv.add(CaughtFish.make(&"a", 1.0, 0, false)))
	assert_true(inv.is_full())
	assert_false(inv.add(CaughtFish.make(&"a", 1.0, 0, false)), "voll heißt: nichts geht mehr rein")
	assert_eq(inv.fish.size(), 3)

func test_favorites_are_not_sellable() -> void:
	var inv := Inventory.new()
	inv.capacity = 10
	var keeper := CaughtFish.make(&"a", 1.0, 0, false)
	keeper.is_favorite = true
	inv.add(keeper)
	inv.add(CaughtFish.make(&"b", 1.0, 0, false))
	assert_eq(inv.sellable().size(), 1)

func test_take_sellable_leaves_favorites_behind() -> void:
	var inv := Inventory.new()
	inv.capacity = 10
	var keeper := CaughtFish.make(&"a", 1.0, 0, false)
	keeper.is_favorite = true
	inv.add(keeper)
	inv.add(CaughtFish.make(&"b", 1.0, 0, false))
	var sold := inv.take_sellable()
	assert_eq(sold.size(), 1)
	assert_eq(inv.fish.size(), 1)
	assert_true(inv.fish[0].is_favorite)

func test_array_roundtrip() -> void:
	var inv := Inventory.new()
	inv.capacity = 10
	inv.add(CaughtFish.make(&"bluegill", 0.3, 4, true))
	var other := Inventory.new()
	other.load_array(inv.to_array())
	assert_eq(other.fish.size(), 1)
	assert_eq(other.fish[0].fish_id, &"bluegill")
	assert_true(other.fish[0].is_shiny)
```

`tests/test_journal.gd`:

```gdscript
extends TestCase

func _fish(id: StringName, secret: bool = false) -> FishData:
	var f := FishData.new()
	f.id = id
	f.is_secret = secret
	f.weight_min = 0.0
	f.weight_max = 10.0
	return f

func test_first_catch_is_a_discovery() -> void:
	var j := Journal.new()
	assert_true(j.record(CaughtFish.make(&"bluegill", 1.0, 2, false)))
	assert_false(j.record(CaughtFish.make(&"bluegill", 1.0, 2, false)))

func test_counts_and_extremes() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 2.0, 1, false))
	j.record(CaughtFish.make(&"bluegill", 5.0, 4, false))
	j.record(CaughtFish.make(&"bluegill", 0.5, 0, false))
	var e := j.entry(&"bluegill")
	assert_eq(e["caught_count"], 3)
	assert_almost_eq(e["best_weight"], 5.0)
	assert_almost_eq(e["worst_weight"], 0.5)
	assert_eq(e["best_quality"], 4)

func test_shiny_flag_sticks() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 1.0, 0, true))
	j.record(CaughtFish.make(&"bluegill", 1.0, 0, false))
	assert_true(j.entry(&"bluegill")["shiny_found"])

func test_completion_ignores_secrets() -> void:
	var j := Journal.new()
	var all: Array[FishData] = [_fish(&"a"), _fish(&"b"), _fish(&"s", true)]
	j.record(CaughtFish.make(&"a", 1.0, 0, false))
	assert_almost_eq(j.completion(all), 0.5, 0.0001, "2 zählbare Fische, einer entdeckt")
	j.record(CaughtFish.make(&"s", 1.0, 0, false))
	assert_almost_eq(j.completion(all), 0.5, 0.0001, "Secret darf die Quote nicht heben")

func test_has_any_secret_flips_after_first_secret() -> void:
	var j := Journal.new()
	var all: Array[FishData] = [_fish(&"a"), _fish(&"s", true)]
	assert_false(j.has_any_secret())
	j.record(CaughtFish.make(&"s", 1.0, 0, false), true)
	assert_true(j.has_any_secret())

func test_dict_roundtrip() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 3.0, 5, true))
	var other := Journal.new()
	other.load_dict(j.to_dict())
	assert_eq(other.entry(&"bluegill")["caught_count"], 1)
	assert_true(other.entry(&"bluegill")["shiny_found"])
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_inventory.gd"` und `"res://tests/test_journal.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "Inventory" not declared`.

- [ ] **Step 3: `Inventory` implementieren**

`core/inventory.gd`:

```gdscript
## Das Fischinventar. Die Kapazität ist die natürliche Bremse für
## Offline-Fortschritt: ist sie erreicht, pausiert das Angeln.
class_name Inventory
extends RefCounted

var capacity: int = 20
var fish: Array[CaughtFish] = []

func is_full() -> bool:
	return fish.size() >= capacity

func add(c: CaughtFish) -> bool:
	if is_full():
		return false
	fish.append(c)
	return true

func remove_at(i: int) -> CaughtFish:
	if i < 0 or i >= fish.size():
		return null
	var c := fish[i]
	fish.remove_at(i)
	return c

## Alles außer Favoriten.
func sellable() -> Array[CaughtFish]:
	var out: Array[CaughtFish] = []
	for c in fish:
		if not c.is_favorite:
			out.append(c)
	return out

## Entfernt alles Verkäufliche aus dem Inventar und gibt es zurück.
func take_sellable() -> Array[CaughtFish]:
	var sold := sellable()
	var kept: Array[CaughtFish] = []
	for c in fish:
		if c.is_favorite:
			kept.append(c)
	fish = kept
	return sold

func to_array() -> Array:
	var out := []
	for c in fish:
		out.append(c.to_dict())
	return out

func load_array(a: Array) -> void:
	fish.clear()
	for d in a:
		fish.append(CaughtFish.from_dict(d))
```

- [ ] **Step 4: `Journal` implementieren**

`core/journal.gd`:

```gdscript
## Das Fisch-Journal. Überlebt das Verkaufen — sonst verliert der Spieler
## beim Verkauf seine Sammlung.
class_name Journal
extends RefCounted

var entries: Dictionary = {}
var _secret_found: bool = false

func _blank() -> Dictionary:
	return {
		"caught_count": 0,
		"best_weight": 0.0,
		"worst_weight": 0.0,
		"best_quality": 0,
		"shiny_found": false,
		"fish_level": 0,
	}

## Trägt einen Fang ein. Gibt true zurück, wenn die Art neu entdeckt wurde.
func record(c: CaughtFish, is_secret: bool = false) -> bool:
	var is_new := not entries.has(c.fish_id)
	var e: Dictionary = entries.get(c.fish_id, _blank())
	if is_new:
		e["best_weight"] = c.weight
		e["worst_weight"] = c.weight
	else:
		e["best_weight"] = maxf(float(e["best_weight"]), c.weight)
		e["worst_weight"] = minf(float(e["worst_weight"]), c.weight)
	e["caught_count"] = int(e["caught_count"]) + 1
	e["best_quality"] = maxi(int(e["best_quality"]), c.quality)
	if c.is_shiny:
		e["shiny_found"] = true
	entries[c.fish_id] = e
	if is_secret:
		_secret_found = true
	return is_new

func is_discovered(id: StringName) -> bool:
	return entries.has(id)

func entry(id: StringName) -> Dictionary:
	return entries.get(id, _blank())

func fish_level(id: StringName) -> int:
	return int(entry(id)["fish_level"])

## Anteil entdeckter Arten. Secret-Fische zählen bewusst nicht mit,
## damit 100 % erreichbar bleibt.
func completion(all_fish: Array[FishData]) -> float:
	var countable := 0
	var found := 0
	for f in all_fish:
		if f.is_secret:
			continue
		countable += 1
		if entries.has(f.id):
			found += 1
	if countable == 0:
		return 0.0
	return float(found) / float(countable)

func has_any_secret() -> bool:
	return _secret_found

func to_dict() -> Dictionary:
	var out := {"secret_found": _secret_found, "entries": {}}
	for id in entries:
		out["entries"][String(id)] = entries[id]
	return out

func load_dict(d: Dictionary) -> void:
	entries.clear()
	_secret_found = bool(d.get("secret_found", false))
	var raw: Dictionary = d.get("entries", {})
	for key in raw:
		entries[StringName(key)] = raw[key]
```

- [ ] **Step 5: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `40 Tests, 0 fehlgeschlagen`.

- [ ] **Step 6: Commit**

```bash
cd ~/stillwater
git add core/inventory.gd core/journal.gd tests/
git commit -m "Inventar mit Favoriten und Journal mit Entdeckungsquote"
```

---

## Task 7: Simulationskontext und Fischauswahl

**Files:**
- Create: `core/sim_context.gd`
- Create: `core/fishing_sim.gd` (nur `select_fish` und Hilfsmethoden)
- Create: `tests/test_fish_selection.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `StillRNG`, `FishData`, `BaitData`, `ZoneData`, `RarityData`, `Inventory`, `Journal`, `CatchCondition`
- Produces:
  - `SimContext` mit `zone: ZoneData`, `bait: BaitData`, `fallback_bait: BaitData`, `bait_counts: Dictionary`, `rod_power: float`, `orb_power: float`, `consumable_bonus: float`, `shiny_bonus: float`, `player_level: int`, `player_xp: int`, `cosmetics: Dictionary`, `rarities: Dictionary`, `inventory: Inventory`, `journal: Journal`; Methoden `rarity_of(fish: FishData) -> RarityData`, `condition_state() -> Dictionary`, `consume_bait() -> void`
  - `FishingSim.select_fish(ctx: SimContext, rng: StillRNG) -> FishData`

- [ ] **Step 1: Failing test schreiben**

`tests/test_fish_selection.gd`:

```gdscript
extends TestCase

func _rarity(id: StringName) -> RarityData:
	var r := RarityData.new()
	r.id = id
	return r

func _fish(id: StringName, rarity: StringName, weight: float = 1.0) -> FishData:
	var f := FishData.new()
	f.id = id
	f.rarity_id = rarity
	f.spawn_weight = weight
	f.weight_min = 1.0
	f.weight_max = 2.0
	return f

func _secret(id: StringName, chance: float, min_level: int, bait: StringName) -> FishData:
	var f := _fish(id, &"rare")
	f.is_secret = true
	f.secret_chance = chance
	var lc := LevelCondition.new()
	lc.min_level = min_level
	var bc := BaitCondition.new()
	bc.bait_id = bait
	f.conditions = [lc, bc]
	return f

func _ctx(fish: Array[FishData], bait_id: StringName = &"pond_grub", level: int = 1) -> SimContext:
	var zone := ZoneData.new()
	zone.id = &"willow_lake"
	zone.fish = fish
	zone.rarity_weights = {&"common": 70.0, &"uncommon": 25.0, &"rare": 5.0}
	var bait := BaitData.new()
	bait.id = bait_id
	var ctx := SimContext.new()
	ctx.zone = zone
	ctx.bait = bait
	ctx.fallback_bait = bait
	ctx.player_level = level
	ctx.rarities = {
		&"common": _rarity(&"common"),
		&"uncommon": _rarity(&"uncommon"),
		&"rare": _rarity(&"rare"),
	}
	ctx.inventory = Inventory.new()
	ctx.journal = Journal.new()
	return ctx

func test_rarity_distribution_follows_zone_weights() -> void:
	var fish: Array[FishData] = [_fish(&"c", &"common"), _fish(&"u", &"uncommon"), _fish(&"r", &"rare")]
	var ctx := _ctx(fish)
	var rng := StillRNG.new(42)
	var counts := {&"c": 0, &"u": 0, &"r": 0}
	for i in 10000:
		counts[FishingSim.select_fish(ctx, rng).id] += 1
	assert_between(float(counts[&"c"]) / 10000.0, 0.66, 0.74)
	assert_between(float(counts[&"u"]) / 10000.0, 0.21, 0.29)
	assert_between(float(counts[&"r"]) / 10000.0, 0.03, 0.07)

func test_bait_bonus_shifts_rarity() -> void:
	var fish: Array[FishData] = [_fish(&"c", &"common"), _fish(&"u", &"uncommon"), _fish(&"r", &"rare")]
	var ctx := _ctx(fish, &"mayfly_nymph")
	ctx.bait.rarity_weight_bonus = {&"uncommon": 1.4, &"rare": 2.2}
	var rng := StillRNG.new(43)
	var rare := 0
	for i in 10000:
		if FishingSim.select_fish(ctx, rng).id == &"r":
			rare += 1
	# 5 * 2.2 = 11 von (70 + 35 + 11) = 116 → rund 9,5 %
	assert_between(float(rare) / 10000.0, 0.07, 0.12)

func test_spawn_weight_splits_within_rarity() -> void:
	var fish: Array[FishData] = [_fish(&"c1", &"common", 3.0), _fish(&"c2", &"common", 1.0)]
	var ctx := _ctx(fish)
	ctx.zone.rarity_weights = {&"common": 1.0}
	var rng := StillRNG.new(44)
	var first := 0
	for i in 8000:
		if FishingSim.select_fish(ctx, rng).id == &"c1":
			first += 1
	assert_between(float(first) / 8000.0, 0.71, 0.79)

func test_preferred_bait_doubles_spawn_weight() -> void:
	var a := _fish(&"c1", &"common", 1.0)
	a.preferred_baits = [&"mayfly_nymph"]
	var fish: Array[FishData] = [a, _fish(&"c2", &"common", 1.0)]
	var ctx := _ctx(fish, &"mayfly_nymph")
	ctx.zone.rarity_weights = {&"common": 1.0}
	var rng := StillRNG.new(45)
	var first := 0
	for i in 8000:
		if FishingSim.select_fish(ctx, rng).id == &"c1":
			first += 1
	assert_between(float(first) / 8000.0, 0.63, 0.71)

func test_secret_never_appears_when_conditions_unmet() -> void:
	var fish: Array[FishData] = [_fish(&"c", &"common"), _secret(&"hollowfin", 1.0, 5, &"mayfly_nymph")]
	var ctx := _ctx(fish, &"pond_grub", 9)  # Level passt, Köder nicht
	var rng := StillRNG.new(46)
	for i in 3000:
		assert_eq(FishingSim.select_fish(ctx, rng).id, &"c")

func test_secret_appears_when_all_conditions_met() -> void:
	var fish: Array[FishData] = [_fish(&"c", &"common"), _secret(&"hollowfin", 1.0, 5, &"mayfly_nymph")]
	var ctx := _ctx(fish, &"mayfly_nymph", 5)
	var rng := StillRNG.new(47)
	assert_eq(FishingSim.select_fish(ctx, rng).id, &"hollowfin", "Chance 1.0 muss immer treffen")

func test_secret_is_excluded_from_normal_table() -> void:
	var fish: Array[FishData] = [_fish(&"r", &"rare"), _secret(&"hollowfin", 0.0, 1, &"pond_grub")]
	var ctx := _ctx(fish)
	ctx.zone.rarity_weights = {&"rare": 1.0}
	var rng := StillRNG.new(48)
	for i in 3000:
		assert_eq(FishingSim.select_fish(ctx, rng).id, &"r", "Chance 0.0 heißt nie, auch nicht über die Raritätstabelle")

func test_consume_bait_falls_back_when_empty() -> void:
	var ctx := _ctx([_fish(&"c", &"common")], &"mayfly_nymph")
	var basic := BaitData.new()
	basic.id = &"pond_grub"
	basic.unlimited = true
	ctx.fallback_bait = basic
	ctx.bait_counts = {&"mayfly_nymph": 1}
	ctx.consume_bait()
	assert_eq(ctx.bait_counts[&"mayfly_nymph"], 0)
	assert_eq(ctx.bait.id, &"pond_grub", "leerer Köder muss auf den Grundköder zurückfallen")

func test_unlimited_bait_is_never_consumed() -> void:
	var ctx := _ctx([_fish(&"c", &"common")], &"pond_grub")
	ctx.bait.unlimited = true
	ctx.bait_counts = {}
	ctx.consume_bait()
	assert_eq(ctx.bait.id, &"pond_grub")
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_fish_selection.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "SimContext" not declared`.

- [ ] **Step 3: `SimContext` implementieren**

`core/sim_context.gd`:

```gdscript
## Alles, was FishingSim zum Rechnen braucht. Bewusst ein einfacher
## Datenhalter ohne Node-Bezug, damit Tests ihn in drei Zeilen bauen können.
class_name SimContext
extends RefCounted

var zone: ZoneData
var bait: BaitData
var fallback_bait: BaitData
var bait_counts: Dictionary = {}

var rod_power: float = 4.0
var orb_power: float = 6.0
var consumable_bonus: float = 1.0
var shiny_bonus: float = 1.0

var player_level: int = 1
var player_xp: int = 0
var cosmetics: Dictionary = {}

var rarities: Dictionary = {}
var inventory: Inventory
var journal: Journal

func rarity_of(fish: FishData) -> RarityData:
	var r: RarityData = rarities.get(fish.rarity_id)
	if r == null:
		r = RarityData.new()
		r.id = fish.rarity_id
	return r

## Der Zustand, gegen den Fangbedingungen prüfen.
func condition_state() -> Dictionary:
	return {
		"bait_id": bait.id if bait != null else &"",
		"player_level": player_level,
		"cosmetics": cosmetics,
		"zone_id": zone.id if zone != null else &"",
	}

## Verbraucht einen Köder. Der Grundköder ist unbegrenzt; läuft ein
## gekaufter Köder leer, wird automatisch auf ihn zurückgeschaltet, damit
## eine lange Idle-Session nie an leerem Köder stehen bleibt.
func consume_bait() -> void:
	if bait == null or bait.unlimited:
		return
	var left := int(bait_counts.get(bait.id, 0)) - 1
	bait_counts[bait.id] = maxi(left, 0)
	if left <= 0 and fallback_bait != null:
		bait = fallback_bait
```

- [ ] **Step 4: `FishingSim.select_fish` implementieren**

`core/fishing_sim.gd` (erster Teil — der Zustandsautomat folgt in Task 8):

```gdscript
## Der Simulationskern. Enthält keine Nodes und keinen Szenenbezug:
## dieselbe Klasse treibt das laufende Spiel und den Offline-Fortschritt.
class_name FishingSim
extends RefCounted

## Wählt den Fisch für einen Biss.
## Reihenfolge: erst der Secret-Durchgang, dann Rarität, dann Art.
static func select_fish(ctx: SimContext, rng: StillRNG) -> FishData:
	var secret := _roll_secret(ctx, rng)
	if secret != null:
		return secret
	var rarity_id := _roll_rarity(ctx, rng)
	if rarity_id == &"":
		return null
	return _roll_fish_of_rarity(ctx, rarity_id, rng)

static func _roll_secret(ctx: SimContext, rng: StillRNG) -> FishData:
	var state := ctx.condition_state()
	for f in ctx.zone.fish:
		if not f.is_secret:
			continue
		if not _conditions_met(f, state):
			continue
		if rng.randf() < f.secret_chance:
			return f
	return null

static func _conditions_met(fish: FishData, state: Dictionary) -> bool:
	for c in fish.conditions:
		if c == null:
			continue
		if not c.is_met(state):
			return false
	return true

static func _roll_rarity(ctx: SimContext, rng: StillRNG) -> StringName:
	var ids: Array = ctx.zone.rarity_weights.keys()
	var weights := PackedFloat64Array()
	for id in ids:
		var w := float(ctx.zone.rarity_weights[id])
		if ctx.bait != null:
			w *= float(ctx.bait.rarity_weight_bonus.get(id, 1.0))
		weights.append(w)
	var i := rng.weighted_pick(weights)
	return ids[i] if i >= 0 else &""

static func _roll_fish_of_rarity(ctx: SimContext, rarity_id: StringName, rng: StillRNG) -> FishData:
	var pool: Array[FishData] = []
	var weights := PackedFloat64Array()
	for f in ctx.zone.fish:
		if f.is_secret or f.rarity_id != rarity_id:
			continue
		var w := f.spawn_weight
		if ctx.bait != null and ctx.bait.id in f.preferred_baits:
			w *= f.preferred_bait_mult
		pool.append(f)
		weights.append(w)
	if pool.is_empty():
		return null
	var i := rng.weighted_pick(weights)
	return pool[i] if i >= 0 else null
```

- [ ] **Step 5: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `49 Tests, 0 fehlgeschlagen`.

- [ ] **Step 6: Commit**

```bash
cd ~/stillwater
git add core/sim_context.gd core/fishing_sim.gd tests/
git commit -m "Simulationskontext und Fischauswahl mit Secret-Durchgang"
```

---

## Task 8: Zustandsautomat, Kampf und Entkommen

**Files:**
- Modify: `core/fishing_sim.gd` (Zustandsautomat ergänzen)
- Create: `tests/test_fishing_sim.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: alles aus Task 7, plus `FishRoll`, `Progression`, `CaughtFish`
- Produces: `FishingSim.State` (`IDLE`, `CASTING`, `WAITING`, `FIGHT`, `INVENTORY_FULL`), Felder `state: int`, `timer: float`, `hooked: FishData`, `hooked_strength: float`, `hooked_max_strength: float`; Methoden `tick(delta: float, ctx: SimContext, rng: StillRNG) -> Array` und `tap(ctx: SimContext) -> Array`. Ereignis-Dictionaries mit `type` aus `bite`, `caught`, `escaped`, `level_up`, `inventory_full`.

- [ ] **Step 1: Failing test schreiben**

`tests/test_fishing_sim.gd`:

```gdscript
extends TestCase

func _rarity() -> RarityData:
	var r := RarityData.new()
	r.id = &"common"
	return r

func _fish(strength: float) -> FishData:
	var f := FishData.new()
	f.id = &"testfish"
	f.rarity_id = &"common"
	f.base_value = 10
	f.strength = strength
	f.xp = 10
	f.weight_min = 1.0
	f.weight_max = 1.0   # Perzentil immer 0 → Stärke exakt vorhersagbar
	f.spawn_weight = 1.0
	return f

func _ctx(strength: float, capacity: int = 100) -> SimContext:
	var zone := ZoneData.new()
	zone.id = &"willow_lake"
	zone.fish = [_fish(strength)]
	zone.rarity_weights = {&"common": 1.0}
	zone.bite_time_min = 10.0
	zone.bite_time_max = 10.0   # feste Bisszeit macht den Test exakt
	zone.fight_window = 20.0
	var bait := BaitData.new()
	bait.id = &"pond_grub"
	bait.unlimited = true
	var ctx := SimContext.new()
	ctx.zone = zone
	ctx.bait = bait
	ctx.fallback_bait = bait
	ctx.rarities = {&"common": _rarity()}
	ctx.inventory = Inventory.new()
	ctx.inventory.capacity = capacity
	ctx.journal = Journal.new()
	ctx.rod_power = 4.0
	ctx.orb_power = 6.0
	return ctx

func _types(events: Array) -> Array:
	var out := []
	for e in events:
		out.append(e["type"])
	return out

func test_first_tick_starts_casting() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(10.0)
	sim.tick(0.1, ctx, StillRNG.new(1))
	assert_eq(sim.state, FishingSim.State.CASTING)

func test_bite_happens_after_cast_and_wait() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(10.0)
	# 1 s Wurf + 10 s Warten = 11 s
	var events := sim.tick(10.9, ctx, StillRNG.new(1))
	assert_false("bite" in _types(events), "bei 10.9 s darf noch nichts beißen")
	events = sim.tick(0.2, ctx, StillRNG.new(1))
	assert_true("bite" in _types(events))
	assert_eq(sim.state, FishingSim.State.FIGHT)

func test_weak_fish_is_landed_automatically() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0)   # 20 Stärke bei Rod Power 4 = 5 s
	var events := sim.tick(11.0 + 5.1, ctx, StillRNG.new(1))
	assert_true("caught" in _types(events))
	assert_eq(ctx.inventory.fish.size(), 1)

func test_strong_fish_escapes_after_the_window() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(200.0)  # 200 / 4 = 50 s, Fenster ist 20 s
	var events := sim.tick(11.0 + 20.1, ctx, StillRNG.new(1))
	assert_true("escaped" in _types(events))
	assert_eq(ctx.inventory.fish.size(), 0)
	assert_false("caught" in _types(events))

func test_tapping_saves_a_fish_that_would_escape() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(100.0)  # 100 / 4 = 25 s > 20 s Fenster
	sim.tick(11.1, ctx, StillRNG.new(1))
	assert_eq(sim.state, FishingSim.State.FIGHT)
	var caught := false
	for i in 20:
		if "caught" in _types(sim.tap(ctx)):
			caught = true
			break
	assert_true(caught, "20 Taps à 6 müssen 100 Stärke brechen")

func test_tap_does_nothing_outside_a_fight() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(10.0)
	assert_eq(sim.tap(ctx).size(), 0)

func test_catch_awards_xp_and_can_level_up() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0)
	var events := sim.tick(11.0 + 5.1, ctx, StillRNG.new(1))
	var xp := 0
	for e in events:
		if e["type"] == "caught":
			xp = int(e["xp"])
	assert_true(xp > 0)
	assert_true(ctx.player_xp > 0 or ctx.player_level > 1)

func test_catch_records_the_journal() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0)
	sim.tick(11.0 + 5.1, ctx, StillRNG.new(1))
	assert_true(ctx.journal.is_discovered(&"testfish"))

func test_full_inventory_pauses_fishing() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0, 1)
	sim.tick(3600.0, ctx, StillRNG.new(1))
	assert_eq(ctx.inventory.fish.size(), 1)
	assert_eq(sim.state, FishingSim.State.INVENTORY_FULL)

func test_fishing_resumes_after_inventory_is_emptied() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0, 1)
	sim.tick(3600.0, ctx, StillRNG.new(1))
	assert_eq(sim.state, FishingSim.State.INVENTORY_FULL)
	ctx.inventory.take_sellable()
	sim.tick(11.0 + 5.1, ctx, StillRNG.new(2))
	assert_eq(ctx.inventory.fish.size(), 1)

func test_many_catches_over_an_hour() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0, 10000)
	sim.tick(3600.0, ctx, StillRNG.new(3))
	# 1 s Wurf + 10 s Warten + 5 s Kampf = 16 s pro Fisch → rund 225
	assert_between(float(ctx.inventory.fish.size()), 200.0, 240.0)
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_fishing_sim.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Invalid access to constant 'State'` oder `Invalid call to function 'tick'`.

- [ ] **Step 3: Zustandsautomat implementieren**

An `core/fishing_sim.gd` anfügen — oberhalb der bestehenden statischen Methoden:

```gdscript
enum State { IDLE, CASTING, WAITING, FIGHT, INVENTORY_FULL }

const CAST_TIME: float = 1.0
const ESCAPE_COOLDOWN: float = 2.0
## Schutz gegen Endlosschleifen bei einem sehr großen Delta.
const MAX_SEGMENTS: int = 500000

var state: int = State.IDLE
var timer: float = 0.0
var hooked: FishData = null
var hooked_strength: float = 0.0
var hooked_max_strength: float = 0.0
var hooked_weight: float = 0.0
var hooked_quality: int = 0
var hooked_shiny: bool = false

## Rechnet delta Sekunden Spielzeit ab und gibt die aufgetretenen
## Ereignisse zurück.
##
## Bewusst segmentweise geschlossen gerechnet statt in festen Schritten:
## dadurch liefert ein einziger tick(43200.0) dasselbe Ergebnis wie
## 432000 mal tick(0.1). Genau das macht den Offline-Fortschritt zum
## selben System statt zu einem zweiten.
func tick(delta: float, ctx: SimContext, rng: StillRNG) -> Array:
	var events: Array = []
	var remaining := delta
	var segments := 0
	while remaining > 0.0:
		segments += 1
		if segments > MAX_SEGMENTS:
			break
		match state:
			State.IDLE:
				_start_cast(ctx, events)
			State.INVENTORY_FULL:
				if ctx.inventory.is_full():
					remaining = 0.0
				else:
					state = State.IDLE
			State.CASTING, State.WAITING:
				if remaining < timer:
					timer -= remaining
					remaining = 0.0
				else:
					remaining -= timer
					timer = 0.0
					if state == State.CASTING:
						_begin_wait(ctx, rng)
					else:
						_on_bite(ctx, rng, events)
			State.FIGHT:
				var time_to_land := INF
				if ctx.rod_power > 0.0:
					time_to_land = hooked_strength / ctx.rod_power
				var segment := minf(time_to_land, timer)
				if remaining < segment:
					hooked_strength -= ctx.rod_power * remaining
					timer -= remaining
					remaining = 0.0
				else:
					remaining -= segment
					if time_to_land <= timer:
						_land(ctx, events)
					else:
						_escape(events)
	return events

## Ein Tipp auf einen Orb. Wirkt nur während eines Kampfes.
func tap(ctx: SimContext) -> Array:
	var events: Array = []
	if state != State.FIGHT:
		return events
	hooked_strength -= ctx.orb_power
	if hooked_strength <= 0.0:
		_land(ctx, events)
	return events

func _start_cast(ctx: SimContext, events: Array) -> void:
	if ctx.inventory.is_full():
		state = State.INVENTORY_FULL
		events.append({"type": "inventory_full"})
		return
	state = State.CASTING
	timer = CAST_TIME

func _begin_wait(ctx: SimContext, rng: StillRNG) -> void:
	state = State.WAITING
	timer = rng.randf_range(ctx.zone.bite_time_min, ctx.zone.bite_time_max)

func _on_bite(ctx: SimContext, rng: StillRNG, events: Array) -> void:
	var fish := select_fish(ctx, rng)
	if fish == null:
		state = State.IDLE
		return
	ctx.consume_bait()
	var rarity := ctx.rarity_of(fish)
	hooked = fish
	hooked_weight = FishRoll.roll_weight(fish, rng)
	var pct := FishRoll.percentile(fish, hooked_weight)
	hooked_quality = FishRoll.roll_quality(pct, rarity, rng)
	hooked_shiny = FishRoll.roll_shiny(ctx.journal.fish_level(fish.id), ctx.shiny_bonus, rng)
	hooked_max_strength = FishRoll.strength_for(fish, rarity, pct)
	hooked_strength = hooked_max_strength
	state = State.FIGHT
	timer = ctx.zone.fight_window
	events.append({"type": "bite", "fish": fish, "strength": hooked_strength})

func _land(ctx: SimContext, events: Array) -> void:
	var fish := hooked
	var caught := CaughtFish.make(fish.id, hooked_weight, hooked_quality, hooked_shiny)
	var rarity := ctx.rarity_of(fish)
	var stored := ctx.inventory.add(caught)
	var discovered := ctx.journal.record(caught, fish.is_secret)
	var xp := Progression.xp_for_catch(fish, rarity, hooked_quality)
	var after := Progression.apply_xp(ctx.player_level, ctx.player_xp, xp)
	ctx.player_level = int(after["level"])
	ctx.player_xp = int(after["xp"])
	events.append({
		"type": "caught",
		"fish": fish,
		"caught": caught,
		"xp": xp,
		"discovered": discovered,
		"stored": stored,
	})
	if int(after["levels_gained"]) > 0:
		events.append({"type": "level_up", "level": ctx.player_level})
	hooked = null
	if ctx.inventory.is_full():
		state = State.INVENTORY_FULL
		events.append({"type": "inventory_full"})
	else:
		state = State.CASTING
		timer = CAST_TIME

func _escape(events: Array) -> void:
	events.append({"type": "escaped", "fish": hooked})
	hooked = null
	state = State.CASTING
	timer = ESCAPE_COOLDOWN
```

- [ ] **Step 4: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `60 Tests, 0 fehlgeschlagen`.

- [ ] **Step 5: Commit**

```bash
cd ~/stillwater
git add core/fishing_sim.gd tests/test_fishing_sim.gd tests/run_tests.gd
git commit -m "Zustandsautomat mit Auto-Fang, Orb-Tap und Entkommen-Regel"
```

---

## Task 9: Offline-Fortschritt und der Gleichheitstest

**Files:**
- Create: `core/offline_sim.gd`
- Create: `tests/test_offline_sim.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `FishingSim`, `SimContext`, `StillRNG`, `Economy`
- Produces: `OfflineSim.MAX_OFFLINE_SECONDS: float` und `OfflineSim.run(elapsed_seconds: float, sim: FishingSim, ctx: SimContext, rng: StillRNG, fish_by_id: Dictionary) -> Dictionary` mit den Schlüsseln `elapsed`, `was_capped`, `caught`, `escaped`, `xp`, `discovered`, `potential_coins`, `inventory_full`

- [ ] **Step 1: Failing test schreiben**

`tests/test_offline_sim.gd`:

```gdscript
extends TestCase

func _rarity() -> RarityData:
	var r := RarityData.new()
	r.id = &"common"
	return r

func _fish() -> FishData:
	var f := FishData.new()
	f.id = &"testfish"
	f.rarity_id = &"common"
	f.base_value = 10
	f.strength = 20.0
	f.xp = 10
	f.weight_min = 1.0
	f.weight_max = 4.0
	f.spawn_weight = 1.0
	return f

func _ctx(capacity: int = 10000) -> SimContext:
	var zone := ZoneData.new()
	zone.id = &"willow_lake"
	zone.fish = [_fish()]
	zone.rarity_weights = {&"common": 1.0}
	zone.bite_time_min = 25.0
	zone.bite_time_max = 45.0
	zone.fight_window = 20.0
	var bait := BaitData.new()
	bait.id = &"pond_grub"
	bait.unlimited = true
	var ctx := SimContext.new()
	ctx.zone = zone
	ctx.bait = bait
	ctx.fallback_bait = bait
	ctx.rarities = {&"common": _rarity()}
	ctx.inventory = Inventory.new()
	ctx.inventory.capacity = capacity
	ctx.journal = Journal.new()
	ctx.rod_power = 4.0
	return ctx

func _fish_by_id() -> Dictionary:
	var f := _fish()
	return {f.id: f}

## Der wichtigste Test des Projekts.
func test_offline_equals_online() -> void:
	var seconds := 1800.0

	var online_sim := FishingSim.new()
	var online_ctx := _ctx()
	var online_rng := StillRNG.new(2026)
	var online_ids: Array = []
	var steps := int(seconds / 0.1)
	for i in steps:
		for e in online_sim.tick(0.1, online_ctx, online_rng):
			if e["type"] == "caught":
				online_ids.append(e["caught"].fish_id)

	var offline_sim := FishingSim.new()
	var offline_ctx := _ctx()
	var offline_rng := StillRNG.new(2026)
	var offline_ids: Array = []
	for e in offline_sim.tick(seconds, offline_ctx, offline_rng):
		if e["type"] == "caught":
			offline_ids.append(e["caught"].fish_id)

	assert_eq(offline_ids.size(), online_ids.size(), "gleich viele Fänge")
	assert_eq(offline_ctx.player_level, online_ctx.player_level, "gleiches Level")
	assert_eq(offline_ctx.player_xp, online_ctx.player_xp, "gleiche XP")
	assert_eq(offline_ctx.journal.entry(&"testfish")["caught_count"],
		online_ctx.journal.entry(&"testfish")["caught_count"], "gleicher Journalstand")

func test_offline_is_capped_at_twelve_hours() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx()
	var out := OfflineSim.run(48.0 * 3600.0, sim, ctx, StillRNG.new(5), _fish_by_id())
	assert_almost_eq(float(out["elapsed"]), OfflineSim.MAX_OFFLINE_SECONDS)
	assert_true(out["was_capped"])

func test_offline_stops_at_a_full_inventory() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(5)
	var out := OfflineSim.run(12.0 * 3600.0, sim, ctx, StillRNG.new(6), _fish_by_id())
	assert_eq(ctx.inventory.fish.size(), 5)
	assert_eq(int(out["caught"]), 5)
	assert_true(out["inventory_full"])

func test_offline_reports_potential_coins() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20)
	var out := OfflineSim.run(3600.0, sim, ctx, StillRNG.new(7), _fish_by_id())
	assert_true(int(out["potential_coins"]) > 0, "gefangene Fische müssen einen Wert haben")

func test_zero_elapsed_changes_nothing() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx()
	var out := OfflineSim.run(0.0, sim, ctx, StillRNG.new(8), _fish_by_id())
	assert_eq(int(out["caught"]), 0)
	assert_eq(ctx.inventory.fish.size(), 0)
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_offline_sim.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "OfflineSim" not declared`. Der Gleichheitstest läuft dagegen sofort — er braucht `OfflineSim` gar nicht, weil beide Wege derselbe `tick` sind.

- [ ] **Step 3: Implementieren**

`core/offline_sim.gd`:

```gdscript
## Offline-Fortschritt. Bewusst winzig: die eigentliche Arbeit macht
## FishingSim.tick() mit einem großen Delta. Es gibt kein zweites
## Fangsystem, das auseinanderdriften könnte.
class_name OfflineSim
extends RefCounted

const MAX_OFFLINE_SECONDS: float = 12.0 * 3600.0

static func run(elapsed_seconds: float, sim: FishingSim, ctx: SimContext, rng: StillRNG, fish_by_id: Dictionary) -> Dictionary:
	var capped := clampf(elapsed_seconds, 0.0, MAX_OFFLINE_SECONDS)
	var events := sim.tick(capped, ctx, rng)

	var caught := 0
	var escaped := 0
	var xp := 0
	var coins := 0
	var discovered: Array[StringName] = []
	for e in events:
		match e["type"]:
			"caught":
				caught += 1
				xp += int(e["xp"])
				var c: CaughtFish = e["caught"]
				var fish: FishData = fish_by_id.get(c.fish_id)
				if fish != null:
					coins += Economy.sell_price(c, fish, ctx.rarity_of(fish), ctx.consumable_bonus)
				if bool(e["discovered"]):
					discovered.append(c.fish_id)
			"escaped":
				escaped += 1

	return {
		"elapsed": capped,
		"was_capped": elapsed_seconds > MAX_OFFLINE_SECONDS,
		"caught": caught,
		"escaped": escaped,
		"xp": xp,
		"discovered": discovered,
		"potential_coins": coins,
		"inventory_full": ctx.inventory.is_full(),
	}
```

`potential_coins` ist der Wert der Fische, die jetzt im Inventar liegen — offline verdient niemand Geld, weil offline niemand verkauft. Das Rückkehr-Panel zeigt also „im Inventar liegen Fische im Wert von X", nicht „du hast X verdient".

- [ ] **Step 4: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `65 Tests, 0 fehlgeschlagen`. Der Gleichheitstest braucht am längsten (18 000 Ticks); wenn er grün ist, ist die Fehlerklasse ausgeschlossen, an der Idle-Spiele üblicherweise sterben.

- [ ] **Step 5: Commit**

```bash
cd ~/stillwater
git add core/offline_sim.gd tests/test_offline_sim.gd tests/run_tests.gd
git commit -m "Offline-Fortschritt als derselbe Tick, mit Gleichheitstest"
```

---

## Task 10: Spielinhalte als Resources und die Datenbank

**Files:**
- Create: `tools/build_data.gd`
- Create: `data/rarities/*.tres`, `data/bait/*.tres`, `data/fish/*.tres`, `data/zones/*.tres`, `data/upgrades/*.tres` (vom Seeder erzeugt)
- Create: `autoload/Database.gd`
- Create: `tests/test_database.gd`
- Modify: `project.godot` (Autoload eintragen)
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: alle Resource-Klassen aus Task 3
- Produces: Autoload `Database` mit `rarities: Dictionary`, `baits: Dictionary`, `fish: Dictionary`, `zones: Dictionary`, `upgrades: Dictionary` (jeweils `StringName` → Resource), `all_fish() -> Array[FishData]`, `fish_of_zone(zone_id: StringName) -> Array[FishData]`, `basic_bait() -> BaitData`, `validate() -> Array[String]`

- [ ] **Step 1: Seeder schreiben**

`tools/build_data.gd` — legt die `.tres` einmalig an. Danach sind die `.tres` die Wahrheit; der Seeder bleibt im Repo, um die Inhalte reproduzierbar neu erzeugen zu können.

```gdscript
extends SceneTree

func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("konnte %s nicht speichern: %d" % [path, err])
	else:
		print("  ", path)

func _rarity(id: StringName, name: String, color: Color, v: float, x: float, s: float, bias: float) -> RarityData:
	var r := RarityData.new()
	r.id = id
	r.display_name = name
	r.color = color
	r.value_mult = v
	r.xp_mult = x
	r.strength_mult = s
	r.quality_bias = bias
	_save(r, "res://data/rarities/%s.tres" % id)
	return r

func _fish(id: StringName, name: String, zone: StringName, rarity: StringName,
		value: int, strength: float, xp: int, wmin: float, wmax: float,
		spawn: float = 1.0) -> FishData:
	var f := FishData.new()
	f.id = id
	f.display_name = name
	f.zone_id = zone
	f.rarity_id = rarity
	f.base_value = value
	f.strength = strength
	f.xp = xp
	f.weight_min = wmin
	f.weight_max = wmax
	f.spawn_weight = spawn
	_save(f, "res://data/fish/%s.tres" % id)
	return f

func _init() -> void:
	# Kein await nötig: dieser Seeder legt Resources an und liest keine Autoloads.
	print("Raritäten")
	_rarity(&"common",    "Gewöhnlich", Color("9aa79f"),  1.0,  1.0,  1.0, 0.00)
	_rarity(&"uncommon",  "Ungewöhnlich", Color("5fa77c"), 2.5,  2.0,  2.2, 0.10)
	_rarity(&"rare",      "Selten",     Color("4f8fd0"),  7.0,  4.5,  4.5, 0.20)
	_rarity(&"epic",      "Episch",     Color("9a6fd0"), 20.0, 10.0,  8.0, 0.30)
	_rarity(&"legendary", "Legendär",   Color("d8a24a"), 60.0, 25.0, 14.0, 0.40)

	print("Köder")
	var grub := BaitData.new()
	grub.id = &"pond_grub"
	grub.display_name = "Teichmade"
	grub.cost = 0
	grub.unlimited = true
	grub.max_stack = 0
	grub.unlock_level = 1
	_save(grub, "res://data/bait/pond_grub.tres")

	var nymph := BaitData.new()
	nymph.id = &"mayfly_nymph"
	nymph.display_name = "Eintagsfliegen-Nymphe"
	nymph.cost = 15
	nymph.max_stack = 99
	nymph.unlock_level = 1
	nymph.rarity_weight_bonus = {&"uncommon": 1.4, &"rare": 2.2}
	_save(nymph, "res://data/bait/mayfly_nymph.tres")

	print("Fische Willow Lake")
	var willow: Array[FishData] = [
		_fish(&"bluegill",       "Bluegill",       &"willow_lake", &"common",    8, 12.0,  4, 0.05, 0.35, 1.0),
		_fish(&"roach",          "Rotauge",        &"willow_lake", &"common",   10, 15.0,  5, 0.10, 0.80, 1.0),
		_fish(&"perch",          "Flussbarsch",    &"willow_lake", &"uncommon", 22, 32.0, 12, 0.15, 1.20, 1.0),
		_fish(&"mirror_carp",    "Spiegelkarpfen", &"willow_lake", &"uncommon", 30, 40.0, 16, 1.00, 6.50, 1.0),
		_fish(&"lantern_tench",  "Laternenschleie", &"willow_lake", &"rare",    85, 70.0, 40, 0.80, 3.50, 1.0),
	]

	var hollowfin := _fish(&"hollowfin", "Hohlflosse", &"willow_lake", &"rare", 400, 95.0, 200, 0.50, 2.00, 1.0)
	hollowfin.is_secret = true
	hollowfin.secret_chance = 0.02
	hollowfin.secret_hint = "Etwas meidet hier den gewöhnlichen Köder."
	var lvl := LevelCondition.new()
	lvl.min_level = 5
	var bait_cond := BaitCondition.new()
	bait_cond.bait_id = &"mayfly_nymph"
	hollowfin.conditions = [lvl, bait_cond]
	_save(hollowfin, "res://data/fish/hollowfin.tres")
	willow.append(hollowfin)

	print("Fische Sunset Coast")
	var coast: Array[FishData] = [
		_fish(&"mackerel",   "Makrele",      &"sunset_coast", &"common",    18, 20.0,  8, 0.30,  1.00, 1.0),
		_fish(&"garfish",    "Hornhecht",    &"sunset_coast", &"common",    24, 26.0, 10, 0.40,  1.60, 1.0),
		_fish(&"red_mullet", "Meerbarbe",    &"sunset_coast", &"uncommon",  55, 44.0, 26, 0.25,  1.40, 1.0),
		_fish(&"sea_bass",   "Wolfsbarsch",  &"sunset_coast", &"uncommon",  70, 52.0, 32, 1.00,  7.00, 1.0),
		_fish(&"ember_ray",  "Glutrochen",   &"sunset_coast", &"rare",     180, 88.0, 75, 2.00, 12.00, 1.0),
	]

	print("Zonen")
	var z1 := ZoneData.new()
	z1.id = &"willow_lake"
	z1.display_name = "Willow Lake"
	z1.fish = willow
	z1.bite_time_min = 25.0
	z1.bite_time_max = 45.0
	z1.fight_window = 20.0
	z1.rarity_weights = {&"common": 70.0, &"uncommon": 25.0, &"rare": 5.0}
	z1.unlock_cost = 0
	z1.unlock_level = 1
	_save(z1, "res://data/zones/willow_lake.tres")

	var z2 := ZoneData.new()
	z2.id = &"sunset_coast"
	z2.display_name = "Sunset Coast"
	z2.fish = coast
	z2.bite_time_min = 35.0
	z2.bite_time_max = 60.0
	z2.fight_window = 20.0
	z2.rarity_weights = {&"common": 50.0, &"uncommon": 32.0, &"rare": 18.0}
	z2.unlock_cost = 1500
	z2.unlock_level = 6
	_save(z2, "res://data/zones/sunset_coast.tres")

	print("Upgrades")
	var ups := [
		[&"rod_power",      "Rutenkraft",   "Zieht mehr Fischstärke pro Sekunde ab.",  50, 4.0,  2.0],
		[&"orb_power",      "Orb-Kraft",    "Mehr Schaden pro Tipp auf einen Orb.",    40, 6.0,  3.0],
		[&"fish_inventory", "Fischkiste",   "Mehr Platz für gefangene Fische.",        80, 20.0, 15.0],
		[&"bait_capacity",  "Ködertasche",  "Mehr Platz für gekaufte Köder.",          60, 30.0, 20.0],
	]
	for u in ups:
		var up := UpgradeData.new()
		up.id = u[0]
		up.display_name = u[1]
		up.description = u[2]
		up.base_cost = u[3]
		up.cost_growth = 1.6
		up.value_base = u[4]
		up.value_per_level = u[5]
		up.max_level = 50
		_save(up, "res://data/upgrades/%s.tres" % u[0])

	print("fertig")
	quit(0)
```

- [ ] **Step 2: Seeder ausführen**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tools/build_data.gd`
Expected: eine Zeile pro Datei, Schlusszeile `fertig`. Danach liegen 5 + 2 + 11 + 2 + 4 = 24 `.tres`-Dateien unter `data/`.

- [ ] **Step 3: Failing test schreiben**

`tests/test_database.gd`:

```gdscript
extends TestCase

func test_all_content_loads() -> void:
	assert_eq(Database.rarities.size(), 5)
	assert_eq(Database.baits.size(), 2)
	assert_eq(Database.fish.size(), 11)
	assert_eq(Database.zones.size(), 2)
	assert_eq(Database.upgrades.size(), 4)

func test_validate_reports_no_problems() -> void:
	var problems := Database.validate()
	assert_eq(problems.size(), 0, "Probleme: %s" % str(problems))

func test_willow_lake_has_six_fish_including_the_secret() -> void:
	var f := Database.fish_of_zone(&"willow_lake")
	assert_eq(f.size(), 6)
	var secrets := 0
	for x in f:
		if x.is_secret:
			secrets += 1
	assert_eq(secrets, 1)

func test_basic_bait_is_unlimited_and_free() -> void:
	var b := Database.basic_bait()
	assert_true(b.unlimited)
	assert_eq(b.cost, 0)

func test_secret_fish_has_both_conditions() -> void:
	var h: FishData = Database.fish[&"hollowfin"]
	assert_true(h.is_secret)
	assert_eq(h.conditions.size(), 2)
	assert_almost_eq(h.secret_chance, 0.02)

func test_upgrade_cost_curve() -> void:
	var rod: UpgradeData = Database.upgrades[&"rod_power"]
	assert_eq(rod.cost_at(0), 50)
	assert_eq(rod.cost_at(1), 80)
	assert_almost_eq(rod.value_at(0), 4.0)
	assert_almost_eq(rod.value_at(3), 10.0)

func test_zone_two_is_gated() -> void:
	var z: ZoneData = Database.zones[&"sunset_coast"]
	assert_eq(z.unlock_level, 6)
	assert_eq(z.unlock_cost, 1500)
```

- [ ] **Step 4: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_database.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "Database" not declared`.

- [ ] **Step 5: `Database` implementieren**

`autoload/Database.gd`:

```gdscript
## Lädt alle .tres beim Start und liefert sie per ID aus.
## Der einzige Ort im Projekt, der data/ kennt.
extends Node

var rarities: Dictionary = {}
var baits: Dictionary = {}
var fish: Dictionary = {}
var zones: Dictionary = {}
var upgrades: Dictionary = {}

const _FOLDERS := {
	"rarities": "res://data/rarities",
	"baits": "res://data/bait",
	"fish": "res://data/fish",
	"zones": "res://data/zones",
	"upgrades": "res://data/upgrades",
}

func _ready() -> void:
	load_all()

func load_all() -> void:
	rarities = _load_folder(_FOLDERS["rarities"])
	baits = _load_folder(_FOLDERS["baits"])
	fish = _load_folder(_FOLDERS["fish"])
	zones = _load_folder(_FOLDERS["zones"])
	upgrades = _load_folder(_FOLDERS["upgrades"])

func _load_folder(path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Datenordner fehlt: %s" % path)
		return out
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var res: Resource = load(path.path_join(file))
		if res == null or not ("id" in res):
			push_error("unbrauchbare Datendatei: %s" % file)
			continue
		out[res.id] = res
	return out

func all_fish() -> Array[FishData]:
	var out: Array[FishData] = []
	for id in fish:
		out.append(fish[id])
	return out

func fish_of_zone(zone_id: StringName) -> Array[FishData]:
	var out: Array[FishData] = []
	for id in fish:
		var f: FishData = fish[id]
		if f.zone_id == zone_id:
			out.append(f)
	return out

func basic_bait() -> BaitData:
	for id in baits:
		var b: BaitData = baits[id]
		if b.unlimited:
			return b
	return null

## Prüft die Inhalte auf Verweise ins Leere. Gibt eine leere Liste zurück,
## wenn alles stimmt.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for id in fish:
		var f: FishData = fish[id]
		if not rarities.has(f.rarity_id):
			problems.append("Fisch %s zeigt auf unbekannte Rarität %s" % [f.id, f.rarity_id])
		if not zones.has(f.zone_id):
			problems.append("Fisch %s zeigt auf unbekannte Zone %s" % [f.id, f.zone_id])
		if f.weight_max < f.weight_min:
			problems.append("Fisch %s hat weight_max < weight_min" % f.id)
		if f.is_secret and f.secret_chance <= 0.0:
			problems.append("Secret-Fisch %s hat Chance 0" % f.id)
		for b in f.preferred_baits:
			if not baits.has(b):
				problems.append("Fisch %s bevorzugt unbekannten Köder %s" % [f.id, b])
	for id in zones:
		var z: ZoneData = zones[id]
		if z.fish.is_empty():
			problems.append("Zone %s hat keine Fische" % z.id)
		for r in z.rarity_weights:
			if not rarities.has(r):
				problems.append("Zone %s gewichtet unbekannte Rarität %s" % [z.id, r])
	if basic_bait() == null:
		problems.append("kein unbegrenzter Grundköder vorhanden")
	return problems
```

- [ ] **Step 6: Autoload eintragen**

In `project.godot` ergänzen:

```ini
[autoload]

Database="*res://autoload/Database.gd"
```

- [ ] **Step 7: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `72 Tests, 0 fehlgeschlagen`.

- [ ] **Step 8: Commit**

```bash
cd ~/stillwater
git add tools/build_data.gd data/ autoload/Database.gd project.godot tests/
git commit -m "Spielinhalte als Resources und Datenbank mit Inhaltsprüfung"
```

---

## Task 11: Der Spielzustand

**Files:**
- Create: `autoload/Game.gd`
- Create: `tests/test_game_actions.gd`
- Modify: `project.godot`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Database`, `SimContext`, `FishingSim`, `Inventory`, `Journal`, `Economy`, `Progression`, `StillRNG`
- Produces: Autoload `Game` mit
  - Feldern `coins: int`, `upgrade_levels: Dictionary`, `unlocked_zones: Array[StringName]`, `cosmetics: Dictionary`, `bait_capacity_used: int`, `sim: FishingSim`, `ctx: SimContext`, `rng: StillRNG`, `paused: bool`
  - Signalen `state_changed`, `bite(fish: FishData)`, `caught(caught: CaughtFish, fish: FishData)`, `escaped(fish: FishData)`, `level_up(level: int)`, `inventory_full`, `coins_changed(coins: int)`
  - Methoden `new_game() -> void`, `tap() -> void`, `sell_all() -> int`, `sell_one(index: int) -> int`, `toggle_favorite(index: int) -> void`, `buy_upgrade(id: StringName) -> bool`, `upgrade_value(id: StringName) -> float`, `upgrade_cost(id: StringName) -> int`, `apply_upgrades() -> void`, `buy_bait(id: StringName, amount: int) -> bool`, `set_active_bait(id: StringName) -> void`, `unlock_zone(id: StringName) -> bool`, `travel_to(id: StringName) -> bool`

- [ ] **Step 1: Failing test schreiben**

`tests/test_game_actions.gd`:

```gdscript
extends TestCase

func _fresh() -> void:
	Game.new_game()

func test_new_game_starts_in_willow_lake_with_basic_bait() -> void:
	_fresh()
	assert_eq(Game.ctx.zone.id, &"willow_lake")
	assert_true(Game.ctx.bait.unlimited)
	assert_eq(Game.coins, 0)
	assert_eq(Game.ctx.player_level, 1)

func test_upgrade_values_come_from_data() -> void:
	_fresh()
	assert_almost_eq(Game.upgrade_value(&"rod_power"), 4.0)
	assert_eq(Game.upgrade_cost(&"rod_power"), 50)

func test_buying_an_upgrade_costs_coins_and_raises_the_value() -> void:
	_fresh()
	Game.coins = 100
	assert_true(Game.buy_upgrade(&"rod_power"))
	assert_eq(Game.coins, 50)
	assert_almost_eq(Game.upgrade_value(&"rod_power"), 6.0)
	assert_almost_eq(Game.ctx.rod_power, 6.0, 0.0001, "der Kontext muss mitziehen")

func test_upgrade_is_refused_without_coins() -> void:
	_fresh()
	Game.coins = 10
	assert_false(Game.buy_upgrade(&"rod_power"))
	assert_eq(Game.coins, 10)

func test_inventory_upgrade_raises_capacity() -> void:
	_fresh()
	Game.coins = 100
	assert_eq(Game.ctx.inventory.capacity, 20)
	Game.buy_upgrade(&"fish_inventory")
	assert_eq(Game.ctx.inventory.capacity, 35)

func test_sell_all_pays_and_empties_the_inventory() -> void:
	_fresh()
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.35, 2, false))
	var earned := Game.sell_all()
	assert_true(earned > 0)
	assert_eq(Game.coins, earned)
	assert_eq(Game.ctx.inventory.fish.size(), 0)

func test_sell_all_keeps_favorites() -> void:
	_fresh()
	var keeper := CaughtFish.make(&"bluegill", 0.35, 2, false)
	keeper.is_favorite = true
	Game.ctx.inventory.add(keeper)
	Game.ctx.inventory.add(CaughtFish.make(&"roach", 0.5, 2, false))
	Game.sell_all()
	assert_eq(Game.ctx.inventory.fish.size(), 1)
	assert_true(Game.ctx.inventory.fish[0].is_favorite)

func test_journal_survives_selling() -> void:
	_fresh()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 0.35, 2, false))
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.35, 2, false))
	Game.sell_all()
	assert_true(Game.ctx.journal.is_discovered(&"bluegill"), "verkaufen darf die Sammlung nicht löschen")

func test_buying_bait_respects_capacity() -> void:
	_fresh()
	Game.coins = 10000
	assert_true(Game.buy_bait(&"mayfly_nymph", 10))
	assert_eq(int(Game.ctx.bait_counts[&"mayfly_nymph"]), 10)
	assert_eq(Game.coins, 10000 - 150)
	assert_false(Game.buy_bait(&"mayfly_nymph", 1000), "über die Ködertasche hinaus geht nichts")

func test_zone_two_needs_level_and_coins() -> void:
	_fresh()
	Game.coins = 5000
	assert_false(Game.unlock_zone(&"sunset_coast"), "Level 1 reicht nicht")
	Game.ctx.player_level = 6
	assert_true(Game.unlock_zone(&"sunset_coast"))
	assert_eq(Game.coins, 3500)
	assert_true(&"sunset_coast" in Game.unlocked_zones)

func test_travel_only_to_unlocked_zones() -> void:
	_fresh()
	assert_false(Game.travel_to(&"sunset_coast"))
	Game.coins = 5000
	Game.ctx.player_level = 6
	Game.unlock_zone(&"sunset_coast")
	assert_true(Game.travel_to(&"sunset_coast"))
	assert_eq(Game.ctx.zone.id, &"sunset_coast")
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_game_actions.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "Game" not declared`.

- [ ] **Step 3: Implementieren**

`autoload/Game.gd`:

```gdscript
## Hält den Spielzustand, treibt die Simulation und übersetzt ihre
## Ereignisse in Signale für die UI. Enthält bewusst keine Spielregeln —
## die stehen in core/.
extends Node

signal state_changed
signal bite(fish: FishData)
signal caught(fish_caught: CaughtFish, fish: FishData)
signal escaped(fish: FishData)
signal level_up(level: int)
signal inventory_full
signal coins_changed(value: int)

var coins: int = 0
var upgrade_levels: Dictionary = {}
var unlocked_zones: Array[StringName] = []
var cosmetics: Dictionary = {}

var sim: FishingSim
var ctx: SimContext
var rng: StillRNG
var paused: bool = false

func _ready() -> void:
	if ctx == null:
		new_game()

func new_game() -> void:
	rng = StillRNG.new(randi())
	sim = FishingSim.new()
	coins = 0
	upgrade_levels = {&"rod_power": 0, &"orb_power": 0, &"fish_inventory": 0, &"bait_capacity": 0}
	unlocked_zones = [&"willow_lake"]
	cosmetics = {"skin": 0, "hair": 0, "hair_color": 0, "shirt": 0, "pants": 0, "hat": 0}

	ctx = SimContext.new()
	ctx.zone = Database.zones[&"willow_lake"]
	ctx.fallback_bait = Database.basic_bait()
	ctx.bait = ctx.fallback_bait
	ctx.bait_counts = {}
	ctx.rarities = Database.rarities
	ctx.inventory = Inventory.new()
	ctx.journal = Journal.new()
	ctx.cosmetics = cosmetics
	ctx.player_level = 1
	ctx.player_xp = 0
	apply_upgrades()
	state_changed.emit()

func _process(delta: float) -> void:
	if paused or ctx == null:
		return
	_dispatch(sim.tick(delta * time_scale, ctx, rng))

## Beschleunigt die Simulation für Tests und Entwicklung. Im Release 1.
var time_scale: float = 1.0

func tap() -> void:
	if ctx == null:
		return
	_dispatch(sim.tap(ctx))

func _dispatch(events: Array) -> void:
	for e in events:
		match e["type"]:
			"bite":
				bite.emit(e["fish"])
			"caught":
				caught.emit(e["caught"], e["fish"])
			"escaped":
				escaped.emit(e["fish"])
			"level_up":
				level_up.emit(int(e["level"]))
			"inventory_full":
				inventory_full.emit()
	if not events.is_empty():
		state_changed.emit()

# --- Upgrades -------------------------------------------------------------

func upgrade_cost(id: StringName) -> int:
	var u: UpgradeData = Database.upgrades[id]
	return u.cost_at(int(upgrade_levels.get(id, 0)))

func upgrade_value(id: StringName) -> float:
	var u: UpgradeData = Database.upgrades[id]
	return u.value_at(int(upgrade_levels.get(id, 0)))

func buy_upgrade(id: StringName) -> bool:
	if not Database.upgrades.has(id):
		return false
	var u: UpgradeData = Database.upgrades[id]
	var level := int(upgrade_levels.get(id, 0))
	if level >= u.max_level:
		return false
	var cost := u.cost_at(level)
	if coins < cost:
		return false
	coins -= cost
	upgrade_levels[id] = level + 1
	apply_upgrades()
	coins_changed.emit(coins)
	state_changed.emit()
	return true

## Wird auch vom SaveManager nach dem Laden gerufen, deshalb ohne Unterstrich.
func apply_upgrades() -> void:
	ctx.rod_power = upgrade_value(&"rod_power")
	ctx.orb_power = upgrade_value(&"orb_power")
	ctx.inventory.capacity = int(upgrade_value(&"fish_inventory"))

func bait_capacity() -> int:
	return int(upgrade_value(&"bait_capacity"))

func bait_used() -> int:
	var total := 0
	for id in ctx.bait_counts:
		total += int(ctx.bait_counts[id])
	return total

# --- Verkauf --------------------------------------------------------------

func _price(c: CaughtFish) -> int:
	var f: FishData = Database.fish.get(c.fish_id)
	if f == null:
		return 0
	return Economy.sell_price(c, f, ctx.rarity_of(f), ctx.consumable_bonus)

func sell_all() -> int:
	var earned := 0
	for c in ctx.inventory.take_sellable():
		earned += _price(c)
	coins += earned
	coins_changed.emit(coins)
	state_changed.emit()
	return earned

func sell_one(index: int) -> int:
	var c := ctx.inventory.fish[index] if index >= 0 and index < ctx.inventory.fish.size() else null
	if c == null or c.is_favorite:
		return 0
	ctx.inventory.remove_at(index)
	var earned := _price(c)
	coins += earned
	coins_changed.emit(coins)
	state_changed.emit()
	return earned

func toggle_favorite(index: int) -> void:
	if index < 0 or index >= ctx.inventory.fish.size():
		return
	ctx.inventory.fish[index].is_favorite = not ctx.inventory.fish[index].is_favorite
	state_changed.emit()

# --- Köder ----------------------------------------------------------------

func buy_bait(id: StringName, amount: int) -> bool:
	var b: BaitData = Database.baits.get(id)
	if b == null or b.unlimited or amount <= 0:
		return false
	if bait_used() + amount > bait_capacity():
		return false
	var cost := b.cost * amount
	if coins < cost:
		return false
	coins -= cost
	ctx.bait_counts[id] = int(ctx.bait_counts.get(id, 0)) + amount
	coins_changed.emit(coins)
	state_changed.emit()
	return true

func set_active_bait(id: StringName) -> void:
	var b: BaitData = Database.baits.get(id)
	if b == null:
		return
	if not b.unlimited and int(ctx.bait_counts.get(id, 0)) <= 0:
		return
	ctx.bait = b
	state_changed.emit()

# --- Zonen ----------------------------------------------------------------

func unlock_zone(id: StringName) -> bool:
	var z: ZoneData = Database.zones.get(id)
	if z == null or id in unlocked_zones:
		return false
	if ctx.player_level < z.unlock_level or coins < z.unlock_cost:
		return false
	coins -= z.unlock_cost
	unlocked_zones.append(id)
	coins_changed.emit(coins)
	state_changed.emit()
	return true

func travel_to(id: StringName) -> bool:
	if not id in unlocked_zones:
		return false
	var z: ZoneData = Database.zones.get(id)
	if z == null:
		return false
	ctx.zone = z
	sim = FishingSim.new()
	state_changed.emit()
	return true
```

- [ ] **Step 4: Autoload eintragen**

In `project.godot` unter `[autoload]` ergänzen — **nach** `Database`, weil `Game._ready()` die Datenbank braucht:

```ini
Game="*res://autoload/Game.gd"
```

- [ ] **Step 5: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `83 Tests, 0 fehlgeschlagen`.

- [ ] **Step 6: Commit**

```bash
cd ~/stillwater
git add autoload/Game.gd project.godot tests/
git commit -m "Spielzustand mit Upgrades, Verkauf, Ködern und Zonenwechsel"
```

---

## Task 12: Speichern, Laden, Migration

**Files:**
- Create: `autoload/SaveManager.gd`
- Create: `tests/test_save_manager.gd`
- Modify: `project.godot`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Game`, `Inventory`, `Journal`, `StillRNG`, `OfflineSim`, `Database`
- Produces: Autoload `SaveManager` mit `SAVE_VERSION: int = 1`, `SAVE_PATH: String`, `save() -> bool`, `load_game() -> bool`, `has_save() -> bool`, `delete_save() -> void`, `serialize() -> Dictionary`, `deserialize(d: Dictionary) -> void`, `migrate(d: Dictionary) -> Dictionary`, `pending_offline: Dictionary`; Signal `offline_ready(summary: Dictionary)`

- [ ] **Step 1: Failing test schreiben**

`tests/test_save_manager.gd`:

```gdscript
extends TestCase

func test_roundtrip_restores_everything() -> void:
	Game.new_game()
	Game.coins = 1234
	Game.ctx.player_level = 7
	Game.ctx.player_xp = 55
	Game.upgrade_levels[&"rod_power"] = 3
	Game.unlocked_zones = [&"willow_lake", &"sunset_coast"]
	Game.ctx.bait_counts = {&"mayfly_nymph": 12}
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.3, 4, true))
	Game.ctx.journal.record(CaughtFish.make(&"roach", 0.6, 3, false))

	var blob := SaveManager.serialize()
	Game.new_game()
	SaveManager.deserialize(blob)

	assert_eq(Game.coins, 1234)
	assert_eq(Game.ctx.player_level, 7)
	assert_eq(Game.ctx.player_xp, 55)
	assert_eq(int(Game.upgrade_levels[&"rod_power"]), 3)
	assert_true(&"sunset_coast" in Game.unlocked_zones)
	assert_eq(int(Game.ctx.bait_counts[&"mayfly_nymph"]), 12)
	assert_eq(Game.ctx.inventory.fish.size(), 1)
	assert_true(Game.ctx.inventory.fish[0].is_shiny)
	assert_true(Game.ctx.journal.is_discovered(&"roach"))

func test_upgrades_are_reapplied_after_loading() -> void:
	Game.new_game()
	Game.upgrade_levels[&"rod_power"] = 3
	var blob := SaveManager.serialize()
	Game.new_game()
	SaveManager.deserialize(blob)
	assert_almost_eq(Game.ctx.rod_power, 10.0, 0.0001, "4 + 3 * 2 = 10")

func test_file_roundtrip() -> void:
	Game.new_game()
	Game.coins = 999
	assert_true(SaveManager.save())
	assert_true(SaveManager.has_save())
	Game.new_game()
	assert_true(SaveManager.load_game())
	assert_eq(Game.coins, 999)
	SaveManager.delete_save()
	assert_false(SaveManager.has_save())

func test_missing_file_loads_nothing() -> void:
	SaveManager.delete_save()
	assert_false(SaveManager.load_game())

func test_migration_fills_a_missing_field() -> void:
	var old := {"save_version": 0, "coins": 42}
	var migrated := SaveManager.migrate(old)
	assert_eq(int(migrated["save_version"]), SaveManager.SAVE_VERSION)
	assert_true(migrated.has("unlocked_zones"), "Migration muss fehlende Felder ergänzen")
	assert_eq(int(migrated["coins"]), 42, "vorhandene Werte müssen erhalten bleiben")

func test_rng_state_survives_the_save() -> void:
	Game.new_game()
	for i in 10:
		Game.rng.randf()
	var blob := SaveManager.serialize()

	# Zweimal denselben Spielstand laden muss zweimal denselben Zufall geben.
	Game.new_game()
	SaveManager.deserialize(blob)
	var first := Game.rng.randf()

	Game.new_game()
	SaveManager.deserialize(blob)
	assert_almost_eq(Game.rng.randf(), first, 0.0, "geladener Zufall muss deterministisch sein")

func test_offline_summary_is_produced_on_load() -> void:
	Game.new_game()
	Game.ctx.inventory.capacity = 500
	var blob := SaveManager.serialize()
	blob["last_seen_unix"] = int(Time.get_unix_time_from_system()) - 3600
	Game.new_game()
	SaveManager.deserialize(blob)
	assert_true(int(SaveManager.pending_offline.get("caught", 0)) > 0, "eine Stunde muss Fänge liefern")
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_save_manager.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "SaveManager" not declared`.

- [ ] **Step 3: Implementieren**

`autoload/SaveManager.gd`:

```gdscript
## Spielstand. Schreibt erst in eine Temp-Datei und benennt dann um —
## ein Absturz mitten im Schreiben darf den Spielstand nicht zerlegen.
extends Node

signal offline_ready(summary: Dictionary)

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.json.tmp"
const AUTOSAVE_INTERVAL: float = 60.0

var pending_offline: Dictionary = {}
var _autosave_timer: float = 0.0

func _ready() -> void:
	if has_save():
		load_game()

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save()

# --- Serialisierung -------------------------------------------------------

func serialize() -> Dictionary:
	var upgrades := {}
	for id in Game.upgrade_levels:
		upgrades[String(id)] = int(Game.upgrade_levels[id])
	var baits := {}
	for id in Game.ctx.bait_counts:
		baits[String(id)] = int(Game.ctx.bait_counts[id])
	var zones := []
	for z in Game.unlocked_zones:
		zones.append(String(z))
	return {
		"save_version": SAVE_VERSION,
		"coins": Game.coins,
		"player_level": Game.ctx.player_level,
		"xp": Game.ctx.player_xp,
		"current_zone": String(Game.ctx.zone.id),
		"unlocked_zones": zones,
		"upgrade_levels": upgrades,
		"bait_inventory": baits,
		"active_bait": String(Game.ctx.bait.id),
		"fish_inventory": Game.ctx.inventory.to_array(),
		"journal": Game.ctx.journal.to_dict(),
		"cosmetics": Game.cosmetics,
		"active_consumables": [],
		"settings": {},
		"statistics": {},
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"rng_state": Game.rng.get_state(),
	}

func deserialize(raw: Dictionary) -> void:
	var d := migrate(raw)
	Game.coins = int(d["coins"])
	Game.ctx.player_level = int(d["player_level"])
	Game.ctx.player_xp = int(d["xp"])

	Game.unlocked_zones.clear()
	for z in d["unlocked_zones"]:
		Game.unlocked_zones.append(StringName(z))

	Game.upgrade_levels.clear()
	for id in d["upgrade_levels"]:
		Game.upgrade_levels[StringName(id)] = int(d["upgrade_levels"][id])

	Game.ctx.bait_counts.clear()
	for id in d["bait_inventory"]:
		Game.ctx.bait_counts[StringName(id)] = int(d["bait_inventory"][id])

	var zone: ZoneData = Database.zones.get(StringName(d["current_zone"]))
	if zone != null:
		Game.ctx.zone = zone
	var bait: BaitData = Database.baits.get(StringName(d["active_bait"]))
	Game.ctx.bait = bait if bait != null else Database.basic_bait()

	Game.ctx.inventory.load_array(d["fish_inventory"])
	Game.ctx.journal.load_dict(d["journal"])
	Game.cosmetics = d["cosmetics"]
	Game.ctx.cosmetics = Game.cosmetics
	Game.rng.set_state(int(d["rng_state"]))
	Game.apply_upgrades()

	_run_offline(int(d["last_seen_unix"]))
	Game.state_changed.emit()

func _run_offline(last_seen: int) -> void:
	var elapsed := float(int(Time.get_unix_time_from_system()) - last_seen)
	if elapsed <= 0.0:
		pending_offline = {}
		return
	pending_offline = OfflineSim.run(elapsed, Game.sim, Game.ctx, Game.rng, Database.fish)
	if int(pending_offline.get("caught", 0)) > 0:
		offline_ready.emit(pending_offline)

# --- Migration ------------------------------------------------------------

## Hebt einen alten Spielstand auf die aktuelle Version. Fehlende Felder
## bekommen den Standardwert eines neuen Spiels.
func migrate(raw: Dictionary) -> Dictionary:
	var d := raw.duplicate(true)
	var defaults := {
		"coins": 0,
		"player_level": 1,
		"xp": 0,
		"current_zone": "willow_lake",
		"unlocked_zones": ["willow_lake"],
		"upgrade_levels": {"rod_power": 0, "orb_power": 0, "fish_inventory": 0, "bait_capacity": 0},
		"bait_inventory": {},
		"active_bait": "pond_grub",
		"fish_inventory": [],
		"journal": {"secret_found": false, "entries": {}},
		"cosmetics": {"skin": 0, "hair": 0, "hair_color": 0, "shirt": 0, "pants": 0, "hat": 0},
		"active_consumables": [],
		"settings": {},
		"statistics": {},
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"rng_state": 0,
	}
	for key in defaults:
		if not d.has(key):
			d[key] = defaults[key]
	# Künftige Schritte hier anhängen:
	# if int(d["save_version"]) < 2: d = _migrate_1_to_2(d)
	d["save_version"] = SAVE_VERSION
	return d

# --- Datei ----------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func save() -> bool:
	if Game.ctx == null:
		return false
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Spielstand nicht schreibbar: %d" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(serialize()))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists("save.json"):
		dir.remove("save.json")
	return dir.rename("save.json.tmp", "save.json") == OK

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Spielstand unlesbar, wird ignoriert")
		return false
	deserialize(parsed)
	return true
```

- [ ] **Step 4: Autoload eintragen**

In `project.godot` unter `[autoload]` **nach** `Game`:

```ini
SaveManager="*res://autoload/SaveManager.gd"
```

- [ ] **Step 5: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `90 Tests, 0 fehlgeschlagen`.

- [ ] **Step 6: Commit**

```bash
cd ~/stillwater
git add autoload/SaveManager.gd project.godot tests/
git commit -m "Spielstand mit atomarem Schreiben, Migration und Offline-Auswertung"
```

---

## Task 13: Platzhalter-Sprites erzeugen

**Files:**
- Create: `tools/palette.gd`
- Create: `tools/gen_sprites.gd`
- Create: `assets/art/**.png` (erzeugt)
- Create: `tests/test_palette.gd`
- Modify: `tests/run_tests.gd`

**Abweichung von der Spec:** Die Spec nennt `tools/gen_sprites.py`. Ich baue den Generator stattdessen in GDScript, weil Godots `Image`-Klasse `save_png()` bereits mitbringt — das erspart eine Python-Bildbibliothek als Abhängigkeit, die auf diesem Gerät gar nicht installiert ist, und folgt der Regel „erst prüfen, ob Godot es selbst kann".

**Interfaces:**
- Consumes: nichts
- Produces: `Palette` mit `const COLORS: Dictionary` (Name → `Color`) und `static func get_color(name: StringName) -> Color`. Erzeugte Dateien: `assets/art/bg_lake.png` (320×180), `assets/art/dock.png`, `assets/art/char_<layer>_<index>.png` (je 3 Frames à 32×32 nebeneinander, also 96×32), `assets/art/fish_<id>.png` (32×16), `assets/art/fish_<id>_silhouette.png`, `assets/art/orb.png` (16×16), `assets/art/bobber.png` (8×8)

- [ ] **Step 1: Failing test schreiben**

`tests/test_palette.gd`:

```gdscript
extends TestCase

func test_known_colors_exist() -> void:
	assert_true(Palette.COLORS.has(&"water_mid"))
	assert_true(Palette.COLORS.has(&"outline"))

func test_unknown_color_is_magenta() -> void:
	assert_eq(Palette.get_color(&"gibt_es_nicht"), Color.MAGENTA)

func test_palette_has_no_duplicates() -> void:
	var seen := {}
	for name in Palette.COLORS:
		var hex: String = Palette.COLORS[name].to_html(false)
		assert_false(seen.has(hex), "Farbe %s doppelt vergeben (%s)" % [hex, name])
		seen[hex] = name
```

- [ ] **Step 2: Testlauf — muss fehlschlagen**

SUITES um `"res://tests/test_palette.gd"` erweitern.

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `Identifier "Palette" not declared`.

- [ ] **Step 3: Palette festlegen**

`tools/palette.gd` — eine feste Palette, damit generierte und später handgemalte Sprites zusammenpassen.

```gdscript
## Die verbindliche Farbpalette von Stillwater. Handgemalte Sprites müssen
## sich daran halten, sonst fällt der Stil auseinander.
class_name Palette
extends RefCounted

const COLORS := {
	&"sky_high":    Color("2f4858"),
	&"sky_low":     Color("6a8ba0"),
	&"water_deep":  Color("1f3b47"),
	&"water_mid":   Color("2e5f6b"),
	&"water_light": Color("478a8f"),
	&"foam":        Color("bcd9d2"),
	&"reed_dark":   Color("2f4a34"),
	&"reed":        Color("4d7a4a"),
	&"reed_light":  Color("7ba85f"),
	&"wood_dark":   Color("4a3626"),
	&"wood":        Color("7a5a3c"),
	&"wood_light":  Color("a5825a"),
	&"skin_1":      Color("e8bE9a"),
	&"skin_2":      Color("c68c63"),
	&"skin_3":      Color("8d5a3c"),
	&"cloth_red":   Color("b4523f"),
	&"cloth_blue":  Color("3f6fb4"),
	&"cloth_green": Color("4a9455"),
	&"cloth_grey":  Color("6f7a75"),
	&"hair_dark":   Color("2c2320"),
	&"hair_warm":   Color("8a5a2c"),
	&"hair_pale":   Color("d8c48a"),
	&"accent":      Color("f0c05a"),
	&"outline":     Color("1a2320"),
	&"shadow":      Color("141c1a"),
}

static func get_color(name: StringName) -> Color:
	return COLORS.get(name, Color.MAGENTA)
```

Magenta als Fehlfarbe ist Absicht: ein falscher Farbname fällt sofort auf.

- [ ] **Step 4: Testlauf — muss grün sein**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `93 Tests, 0 fehlgeschlagen`.

- [ ] **Step 5: Generator schreiben**

`tools/gen_sprites.gd`:

```gdscript
extends SceneTree

const OUT := "res://assets/art"

func _c(name: StringName) -> Color:
	return Palette.get_color(name)

func _new_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, mini(y + h, img.get_height())):
		for ix in range(x, mini(x + w, img.get_width())):
			if ix >= 0 and iy >= 0:
				img.set_pixel(ix, iy, c)

func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for iy in img.get_height():
		for ix in img.get_width():
			var dx := (float(ix) + 0.5 - cx) / rx
			var dy := (float(iy) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(ix, iy, c)

func _save(img: Image, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var path := "%s/%s.png" % [OUT, name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("  ", path)

# --- Hintergrund ----------------------------------------------------------

func _background() -> void:
	var img := _new_image(320, 180)
	for y in 78:
		var t := float(y) / 78.0
		_rect(img, 0, y, 320, 1, _c(&"sky_high").lerp(_c(&"sky_low"), t))
	_rect(img, 0, 78, 320, 6, _c(&"reed_dark"))
	for y in range(84, 180):
		var t := float(y - 84) / 96.0
		_rect(img, 0, y, 320, 1, _c(&"water_light").lerp(_c(&"water_deep"), t))
	# ruhige Wasserlinien
	for i in 26:
		var y := 92 + (i * 3) % 84
		var x := (i * 37) % 300
		_rect(img, x, y, 10 + (i % 4) * 4, 1, _c(&"foam"))
	# Schilf am Ufer
	for i in 40:
		var x := (i * 8 + (i % 3) * 3) % 318
		var h := 6 + (i % 5) * 3
		_rect(img, x, 78 - h, 1, h, _c(&"reed") if i % 2 == 0 else _c(&"reed_light"))
	_save(img, "bg_lake")

func _dock() -> void:
	var img := _new_image(64, 24)
	_rect(img, 0, 0, 64, 6, _c(&"wood_light"))
	_rect(img, 0, 6, 64, 3, _c(&"wood"))
	for i in 4:
		_rect(img, 6 + i * 16, 9, 4, 15, _c(&"wood_dark"))
	_save(img, "dock")

# --- Charakterebenen ------------------------------------------------------
# Drei Frames nebeneinander: 0 ruhig, 1 Ausholen, 2 Wurf.

const FRAME := 32
const FRAMES := 3

func _char_sheet() -> Image:
	return _new_image(FRAME * FRAMES, FRAME)

func _arm_offset(frame: int) -> int:
	return [0, -3, 4][frame]

func _skin(index: int) -> void:
	var tone := [&"skin_1", &"skin_2", &"skin_3"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_rect(img, ox + 12, 6, 8, 8, _c(tone))          # Kopf
		_rect(img, ox + 13, 14, 6, 10, _c(tone))        # Rumpf
		_rect(img, ox + 19, 15 + _arm_offset(f), 3, 7, _c(tone))  # Wurfarm
		_rect(img, ox + 10, 16, 3, 6, _c(tone))         # Ruhearm
	_save(img, "char_skin_%d" % index)

func _hair(index: int) -> void:
	var tone := [&"hair_dark", &"hair_warm", &"hair_pale"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_rect(img, ox + 11, 4, 10, 4, _c(tone))
		_rect(img, ox + 11, 8, 2, 4, _c(tone))
		if index == 2:
			_rect(img, ox + 19, 8, 2, 6, _c(tone))
	_save(img, "char_hair_%d" % index)

func _shirt(index: int) -> void:
	var tone := [&"cloth_red", &"cloth_blue", &"cloth_green"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_rect(img, ox + 12, 14, 8, 7, _c(tone))
		_rect(img, ox + 19, 15 + _arm_offset(f), 3, 4, _c(tone))
		_rect(img, ox + 10, 16, 3, 4, _c(tone))
	_save(img, "char_shirt_%d" % index)

func _pants(index: int) -> void:
	var tone := [&"cloth_grey", &"wood_dark"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_rect(img, ox + 13, 21, 6, 6, _c(tone))
		_rect(img, ox + 13, 27, 2, 3, _c(&"outline"))
		_rect(img, ox + 17, 27, 2, 3, _c(&"outline"))
	_save(img, "char_pants_%d" % index)

func _hat(index: int) -> void:
	var img := _char_sheet()
	if index > 0:
		var tone := [&"cloth_grey", &"reed", &"accent"][index]
		for f in FRAMES:
			var ox := f * FRAME
			_rect(img, ox + 9, 3, 14, 2, _c(tone))
			_rect(img, ox + 12, 0, 8, 3, _c(tone))
	_save(img, "char_hat_%d" % index)

func _rod() -> void:
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		var lift := _arm_offset(f)
		for i in 14:
			_rect(img, ox + 21 + i, 16 + lift - i, 1, 1, _c(&"wood_light"))
	_save(img, "char_rod_0")

# --- Fische ---------------------------------------------------------------

func _fish_sprite(id: StringName, body: Color, fin: Color) -> void:
	var img := _new_image(32, 16)
	_ellipse(img, 14.0, 8.0, 10.0, 5.0, body)
	# Schwanz
	for i in 6:
		_rect(img, 24 + i, 8 - i / 2 - 1, 1, 2 + i, fin)
	# Rückenflosse
	_rect(img, 11, 2, 7, 2, fin)
	# Auge
	img.set_pixel(7, 7, _c(&"outline"))
	_save(img, "fish_%s" % id)

	var sil := _new_image(32, 16)
	for y in 16:
		for x in 32:
			if img.get_pixel(x, y).a > 0.0:
				sil.set_pixel(x, y, _c(&"shadow"))
	_save(sil, "fish_%s_silhouette" % id)

func _fishes() -> void:
	# Farbe deterministisch aus der ID: jede Art sieht stabil eigen aus.
	for id in Database.fish:
		var f: FishData = Database.fish[id]
		var h := int(String(f.id).hash())
		var hue := float(absi(h) % 1000) / 1000.0
		var body := Color.from_hsv(hue, 0.35, 0.72)
		var fin := body.darkened(0.28)
		if f.is_secret:
			body = _c(&"accent")
			fin = _c(&"wood_dark")
		_fish_sprite(f.id, body, fin)

# --- Kleinkram ------------------------------------------------------------

func _orb() -> void:
	var img := _new_image(16, 16)
	_ellipse(img, 8.0, 8.0, 7.0, 7.0, _c(&"accent"))
	_ellipse(img, 8.0, 8.0, 4.5, 4.5, _c(&"foam"))
	_save(img, "orb")

func _bobber() -> void:
	var img := _new_image(8, 8)
	_ellipse(img, 4.0, 4.0, 3.5, 3.5, _c(&"cloth_red"))
	_rect(img, 0, 4, 8, 4, _c(&"foam"))
	_save(img, "bobber")

func _init() -> void:
	# Wartet auf die Autoloads — _fishes() braucht Database. Siehe die
	# gleichlautende Anmerkung in tests/run_tests.gd.
	await process_frame
	print("Hintergrund")
	_background()
	_dock()
	print("Charakter")
	for i in 3:
		_skin(i)
		_hair(i)
		_shirt(i)
	for i in 2:
		_pants(i)
	for i in 3:
		_hat(i)
	_rod()
	print("Fische")
	_fishes()
	print("Kleinkram")
	_orb()
	_bobber()
	print("fertig")
	quit(0)
```

- [ ] **Step 6: Generator ausführen**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tools/gen_sprites.gd`
Expected: eine Zeile pro Datei, Schlusszeile `fertig`. Danach liegen unter `assets/art/` der Hintergrund, der Steg, 15 Charakterbögen, 22 Fischdateien, Orb und Bobber.

- [ ] **Step 7: Sichtprüfung**

```bash
ls -la ~/stillwater/assets/art/ | head -30
```

Erwartet: alle PNG größer als 0 Bytes, `bg_lake.png` deutlich größer als die Sprites.

- [ ] **Step 8: Commit**

```bash
cd ~/stillwater
git add tools/palette.gd tools/gen_sprites.gd assets/art/ tests/test_palette.gd tests/run_tests.gd
git commit -m "Feste Farbpalette und Generator für Platzhalter-Sprites"
```

---

## Task 14: Weltszene, Charakter und Angelanimation

**Files:**
- Create: `scenes/main.tscn`
- Create: `scenes/fishing/world.tscn`
- Create: `scenes/fishing/world.gd`
- Create: `scenes/fishing/angler.tscn`
- Create: `scenes/fishing/angler.gd`
- Create: `assets/art/palette_swap.gdshader`

**Interfaces:**
- Consumes: `Game` (Signale `bite`, `caught`, `escaped`, `state_changed`), `Palette`
- Produces: `Angler` mit `set_cosmetics(c: Dictionary) -> void` und `play_state(state: int) -> void`; `World` mit `orb_area: Control` (die Fläche, über der die Orbs erscheinen dürfen)

- [ ] **Step 1: Palettenaustausch-Shader schreiben**

`assets/art/palette_swap.gdshader` — färbt eine Ebene ein, ohne pro Farbe ein eigenes Sprite zu brauchen.

```glsl
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// Helligkeit behalten, Farbton ersetzen — so bleiben die Schattierungen
	// des Sprites erhalten.
	float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 swapped = tint.rgb * (0.55 + 0.9 * luma);
	COLOR = vec4(mix(base.rgb, swapped, strength), base.a);
}
```

- [ ] **Step 2: Charakterszene anlegen**

`scenes/fishing/angler.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/fishing/angler.gd" id="1"]

[node name="Angler" type="Node2D"]
script = ExtResource("1")

[node name="Skin" type="Sprite2D" parent="."]
hframes = 3
centered = false

[node name="Pants" type="Sprite2D" parent="."]
hframes = 3
centered = false

[node name="Shirt" type="Sprite2D" parent="."]
hframes = 3
centered = false

[node name="Hair" type="Sprite2D" parent="."]
hframes = 3
centered = false

[node name="Hat" type="Sprite2D" parent="."]
hframes = 3
centered = false

[node name="Rod" type="Sprite2D" parent="."]
hframes = 3
centered = false
```

Die Reihenfolge der Knoten ist die Zeichenreihenfolge: Haut unten, Angel oben.

- [ ] **Step 3: Charakterskript schreiben**

`scenes/fishing/angler.gd`:

```gdscript
## Der Angler. Besteht aus getrennten Ebenen, damit Cosmetics später nur
## Texturen und Farben tauschen statt den Charakter neu zu zeichnen.
extends Node2D

const LAYERS := ["Skin", "Pants", "Shirt", "Hair", "Hat", "Rod"]
const TEX_PREFIX := {
	"Skin": "char_skin",
	"Pants": "char_pants",
	"Shirt": "char_shirt",
	"Hair": "char_hair",
	"Hat": "char_hat",
	"Rod": "char_rod",
}
const HAIR_TINTS := [&"hair_dark", &"hair_warm", &"hair_pale"]

var _frame: int = 0

func _ready() -> void:
	set_cosmetics(Game.cosmetics)
	Game.bite.connect(_on_bite)
	Game.caught.connect(_on_caught)
	Game.escaped.connect(_on_escaped)

func set_cosmetics(c: Dictionary) -> void:
	_set_layer("Skin", int(c.get("skin", 0)))
	_set_layer("Pants", int(c.get("pants", 0)))
	_set_layer("Shirt", int(c.get("shirt", 0)))
	_set_layer("Hair", int(c.get("hair", 0)))
	_set_layer("Hat", int(c.get("hat", 0)))
	_set_layer("Rod", 0)
	_tint_hair(int(c.get("hair_color", 0)))

func _set_layer(name: String, index: int) -> void:
	var sprite: Sprite2D = get_node(name)
	var path := "res://assets/art/%s_%d.png" % [TEX_PREFIX[name], index]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.frame = _frame

func _tint_hair(color_index: int) -> void:
	var sprite: Sprite2D = $Hair
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/art/palette_swap.gdshader")
	mat.set_shader_parameter("tint", Palette.get_color(HAIR_TINTS[clampi(color_index, 0, HAIR_TINTS.size() - 1)]))
	mat.set_shader_parameter("strength", 1.0)
	sprite.material = mat

## 0 ruhig, 1 Ausholen, 2 Wurf
func play_state(frame: int) -> void:
	_frame = clampi(frame, 0, 2)
	for name in LAYERS:
		(get_node(name) as Sprite2D).frame = _frame

func _process(_delta: float) -> void:
	match Game.sim.state:
		FishingSim.State.CASTING:
			play_state(2)
		FishingSim.State.FIGHT:
			play_state(1)
		_:
			play_state(0)

func _on_bite(_fish: FishData) -> void:
	play_state(1)

func _on_caught(_c: CaughtFish, _f: FishData) -> void:
	play_state(0)

func _on_escaped(_f: FishData) -> void:
	play_state(0)
```

- [ ] **Step 4: Weltszene anlegen**

`scenes/fishing/world.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scenes/fishing/world.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/bg_lake.png" id="2"]
[ext_resource type="PackedScene" path="res://scenes/fishing/angler.tscn" id="3"]

[node name="World" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Background" type="TextureRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
texture = ExtResource("2")
expand_mode = 1
stretch_mode = 6

[node name="Angler" parent="." instance=ExtResource("3")]
position = Vector2(120, 300)
scale = Vector2(4, 4)

[node name="Bobber" type="Sprite2D" parent="."]
position = Vector2(430, 470)
scale = Vector2(4, 4)

[node name="OrbArea" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
```

- [ ] **Step 5: Weltskript schreiben**

`scenes/fishing/world.gd`:

```gdscript
## Die Spielwelt links im Querformat. Zeigt Hintergrund, Angler und Bobber
## und stellt die Fläche bereit, über der die Orbs erscheinen dürfen.
extends Control

@onready var orb_area: Control = $OrbArea
@onready var _bobber: Sprite2D = $Bobber

var _bob_time: float = 0.0
var _bobber_home: Vector2

func _ready() -> void:
	_bobber.texture = load("res://assets/art/bobber.png")
	_bobber_home = _bobber.position
	Game.bite.connect(_on_bite)

func _process(delta: float) -> void:
	_bob_time += delta
	var visible_states := [FishingSim.State.WAITING, FishingSim.State.FIGHT]
	_bobber.visible = Game.sim.state in visible_states
	var amplitude := 10.0 if Game.sim.state == FishingSim.State.FIGHT else 3.0
	_bobber.position.y = _bobber_home.y + sin(_bob_time * 3.0) * amplitude

func _on_bite(_fish: FishData) -> void:
	_bob_time = 0.0
```

- [ ] **Step 6: Hauptszene anlegen**

`scenes/main.tscn` — vorerst nur die Welt; die UI kommt in Task 16 daneben.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://scenes/fishing/world.tscn" id="1"]

[node name="Main" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="World" parent="." instance=ExtResource("1")]
```

- [ ] **Step 7: Szene startet ohne Fehler**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --quit-after 120 res://scenes/main.tscn 2>&1 | tail -20`
Expected: keine `SCRIPT ERROR`- und keine `ERROR`-Zeilen. Headless zeigt nichts an, prüft aber Szenenaufbau, Skriptbindung und Ressourcenpfade.

- [ ] **Step 8: Commit**

```bash
cd ~/stillwater
git add scenes/ assets/art/palette_swap.gdshader
git commit -m "Weltszene mit Ebenen-Charakter, Angelanimation und Bobber"
```

---

## Task 15: Fangansicht mit Orbs

**Files:**
- Create: `scenes/fishing/catch_view.tscn`
- Create: `scenes/fishing/catch_view.gd`
- Create: `scenes/fishing/orb.tscn`
- Create: `scenes/fishing/orb.gd`
- Modify: `scenes/fishing/world.tscn` (Fangansicht einhängen)

**Interfaces:**
- Consumes: `Game` (`bite`, `caught`, `escaped`), `World.orb_area`
- Produces: `CatchView` mit `spawn_area: Control`; `Orb` mit Signal `tapped` und `setup(position: Vector2, lifetime: float) -> void`

- [ ] **Step 1: Orb anlegen**

`scenes/fishing/orb.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/fishing/orb.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/art/orb.png" id="2"]

[node name="Orb" type="Control"]
custom_minimum_size = Vector2(112, 112)
size = Vector2(112, 112)
script = ExtResource("1")

[node name="Visual" type="TextureRect" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 88.0
offset_bottom = 88.0
texture = ExtResource("2")
expand_mode = 1
stretch_mode = 6
mouse_filter = 2

[node name="Button" type="Button" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
flat = true
```

Die Trefferfläche ist 112 × 112 und damit deutlich größer als der sichtbare Orb von 64 × 64 — auf dem Handy tippt man ungenau. 112 px in der Basisauflösung 1280 × 720 entsprechen gut 48 dp.

- [ ] **Step 2: Orb-Skript schreiben**

`scenes/fishing/orb.gd`:

```gdscript
## Ein antippbarer Orb. Verschwindet nach seiner Lebenszeit von allein.
extends Control

signal tapped

const FADE_TIME: float = 0.15

var _life: float = 2.0
var _age: float = 0.0
var _dead: bool = false

func _ready() -> void:
	$Button.pressed.connect(_on_pressed)
	pivot_offset = size * 0.5
	scale = Vector2.ZERO

func setup(pos: Vector2, lifetime: float) -> void:
	position = pos - size * 0.5
	_life = lifetime

func _process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	# Kurzes Aufploppen, dann ruhiges Pulsieren.
	if _age < FADE_TIME:
		scale = Vector2.ONE * (_age / FADE_TIME)
	else:
		scale = Vector2.ONE * (1.0 + sin(_age * 6.0) * 0.06)
	modulate.a = clampf((_life - _age) / 0.4, 0.0, 1.0)
	if _age >= _life:
		_expire()

func _on_pressed() -> void:
	if _dead:
		return
	_dead = true
	tapped.emit()
	queue_free()

func _expire() -> void:
	_dead = true
	queue_free()
```

- [ ] **Step 3: Fangansicht anlegen**

`scenes/fishing/catch_view.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/fishing/catch_view.gd" id="1"]

[node name="CatchView" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("1")

[node name="Panel" type="PanelContainer" parent="."]
anchor_left = 0.5
anchor_right = 0.5
offset_left = -180.0
offset_top = 16.0
offset_right = 180.0
offset_bottom = 96.0

[node name="Box" type="VBoxContainer" parent="Panel"]

[node name="FishName" type="Label" parent="Panel/Box"]
horizontal_alignment = 1

[node name="Strength" type="ProgressBar" parent="Panel/Box"]
custom_minimum_size = Vector2(0, 22)
show_percentage = false

[node name="Line" type="ProgressBar" parent="Panel/Box"]
custom_minimum_size = Vector2(0, 10)
show_percentage = false

[node name="Orbs" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
```

- [ ] **Step 4: Fangansicht-Skript schreiben**

`scenes/fishing/catch_view.gd`:

```gdscript
## Die Fanganzeige während eines Kampfes: Fischstärke, Leinenspannung und
## die antippbaren Orbs.
extends Control

const ORB_SCENE := preload("res://scenes/fishing/orb.tscn")
const ORB_INTERVAL: float = 0.9
const ORB_LIFETIME: float = 2.2
const ORB_MARGIN: float = 80.0

@onready var _panel: PanelContainer = $Panel
@onready var _name: Label = $Panel/Box/FishName
@onready var _strength: ProgressBar = $Panel/Box/Strength
@onready var _line: ProgressBar = $Panel/Box/Line
@onready var _orbs: Control = $Orbs

var _spawn_timer: float = 0.0

func _ready() -> void:
	_panel.visible = false
	Game.bite.connect(_on_bite)
	Game.caught.connect(_on_ended.unbind(2))
	Game.escaped.connect(_on_ended.unbind(1))

func _process(delta: float) -> void:
	var fighting := Game.sim.state == FishingSim.State.FIGHT
	_panel.visible = fighting
	if not fighting:
		_clear_orbs()
		return
	_strength.max_value = Game.sim.hooked_max_strength
	_strength.value = maxf(Game.sim.hooked_strength, 0.0)
	_line.max_value = Game.ctx.zone.fight_window
	_line.value = maxf(Game.sim.timer, 0.0)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = ORB_INTERVAL
		_spawn_orb()

func _on_bite(fish: FishData) -> void:
	_name.text = fish.display_name
	_spawn_timer = 0.25

func _on_ended() -> void:
	_clear_orbs()

func _clear_orbs() -> void:
	for child in _orbs.get_children():
		child.queue_free()

func _spawn_orb() -> void:
	var orb := ORB_SCENE.instantiate()
	_orbs.add_child(orb)
	var area := _orbs.size
	var pos := Vector2(
		randf_range(ORB_MARGIN, maxf(area.x - ORB_MARGIN, ORB_MARGIN + 1.0)),
		randf_range(ORB_MARGIN, maxf(area.y - ORB_MARGIN, ORB_MARGIN + 1.0))
	)
	orb.setup(pos, ORB_LIFETIME)
	orb.tapped.connect(Game.tap)
```

Die Orbs benutzen bewusst `randf_range` statt `Game.rng`: ihre Position ist reine Darstellung und darf den Spielzufall nicht verbrauchen — sonst würden Online- und Offline-Lauf auseinanderlaufen.

- [ ] **Step 5: Fangansicht in die Welt hängen**

In `scenes/fishing/world.tscn` unterhalb von `OrbArea` ergänzen:

```
[node name="CatchView" parent="." instance=ExtResource("4")]
```

und oben die Ressource eintragen:

```
[ext_resource type="PackedScene" path="res://scenes/fishing/catch_view.tscn" id="4"]
```

`load_steps` in der ersten Zeile auf `5` erhöhen.

- [ ] **Step 6: Szene startet ohne Fehler**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --quit-after 300 res://scenes/main.tscn 2>&1 | tail -20`
Expected: keine `SCRIPT ERROR`-Zeilen.

- [ ] **Step 7: Commit**

```bash
cd ~/stillwater
git add scenes/fishing/
git commit -m "Fangansicht mit Stärke- und Spannungsbalken sowie antippbaren Orbs"
```

---

## Task 16: UI-Rahmen — HUD, Tab-Leiste, Panel-Wechsel

**Files:**
- Create: `scenes/ui/hud.tscn`
- Create: `scenes/ui/hud.gd`
- Create: `scenes/ui/tab_rail.tscn`
- Create: `scenes/ui/tab_rail.gd`
- Create: `scenes/ui/panel_base.gd`
- Modify: `scenes/main.tscn`
- Create: `scenes/main.gd`

**Interfaces:**
- Consumes: `Game`, `Progression`
- Produces: `TabRail` mit Signal `tab_selected(index: int)` und `const TABS: Array[String]`; `PanelBase` mit `func refresh() -> void` als Überschreibungspunkt und automatischer Anmeldung an `Game.state_changed`; `Main` mit `show_tab(index: int) -> void`

- [ ] **Step 1: Panel-Basis schreiben**

`scenes/ui/panel_base.gd`:

```gdscript
## Basis aller Seitenpanels. Zeichnet sich neu, wenn sich der Spielzustand
## ändert — aber nur, solange das Panel sichtbar ist. Ein verstecktes Panel
## soll auf einem schwachen Gerät keine Arbeit machen.
class_name PanelBase
extends VBoxContainer

func _ready() -> void:
	Game.state_changed.connect(_on_state_changed)
	visibility_changed.connect(_on_visibility_changed)
	if visible:
		refresh()

func _on_state_changed() -> void:
	if visible:
		refresh()

func _on_visibility_changed() -> void:
	if visible:
		refresh()

## Von jedem Panel überschrieben.
func refresh() -> void:
	pass

## Hilfsmittel: Alle Kinder eines Containers entfernen.
func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
```

- [ ] **Step 2: HUD anlegen**

`scenes/ui/hud.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/hud.gd" id="1"]

[node name="Hud" type="PanelContainer"]
offset_right = 420.0
offset_bottom = 64.0
script = ExtResource("1")

[node name="Box" type="HBoxContainer" parent="."]
theme_override_constants/separation = 18

[node name="Coins" type="Label" parent="Box"]
[node name="Level" type="Label" parent="Box"]

[node name="Xp" type="ProgressBar" parent="Box"]
custom_minimum_size = Vector2(160, 18)
show_percentage = false

[node name="Zone" type="Label" parent="Box"]
```

- [ ] **Step 3: HUD-Skript schreiben**

`scenes/ui/hud.gd`:

```gdscript
## Kopfzeile oben links: Geld, Level, XP-Fortschritt, aktuelle Zone.
extends PanelContainer

@onready var _coins: Label = $Box/Coins
@onready var _level: Label = $Box/Level
@onready var _xp: ProgressBar = $Box/Xp
@onready var _zone: Label = $Box/Zone

func _ready() -> void:
	Game.state_changed.connect(refresh)
	Game.coins_changed.connect(func(_v: int) -> void: refresh())
	refresh()

func refresh() -> void:
	_coins.text = "%s Münzen" % _grouped(Game.coins)
	_level.text = "Lvl %d" % Game.ctx.player_level
	_xp.max_value = Progression.xp_needed(Game.ctx.player_level)
	_xp.value = Game.ctx.player_xp
	_zone.text = Game.ctx.zone.display_name

func _grouped(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if value < 0 else "") + out
```

- [ ] **Step 4: Tab-Leiste anlegen**

`scenes/ui/tab_rail.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/tab_rail.gd" id="1"]

[node name="TabRail" type="PanelContainer"]
custom_minimum_size = Vector2(96, 0)
script = ExtResource("1")

[node name="Box" type="VBoxContainer" parent="."]
theme_override_constants/separation = 6
```

- [ ] **Step 5: Tab-Leisten-Skript schreiben**

`scenes/ui/tab_rail.gd`:

```gdscript
## Die senkrechte Leiste ganz rechts. Im Querformat liegt dort der rechte
## Daumen. Jeder Knopf ist mindestens 96 px hoch, also gut 48 dp.
extends PanelContainer

signal tab_selected(index: int)

const TABS: Array[String] = ["Fische", "Journal", "Laden", "Ausbau", "Welt", "Figur"]
const BUTTON_HEIGHT: float = 96.0

var _buttons: Array[Button] = []
var _active: int = -1

func _ready() -> void:
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		b.toggle_mode = true
		b.pressed.connect(_on_pressed.bind(i))
		$Box.add_child(b)
		_buttons.append(b)

func select(index: int) -> void:
	_active = -1 if _active == index else index
	for i in _buttons.size():
		_buttons[i].button_pressed = (i == _active)
	tab_selected.emit(_active)

func _on_pressed(index: int) -> void:
	select(index)
```

Ein zweiter Druck auf denselben Tab schließt das Panel wieder — dann sieht man die ganze Welt.

- [ ] **Step 6: Hauptszene umbauen**

`scenes/main.tscn` ersetzen:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scenes/main.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/fishing/world.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/hud.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/tab_rail.tscn" id="4"]

[node name="Main" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Row" type="HBoxContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_constants/separation = 0

[node name="World" parent="Row" instance=ExtResource("2")]
size_flags_horizontal = 3
size_flags_stretch_ratio = 1.5

[node name="SidePanel" type="PanelContainer" parent="Row"]
custom_minimum_size = Vector2(420, 0)
visible = false

[node name="Panels" type="Control" parent="Row/SidePanel"]

[node name="TabRail" parent="Row" instance=ExtResource("4")]

[node name="Hud" parent="." instance=ExtResource("3")]
offset_left = 16.0
offset_top = 16.0
```

Das Verhältnis 1.5 zu 1 zwischen Welt und Panel ergibt die geplanten rund 60 zu 40 Prozent. Das HUD liegt als Geschwister über der Zeile, damit es die Aufteilung nicht verschiebt.

- [ ] **Step 7: Hauptskript schreiben**

`scenes/main.gd`:

```gdscript
## Hält das Querformat-Layout zusammen: links die Welt, rechts das Panel,
## ganz rechts die Tab-Leiste. Das Panel überdeckt die Welt nie — ein Fisch
## kann mitten im Laden gedrillt werden.
extends Control

@onready var _side: PanelContainer = $Row/SidePanel
@onready var _panels: Control = $Row/SidePanel/Panels
@onready var _rail = $Row/TabRail

func _ready() -> void:
	_rail.tab_selected.connect(show_tab)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	show_tab(-1)

## Blendet genau ein Panel ein. -1 schließt alle.
func show_tab(index: int) -> void:
	_side.visible = index >= 0
	for i in _panels.get_child_count():
		(_panels.get_child(i) as Control).visible = (i == index)

## Hält HUD und Tab-Leiste aus Notch und Gestenleiste heraus.
func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.window_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return
	var scale_x := float(size.x) / float(screen.x)
	var scale_y := float(size.y) / float(screen.y)
	var left := float(safe.position.x) * scale_x
	var top := float(safe.position.y) * scale_y
	var right := float(screen.x - safe.end.x) * scale_x
	var bottom := float(screen.y - safe.end.y) * scale_y
	$Row.offset_left = left
	$Row.offset_top = top
	$Row.offset_right = -right
	$Row.offset_bottom = -bottom
	$Hud.offset_left = left + 16.0
	$Hud.offset_top = top + 16.0
```

- [ ] **Step 8: Szene startet ohne Fehler**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --quit-after 180 res://scenes/main.tscn 2>&1 | tail -20`
Expected: keine `SCRIPT ERROR`-Zeilen.

- [ ] **Step 9: Commit**

```bash
cd ~/stillwater
git add scenes/ui/ scenes/main.tscn scenes/main.gd
git commit -m "Querformat-Rahmen mit HUD, Tab-Leiste und Panel-Wechsel"
```

---

## Task 17: Die sechs Panels und das Rückkehr-Fenster

**Files:**
- Create: `scenes/ui/panels/fish_panel.gd`
- Create: `scenes/ui/panels/journal_panel.gd`
- Create: `scenes/ui/panels/shop_panel.gd`
- Create: `scenes/ui/panels/upgrade_panel.gd`
- Create: `scenes/ui/panels/world_panel.gd`
- Create: `scenes/ui/panels/character_panel.gd`
- Create: `scenes/ui/welcome_back.tscn`
- Create: `scenes/ui/welcome_back.gd`
- Modify: `scenes/main.tscn`

**Interfaces:**
- Consumes: `PanelBase`, `Game`, `Database`, `Economy`, `FishRoll`, `SaveManager` (Signal `offline_ready`)
- Produces: sechs Panels, die alle `PanelBase` erweitern und `refresh()` überschreiben; `WelcomeBack` mit `show_summary(summary: Dictionary) -> void`

- [ ] **Step 1: Panels in die Hauptszene eintragen**

In `scenes/main.tscn` unter `Row/SidePanel/Panels` sechs `ScrollContainer` mit je einem `VBoxContainer` anlegen. Die Reihenfolge muss der `TabRail.TABS`-Reihenfolge entsprechen — Fische, Journal, Laden, Ausbau, Welt, Figur:

```
[node name="FishScroll" type="ScrollContainer" parent="Row/SidePanel/Panels"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="FishPanel" type="VBoxContainer" parent="Row/SidePanel/Panels/FishScroll"]
size_flags_horizontal = 3
script = ExtResource("5")
```

Analog `JournalScroll`/`JournalPanel` (id 6), `ShopScroll`/`ShopPanel` (7), `UpgradeScroll`/`UpgradePanel` (8), `WorldScroll`/`WorldPanel` (9), `CharacterScroll`/`CharacterPanel` (10). `load_steps` entsprechend erhöhen und je eine `[ext_resource type="Script" ...]`-Zeile ergänzen.

**Wichtig:** `Main.show_tab` blendet die Kinder von `Panels` per Index ein. Die Kinder sind die `ScrollContainer`, nicht die Panels — die Reihenfolge der `ScrollContainer` ist also das, was zählt.

- [ ] **Step 2: Fisch-Panel schreiben**

`scenes/ui/panels/fish_panel.gd`:

```gdscript
## Das Inventar. Zeigt jeden Fang mit Preis, Qualität und Gewicht, erlaubt
## Einzelverkauf, Favorisieren und Alles-Verkaufen.
extends PanelBase

func refresh() -> void:
	clear(self)

	var header := Label.new()
	header.text = "Fischkiste  %d / %d" % [Game.ctx.inventory.fish.size(), Game.ctx.inventory.capacity]
	add_child(header)

	if Game.ctx.inventory.is_full():
		var warn := Label.new()
		warn.text = "Voll — das Angeln pausiert."
		warn.modulate = Palette.get_color(&"cloth_red")
		add_child(warn)

	var sell_all := Button.new()
	sell_all.text = "Alles verkaufen"
	sell_all.custom_minimum_size = Vector2(0, 96)
	sell_all.pressed.connect(func() -> void: Game.sell_all())
	add_child(sell_all)

	for i in Game.ctx.inventory.fish.size():
		add_child(_row(i))

func _row(index: int) -> Control:
	var c: CaughtFish = Game.ctx.inventory.fish[index]
	var fish: FishData = Database.fish.get(c.fish_id)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 96)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := fish.display_name if fish != null else String(c.fish_id)
	if c.is_shiny:
		name = "✦ " + name
	label.text = "%s\n%s · %.2f kg" % [name, FishRoll.QUALITY_NAMES[c.quality], c.weight]
	if fish != null:
		label.modulate = Game.ctx.rarity_of(fish).color
	row.add_child(label)

	var fav := Button.new()
	fav.text = "★" if c.is_favorite else "☆"
	fav.custom_minimum_size = Vector2(96, 96)
	fav.pressed.connect(func() -> void: Game.toggle_favorite(index))
	row.add_child(fav)

	var sell := Button.new()
	sell.custom_minimum_size = Vector2(120, 96)
	sell.disabled = c.is_favorite
	sell.text = "%d" % (0 if fish == null else Economy.sell_price(c, fish, Game.ctx.rarity_of(fish), Game.ctx.consumable_bonus))
	sell.pressed.connect(func() -> void: Game.sell_one(index))
	row.add_child(sell)

	return row
```

- [ ] **Step 3: Journal-Panel schreiben**

`scenes/ui/panels/journal_panel.gd`:

```gdscript
## Das Fisch-Journal. Unentdeckte Arten erscheinen als Silhouette,
## Secret-Fische als verschlossener Platz mit Hinweis.
extends PanelBase

func refresh() -> void:
	clear(self)
	for zone_id in Database.zones:
		var zone: ZoneData = Database.zones[zone_id]
		var fish := Database.fish_of_zone(zone_id)

		var title := Label.new()
		title.text = "%s   %d %%" % [zone.display_name, int(round(Game.ctx.journal.completion(fish) * 100.0))]
		add_child(title)

		for f in fish:
			if f.is_secret and not Game.ctx.journal.is_discovered(f.id):
				if Game.ctx.journal.has_any_secret():
					add_child(_locked(f))
				continue
			add_child(_entry(f))

func _entry(f: FishData) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 84)

	var known := Game.ctx.journal.is_discovered(f.id)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var suffix := "" if known else "_silhouette"
	var path := "res://assets/art/fish_%s%s.png" % [f.id, suffix]
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	row.add_child(icon)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if known:
		var e := Game.ctx.journal.entry(f.id)
		var shiny := "  ✦" if bool(e["shiny_found"]) else ""
		label.text = "%s%s\n%dx · beste %s · %.2f–%.2f kg" % [
			f.display_name, shiny, int(e["caught_count"]),
			FishRoll.QUALITY_NAMES[int(e["best_quality"])],
			float(e["worst_weight"]), float(e["best_weight"])
		]
		label.modulate = Game.ctx.rarity_of(f).color
	else:
		label.text = "???"
		label.modulate = Palette.get_color(&"shadow")
	row.add_child(label)
	return row

func _locked(f: FishData) -> Control:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 64)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "🔒 %s" % f.secret_hint
	label.modulate = Palette.get_color(&"accent")
	return label
```

- [ ] **Step 4: Laden-Panel schreiben**

`scenes/ui/panels/shop_panel.gd`:

```gdscript
## Der Köderladen. Der Grundköder ist gratis und unbegrenzt und steht
## deshalb nur zur Auswahl, nicht zum Kauf.
extends PanelBase

func refresh() -> void:
	clear(self)

	var header := Label.new()
	header.text = "Ködertasche  %d / %d" % [Game.bait_used(), Game.bait_capacity()]
	add_child(header)

	for id in Database.baits:
		var b: BaitData = Database.baits[id]
		if Game.ctx.player_level < b.unlock_level:
			continue
		add_child(_row(b))

func _row(b: BaitData) -> Control:
	var box := VBoxContainer.new()

	var title := Label.new()
	var owned := "unbegrenzt" if b.unlimited else "%d Stück" % int(Game.ctx.bait_counts.get(b.id, 0))
	var active := "  ← aktiv" if Game.ctx.bait.id == b.id else ""
	title.text = "%s  (%s)%s" % [b.display_name, owned, active]
	box.add_child(title)

	if not b.rarity_weight_bonus.is_empty():
		var effect := Label.new()
		var parts: Array[String] = []
		for rarity_id in b.rarity_weight_bonus:
			var r: RarityData = Database.rarities.get(rarity_id)
			var label := r.display_name if r != null else String(rarity_id)
			parts.append("%s ×%.1f" % [label, float(b.rarity_weight_bonus[rarity_id])])
		effect.text = "  " + ", ".join(parts)
		box.add_child(effect)

	var row := HBoxContainer.new()

	var use := Button.new()
	use.text = "Anlegen"
	use.custom_minimum_size = Vector2(0, 96)
	use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use.disabled = not b.unlimited and int(Game.ctx.bait_counts.get(b.id, 0)) <= 0
	use.pressed.connect(func() -> void: Game.set_active_bait(b.id))
	row.add_child(use)

	if not b.unlimited:
		for amount in [1, 10]:
			var buy := Button.new()
			buy.text = "%d ×  %d" % [amount, b.cost * amount]
			buy.custom_minimum_size = Vector2(0, 96)
			buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buy.disabled = Game.coins < b.cost * amount or Game.bait_used() + amount > Game.bait_capacity()
			buy.pressed.connect(func() -> void: Game.buy_bait(b.id, amount))
			row.add_child(buy)

	box.add_child(row)
	return box
```

- [ ] **Step 5: Ausbau-Panel schreiben**

`scenes/ui/panels/upgrade_panel.gd`:

```gdscript
## Die vier Upgrades. Werte und Kosten kommen ausschließlich aus den
## UpgradeData — hier steht keine einzige Zahl.
extends PanelBase

func refresh() -> void:
	clear(self)
	for id in Database.upgrades:
		add_child(_row(Database.upgrades[id]))

func _row(u: UpgradeData) -> Control:
	var level := int(Game.upgrade_levels.get(u.id, 0))
	var box := VBoxContainer.new()

	var title := Label.new()
	title.text = "%s  Stufe %d" % [u.display_name, level]
	box.add_child(title)

	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = "%s\nJetzt %.0f → danach %.0f" % [u.description, u.value_at(level), u.value_at(level + 1)]
	box.add_child(detail)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 96)
	if level >= u.max_level:
		buy.text = "Maximum erreicht"
		buy.disabled = true
	else:
		var cost := u.cost_at(level)
		buy.text = "Ausbauen  %d Münzen" % cost
		buy.disabled = Game.coins < cost
		buy.pressed.connect(func() -> void: Game.buy_upgrade(u.id))
	box.add_child(buy)

	return box
```

- [ ] **Step 6: Welt-Panel schreiben**

`scenes/ui/panels/world_panel.gd`:

```gdscript
## Zonenauswahl mit Freischaltbedingungen.
extends PanelBase

func refresh() -> void:
	clear(self)
	for id in Database.zones:
		add_child(_row(Database.zones[id]))

func _row(z: ZoneData) -> Control:
	var box := VBoxContainer.new()
	var unlocked := z.id in Game.unlocked_zones
	var here := Game.ctx.zone.id == z.id

	var title := Label.new()
	title.text = z.display_name + ("  ← hier" if here else "")
	box.add_child(title)

	var detail := Label.new()
	var fish := Database.fish_of_zone(z.id)
	detail.text = "%d Arten · Biss %.0f–%.0f s" % [fish.size(), z.bite_time_min, z.bite_time_max]
	box.add_child(detail)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 96)
	if here:
		button.text = "Du bist hier"
		button.disabled = true
	elif unlocked:
		button.text = "Hinreisen"
		button.pressed.connect(func() -> void: Game.travel_to(z.id))
	else:
		button.text = "Freischalten  Lvl %d · %d Münzen" % [z.unlock_level, z.unlock_cost]
		button.disabled = Game.ctx.player_level < z.unlock_level or Game.coins < z.unlock_cost
		button.pressed.connect(func() -> void: Game.unlock_zone(z.id))
	box.add_child(button)

	return box
```

- [ ] **Step 7: Figur-Panel schreiben**

`scenes/ui/panels/character_panel.gd`:

```gdscript
## Charakteranpassung. Rein kosmetisch: keine dieser Auswahlmöglichkeiten
## verändert einen einzigen Spielwert. Sie können später aber
## Fangbedingungen erfüllen.
extends PanelBase

const SLOTS := [
	{"key": "skin", "label": "Hautton", "count": 3},
	{"key": "hair", "label": "Frisur", "count": 3},
	{"key": "hair_color", "label": "Haarfarbe", "count": 3},
	{"key": "shirt", "label": "Oberteil", "count": 3},
	{"key": "pants", "label": "Hose", "count": 2},
	{"key": "hat", "label": "Hut", "count": 3},
]

func refresh() -> void:
	clear(self)

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Aussehen verändert keine Werte. Manche Fische achten trotzdem darauf."
	add_child(note)

	for slot in SLOTS:
		add_child(_row(slot))

func _row(slot: Dictionary) -> Control:
	var key: String = slot["key"]
	var current := int(Game.cosmetics.get(key, 0))
	var box := VBoxContainer.new()

	var title := Label.new()
	title.text = "%s  %d / %d" % [slot["label"], current + 1, int(slot["count"])]
	box.add_child(title)

	var row := HBoxContainer.new()
	for i in int(slot["count"]):
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = (i == current)
		b.pressed.connect(_choose.bind(key, i))
		row.add_child(b)
	box.add_child(row)

	return box

func _choose(key: String, index: int) -> void:
	Game.cosmetics[key] = index
	Game.ctx.cosmetics = Game.cosmetics
	for angler in get_tree().get_nodes_in_group("angler"):
		angler.set_cosmetics(Game.cosmetics)
	Game.state_changed.emit()
```

Dazu in `scenes/fishing/angler.gd` am Ende von `_ready()` ergänzen:

```gdscript
	add_to_group("angler")
```

- [ ] **Step 8: Rückkehr-Fenster anlegen**

`scenes/ui/welcome_back.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/welcome_back.gd" id="1"]

[node name="WelcomeBack" type="PanelContainer"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -240.0
offset_top = -140.0
offset_right = 240.0
offset_bottom = 140.0
visible = false
script = ExtResource("1")

[node name="Box" type="VBoxContainer" parent="."]
theme_override_constants/separation = 12

[node name="Title" type="Label" parent="Box"]
horizontal_alignment = 1

[node name="Body" type="Label" parent="Box"]
horizontal_alignment = 1

[node name="Close" type="Button" parent="Box"]
custom_minimum_size = Vector2(0, 96)
text = "Weiterangeln"
```

- [ ] **Step 9: Rückkehr-Skript schreiben**

`scenes/ui/welcome_back.gd`:

```gdscript
## Zeigt, was während der Abwesenheit passiert ist. Offline verdient
## niemand Geld — die Fische liegen im Inventar und wollen verkauft werden.
extends PanelContainer

func _ready() -> void:
	$Box/Close.pressed.connect(func() -> void: visible = false)
	SaveManager.offline_ready.connect(show_summary)
	if not SaveManager.pending_offline.is_empty():
		show_summary(SaveManager.pending_offline)

func show_summary(summary: Dictionary) -> void:
	var caught := int(summary.get("caught", 0))
	if caught <= 0:
		return
	$Box/Title.text = "Willkommen zurück"
	var lines: Array[String] = []
	lines.append("Du warst %s weg." % _duration(float(summary.get("elapsed", 0.0))))
	lines.append("Gefangen: %d Fische" % caught)
	lines.append("Erhalten: %d XP" % int(summary.get("xp", 0)))
	lines.append("Im Inventar liegen etwa %d Münzen." % int(summary.get("potential_coins", 0)))
	var discovered: Array = summary.get("discovered", [])
	if not discovered.is_empty():
		lines.append("Neu entdeckt: %d Arten" % discovered.size())
	if bool(summary.get("inventory_full", false)):
		lines.append("Die Fischkiste ist voll — das Angeln hat pausiert.")
	if bool(summary.get("was_capped", false)):
		lines.append("Angerechnet wurden höchstens 12 Stunden.")
	$Box/Body.text = "\n".join(lines)
	visible = true

func _duration(seconds: float) -> String:
	var total := int(seconds)
	var h := total / 3600
	var m := (total % 3600) / 60
	if h > 0:
		return "%d h %02d min" % [h, m]
	return "%d min" % m
```

In `scenes/main.tscn` als letztes Kind von `Main` einhängen, damit es über allem liegt:

```
[node name="WelcomeBack" parent="." instance=ExtResource("11")]
```

- [ ] **Step 10: Szene startet ohne Fehler**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --quit-after 300 res://scenes/main.tscn 2>&1 | tail -30`
Expected: keine `SCRIPT ERROR`-Zeilen.

- [ ] **Step 11: Volle Testsuite bleibt grün**

Run: `PROJECT=$HOME/stillwater bash ~/stillwater/tools/godot.sh --script res://tests/run_tests.gd`
Expected: `93 Tests, 0 fehlgeschlagen`.

- [ ] **Step 12: Commit**

```bash
cd ~/stillwater
git add scenes/
git commit -m "Sechs Seitenpanels und das Rückkehr-Fenster"
```

---

## Task 18: Android-Export und CI

**Files:**
- Create: `export_presets.cfg`
- Create: `.github/workflows/test.yml`
- Create: `.github/workflows/build.yml`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: das fertige Projekt
- Produces: zwei Workflows. `test.yml` läuft bei jedem Push und ist das Test-Gate. `build.yml` läuft auf Anforderung und legt `stillwater-debug.apk` als Artefakt ab.

- [ ] **Step 1: `.gitignore` korrigieren**

`export_presets.cfg` muss ins Repo, sonst kann die CI nicht exportieren. Passwörter stehen nicht darin — Godot 4 liest den Debug-Keystore aus Umgebungsvariablen. Die Zeile `export_presets.cfg` also entfernen und stattdessen ergänzen:

```
.godot/
.import/
build/
*.apk
*.aab
*.keystore
android/build/
```

- [ ] **Step 2: Export-Vorgabe anlegen**

`export_presets.cfg`:

```ini
[preset.0]

name="Android"
platform="Android"
runnable=true
advanced_options=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, docs/*"
export_path="build/stillwater-debug.apk"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

gradle_build/use_gradle_build=false
package/unique_name="org.phioster.stillwater"
package/name="Stillwater"
package/signed=true
package/app_category=2
package/retain_data_on_uninstall=false
launcher_icons/main_192x192=""
launcher_icons/adaptive_foreground_432x432=""
launcher_icons/adaptive_background_432x432=""
graphics/opengl_debug=false
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
user_data_backup/allow=false
command_line/extra_args=""
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1.0"
```

`exclude_filter` hält Tests, Werkzeuge und Doku aus der APK heraus. Nur `arm64-v8a` — jedes moderne Android-Gerät ist arm64, und die APK bleibt halb so groß.

- [ ] **Step 3: Test-Workflow schreiben**

`.github/workflows/test.yml`:

```yaml
name: Tests

on:
  push:
  pull_request:
  workflow_dispatch:

env:
  GODOT_VERSION: 4.7.2

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Godot holen
        run: |
          wget -q "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          unzip -q "Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          chmod +x "Godot_v${GODOT_VERSION}-stable_linux.x86_64"
          sudo mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot
          godot --headless --version

      - name: Ressourcen importieren
        run: godot --headless --import --quit-after 2000 || true

      - name: Inhalte prüfen und Tests laufen lassen
        run: godot --headless --script res://tests/run_tests.gd
```

Der Importlauf ist nötig, weil Godot die `.png` und `.tres` beim ersten Start erst einliest. `|| true` steht dort, weil der Importlauf je nach Godot-Version mit einem von Null verschiedenen Code endet, ohne dass etwas kaputt ist — der eigentliche Testlauf danach entscheidet.

- [ ] **Step 4: Build-Workflow schreiben**

`.github/workflows/build.yml`:

```yaml
name: APK bauen

on:
  workflow_dispatch:

env:
  GODOT_VERSION: 4.7.2

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: android-actions/setup-android@v3

      - name: Android-Werkzeuge einrichten
        run: |
          sdkmanager --install "platform-tools" "build-tools;34.0.0" "platforms;android-34" "cmdline-tools;latest"

      - name: Godot und Export-Vorlagen holen
        run: |
          wget -q "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          unzip -q "Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          chmod +x "Godot_v${GODOT_VERSION}-stable_linux.x86_64"
          sudo mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot

          wget -q "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
          mkdir -p ~/.local/share/godot/export_templates
          unzip -q "Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
          mv templates "~/.local/share/godot/export_templates/${GODOT_VERSION}.stable" || \
            mv templates "$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

      - name: Debug-Keystore erzeugen
        run: |
          keytool -keyalg RSA -genkeypair -alias androiddebugkey \
            -keypass android -keystore debug.keystore -storepass android \
            -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12

      - name: Exportieren
        env:
          GODOT_ANDROID_KEYSTORE_DEBUG_PATH: ${{ github.workspace }}/debug.keystore
          GODOT_ANDROID_KEYSTORE_DEBUG_USER: androiddebugkey
          GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD: android
        run: |
          godot --headless --import --quit-after 2000 || true
          mkdir -p build
          godot --headless --export-debug "Android" build/stillwater-debug.apk
          ls -la build/

      - uses: actions/upload-artifact@v4
        with:
          name: stillwater-debug-apk
          path: build/stillwater-debug.apk
          retention-days: 7
```

Der Debug-Keystore wird bei jedem Lauf frisch erzeugt und nie ins Repo gelegt — er enthält nichts Schützenswertes und darf nirgends eingecheckt werden. Ein echter Release-Keystore käme später über GitHub-Secrets, nicht ins Repo.

- [ ] **Step 5: Workflows lokal auf Syntax prüfen**

```bash
python3 -c "
import sys, yaml
for p in ['.github/workflows/test.yml', '.github/workflows/build.yml']:
    yaml.safe_load(open(p))
    print('ok', p)
"
```

Expected: zwei `ok`-Zeilen. Falls `yaml` fehlt: `pip install pyyaml`.

- [ ] **Step 6: Commit**

```bash
cd ~/stillwater
git add export_presets.cfg .github/ .gitignore
git commit -m "Android-Export-Vorgabe und CI für Tests und APK"
```

- [ ] **Step 7: Repo anlegen und pushen**

**Erst nach ausdrücklicher Freigabe durch den Nutzer** — ein öffentliches Repo ist nach außen sichtbar.

```bash
cd ~/stillwater
gh repo create Phioster/stillwater --public --source=. --remote=origin --push
gh workflow run build.yml
```

- [ ] **Step 8: APK aufs Gerät bringen**

```bash
cd ~/stillwater
gh run watch
gh run download -n stillwater-debug-apk -D ~/stillwater-apk
adb install -r ~/stillwater-apk/stillwater-debug.apk
```

`adb devices` muss `emulator-5554` zeigen — das ist das echte Handy des Nutzers. Nur installieren, die App nicht selbst starten oder fernsteuern.

---

## Task 19: Dokumentation

**Files:**
- Create: `README.md`
- Create: `GAME_DESIGN.md`
- Create: `ARCHITECTURE.md`
- Create: `TODO.md`

**Interfaces:**
- Consumes: den fertigen Slice
- Produces: die vier von der Spec verlangten Dokumente

- [ ] **Step 1: `README.md` schreiben**

Inhalt, jeweils als eigener Abschnitt:

- **Was Stillwater ist** — zwei Sätze, plus der Hinweis, dass Inhalte eigenständig sind und reale Fischarten frei verwendet werden
- **Voraussetzungen** — Godot 4.7.2 stable; für den Android-Export zusätzlich JDK 17 und das Android SDK, beides nur in der CI nötig
- **Starten** — `godot res://scenes/main.tscn`, dazu der Termux-Weg über `tools/godot.sh`
- **Tests** — `PROJECT=$HOME/stillwater bash ./tools/godot.sh --script res://tests/run_tests.gd`
- **Inhalte neu erzeugen** — `--script res://tools/build_data.gd` für die `.tres`, `--script res://tools/gen_sprites.gd` für die Platzhalter-Sprites
- **Android bauen** — `gh workflow run build.yml`, danach `gh run download` und `adb install -r`
- **Projektstruktur** — die Tabelle aus dem Abschnitt „Dateistruktur" dieses Plans

- [ ] **Step 2: `GAME_DESIGN.md` schreiben**

Die Spec `docs/superpowers/specs/2026-08-26-stillwater-design.md` ist die Quelle. `GAME_DESIGN.md` fasst die **Systeme** zusammen, ohne sie zu duplizieren: Fang-Loop, Auto- gegen Manualfang und die Entkommen-Regel, Raritäten und Qualitäten, Secret-Fische mit Bedingungssystem, Journal und Fisch-Level, Ökonomie mit der einen Preisformel, Fortschritt, Köder, Zonen, Offline-Verhalten, Cosmetics. Jeder Abschnitt endet mit einem Verweis auf den entsprechenden Spec-Abschnitt.

Wichtig: die drei bewussten Abweichungen vom Vorbild ausdrücklich benennen — Fische können entkommen, der Grundköder ist unbegrenzt, Shiny ist 1 zu 800 statt 1 zu 3000 — jeweils mit der Begründung. Sonst „repariert" jemand später versehentlich eine absichtliche Entscheidung.

- [ ] **Step 3: `ARCHITECTURE.md` schreiben**

Erklärt die Godot-Struktur:

- **Der Grundsatz** — Simulationskern plus dünne Ansicht, und warum: der Offline-Fortschritt ist derselbe `tick()`, kein zweites System
- **Die Regel für `core/`** — kein `extends Node`, kein `get_node`, kein `await get_tree()`
- **Warum `tick()` deltaunabhängig ist** — segmentweise geschlossen gerechnet, damit ein `tick(43200.0)` dasselbe liefert wie 432 000 kleine Ticks
- **Die vier Autoloads** und warum es keinen fünften gibt
- **Datenfluss** — `Database` lädt `.tres` → `Game` baut den `SimContext` → `FishingSim` rechnet → Ereignisse werden zu Signalen → Panels zeichnen sich neu
- **Warum Resources statt JSON** — Godots eigene Antwort auf datengetriebenes Design
- **Wo Zufall herkommt** — `Game.rng` für Spielentscheidungen, `randf_range` für reine Darstellung wie Orb-Positionen, und warum die Trennung nötig ist
- **Testaufbau** — `SceneTree`-Skript ohne Plugin, und welcher Test der wichtigste ist

- [ ] **Step 4: `TODO.md` schreiben**

Nach Nähe geordnet:

**Als Nächstes** — Audio (Wasser, Wurf, Biss, Fang, Verkauf, Upgrade, Level-Up, UI), echte Hintergrundgrafik für Sunset Coast, Fisch-Level über Mini-Quests

**Danach** — Quest-System, Consumables **über Anzahl Fänge statt Echtzeit**, ein einziger Rückkehr-Rhythmus statt mehrerer Echtzeituhren, Raritäten Epic und Legendary, weitere Zonen

**Bedingungstypen für Secret-Fische** — Aussehen, Tageszeit, Fänge in dieser Zone, Journal-Fortschritt, aktiver Trank

**Inhalte** — Willow Lake auf 12 bis 18 Arten ausbauen, davon späte Epic- und Legendary-Fische, die erst mit späten Ködern anbeißen, damit die Startzone nicht zu totem Inhalt wird

**Technik** — Lokalisierung über Godots CSV-Übersetzungen, Release-Keystore über GitHub-Secrets, Statistiken, Einstellungen

- [ ] **Step 5: Commit**

```bash
cd ~/stillwater
git add README.md GAME_DESIGN.md ARCHITECTURE.md TODO.md
git commit -m "README, Game-Design, Architektur und TODO"
```

---

## Abschluss

Der Slice ist fertig, wenn:

1. `PROJECT=$HOME/stillwater bash ./tools/godot.sh --script res://tests/run_tests.gd` grün ist, insbesondere `test_offline_equals_online`
2. `Database.validate()` keine Probleme meldet
3. `scenes/main.tscn` headless ohne `SCRIPT ERROR` startet
4. die CI beide Workflows grün durchläuft
5. die APK auf dem Gerät installiert ist und der Loop dort läuft: angeln, Biss, Fang, verkaufen, aufrüsten
