extends TestCase

## Die Kampfanzeige greift ueber Game.sim auf Felder zu, die kein
## Kompilierlauf pruefen kann: ein umbenanntes Feld faellt erst zur Laufzeit
## auf. Genau das ist beim Umbau auf Lebenspunkte passiert. Dieser Test
## faehrt einen echten Kampf und liest die Leisten ab.

func _view() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var v: Control = load("res://scenes/fishing/catch_view.tscn").instantiate()
	tree.root.add_child(v)
	return v

## Bringt das Spiel in einen laufenden Kampf und gibt den erwarteten Rang zurück.
func _into_a_fight() -> void:
	Game.new_game()
	Game.paused = true
	Game.sim = FishingSim.new()
	Game.sim.tick(200.0, Game.ctx, StillRNG.new(4))
	while Game.sim.state != FishingSim.State.FIGHT:
		Game.sim.tick(1.0, Game.ctx, StillRNG.new(4))

func test_the_bars_show_health_and_time_of_the_hooked_fish() -> void:
	_into_a_fight()
	var v := _view()
	v._process(0.0)
	var health: GhostBar = v._health
	var time: GhostBar = v._line
	assert_true(v.get_node("Panel").visible, "die Anzeige muss im Kampf sichtbar sein")
	assert_almost_eq(health.max_value(), Game.sim.hooked_max_health, 0.001,
		"die Leiste muss die Lebenspunkte des Fisches zeigen")
	assert_true(health.max_value() > 0.0, "ohne Lebenspunkte ist die Leiste sinnlos")
	assert_almost_eq(time.max_value(), Game.sim.hooked_max_time, 0.001,
		"das Zeitfenster haengt am Rang, nicht an der Zone")
	v.free()

func test_the_health_bar_falls_when_the_fish_takes_damage() -> void:
	_into_a_fight()
	var v := _view()
	v._process(0.0)
	var health: GhostBar = v._health
	var before: float = health.value()
	Game.sim.tap(Game.ctx)
	v._process(0.0)
	assert_true(health.value() < before,
		"ein Tipp muss die Leiste sichtbar senken (vorher %f, nachher %f)" % [before, health.value()])
	v.free()

func test_the_name_line_carries_the_rank() -> void:
	_into_a_fight()
	var v := _view()
	v._on_bite(Game.sim.hooked)
	var text: String = v.get_node("Panel/Box/FishName").text
	assert_true(Game.sim.hooked.display_name in text, "der Artname fehlt")
	assert_true("Rang" in text, "der Rang fehlt")
	assert_true(FishRoll.RANK_NAMES[Game.sim.hooked_rank] in text, "der falsche Rang steht da")
	v.free()

## Der Schaden muss als Zahl auftauchen, sonst ist nicht zu sehen, dass
## Tippen wirkt -- und damit nicht, wozu die Orb-Kraft gut ist.
func test_tapping_an_orb_leaves_a_damage_number() -> void:
	_into_a_fight()
	var v := _view()
	var area: Control = v.get_node("Orbs")
	v._spawn_orb()
	var orb: Node = area.get_child(0)
	v._on_orb_tapped(orb)
	var found := ""
	for child in v.get_node("Pops").get_children():
		if child is Label:
			found = (child as Label).text
	assert_eq(found, "-%d" % int(round(Game.ctx.orb_power)),
		"es muss eine Schadenszahl stehen")
	v.free()

## Die Schadenszahl darf den naechsten Punkt nicht aufhalten. Sie lag frueher
## im selben Container wie die Orbs und galt dort als lebender Punkt -- beim
## schnellen Tippen kam der Nachruecker dadurch ueber eine Sekunde zu spaet.
func test_a_damage_number_does_not_block_the_next_orb() -> void:
	_into_a_fight()
	var v := _view()
	var area: Control = v.get_node("Orbs")
	v._spawn_orb()
	v._on_orb_tapped(area.get_child(0))
	area.get_child(0).queue_free()
	assert_true(v.get_node("Pops").get_child_count() > 0, "die Schadenszahl fehlt")
	assert_eq(v._living_orbs(), 0, "eine Schadenszahl ist kein lebender Punkt")
	v.free()

## Schnelles Tippen darf nicht ausgebremst werden: nach einem Treffer muss der
## naechste Punkt binnen ORB_RESPAWN stehen.
func test_the_next_orb_follows_within_the_respawn_window() -> void:
	_into_a_fight()
	var v := _view()
	var area: Control = v.get_node("Orbs")
	v._spawn_orb()
	v._on_orb_tapped(area.get_child(0))
	area.get_child(0).free()
	v._process(v.ORB_RESPAWN + 0.001)
	assert_eq(v._living_orbs(), 1, "der naechste Punkt muss sofort nachruecken")
	v.free()

## Der abgezogene Streifen muss sichtbar bleiben: nach einem Treffer liegt
## die nachziehende Haelfte ueber der vorderen. Ohne diesen Test waere die
## Doppelleiste durch eine gewoehnliche ersetzbar, ohne dass es auffaellt.
func test_a_hit_leaves_a_visible_ghost_stripe() -> void:
	_into_a_fight()
	var v := _view()
	v._on_bite(Game.sim.hooked)
	v._process(0.0)
	Game.sim.tap(Game.ctx)
	v._process(0.0)
	assert_true(v._health._ghost.value > v._health._front.value,
		"nach einem Treffer muss der abgezogene Streifen noch stehen")
	v.free()

## Jeder Rutenschlag muss eine Zahl hinterlassen -- sonst arbeitet die Rute
## unsichtbar und niemand sieht, wofuer Rutenkraft gut ist.
func test_a_rod_pulse_leaves_a_damage_number() -> void:
	_into_a_fight()
	var v := _view()
	v._on_bite(Game.sim.hooked)
	v._process(0.0)
	var before := v.get_node("Pops").get_child_count()
	Game.sim.tick(1.05, Game.ctx, StillRNG.new(4))
	assert_true(Game.sim.rod_hits > 0, "die Rute muss geschlagen haben")
	v._process(0.0)
	assert_true(v.get_node("Pops").get_child_count() > before,
		"der Rutenschlag hat keine Zahl hinterlassen")
	v.free()

## Nach einem Offline-Nachlauf steht der Zaehler bei hunderten Schlaegen.
## Dann darf die Anzeige NICHT hunderte Zahlen werfen.
func test_a_huge_jump_in_rod_hits_does_not_flood_the_screen() -> void:
	_into_a_fight()
	var v := _view()
	v._on_bite(Game.sim.hooked)
	v._process(0.0)
	Game.sim.rod_hits = 500
	v._process(0.0)
	assert_true(v.get_node("Pops").get_child_count() <= 3,
		"es haengen %d Zahlen im Baum" % v.get_node("Pops").get_child_count())
	assert_eq(v._seen_rod_hits, 500, "der Zaehler muss trotzdem nachgezogen werden")
	v.free()

## Alle Zahlen erscheinen an derselben Stelle neben der Leiste, damit das
## Auge nicht dem Finger hinterherspringt.
func test_damage_numbers_appear_next_to_the_bar_not_at_the_orb() -> void:
	_into_a_fight()
	var v := _view()
	v._on_bite(Game.sim.hooked)
	var area: Control = v.get_node("Orbs")
	v._spawn_orb()
	var orb: Control = area.get_child(0)
	orb.position = Vector2(900.0, 40.0)
	v._on_orb_tapped(orb)
	var pop: Control = v.get_node("Pops").get_child(0)
	assert_true(absf(pop.position.x - orb.position.x) > 100.0,
		"die Zahl klebt am Orb statt an der Leiste")

## Die Ansage muss auch wirklich in der Zeile stehen.
func test_the_name_line_calls_for_hands_when_the_rod_is_not_enough() -> void:
	Game.new_game()
	Game.paused = true
	Game.sim = FishingSim.new()
	Game.sim.tick(200.0, Game.ctx, StillRNG.new(11))
	while Game.sim.state != FishingSim.State.FIGHT:
		Game.sim.tick(1.0, Game.ctx, StillRNG.new(11))
	Game.sim.needs_hands = true
	var v := _view()
	v._on_bite(Game.sim.hooked)
	assert_true("antippen" in v.get_node("Panel/Box/FishName").text,
		"die Aufforderung fehlt")
	Game.sim.needs_hands = false
	v._on_bite(Game.sim.hooked)
	assert_false("antippen" in v.get_node("Panel/Box/FishName").text,
		"die Aufforderung steht da, obwohl die Rute reicht")
	v.free()
