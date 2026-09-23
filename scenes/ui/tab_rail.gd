## Die senkrechte Leiste ganz rechts. Im Querformat liegt dort der rechte
## Daumen. Die Knöpfe teilen sich die vorhandene Höhe gleichmäßig.
class_name TabRail
extends PanelContainer

signal tab_selected(index: int)

## Jeder Reiter hat EINE Aufgabe, wie bei Cornerpond: Laden kauft,
## Ausruestung benutzt, was man hat. Die Unterteilung uebernimmt TabGroup.
const TABS: Array[String] = ["Fische", "Ausrüstung", "Laden", "Journal",
	"Aufträge", "Orte", "Optionen"]
## Was nicht in die 140 breite Leiste passt, bricht auf dem Knopf um.
const ANZEIGE := {"Ausrüstung": "Aus-\nrüstung"}

static func anzeige(reiter: String) -> String:
	return ANZEIGE.get(reiter, reiter)
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
var _punkt: ColorRect = null

const QUEST_TAB := 4
const PLACES_TAB := 5

func _ready() -> void:
	for i in TABS.size():
		var b := TapButton.new()
		b.text = anzeige(TABS[i])
		b.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.tapped.connect(_on_pressed.bind(i))
		$Box.add_child(b)
		_buttons.append(b)
	# Cornerpond setzt einen Punkt an den Auftraege-Knopf, sobald etwas fertig
	# ist -- sonst muss man nachsehen, um zu erfahren, dass es nichts gibt.
	_punkt = ColorRect.new()
	_punkt.color = Palette.get_color(&"accent")
	_punkt.size = Vector2(12, 12)
	_punkt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons[QUEST_TAB].add_child(_punkt)
	_punkt.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_punkt.position = Vector2(-18, 6)
	if not Game.state_changed.is_connected(refresh_hints):
		Game.state_changed.connect(refresh_hints)
	refresh_hints()

func refresh_hints() -> void:
	if _buttons.size() <= PLACES_TAB:
		return
	_punkt.visible = Game.quest_ready()
	# Nur Regen ueber einem erreichbaren Ort -- wie in der Ortsliste.
	var nass := Game.rain_zone() in Game.unlocked_zones
	_buttons[PLACES_TAB].text = anzeige(TABS[PLACES_TAB]) + ("  ☂" if nass else "")

func punkt_sichtbar() -> bool:
	return _punkt != null and _punkt.visible

## Ein zweiter Aufruf mit demselben Index klappt das Panel wieder zu.
func select(index: int) -> void:
	_active = -1 if _active == index else index
	for i in _buttons.size():
		_buttons[i].button_pressed = (i == _active)
	tab_selected.emit(_active)

func _on_pressed(index: int) -> void:
	select(index)
