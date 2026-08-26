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
		if not f.is_secret and not f.conditions.is_empty():
			problems.append("Fisch %s hat Fangbedingungen, ist aber nicht secret (wirkungslos)" % f.id)
		for b in f.preferred_baits:
			if not baits.has(b):
				problems.append("Fisch %s bevorzugt unbekannten Köder %s" % [f.id, b])
		if f.preferred_bait_mult <= 0.0 and not f.preferred_baits.is_empty():
			problems.append("Fisch %s hat preferred_bait_mult <= 0" % f.id)
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
