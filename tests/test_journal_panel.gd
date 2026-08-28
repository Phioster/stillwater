extends TestCase

## journal_panel.gd ist ein Szenenskript ohne eigenen class_name, deshalb per
## load() statt eines bare Bezeichners (wie in test_upgrade_panel.gd).
func _panel() -> PanelBase:
	var panel: PanelBase = load("res://scenes/ui/panels/journal_panel.gd").new()
	panel.refresh()
	return panel

## Zeilen und Detailbloecke tragen ihre Fisch-ID als Metadatum -- robuster
## als eine Kindindex-Rechnung ueber die echte Datenbank.
func _row_for(panel: PanelBase, id: StringName) -> Control:
	for child in panel.get_children():
		if child.has_meta(&"fish_id") and child.get_meta(&"fish_id") == id:
			return child
	return null

func _detail_for(panel: PanelBase, id: StringName) -> Control:
	for child in panel.get_children():
		if child.has_meta(&"detail_for") and child.get_meta(&"detail_for") == id:
			return child
	return null

func _tap(panel: PanelBase, id: StringName) -> void:
	var row := _row_for(panel, id)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	row.gui_input.emit(event)

func test_expanding_a_discovered_species_shows_all_details() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 2.0, 4, true))
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 0.5, 1, false))

	var panel := _panel()
	_tap(panel, &"bluegill")
	var detail := _detail_for(panel, &"bluegill")
	assert_true(detail != null, "aufgeklappte Zeile muss einen Detailblock zeigen")

	var fish: FishData = Database.fish[&"bluegill"]
	var e := Game.ctx.journal.entry(&"bluegill")
	var rarity := Game.ctx.rarity_of(fish)
	var record := CaughtFish.make(&"bluegill", float(e["best_weight"]), int(e["best_quality"]), bool(e["shiny_found"]))
	var expected_value := Economy.sell_price(record, fish, rarity)

	assert_true(rarity.display_name in detail.text, "Rarität fehlt")
	assert_true("2" in detail.text, "Fangzahl fehlt")
	assert_true("0,50" in detail.text, "kleinstes Gewicht fehlt")
	assert_true("2,00" in detail.text, "Rekordgewicht fehlt")
	assert_true(FishRoll.QUALITY_NAMES[int(e["best_quality"])] in detail.text, "Qualitätsname fehlt")
	assert_true("ja" in detail.text, "Schimmer-Angabe fehlt")
	assert_true("0" in detail.text, "Fischlevel fehlt")
	assert_true(("%d" % expected_value) in detail.text, "Wert muss aus Economy.sell_price() kommen")
	panel.free()

func test_expanding_an_undiscovered_species_reveals_nothing() -> void:
	Game.new_game()
	var id: StringName = &"roach"
	assert_false(Game.ctx.journal.is_discovered(id))

	var panel := _panel()
	_tap(panel, id)
	var detail := _detail_for(panel, id)
	assert_true(detail != null, "auch eine unentdeckte Zeile muss sich aufklappen lassen")

	var fish: FishData = Database.fish[id]
	assert_false(fish.display_name in detail.text, "Name darf nicht verraten werden")
	assert_false("kg" in detail.text, "Gewicht darf nicht verraten werden")
	panel.free()

func test_expanded_row_survives_a_refresh() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 1.0, 0, false))

	var panel := _panel()
	_tap(panel, &"bluegill")
	assert_true(_detail_for(panel, &"bluegill") != null)

	panel.refresh()
	assert_true(_detail_for(panel, &"bluegill") != null,
		"ein Fang loest state_changed -> refresh() aus; die offene Zeile darf dabei nicht zuklappen")
	panel.free()

func test_tapping_the_open_row_again_closes_it() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 1.0, 0, false))

	var panel := _panel()
	_tap(panel, &"bluegill")
	assert_true(_detail_for(panel, &"bluegill") != null)
	_tap(panel, &"bluegill")
	assert_true(_detail_for(panel, &"bluegill") == null)
	panel.free()

func test_only_one_row_is_expanded_at_once() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 1.0, 0, false))
	Game.ctx.journal.record(CaughtFish.make(&"perch", 1.0, 0, false))

	var panel := _panel()
	_tap(panel, &"bluegill")
	_tap(panel, &"perch")
	assert_true(_detail_for(panel, &"bluegill") == null, "die zuerst geoeffnete Zeile muss zuklappen")
	assert_true(_detail_for(panel, &"perch") != null)
	panel.free()
