## Die senkrechte Leiste ganz rechts. Im Querformat liegt dort der rechte
## Daumen. Die Knöpfe teilen sich die vorhandene Höhe gleichmäßig.
class_name TabRail
extends PanelContainer

signal tab_selected(index: int)

const TABS: Array[String] = ["Fische", "Vitrine", "Journal", "Laden", "Ausbau", "Welt", "Figur", "Optionen", "Geheim"]
## Dieser Reiter bleibt unsichtbar, bis der erste Geheimfisch an Land ist.
## Versteckt statt entfernt, damit Reiter- und Panel-Index gleich bleiben.
const SECRET_TAB: int = 8
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
	if not Game.state_changed.is_connected(_update_secret_tab):
		Game.state_changed.connect(_update_secret_tab)
	_update_secret_tab()

func _exit_tree() -> void:
	if Game.state_changed.is_connected(_update_secret_tab):
		Game.state_changed.disconnect(_update_secret_tab)

## Vor dem ersten Fang soll das Spiel nicht einmal andeuten, dass es
## Geheimfische gibt -- kein Reiter, keine Hinweiszeile, nichts.
func _update_secret_tab() -> void:
	var known := Game.ctx != null and Game.ctx.journal.has_any_secret()
	_buttons[SECRET_TAB].visible = known
	if not known and _active == SECRET_TAB:
		select(SECRET_TAB)

## Ein zweiter Aufruf mit demselben Index klappt das Panel wieder zu.
func select(index: int) -> void:
	_active = -1 if _active == index else index
	for i in _buttons.size():
		_buttons[i].button_pressed = (i == _active)
	tab_selected.emit(_active)

func _on_pressed(index: int) -> void:
	select(index)
