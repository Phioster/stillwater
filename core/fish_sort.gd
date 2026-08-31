## Wie das Inventar sortiert wird. Eigene Datei, weil Kiste und Vitrine
## dieselbe Reihenfolge anbieten sollen — zwei Kopien liefen auseinander.
##
## Sortiert werden INDIZES ins Inventar, nicht die Fänge selbst: die Zeilen
## und der Verkauf sprechen das Inventar über den Index an, und eine
## umsortierte Liste würde auf den falschen Fisch zeigen.
class_name FishSort
extends RefCounted

const MODES := [&"fang", &"rang", &"gewicht", &"wert", &"art", &"seltenheit"]
const LABELS := {
	&"fang": "Fang",
	&"rang": "Rang",
	&"gewicht": "Gewicht",
	&"wert": "Wert",
	&"art": "Art",
	&"seltenheit": "Selten",
}

static func is_mode(id: StringName) -> bool:
	return MODES.has(id)

## Absteigend, wo „mehr" das Bessere ist — der beste Fang steht oben, weil
## man ihn dort sucht. „Fang" bleibt die Reihenfolge des Fangens.
static func sorted(indices: Array[int], mode: StringName) -> Array[int]:
	var out := indices.duplicate()
	match mode:
		&"rang":
			out.sort_custom(func(a, b): return _key_rank(a) > _key_rank(b))
		&"gewicht":
			out.sort_custom(func(a, b): return _key_weight(a) > _key_weight(b))
		&"wert":
			out.sort_custom(func(a, b): return _key_value(a) > _key_value(b))
		&"art":
			out.sort_custom(func(a, b): return _key_name(a) < _key_name(b))
		&"seltenheit":
			out.sort_custom(func(a, b): return _key_rarity(a) > _key_rarity(b))
	return out

static func _at(index: int) -> CaughtFish:
	return Game.ctx.inventory.fish[index]

static func _data(index: int) -> FishData:
	return Database.fish.get(_at(index).fish_id)

## Gleicher Rang, gleicher Fisch: dann entscheidet das Gewicht. Ohne den
## zweiten Schlüssel stünde die Liste bei jedem Neuaufbau anders da.
static func _key_rank(index: int) -> float:
	return float(_at(index).rank) * 1000.0 + _at(index).weight_dev

static func _key_weight(index: int) -> float:
	var f := _data(index)
	return _at(index).weight_of(f) if f != null else 0.0

static func _key_value(index: int) -> float:
	var f := _data(index)
	if f == null:
		return 0.0
	return float(Economy.sell_price(_at(index), f, Game.ctx.rarity_of(f),
		Game.ctx.consumable_bonus))

static func _key_name(index: int) -> String:
	var f := _data(index)
	return (f.display_name if f != null else String(_at(index).fish_id)) \
		+ "%08.3f" % (100.0 - _at(index).weight_dev)

static func _key_rarity(index: int) -> float:
	var f := _data(index)
	if f == null:
		return 0.0
	return Game.ctx.rarity_of(f).value_mult * 1000.0 + _at(index).weight_dev
