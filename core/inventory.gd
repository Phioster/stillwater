## Das Fischinventar. Die Kapazität ist die natürliche Bremse für
## Offline-Fortschritt: ist sie erreicht, pausiert das Angeln.
class_name Inventory
extends RefCounted

var capacity: int = 20
var fish: Array[CaughtFish] = []

func is_full() -> bool:
	return fish.size() >= capacity

func add(c: CaughtFish) -> bool:
	if is_full():
		return false
	fish.append(c)
	return true

func remove_at(i: int) -> CaughtFish:
	if i < 0 or i >= fish.size():
		return null
	var c := fish[i]
	fish.remove_at(i)
	return c

## Alles außer Favoriten.
func sellable() -> Array[CaughtFish]:
	var out: Array[CaughtFish] = []
	for c in fish:
		if not c.is_favorite:
			out.append(c)
	return out

## Entfernt alles Verkäufliche aus dem Inventar und gibt es zurück.
func take_sellable() -> Array[CaughtFish]:
	var sold := sellable()
	var kept: Array[CaughtFish] = []
	for c in fish:
		if c.is_favorite:
			kept.append(c)
	fish = kept
	return sold

func to_array() -> Array:
	var out := []
	for c in fish:
		out.append(c.to_dict())
	return out

func load_array(a: Array) -> void:
	fish.clear()
	for d in a:
		fish.append(CaughtFish.from_dict(d))
