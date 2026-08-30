extends TestCase

func _main() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	return m

## Reiterleiste und Panel-Liste sind ueber den INDEX gekoppelt. Ein Panel an
## der falschen Stelle einzufuegen wuerde stumm den falschen Reiter oeffnen --
## genau das ist beim Einhaengen der Vitrine beinahe passiert.
func test_every_tab_has_its_panel_in_the_same_order() -> void:
	Game.new_game()
	var m := _main()
	var panels: Node = m.get_node("SidePanel/Panels")
	assert_eq(TabRail.TABS.size(), panels.get_child_count(),
		"jeder Reiter braucht genau ein Panel")
	assert_eq(panels.get_child(TabRail.SECRET_TAB).name, &"SecretScroll",
		"SECRET_TAB zeigt auf das falsche Panel")
	assert_eq(TabRail.TABS[TabRail.SECRET_TAB], "Geheim")
	assert_eq(panels.get_child(1).name, &"VitrineScroll")
	assert_eq(TabRail.TABS[1], "Vitrine")
	m.free()

func test_the_rail_never_grows_past_its_own_height() -> void:
	Game.new_game()
	var m := _main()
	var rail := m.get_node("Row/TabRail")
	rail.size = Vector2(96, 500)
	rail._fit_buttons()
	var used := 0.0
	var box: VBoxContainer = rail.get_node("Box")
	var shown := 0
	for b in box.get_children():
		if b.visible:
			shown += 1
			used += b.custom_minimum_size.y
	used += float(shown - 1) * float(box.get_theme_constant(&"separation"))
	assert_true(used <= 500.0, "die Leiste ragt über den Rand: %f von 500" % used)
	m.free()

func test_the_showcase_tab_lists_only_favorites() -> void:
	Game.new_game()
	var inv := Game.ctx.inventory
	inv.add(CaughtFish.make(&"bluegill", 0.0, false))
	inv.add(CaughtFish.make(&"roach", 1.0, false))
	assert_true(Game.toggle_favorite(1))

	var m := _main()
	m.show_tab(1)
	var panel: PanelBase = m.get_node("SidePanel/Panels/VitrineScroll/VitrinePanel")
	var names := _all_text(panel)
	var joined := "\n".join(names)
	assert_true("Rotauge" in joined or "roach" in joined, "der Favorit fehlt in der Vitrine")
	assert_false("Bluegill" in joined, "ein normaler Fang gehört nicht in die Vitrine")

	# ... und umgekehrt: das Inventar zeigt den Favoriten nicht mehr.
	m.show_tab(0)
	var fish_panel: PanelBase = m.get_node("SidePanel/Panels/FishScroll/FishPanel")
	var inv_text := "\n".join(_all_text(fish_panel))
	assert_true("Bluegill" in inv_text, "der normale Fang fehlt im Inventar")
	assert_false("Rotauge" in inv_text, "der Favorit steht doppelt")
	m.free()

## Die Zonenreihenfolge folgt der Freischaltung, nicht der Ordner-Auflistung --
## die ist zwischen Geräten nicht einmal stabil.
func test_journal_zones_are_in_unlock_order() -> void:
	Game.new_game()
	var m := _main()
	var panel = m.get_node("SidePanel/Panels/JournalScroll/JournalPanel")
	var zones: Array = panel._zones_in_order()
	assert_eq(zones[0].id, &"willow_lake", "die Startzone muss zuerst kommen")
	for i in range(1, zones.size()):
		assert_true(zones[i - 1].unlock_level <= zones[i].unlock_level,
			"Zonen stehen falsch herum")
	m.free()

## Innerhalb einer Zone: gewöhnlich vor selten, gleichrangig alphabetisch.
func test_fish_inside_a_zone_are_sorted_by_rarity_then_name() -> void:
	Game.new_game()
	var m := _main()
	var panel = m.get_node("SidePanel/Panels/JournalScroll/JournalPanel")
	var fish: Array = panel._fish_in_order(&"willow_lake")
	assert_true(fish.size() > 5, "die Startzone muss mehrere Arten haben")
	for f in fish:
		assert_false(f.is_secret, "Geheimfische gehören nicht ins Journal")
	for i in range(1, fish.size()):
		var a: RarityData = Database.rarities[fish[i - 1].rarity_id]
		var b: RarityData = Database.rarities[fish[i].rarity_id]
		assert_true(a.value_mult < b.value_mult
			or (a.value_mult == b.value_mult and fish[i - 1].display_name <= fish[i].display_name),
			"falsche Reihenfolge: %s (%s) vor %s (%s)" % [
				fish[i - 1].display_name, a.display_name, fish[i].display_name, b.display_name])
	assert_eq(Database.rarities[fish[0].rarity_id].id, &"common",
		"die erste Zeile muss ein gewöhnlicher Fisch sein")
	m.free()

func test_the_journal_shows_one_zone_at_a_time() -> void:
	Game.new_game()
	var m := _main()
	m.show_tab(2)
	var panel = m.get_node("SidePanel/Panels/JournalScroll/JournalPanel")
	var shown: Array[StringName] = []
	for child in panel.get_children():
		if child.has_meta(&"fish_id"):
			shown.append(child.get_meta(&"fish_id"))
	assert_true(shown.size() > 0, "es wird gar nichts angezeigt")
	for id in shown:
		assert_eq(Database.fish[id].zone_id, &"willow_lake",
			"%s gehört nicht in die angezeigte Zone" % id)
	m.free()

func _all_text(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_all_text(child))
	return out
