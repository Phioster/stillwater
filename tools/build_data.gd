extends SceneTree

func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("konnte %s nicht speichern: %d" % [path, err])
	else:
		# ResourceSaver.save() setzt resource_path nicht selbst - ohne das hier
		# landet der Fisch beim Einbetten in ZoneData.fish als Kopie statt als Referenz.
		res.resource_path = path
		print("  ", path)

func _rarity(id: StringName, name: String, color: Color, v: float, x: float, s: float, bias: float) -> RarityData:
	var r := RarityData.new()
	r.id = id
	r.display_name = name
	r.color = color
	r.value_mult = v
	r.xp_mult = x
	r.strength_mult = s
	r.quality_bias = bias
	_save(r, "res://data/rarities/%s.tres" % id)
	return r

func _fish(id: StringName, name: String, zone: StringName, rarity: StringName,
		value: int, strength: float, xp: int, wmin: float, wmax: float,
		spawn: float = 1.0) -> FishData:
	var f := FishData.new()
	f.id = id
	f.display_name = name
	f.zone_id = zone
	f.rarity_id = rarity
	f.base_value = value
	f.strength = strength
	f.xp = xp
	f.weight_min = wmin
	f.weight_max = wmax
	f.spawn_weight = spawn
	_save(f, "res://data/fish/%s.tres" % id)
	return f

func _init() -> void:
	# Kein await nötig: dieser Seeder legt Resources an und liest keine Autoloads.
	print("Raritäten")
	_rarity(&"common",    "Gewöhnlich", Color("9aa79f"),  1.0,  1.0,  1.0, 0.00)
	_rarity(&"uncommon",  "Ungewöhnlich", Color("5fa77c"), 2.5,  2.0,  2.2, 0.10)
	_rarity(&"rare",      "Selten",     Color("4f8fd0"),  7.0,  4.5,  4.5, 0.20)
	_rarity(&"epic",      "Episch",     Color("9a6fd0"), 20.0, 10.0,  8.0, 0.30)
	_rarity(&"legendary", "Legendär",   Color("d8a24a"), 60.0, 25.0, 14.0, 0.40)

	print("Köder")
	var grub := BaitData.new()
	grub.id = &"pond_grub"
	grub.display_name = "Teichmade"
	grub.cost = 0
	grub.unlimited = true
	grub.max_stack = 0
	grub.unlock_level = 1
	_save(grub, "res://data/bait/pond_grub.tres")

	var nymph := BaitData.new()
	nymph.id = &"mayfly_nymph"
	nymph.display_name = "Eintagsfliegen-Nymphe"
	nymph.cost = 15
	nymph.max_stack = 99
	nymph.unlock_level = 1
	nymph.rarity_weight_bonus = {&"uncommon": 1.4, &"rare": 2.2}
	_save(nymph, "res://data/bait/mayfly_nymph.tres")

	print("Fische Willow Lake")
	var willow: Array[FishData] = [
		_fish(&"bluegill",       "Bluegill",       &"willow_lake", &"common",    8, 12.0,  4, 0.05, 0.35, 1.0),
		_fish(&"roach",          "Rotauge",        &"willow_lake", &"common",   10, 15.0,  5, 0.10, 0.80, 1.0),
		_fish(&"perch",          "Flussbarsch",    &"willow_lake", &"uncommon", 22, 32.0, 12, 0.15, 1.20, 1.0),
		_fish(&"mirror_carp",    "Spiegelkarpfen", &"willow_lake", &"uncommon", 30, 40.0, 16, 1.00, 6.50, 1.0),
		_fish(&"lantern_tench",  "Laternenschleie", &"willow_lake", &"rare",    85, 70.0, 40, 0.80, 3.50, 1.0),
	]

	var hollowfin := _fish(&"hollowfin", "Hohlflosse", &"willow_lake", &"rare", 400, 95.0, 200, 0.50, 2.00, 1.0)
	hollowfin.is_secret = true
	hollowfin.secret_chance = 0.02
	hollowfin.secret_hint = "Etwas meidet hier den gewöhnlichen Köder."
	var lvl := LevelCondition.new()
	lvl.min_level = 5
	var bait_cond := BaitCondition.new()
	bait_cond.bait_id = &"mayfly_nymph"
	hollowfin.conditions = [lvl, bait_cond]
	_save(hollowfin, "res://data/fish/hollowfin.tres")
	willow.append(hollowfin)

	print("Fische Sunset Coast")
	var coast: Array[FishData] = [
		_fish(&"mackerel",   "Makrele",      &"sunset_coast", &"common",    18, 20.0,  8, 0.30,  1.00, 1.0),
		_fish(&"garfish",    "Hornhecht",    &"sunset_coast", &"common",    24, 26.0, 10, 0.40,  1.60, 1.0),
		_fish(&"red_mullet", "Meerbarbe",    &"sunset_coast", &"uncommon",  55, 44.0, 26, 0.25,  1.40, 1.0),
		_fish(&"sea_bass",   "Wolfsbarsch",  &"sunset_coast", &"uncommon",  70, 52.0, 32, 1.00,  7.00, 1.0),
		_fish(&"ember_ray",  "Glutrochen",   &"sunset_coast", &"rare",     180, 88.0, 75, 2.00, 12.00, 1.0),
	]

	print("Zonen")
	var z1 := ZoneData.new()
	z1.id = &"willow_lake"
	z1.display_name = "Willow Lake"
	z1.fish = willow
	z1.bite_time_min = 25.0
	z1.bite_time_max = 45.0
	z1.fight_window = 20.0
	z1.rarity_weights = {&"common": 70.0, &"uncommon": 25.0, &"rare": 5.0}
	z1.unlock_cost = 0
	z1.unlock_level = 1
	_save(z1, "res://data/zones/willow_lake.tres")

	var z2 := ZoneData.new()
	z2.id = &"sunset_coast"
	z2.display_name = "Sunset Coast"
	z2.fish = coast
	z2.bite_time_min = 35.0
	z2.bite_time_max = 60.0
	z2.fight_window = 20.0
	z2.rarity_weights = {&"common": 50.0, &"uncommon": 32.0, &"rare": 18.0}
	z2.unlock_cost = 1500
	z2.unlock_level = 6
	_save(z2, "res://data/zones/sunset_coast.tres")

	print("Upgrades")
	var ups := [
		[&"rod_power",      "Rutenkraft",   "Zieht mehr Fischstärke pro Sekunde ab.",  50, 4.0,  2.0],
		[&"orb_power",      "Orb-Kraft",    "Mehr Schaden pro Tipp auf einen Orb.",    40, 6.0,  3.0],
		[&"fish_inventory", "Fischkiste",   "Mehr Platz für gefangene Fische.",        80, 20.0, 15.0],
		[&"bait_capacity",  "Ködertasche",  "Mehr Platz für gekaufte Köder.",          60, 30.0, 20.0],
	]
	for u in ups:
		var up := UpgradeData.new()
		up.id = u[0]
		up.display_name = u[1]
		up.description = u[2]
		up.base_cost = u[3]
		up.cost_growth = 1.6
		up.value_base = u[4]
		up.value_per_level = u[5]
		up.max_level = 50
		_save(up, "res://data/upgrades/%s.tres" % u[0])

	print("fertig")
	quit(0)
