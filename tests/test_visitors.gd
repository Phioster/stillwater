extends TestCase

## Beide Besucher hängen an der Uhr, nicht an einem Countdown. Geprüft wird
## genau das: dieselbe Stunde gibt dasselbe, nichts verfällt beim Weggehen,
## und lange Abwesenheit häuft nichts an.

const HOUR := 3600.0
const FOUR := 14400.0

func _fresh() -> Visitors:
	return Visitors.new()

func test_the_same_hour_always_gives_the_same_offer() -> void:
	var v := _fresh()
	var a := v.mouse_offer(1000.0 * HOUR + 12.0, 3)
	var b := v.mouse_offer(1000.0 * HOUR + 3599.0, 3)
	assert_eq(a, b, "innerhalb einer Stunde muss das Angebot stehen")

func test_the_next_hour_gives_a_different_offer() -> void:
	var v := _fresh()
	var same := 0
	for h in 40:
		var a := v.mouse_offer(float(1000 + h) * HOUR, 3)
		var b := v.mouse_offer(float(1001 + h) * HOUR, 3)
		if a == b:
			same += 1
	assert_true(same < 20, "das Angebot wechselt kaum: %d von 40 Stunden gleich" % same)

func test_the_offer_has_no_duplicates() -> void:
	var v := _fresh()
	for h in 30:
		var offer := v.mouse_offer(float(500 + h) * HOUR, 5)
		var seen: Dictionary = {}
		for id in offer:
			assert_false(seen.has(id), "%s liegt doppelt aus" % id)
			seen[id] = true

## Billiges liegt oft aus, Teures selten -- sonst waere ein Legenden-Elixier
## jede Stunde zu haben und der Reiz weg.
func test_cheap_things_show_up_more_often_than_dear_ones() -> void:
	var v := _fresh()
	var cheap := 0
	var dear := 0
	for h in 300:
		for id in v.mouse_offer(float(h) * HOUR, 3):
			var c: ConsumableData = Database.consumables[id]
			if c.cost <= 600:
				cheap += 1
			elif c.cost >= 60000:
				dear += 1
	assert_true(cheap > dear * 3,
		"billig %d gegen teuer %d -- die Gewichtung greift nicht" % [cheap, dear])

func test_a_new_hour_clears_what_was_bought() -> void:
	var v := _fresh()
	v.refresh_mouse(100.0 * HOUR)
	v.mouse_buy(&"schimmer_phiole")
	assert_true(v.mouse_sold_out(&"schimmer_phiole"))
	assert_false(v.refresh_mouse(100.0 * HOUR + 60.0), "dieselbe Stunde wechselt nichts")
	assert_true(v.mouse_sold_out(&"schimmer_phiole"), "in derselben Stunde bleibt es verkauft")
	assert_true(v.refresh_mouse(101.0 * HOUR), "die naechste Stunde bringt ihn neu")
	assert_false(v.mouse_sold_out(&"schimmer_phiole"))

func test_rerolling_changes_the_offer() -> void:
	var v := _fresh()
	var before := v.mouse_offer(77.0 * HOUR, 3)
	v.reroll()
	var after := v.mouse_offer(77.0 * HOUR, 3)
	assert_true(before != after, "Neuwürfeln ändert nichts")

# --- Moewe --------------------------------------------------------------------

func test_a_package_waits_until_it_is_collected() -> void:
	var v := _fresh()
	var now := 50.0 * FOUR
	assert_true(v.package_waiting(now), "beim ersten Mal muss eins daliegen")
	assert_true(v.package_waiting(now + 100000.0), "es wartet, bis man es aufhebt")
	v.collect_package(now)
	assert_false(v.package_waiting(now), "danach ist es weg")

func test_a_long_absence_leaves_one_package_not_three() -> void:
	var v := _fresh()
	v.collect_package(10.0 * FOUR)
	# Zwoelf Stunden weg = drei Bloecke.
	var later := 13.0 * FOUR
	assert_true(v.package_waiting(later))
	v.collect_package(later)
	assert_false(v.package_waiting(later), "es darf sich nichts anhaeufen")

func test_the_gift_is_the_same_for_the_same_block() -> void:
	var v := _fresh()
	var a := v.package_gift(88.0 * FOUR + 5.0)
	var b := v.package_gift(88.0 * FOUR + 14000.0)
	assert_eq(a, b)
	assert_true(Database.consumables.has(a), "das Geschenk muss es geben")

func test_visitors_survive_a_save_and_load() -> void:
	var v := _fresh()
	v.refresh_mouse(200.0 * HOUR)
	# Erst wuerfeln, dann kaufen: ein neues Angebot loescht die
	# Verkauft-Liste, und das ist richtig so.
	v.reroll()
	v.mouse_buy(&"wert_phiole")
	v.collect_package(60.0 * FOUR)
	var back := Visitors.new()
	back.load_dict(v.to_dict())
	assert_eq(back.mouse_slot, v.mouse_slot)
	assert_true(back.mouse_sold_out(&"wert_phiole"))
	assert_eq(back.mouse_rerolls, v.mouse_rerolls)
	assert_eq(back.bird_slot, v.bird_slot)

## Der Laden fuehrt Traenke NICHT mehr -- sie kommen vom Haendler und der
## Moewe. Genau wie in der Referenz, deren Laden nur Ausbau und Koeder hat.
func test_buying_a_potion_needs_the_trader() -> void:
	Game.new_game()
	Game.ctx.player_level = 60
	Game.coins = 1_000_000
	Game.visitors = Visitors.new()
	var offer := Game.mouse_offer()
	assert_true(offer.size() > 0, "der Haendler hat nichts dabei")
	var not_offered := &""
	for c in Database.consumables_in_order():
		if not offer.has(c.id):
			not_offered = c.id
			break
	assert_false(Game.buy_from_mouse(not_offered),
		"was er nicht dabei hat, kann man nicht kaufen")
	assert_true(Game.buy_from_mouse(offer[0]))
	assert_eq(Game.consumable_count(offer[0]), 1)
	assert_false(Game.buy_from_mouse(offer[0]), "verkauft ist verkauft")

func test_the_package_lands_in_the_satchel() -> void:
	Game.new_game()
	Game.visitors = Visitors.new()
	assert_true(Game.package_waiting())
	var gift := Game.collect_package()
	assert_true(gift != &"", "das Paket war leer")
	assert_eq(Game.consumable_count(gift), 1)
	assert_false(Game.package_waiting())
	assert_eq(Game.collect_package(), &"", "zweimal aufheben geht nicht")

## Ein neues Angebot loescht, was verkauft war -- sonst waere ein Teil des
## frischen Angebots von Anfang an vergriffen.
func test_a_reroll_clears_the_sold_out_list() -> void:
	var v := _fresh()
	v.refresh_mouse(300.0 * HOUR)
	v.mouse_buy(&"schimmer_phiole")
	assert_true(v.mouse_sold_out(&"schimmer_phiole"))
	v.reroll()
	assert_false(v.mouse_sold_out(&"schimmer_phiole"))

## Die Besucher stehen in der Welt und sind nur zu sehen, wenn es etwas zu
## holen gibt -- ein Knopf, der nichts tut, ist Ballast.
func _world() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var w: Control = load("res://scenes/fishing/world.tscn").instantiate()
	tree.root.add_child(w)
	w.size = Vector2(1280, 720)
	w._layout()
	return w

func test_the_package_is_only_visible_when_one_waits() -> void:
	Game.new_game()
	Game.paused = true
	Game.visitors = Visitors.new()
	var w := _world()
	w._update_visitors()
	assert_true(w.get_node("Visitors/Package").visible, "das Paket fehlt")
	Game.collect_package()
	w._update_visitors()
	assert_false(w.get_node("Visitors/Package").visible, "es liegt noch da, obwohl geholt")
	w.free()

func test_tapping_the_package_puts_a_potion_in_the_satchel() -> void:
	Game.new_game()
	Game.paused = true
	Game.visitors = Visitors.new()
	Game.consumable_counts.clear()
	var w := _world()
	w._update_visitors()
	w._on_package_pressed()
	var total := 0
	for id in Game.consumable_counts:
		total += Game.consumable_count(id)
	assert_eq(total, 1, "im Beutel liegt nichts")
	w.free()

func test_the_trader_asks_the_menu_to_open() -> void:
	Game.new_game()
	Game.paused = true
	var w := _world()
	var seen := [0]
	w.visitor_tapped.connect(func() -> void: seen[0] += 1)
	w._on_mouse_pressed()
	assert_eq(seen[0], 1, "das Antippen meldet sich nicht")
	w.free()
