extends TestCase

## Die Bilanz zählt nur mit. Geprüft wird, dass jeder Zähler auch wirklich
## hochgeht -- ein Zähler, der stehenbleibt, ist schlimmer als keiner: er
## behauptet etwas.

func _fresh() -> void:
	Game.new_game()
	Game.ctx.player_level = 60
	Game.coins = 1_000_000
	Game.records = Records.new()
	Game.buffs.active.clear()
	Game.consumable_counts.clear()
	Game.visitors = Visitors.new()

func test_catching_and_escaping_are_counted() -> void:
	_fresh()
	var caught := CaughtFish.make(&"bluegill", 0.0, true)
	Game._dispatch([{"type": "caught", "caught": caught, "fish": Database.fish[&"bluegill"],
		"xp": 1, "discovered": true, "record": true, "new_rank": true, "stored": true}])
	assert_eq(Game.records.fish_caught, 1)
	assert_eq(Game.records.shiny_caught, 1, "der Schimmer wird nicht mitgezaehlt")
	Game._dispatch([{"type": "escaped", "fish": Database.fish[&"bluegill"]}])
	assert_eq(Game.records.fish_escaped, 1)
	Game._dispatch([{"type": "cast"}])
	assert_eq(Game.records.casts, 1)

func test_spending_is_counted_wherever_it_happens() -> void:
	_fresh()
	var before := Game.records.coins_spent
	Game.upgrade_levels[&"trader"] = 1
	Game.buy_bait(&"mayfly_nymph", 5)
	assert_true(Game.records.coins_spent > before, "Koederkauf faellt nicht auf")
	before = Game.records.coins_spent
	Game.buy_upgrade(&"rod_power")
	assert_true(Game.records.coins_spent > before, "Ausbau faellt nicht auf")
	before = Game.records.coins_spent
	Game.reroll_trader()
	assert_true(Game.records.coins_spent > before, "Neuwuerfeln faellt nicht auf")

func test_earning_is_counted() -> void:
	_fresh()
	Game.ctx.inventory.capacity = 20
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 1.0, false))
	var earned := Game.sell_all()
	assert_eq(Game.records.coins_earned, earned)
	assert_true(Game.records.fish_sold > 0, "verkaufte Fische fehlen")

func test_drinking_and_quests_are_counted() -> void:
	_fresh()
	Game.upgrade_levels[&"trader"] = 1
	Game.buy_consumable(&"wert_phiole", 1)
	Game.use_consumable(&"wert_phiole")
	assert_eq(Game.records.potions_drunk, 1)

	Game.upgrade_levels[&"quests"] = 2
	Game.ctx.inventory.capacity = 20
	var id := Game.quest_offer()[0]
	Game.ctx.inventory.add(CaughtFish.make(id, 0.0, false))
	assert_true(Game.hand_in_quest(id))
	assert_eq(Game.records.quests_done, 1)

func test_playtime_grows_and_reads_as_text() -> void:
	_fresh()
	Game.records.playtime = 3.0 * 3600.0 + 12.0 * 60.0
	assert_eq(Game.records.playtime_text(), "3 h 12 min")
	Game.records.playtime = 90.0
	assert_eq(Game.records.playtime_text(), "1 min")

func test_records_survive_a_save_and_load() -> void:
	_fresh()
	Game.records.fish_caught = 42
	Game.records.coins_earned = 12345
	Game.records.playtime = 999.0
	var blob := SaveManager.serialize()
	blob["last_seen_unix"] = int(Time.get_unix_time_from_system()) + 3600
	Game.new_game()
	Game.records = Records.new()
	SaveManager.deserialize(blob)
	assert_eq(Game.records.fish_caught, 42)
	assert_eq(Game.records.coins_earned, 12345)
	assert_almost_eq(Game.records.playtime, 999.0, 0.001)

## Ein alter Spielstand ohne Bilanz darf nicht abstuerzen.
func test_a_save_without_records_falls_back_to_zero() -> void:
	var r := Records.new()
	r.load_dict({})
	assert_eq(r.fish_caught, 0)
	r.load_dict({"fish_caught": "viele", "coins_earned": 7})
	assert_eq(r.fish_caught, 0, "Unsinn darf nichts setzen")
	assert_eq(r.coins_earned, 7)

## Die Seite muss die Zahlen auch zeigen.
func test_the_page_shows_the_numbers() -> void:
	_fresh()
	Game.records.fish_caught = 77
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	m.show_tab(1)
	var panel: PanelBase = m.get_node("SidePanel/Panels/JournalGroup/RecordScroll/RecordPanel")
	panel.refresh()
	var text := ""
	for l in _labels(panel):
		text += l + "\n"
	assert_true("77" in text, "die Fangzahl steht nicht auf der Seite")
	assert_true("Gespielt" in text, "die Spielzeit fehlt")
	m.free()

func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		out.append_array(_labels(c))
	return out
