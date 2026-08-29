extends TestCase

func _rarity(id: StringName) -> RarityData:
	var r := RarityData.new()
	r.id = id
	return r

func _fish(id: StringName, rarity: StringName, weight: float = 1.0) -> FishData:
	var f := FishData.new()
	f.id = id
	f.rarity_id = rarity
	f.spawn_weight = weight
	f.weight_min = 1.0
	f.weight_max = 2.0
	return f

func _secret(id: StringName, chance: float, min_level: int, bait: StringName) -> FishData:
	var f := _fish(id, &"rare")
	f.is_secret = true
	f.secret_chance = chance
	var lc := LevelCondition.new()
	lc.min_level = min_level
	var bc := BaitCondition.new()
	bc.bait_id = bait
	f.conditions = [lc, bc]
	return f

func _ctx(fish: Array[FishData], bait_id: StringName = &"pond_grub", level: int = 1) -> SimContext:
	var zone := ZoneData.new()
	zone.id = &"willow_lake"
	zone.fish = fish
	zone.rarity_weights = {&"common": 70.0, &"uncommon": 25.0, &"rare": 5.0}
	var bait := BaitData.new()
	bait.id = bait_id
	var ctx := SimContext.new()
	ctx.zone = zone
	ctx.bait = bait
	ctx.fallback_bait = bait
	ctx.player_level = level
	ctx.rarities = {
		&"common": _rarity(&"common"),
		&"uncommon": _rarity(&"uncommon"),
		&"rare": _rarity(&"rare"),
	}
	ctx.inventory = Inventory.new()
	ctx.journal = Journal.new()
	return ctx

func test_rarity_distribution_follows_zone_weights() -> void:
	var fish: Array[FishData] = [_fish(&"c", &"common"), _fish(&"u", &"uncommon"), _fish(&"r", &"rare")]
	var ctx := _ctx(fish)
	var rng := StillRNG.new(42)
	var counts := {&"c": 0, &"u": 0, &"r": 0}
	for i in 10000:
		counts[FishingSim.select_fish(ctx, rng).id] += 1
	assert_between(float(counts[&"c"]) / 10000.0, 0.66, 0.74)
	assert_between(float(counts[&"u"]) / 10000.0, 0.21, 0.29)
	assert_between(float(counts[&"r"]) / 10000.0, 0.03, 0.07)

func test_bait_bonus_shifts_rarity() -> void:
	var fish: Array[FishData] = [_fish(&"c", &"common"), _fish(&"u", &"uncommon"), _fish(&"r", &"rare")]
	var ctx := _ctx(fish, &"mayfly_nymph")
	ctx.bait.rarity_weight_bonus = {&"uncommon": 1.4, &"rare": 2.2}
	var rng := StillRNG.new(43)
	var rare := 0
	for i in 10000:
		if FishingSim.select_fish(ctx, rng).id == &"r":
			rare += 1
	# 5 * 2.2 = 11 von (70 + 35 + 11) = 116 → rund 9,5 %
	assert_between(float(rare) / 10000.0, 0.07, 0.12)

func test_spawn_weight_splits_within_rarity() -> void:
	var fish: Array[FishData] = [_fish(&"c1", &"common", 3.0), _fish(&"c2", &"common", 1.0)]
	var ctx := _ctx(fish)
	ctx.zone.rarity_weights = {&"common": 1.0}
	var rng := StillRNG.new(44)
	var first := 0
	for i in 8000:
		if FishingSim.select_fish(ctx, rng).id == &"c1":
			first += 1
	assert_between(float(first) / 8000.0, 0.71, 0.79)

func test_preferred_bait_doubles_spawn_weight() -> void:
	var a := _fish(&"c1", &"common", 1.0)
	a.preferred_baits = [&"mayfly_nymph"]
	var fish: Array[FishData] = [a, _fish(&"c2", &"common", 1.0)]
	var ctx := _ctx(fish, &"mayfly_nymph")
	ctx.zone.rarity_weights = {&"common": 1.0}
	var rng := StillRNG.new(45)
	var first := 0
	for i in 8000:
		if FishingSim.select_fish(ctx, rng).id == &"c1":
			first += 1
	assert_between(float(first) / 8000.0, 0.63, 0.71)

func test_secret_never_appears_when_conditions_unmet() -> void:
	var fish: Array[FishData] = [_fish(&"c", &"common"), _secret(&"hollowfin", 1.0, 5, &"mayfly_nymph")]
	var ctx := _ctx(fish, &"pond_grub", 9)  # Level passt, Köder nicht
	var rng := StillRNG.new(46)
	for i in 3000:
		assert_eq(FishingSim.select_fish(ctx, rng).id, &"c")

func test_secret_appears_when_all_conditions_met() -> void:
	var fish: Array[FishData] = [_fish(&"c", &"common"), _secret(&"hollowfin", 1.0, 5, &"mayfly_nymph")]
	var ctx := _ctx(fish, &"mayfly_nymph", 5)
	var rng := StillRNG.new(47)
	assert_eq(FishingSim.select_fish(ctx, rng).id, &"hollowfin", "Chance 1.0 muss immer treffen")

func test_secret_is_excluded_from_normal_table() -> void:
	var fish: Array[FishData] = [_fish(&"r", &"rare"), _secret(&"hollowfin", 0.0, 1, &"pond_grub")]
	var ctx := _ctx(fish)
	ctx.zone.rarity_weights = {&"rare": 1.0}
	var rng := StillRNG.new(48)
	for i in 3000:
		assert_eq(FishingSim.select_fish(ctx, rng).id, &"r", "Chance 0.0 heißt nie, auch nicht über die Raritätstabelle")

func test_consume_bait_falls_back_when_empty() -> void:
	var ctx := _ctx([_fish(&"c", &"common")], &"mayfly_nymph")
	var basic := BaitData.new()
	basic.id = &"pond_grub"
	basic.unlimited = true
	ctx.fallback_bait = basic
	ctx.bait_counts = {&"mayfly_nymph": 1}
	ctx.consume_bait()
	assert_eq(ctx.bait_counts[&"mayfly_nymph"], 0)
	assert_eq(ctx.bait.id, &"pond_grub", "leerer Köder muss auf den Grundköder zurückfallen")

func test_unlimited_bait_is_never_consumed() -> void:
	var ctx := _ctx([_fish(&"c", &"common")], &"pond_grub")
	ctx.bait.unlimited = true
	ctx.bait_counts = {}
	ctx.consume_bait()
	assert_eq(ctx.bait.id, &"pond_grub")

func test_disabled_fish_rarity_is_never_drawn() -> void:
	var off := _fish(&"u", &"uncommon", 0.0)
	var fish: Array[FishData] = [_fish(&"c", &"common"), off]
	var ctx := _ctx(fish)
	ctx.zone.rarity_weights = {&"common": 1.0, &"uncommon": 1.0}
	var rng := StillRNG.new(50)
	for i in 3000:
		var result := FishingSim.select_fish(ctx, rng)
		assert_true(result != null, "select_fish darf nicht null liefern, wenn ein ziehbarer Fisch existiert")
		assert_eq(result.id, &"c", "eine Rarität, deren einziger Fisch spawn_weight 0 hat, darf nie gezogen werden")

func test_empty_zone_returns_null() -> void:
	var ctx := _ctx([])
	var rng := StillRNG.new(51)
	assert_eq(FishingSim.select_fish(ctx, rng), null, "eine Zone ohne Fische darf nicht abstürzen")
