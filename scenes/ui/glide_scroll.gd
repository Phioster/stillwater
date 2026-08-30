## Gibt einem ScrollContainer Nachschwung: beim Loslassen rollt die Liste
## weiter aus, statt abrupt stehenzubleiben.
##
## Godots ScrollContainer kann das nicht — die Referenz brauchte dafür ein
## eigenes Addon. Unser Weg ist kleiner: die Geschwindigkeit wird aus dem
## Zug gemessen, beim Loslassen läuft sie mit Reibung aus, und an den Enden
## wird sie sofort verworfen.
class_name GlideScroll
extends RefCounted

## Bremse je Sekunde. Kleiner = längeres Ausrollen.
const FRICTION: float = 6.0
## Darunter lohnt das Nachrollen nicht mehr.
const STOP: float = 8.0
## Schneller als das wird nicht geworfen — sonst schießt eine hastige Geste
## quer durch die ganze Liste.
const MAX_SPEED: float = 4000.0

var _target: ScrollContainer
var _velocity: float = 0.0
var _dragging: bool = false
var _last_y: float = 0.0
var _last_scroll: int = 0

func _init(target: ScrollContainer) -> void:
	_target = target

func on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		if pressed:
			_dragging = true
			_velocity = 0.0
			_last_y = event.position.y
			_last_scroll = _target.scroll_vertical
		else:
			_dragging = false
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_last_y = event.position.y

## Muss jedes Bild aufgerufen werden. Misst während des Ziehens die
## Geschwindigkeit und lässt sie danach auslaufen.
func update(delta: float) -> void:
	if delta <= 0.0 or _target == null:
		return
	var now := _target.scroll_vertical
	if _dragging:
		# Aus der tatsächlichen Bewegung der Liste gemessen, nicht aus dem
		# Finger: dann stimmt sie auch, wenn der Container am Ende bremst.
		_velocity = clampf(float(now - _last_scroll) / delta, -MAX_SPEED, MAX_SPEED)
		_last_scroll = now
		return
	if absf(_velocity) < STOP:
		_velocity = 0.0
		return
	var before := now
	_target.scroll_vertical = int(round(float(now) + _velocity * delta))
	if _target.scroll_vertical == before:
		# Am Ende angekommen: den Rest verwerfen, statt stumm weiterzurechnen.
		_velocity = 0.0
		return
	_velocity -= _velocity * clampf(FRICTION * delta, 0.0, 1.0)
