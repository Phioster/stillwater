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

## Testdouble mit Inhalt, damit ueberhaupt gescrollt werden kann.
class TallPanel:
	extends PanelBase
	func refresh() -> void:
		for c in get_children():
			c.queue_free()
		for i in 20:
			var l := Label.new()
			l.text = "Zeile %d" % i
			l.custom_minimum_size = Vector2(0, 40)
			add_child(l)

## Ein Fang baut die Liste neu auf. Ohne Merken springt die Ansicht dabei
## zurueck an den Anfang -- mitten im Lesen.
func test_refresh_keeps_the_scroll_position() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(200, 100)
	var panel := TallPanel.new()
	scroll.add_child(panel)
	tree.root.add_child(scroll)
	scroll.size = Vector2(200, 100)
	await tree.process_frame
	await tree.process_frame
	scroll.scroll_vertical = 120
	await tree.process_frame
	var before := scroll.scroll_vertical
	assert_true(before > 0, "Vorbedingung: die Ansicht muss ueberhaupt scrollbar sein")
	await panel.refresh_keeping_scroll()
	await tree.process_frame
	assert_eq(scroll.scroll_vertical, before, "nach dem Neuaufbau muss die Ansicht stehen bleiben")
	tree.root.remove_child(scroll)
	scroll.free()
