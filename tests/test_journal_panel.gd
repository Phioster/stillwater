extends TestCase

## journal_panel.gd ist ein Szenenskript ohne eigenen class_name, deshalb per
## load() statt eines bare Bezeichners (wie in test_upgrade_panel.gd).
func _panel() -> PanelBase:
	var panel: PanelBase = load("res://scenes/ui/panels/journal_panel.gd").new()
	panel.refresh()
	return panel

## Zeilen (auch die gesperrten) tragen ihre Fisch-ID als Metadatum -- robuster
## als eine Kindindex-Rechnung ueber die echte Datenbank.
func _row_for(panel: PanelBase, id: StringName) -> Control:
	for child in panel.get_children():
		if child.has_meta(&"fish_id") and child.get_meta(&"fish_id") == id:
			return child
	return null

## Die Zeile ist ein Knopf: druecken statt ein Eingabeereignis nachbauen. Das
## ist naeher an dem, was der Spieler tut -- rohe gui_input-Ereignisse kamen auf
## dem Geraet gar nicht erst an.
func _tap(panel: PanelBase, id: StringName) -> void:
	var row := _row_for(panel, id)
	assert_true(row is Button, "eine Journalzeile muss ein Knopf sein: %s" % row.get_class())
	(row as Button).pressed.emit()

func _secret_id() -> StringName:
	for id in Database.fish:
		if (Database.fish[id] as FishData).is_secret:
			return id
	return &""

## Das Aufklappen ist raus: eine Zeile meldet sich beim Fenster ueber ein
## Signal statt selbst Einzelheiten anzuzeigen.
func test_tapping_a_discovered_row_emits_fish_tapped_with_its_id() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 1.0, 0, false))

	var panel := _panel()
	var seen: Array = []
	panel.fish_tapped.connect(func(id: StringName) -> void: seen.append(id))
	_tap(panel, &"bluegill")
	assert_eq(seen.size(), 1, "ein Tipp muss genau ein Signal ausloesen")
	assert_true(seen[0] == &"bluegill", "die gemeldete ID muss zur getippten Zeile passen")
	panel.free()

func test_tapping_an_undiscovered_row_emits_too_so_the_window_can_show_the_silhouette() -> void:
	Game.new_game()
	var id: StringName = &"roach"
	assert_false(Game.ctx.journal.is_discovered(id))

	var panel := _panel()
	var seen: Array = []
	panel.fish_tapped.connect(func(i: StringName) -> void: seen.append(i))
	_tap(panel, id)
	assert_eq(seen.size(), 1)
	assert_true(seen[0] == id)
	panel.free()

func test_tapping_a_locked_secret_row_emits_too_so_the_window_can_show_the_hint() -> void:
	Game.new_game()
	var id := _secret_id()
	assert_false(id == &"", "es muss einen geheimen Fisch in den Testdaten geben")

	var panel := _panel()
	var seen: Array = []
	panel.fish_tapped.connect(func(i: StringName) -> void: seen.append(i))
	_tap(panel, id)
	assert_eq(seen.size(), 1, "auch der gesperrte Platz muss antippbar sein")
	assert_true(seen[0] == id)
	panel.free()

func test_refresh_does_not_lose_any_rows() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 1.0, 0, false))

	var panel := _panel()
	var before := panel.get_child_count()
	panel.refresh()
	assert_eq(panel.get_child_count(), before, "ein Fang loest state_changed -> refresh() aus, die Zeilenliste muss gleich bleiben")
	panel.free()
