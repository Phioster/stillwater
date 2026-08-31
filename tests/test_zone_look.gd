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

## Der Wurf war keine Bewegung: der Schwimmer blieb unsichtbar und tauchte am
## Ende an seiner Endstelle auf. Jetzt fliegt er einen Bogen -- geprüft wird,
## dass er sich überhaupt bewegt, oben ankommt und unten landet.
func _cast_world() -> Control:
	Game.new_game()
	Game.paused = true
	Game.sim = FishingSim.new()
	Game.sim.tick(0.01, Game.ctx, StillRNG.new(1))
	var w := _world()
	w.size = Vector2(1280, 720)
	w._layout()
	return w

func test_the_bobber_flies_an_arc_while_casting() -> void:
	var w := _cast_world()
	assert_eq(Game.sim.state, FishingSim.State.CASTING, "der Wurf muss laufen")
	var seen: Array[Vector2] = []
	for i in 5:
		Game.sim.timer = FishingSim.CAST_TIME * (1.0 - float(i) / 4.0)
		w._process(0.0)
		assert_true(w.get_node("Bobber").visible, "der Schwimmer muss beim Wurf zu sehen sein")
		seen.append(w.get_node("Bobber").position)
	# Er muss sich bewegen, nicht springen.
	for i in range(1, seen.size()):
		assert_true(seen[i] != seen[i - 1], "der Schwimmer steht still")
	# Ein Bogen ist eine Woelbung gegenueber der VERBINDUNGSLINIE, nicht
	# gegenueber der Rutenspitze -- ein Wurf muss nicht ueber den Kopf gehen.
	var from: Vector2 = seen[0]
	var to: Vector2 = seen[seen.size() - 1]
	var bulge := 0.0
	for i in range(1, seen.size() - 1):
		var t := float(i) / float(seen.size() - 1)
		var on_chord := from.lerp(to, t)
		bulge = maxf(bulge, on_chord.y - seen[i].y)
	assert_true(bulge > 30.0, "der Wurf ist eine gerade Linie, Woelbung nur %f" % bulge)
	w.free()

func test_the_line_follows_the_bobber_during_the_cast() -> void:
	var w := _cast_world()
	Game.sim.timer = FishingSim.CAST_TIME * 0.5
	w._process(0.0)
	var line: Line2D = w.get_node("Line")
	assert_true(line.visible, "die Schnur muss beim Wurf zu sehen sein")
	assert_eq(line.points.size(), 2)
	assert_true(line.points[1].is_equal_approx(w.get_node("Bobber").position),
		"die Schnur endet nicht am Schwimmer")

## Beim Wurf zeigt der Angler Bild 2, dessen Rutenspitze tiefer liegt. Die
## Schnur muss trotzdem AN der Rute beginnen -- mit einer festen Konstante
## hing sie in der Luft.
func test_the_line_starts_at_the_rod_in_every_pose() -> void:
	var w := _cast_world()
	var angler = w.get_node("Angler")
	var line: Line2D = w.get_node("Line")
	for state in [FishingSim.State.CASTING, FishingSim.State.FIGHT, FishingSim.State.WAITING]:
		Game.sim.state = state
		w._process(0.0)
		if not line.visible:
			continue
		assert_true(line.points[0].is_equal_approx(angler.rod_tip()),
			"Zustand %d: Schnur beginnt bei %s, die Rute endet bei %s"
			% [state, line.points[0], angler.rod_tip()])
	w.free()

## Die Spitze muss sich zwischen den Posen überhaupt bewegen -- sonst wäre die
## Rechnung eine verkleidete Konstante.
func test_the_rod_tip_moves_between_poses() -> void:
	var w := _cast_world()
	var angler = w.get_node("Angler")
	angler.play_state(0)
	var idle: Vector2 = angler.rod_tip()
	angler.play_state(4)
	var cast: Vector2 = angler.rod_tip()
	assert_true(not idle.is_equal_approx(cast),
		"die Rutenspitze steht in jeder Pose gleich: %s" % idle)
	w.free()
