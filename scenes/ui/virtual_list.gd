## Eine Liste, die nur baut, was man sieht.
##
## Gemessen: 395 Inventarzeilen sind 1.583 Knoten, und die kosten 394 ms —
## nicht beim Erzeugen (41 ms) und nicht beim Einsortieren (2 ms), sondern
## beim EINTRITT IN DEN BAUM. Bündeln hilft deshalb nichts; der Preis fällt
## pro Knoten an. Also hängen wir nur die ein, die gerade im Fenster stehen.
##
## Bedingung: alle Zeilen sind gleich hoch. Damit lässt sich aus der
## Scrollposition ausrechnen, welche sichtbar sind — ohne sie zu bauen.
class_name VirtualList
extends Control

## Wie viele Zeilen über und unter dem Fenster zusätzlich gebaut werden,
## damit beim Wischen nichts leer aufblitzt.
const OVERSCAN: int = 3

var _count: int = 0
var _row_height: float = 96.0
var _build: Callable = Callable()
var _first: int = -1
var _last: int = -1
var _scroll: ScrollContainer = null

## `build` bekommt den Index und gibt die fertige Zeile zurück.
func setup(count: int, row_height: float, build: Callable) -> void:
	_count = maxi(count, 0)
	_row_height = maxf(row_height, 1.0)
	_build = build
	_first = -1
	_last = -1
	for c in get_children():
		remove_child(c)
		c.queue_free()
	# Die volle Höhe steht auch ohne Inhalt: sonst wüsste der Scrollbalken
	# nicht, wie weit es geht.
	custom_minimum_size = Vector2(0, float(_count) * _row_height)
	_refresh_window()

func _ready() -> void:
	_scroll = _find_scroll()

func _process(_delta: float) -> void:
	_refresh_window()

## Beim ersten Aufbau steht die Groesse des Scrollbereichs oft noch nicht --
## dann waere das Fenster zu klein. Nach jedem Layout neu rechnen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_first = -1
		_last = -1

func _find_scroll() -> ScrollContainer:
	var n: Node = get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null

## Sichtbarer Bereich in Zeilenindizes, aus der Scrollposition gerechnet.
func window() -> Vector2i:
	if _count == 0:
		return Vector2i(0, -1)
	if _scroll == null:
		_scroll = _find_scroll()
	var top := 0.0
	var height := 1200.0
	if _scroll != null:
		# position.y ist der Versatz dieser Liste im Scrollinhalt: darüber
		# stehen Kopfzeile und Knöpfe, die nicht mitgezählt werden dürfen.
		top = float(_scroll.scroll_vertical) - position.y
		height = _scroll.size.y
	var first := int(floor(top / _row_height)) - OVERSCAN
	var last := int(ceil((top + height) / _row_height)) + OVERSCAN
	return Vector2i(clampi(first, 0, _count - 1), clampi(last, 0, _count - 1))

func _refresh_window() -> void:
	if _count == 0 or not _build.is_valid():
		return
	var w := window()
	if w.x == _first and w.y == _last:
		return
	_first = w.x
	_last = w.y
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for i in range(_first, _last + 1):
		var row: Control = _build.call(i)
		if row == null:
			continue
		add_child(row)
		# Oben verankert und ueber die volle Breite: dann folgt die Zeile der
		# Breite der Liste von selbst. Mit fester Groesse waere sie null Pixel
		# breit, solange das Layout beim Bauen noch nicht gelaufen ist.
		row.set_anchors_preset(Control.PRESET_TOP_WIDE, true)
		row.offset_left = 0.0
		row.offset_right = 0.0
		row.offset_top = float(i) * _row_height
		row.offset_bottom = row.offset_top + _row_height

## Wie viele Zeilen gerade wirklich im Baum stehen.
func live_rows() -> int:
	return get_child_count()
