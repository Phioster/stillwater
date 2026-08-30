## Die senkrechte Leiste ganz rechts. Im Querformat liegt dort der rechte
## Daumen. Jeder Knopf ist mindestens 96 px hoch, also gut 48 dp.
class_name TabRail
extends PanelContainer

signal tab_selected(index: int)

const TABS: Array[String] = ["Fische", "Vitrine", "Journal", "Laden", "Ausbau", "Welt", "Figur", "Geheim"]
## Dieser Reiter bleibt unsichtbar, bis der erste Geheimfisch an Land ist.
## Versteckt statt entfernt, damit Reiter- und Panel-Index gleich bleiben.
const SECRET_TAB: int = 7
## Wunschhoehe eines Knopfes. Passen nicht alle sichtbaren Reiter nebeneinander
## in die Leiste, wird gleichmaessig gekuerzt statt unten abgeschnitten.
const BUTTON_HEIGHT: float = 96.0
const MIN_BUTTON_HEIGHT: float = 64.0

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
	if not Game.state_changed.is_connected(_update_secret_tab):
		Game.state_changed.connect(_update_secret_tab)
	_update_secret_tab()
	if not resized.is_connected(_fit_buttons):
		resized.connect(_fit_buttons)

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
	_fit_buttons()

## Die Leiste darf nie ueber den Bildrand hinauslaufen -- ein Reiter, den man
## nicht erreicht, ist schlimmer als ein etwas flacherer.
func _fit_buttons() -> void:
	var visible_count := 0
	for b in _buttons:
		if b.visible:
			visible_count += 1
	if visible_count == 0:
		return
	var box: VBoxContainer = $Box
	var gaps := float(visible_count - 1) * float(box.get_theme_constant(&"separation"))
	var room := (size.y - gaps) / float(visible_count)
	var h := clampf(room, MIN_BUTTON_HEIGHT, BUTTON_HEIGHT)
	for b in _buttons:
		b.custom_minimum_size = Vector2(0, h)

## Ein zweiter Aufruf mit demselben Index klappt das Panel wieder zu.
func select(index: int) -> void:
	_active = -1 if _active == index else index
	for i in _buttons.size():
		_buttons[i].button_pressed = (i == _active)
	tab_selected.emit(_active)

func _on_pressed(index: int) -> void:
	select(index)
