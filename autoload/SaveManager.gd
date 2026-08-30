## Spielstand: atomares Schreiben (Temp-Datei + rename), Migration alter/
## kaputter Stände, Offline-Auswertung beim Laden. Die Datei liegt beim
## Spieler auf dem Gerät -- migrate() darf ihr nie ungeprüft vertrauen.
extends Node

signal offline_ready(summary: Dictionary)

const SAVE_VERSION: int = 2
## Kein const: Tests tauschen den Pfad gegen einen eigenen, damit ein
## Testlauf nie den echten Spielstand des Entwicklers überschreibt.
var SAVE_PATH: String = "user://save.json"
const AUTOSAVE_INTERVAL: float = 60.0

var pending_offline: Dictionary = {}
var _autosave_timer: float = 0.0

func _ready() -> void:
	if not Game.progress_changed.is_connected(_on_progress_changed):
		Game.progress_changed.connect(_on_progress_changed)
	if has_save():
		load_game()

## Verkauf, Upgrade-Kauf, Köderkauf und Zonenwechsel lösen sofort einen Save
## aus, statt auf den 60-s-Takt zu warten -- siehe Spec §11.1.
func _on_progress_changed() -> void:
	save()

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

func _temp_path() -> String:
	return SAVE_PATH + ".tmp"

# --- Serialisierung ---------------------------------------------------------

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
		# Duplikat: Game.cosmetics darf nicht dieselbe Dictionary-Instanz wie
		# der gespeicherte Blob teilen (derselbe Aliasing-Fehler wie beim
		# Journal in Task 6).
		"cosmetics": Game.cosmetics.duplicate(),
		# duplicate(true): die Werte sind Arrays (Referenztyp) -- eine flache
		# Kopie würde nur das Dictionary duplizieren, nicht die Arrays darin.
		"owned_cosmetics": Game.owned_cosmetics.duplicate(true),
		"active_consumables": [],
		"settings": {},
		"statistics": {},
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"rng_state": Game.rng.get_state(),
	}

## Ein Stand aus einer neueren Version wird verweigert statt geraten --
## sonst könnten unbekannte Felder Fortschritt stillschweigend verwerfen.
func deserialize(raw: Dictionary) -> void:
	if _is_future_version(raw):
		push_error("Spielstand stammt aus einer neueren Version, wird nicht geladen")
		return
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
	Game.cosmetics = (d["cosmetics"] as Dictionary).duplicate()
	Game.ctx.cosmetics = Game.cosmetics
	Game.owned_cosmetics = (d["owned_cosmetics"] as Dictionary).duplicate(true)
	_own_the_worn_cosmetics()
	Game.rng.set_state(int(d["rng_state"]))
	Game.apply_upgrades()

	_run_offline(int(d["last_seen_unix"]))
	Game.state_changed.emit()

## Ein Stand von vor Task 20 trug Varianten, ohne sie zu "besitzen" -- ohne
## das hier wuerde das Laden eine Variante zeigen, die dem Spieler nicht gehoert.
func _own_the_worn_cosmetics() -> void:
	for category in Game.cosmetics:
		var variant := int(Game.cosmetics[category])
		var owned: Array = Game.owned_cosmetics.get(category, [0])
		if not owned.has(variant):
			owned.append(variant)
			Game.owned_cosmetics[category] = owned

func _run_offline(last_seen: int) -> void:
	var elapsed := float(int(Time.get_unix_time_from_system()) - last_seen)
	if elapsed <= 0.0:
		pending_offline = {}
		return
	pending_offline = OfflineSim.run(elapsed, Game.sim, Game.ctx, Game.rng, Database.fish)
	if int(pending_offline.get("caught", 0)) > 0:
		offline_ready.emit(pending_offline)

func _is_future_version(d: Dictionary) -> bool:
	return _safe_int(d.get("save_version"), 0) > SAVE_VERSION

# --- Migration ---------------------------------------------------------------

## Normalisiert jedes Feld auf den erwarteten Typ, bis in Inventar- und
## Journal-Einträge hinein -- deserialize() verlässt sich danach blind auf die Form.
func migrate(raw: Dictionary) -> Dictionary:
	var defaults := _defaults()
	var d := {}

	d["coins"] = _safe_int(raw.get("coins"), defaults["coins"])
	d["player_level"] = _safe_int(raw.get("player_level"), defaults["player_level"])
	d["xp"] = _safe_int(raw.get("xp"), defaults["xp"])
	d["current_zone"] = _safe_string(raw.get("current_zone"), defaults["current_zone"])
	d["active_bait"] = _safe_string(raw.get("active_bait"), defaults["active_bait"])
	d["last_seen_unix"] = _safe_int(raw.get("last_seen_unix"), defaults["last_seen_unix"])
	d["rng_state"] = _safe_int(raw.get("rng_state"), defaults["rng_state"])
	d["cosmetics"] = _safe_dict(raw.get("cosmetics"), defaults["cosmetics"])
	d["owned_cosmetics"] = _safe_owned_cosmetics(raw.get("owned_cosmetics"), defaults["owned_cosmetics"])
	d["active_consumables"] = _safe_array(raw.get("active_consumables"), [])
	d["settings"] = _safe_dict(raw.get("settings"), {})
	d["statistics"] = _safe_dict(raw.get("statistics"), {})

	var zones: Array = []
	for z in _safe_array(raw.get("unlocked_zones"), []):
		if typeof(z) == TYPE_STRING or typeof(z) == TYPE_STRING_NAME:
			zones.append(String(z))
	d["unlocked_zones"] = zones if not zones.is_empty() else defaults["unlocked_zones"]

	d["upgrade_levels"] = _safe_int_map(raw.get("upgrade_levels"), defaults["upgrade_levels"])
	d["bait_inventory"] = _safe_int_map(raw.get("bait_inventory"), {})

	var fish: Array = []
	for entry in _safe_array(raw.get("fish_inventory"), []):
		if typeof(entry) == TYPE_DICTIONARY:
			fish.append(_sanitize_fish_entry(entry))
	d["fish_inventory"] = fish

	var journal_raw := _safe_dict(raw.get("journal"), defaults["journal"])
	var entries_raw := _safe_dict(journal_raw.get("entries"), {})
	var entries := {}
	for key in entries_raw:
		if typeof(entries_raw[key]) == TYPE_DICTIONARY:
			entries[String(key)] = _sanitize_journal_entry(entries_raw[key])
	d["journal"] = {
		"secret_found": _safe_bool(journal_raw.get("secret_found"), false),
		"entries": entries,
	}

	if _safe_int(raw.get("save_version"), 0) < 2:
		d = _migrate_1_to_2(d)
	d["save_version"] = SAVE_VERSION
	return d

## Bringt einen Inventar-Eintrag auf die Form von CaughtFish.from_dict() --
## ein falsch typisiertes fish_id/quality darf nicht bis zu dessen Konstruktoren durchlaufen.
func _sanitize_fish_entry(entry: Dictionary) -> Dictionary:
	var out := {
		"fish_id": _safe_string(entry.get("fish_id"), ""),
		"weight_dev": _safe_float(entry.get("weight_dev"), 0.0),
		"is_shiny": _safe_bool(entry.get("is_shiny"), false),
		"is_favorite": _safe_bool(entry.get("is_favorite"), false),
	}
	# Version 1 speicherte das absolute Gewicht. Zum Umrechnen wird es hier
	# durchgereicht; _migrate_1_to_2 braucht es und entfernt es danach.
	if entry.has("weight") and not entry.has("weight_dev"):
		out["weight"] = _safe_float(entry.get("weight"), 0.0)
	return out

## Bringt einen Journal-Eintrag auf die Form von Journal._blank() -- dieselbe
## Absicherung wie bei Inventar-Einträgen, gegen dieselbe Fehlerklasse.
func _sanitize_journal_entry(e: Dictionary) -> Dictionary:
	var ranks: Array = []
	var raw_ranks = e.get("caught_ranks")
	if raw_ranks is Array:
		for r in raw_ranks:
			var v := _safe_int(r, -1)
			if v >= 0 and v < FishRoll.RANK_NAMES.size() and not ranks.has(v):
				ranks.append(v)
		ranks.sort()
	var out := {
		"caught_count": _safe_int(e.get("caught_count"), 0),
		"best_dev": _safe_float(e.get("best_dev"), 0.0),
		"worst_dev": _safe_float(e.get("worst_dev"), 0.0),
		"caught_ranks": ranks,
		"shiny_found": _safe_bool(e.get("shiny_found"), false),
	}
	for old in ["best_weight", "worst_weight", "best_quality"]:
		if e.has(old):
			out[old] = _safe_float(e.get(old), 0.0)
	return out

func _defaults() -> Dictionary:
	return {
		"coins": 0,
		"player_level": 1,
		"xp": 0,
		"current_zone": "willow_lake",
		"unlocked_zones": ["willow_lake"],
		"upgrade_levels": {"rod_power": 0, "orb_power": 0, "fish_inventory": 0, "bait_capacity": 0},
		"active_bait": String(Database.basic_bait().id) if Database.basic_bait() != null else "",
		"journal": {"secret_found": false, "entries": {}},
		"cosmetics": {"skin": 0, "hair": 0, "hair_color": 0, "shirt": 0, "pants": 0, "hat": 0},
		"owned_cosmetics": {"skin": [0], "hair": [0], "hair_color": [0], "shirt": [0], "pants": [0], "hat": [0]},
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"rng_state": 0,
	}

## Sichere Umwandlung roher JSON-Werte: Array/Dictionary/null würden sonst
## einen GDScript-Laufzeitfehler auslösen, der die aufrufende Funktion stumm abbricht.
func _safe_int(v, fallback: int) -> int:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL]:
		return int(v)
	return fallback

func _safe_float(v, fallback: float) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL]:
		return float(v)
	return fallback

func _safe_string(v, fallback: String) -> String:
	if typeof(v) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
		return str(v)
	return fallback

func _safe_bool(v, fallback: bool) -> bool:
	if typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
		return bool(v)
	return fallback

func _safe_dict(v, fallback: Dictionary) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else fallback

func _safe_array(v, fallback: Array) -> Array:
	return v if typeof(v) == TYPE_ARRAY else fallback

func _safe_int_map(v, fallback: Dictionary) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return fallback.duplicate()
	var out := {}
	for key in v:
		out[key] = _safe_int(v[key], 0)
	return out

## Bringt owned_cosmetics auf Kategorie -> Array[int]. Ein alter Stand ohne
## das Feld -- oder eine kaputte Kategorie darin -- bekommt "nur Variante 0".
func _safe_owned_cosmetics(v, fallback: Dictionary) -> Dictionary:
	var out := {}
	if typeof(v) == TYPE_DICTIONARY:
		for key in v:
			var variants: Array = []
			for entry in _safe_array(v[key], []):
				if typeof(entry) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL]:
					var i := _safe_int(entry, -1)
					if i >= 0 and not variants.has(i):
						variants.append(i)
			if not variants.has(0):
				variants.append(0)
			out[String(key)] = variants
	for key in fallback:
		if not out.has(key):
			out[key] = (fallback[key] as Array).duplicate()
	return out

# --- Datei --------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## dir.rename() ersetzt eine bestehende Zieldatei atomar (auf dem proot-Debian-
## Zielsystem gemessen: liefert OK, Inhalt stimmt danach) -- vorheriges Löschen würde das zerstören.
func save() -> bool:
	if Game.ctx == null:
		return false
	var f := FileAccess.open(_temp_path(), FileAccess.WRITE)
	if f == null:
		push_error("Spielstand nicht schreibbar: %d" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(serialize()))
	f.close()
	var dir := DirAccess.open(SAVE_PATH.get_base_dir())
	if dir == null:
		return false
	return dir.rename(_temp_path().get_file(), SAVE_PATH.get_file()) == OK

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	if text.is_empty():
		push_error("Spielstand leer, wird ignoriert")
		return false
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Spielstand unlesbar, wird ignoriert")
		return false
	if _is_future_version(parsed):
		push_error("Spielstand stammt aus einer neueren Version, wird nicht geladen")
		return false
	deserialize(parsed)
	return true

## Version 1 -> 2: Gewichte wurden absolut gespeichert, jetzt als Abweichung
## vom Artmittel. Die Umrechnung braucht die Artdaten; fehlt eine Art, bleibt
## der Eintrag bei Abweichung 0 -- ein Durchschnittsexemplar statt Datenmuell.
func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	for entry in d.get("fish_inventory", []):
		if entry.has("weight"):
			entry["weight_dev"] = _dev_of(entry.get("fish_id", ""), float(entry["weight"]))
			entry.erase("weight")
			entry.erase("quality")
	var entries: Dictionary = d["journal"]["entries"]
	for id in entries:
		var e: Dictionary = entries[id]
		if e.has("best_weight"):
			e["best_dev"] = _dev_of(id, float(e["best_weight"]))
			e["worst_dev"] = _dev_of(id, float(e.get("worst_weight", e["best_weight"])))
			# Der frueher beste Qualitaetsrang gilt als gefangen. Die
			# darunter liegenden Raenge sind nicht belegt und bleiben offen.
			var best := int(e.get("best_quality", 0))
			e["caught_ranks"] = [clampi(best, 0, FishRoll.RANK_NAMES.size() - 1)]
			e.erase("best_weight")
			e.erase("worst_weight")
			e.erase("best_quality")
	return d

func _dev_of(fish_id, weight: float) -> float:
	var f: FishData = Database.fish.get(StringName(fish_id))
	if f == null or f.weight_dev <= 0.0:
		return 0.0
	return clampf((weight - f.weight_mean) / f.weight_dev, -FishRoll.DEV_LIMIT, FishRoll.DEV_LIMIT)
