## Ein Knopf, der in einer Scrollliste leben kann.
##
## Ein gewoehnlicher Button verschluckt die Wischgeste: der ScrollContainer
## bekommt sie nie zu sehen, und die Liste laesst sich nur in den Luecken
## zwischen den Knoepfen bewegen. MOUSE_FILTER_PASS reicht das Ereignis nach
## oben durch -- danach wuerde aber jedes Wischen auch den Knopf ausloesen,
## deshalb feuert `tapped` nur, wenn der Finger dabei kaum gewandert ist.
class_name TapButton
extends Button

signal tapped

## Weiter als das darf der Finger zwischen Aufsetzen und Loslassen nicht
## wandern, sonst war es ein Scrollen. Grosszuegiger als die Wischschwelle
## des ScrollContainers (8), damit kein Bereich dazwischenfaellt.
const DRAG_SLOP: float = 16.0

var _down_at: Vector2 = Vector2.INF

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	pressed.connect(_on_pressed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_down_at = (event as InputEventMouseButton).global_position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_down_at = (event as InputEventScreenTouch).global_position

## Ohne aufgezeichneten Startpunkt bleibt es beim alten Verhalten: lieber
## einmal zu viel ausloesen als einen Knopf, der gar nicht mehr reagiert.
func _on_pressed() -> void:
	var start := _down_at
	_down_at = Vector2.INF
	if start != Vector2.INF and get_global_mouse_position().distance_to(start) > DRAG_SLOP:
		return
	tapped.emit()
