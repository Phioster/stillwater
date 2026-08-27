extends TestCase

## Testdouble: zaehlt refresh()-Aufrufe, sonst reines PanelBase-Verhalten.
class CountingPanel:
	extends PanelBase
	var refresh_count: int = 0
	func refresh() -> void:
		refresh_count += 1

## Reproduziert main.tscn: das Panel steckt in einem ScrollContainer, dessen
## eigenes visible umgeschaltet wird -- das Panel-`visible` selbst bleibt
## immer true. Genau die Konstellation aus I1.
func test_refresh_only_runs_while_visible_in_a_wrapped_scroll_container() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scroll := ScrollContainer.new()
	var panel := CountingPanel.new()
	scroll.add_child(panel)
	scroll.visible = false
	tree.root.add_child(scroll)

	assert_eq(panel.refresh_count, 0, "verstecktes Panel darf beim Eintritt nicht zeichnen")

	Game.state_changed.emit()
	assert_eq(panel.refresh_count, 0,
		"state_changed darf ein verstecktes, in ScrollContainer gewickeltes Panel nicht neu zeichnen")

	scroll.visible = true
	assert_eq(panel.refresh_count, 1, "Sichtbarwerden muss genau einmal zeichnen")

	Game.state_changed.emit()
	assert_eq(panel.refresh_count, 2, "sichtbares Panel zeichnet bei state_changed neu")

	scroll.visible = false
	assert_eq(panel.refresh_count, 2, "Verstecken darf nicht erneut zeichnen")

	tree.root.remove_child(scroll)
	scroll.free()
