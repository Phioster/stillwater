## Eine Leiste aus ZWEI übereinanderliegenden Balken.
##
## Der Witz ist das richtungsabhängige Verhalten: fällt der Wert, springt
## der vordere Balken sofort herunter und der hintere zieht langsam nach —
## man sieht genau den Streifen, der eben abging. Steigt er, springt der
## hintere vor und der vordere zieht nach. Ohne das ist ein Treffer nur
## eine Leiste, die kürzer wird.
class_name GhostBar
extends Control

## Wie schnell die nachziehende Hälfte aufholt.
const CATCH_UP: float = 6.0
## Näher als das gilt als angekommen. Ohne diese Schwelle nähert sich ein
## Lerp dem Ziel ewig, ohne es je zu erreichen.
const SNAP: float = 0.001

var _front: ProgressBar
var _ghost: ProgressBar
var _target: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost = _make_bar()
	_front = _make_bar()
	add_child(_ghost)
	add_child(_front)

func _make_bar() -> ProgressBar:
	var b := ProgressBar.new()
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.show_percentage = false
	# Ohne das rastet Godots Range auf Stufen ein und die Leiste kommt nie
	# genau an. Die Referenz setzt an derselben Stelle dieselbe Null.
	b.step = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.max_value = 1.0
	b.value = 0.0
	return b

## front_color trägt den Wert, ghost_color den nachziehenden Streifen.
func set_colors(front_color: Color, ghost_color: Color) -> void:
	_tint(_front, front_color)
	_tint(_ghost, ghost_color)

func _tint(bar: ProgressBar, c: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = c
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.get_color(&"shadow")
	bg.bg_color.a = 0.55
	bar.add_theme_stylebox_override("background", bg)

func set_max(v: float) -> void:
	var m := maxf(v, 0.0001)
	_front.max_value = m
	_ghost.max_value = m

func max_value() -> float:
	return _front.max_value

func value() -> float:
	return _target

## Ohne Nachziehen setzen — beim Beginn eines Kampfes soll nichts hinterherlaufen.
func reset_to(v: float) -> void:
	_target = v
	_front.value = v
	_ghost.value = v

func set_value(v: float) -> void:
	if v < _front.value:
		_front.value = v      # Verlust: vorn sofort, hinten zieht nach
	else:
		_ghost.value = v      # Gewinn: hinten sofort, vorn zieht nach
	_target = v

func _process(delta: float) -> void:
	_front.value = _approach(_front.value, _target, delta)
	_ghost.value = _approach(_ghost.value, _target, delta)

func _approach(from: float, to: float, delta: float) -> float:
	var v := lerpf(from, to, clampf(CATCH_UP * delta, 0.0, 1.0))
	return to if absf(to - v) <= SNAP else v
