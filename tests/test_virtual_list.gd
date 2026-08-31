extends TestCase

## Gemessen, nicht vermutet: 395 Inventarzeilen sind 1.583 Knoten, und die
## kosten 394 ms beim Eintritt in den Baum. Deshalb baut die Liste nur, was
## im Fenster steht -- und genau das wird hier geprüft.

func _list(count: int) -> VirtualList:
	var tree := Engine.get_main_loop() as SceneTree
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(400, 480)
	tree.root.add_child(scroll)
	var list := VirtualList.new()
	scroll.add_child(list)
	list.size = Vector2(400, 480)
	list.setup(count, 96.0, func(i: int) -> Control:
		var c := Control.new()
		c.set_meta(&"row", i)
		return c)
	return list

func test_only_the_visible_rows_are_built() -> void:
	var list := _list(395)
	list._refresh_window()
	assert_true(list.live_rows() > 0, "es wird gar nichts gebaut")
	assert_true(list.live_rows() < 40,
		"es stehen %d Zeilen im Baum, das ist keine Virtualisierung" % list.live_rows())
	list.get_parent().free()

## Der Scrollbalken muss die GANZE Liste kennen, auch wenn nur ein Ausschnitt
## im Baum steht -- sonst lässt sich nicht bis unten scrollen.
func test_the_full_height_is_reserved() -> void:
	var list := _list(395)
	assert_almost_eq(list.custom_minimum_size.y, 395.0 * 96.0, 0.001)
	list.get_parent().free()

func test_scrolling_moves_the_window() -> void:
	var list := _list(395)
	list._refresh_window()
	var first_before: int = int(list.get_child(0).get_meta(&"row"))
	var scroll: ScrollContainer = list.get_parent()
	# Ohne Layout-Durchlauf kennt der Scrollbalken seinen Bereich noch nicht
	# und klemmt jede Position auf 0. Hier von Hand setzen.
	scroll.get_v_scroll_bar().max_value = 395.0 * 96.0
	scroll.scroll_vertical = 200 * 96
	list._refresh_window()
	var first_after: int = int(list.get_child(0).get_meta(&"row"))
	assert_true(first_after > first_before + 100,
		"das Fenster ist nicht mitgewandert: %s -> %s" % [first_before, first_after])
	list.get_parent().free()

## Die Zeilen müssen an der richtigen Stelle sitzen, sonst liegen sie
## übereinander.
func test_rows_sit_at_their_index_position() -> void:
	var list := _list(50)
	list._refresh_window()
	for c in list.get_children():
		var i := int(c.get_meta(&"row"))
		assert_almost_eq(c.offset_top, float(i) * 96.0, 0.001,
			"Zeile %d sitzt falsch" % i)
	list.get_parent().free()

func test_an_empty_list_builds_nothing_and_does_not_crash() -> void:
	var list := _list(0)
	list._refresh_window()
	assert_eq(list.live_rows(), 0)
	assert_almost_eq(list.custom_minimum_size.y, 0.0)
	list.get_parent().free()

## Das ganze Panel darf mit vielen Fischen nicht mehr hunderte Knoten haben.
func test_the_inventory_panel_stays_small_with_many_fish() -> void:
	Game.new_game()
	Game.ctx.inventory.capacity = 500
	for i in 395:
		Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.0, false))
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	m.show_tab(0)
	var panel: PanelBase = m.get_node("SidePanel/Panels/FishGroup/FishScroll/FishPanel")
	panel.refresh()
	var nodes := _count(panel)
	assert_true(nodes < 300, "das Panel hat %d Knoten -- vorher waren es 1.583" % nodes)
	m.free()

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c

## Ein Waechter fuer ALLE Panels, nicht nur die, die ich heute kenne: mit
## vollem Spielstand darf kein Panel hunderte Knoten in den Baum haengen.
## Gemessen kostet jeder eingehaengte Knoten rund 0,25 ms -- 400 waeren schon
## eine zehntel Sekunde Standzeit beim Oeffnen.
func test_no_panel_builds_hundreds_of_nodes_with_a_full_save() -> void:
	Game.new_game()
	Game.coins = 9_000_000
	Game.ctx.player_level = 60
	Game.ctx.inventory.capacity = 500
	for id in Database.zones:
		if not Game.unlocked_zones.has(id):
			Game.unlocked_zones.append(id)
	for id in Database.fish:
		var f: FishData = Database.fish[id]
		for rank in FishRoll.RANK_NAMES.size():
			Game.ctx.journal.record(CaughtFish.make(f.id, [-2.5, -1.0, 0.0, 1.0, 1.9, 2.6, 3.3][rank], false), f.is_secret)
	for i in 400:
		Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.0, i % 40 == 0))
	for i in Game.ctx.inventory.fish.size():
		if Game.ctx.inventory.fish[i].is_shiny:
			Game.toggle_favorite(i)

	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	var worst := ""
	var worst_count := 0
	for tab in TabRail.TABS.size():
		m.show_tab(tab)
		var group: Node = m.get_node("SidePanel/Panels").get_child(tab)
		for sub in group.get_children():
			if not (sub is ScrollContainer):
				continue
			for panel in sub.get_children():
				if panel is PanelBase:
					(panel as PanelBase).refresh()
					var n := _count(panel)
					if n > worst_count:
						worst_count = n
						worst = String(panel.name)
	assert_true(worst_count < 400,
		"%s baut %d Knoten -- das gehoert in eine VirtualList" % [worst, worst_count])
	m.free()

## Ein Control schluckt Berührungen standardmäßig -- damit fing die Liste
## jede Wischgeste ab, und in keiner Liste liess sich mehr scrollen.
func test_the_list_lets_the_drag_reach_the_scroll_container() -> void:
	var list := _list(10)
	assert_eq(list.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"die Liste schluckt die Wischgeste")
	list.get_parent().free()

## Und dasselbe für jede Liste, die wirklich im Spiel hängt.
func test_no_panel_swallows_the_drag() -> void:
	Game.new_game()
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	for tab in TabRail.TABS.size():
		m.show_tab(tab)
	for node in _all(m.get_node("SidePanel/Panels")):
		if node is VirtualList:
			assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s schluckt die Wischgeste" % node.get_path())
	m.free()

func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
