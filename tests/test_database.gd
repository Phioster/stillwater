extends TestCase

func test_all_content_loads() -> void:
	assert_eq(Database.rarities.size(), 5)
	assert_eq(Database.baits.size(), 8)
	assert_eq(Database.fish.size(), 105)
	assert_eq(Database.zones.size(), 7)
	assert_eq(Database.upgrades.size(), 7)

func test_validate_reports_no_problems() -> void:
	var problems := Database.validate()
	assert_eq(problems.size(), 0, "Probleme: %s" % str(problems))

func test_willow_lake_has_its_full_roster_including_the_secret() -> void:
	var f := Database.fish_of_zone(&"willow_lake")
	assert_eq(f.size(), 16)
	var secrets := 0
	for x in f:
		if x.is_secret:
			secrets += 1
	assert_eq(secrets, 3)

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
	# FishingSim würfelt über zone.fish - ohne diese Identität würde sie mit
	# veralteten Kopien statt den aktuellen data/fish/*.tres-Werten rechnen.
	for zone_id in Database.zones:
		var z: ZoneData = Database.zones[zone_id]
		for zf: FishData in z.fish:
			var db_f: FishData = Database.fish[zf.id]
			assert_true(db_f == zf, "Fisch %s: Zone-Kopie ist nicht dieselbe Instanz wie Database.fish" % zf.id)
			assert_eq(db_f.resource_path, zf.resource_path, "Fisch %s: unterschiedlicher resource_path" % zf.id)

## Epic und Legendary standen lange nur in den Raritaetsdaten: kein Fisch
## trug sie, keine Zone gewichtete sie. Beide Haelften muessen stimmen,
## sonst ist die Stufe wieder unerreichbar.
func test_every_rarity_has_fish_and_zone_weight() -> void:
	var used: Dictionary = {}
	for id in Database.fish:
		used[Database.fish[id].rarity_id] = true
	for rid in Database.rarities:
		assert_true(used.has(rid), "keine Art hat die Raritaet %s" % rid)
		var weighted := false
		for zid in Database.zones:
			if Database.zones[zid].rarity_weights.has(rid):
				weighted = true
		assert_true(weighted, "keine Zone gewichtet die Raritaet %s" % rid)

## Die zweite Zone darf nicht dünner sein als die erste -- sonst fühlt sich
## das Freischalten wie ein Rückschritt an.
func test_no_zone_is_much_thinner_than_the_starting_zone() -> void:
	var counts: Dictionary = {}
	for zid in Database.zones:
		counts[zid] = Database.fish_of_zone(zid).size()
	var start := int(counts[&"willow_lake"])
	for zid in counts:
		assert_true(int(counts[zid]) >= start - 2,
			"%s hat nur %d Arten, Willow Lake hat %d" % [zid, counts[zid], start])

## Jede Zone braucht in jeder gewichteten Rarität auch wirklich Fische --
## sonst greift die Gewichtung ins Leere und die Auswahl fällt zurück.
func test_every_weighted_rarity_has_fish_in_that_zone() -> void:
	for zid in Database.zones:
		var z: ZoneData = Database.zones[zid]
		var present: Dictionary = {}
		for f in z.fish:
			present[f.rarity_id] = true
		for rid in z.rarity_weights:
			if float(z.rarity_weights[rid]) <= 0.0:
				continue
			assert_true(present.has(rid),
				"%s gewichtet %s, hat dort aber keine Art" % [zid, rid])

## Achtzehn Tränke: zwölf nach dem Vorbild (vier Wirkungen mal drei Stufen),
## drei Raritäts-Elixiere, drei eigene.
func test_the_potion_range_is_complete() -> void:
	assert_eq(Database.consumables.size(), 18)
	for group in ["schimmer", "koeder", "erfahrung", "wert"]:
		var tiers := 0
		for id in Database.consumables:
			if Database.consumables[id].group == StringName(group):
				tiers += 1
		assert_eq(tiers, 3, "Gruppe %s hat %d Stufen statt drei" % [group, tiers])

## Innerhalb einer Gruppe muss die teurere Stufe auch stärker sein, sonst
## kauft man sich schlechter.
func test_a_dearer_tier_is_always_stronger() -> void:
	for group in ["schimmer", "erfahrung", "wert"]:
		var tiers: Array[ConsumableData] = []
		for c in Database.consumables_in_order():
			if c.group == StringName(group):
				tiers.append(c)
		for i in range(1, tiers.size()):
			assert_true(tiers[i].cost > tiers[i - 1].cost, "%s: Preis steigt nicht" % group)
			var a := maxf(maxf(tiers[i - 1].shiny_mult, tiers[i - 1].xp_mult), tiers[i - 1].value_mult)
			var b := maxf(maxf(tiers[i].shiny_mult, tiers[i].xp_mult), tiers[i].value_mult)
			assert_true(b > a, "%s: die teurere Stufe ist nicht stärker" % group)

## Der Lockstoff wirkt andersherum -- kleiner ist besser.
func test_the_bite_potion_gets_faster_with_each_tier() -> void:
	var tiers: Array[ConsumableData] = []
	for c in Database.consumables_in_order():
		if c.group == &"koeder":
			tiers.append(c)
	for i in range(1, tiers.size()):
		assert_true(tiers[i].bite_time_mult < tiers[i - 1].bite_time_mult,
			"die teurere Stufe beißt nicht schneller")
