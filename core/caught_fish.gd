## Ein konkret gefangenes Exemplar. Bewusst nicht als Resource, sondern als
## leichte Instanz — davon liegen hunderte im Inventar und im Spielstand.
##
## Gespeichert wird die Abweichung vom Artmittel, nicht das Gewicht: dann
## bleiben Rekorde vergleichbar, auch wenn eine Art spaeter neu gewichtet
## wird, und "wie aussergewoehnlich war der Fang" ist direkt ablesbar.
class_name CaughtFish
extends RefCounted

var fish_id: StringName = &""
var weight_dev: float = 0.0
var rank: int = 0
var is_shiny: bool = false
var is_favorite: bool = false

static func make(id: StringName, dev: float, shiny: bool = false) -> CaughtFish:
	var c := CaughtFish.new()
	c.fish_id = id
	c.weight_dev = dev
	c.rank = FishRoll.rank_for_deviation(dev)
	c.is_shiny = shiny
	return c

func weight_of(fish: FishData) -> float:
	return fish.weight_at(weight_dev) if fish != null else 0.0

func to_dict() -> Dictionary:
	return {
		"fish_id": String(fish_id),
		"weight_dev": weight_dev,
		"is_shiny": is_shiny,
		"is_favorite": is_favorite,
	}

## Der Rang wird nicht gespeichert, sondern aus der Abweichung abgeleitet --
## zwei gespeicherte Zahlen fuer dieselbe Sache koennen auseinanderlaufen.
static func from_dict(d: Dictionary) -> CaughtFish:
	var c := CaughtFish.make(
		StringName(d.get("fish_id", "")),
		float(d.get("weight_dev", 0.0)),
		bool(d.get("is_shiny", false)))
	c.is_favorite = bool(d.get("is_favorite", false))
	return c
