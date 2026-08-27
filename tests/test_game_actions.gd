extends TestCase

func _fresh() -> void:
	Game.new_game()

func test_new_game_starts_in_willow_lake_with_basic_bait() -> void:
	_fresh()
	assert_eq(Game.ctx.zone.id, &"willow_lake")
	assert_true(Game.ctx.bait.unlimited)
	assert_eq(Game.coins, 0)
	assert_eq(Game.ctx.player_level, 1)

func test_upgrade_values_come_from_data() -> void:
	_fresh()
	assert_almost_eq(Game.upgrade_value(&"rod_power"), 4.0)
	assert_eq(Game.upgrade_cost(&"rod_power"), 50)

func test_buying_an_upgrade_costs_coins_and_raises_the_value() -> void:
	_fresh()
	Game.coins = 100
	assert_true(Game.buy_upgrade(&"rod_power"))
	assert_eq(Game.coins, 50)
	assert_almost_eq(Game.upgrade_value(&"rod_power"), 6.0)
	assert_almost_eq(Game.ctx.rod_power, 6.0, 0.0001, "der Kontext muss mitziehen")

func test_upgrade_is_refused_without_coins() -> void:
	_fresh()
	Game.coins = 10
	assert_false(Game.buy_upgrade(&"rod_power"))
	assert_eq(Game.coins, 10)

func test_inventory_upgrade_raises_capacity() -> void:
	_fresh()
	Game.coins = 100
	assert_eq(Game.ctx.inventory.capacity, 20)
	Game.buy_upgrade(&"fish_inventory")
	assert_eq(Game.ctx.inventory.capacity, 35)

func test_sell_all_pays_and_empties_the_inventory() -> void:
	_fresh()
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.35, 2, false))
	var earned := Game.sell_all()
	assert_true(earned > 0)
	assert_eq(Game.coins, earned)
	assert_eq(Game.ctx.inventory.fish.size(), 0)

func test_sell_all_keeps_favorites() -> void:
	_fresh()
	var keeper := CaughtFish.make(&"bluegill", 0.35, 2, false)
	keeper.is_favorite = true
	Game.ctx.inventory.add(keeper)
	Game.ctx.inventory.add(CaughtFish.make(&"roach", 0.5, 2, false))
	Game.sell_all()
	assert_eq(Game.ctx.inventory.fish.size(), 1)
	assert_true(Game.ctx.inventory.fish[0].is_favorite)

func test_journal_survives_selling() -> void:
	_fresh()
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 0.35, 2, false))
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.35, 2, false))
	Game.sell_all()
	assert_true(Game.ctx.journal.is_discovered(&"bluegill"), "verkaufen darf die Sammlung nicht löschen")

func test_buying_bait_respects_capacity() -> void:
	_fresh()
	Game.coins = 10000
	assert_true(Game.buy_bait(&"mayfly_nymph", 10))
	assert_eq(int(Game.ctx.bait_counts[&"mayfly_nymph"]), 10)
	assert_eq(Game.coins, 10000 - 150)
	assert_false(Game.buy_bait(&"mayfly_nymph", 1000), "über die Ködertasche hinaus geht nichts")

## bait_cost() ist die einzige Stelle, die den Preis kennt -- buy_bait() muss
## exakt so viel abziehen, wie bait_cost() für dieselbe Menge nennt.
func test_bait_cost_matches_what_buy_bait_actually_charges() -> void:
	_fresh()
	assert_eq(Game.bait_cost(&"mayfly_nymph", 10), 150)
	Game.coins = 10000
	Game.buy_bait(&"mayfly_nymph", 10)
	assert_eq(Game.coins, 10000 - Game.bait_cost(&"mayfly_nymph", 10))

func test_bait_cost_for_unknown_bait_is_zero() -> void:
	_fresh()
	assert_eq(Game.bait_cost(&"nonexistent_bait", 5), 0)

func test_zone_two_needs_level_and_coins() -> void:
	_fresh()
	Game.coins = 5000
	assert_false(Game.unlock_zone(&"sunset_coast"), "Level 1 reicht nicht")
	Game.ctx.player_level = 6
	assert_true(Game.unlock_zone(&"sunset_coast"))
	assert_eq(Game.coins, 3500)
	assert_true(&"sunset_coast" in Game.unlocked_zones)

func test_travel_only_to_unlocked_zones() -> void:
	_fresh()
	assert_false(Game.travel_to(&"sunset_coast"))
	Game.coins = 5000
	Game.ctx.player_level = 6
	Game.unlock_zone(&"sunset_coast")
	assert_true(Game.travel_to(&"sunset_coast"))
	assert_eq(Game.ctx.zone.id, &"sunset_coast")

func test_apply_upgrades_is_idempotent() -> void:
	_fresh()
	Game.coins = 1000
	Game.buy_upgrade(&"rod_power")
	var v1 := Game.ctx.rod_power
	Game.apply_upgrades()
	Game.apply_upgrades()
	assert_almost_eq(Game.ctx.rod_power, v1, 0.0001, "zweimaliges Anwenden darf die Rutenkraft nicht doppelt wachsen lassen")

func test_coins_changed_fires_only_on_real_change() -> void:
	_fresh()
	var fire_count := [0]
	var handler := func(_c): fire_count[0] += 1
	Game.coins_changed.connect(handler)
	Game.coins = 100
	Game.coins = 100
	Game.coins_changed.disconnect(handler)
	assert_eq(fire_count[0], 1)

func test_caught_fires_exactly_once_per_catch() -> void:
	_fresh()
	var fish: FishData = Database.fish[&"bluegill"]
	Game.sim.state = FishingSim.State.FIGHT
	Game.sim.hooked = fish
	Game.sim.hooked_strength = 0.01
	Game.sim.hooked_max_strength = 0.01
	Game.sim.hooked_weight = 0.35
	Game.sim.hooked_quality = 2
	Game.sim.hooked_shiny = false
	var fire_count := [0]
	var handler := func(_c, _f): fire_count[0] += 1
	Game.caught.connect(handler)
	Game.tap()
	Game.caught.disconnect(handler)
	assert_eq(fire_count[0], 1)

func test_paused_actually_halts_the_simulation() -> void:
	_fresh()
	Game.paused = true
	var state_before := Game.sim.state
	for i in range(5):
		Game._process(1.0)
	assert_eq(Game.sim.state, state_before, "paused darf den Sim-Zustand nicht verändern")
	Game.paused = false
	Game._process(1.0)
	assert_true(Game.sim.state != state_before, "unpaused muss die Simulation weiterlaufen lassen")
	Game.paused = true

func test_sell_one_and_toggle_favorite_reject_out_of_range_indices() -> void:
	_fresh()
	assert_eq(Game.sell_one(0), 0, "leeres Inventar: jeder Index ist außerhalb")
	Game.toggle_favorite(0)
	assert_eq(Game.ctx.inventory.fish.size(), 0)

	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.35, 2, false))
	assert_eq(Game.sell_one(-1), 0)
	assert_eq(Game.sell_one(99), 0)
	Game.toggle_favorite(-1)
	Game.toggle_favorite(99)
	assert_eq(Game.ctx.inventory.fish.size(), 1, "Ablehnung darf das Inventar nicht verändern")
	assert_false(Game.ctx.inventory.fish[0].is_favorite, "ungültiger Index darf nichts umschalten")
