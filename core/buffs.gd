## Die laufenden Tränke.
##
## Die Restzeit läuft NUR, während das Spiel offen ist: ein Trank ist etwas,
## das man trinkt und dabei zusieht. Im Offline-Nachlauf zwölf Stunden lang
## abzulaufen wäre für den Spieler nur ärgerlich — er hätte nichts davon
## gehabt.
class_name Buffs
extends RefCounted

## id -> Restzeit in Sekunden.
var active: Dictionary = {}

func _data(id: StringName) -> ConsumableData:
	return Database.consumables.get(id)

## Trinken. Ein Trank derselben Gruppe wird ersetzt, nicht gestapelt.
func apply(c: ConsumableData) -> void:
	if c == null:
		return
	if c.group != &"":
		for other in active.keys():
			var o := _data(other)
			if o != null and o.group == c.group:
				active.erase(other)
	active[c.id] = c.duration

func tick(delta: float) -> void:
	for id in active.keys():
		var left: float = float(active[id]) - delta
		if left <= 0.0:
			active.erase(id)
		else:
			active[id] = left

func remaining(id: StringName) -> float:
	return float(active.get(id, 0.0))

func is_active(id: StringName) -> bool:
	return active.has(id)

## Produkt aller laufenden Faktoren für eine Eigenschaft.
func product(property: StringName) -> float:
	var f := 1.0
	for id in active:
		var c := _data(id)
		if c != null:
			f *= float(c.get(property))
	return f

func rank_shift() -> int:
	var n := 0
	for id in active:
		var c := _data(id)
		if c != null:
			n += c.rank_shift
	return n

func flag(property: StringName) -> bool:
	for id in active:
		var c := _data(id)
		if c != null and bool(c.get(property)):
			return true
	return false

## Faktoren auf die Raritätsgewichte, über alle laufenden Tränke multipliziert.
func rarity_bonus() -> Dictionary:
	var out: Dictionary = {}
	for id in active:
		var c := _data(id)
		if c == null:
			continue
		for rarity in c.rarity_weight_bonus:
			out[rarity] = float(out.get(rarity, 1.0)) * float(c.rarity_weight_bonus[rarity])
	return out

func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id in active:
		out[String(id)] = float(active[id])
	return out

func load_dict(d: Dictionary) -> void:
	active.clear()
	for key in d:
		var left := float(d[key])
		if left > 0.0 and Database.consumables.has(StringName(key)):
			active[StringName(key)] = left
