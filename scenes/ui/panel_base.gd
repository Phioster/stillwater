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
		refresh()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()

## Von jedem Panel überschrieben.
func refresh() -> void:
	pass

## Hilfsmittel: Alle Kinder eines Containers entfernen.
func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
