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
