## Regen. Zieht über die Gewässer und macht das Angeln besser, nie schlechter
## — ein Wetter, das bestraft, treibt den Spieler nur weg.
##
## Wie Besucher und Aufträge aus der Uhr abgeleitet: ob es in einer Zone
## regnet, hängt allein an Stunde und Zone. Damit gibt es keinen Zustand, der
## driften könnte, und wer das Spiel schließt, findet dasselbe Wetter vor.
class_name Weather
extends RefCounted

const INTERVAL: float = 3600.0
## Wie oft es in einer bestimmten Zone regnet.
const CHANCE: float = 0.28
## Bei Regen beißt es schneller und der Kampf dauert länger.
const BITE_FACTOR: float = 0.6
const FIGHT_FACTOR: float = 1.33

static func slot_at(now: float) -> int:
	return int(floor(now / INTERVAL))

static func is_raining(now: float, zone_id: StringName) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("regen:%d:%s" % [slot_at(now), zone_id])
	return rng.randf() < CHANCE

## Wie lange es in dieser Zone noch schüttet, in Sekunden.
static func minutes_left(now: float, zone_id: StringName) -> float:
	if not is_raining(now, zone_id):
		return 0.0
	return INTERVAL - fmod(now, INTERVAL)
