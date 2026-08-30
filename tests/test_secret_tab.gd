extends TestCase

## Vor dem ersten Geheimfang darf nichts auf sie hindeuten: kein Reiter,
## keine Zeile, kein Hinweis. Danach bekommen sie einen eigenen Reiter.

func _main() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var main: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	return main

func _secret_id() -> StringName:
	for id in Database.fish:
		if Database.fish[id].is_secret:
			return id
	return &""

func _rail_button(main: Control, index: int) -> Button:
	return main.get_node("Row/TabRail/Box").get_child(index) as Button

func test_the_secret_tab_is_hidden_until_the_first_catch() -> void:
	Game.new_game()
	var main := _main()
	var tab := _rail_button(main, TabRail.SECRET_TAB)
	assert_eq(tab.text, "Geheim", "falscher Reiter geprueft")
	assert_false(tab.visible, "vor dem ersten Fang darf es den Reiter nicht geben")

	Game.ctx.journal.record(CaughtFish.make(_secret_id(), 1.0, 3, false), true)
	Game.state_changed.emit()
	assert_true(tab.visible, "nach dem Fang muss der Reiter da sein")
	main.free()

func test_the_secret_panel_stays_empty_until_the_first_catch() -> void:
	Game.new_game()
	var main := _main()
	var panel: PanelBase = main.get_node("SidePanel/Panels/SecretScroll/SecretPanel")
	main.show_tab(TabRail.SECRET_TAB)
	assert_eq(panel.get_child_count(), 0, "leer, solange nichts gefangen ist")

	var id := _secret_id()
	Game.ctx.journal.record(CaughtFish.make(id, 2.5, 4, false), true)
	panel.refresh()
	assert_true(panel.get_child_count() > 0, "der gefangene Geheimfisch fehlt")
	var found := false
	for child in panel.get_children():
		if child.has_meta(&"fish_id") and child.get_meta(&"fish_id") == id:
			found = true
	assert_true(found, "der Fisch steht nicht im eigenen Reiter")
	main.free()

## Ein Geheimfisch, der nur in einer anderen Zone lebt, darf nicht auftauchen,
## bloss weil irgendein anderer gefangen wurde.
func test_only_caught_secrets_are_listed() -> void:
	Game.new_game()
	var ids: Array[StringName] = []
	for id in Database.fish:
		if Database.fish[id].is_secret:
			ids.append(id)
	assert_true(ids.size() >= 2, "die Testdaten brauchen mehrere Geheimfische")

	var main := _main()
	var panel: PanelBase = main.get_node("SidePanel/Panels/SecretScroll/SecretPanel")
	Game.ctx.journal.record(CaughtFish.make(ids[0], 1.0, 3, false), true)
	panel.refresh()
	for child in panel.get_children():
		if child.has_meta(&"fish_id"):
			assert_true(child.get_meta(&"fish_id") == ids[0],
				"ungefangener Geheimfisch verraten: %s" % child.get_meta(&"fish_id"))
	main.free()
