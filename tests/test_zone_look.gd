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
	# Der Streifen traegt den Uferton der Zone, abgedunkelt auf das Ende der
	# gemalten Uferbande -- der Faktor steht in world.gd, nicht hier.
	assert_eq(world.get_node("WaterBody").color,
		Palette.get_color(&"reed_dark").darkened(world.SHORE_STRIP_DARKEN))
	world.free()

func test_travelling_to_the_coast_changes_background_and_water() -> void:
	Game.new_game()
	var world := _world()
	var lake_texture: Texture2D = world.get_node("Background").texture
	Game.unlocked_zones = [&"willow_lake", &"sunset_coast"]
	assert_true(Game.travel_to(&"sunset_coast"), "Reise zur Kueste schlug fehl")
	assert_true(world.get_node("Background").texture != lake_texture,
		"der Hintergrund blieb der des Sees")
	assert_eq(world.get_node("WaterBody").color,
		Palette.get_color(&"sand_dark").darkened(world.SHORE_STRIP_DARKEN))
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
	# Der Flug beginnt erst beim Abwurf: davor haengt der Schwimmer an der
	# Rutenspitze, sonst flaege er los, waehrend sie noch ausholt. Geprueft
	# wird deshalb ab dem Abwurf.
	var los: float = w.CAST_RELEASE
	var seen: Array[Vector2] = []
	for i in 5:
		var fortschritt := los + (1.0 - los) * float(i) / 4.0
		Game.sim.timer = FishingSim.CAST_TIME * (1.0 - fortschritt)
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
	var punkte: int = w.LINE_POINTS
	assert_true(line.visible, "die Schnur muss beim Wurf zu sehen sein")
	## Seit dem Wurfbogen ist die Schnur eine Kurve und keine Gerade mehr:
	## LINE_POINTS Punkte, und wenn das Vorfach zu sehen ist, haengt darunter
	## noch einer. Das Ende der SCHNUR ist deshalb Punkt LINE_POINTS - 1.
	assert_true(line.points.size() == punkte or line.points.size() == punkte + 1,
		"die Schnur hat %d Punkte, erwartet %d oder %d mit Vorfach"
		% [line.points.size(), punkte, punkte + 1])
	assert_true(line.points[punkte - 1].is_equal_approx(w.get_node("Bobber").position),
		"die Schnur endet nicht am Schwimmer")
	if line.points.size() > punkte:
		assert_true(line.points[punkte].y > line.points[punkte - 1].y,
			"das Vorfach muss unter dem Schwimmer haengen")

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
	## Armzustand 0 ist die Ruhe, ab 1 laeuft der Wurf. Zustand 1 taugt hier
	## NICHT: er ist dasselbe Bild wie die Ruhe (sit3_arm_nah.png und
	## wurf_arm_0.png sind byteweise gleich), die Spitze steht also still.
	## Zustand 5 ist das weiteste Ausholen.
	angler.set_pose(0, 0, 0, 0, &"open", 0)
	var idle: Vector2 = angler.rod_tip()
	angler.set_pose(0, 0, 0, 0, &"open", 5)
	var cast: Vector2 = angler.rod_tip()
	assert_true(not idle.is_equal_approx(cast),
		"die Rutenspitze steht in jeder Pose gleich: %s" % idle)
	w.free()

## Vor dem Abwurf haengt der Schwimmer an der Rutenspitze und fliegt NICHT
## schon los -- er startete frueher im selben Augenblick, in dem sie erst
## ausholte, und war unten, bevor die Rute wieder herunterkam.
func test_the_bobber_waits_at_the_rod_tip_until_the_release() -> void:
	var w := _cast_world()
	var los: float = w.CAST_RELEASE
	assert_true(los > 0.0, "ohne Abwurfpunkt prueft der Test nichts")
	var spitze := Vector2.ZERO
	for i in 4:
		# Von Wurfbeginn bis kurz vor den Abwurf.
		var fortschritt := los * float(i) / 4.0
		Game.sim.timer = FishingSim.CAST_TIME * (1.0 - fortschritt)
		w._process(0.0)
		var p: Vector2 = w.get_node("Bobber").position
		if i == 0:
			spitze = p
		assert_true(p.distance_to(spitze) < 24.0,
			"der Schwimmer ist bei %d%% des Wurfs schon %d Punkte unterwegs"
				% [int(fortschritt * 100.0), p.distance_to(spitze)])
	w.free()

## Und er darf am Ende nicht in einem Satz ins Wasser fallen: der letzte
## Abschnitt des Flugs muss kuerzer sein als der erste, nicht laenger.
func test_the_bobber_settles_instead_of_dropping_at_the_end() -> void:
	var w := _cast_world()
	var los: float = w.CAST_RELEASE
	var punkte: Array[Vector2] = []
	for i in 5:
		var fortschritt := los + (1.0 - los) * float(i) / 4.0
		Game.sim.timer = FishingSim.CAST_TIME * (1.0 - fortschritt)
		w._process(0.0)
		punkte.append(w.get_node("Bobber").position)
	var erster := punkte[0].distance_to(punkte[1])
	var letzter := punkte[3].distance_to(punkte[4])
	w.free()
	assert_true(letzter < erster,
		"der Schwimmer legt zuletzt %d Punkte zurueck und zuerst nur %d -- er stuerzt"
			% [letzter, erster])

## Der Schwimmer muss sich NACH dem Umkehrpunkt loesen, nicht davor: im
## Schnalzen nach vorn, nicht mitten im Ausholen. Die beiden Zahlen stehen in
## verschiedenen Dateien (angler.gd und world.gd) und koennen sonst stumm
## auseinanderlaufen.
func test_the_bobber_releases_after_the_windup_peak() -> void:
	var angler := preload("res://scenes/fishing/angler.gd")
	var welt := preload("res://scenes/fishing/world.gd")
	var umkehr: float = angler.CAST_SWING * angler.CAST_WINDUP
	assert_true(welt.CAST_RELEASE >= umkehr,
		"der Abwurf liegt bei %.2f, der Umkehrpunkt erst bei %.2f"
			% [welt.CAST_RELEASE, umkehr])
	# Aber auch nicht erst, wenn der Schwung laengst vorbei ist.
	assert_true(welt.CAST_RELEASE <= angler.CAST_SWING,
		"der Abwurf liegt bei %.2f, der Schwung endet schon bei %.2f"
			% [welt.CAST_RELEASE, angler.CAST_SWING])

## Nach dem Kampf wird eingeholt wie bei Cornerpond: der Schwimmer steigt aus
## dem Wasser und endet an der Rutenspitze, der Fisch haengt daran.
func test_nach_dem_fang_wird_der_schwimmer_eingeholt() -> void:
	var w := _cast_world()
	Game.sim.timer = FishingSim.CAST_TIME + FishingSim.LAND_PAUSE
	var fisch: FishData = Database.fish.values()[0]
	w.einholen_beginnen(fisch)
	w._process(0.0)
	var start: Vector2 = w.get_node("Bobber").position
	assert_true(start.distance_to(w._angler.rod_tip()) > 100.0, "er beginnt draussen im Wasser")
	w._process(w.REEL_TIME * 0.5)
	assert_true(w.get_node("Bobber").position.y < start.y - 20.0, "er steigt aus dem Wasser")
	assert_true(w._haken_fisch.visible, "der Fisch haengt am Haken, aufgetaucht")
	w._process(w.REEL_TIME * 0.6)
	assert_true(w.get_node("Bobber").position.distance_to(w._angler.rod_tip()) < 1.0,
		"am Ende haengt er an der Rutenspitze")
	Game.sim.timer = FishingSim.CAST_TIME
	w._process(0.0)
	assert_false(w._haken_fisch.visible, "beim neuen Wurf ist der Fisch weg")
	w.free()

func test_nach_der_flucht_haengt_kein_fisch() -> void:
	var w := _cast_world()
	Game.sim.timer = FishingSim.CAST_TIME + FishingSim.LAND_PAUSE
	w.einholen_beginnen(null)
	w._process(0.0)
	assert_false(w._haken_fisch.visible)
	w.free()

## Fanganzeige und Kampfleiste stehen oben mittig. Die Rutenspitze reicht beim
## Ausholen bis y~106, nur wenige Punkte unter die Karte -- nachgerechnet, nicht
## geschaetzt, und hier festgehalten, falls Rute oder Figur wandern.
func test_die_rute_bleibt_unter_der_fanganzeige() -> void:
	var w := _cast_world()
	var toast = load("res://scenes/ui/catch_toast.gd")
	var view = load("res://scenes/fishing/catch_view.gd")
	var unterkante: float = maxf(toast.OBEN + toast.MASS.y, view.OBEN + view.MASS.y)
	var a = w._angler
	for arm in AnglerPose.ROD_STATES:
		a._arm = arm
		var tip: Vector2 = a.rod_tip()
		assert_true(tip.y > unterkante,
			"Zustand %d: Rutenspitze bei y=%d, die Karte endet bei %d" % [arm, tip.y, unterkante])
	w.free()

## Zieht der Fisch den Schwimmer unter Wasser, endet die Schnur an der
## Oberflaeche -- vorher lief sie sichtbar durchs Wasser bis zu seiner Mitte.
func test_die_schnur_endet_an_der_wasseroberflaeche() -> void:
	var w := _cast_world()
	var linie := 300.0
	assert_eq(w._schnur_ende(Vector2(500, 340), linie), Vector2(500, 300), "unter Wasser")
	assert_eq(w._schnur_ende(Vector2(500, 280), linie), Vector2(500, 280), "ueber Wasser")
	w.free()
