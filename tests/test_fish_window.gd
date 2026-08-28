extends TestCase

## Instanziert die echte Szene (nicht nur das Skript) -- Icon, Panel und
## Scrim muessen als Kindknoten existieren, damit die @onready-Referenzen
## im Skript etwas finden.
func _window() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var w: Control = load("res://scenes/ui/fish_window.tscn").instantiate()
	tree.root.add_child(w)
	return w

func _tap(node: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	node.gui_input.emit(event)

func test_a_discovered_species_shows_all_the_promised_details() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 2.0, 4, true))
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 0.5, 1, false))

	var w := _window()
	w.open(&"bluegill")
	assert_true(w.visible, "open() muss das Fenster zeigen")

	var fish: FishData = Database.fish[&"bluegill"]
	var zone: ZoneData = Database.zones[fish.zone_id]
	var e := Game.ctx.journal.entry(&"bluegill")
	var rarity := Game.ctx.rarity_of(fish)
	var record := CaughtFish.make(&"bluegill", float(e["best_weight"]), int(e["best_quality"]), bool(e["shiny_found"]))
	var expected_value := Economy.sell_price(record, fish, rarity)

	var text: String = w.get_node("Panel/Box/NameLabel").text + "\n" + w.get_node("Panel/Box/ZoneLabel").text + "\n" + w.get_node("Panel/Box/StatsLabel").text
	assert_true(fish.display_name in text, "Name fehlt")
	assert_true(rarity.display_name in text, "Rarität fehlt")
	assert_true(zone.display_name in text, "Heimatzone fehlt")
	assert_true("2" in text, "Fangzahl fehlt")
	assert_true("0,50" in text, "kleinstes Gewicht fehlt")
	assert_true("2,00" in text, "Rekordgewicht fehlt")
	assert_true(("%.2f" % fish.weight_min).replace(".", ",") in text, "Gewichtsspanne (min) fehlt")
	assert_true(("%.2f" % fish.weight_max).replace(".", ",") in text, "Gewichtsspanne (max) fehlt")
	assert_true(FishRoll.QUALITY_NAMES[int(e["best_quality"])] in text, "Qualitätsname fehlt")
	assert_true("ja" in text, "Schimmer-Angabe fehlt")
	assert_true(("%d" % expected_value) in text, "Wert muss aus Economy.sell_price() kommen")
	assert_true(("%d" % fish.base_value) in text, "Grundwert fehlt")
	assert_true(("%d" % fish.xp) in text, "XP fehlt")
	w.queue_free()

func test_an_undiscovered_species_reveals_nothing() -> void:
	Game.new_game()
	var id: StringName = &"roach"
	assert_false(Game.ctx.journal.is_discovered(id))

	var w := _window()
	w.open(id)
	assert_true(w.visible)

	var fish: FishData = Database.fish[id]
	var text: String = w.get_node("Panel/Box/NameLabel").text + "\n" + w.get_node("Panel/Box/StatsLabel").text
	assert_false(fish.display_name in text, "Name darf nicht verraten werden")
	assert_false("kg" in text, "Gewicht darf nicht verraten werden")
	w.queue_free()

func test_a_locked_secret_species_shows_only_its_hint() -> void:
	Game.new_game()
	var id: StringName = &""
	for fid in Database.fish:
		if (Database.fish[fid] as FishData).is_secret:
			id = fid
	assert_false(id == &"")
	var fish: FishData = Database.fish[id]

	var w := _window()
	w.open(id)

	var text: String = w.get_node("Panel/Box/StatsLabel").text
	assert_true(fish.secret_hint in text, "der Hinweistext muss erscheinen")
	assert_false(fish.display_name in text, "Name darf nicht verraten werden")
	w.queue_free()

func test_close_button_hides_the_window() -> void:
	Game.new_game()
	var w := _window()
	w.open(&"bluegill")
	assert_true(w.visible)
	w.get_node("Panel/Box/Close").pressed.emit()
	assert_false(w.visible)
	w.queue_free()

func test_tapping_the_scrim_hides_the_window() -> void:
	Game.new_game()
	var w := _window()
	w.open(&"bluegill")
	assert_true(w.visible)
	_tap(w.get_node("Scrim"))
	assert_false(w.visible, "ein Tipp daneben muss ebenfalls schliessen")
	w.queue_free()

func test_tapping_inside_the_panel_does_not_close_it() -> void:
	Game.new_game()
	var w := _window()
	w.open(&"bluegill")
	_tap(w.get_node("Panel"))
	assert_true(w.visible, "ein Tipp auf das Fenster selbst darf es nicht schliessen")
	w.queue_free()

## Ein Fang waehrend das Fenster offen ist darf weder den Inhalt neu
## aufbauen noch die Position verschieben -- siehe Task-Brief.
func test_window_stays_open_and_in_place_across_a_catch() -> void:
	Game.new_game()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 1.0, 0, false))

	var w := _window()
	w.open(&"bluegill")
	var panel: Control = w.get_node("Panel")
	var offsets_before := Vector4(panel.offset_left, panel.offset_top, panel.offset_right, panel.offset_bottom)
	var text_before: String = w.get_node("Panel/Box/StatsLabel").text

	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 3.0, 5, true))
	Game.state_changed.emit()

	assert_true(w.visible, "das Fenster darf sich waehrend eines Fangs nicht schliessen")
	var offsets_after := Vector4(panel.offset_left, panel.offset_top, panel.offset_right, panel.offset_bottom)
	assert_eq(offsets_after, offsets_before, "die Fensterposition darf sich nicht verschieben")
	assert_eq(w.get_node("Panel/Box/StatsLabel").text, text_before,
		"der Inhalt darf sich nicht mitten im Betrachten neu aufbauen")
	w.queue_free()
