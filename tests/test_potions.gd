extends TestCase

## Tränke sind reine Faktoren auf Zahlen, die es schon gibt. Geprüft wird,
## dass jede Wirkung wirklich ankommt -- ein Trank, der nichts tut, wäre
## verkauftes Nichts.

func _fresh() -> void:
	Game.new_game()
	Game.ctx.player_level = 60
	Game.coins = 5_000_000
	Game.buffs.active.clear()
	Game.consumable_counts.clear()
	Game.apply_buffs()

func _drink(id: StringName) -> void:
	assert_true(Game.buy_consumable(id, 1), "%s liess sich nicht kaufen" % id)
	assert_true(Game.use_consumable(id), "%s liess sich nicht trinken" % id)

func test_every_potion_actually_changes_something() -> void:
	for c in Database.consumables_in_order():
		var acts := c.shiny_mult != 1.0 or c.value_mult != 1.0 or c.xp_mult != 1.0 \
			or c.bite_time_mult != 1.0 or c.fight_time_mult != 1.0 \
			or not c.rarity_weight_bonus.is_empty() or c.rank_shift != 0 \
			or c.free_bait or c.ignore_time_of_day
		assert_true(acts, "%s hat gar keine Wirkung" % c.id)
		assert_true(c.duration > 0.0, "%s wirkt null Sekunden" % c.id)
		assert_true(c.cost > 0, "%s ist umsonst" % c.id)

func test_drinking_reaches_the_simulation() -> void:
	_fresh()
	_drink(&"schimmer_elixier")
	assert_almost_eq(Game.ctx.shiny_bonus, 8.0, 0.001, "der Schimmerfaktor kommt nicht an")
	_fresh()
	_drink(&"wert_trank")
	assert_almost_eq(Game.ctx.consumable_bonus, 1.3, 0.001)
	_fresh()
	_drink(&"koeder_elixier")
	assert_almost_eq(Game.ctx.bite_bonus, 0.2, 0.001)

## Gleiche Gruppe ersetzt sich, statt sich zu stapeln -- sonst legte man drei
## Stufen desselben Effekts uebereinander.
func test_the_same_group_replaces_instead_of_stacking() -> void:
	_fresh()
	_drink(&"schimmer_phiole")
	_drink(&"schimmer_elixier")
	assert_eq(Game.buffs.active.size(), 1, "es laufen zwei Traenke derselben Gruppe")
	assert_almost_eq(Game.ctx.shiny_bonus, 8.0, 0.001, "der zuletzt getrunkene muss gelten")

func test_different_groups_do_stack() -> void:
	_fresh()
	_drink(&"schimmer_phiole")
	_drink(&"wert_phiole")
	assert_eq(Game.buffs.active.size(), 2)
	assert_almost_eq(Game.ctx.shiny_bonus, 2.0, 0.001)
	assert_almost_eq(Game.ctx.consumable_bonus, 1.15, 0.001)

func test_a_potion_runs_out_and_stops_working() -> void:
	_fresh()
	_drink(&"schimmer_phiole")
	Game.buffs.tick(899.0)
	assert_true(Game.buffs.is_active(&"schimmer_phiole"), "kurz vor Schluss wirkt er noch")
	Game.buffs.tick(2.0)
	assert_false(Game.buffs.is_active(&"schimmer_phiole"))
	Game.apply_buffs()
	assert_almost_eq(Game.ctx.shiny_bonus, 1.0, 0.001, "nach Ablauf muss die Wirkung weg sein")

func test_without_stock_nothing_is_drunk() -> void:
	_fresh()
	assert_false(Game.use_consumable(&"schimmer_phiole"), "ohne Vorrat darf nichts wirken")
	assert_true(Game.buffs.active.is_empty())

func test_a_locked_potion_cannot_be_bought() -> void:
	_fresh()
	Game.ctx.player_level = 1
	var late: ConsumableData = Database.consumables[&"legendaer_elixier"]
	assert_true(late.unlock_level > 1)
	assert_false(Game.buy_consumable(late.id, 1))

## Der Sparhaken haengt an unserem Koederverbrauch -- den gibt es in der
## Referenz gar nicht.
func test_the_bait_saver_stops_consumption() -> void:
	_fresh()
	var bait := BaitData.new()
	bait.id = &"test"
	Game.ctx.bait = bait
	Game.ctx.fallback_bait = bait
	Game.ctx.bait_counts = {&"test": 5}
	Game.ctx.consume_bait()
	assert_eq(int(Game.ctx.bait_counts[&"test"]), 4, "ohne Trank wird verbraucht")
	_drink(&"sparhaken")
	Game.ctx.bait = bait
	Game.ctx.bait_counts = {&"test": 5}
	Game.ctx.consume_bait()
	assert_eq(int(Game.ctx.bait_counts[&"test"]), 5, "mit Sparhaken darf nichts verbraucht werden")

## Das Tiefenlot hebt den Rang -- moeglich nur, weil bei uns der Koeder ihn
## bestimmt und nicht der Zufall.
func test_the_sounding_lead_raises_the_rank() -> void:
	_fresh()
	var bait := BaitData.new()
	bait.unlimited = true
	bait.rank_probabilities = {2: 1.0}
	Game.ctx.bait = bait
	assert_eq(Game.ctx.pull_rank(StillRNG.new(1)), 2)
	_drink(&"tiefenlot")
	assert_eq(Game.ctx.pull_rank(StillRNG.new(1)), 3, "der Rang muss um eine Stufe steigen")

## Das Mondglas hebt Tageszeit-Bedingungen auf -- unsere eigene Achse.
func test_the_moon_glass_opens_the_night_fish() -> void:
	_fresh()
	var c := TimeOfDayCondition.new()
	c.from_hour = 22
	c.to_hour = 4
	Game.ctx.hour_of_day = 12
	assert_false(c.is_met(Game.ctx.condition_state()), "mittags beisst er nicht")
	_drink(&"mondglas")
	assert_true(c.is_met(Game.ctx.condition_state()), "mit Mondglas schon")

func test_potions_survive_a_save_and_load() -> void:
	_fresh()
	Game.buy_consumable(&"wert_trank", 3)
	_drink(&"schimmer_phiole")
	var blob := SaveManager.serialize()
	blob["last_seen_unix"] = int(Time.get_unix_time_from_system()) + 3600

	Game.new_game()
	Game.buffs.active.clear()
	Game.consumable_counts.clear()
	SaveManager.deserialize(blob)
	assert_true(Game.buffs.is_active(&"schimmer_phiole"), "der laufende Trank ist weg")
	assert_almost_eq(Game.ctx.shiny_bonus, 2.0, 0.001, "die Wirkung wurde nicht wiederhergestellt")
	assert_eq(Game.consumable_count(&"wert_trank"), 3, "der Vorrat ist weg")
