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
	var health: ProgressBar = v.get_node("Panel/Box/Strength")
	var time: ProgressBar = v.get_node("Panel/Box/Line")
	assert_true(v.get_node("Panel").visible, "die Anzeige muss im Kampf sichtbar sein")
	assert_almost_eq(health.max_value, Game.sim.hooked_max_health, 0.001,
		"die Leiste muss die Lebenspunkte des Fisches zeigen")
	assert_true(health.max_value > 0.0, "ohne Lebenspunkte ist die Leiste sinnlos")
	assert_almost_eq(time.max_value, Game.sim.hooked_max_time, 0.001,
		"das Zeitfenster haengt am Rang, nicht an der Zone")
	v.free()

func test_the_health_bar_falls_when_the_fish_takes_damage() -> void:
	_into_a_fight()
	var v := _view()
	v._process(0.0)
	var health: ProgressBar = v.get_node("Panel/Box/Strength")
	var before: float = health.value
	Game.sim.tap(Game.ctx)
	v._process(0.0)
	assert_true(health.value < before,
		"ein Tipp muss die Leiste sichtbar senken (vorher %f, nachher %f)" % [before, health.value])
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
	for child in area.get_children():
		if child is Label:
			found = (child as Label).text
	assert_eq(found, "-%d" % int(round(Game.ctx.orb_power)),
		"es muss eine Schadenszahl stehen")
	v.free()
