## Das Fisch-Journal. Überlebt das Verkaufen — sonst verliert der Spieler
## beim Verkauf seine Sammlung.
class_name Journal
extends RefCounted

## Fischlevel steigt mit den Faengen dieser Art. Dreieckszahlen: Stufe n
## verlangt 5*(1+2+...+n) Faenge, also 5, 15, 30, 50, 75 ... -- die ersten
## Stufen kommen schnell, die letzten sind ein Fernziel.
const LEVEL_STEP: int = 5
const MAX_FISH_LEVEL: int = 10

var entries: Dictionary = {}
var _secret_found: bool = false

## Faenge, die Stufe `level` verlangt.
static func catches_for_level(level: int) -> int:
	var n := clampi(level, 0, MAX_FISH_LEVEL)
	return LEVEL_STEP * n * (n + 1) / 2

## Umkehrung, ganzzahlig statt per Wurzel -- bei zehn Stufen ist die Schleife
## billiger als das Risiko, an einer Schwelle um eins danebenzuliegen.
static func level_for_count(count: int) -> int:
	var level := 0
	while level < MAX_FISH_LEVEL and count >= catches_for_level(level + 1):
		level += 1
	return level

func _blank() -> Dictionary:
	return {
		"caught_count": 0,
		"best_dev": 0.0,
		"worst_dev": 0.0,
		"caught_ranks": [],
		"shiny_found": false,
	}

## Trägt einen Fang ein. Gibt true zurück, wenn die Art neu entdeckt wurde.
func record(c: CaughtFish, is_secret: bool = false) -> bool:
	var is_new := not entries.has(c.fish_id)
	var e: Dictionary = entries.get(c.fish_id, _blank())
	if is_new:
		e["best_dev"] = c.weight_dev
		e["worst_dev"] = c.weight_dev
	else:
		e["best_dev"] = maxf(float(e["best_dev"]), c.weight_dev)
		e["worst_dev"] = minf(float(e["worst_dev"]), c.weight_dev)
	e["caught_count"] = int(e["caught_count"]) + 1
	# Welche Raenge dieser Art schon an Land waren. Das ist die zweite
	# Sammelachse neben "welche Arten" -- Arten mal Raenge.
	var ranks: Array = e["caught_ranks"]
	if not ranks.has(c.rank):
		ranks.append(c.rank)
		ranks.sort()
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
	return level_for_count(int(entry(id)["caught_count"]))

## Fortschritt in der laufenden Stufe: [in dieser Stufe, fuer die naechste].
## Auf der Hoechststufe [0, 0] -- die Anzeige zeigt dann keinen Balken.
func level_progress(id: StringName) -> Array[int]:
	var count := int(entry(id)["caught_count"])
	var level := level_for_count(count)
	if level >= MAX_FISH_LEVEL:
		return [0, 0]
	var base := catches_for_level(level)
	return [count - base, catches_for_level(level + 1) - base]

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
		# TIEF kopieren: caught_ranks ist ein Array im Eintrag, eine flache
		# Kopie wuerde es zwischen Journal und Spielstand teilen.
		out["entries"][String(id)] = (entries[id] as Dictionary).duplicate(true)
	return out

func load_dict(d: Dictionary) -> void:
	entries.clear()
	_secret_found = bool(d.get("secret_found", false))
	var raw: Dictionary = d.get("entries", {})
	for key in raw:
		entries[StringName(key)] = (raw[key] as Dictionary).duplicate(true)

func caught_ranks(id: StringName) -> Array:
	return entry(id)["caught_ranks"]

func has_rank(id: StringName, rank: int) -> bool:
	return caught_ranks(id).has(rank)

## Anteil aller Art-Rang-Felder, die schon gefuellt sind. Die zweite
## Vollstaendigkeit neben completion(), und die deutlich laengere.
func rank_completion(all_fish: Array[FishData]) -> float:
	var total := 0
	var found := 0
	for f in all_fish:
		if f.is_secret:
			continue
		total += FishRoll.RANK_NAMES.size()
		found += caught_ranks(f.id).size()
	return 0.0 if total == 0 else float(found) / float(total)
