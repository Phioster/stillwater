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
