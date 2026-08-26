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
