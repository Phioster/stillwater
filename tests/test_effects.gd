extends TestCase

## Effekte zeigen nur an -- sie duerfen den Baum weder dauerhaft fuellen
## noch laufen, waehrend niemand hinschaut. Genau das wird hier geprueft,
## nicht das Aussehen der Partikel selbst.
##
## Bewusst ohne "await" in einer geprueften Codezeile: run_tests.gd ruft
## suite.call(name) ohne await auf, eine Assertion nach einem await in der
## Testfunktion wuerde also nie ausgewertet, bevor "ok"/"FAIL" gedruckt wird
## (an test_panel_base.gd mit einem absichtlich falschen Sentinel-Wert
## nachgestellt und bestaetigt -- siehe Bericht). add_child() ruft _ready()
## synchron auf, wenn der Elternknoten schon im Baum steckt, ein Frame
## abzuwarten ist deshalb hier nicht noetig.

const POP_TEXT_SCENE := preload("res://scenes/effects/pop_text.tscn")
const BURST_SCENE := preload("res://scenes/effects/burst.tscn")

func _world() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Control = load("res://scenes/fishing/world.tscn").instantiate()
	tree.root.add_child(world)
	return world

func _fish_and_catch() -> Array:
	Game.new_game()
	var fish: FishData = Database.fish[&"bluegill"]
	var c := CaughtFish.make(&"bluegill", 0.4, false)
	return [fish, c]

func test_pop_text_and_burst_free_themselves_after_their_lifetime() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var pop: Label = POP_TEXT_SCENE.instantiate()
	tree.root.add_child(pop)
	pop.setup("B", Vector2.ZERO, Color.WHITE)

	var burst: Node2D = BURST_SCENE.instantiate()
	tree.root.add_child(burst)
	burst.setup_splash(Vector2.ZERO)

	# Direkter Aufruf statt echter Wartezeit -- dieselbe Idee wie orb.gd.
	pop._process(5.0)
	burst._process(5.0)
	assert_true(pop.is_queued_for_deletion(), "PopText muss nach Ablauf der Lebenszeit sich selbst entfernen")
	assert_true(burst.is_queued_for_deletion(), "Burst muss nach Ablauf der Lebenszeit sich selbst entfernen")
	pop.free()
	burst.free()

func test_a_catch_creates_exactly_one_text_and_one_particle_effect_and_both_clean_up() -> void:
	var world := _world()
	var effects: Control = world.get_node("Effects")
	var pair := _fish_and_catch()

	Game.caught.emit(pair[1], pair[0], false, false)
	var children := effects.get_children()
	assert_eq(children.size(), 2, "ein Fang muss genau einen Text und einen Partikeleffekt erzeugen")

	for child in children:
		child._process(5.0)
	for child in children:
		assert_true(child.is_queued_for_deletion(),
			"muss nach Ablauf der Lebenszeit sich selbst aus dem Baum entfernen")
	world.free()

func test_many_caught_events_in_one_frame_do_not_grow_the_tree_unbounded() -> void:
	var world := _world()
	var effects: Control = world.get_node("Effects")
	var pair := _fish_and_catch()

	# Der Offline-Fall: viele caught-Ereignisse im selben Frame (kein await
	# dazwischen), wie es ein grosser time_scale-Tick auf einmal ausloest.
	for i in 50:
		Game.caught.emit(pair[1], pair[0], false, false)
	assert_true(effects.get_child_count() <= 10,
		"50 caught-Ereignisse in einem Frame duerfen den Baum nicht ungebremst fuellen, war %d" % effects.get_child_count())
	world.free()

func test_no_effect_spawns_while_the_world_is_invisible() -> void:
	var world := _world()
	var effects: Control = world.get_node("Effects")
	var pair := _fish_and_catch()

	world.visible = false
	Game.caught.emit(pair[1], pair[0], false, false)
	Game.coins = Game.coins + 50
	assert_eq(effects.get_child_count(), 0, "eine unsichtbare Weltszene darf keinen neuen Effekt erzeugen")
	world.free()

func test_selling_creates_a_pop_text_but_spending_does_not() -> void:
	# Erst Game.coins auf den Ausgangswert bringen, dann erst die Welt (und
	# damit Effects) erzeugen -- sonst zaehlt der Sprung beim Aufsetzen selbst
	# schon als "Anstieg" und verfaelscht die Zaehlung unten.
	Game.new_game()
	Game.coins = 100
	var world := _world()
	var effects: Control = world.get_node("Effects")

	Game.coins = 150  # steigt -- ein Verkauf
	assert_eq(effects.get_child_count(), 1, "ein Anstieg der Münzen muss eine aufsteigende Zahl zeigen")

	Game.coins = 80  # sinkt -- ein Kauf, kein Verkauf
	assert_eq(effects.get_child_count(), 1, "ein Sinken der Münzen darf keine weitere Zahl erzeugen")
	world.free()
