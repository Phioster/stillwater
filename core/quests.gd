## Aufträge: gib einen bestimmten Fisch ab, bekomme Geld und Erfahrung.
##
## Wie die Besucher aus der Uhr abgeleitet, nicht heruntergezählt: derselbe
## Drei-Stunden-Block gibt immer dieselben Aufträge, auch nach einem
## Neustart, und nichts läuft ab, während man weg ist.
##
## Verlangt werden nur Arten aus Zonen, die man erreichen kann — ein Auftrag
## für einen Fisch, an den man nicht herankommt, wäre kein Auftrag, sondern
## eine Sperre.
class_name Quests
extends RefCounted

const INTERVAL: float = 10800.0
## Der Lohn ist ein Vielfaches dessen, was der Fisch beim Verkauf brächte --
## abgeben muss sich lohnen, sonst verkauft man ihn einfach.
const MONEY_FACTOR: float = 2.5
const XP_FACTOR: float = 3.0

var slot: int = -1
## Welche der Aufträge dieses Blocks schon erfüllt sind.
var done: Array[StringName] = []

static func slot_at(now: float) -> int:
	return int(floor(now / INTERVAL))

func refresh(now: float) -> bool:
	var s := slot_at(now)
	if s == slot:
		return false
	slot = s
	done = []
	return true

## Die Aufträge dieses Blocks. Aus dem Zeitfenster gesät.
func offer(now: float, count: int, reachable: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	if count <= 0 or reachable.is_empty():
		return out
	var pool := reachable.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("auftrag:%d" % slot_at(now))
	while out.size() < count and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out

func is_done(id: StringName) -> bool:
	return done.has(id)

func complete(id: StringName) -> void:
	if not done.has(id):
		done.append(id)

func to_dict() -> Dictionary:
	var d: Array = []
	for id in done:
		d.append(String(id))
	return {"slot": slot, "done": d}

func load_dict(d: Dictionary) -> void:
	slot = int(d.get("slot", -1))
	done = []
	for id in d.get("done", []):
		done.append(StringName(id))
