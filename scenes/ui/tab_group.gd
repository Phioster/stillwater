## Ein Hauptreiter, der mehrere Unterreiter zusammenfasst.
##
## Neun Reiter nebeneinander waren zu viele, und die Zuordnung war schief:
## Kosmetik gehört zu dem, was man kauft, Geheimfische zu den Fischen. Die
## Gruppe hält beides zusammen — die Leiste rechts trägt jetzt fünf Einträge
## statt neun, und verwandte Dinge stehen beieinander.
##
## Jedes Kind, das ein ScrollContainer ist, ist ein Unterreiter. Bei nur
## einem wird keine Leiste gezeigt: eine Auswahl mit einer Möglichkeit ist
## keine Auswahl.
class_name TabGroup
extends VBoxContainer

## Beschriftungen in der Reihenfolge der Unterreiter.
@export var labels: PackedStringArray = PackedStringArray()

var _subs: Array[Control] = []
var _buttons: Array[TapButton] = []
var _row: HBoxContainer = null
var _active: int = 0

func _ready() -> void:
	for child in get_children():
		if child is ScrollContainer:
			_subs.append(child)
			(child as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _subs.size() > 1:
		_row = HBoxContainer.new()
		for i in _subs.size():
			var b := TapButton.new()
			b.text = labels[i] if i < labels.size() else "?"
			b.custom_minimum_size = Vector2(0, 76)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.toggle_mode = true
			b.tapped.connect(select_sub.bind(i))
			_row.add_child(b)
			_buttons.append(b)
		add_child(_row)
		move_child(_row, 0)
	select_sub(0)

func select_sub(index: int) -> void:
	if _subs.is_empty():
		return
	# Auf einen versteckten Unterreiter darf nicht geschaltet werden -- der
	# Geheimreiter existiert erst nach dem ersten Fang.
	if index < 0 or index >= _subs.size() or not _sub_allowed(index):
		index = _first_allowed()
	_active = index
	for i in _subs.size():
		_subs[i].visible = i == index
		if i < _buttons.size():
			_buttons[i].button_pressed = i == index

## Blendet einen Unterreiter samt Knopf aus.
func set_sub_visible(index: int, shown: bool) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_buttons[index].visible = shown
	if not shown and _active == index:
		select_sub(_first_allowed())

func _sub_allowed(index: int) -> bool:
	return index >= _buttons.size() or _buttons[index].visible

func _first_allowed() -> int:
	for i in _subs.size():
		if _sub_allowed(i):
			return i
	return 0

func active_sub() -> int:
	return _active
