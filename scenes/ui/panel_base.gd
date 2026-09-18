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

## Eine Textzeile fuers Panel. IMMER mit Umbruch.
##
## Ohne ihn verlangt ein Label als MINDESTbreite seine volle Textbreite. Ein
## einziger langer Satz schiebt damit die ganze Gruppe ueber den Rahmen
## hinaus: der Sandgrund hoert an der richtigen Stelle auf, die Knoepfe laufen
## darueber weiter und verschwinden unter der Bildlaufleiste. Genau so sah der
## Koederreiter aus (tests/test_panel_width.gd haelt es jetzt fest).
func zeile(text: String, farbe: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if farbe != &"":
		l.modulate = Palette.get_color(farbe)
	return l

## Sofort aus dem Baum nehmen, nicht nur zum Freigeben vormerken: sonst haengen
## die alten Zeilen bis zum Frameende neben den neuen, die Liste ist kurz
## doppelt so lang und die Ansicht springt.
func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
