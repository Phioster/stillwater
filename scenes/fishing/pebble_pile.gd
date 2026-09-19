## Der Kieselhaufen am Ufer. Antippbar, sonst stumm -- wie der Schilfhorst
## (scenes/fishing/reed_patch.gd), nur ohne Windstellungen: Steine bewegen
## sich nicht.
class_name PebblePile
extends Control

signal tapped

var _bild: Texture2D
var _skala := 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setze(bild: Texture2D, skala: float) -> void:
	_bild = bild
	_skala = skala
	if _bild != null:
		size = Vector2(_bild.get_width(), _bild.get_height()) * skala
	queue_redraw()

func _draw() -> void:
	if _bild == null:
		return
	draw_texture_rect(_bild, Rect2(Vector2.ZERO, size), false)

func _gui_input(event: InputEvent) -> void:
	var tipp := event is InputEventScreenTouch \
		and (event as InputEventScreenTouch).pressed
	var klick := event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed
	if tipp or klick:
		tapped.emit()
		accept_event()
