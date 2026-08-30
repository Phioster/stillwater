extends TestCase

## Sunset Coast benutzte den Hintergrund von Willow Lake, und die Wasserfarben
## standen fest im Code. Geprueft wird, dass die Zone die Optik bestimmt --
## nicht, wie die Bilder aussehen.

func _world() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Control = load("res://scenes/fishing/world.tscn").instantiate()
	tree.root.add_child(world)
	return world

func test_lake_uses_the_lake_look() -> void:
	Game.new_game()
	var world := _world()
	assert_true(world.get_node("Background").texture != null, "kein Hintergrund geladen")
	assert_eq(world.get_node("WaterBody").color, Palette.get_color(&"reed_dark"))
	world.free()

func test_travelling_to_the_coast_changes_background_and_water() -> void:
	Game.new_game()
	var world := _world()
	var lake_texture: Texture2D = world.get_node("Background").texture
	Game.unlocked_zones = [&"willow_lake", &"sunset_coast"]
	assert_true(Game.travel_to(&"sunset_coast"), "Reise zur Kueste schlug fehl")
	assert_true(world.get_node("Background").texture != lake_texture,
		"der Hintergrund blieb der des Sees")
	assert_eq(world.get_node("WaterBody").color, Palette.get_color(&"sand_dark"))
	var crest: Color = world.get_node("WaterLine").default_color
	var expected := Palette.get_color(&"sea_foam")
	assert_true(Color(crest.r, crest.g, crest.b) == Color(expected.r, expected.g, expected.b),
		"die Schaumkrone muss die Kuestenfarbe tragen")
	assert_almost_eq(crest.a, 0.85, 0.001, "die Krone bleibt leicht durchscheinend")
	world.free()

## Jede Zone muss ihr Hintergrundbild auch wirklich haben -- ein Tippfehler in
## background_id waere sonst erst auf dem Geraet als leeres Bild sichtbar.
func test_every_zone_has_its_background_file() -> void:
	for id in Database.zones:
		var path := "res://assets/art/bg_%s.png" % Database.zones[id].background_id
		assert_true(TextureLoader.load_texture(path) != null,
			"fehlt: %s (Zone %s)" % [path, id])

## Die dritte Zone ist dunkel und kühl -- der Gegensatz zu See und Küste.
## Geprüft wird, dass sie überhaupt eigene Farben hat, nicht wie schön sie sind.
func test_the_moor_has_its_own_look() -> void:
	var moor: ZoneData = Database.zones[&"night_moor"]
	var lake: ZoneData = Database.zones[&"willow_lake"]
	assert_true(moor.background_id != lake.background_id, "gleicher Hintergrund wie der See")
	assert_true(moor.shore_key != lake.shore_key, "gleiches Ufer wie der See")
	assert_true(TextureLoader.load_texture("res://assets/art/bg_%s.png" % moor.background_id) != null)

## Jede Zone muss teurer und später sein als die davor -- sonst ist die
## Reihenfolge im Journal willkürlich und das Freischalten kein Fortschritt.
func test_zones_get_steadily_harder_to_reach() -> void:
	var zones: Array[ZoneData] = []
	for id in Database.zones:
		zones.append(Database.zones[id])
	zones.sort_custom(func(a: ZoneData, b: ZoneData) -> bool: return a.unlock_level < b.unlock_level)
	for i in range(1, zones.size()):
		assert_true(zones[i].unlock_cost > zones[i - 1].unlock_cost,
			"%s kostet nicht mehr als %s" % [zones[i].id, zones[i - 1].id])
		assert_true(zones[i].unlock_level > zones[i - 1].unlock_level,
			"%s kommt nicht später als %s" % [zones[i].id, zones[i - 1].id])
