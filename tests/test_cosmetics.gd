extends TestCase

func _fresh() -> void:
	Game.new_game()

# --- Database ---------------------------------------------------------------

## Die Zahl steht hier bewusst fest: eine Variante, die beim Umbenennen still
## verschwindet, faellt sonst niemandem auf.
func test_every_cosmetic_variant_loads() -> void:
	assert_eq(Database.cosmetics.size(), 33)

## Die Haarfarbe ist die einzige Kategorie ohne eigenes Sprite: sie faerbt
## die Frisur ein. Gibt es mehr Farben als Toene, waehlt man stumm dieselbe.
func test_every_hair_colour_has_a_tint() -> void:
	var colours := 0
	for id in Database.cosmetics:
		if (Database.cosmetics[id] as CosmeticData).category == &"hair_color":
			colours += 1
	var angler = load("res://scenes/fishing/angler.tscn").instantiate()
	assert_eq(colours, angler.HAIR_TINTS.size(), "Farben und Toene laufen auseinander")
	angler.free()

## Die Rute ist eine echte Kategorie mit eigenem Sprite, keine Farbe.
func test_the_rod_is_worn_like_any_other_layer() -> void:
	_fresh()
	Game.ctx.player_level = 60
	Game.coins = 100_000
	assert_true(Game.buy_cosmetic(&"rod", 2), "die Silberrute ist nicht kaufbar")
	assert_true(Game.set_cosmetic(&"rod", 2))
	var angler = load("res://scenes/fishing/angler.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(angler)
	angler.set_cosmetics(Game.cosmetics)
	# Ueber die Bilddaten verglichen, nicht ueber resource_path: auf diesem
	# Geraet gibt es keinen Import-Cache, dort kommt die Textur aus einer
	# Bilddatei und hat gar keinen Pfad (siehe core/texture_loader.gd).
	var worn: Texture2D = angler.get_node("Rod").texture
	assert_true(worn != null, "es wird gar keine Rute getragen")
	var expected := TextureLoader.load_texture("res://assets/art/char_rod_2.png")
	assert_true(worn.get_image().get_data() == expected.get_image().get_data(),
		"getragen wird eine andere Rute als die gekaufte")
	angler.free()

## Ein Spielstand von vor der Rute darf nicht mit einer leeren Hand laden.
func test_an_older_save_without_a_rod_still_works() -> void:
	_fresh()
	var blob := SaveManager.serialize()
	blob["last_seen_unix"] = int(Time.get_unix_time_from_system()) + 3600
	(blob["cosmetics"] as Dictionary).erase("rod")
	SaveManager.deserialize(blob)
	assert_eq(int(Game.cosmetics.get("rod", 0)), 0, "die Rute faellt nicht auf 0 zurueck")

func test_cosmetics_validate_reports_no_problems() -> void:
	var problems := Database.validate()
	assert_eq(problems.size(), 0, "Probleme: %s" % str(problems))

func test_cosmetic_of_finds_category_and_variant() -> void:
	var c := Database.cosmetic_of(&"hat", 2)
	assert_true(c != null)
	assert_eq(c.id, &"hat_2")

func test_cosmetic_of_returns_null_for_unknown_combo() -> void:
	assert_true(Database.cosmetic_of(&"hat", 99) == null)
	assert_true(Database.cosmetic_of(&"nonexistent", 0) == null)

func test_variant_zero_of_every_category_is_free() -> void:
	for category in [&"skin", &"hair", &"hair_color", &"shirt", &"pants", &"hat", &"rod"]:
		var c := Database.cosmetic_of(category, 0)
		assert_true(c != null, "Kategorie %s hat keine Variante 0" % category)
		assert_eq(c.cost, 0, "Variante 0 von %s muss frei sein" % category)

func test_validate_catches_a_category_missing_variant_zero() -> void:
	var fake := CosmeticData.new()
	fake.id = &"fake_broken"
	fake.category = &"skin"
	fake.variant = 7
	Database.cosmetics[&"fake_broken_only"] = fake
	# skin behaelt seine echte Variante 0 -- die fehlende muss von einer
	# ganz neuen Kategorie kommen, unabhaengig von der Dopplungspruefung.
	var lonely := CosmeticData.new()
	lonely.id = &"lonely_1"
	lonely.category = &"lonely_category"
	lonely.variant = 1
	Database.cosmetics[&"lonely_1"] = lonely
	var problems := Database.validate()
	Database.cosmetics.erase(&"fake_broken_only")
	Database.cosmetics.erase(&"lonely_1")
	var found := false
	for p in problems:
		if "lonely_category" in p:
			found = true
	assert_true(found, "fehlende Variante 0 einer Kategorie muss gemeldet werden")

func test_validate_catches_duplicate_category_variant_combo() -> void:
	var dupe := CosmeticData.new()
	dupe.id = &"skin_dupe"
	dupe.category = &"skin"
	dupe.variant = 0
	Database.cosmetics[&"skin_dupe"] = dupe
	var problems := Database.validate()
	Database.cosmetics.erase(&"skin_dupe")
	var found := false
	for p in problems:
		if "skin" in p and "0" in p:
			found = true
	assert_true(found, "doppelte Kategorie/Variante-Kombination muss gemeldet werden")

func test_validate_catches_missing_sprite() -> void:
	var ghost := CosmeticData.new()
	ghost.id = &"skin_ghost"
	ghost.category = &"skin"
	ghost.variant = 42
	Database.cosmetics[&"skin_ghost"] = ghost
	var problems := Database.validate()
	Database.cosmetics.erase(&"skin_ghost")
	var found := false
	for p in problems:
		if "skin_ghost" in p:
			found = true
	assert_true(found, "eine Variante ohne Sprite muss gemeldet werden")

# --- Game: Besitz, Kauf, Anziehen -------------------------------------------

func test_new_game_owns_exactly_the_six_free_variants() -> void:
	_fresh()
	for category in [&"skin", &"hair", &"hair_color", &"shirt", &"pants", &"hat"]:
		assert_true(Game.owns_cosmetic(category, 0), "Variante 0 von %s muss von Anfang an gehoeren" % category)
		assert_false(Game.owns_cosmetic(category, 1), "Variante 1 von %s darf nicht von Anfang an gehoeren" % category)

func test_cosmetic_cost_reads_from_database() -> void:
	_fresh()
	assert_eq(Game.cosmetic_cost(&"hat", 1), Database.cosmetic_of(&"hat", 1).cost)
	assert_eq(Game.cosmetic_cost(&"hat", 0), 0)

func test_cosmetic_cost_for_unknown_combo_is_zero() -> void:
	_fresh()
	assert_eq(Game.cosmetic_cost(&"hat", 99), 0)

func test_buy_cosmetic_without_enough_coins_changes_nothing() -> void:
	_fresh()
	Game.coins = 5
	Game.ctx.player_level = 10
	assert_false(Game.buy_cosmetic(&"hat", 1))
	assert_eq(Game.coins, 5)
	assert_false(Game.owns_cosmetic(&"hat", 1))

func test_buy_cosmetic_without_enough_level_changes_nothing() -> void:
	_fresh()
	Game.coins = 100000
	Game.ctx.player_level = 1
	assert_false(Game.buy_cosmetic(&"hat", 1))
	assert_eq(Game.coins, 100000)
	assert_false(Game.owns_cosmetic(&"hat", 1))

func test_buy_cosmetic_with_enough_coins_and_level_deducts_exact_price_and_grants_ownership() -> void:
	_fresh()
	Game.coins = 100000
	Game.ctx.player_level = 10
	var cost := Game.cosmetic_cost(&"hat", 1)
	assert_true(Game.buy_cosmetic(&"hat", 1))
	assert_eq(Game.coins, 100000 - cost)
	assert_true(Game.owns_cosmetic(&"hat", 1))

func test_buy_cosmetic_twice_is_refused_the_second_time() -> void:
	_fresh()
	Game.coins = 100000
	Game.ctx.player_level = 10
	assert_true(Game.buy_cosmetic(&"hat", 1))
	var coins_after_first_buy := Game.coins
	assert_false(Game.buy_cosmetic(&"hat", 1))
	assert_eq(Game.coins, coins_after_first_buy, "ein zweiter Kauf darf kein Geld nochmal abziehen")

func test_buy_cosmetic_for_unknown_combo_is_refused() -> void:
	_fresh()
	Game.coins = 100000
	assert_false(Game.buy_cosmetic(&"hat", 99))

func test_set_cosmetic_without_ownership_is_refused() -> void:
	_fresh()
	assert_false(Game.set_cosmetic(&"hat", 1))
	assert_eq(int(Game.cosmetics.get("hat", 0)), 0)

func test_set_cosmetic_after_purchase_succeeds() -> void:
	_fresh()
	Game.coins = 100000
	Game.ctx.player_level = 10
	Game.buy_cosmetic(&"hat", 1)
	assert_true(Game.set_cosmetic(&"hat", 1))
	assert_eq(int(Game.cosmetics.get("hat", 0)), 1)
	assert_eq(int(Game.ctx.cosmetics.get("hat", 0)), 1)

func test_buying_a_cosmetic_triggers_an_autosave() -> void:
	var original := SaveManager.SAVE_PATH
	SaveManager.SAVE_PATH = "user://test_cosmetics_autosave.json"
	SaveManager.delete_save()
	_fresh()
	Game.coins = 100000
	Game.ctx.player_level = 10
	Game.buy_cosmetic(&"hat", 1)
	assert_true(SaveManager.has_save(), "ein Kauf muss sofort speichern")
	SaveManager.delete_save()
	SaveManager.SAVE_PATH = original

# --- Review-Fix: cosmetic_state() als einzige Regelquelle ------------------

func test_cosmetic_state_unknown_for_missing_combo() -> void:
	_fresh()
	assert_eq(Game.cosmetic_state(&"hat", 99), Game.CosmeticState.UNKNOWN)

func test_cosmetic_state_owned_for_variant_zero() -> void:
	_fresh()
	assert_eq(Game.cosmetic_state(&"hat", 0), Game.CosmeticState.OWNED)

func test_cosmetic_state_locked_level_before_locked_coins() -> void:
	_fresh()
	Game.coins = 0
	Game.ctx.player_level = 1
	assert_eq(Game.cosmetic_state(&"hat", 2), Game.CosmeticState.LOCKED_LEVEL)

func test_cosmetic_state_locked_coins_once_level_is_reached() -> void:
	_fresh()
	Game.coins = 0
	Game.ctx.player_level = 10
	assert_eq(Game.cosmetic_state(&"hat", 1), Game.CosmeticState.LOCKED_COINS)

func test_cosmetic_state_buyable_with_level_and_coins() -> void:
	_fresh()
	Game.coins = 100000
	Game.ctx.player_level = 10
	assert_eq(Game.cosmetic_state(&"hat", 1), Game.CosmeticState.BUYABLE)

func test_cosmetic_state_owned_after_purchase() -> void:
	_fresh()
	Game.coins = 100000
	Game.ctx.player_level = 10
	Game.buy_cosmetic(&"hat", 1)
	assert_eq(Game.cosmetic_state(&"hat", 1), Game.CosmeticState.OWNED)

# --- Review-Fix: Variante 0 muss wirklich kostenlos und erreichbar sein ----

func test_validate_catches_a_priced_variant_zero() -> void:
	var priced_zero := CosmeticData.new()
	priced_zero.id = &"skin_zero_broken"
	priced_zero.category = &"skin"
	priced_zero.variant = 0
	priced_zero.cost = 100
	var real_skin_zero: CosmeticData = Database.cosmetics[&"skin_0"]
	Database.cosmetics[&"skin_0"] = priced_zero
	var problems := Database.validate()
	Database.cosmetics[&"skin_0"] = real_skin_zero
	var found := false
	for p in problems:
		if "skin" in p and "kostenlos" in p:
			found = true
	assert_true(found, "eine bepreiste Variante 0 muss gemeldet werden")
