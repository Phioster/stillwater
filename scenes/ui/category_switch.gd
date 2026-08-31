## Die Reihe kleiner Umschaltknöpfe über einer langen Liste — im Journal für
## die Zonen, im Beutel für die Trankarten.
##
## Eine Stelle statt zweier Kopien: sonst laufen die beiden Listen im Gefühl
## auseinander, sobald an einer etwas geändert wird.
class_name CategorySwitch
extends RefCounted

## Mehr als drei nebeneinander werden auf einem Handy zu schmal zum Lesen.
const COLUMNS: int = 3
const HEIGHT: float = 72.0

## keys und labels laufen parallel; on_pick bekommt den gewählten Schlüssel.
static func build(keys: Array, labels: Array, current: Variant, on_pick: Callable) -> Control:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	for i in keys.size():
		var key: Variant = keys[i]
		var b := TapButton.new()
		b.text = str(labels[i])
		b.custom_minimum_size = Vector2(0, HEIGHT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		# Der aktive Knopf bleibt gedrückt und nimmt keine Tipps mehr an --
		# ein zweiter Tipp darauf würde die Liste nur neu bauen.
		b.button_pressed = key == current
		b.disabled = key == current
		b.tapped.connect(func() -> void: on_pick.call(key))
		grid.add_child(b)
	return grid
