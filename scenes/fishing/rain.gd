## Der Regen über dem Wasser. Selbst gezeichnet statt als Partikelsystem:
## ein paar hundert kurze Striche kosten nichts, und der Fall ist eine
## Modulo-Rechnung ohne Zustand — es gibt also nichts, was auseinanderlaufen
## könnte, wenn das Spiel pausiert.
class_name Rain
extends Control

const DROPS: int = 90
const SPEED: float = 620.0
const LENGTH: float = 22.0
const SLANT: float = 0.18

var _time: float = 0.0
var _seeds: PackedFloat32Array = PackedFloat32Array()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 8817
	_seeds.resize(DROPS * 2)
	for i in _seeds.size():
		_seeds[i] = rng.randf()

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	var c := Palette.get_color(&"foam")
	c.a = 0.35
	var h := maxf(size.y, 1.0)
	for i in DROPS:
		var x := _seeds[i * 2] * size.x
		# Jeder Tropfen hat sein eigenes Tempo, sonst fällt der Regen im Gleichschritt.
		var speed := SPEED * (0.7 + 0.6 * _seeds[i * 2 + 1])
		var y := fmod(_seeds[i * 2 + 1] * h + _time * speed, h + LENGTH) - LENGTH
		draw_line(Vector2(x, y), Vector2(x - LENGTH * SLANT, y + LENGTH), c, 2.0)
