## Die senkrechte Leiste ganz rechts. Im Querformat liegt dort der rechte
## Daumen. Die Knöpfe teilen sich die vorhandene Höhe gleichmäßig.
class_name TabRail
extends PanelContainer

signal tab_selected(index: int)

## Fuenf statt neun. Verwandtes steht zusammen: was man kauft, im Laden;
## was mit gefangenen Fischen zu tun hat, bei den Fischen. Die Unterteilung
## uebernimmt TabGroup.
const TABS: Array[String] = ["Fische", "Journal", "Laden", "Welt", "Optionen"]
## Untergrenze eines Knopfes -- bewusst KLEIN. Die Mindesthöhen summieren
## sich zur Mindesthöhe der Leiste, und ein Control kann nicht kleiner werden
## als die. Mit 96 hier wäre die Leiste bei neun Reitern 810 px hoch geworden
## und unten aus dem Bild gelaufen; die Rechnerei, die genau das verhindern
## sollte, konnte gar nicht greifen, weil sie das Problem selbst erzeugte.
##
## Verteilt wird stattdessen vom VBoxContainer: jeder Knopf dehnt sich, also
## teilen sie sich den vorhandenen Platz von selbst und gleichmäßig.
const MIN_BUTTON_HEIGHT: float = 40.0

var _buttons: Array[TapButton] = []
var _active: int = -1

func _ready() -> void:
	for i in TABS.size():
		var b := TapButton.new()
		b.text = TABS[i]
		b.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.tapped.connect(_on_pressed.bind(i))
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
