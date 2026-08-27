## Hält das Querformat-Layout zusammen: links die Welt, rechts das Panel,
## ganz rechts die Tab-Leiste. Das Panel überdeckt die Welt nie — ein Fisch
## kann mitten im Laden gedrillt werden.
extends Control

@onready var _side: PanelContainer = $Row/SidePanel
@onready var _panels: Control = $Row/SidePanel/Panels
@onready var _rail = $Row/TabRail

func _ready() -> void:
	if not _rail.tab_selected.is_connected(show_tab):
		_rail.tab_selected.connect(show_tab)
	_apply_safe_area()
	if not get_viewport().size_changed.is_connected(_apply_safe_area):
		get_viewport().size_changed.connect(_apply_safe_area)
	show_tab(-1)


## Auswertung wieder entfernt.
func _diagnose_rects() -> void:
	await get_tree().create_timer(2.0).timeout
	var paths := ["Row", "Row/World", "Row/World/CatchView", "Row/World/CatchView/Panel", "Row/World/CatchView/Orbs", "Row/SidePanel", "Row/TabRail", "Hud"]
	print("DIAG viewport=", get_viewport_rect().size, " main=", size,
		" safe=", DisplayServer.get_display_safe_area(), " win=", DisplayServer.window_get_size())
	for p in paths:
		var n := get_node_or_null(p)
		if n is Control:
			var c: Control = n
			print("DIAG ", p, " -> ", c.get_global_rect(),
				" A=", Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom),
				" O=", Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom),
				" min=", c.custom_minimum_size, " sichtbar=", c.is_visible_in_tree())
		else:
			print("DIAG ", p, " -> FEHLT")

## Blendet genau ein Panel ein. -1 schließt alle. Ein Index außerhalb der
## vorhandenen Panels wirkt wie -1: alles bleibt zu, statt abzustürzen.
func show_tab(index: int) -> void:
	var count := _panels.get_child_count()
	var valid := index >= 0 and index < count
	_side.visible = valid
	for i in count:
		(_panels.get_child(i) as Control).visible = (valid and i == index)

## Hält HUD und Tab-Leiste aus Notch und Gestenleiste heraus.
func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.window_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return
	var scale_x := float(size.x) / float(screen.x)
	var scale_y := float(size.y) / float(screen.y)
	var left := float(safe.position.x) * scale_x
	var top := float(safe.position.y) * scale_y
	var right := float(screen.x - safe.end.x) * scale_x
	var bottom := float(screen.y - safe.end.y) * scale_y
	$Row.offset_left = left
	$Row.offset_top = top
	$Row.offset_right = -right
	$Row.offset_bottom = -bottom
	$Hud.offset_left = left + 16.0
	$Hud.offset_top = top + 16.0
