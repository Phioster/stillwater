## Lädt alle .tres beim Start und liefert sie per ID aus.
## Der einzige Ort im Projekt, der data/ kennt.
extends Node

var rarities: Dictionary = {}
var baits: Dictionary = {}
var fish: Dictionary = {}
var zones: Dictionary = {}
var upgrades: Dictionary = {}
var cosmetics: Dictionary = {}

const _FOLDERS := {
	"rarities": "res://data/rarities",
	"baits": "res://data/bait",
	"fish": "res://data/fish",
	"zones": "res://data/zones",
	"upgrades": "res://data/upgrades",
	"cosmetics": "res://data/cosmetics",
}

## Kategorien mit einem eigenen Sprite pro Variante -- "hair_color" faerbt das
## Haar per Shader (angler.gd) statt eine eigene Textur zu laden.
const _COSMETIC_SPRITE_PREFIX := {
	"skin": "char_skin",
	"hair": "char_hair",
	"shirt": "char_shirt",
	"pants": "char_pants",
	"hat": "char_hat",
}

func _ready() -> void:
	load_all()

func load_all() -> void:
	rarities = _load_folder(_FOLDERS["rarities"])
	baits = _load_folder(_FOLDERS["baits"])
	fish = _load_folder(_FOLDERS["fish"])
	zones = _load_folder(_FOLDERS["zones"])
	upgrades = _load_folder(_FOLDERS["upgrades"])
	cosmetics = _load_folder(_FOLDERS["cosmetics"])
	# Kaputte Verweise sollen beim Start auffallen, nicht erst beim ersten Biss -
	# aber ein Datenfehler soll das Spiel nicht am Starten hindern.
	for problem in validate():
		push_error("Dateninhalt: %s" % problem)

func _load_folder(path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Datenordner fehlt: %s" % path)
		return out
	for file in dir.get_files():
		var name := resource_name_of(file)
		if name == "":
			continue
		var res: Resource = load(path.path_join(name))
		if res == null or not ("id" in res):
			push_error("unbrauchbare Datendatei: %s" % file)
			continue
		out[res.id] = res
	return out

## Im Quellbaum heissen die Daten "x.tres", in der exportierten APK legt Godot
## Umleitungsdateien "x.tres.remap" an. Beide muessen zum selben Ergebnis
## fuehren, sonst laedt im Export keine einzige Datei.
static func resource_name_of(file: String) -> String:
	var name := file
	if name.ends_with(".remap"):
		name = name.trim_suffix(".remap")
	return name if name.ends_with(".tres") else ""

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

func cosmetic_of(category: StringName, variant: int) -> CosmeticData:
	for id in cosmetics:
		var c: CosmeticData = cosmetics[id]
		if c.category == category and c.variant == variant:
			return c
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

	var combos_seen: Dictionary = {}
	var categories_seen: Dictionary = {}
	for id in cosmetics:
		var c: CosmeticData = cosmetics[id]
		categories_seen[c.category] = true
		var combo := "%s:%d" % [c.category, c.variant]
		if combos_seen.has(combo):
			problems.append("Kosmetik-Kombination %s doppelt vergeben (%s und %s)" % [combo, combos_seen[combo], c.id])
		else:
			combos_seen[combo] = c.id
		if _COSMETIC_SPRITE_PREFIX.has(String(c.category)):
			var sprite_path := "res://assets/art/%s_%d.png" % [_COSMETIC_SPRITE_PREFIX[String(c.category)], c.variant]
			if not FileAccess.file_exists(sprite_path):
				problems.append("Kosmetik %s zeigt auf fehlendes Sprite %s" % [c.id, sprite_path])
	for category in categories_seen:
		var zero := cosmetic_of(category, 0)
		if zero == null:
			problems.append("Kategorie %s hat keine Variante 0" % category)
		elif zero.cost != 0 or zero.unlock_level > 1:
			problems.append("Variante 0 von %s muss kostenlos und ab Stufe 1 verfuegbar sein" % category)
	return problems
