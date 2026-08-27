## Basis aller Seitenpanels. Zeichnet sich neu, wenn sich der Spielzustand
## ändert — aber nur, solange das Panel sichtbar ist. Ein verstecktes Panel
## soll auf einem schwachen Gerät keine Arbeit machen.
class_name PanelBase
extends VBoxContainer

func _ready() -> void:
	if not Game.state_changed.is_connected(_on_state_changed):
		Game.state_changed.connect(_on_state_changed)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if is_visible_in_tree():
		refresh()

func _exit_tree() -> void:
	if Game.state_changed.is_connected(_on_state_changed):
		Game.state_changed.disconnect(_on_state_changed)

func _on_state_changed() -> void:
	if is_visible_in_tree():
		refresh_keeping_scroll()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh_keeping_scroll()

## Ein Fang loest state_changed aus, und refresh() baut die Liste neu auf --
## dabei springt die Ansicht sonst zurueck an den Anfang, mitten im Lesen.
func refresh_keeping_scroll() -> void:
	var scroll: ScrollContainer = get_parent() as ScrollContainer
	var y := scroll.scroll_vertical if scroll != null else 0
	refresh()
	if scroll != null and y > 0:
		# Erst nach dem Neuaufbau, sonst ist die Liste noch leer und der
		# Wert wird auf 0 zurechtgestutzt.
		await get_tree().process_frame
		scroll.scroll_vertical = y

## Von jedem Panel überschrieben.
func refresh() -> void:
	pass

## Hilfsmittel: Alle Kinder eines Containers entfernen.
func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
