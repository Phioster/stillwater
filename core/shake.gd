## Eine Erschütterung. Das Rauschen wird VORAB gezogen und dazwischen linear
## überblendet — nicht pro Bild gewürfelt. Sonst sieht es nach Bildfehler aus
## statt nach Erschütterung, und die Stärke hängt an der Bildrate.
class_name Shake
extends RefCounted

var magnitude: float
var duration: float
var frequency: float
var elapsed: float = 0.0

var _samples: PackedFloat32Array = PackedFloat32Array()

func _init(_magnitude: float, _duration: float, _frequency: float = 20.0) -> void:
	magnitude = _magnitude
	duration = maxf(_duration, 0.0001)
	frequency = maxf(_frequency, 1.0)
	_samples.resize(int(ceil(duration * frequency)) + 2)
	for i in _samples.size():
		_samples[i] = randf() * 2.0 - 1.0

func alive() -> bool:
	return elapsed < duration

func update(delta: float) -> void:
	elapsed += delta

## Der Ausschlag zum jetzigen Zeitpunkt, linear abklingend.
func amplitude() -> float:
	if not alive():
		return 0.0
	var s := elapsed * frequency
	var i := int(floor(s))
	var t := s - float(i)
	var a := _sample(i)
	var b := _sample(i + 1)
	var decay := (duration - elapsed) / duration
	return magnitude * lerpf(a, b, t) * decay

func _sample(i: int) -> float:
	return _samples[i] if i >= 0 and i < _samples.size() else 0.0
