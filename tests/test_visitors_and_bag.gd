extends TestCase

## Der Händler zieht weiter, sobald man bei ihm gekauft und den Laden wieder
## geschlossen hat -- wie in der Referenz. Der Rabe bleibt davon unberührt.

func _shop_ready() -> void:
	Game.new_game()
	Game.coins = 1_000_000
	Game.ctx.player_level = 60
	Game.upgrade_levels[&"trader"] = 2
	Game.visitors = Visitors.new()
	Game.visitors.refresh_trader(Time.get_unix_time_from_system())

func test_the_trader_stays_while_you_only_look() -> void:
	_shop_ready()
	assert_true(Game.trader_present(), "er muss erst einmal da sein")
	Game.close_shop()
	assert_true(Game.trader_present(), "wer nur schaut, verliert den Besuch nicht")

func test_the_trader_leaves_after_a_purchase_when_the_shop_closes() -> void:
	_shop_ready()
	var id := Game.trader_offer()[0]
	assert_true(Game.buy_from_trader(id))
	assert_true(Game.trader_present(), "waehrend des Kaufs bleibt er stehen")
	Game.close_shop()
	assert_false(Game.trader_present(), "nach dem Schliessen muss er weg sein")
	assert_true(Game.trader_offer().is_empty(), "sein Angebot verschwindet mit ihm")
	assert_false(Game.reroll_trader(), "und neu wuerfeln geht auch nicht mehr")

func test_the_next_hour_brings_him_back() -> void:
	_shop_ready()
	assert_true(Game.buy_from_trader(Game.trader_offer()[0]))
	Game.close_shop()
	Game.visitors.refresh_trader(Time.get_unix_time_from_system() + Visitors.TRADER_INTERVAL)
	assert_true(Game.trader_present(), "zur naechsten Stunde steht er wieder da")

func test_his_departure_survives_a_save() -> void:
	_shop_ready()
	assert_true(Game.buy_from_trader(Game.trader_offer()[0]))
	Game.close_shop()
	var blob := SaveManager.serialize()
	blob["last_seen_unix"] = int(Time.get_unix_time_from_system()) + 3600
	Game.new_game()
	SaveManager.deserialize(blob)
	assert_true(Game.visitors.trader_gone, "nach dem Laden staende er wieder da")

## Der Laden schliessen heisst hier: einen anderen Reiter waehlen.
func test_leaving_the_shop_tab_sends_him_off() -> void:
	_shop_ready()
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	m.show_tab(m.SHOP_TAB)
	assert_true(Game.buy_from_trader(Game.trader_offer()[0]))
	m.show_tab(0)
	assert_false(Game.trader_present(), "der Reiterwechsel verabschiedet ihn nicht")
	m.free()

func test_the_raven_is_not_affected() -> void:
	_shop_ready()
	Game.visitors.raven_slot = -1
	assert_true(Game.raven_waiting())
	assert_true(Game.buy_from_trader(Game.trader_offer()[0]))
	Game.close_shop()
	assert_true(Game.raven_waiting(), "der Rabe haengt nicht am Laden")

# --- Beutel -------------------------------------------------------------------

func _bag(m: Control) -> PanelBase:
	return m.get_node("SidePanel/Panels/FishGroup/PotionScroll/PotionPanel")

func test_the_bag_sits_with_the_fish_not_in_the_shop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	assert_true(m.has_node("SidePanel/Panels/FishGroup/PotionScroll"), "der Beutel fehlt im Inventar")
	assert_false(m.has_node("SidePanel/Panels/ShopGroup/PotionScroll"), "er haengt noch im Laden")
	m.free()

func test_the_bag_switches_between_categories() -> void:
	Game.new_game()
	Game.consumable_counts[&"schimmer_phiole"] = 2
	Game.consumable_counts[&"tiefenlot"] = 1
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	var bag := _bag(m)
	bag.refresh()
	var all := _texts(bag)
	assert_true(_has(all, "Schimmer-Phiole") and _has(all, "Tiefenlot"),
		"unter Alle muss beides stehen")

	bag._category = &"schimmer"
	bag.refresh()
	var only := _texts(bag)
	assert_true(_has(only, "Schimmer-Phiole"), "die gewaehlte Kategorie fehlt")
	assert_false(_has(only, "Tiefenlot"), "eine fremde Kategorie wird mitgezeigt")
	m.free()

## Leere Faecher gehoeren nicht in einen Beutel.
func test_the_bag_only_offers_categories_it_holds() -> void:
	Game.new_game()
	Game.consumable_counts.clear()
	Game.consumable_counts[&"schimmer_phiole"] = 1
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	var bag := _bag(m)
	bag.refresh()
	var buttons := 0
	for t in _texts(bag):
		if t in ["Alle", "Schimmer", "Lockstoff", "Handel", "Erfahrung", "Seltenheit", "Besonderes"]:
			buttons += 1
	assert_eq(buttons, 2, "erwartet waren nur Alle und Schimmer")
	m.free()

# --- Regen in der Weltliste ---------------------------------------------------

## Prueft die Ein-Zonen-Regel an der Anzeige: nie zwei Schirme, und wenn es
## gerade nirgends regnet, auch keiner. Ob der Schirm bei der RICHTIGEN Zone
## steht, entscheidet die Uhr -- das prueft test_weather.gd an der Quelle.
func test_the_world_list_marks_at_most_the_one_rainy_zone() -> void:
	Game.new_game()
	for id in Database.zones:
		if not Game.unlocked_zones.has(id):
			Game.unlocked_zones.append(id)
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	var panel: PanelBase = m.get_node("SidePanel/Panels/WorldGroup/WorldScroll/WorldPanel")
	panel.refresh()
	var marked := 0
	for t in _texts(panel):
		if "☂" in t:
			marked += 1
	var expected := 1 if Game.rain_zone() != &"" else 0
	assert_eq(marked, expected, "der Regen steht falsch in der Liste")
	m.free()

func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		out.append_array(_texts(c))
	return out

func _has(texts: Array[String], needle: String) -> bool:
	for t in texts:
		if needle in t:
			return true
	return false

# --- Sortierung der Fischliste -------------------------------------------------

func _stock() -> void:
	Game.new_game()
	Game.ctx.inventory.capacity = 50
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", -1.5, false))
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 3.2, false))
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.5, false))

func test_sorting_by_rank_puts_the_best_on_top() -> void:
	_stock()
	var all: Array[int] = [0, 1, 2]
	var by_rank := FishSort.sorted(all, &"rang")
	assert_eq(by_rank[0], 1, "der beste Rang steht nicht oben")
	assert_eq(by_rank[2], 0, "der schlechteste steht nicht unten")

func test_sorting_by_catch_keeps_the_order_of_catching() -> void:
	_stock()
	var all: Array[int] = [0, 1, 2]
	assert_eq(FishSort.sorted(all, &"fang"), all, "Fang darf nichts umstellen")

## Sortiert werden Indizes -- eine umgestellte Liste zeigte sonst beim
## Verkaufen auf den falschen Fisch.
func test_sorting_leaves_the_inventory_itself_alone() -> void:
	_stock()
	var before := Game.ctx.inventory.fish.duplicate()
	FishSort.sorted([0, 1, 2] as Array[int], &"gewicht")
	assert_eq(Game.ctx.inventory.fish, before, "die Kiste selbst wurde umsortiert")

func test_the_chosen_order_is_remembered() -> void:
	_stock()
	Game.settings.fish_sort = &"wert"
	var blob := SaveManager.serialize()
	blob["last_seen_unix"] = int(Time.get_unix_time_from_system()) + 3600
	Game.new_game()
	SaveManager.deserialize(blob)
	assert_eq(Game.settings.fish_sort, &"wert", "die Sortierung wird nicht gemerkt")

func test_nonsense_in_the_save_falls_back() -> void:
	var s := Settings.new()
	s.load_dict({"fish_sort": "nach_laune"})
	assert_eq(s.fish_sort, &"fang", "ein unbekannter Schluessel muss zurueckfallen")

func test_the_inventory_shows_the_switch_and_uses_it() -> void:
	_stock()
	Game.settings.fish_sort = &"rang"
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	var panel: PanelBase = m.get_node("SidePanel/Panels/FishGroup/FishScroll/FishPanel")
	panel.refresh()
	var texts := _texts(panel)
	for label in FishSort.LABELS.values():
		assert_true(_has(texts, label), "der Knopf %s fehlt" % label)
	m.free()
