## Ein aufsteigender, verblassender Kurztext. Raeumt sich nach seiner
## Lebenszeit selbst aus dem Baum -- niemand ausserhalb muss ihn aufraeumen.
extends Label

const LIFETIME: float = 1.1
const RISE: float = 46.0

var _age: float = 0.0
var _start_y: float = 0.0

func _ready() -> void:
	add_theme_color_override("font_outline_color", Palette.get_color(&"shadow"))
	add_theme_constant_override("outline_size", 6)
	add_theme_font_size_override("font_size", 26)

## pos ist der Mittelpunkt des Texts, nicht die obere linke Ecke --
## custom_minimum_size steht schon in der .tscn, damit hier keine
## Grössenabfrage vor dem ersten Layout-Durchlauf noetig ist.
func setup(txt: String, pos: Vector2, color: Color) -> void:
	text = txt
	modulate = color
	position = pos - custom_minimum_size * 0.5
	_start_y = position.y

func _process(delta: float) -> void:
	_age += delta
	position.y = _start_y - RISE * (_age / LIFETIME)
	modulate.a = clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
