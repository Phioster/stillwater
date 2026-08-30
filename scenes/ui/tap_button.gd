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
## Ein Knopf, der beim Drücken kurz einfedert, fühlt sich an wie ein Knopf.
var _scale := Spring.new(1.0, 320.0, 22.0)
var _shake: Shake = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	pressed.connect(_on_pressed)
	button_down.connect(func() -> void: _scale.nudge(-3.5))

## Eine abgelehnte Aktion muss man sehen. Wackeln statt stillschweigend
## nichts zu tun -- ein Knopf, der nicht reagiert, wirkt kaputt.
func refuse() -> void:
	_shake = Shake.new(7.0, 0.28, 26.0)

func _process(delta: float) -> void:
	pivot_offset = size * 0.5
	_scale.update(delta)
	scale = Vector2(_scale.value, _scale.value)
	if _shake != null:
		_shake.update(delta)
		position.x = _rest_x + _shake.amplitude()
		if not _shake.alive():
			position.x = _rest_x
			_shake = null
	else:
		_rest_x = position.x

var _rest_x: float = 0.0

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
