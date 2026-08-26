extends TestCase

func test_all_content_loads() -> void:
	assert_eq(Database.rarities.size(), 5)
	assert_eq(Database.baits.size(), 2)
	assert_eq(Database.fish.size(), 11)
	assert_eq(Database.zones.size(), 2)
	assert_eq(Database.upgrades.size(), 4)

func test_validate_reports_no_problems() -> void:
	var problems := Database.validate()
	assert_eq(problems.size(), 0, "Probleme: %s" % str(problems))

func test_willow_lake_has_six_fish_including_the_secret() -> void:
	var f := Database.fish_of_zone(&"willow_lake")
	assert_eq(f.size(), 6)
	var secrets := 0
	for x in f:
		if x.is_secret:
			secrets += 1
	assert_eq(secrets, 1)

func test_basic_bait_is_unlimited_and_free() -> void:
	var b := Database.basic_bait()
	assert_true(b.unlimited)
	assert_eq(b.cost, 0)

func test_secret_fish_has_both_conditions() -> void:
	var h: FishData = Database.fish[&"hollowfin"]
	assert_true(h.is_secret)
	assert_eq(h.conditions.size(), 2)
	assert_almost_eq(h.secret_chance, 0.02)

func test_upgrade_cost_curve() -> void:
	var rod: UpgradeData = Database.upgrades[&"rod_power"]
	assert_eq(rod.cost_at(0), 50)
	assert_eq(rod.cost_at(1), 80)
	assert_almost_eq(rod.value_at(0), 4.0)
	assert_almost_eq(rod.value_at(3), 10.0)

func test_zone_two_is_gated() -> void:
	var z: ZoneData = Database.zones[&"sunset_coast"]
	assert_eq(z.unlock_level, 6)
	assert_eq(z.unlock_cost, 1500)

func test_zone_fish_are_the_same_instances_as_database_fish() -> void:
	# ZoneData.fish muss auf dieselben Resourcen zeigen wie Database.fish -
	# sonst würfelt FishingSim (das über zone.fish iteriert) mit veralteten
	# Werten, während Journal/UI (die über Database.fish gehen) die aktuellen
	# aus data/fish/*.tres zeigen.
	for zone_id in Database.zones:
		var z: ZoneData = Database.zones[zone_id]
		for zf: FishData in z.fish:
			var db_f: FishData = Database.fish[zf.id]
			assert_true(db_f == zf, "Fisch %s: Zone-Kopie ist nicht dieselbe Instanz wie Database.fish" % zf.id)
			assert_eq(db_f.resource_path, zf.resource_path, "Fisch %s: unterschiedlicher resource_path" % zf.id)
