## Regen. Zieht über EIN Gewässer und macht das Angeln dort besser, nie
## schlechter — ein Wetter, das bestraft, treibt den Spieler nur weg.
##
## Wie Besucher und Aufträge aus der Uhr abgeleitet: es gibt keinen Zustand,
## der driften könnte, und wer das Spiel schließt, findet dasselbe Wetter vor.
##
## Zwei Regeln machen aus dem Regen ein Ereignis statt eines Dauerzustands:
## er fällt immer nur in einer einzigen Zone, und je Block von BLOCK Stunden
## höchstens einmal. Der Rest des Blocks ist die Abklingzeit — vorher würfelte
## jede Zone für sich, dann regnete es irgendwo praktisch immer.
class_name Weather
extends RefCounted

## Ein Regen dauert eine Stunde.
const INTERVAL: float = 3600.0
## Stunden je Block. Höchstens eine davon ist nass, der Rest ist Abklingzeit.
const BLOCK: int = 6
## Die letzten Stunden eines Blocks bleiben immer trocken. Ohne das könnte
## ein Block in seiner letzten Stunde regnen und der nächste gleich in seiner
## ersten -- zwei Regenstunden am Stück, also gar keine Abklingzeit.
const DRY_TAIL: int = 2
## Wie oft ein Block überhaupt Regen bringt.
const CHANCE: float = 0.6
## Bei Regen beißt es schneller und der Kampf dauert länger.
const BITE_FACTOR: float = 0.6
const FIGHT_FACTOR: float = 1.33

static func slot_at(now: float) -> int:
	return int(floor(now / INTERVAL))

## Über welcher Zone es gerade regnet — &"" heißt: nirgends.
static func rain_zone(now: float) -> StringName:
	var s := slot_at(now)
	var block := int(floor(float(s) / float(BLOCK)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("regen:%d" % block)
	if rng.randf() >= CHANCE:
		return &""
	if block * BLOCK + rng.randi_range(0, BLOCK - DRY_TAIL - 1) != s:
		return &""
	var zones := Database.zones_in_order()
	if zones.is_empty():
		return &""
	return zones[rng.randi_range(0, zones.size() - 1)].id

static func is_raining(now: float, zone_id: StringName) -> bool:
	return zone_id != &"" and rain_zone(now) == zone_id

## Wie lange es in dieser Zone noch schüttet, in Sekunden.
static func minutes_left(now: float, zone_id: StringName) -> float:
	if not is_raining(now, zone_id):
		return 0.0
	return INTERVAL - fmod(now, INTERVAL)
