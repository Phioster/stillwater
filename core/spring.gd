## Ein gedämpfter Federschwinger. Trägt fast das gesamte „Gefühl" einer
## Oberfläche: ein Knopf, der beim Drücken kurz einfedert, fühlt sich an wie
## ein Knopf. Einer, der nur die Farbe wechselt, nicht.
class_name Spring
extends RefCounted

## Ein Ruckler darf die Feder nicht sprengen. Ohne diesen Deckel schaukelt
## sie sich bei einem langen Bild auf, statt zu schwingen.
const MAX_STEP: float = 0.02
## Näher als das gilt als angekommen — sonst ruht die Feder nie ganz.
const REST: float = 0.0001

var value: float
var target: float
var velocity: float = 0.0
var stiffness: float
var damping: float
var resting: bool = false

func _init(start: float, _stiffness: float = 250.0, _damping: float = 18.0) -> void:
	value = start
	target = start
	stiffness = _stiffness
	damping = _damping

## Stößt die Feder an, statt sie zu setzen: das ist der Griff für „reagiere".
func nudge(force: float) -> void:
	velocity += force
	resting = false

func move_to(v: float) -> void:
	target = v
	resting = false

func update(delta: float) -> void:
	if resting:
		return
	var step := minf(delta, MAX_STEP)
	var acceleration := -stiffness * (value - target) - damping * velocity
	velocity += acceleration * step
	value += velocity * step
	if absf(acceleration) <= REST and absf(velocity) <= REST:
		value = target
		velocity = 0.0
		resting = true
