extends TestCase

func _main() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	return m

## Reiterleiste und Gruppen sind ueber den INDEX gekoppelt. Eine Gruppe an
## der falschen Stelle wuerde stumm den falschen Reiter oeffnen.
func test_every_tab_has_its_group_in_the_same_order() -> void:
	Game.new_game()
	var m := _main()
	var panels: Node = m.get_node("SidePanel/Panels")
	assert_eq(TabRail.TABS.size(), panels.get_child_count(),
		"jeder Reiter braucht genau eine Gruppe")
	var expected := ["FishGroup", "JournalGroup", "ShopGroup", "WorldGroup", "OptionsGroup"]
	for i in expected.size():
		assert_eq(String(panels.get_child(i).name), expected[i],
			"Reiter %s zeigt auf %s" % [TabRail.TABS[i], panels.get_child(i).name])
		assert_true(panels.get_child(i) is TabGroup, "Gruppe %d ist keine TabGroup" % i)
	m.free()

## Jede Gruppe braucht so viele Beschriftungen, wie sie Unterreiter hat --
## sonst steht dort ein Fragezeichen.
func test_every_group_labels_all_of_its_sub_tabs() -> void:
	Game.new_game()
	var m := _main()
	for group in m.get_node("SidePanel/Panels").get_children():
		var subs := 0
		for child in group.get_children():
			if child is ScrollContainer:
				subs += 1
		if subs > 1:
			assert_eq(group.labels.size(), subs,
				"%s hat %d Unterreiter, aber %d Beschriftungen" % [group.name, subs, group.labels.size()])
	m.free()

func test_the_rail_never_demands_more_room_than_the_screen() -> void:
	Game.new_game()
	var m := _main()
	var rail: Control = m.get_node("Row/TabRail")
	var demanded := rail.get_combined_minimum_size().y
	assert_true(demanded <= 720.0,
		"die Leiste verlangt %f px, der Bildschirm hat 720" % demanded)
	m.free()

## Jeder Knopf bleibt mit dem Daumen treffbar, und sie teilen sich den Platz.
func test_every_tab_stays_thumb_sized_and_shares_the_space() -> void:
	Game.new_game()
	var m := _main()
	var box: VBoxContainer = m.get_node("Row/TabRail/Box")
	for b in box.get_children():
		assert_eq(b.custom_minimum_size.y, TabRail.MIN_BUTTON_HEIGHT)
		assert_eq(b.size_flags_vertical, Control.SIZE_EXPAND_FILL,
			"ohne Dehnung teilen sich die Reiter den Platz nicht")
	m.free()

func test_the_showcase_tab_lists_only_favorites() -> void:
	Game.new_game()
	var inv := Game.ctx.inventory
	inv.add(CaughtFish.make(&"bluegill", 0.0, false))
	inv.add(CaughtFish.make(&"roach", 1.0, false))
	assert_true(Game.toggle_favorite(1))

	var m := _main()
	m.show_tab(0)
	m.get_node("SidePanel/Panels/FishGroup").select_sub(1)
	var panel: PanelBase = m.get_node("SidePanel/Panels/FishGroup/VitrineScroll/VitrinePanel")
	var names := _all_text(panel)
	var joined := "\n".join(names)
	assert_true("Rotauge" in joined or "roach" in joined, "der Favorit fehlt in der Vitrine")
	assert_false("Bluegill" in joined, "ein normaler Fang gehört nicht in die Vitrine")

	# ... und umgekehrt: das Inventar zeigt den Favoriten nicht mehr.
	m.get_node("SidePanel/Panels/FishGroup").select_sub(0)
	var fish_panel: PanelBase = m.get_node("SidePanel/Panels/FishGroup/FishScroll/FishPanel")
	var inv_text := "\n".join(_all_text(fish_panel))
	assert_true("Bluegill" in inv_text, "der normale Fang fehlt im Inventar")
	assert_false("Rotauge" in inv_text, "der Favorit steht doppelt")
	m.free()

## Die Zonenreihenfolge folgt der Freischaltung, nicht der Ordner-Auflistung --
## die ist zwischen Geräten nicht einmal stabil.
func test_journal_zones_are_in_unlock_order() -> void:
	Game.new_game()
	var m := _main()
	var panel = m.get_node("SidePanel/Panels/JournalGroup/JournalScroll/JournalPanel")
	var zones: Array = Database.zones_in_order()
	assert_eq(zones[0].id, &"willow_lake", "die Startzone muss zuerst kommen")
	for i in range(1, zones.size()):
		assert_true(zones[i - 1].unlock_level <= zones[i].unlock_level,
			"Zonen stehen falsch herum")
	m.free()

## Innerhalb einer Zone: gewöhnlich vor selten, gleichrangig alphabetisch.
func test_fish_inside_a_zone_are_sorted_by_rarity_then_name() -> void:
	Game.new_game()
	var m := _main()
	var panel = m.get_node("SidePanel/Panels/JournalGroup/JournalScroll/JournalPanel")
	var fish: Array = panel._fish_in_order(&"willow_lake")
	assert_true(fish.size() > 5, "die Startzone muss mehrere Arten haben")
	for f in fish:
		assert_false(f.is_secret, "Geheimfische gehören nicht ins Journal")
	for i in range(1, fish.size()):
		var a: RarityData = Database.rarities[fish[i - 1].rarity_id]
		var b: RarityData = Database.rarities[fish[i].rarity_id]
		var same_rarity: bool = a.value_mult == b.value_mult
		assert_true(a.value_mult < b.value_mult
			or (same_rarity and fish[i - 1].weight_mean <= fish[i].weight_mean),
			"falsche Reihenfolge: %s (%s, %.2f kg) vor %s (%s, %.2f kg)" % [
				fish[i - 1].display_name, a.display_name, fish[i - 1].weight_mean,
				fish[i].display_name, b.display_name, fish[i].weight_mean])
	assert_eq(Database.rarities[fish[0].rarity_id].id, &"common",
		"die erste Zeile muss ein gewöhnlicher Fisch sein")
	m.free()

func test_the_journal_shows_one_zone_at_a_time() -> void:
	Game.new_game()
	var m := _main()
	m.show_tab(1)
	var panel = m.get_node("SidePanel/Panels/JournalGroup/JournalScroll/JournalPanel")
	var shown: Array[StringName] = []
	for child in _rows_with_fish_id(panel):
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

## Ein Theme an EINER Stelle statt Umriss pro Element -- Vergessen ist bei so
## etwas die wahrscheinlichste Fehlerquelle, also wird es hier festgehalten.
func test_the_ui_carries_outline_and_shadow_from_one_theme() -> void:
	Game.new_game()
	var m := _main()
	assert_true(m.theme != null, "die Oberfläche hat kein Theme")
	assert_eq(m.theme.get_constant("outline_size", "Label"), UiTheme.OUTLINE)
	assert_eq(m.theme.get_color("font_outline_color", "Label"), Palette.get_color(&"outline"))
	assert_true(m.theme.get_stylebox("panel", "PanelContainer") != null, "Panels haben keinen Stil")
	# Jede Beschriftung erbt ihn, ohne selbst etwas zu setzen.
	var label := Label.new()
	m.add_child(label)
	assert_eq(label.get_theme_constant("outline_size"), UiTheme.OUTLINE,
		"eine frische Beschriftung erbt den Umriss nicht")
	m.free()

## Auch die Reiter federn -- sonst fühlt sich ausgerechnet der meistbenutzte
## Der Zonenwechsler muss jede Zone mit EINEM Tipp erreichbar halten, auch
## wenn es sieben werden -- deshalb ein Raster statt einer Reihe.
func test_the_zone_switcher_holds_every_zone_in_one_tap() -> void:
	Game.new_game()
	var m := _main()
	m.show_tab(1)
	var panel = m.get_node("SidePanel/Panels/JournalGroup/JournalScroll/JournalPanel")
	var grid: GridContainer = null
	for child in panel.get_children():
		if child is GridContainer:
			grid = child
	assert_true(grid != null, "kein Raster im Journal")
	assert_eq(grid.get_child_count(), Database.zones.size(),
		"nicht jede Zone hat einen Knopf")
	for b in grid.get_children():
		assert_true(b is TapButton, "der Zonenknopf ist kein TapButton: %s" % b.get_class())
	m.free()

## Der letzte Eintrag einer Zone ist der seltenste, und innerhalb seiner
## Rarität der schwerste. NICHT unbedingt der schwerste der ganzen Zone: ein
## epischer Fisch darf schwerer sein als ein legendärer. Die Rarität führt,
## das Gewicht ordnet innerhalb davon -- so wie in der Referenz, nur dass
## dort der zweite Schlüssel gar keiner ist.
func test_the_last_entry_is_the_rarest_and_heaviest_of_its_rarity() -> void:
	Game.new_game()
	var m := _main()
	var panel = m.get_node("SidePanel/Panels/JournalGroup/JournalScroll/JournalPanel")
	for zid in Database.zones:
		var fish: Array = panel._fish_in_order(zid)
		var last: FishData = fish[fish.size() - 1]
		for f in fish:
			var rf: RarityData = Database.rarities[f.rarity_id]
			var rl: RarityData = Database.rarities[last.rarity_id]
			assert_true(rf.value_mult <= rl.value_mult,
				"%s ist seltener als der letzte Eintrag in %s" % [f.display_name, zid])
			if is_equal_approx(rf.value_mult, rl.value_mult):
				assert_true(f.weight_mean <= last.weight_mean,
					"%s ist schwerer als der letzte Eintrag in %s" % [f.display_name, zid])
	m.free()

## Das Scrollen steckt seit der Gruppierung eine Ebene tiefer. Eine Schleife
## nur ueber die direkten Kinder haette es stumm uebersehen -- und niemand
## haette es gemerkt, bis eine Liste sich nicht mehr wischen laesst.
func test_every_list_still_scrolls_after_the_regrouping() -> void:
	Game.new_game()
	var m := _main()
	var found := _scrolls(m.get_node("SidePanel/Panels"))
	# Die Zahl steht als Literal da, damit eine neue Liste auffaellt und
	# jemand prueft, ob sie eingerichtet wurde -- nicht damit sie nie wachsen darf.
	assert_eq(found.size(), 13, "es gibt %d Listen, erwartet waren 13" % found.size())
	for sc in found:
		assert_eq(sc.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO,
			"%s wurde beim Einrichten uebersehen" % sc.name)
		assert_true(sc.gui_input.get_connections().size() > 0,
			"%s hat keinen Nachschwung" % sc.name)
	m.free()

func _scrolls(node: Node) -> Array[ScrollContainer]:
	var out: Array[ScrollContainer] = []
	if node is ScrollContainer:
		out.append(node)
	for c in node.get_children():
		out.append_array(_scrolls(c))
	return out

## Zeilen stecken seit der Virtualisierung in einer VirtualList, nicht mehr
## direkt im Panel -- deshalb rekursiv suchen.
func _rows_with_fish_id(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	if node is Control and node.has_meta(&"fish_id"):
		out.append(node)
	for c in node.get_children():
		out.append_array(_rows_with_fish_id(c))
	return out
