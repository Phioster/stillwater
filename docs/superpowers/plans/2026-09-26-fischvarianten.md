# Fischvarianten — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fänge können Schimmer, Dunkel, Trophäe oder Albino sein – mit
eigener Chance, eigenem Wert, eigenem Bild, und sichtbar im Journal.

**Architecture:** Ein neues, zustandsloses Modul `core/fish_variant.gd`
kennt alle Varianten (Chance, Wert, Name, Bildpfad, Rangfolge) und würfelt.
`CaughtFish.variant` trägt das Ergebnis; `is_shiny` bleibt als abgeleitete
Eigenschaft, damit bestehender Code weiterläuft. Die Bilder rechnet
`tools/fische_bauen.py` beim Bauen aus den fertigen Zonenbildern.

**Tech Stack:** Godot 4.7.2 / GDScript, Python 3 + Pillow (Bauwerkzeug).

**Spec:** `docs/superpowers/specs/2026-09-26-fischvarianten-design.md`

## Global Constraints

- Varianten-IDs: `&""` normal, `&"shiny"`, `&"dark"`, `&"trophy"`, `&"albino"`.
- Chancen: shiny 1/800, dark 1/1500, trophy 1/3000, albino 1/10000.
- Wertfaktoren: shiny 4, dark 6, trophy 10, albino 25.
- Dunkel nur bei `hour_of_day` 21, 22, 23, 0, 1, 2, 3, 4, 5.
- Würfelreihenfolge albino → trophy → dark → shiny; erster Treffer gewinnt.
- Fischlevel: jede Chance × (1 + 0,05·Level); `shiny_bonus` nur auf shiny.
- Offline: keine Variante, kein Geheimfisch; die Würfe werden trotzdem
  gezogen (gleicher Zufallsstrom wie online), nur das Ergebnis verworfen.
- Beste Variante: albino > trophy > dark > shiny > normal.
- Bildnamen: `fish_<id>_<variant>.png` (z. B. `fish_pike_albino.png`).
- Testtor `bash tools/test.sh`, Rückgabewert prüfen (in Datei umleiten,
  nicht pipen). Neue Testdateien in `tests/run_tests.gd` eintragen.
- Kommentare kurz (1–2 Zeilen), das Warum.
- Nach jeder fertigen Aufgabe: committen; nach Aufgabe 4 und 6 bauen und
  installieren (push → `gh workflow run build.yml --ref master` → beide
  Läufe grün → `gh run download` → `bash tools/sign.sh <apk> --install`).

## Review Focus

- Alter Spielstand mit `"is_shiny": true` im Inventar und
  `"shiny_found": true` im Journal → lädt als Schimmer, Journal zeigt ihn.
- Fang um 20:59 vs. 21:00 und 5:59 vs. 6:00 → Dunkel nur ab 21 bis 5 Uhr.
- Offline-Nachlauf über 12 Stunden mit Schimmer-Trank → kein einziger
  besonderer Fang, keine Geheimart.
- Art ohne erkennbares Auge (z. B. Schwarzes Loch) → Albino/Dunkel-Bild
  existiert trotzdem, nur ohne rotes Auge; kein Absturz beim Bauen.
- Journal-Detail einer Art, von der nur „normal“ gefangen ist → die übrigen
  Varianten stehen als „???“ und lassen sich nicht antippen.

---

### Task 1: Variantenmodul, Fang-Datensatz, Preis

**Files:**
- Create: `core/fish_variant.gd`
- Modify: `core/caught_fish.gd`, `core/economy.gd`, `core/fish_roll.gd`
- Test: `tests/test_fish_variant.gd` (neu, in `tests/run_tests.gd` eintragen), `tests/test_economy.gd`
- Danach: `python3 tools/gen_class_cache.py` (neue class_name)

**Interfaces:**
- Produces:
  - `FishVariant.NONE/SHINY/DARK/TROPHY/ALBINO: StringName`
  - `FishVariant.ORDER: Array[StringName]` (beste zuerst: albino, trophy, dark, shiny)
  - `FishVariant.roll(fish_level: int, shiny_bonus: float, hour: int, rng: StillRNG) -> StringName`
  - `FishVariant.mult(v: StringName) -> float`
  - `FishVariant.display_name(v: StringName) -> String`
  - `FishVariant.best(found: Array) -> StringName`
  - `FishVariant.texture_path(fish_id: StringName, v: StringName) -> String`
  - `FishVariant.is_night(hour: int) -> bool`
  - `CaughtFish.variant: StringName`; `CaughtFish.is_shiny` bleibt (abgeleitet)
  - `CaughtFish.make(id, dev, shiny := false, variant := &"")`

- [ ] **Step 1: Failing tests** — `tests/test_fish_variant.gd`:

```gdscript
extends TestCase

func _rng(seed: int) -> StillRNG:
	var r := StillRNG.new()
	r.seed_with(seed)
	return r

func test_hoechstens_eine_und_nachts_dunkel() -> void:
	var rng := _rng(3)
	var seen := {}
	for i in 200000:
		var v := FishVariant.roll(0, 1.0, 12, rng)
		seen[v] = int(seen.get(v, 0)) + 1
	assert_false(seen.has(FishVariant.DARK), "tagsueber nie dunkel")
	assert_true(seen.has(FishVariant.SHINY))
	var n := 0
	rng = _rng(3)
	for i in 200000:
		if FishVariant.roll(0, 1.0, 23, rng) == FishVariant.DARK:
			n += 1
	assert_true(n > 60 and n < 220, "nachts etwa 1/1500: %d" % n)

func test_nachtgrenzen() -> void:
	for h in [21, 22, 23, 0, 1, 2, 3, 4, 5]:
		assert_true(FishVariant.is_night(h), "Stunde %d" % h)
	for h in [6, 12, 20]:
		assert_false(FishVariant.is_night(h), "Stunde %d" % h)

func test_seltenheit_folgt_der_tabelle() -> void:
	var rng := _rng(9)
	var zaehler := {}
	for i in 400000:
		var v := FishVariant.roll(0, 1.0, 12, rng)
		zaehler[v] = int(zaehler.get(v, 0)) + 1
	assert_true(int(zaehler.get(FishVariant.SHINY, 0)) > int(zaehler.get(FishVariant.TROPHY, 0)))
	assert_true(int(zaehler.get(FishVariant.TROPHY, 0)) > int(zaehler.get(FishVariant.ALBINO, 0)))

func test_schimmertrank_nur_auf_schimmer() -> void:
	var a := 0
	var b := 0
	var r1 := _rng(5)
	var r2 := _rng(5)
	for i in 200000:
		if FishVariant.roll(0, 1.0, 12, r1) == FishVariant.TROPHY: a += 1
		if FishVariant.roll(0, 8.0, 12, r2) == FishVariant.TROPHY: b += 1
	assert_eq(a, b, "der Trank aendert die Trophaeen nicht")

func test_beste_variante() -> void:
	assert_eq(FishVariant.best([]), FishVariant.NONE)
	assert_eq(FishVariant.best(["shiny", "albino", "dark"]), FishVariant.ALBINO)
	assert_eq(FishVariant.best(["shiny", "dark"]), FishVariant.DARK)

func test_bildpfad() -> void:
	assert_eq(FishVariant.texture_path(&"pike", FishVariant.NONE), "res://assets/art/fish_pike.png")
	assert_eq(FishVariant.texture_path(&"pike", FishVariant.ALBINO), "res://assets/art/fish_pike_albino.png")

func test_fang_speichert_variante_und_liest_alten_schimmer() -> void:
	var c := CaughtFish.make(&"pike", 0.5, false, FishVariant.TROPHY)
	var back := CaughtFish.from_dict(c.to_dict())
	assert_eq(back.variant, FishVariant.TROPHY)
	assert_false(back.is_shiny)
	var alt := CaughtFish.from_dict({"fish_id": "pike", "weight_dev": 0.0, "is_shiny": true})
	assert_eq(alt.variant, FishVariant.SHINY)
	assert_true(alt.is_shiny)
```

In `tests/test_economy.gd` ergänzen:

```gdscript
func test_variante_multipliziert_den_preis() -> void:
	var f: FishData = Database.fish[&"pike"]
	var r := Game.ctx.rarity_of(f)
	var base := Economy.sell_price(CaughtFish.make(&"pike", 0.0), f, r)
	for v in [FishVariant.SHINY, FishVariant.DARK, FishVariant.TROPHY, FishVariant.ALBINO]:
		var p := Economy.sell_price(CaughtFish.make(&"pike", 0.0, false, v), f, r)
		assert_eq(p, int(floor(float(base) * FishVariant.mult(v))), String(v))
```

- [ ] **Step 2:** `bash tools/test.sh > ~/.cache/sw-test.log 2>&1; echo $?` → rot (FishVariant fehlt).

- [ ] **Step 3: Implementierung** — `core/fish_variant.gd`:

```gdscript
## Die besonderen Faelle eines Fangs. Zustandslos, damit jeder Wurf testbar ist.
class_name FishVariant
extends RefCounted

const NONE := &""
const SHINY := &"shiny"
const DARK := &"dark"
const TROPHY := &"trophy"
const ALBINO := &"albino"
## Beste zuerst -- zugleich die Wuerfelreihenfolge (selten vor haeufig).
const ORDER: Array[StringName] = [ALBINO, TROPHY, DARK, SHINY]
const CHANCE := {ALBINO: 1.0 / 10000.0, TROPHY: 1.0 / 3000.0, DARK: 1.0 / 1500.0, SHINY: 1.0 / 800.0}
const MULT := {NONE: 1.0, SHINY: 4.0, DARK: 6.0, TROPHY: 10.0, ALBINO: 25.0}
const NAMES := {NONE: "Normal", SHINY: "Schimmer", DARK: "Dunkel", TROPHY: "Trophäe", ALBINO: "Albino"}

static func is_night(hour: int) -> bool:
	return hour >= 21 or hour <= 5

## Jede Variante wird gewuerfelt, auch wenn eine fruehere schon traf: so
## verbraucht jeder Fang gleich viele Zufallszahlen (Offline == Online).
static func roll(fish_level: int, shiny_bonus: float, hour: int, rng: StillRNG) -> StringName:
	var level_mult := 1.0 + 0.05 * float(fish_level)
	var result := NONE
	for v in ORDER:
		var chance: float = CHANCE[v] * level_mult
		if v == SHINY:
			chance *= shiny_bonus
		var hit := rng.randf() < chance
		if v == DARK and not is_night(hour):
			hit = false
		if hit and result == NONE:
			result = v
	return result

static func mult(v: StringName) -> float:
	return float(MULT.get(v, 1.0))

static func display_name(v: StringName) -> String:
	return String(NAMES.get(v, "Normal"))

static func best(found: Array) -> StringName:
	for v in ORDER:
		if found.has(String(v)) or found.has(v):
			return v
	return NONE

static func texture_path(fish_id: StringName, v: StringName) -> String:
	if v == NONE:
		return "res://assets/art/fish_%s.png" % fish_id
	return "res://assets/art/fish_%s_%s.png" % [fish_id, v]
```

`core/caught_fish.gd`: `var is_shiny: bool = false` ersetzen durch

```gdscript
var variant: StringName = &""
## Abgeleitet, damit bestehender Code (Kiste, Effekte, Tests) weiterlaeuft.
var is_shiny: bool:
	get:
		return variant == FishVariant.SHINY
	set(value):
		variant = FishVariant.SHINY if value else FishVariant.NONE
```

`make` bekommt `variant: StringName = &""` als vierten Parameter und setzt
`c.variant = variant if variant != &"" else (FishVariant.SHINY if shiny else FishVariant.NONE)`.
`to_dict` schreibt `"variant": String(variant)` statt `"is_shiny"`.
`from_dict`: `var v := StringName(d.get("variant", "shiny" if bool(d.get("is_shiny", false)) else ""))`, dann `CaughtFish.make(..., false, v)`.

`core/economy.gd`: `SHINY_MULT` streichen, stattdessen
`price *= FishVariant.mult(caught.variant)`.

`core/fish_roll.gd`: `SHINY_BASE` und `roll_shiny` entfernen;
`tests/test_fish_roll.gd` Zeilen 120–140 (die beiden roll_shiny-Tests)
entfernen – sie sind durch `test_fish_variant.gd` ersetzt.

- [ ] **Step 4:** `python3 tools/gen_class_cache.py`, Testtor → grün.
- [ ] **Step 5:** Commit `Varianten: Modul, Fang-Datensatz, Preis`.

### Task 2: Fang-Simulation und Offline

**Files:**
- Modify: `core/fishing_sim.gd`, `core/sim_context.gd`, `core/offline_sim.gd`
- Test: `tests/test_fishing_sim.gd`, `tests/test_offline_sim.gd`, `tests/test_game_actions.gd`

**Interfaces:**
- Consumes: `FishVariant.roll`, `CaughtFish.make(id, dev, shiny, variant)`
- Produces: `FishingSim.hooked_variant: StringName` (`hooked_shiny` bleibt
  als abgeleitete Eigenschaft); `SimContext.offline: bool`

- [ ] **Step 1: Failing tests** — in `tests/test_offline_sim.gd`:

```gdscript
func test_offline_nichts_besonderes() -> void:
	var ctx := _ctx()   # vorhandener Helfer der Datei
	ctx.shiny_bonus = 1000.0
	ctx.hour_of_day = 23
	var sim := FishingSim.new()
	var rng := StillRNG.new()
	rng.seed_with(11)
	var out := OfflineSim.run(12.0 * 3600.0, sim, ctx, rng, Database.fish)
	for c in ctx.inventory.fish:
		assert_eq((c as CaughtFish).variant, FishVariant.NONE)
		assert_false((Database.fish[c.fish_id] as FishData).is_secret)
	assert_false(ctx.offline, "nach dem Nachlauf wieder online")
```

(Heißt der Helfer anders, den in der Datei vorhandenen Kontextbau nehmen
und auf `willow_lake` stellen.)

In `tests/test_fishing_sim.gd`:

```gdscript
func test_online_kann_schimmern() -> void:
	var ctx := _ctx()
	ctx.shiny_bonus = 1000.0
	var sim := FishingSim.new()
	var rng := StillRNG.new()
	rng.seed_with(2)
	sim.tick(3600.0, ctx, rng)
	var schimmer := 0
	for c in ctx.inventory.fish:
		if (c as CaughtFish).is_shiny:
			schimmer += 1
	assert_true(schimmer > 0)
```

- [ ] **Step 2:** Testtor → rot.

- [ ] **Step 3: Implementierung**
  - `SimContext`: `## Offline-Nachlauf: nur normale Fische.` `var offline: bool = false`.
  - `FishingSim`: `var hooked_shiny: bool = false` ersetzen durch
    `var hooked_variant: StringName = &""` plus abgeleitetes
    `var hooked_shiny: bool:` (get: `hooked_variant == FishVariant.SHINY`;
    set: `hooked_variant = FishVariant.SHINY if value else FishVariant.NONE`).
  - `_on_bite`: `hooked_variant = FishVariant.roll(ctx.journal.fish_level(fish.id), ctx.shiny_bonus, ctx.hour_of_day, rng)`,
    danach `if ctx.offline: hooked_variant = FishVariant.NONE`.
  - `_land`: `CaughtFish.make(fish.id, hooked_dev, false, hooked_variant)`.
  - `_clear_hooked`: `hooked_variant = FishVariant.NONE`.
  - `select_fish`: `var secret := _roll_secret(ctx, rng)` bleibt (Würfe
    werden gezogen), dann `if secret != null and not ctx.offline: return secret`.
  - `OfflineSim.run`: vor `sim.tick` `ctx.offline = true`, danach
    `ctx.offline = false`.
  - Bestehende Tests, die `hooked_shiny` setzen/vergleichen, laufen über die
    Eigenschaft weiter; der Offline/Online-Vergleich in
    `test_offline_sim.gd:97/170` vergleicht künftig `hooked_variant`.

- [ ] **Step 4:** Testtor → grün.
- [ ] **Step 5:** Commit `Varianten: Fang-Simulation, offline nur normale Fische`.

### Task 3: Journal, Statistik, Spielstand

**Files:**
- Modify: `core/journal.gd`, `core/records.gd`, `autoload/Game.gd` (`_dispatch`), `autoload/SaveManager.gd`
- Test: `tests/test_journal.gd`, `tests/test_records.gd`, `tests/test_save_manager.gd`

**Interfaces:**
- Consumes: `CaughtFish.variant`, `FishVariant.best`
- Produces: Journal-Eintrag `"variants": Array` (Strings); `"shiny_found"`
  bleibt und wird weiter gepflegt; `Journal.variants(id) -> Array`;
  `Journal.best_variant(id) -> StringName`;
  `Records.dark_caught/trophy_caught/albino_caught: int`

- [ ] **Step 1: Failing tests**

`tests/test_journal.gd`:

```gdscript
func test_varianten_werden_gesammelt() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"pike", 0.0, false, FishVariant.DARK))
	j.record(CaughtFish.make(&"pike", 0.0, false, FishVariant.SHINY))
	j.record(CaughtFish.make(&"pike", 0.0))
	assert_eq(j.variants(&"pike").size(), 2)
	assert_eq(j.best_variant(&"pike"), FishVariant.DARK)
	assert_true(j.entry(&"pike")["shiny_found"])

func test_alter_eintrag_ohne_varianten() -> void:
	var j := Journal.new()
	j.load_dict({"entries": {"pike": {"caught_count": 1, "best_dev": 0.0,
		"worst_dev": 0.0, "caught_ranks": [2], "shiny_found": true}}})
	assert_eq(j.best_variant(&"pike"), FishVariant.SHINY)
```

`tests/test_records.gd`: ein Fang mit `FishVariant.TROPHY` über
`Game._dispatch([{"type": "caught", "caught": c, "fish": f, "discovered": false, "record": false}])`
erhöht `Game.records.trophy_caught` um 1 und `shiny_caught` nicht.

`tests/test_save_manager.gd`: Spielstand mit Inventar
`{"fish_id": "bluegill", "weight_dev": 0.0, "variant": "albino"}` und
Journal `"variants": ["albino", 5, "quatsch"]` → nach `deserialize`
`inventory.fish[0].variant == &"albino"`; `journal.variants(&"bluegill") == ["albino"]`
(unbekannte und falsch typisierte Einträge fallen weg).

- [ ] **Step 2:** Testtor → rot.

- [ ] **Step 3: Implementierung**
  - `Journal._blank()`: `"variants": []` ergänzen.
  - `Journal.record`: nach dem Schimmer-Block
    ```gdscript
    	if c.variant != FishVariant.NONE:
    		var vs: Array = e.get("variants", [])
    		if not vs.has(String(c.variant)):
    			vs.append(String(c.variant))
    		e["variants"] = vs
    ```
  - `Journal.variants(id) -> Array`: `var vs: Array = entry(id).get("variants", []).duplicate()`;
    `if bool(entry(id).get("shiny_found", false)) and not vs.has("shiny"): vs.append("shiny")`; `return vs`.
  - `Journal.best_variant(id) -> StringName`: `return FishVariant.best(variants(id))`.
  - `Records`: drei Zähler + in `FIELDS` ergänzen.
  - `Game._dispatch` (`"caught"`): nach dem Schimmer-Zähler
    `match (e["caught"] as CaughtFish).variant:` → `FishVariant.DARK: records.dark_caught += 1` usw.
  - `SaveManager._sanitize_fish_entry`: `"variant": _safe_variant(entry)` –
    liest `"variant"` (nur bekannte IDs, sonst `""`), fällt auf `"is_shiny"` zurück.
  - `SaveManager._sanitize_journal_entry`: `"variants"` = nur Strings aus
    `["shiny","dark","trophy","albino"]`, ohne Doppelte.
  - `records_panel.gd`: drei Zeilen „Dunkle Fänge“, „Trophäen“, „Albinos“.

- [ ] **Step 4:** Testtor → grün.
- [ ] **Step 5:** Commit `Varianten: Journal, Statistik, Spielstand`.

### Task 4: Variantenbilder im Bauwerkzeug (mit Abnahme)

**Files:**
- Modify: `tools/fische_bauen.py`, `tests/test_sprite_assets.gd`
- Test: `tools/tests/test_fische_bauen.py`

**Interfaces:**
- Produces: `assets/art/fish_<id>_{shiny,dark,trophy,albino}.png` für alle
  114 Arten, gleiche Größe wie `fish_<id>.png`; in Python
  `fb.augen(bild) -> list[set[tuple]]`, `fb.variante(bild, v, augen) -> Image`,
  Tabelle `fb.AUGEN = {fid: [(x, y), ...]}` (leere Liste = kein Auge).

- [ ] **Step 1: Failing tests** (`tools/tests/test_fische_bauen.py`):

```python
    def _fisch_mit_auge(self):
        bild = Image.new("RGBA", KLEIN, (0, 0, 0, 0))
        for x in range(8, 40):
            for y in range(6, 18):
                bild.putpixel((x, y), (120, 150, 90, 255))
        bild.putpixel((12, 10), (10, 10, 10, 255))
        return bild

    def test_auge_wird_gefunden(self):
        augen = fb.augen(self._fisch_mit_auge())
        self.assertEqual(len(augen), 1)
        self.assertIn((12, 10), augen[0])

    def test_albino_hat_rotes_auge_und_gleiche_silhouette(self):
        bild = self._fisch_mit_auge()
        alb = fb.variante(bild, "albino", fb.augen(bild))
        r, g, b, a = alb.getpixel((12, 10))
        self.assertTrue(r > 150 and g < 80, (r, g, b))
        self.assertEqual(bild.getchannel("A").tobytes(), alb.getchannel("A").tobytes())

    def test_alle_varianten_behalten_die_form(self):
        bild = self._fisch_mit_auge()
        for v in ("shiny", "dark", "trophy", "albino"):
            neu = fb.variante(bild, v, fb.augen(bild))
            self.assertEqual(neu.size, bild.size)
            self.assertEqual(bild.getchannel("A").tobytes(), neu.getchannel("A").tobytes(), v)
```

`tests/test_sprite_assets.gd`: für jede Art in `Database.fish` und jede der
vier Varianten muss `res://assets/art/fish_<id>_<v>.png` existieren und
dieselbe Größe wie `fish_<id>.png` haben; die Größenregel für `fish_`
schneidet dafür zusätzlich die Endungen `_shiny/_dark/_trophy/_albino` ab.

- [ ] **Step 2:** Tests → rot.

- [ ] **Step 3: Implementierung** in `tools/fische_bauen.py`:

```python
VARIANTEN = ("shiny", "dark", "trophy", "albino")
## Augen, die die Erkennung verfehlt: Art -> Pixel. [] = kein Auge.
AUGEN = {}

def _hell(p):
    return p[0] * 0.3 + p[1] * 0.59 + p[2] * 0.11

def augen(bild):
    """Dunkle Inseln (1-4 Pixel) im Koerper, rundum heller -- so sieht ein
    Pixelauge aus. Umriss und Flaechenschatten fallen durch die Groesse raus."""
    w, h = bild.size
    px = bild.load()
    def innen(x, y):
        return all(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    dunkel = {(x, y) for x in range(w) for y in range(h)
              if px[x, y][3] and _hell(px[x, y]) < 45 and innen(x, y)}
    inseln, gesehen = [], set()
    for start in dunkel:
        if start in gesehen:
            continue
        insel, offen = set(), [start]
        while offen:
            q = offen.pop()
            if q in insel or q not in dunkel:
                continue
            insel.add(q)
            offen += [(q[0] + dx, q[1] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        gesehen |= insel
        rand = {(x + dx, y + dy) for x, y in insel for dx in (-1, 0, 1) for dy in (-1, 0, 1)} - insel
        if len(insel) <= 4 and all(0 <= x < w and 0 <= y < h and px[x, y][3] and _hell(px[x, y]) > 90
                                   for x, y in rand):
            inseln.append(insel)
    return inseln

def _rampe(stufen, l):
    i = min(len(stufen) - 1, int(l / 256 * len(stufen)))
    return stufen[i]

def variante(bild, v, augen_liste):
    aus = bild.copy()
    px = aus.load()
    w, h = aus.size
    auge = set().union(*augen_liste) if augen_liste else set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a:
                continue
            l = _hell((r, g, b))
            if l < 30 and (x, y) not in auge:
                continue  # Umriss bleibt
            if v == "shiny":
                n = (int(r * 0.45 + 70), int(g * 0.55 + 90), min(255, int(b * 0.5 + 150)))
            elif v == "trophy":
                n = _rampe([(96, 62, 14), (160, 112, 28), (214, 164, 48), (244, 206, 96), (255, 238, 170)], l)
            elif v == "albino":
                n = _rampe([(128, 128, 132), (176, 176, 180), (214, 214, 216), (238, 238, 238), (252, 252, 250)], l)
            else:  # dark
                n = _rampe([(14, 12, 20), (26, 22, 34), (40, 34, 50), (58, 50, 70)], l)
            px[x, y] = n + (255,)
    if v in ("albino", "dark"):
        for x, y in auge:
            px[x, y] = (214, 24, 36, 255)
    return aus
```

In `main()` nach dem Speichern von `fish_<id>.png`:

```python
            gefunden = [set(AUGEN[fid])] if AUGEN.get(fid) else ([] if fid in AUGEN else augen(bild))
            for v in VARIANTEN:
                variante(bild, v, gefunden).save(os.path.join(ZIEL, "fish_%s_%s.png" % (fid, v)))
```

Beim Glitchfisch wird `variante` auf das bereits verzerrte Bild angewendet.
Zusätzlich gibt `main()` eine Liste der Arten aus, bei denen die Erkennung
0 oder mehr als 3 Augen fand (Kandidaten für `AUGEN`).

- [ ] **Step 4:** `python3 -m tools.fische_bauen`, Tests → grün.
- [ ] **Step 5: Abnahme (Nutzer).** Bogen je Zone (Normal · Schimmer ·
  Dunkel · Trophäe · Albino nebeneinander) auf die Vorschauseite; die von
  `main()` gemeldeten unsicheren Arten in Fünfergruppen vorlegen, Augen in
  `AUGEN` nachtragen, neu bauen. Farbrampen nur nach Rückmeldung ändern.
- [ ] **Step 6:** Commit `Varianten: Bilder aus dem Bauwerkzeug`; bauen und installieren.

### Task 5: Variantensymbole

**Files:**
- Create: `assets/source/varianten/<v>.png` (PixelLab), `assets/art/variant_<v>.png`
- Modify: `tests/test_sprite_assets.gd`

**Interfaces:**
- Produces: `FishVariant.icon_path(v) -> String` = `"res://assets/art/variant_%s.png" % v`
  (in `core/fish_variant.gd` ergänzen); Symbole 32×32.

- [ ] **Step 1:** Test in `tests/test_sprite_assets.gd`: `variant_<v>.png`
  existiert für alle vier und ist 32×32 (Größenregel `variant_` → 32×32).
- [ ] **Step 2:** PixelLab `create_image_pixflux` 32×32, `no_background`:
  Schimmer = kleiner blauer vierzackiger Funkelstern; Dunkel = kleiner
  dunkelvioletter Halbmond; Trophäe = kleiner goldener Pokal; Albino =
  kleine weiße Perle mit rotem Glanzpunkt. Abnahme auf der Vorschauseite,
  dann nach `assets/source/varianten/` und `assets/art/variant_<v>.png`.
- [ ] **Step 3:** `icon_path` ergänzen, Testtor grün, Commit.

### Task 6: Anzeige im Spiel

**Files:**
- Modify: `scenes/ui/panels/journal_panel.gd`, `scenes/ui/fish_window.gd`,
  `scenes/ui/fish_row.gd`, `scenes/ui/catch_toast.gd`, `scenes/fishing/world.gd`,
  `scenes/effects/effects.gd`, `scenes/ui/panels/secret_panel.gd`
- Test: `tests/test_fish_window.gd`, `tests/test_tabs_and_journal_order.gd` (Journalzeile), `tests/test_zone_look.gd` (Haken)

**Interfaces:**
- Consumes: `FishVariant.texture_path/icon_path/display_name/best/ORDER`,
  `Journal.variants/best_variant`, `CaughtFish.variant`
- Produces: `FishWindow.show_variant(v: StringName)`; Knoten
  `Panel/Box/VariantRow` (HBoxContainer mit je einem `TapButton` pro
  Variante, Meta `&"variant"`)

- [ ] **Step 1: Failing tests**

`tests/test_fish_window.gd`:

```gdscript
func test_varianten_zeile_wechselt_das_bild() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"pike", 0.0, false, FishVariant.ALBINO))
	var w := _window()
	w.open(&"pike")
	var reihe: HBoxContainer = w.get_node("Panel/Box/VariantRow")
	var albino: TapButton = null
	var dunkel: TapButton = null
	for b in reihe.get_children():
		if b.get_meta(&"variant") == FishVariant.ALBINO: albino = b
		if b.get_meta(&"variant") == FishVariant.DARK: dunkel = b
	assert_true(dunkel.disabled and dunkel.text == "???", "nicht gefunden")
	albino.tapped.emit()
	assert_eq((w.get_node("Panel/Box/Icon") as TextureRect).texture.resource_path,
		FishVariant.texture_path(&"pike", FishVariant.ALBINO))
	w.queue_free()
```

Journal-Liste: nach `record(... ALBINO)` zeigt das Zeilenbild von `pike`
`texture_path(&"pike", ALBINO)`, und die Zeile enthält ein `TextureRect`
mit `icon_path(ALBINO)`.

Haken: `einholen_beginnen(fish, FishVariant.TROPHY)` lädt
`texture_path(fish.id, TROPHY)`.

- [ ] **Step 2:** Testtor → rot.

- [ ] **Step 3: Implementierung**
  - `journal_panel.gd` (Zeilenbild, ~Z. 122): bekannt →
    `FishVariant.texture_path(f.id, Game.ctx.journal.best_variant(f.id))`;
    hinter dem Namen je gefundener Variante (Reihenfolge `ORDER`) ein
    `TextureRect` 24×24 mit `icon_path`, `EXPAND_IGNORE_SIZE`,
    `STRETCH_KEEP_ASPECT_CENTERED`, `MOUSE_FILTER_IGNORE`; die Zeile
    „✦“-Anhängsel entfällt.
  - `fish_window.gd`: neuer Knoten `VariantRow` in der Szene unter dem Icon
    (auch in `fish_window.tscn` eintragen); `open(id)` baut ihn neu: für
    `[NONE] + ORDER.reversed()` (Normal, Schimmer, Dunkel, Trophäe, Albino)
    je ein `TapButton` (Text = `display_name` oder „???“ wenn nicht in
    `journal.variants` und nicht NONE; dann `disabled = true`),
    `tapped` → `show_variant(v)`. `open` zeigt zuerst die beste Variante.
    `show_variant` setzt `_icon.texture` auf `texture_path` und startet für
    SHINY/TROPHY ein leichtes Funkeln: Tween auf `_icon.self_modulate`
    zwischen `Color(1,1,1)` und `Color(1.25,1.25,1.25)` (1,2 s, Endlosschleife),
    sonst Tween stoppen und `self_modulate = Color.WHITE`.
    Zeile „Schimmernd: ja/nein“ ersetzen durch
    „Varianten: <Namen der gefundenen, sonst –>“.
  - `fish_row.gd`: „✦ “-Präfix ersetzen durch `"%s · " % display_name(v)`
    bei `v != NONE`; Farbe bleibt Seltenheitsfarbe.
  - `catch_toast.gd`: bei `c.variant != NONE` Zusatz
    `"  ✦ %s" % display_name(c.variant)`; Klang `&"shiny"` für jede Variante.
  - `world.gd` `einholen_beginnen(fish, variant := FishVariant.NONE)`:
    Textur über `texture_path(fish.id, variant)`; Aufrufer übergibt
    `caught.variant`.
  - `effects.gd`: Funkelstoß bei jeder Variante (`c.variant != NONE`).
  - `secret_panel.gd`: Bild der besten Variante wie im Journal.

- [ ] **Step 4:** Testtor → grün.
- [ ] **Step 5:** Commit `Varianten: Anzeige in Journal, Fenster, Kiste, Haken`;
  bauen und installieren; Vorschauseite aktualisieren.
