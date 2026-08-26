class_name StillRNG
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

func get_state() -> int:
	return int(_rng.state)

func set_state(s: int) -> void:
	_rng.state = s

func randf() -> float:
	return _rng.randf()

func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)

func randfn(mean: float, deviation: float) -> float:
	return _rng.randfn(mean, deviation)

## Zieht einen Index proportional zu den Gewichten.
## Gibt -1 zurück, wenn die Summe aller Gewichte 0 oder kleiner ist.
func weighted_pick(weights: PackedFloat64Array) -> int:
	var total := 0.0
	for w in weights:
		if w > 0.0:
			total += w
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		if weights[i] <= 0.0:
			continue
		acc += weights[i]
		if roll < acc:
			return i
	return weights.size() - 1
