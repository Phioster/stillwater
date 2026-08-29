extends TestCase

## Im Android-Export kommt die Wurzel einer instanzierten Szene mit
## STANDARDANKERN an, egal was in der .tscn steht. Das hat die Fangansicht
## einmal auf Groesse 0 schrumpfen lassen und vier Messlaeufe gekostet.
## Der Test stellt genau das nach: Anker auf null, dann in den Baum -- wer sie
## im Code setzt, ueberlebt es, wer sich auf die Datei verlaesst, nicht.

const WINDOWS := [
	"res://scenes/ui/welcome_back.tscn",
	"res://scenes/ui/fish_window.tscn",
	"res://scenes/fishing/catch_view.tscn",
	"res://scenes/ui/catch_toast.tscn",
]

func test_instanced_roots_set_their_own_anchors() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for path in WINDOWS:
		var ps: PackedScene = load(path)
		assert_true(ps != null and ps.can_instantiate(), "Szene laedt nicht: %s" % path)
		var node: Control = ps.instantiate()
		# Export nachstellen: alle Anker auf den Standard zuruecksetzen.
		node.anchor_left = 0.0
		node.anchor_top = 0.0
		node.anchor_right = 0.0
		node.anchor_bottom = 0.0
		node.offset_left = 0.0
		node.offset_top = 0.0
		node.offset_right = 0.0
		node.offset_bottom = 0.0
		tree.root.add_child(node)
		await tree.process_frame
		var restored := node.anchor_right != 0.0 or node.anchor_bottom != 0.0 \
			or node.offset_right != 0.0 or node.offset_bottom != 0.0
		assert_true(restored,
			"%s verlaesst sich auf die Szenendatei -- im Export waere es 0x0 gross" % path)
		tree.root.remove_child(node)
		node.queue_free()
