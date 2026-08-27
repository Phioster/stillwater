## Die senkrechte Leiste ganz rechts. Im Querformat liegt dort der rechte
## Daumen. Jeder Knopf ist mindestens 96 px hoch, also gut 48 dp.
extends PanelContainer

signal tab_selected(index: int)

const TABS: Array[String] = ["Fische", "Journal", "Laden", "Ausbau", "Welt", "Figur"]
const BUTTON_HEIGHT: float = 96.0

var _buttons: Array[Button] = []
var _active: int = -1

func _ready() -> void:
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		b.toggle_mode = true
		b.pressed.connect(_on_pressed.bind(i))
		$Box.add_child(b)
		_buttons.append(b)

## Ein zweiter Aufruf mit demselben Index klappt das Panel wieder zu.
func select(index: int) -> void:
	_active = -1 if _active == index else index
	for i in _buttons.size():
		_buttons[i].button_pressed = (i == _active)
	tab_selected.emit(_active)

func _on_pressed(index: int) -> void:
	select(index)
