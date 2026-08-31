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
	var a := v.trader_offer(1000.0 * HOUR + 12.0, 3)
	var b := v.trader_offer(1000.0 * HOUR + 3599.0, 3)
	assert_eq(a, b, "innerhalb einer Stunde muss das Angebot stehen")

func test_the_next_hour_gives_a_different_offer() -> void:
	var v := _fresh()
	var same := 0
	for h in 40:
		var a := v.trader_offer(float(1000 + h) * HOUR, 3)
		var b := v.trader_offer(float(1001 + h) * HOUR, 3)
		if a == b:
			same += 1
	assert_true(same < 20, "das Angebot wechselt kaum: %d von 40 Stunden gleich" % same)

func test_the_offer_has_no_duplicates() -> void:
	var v := _fresh()
	for h in 30:
		var offer := v.trader_offer(float(500 + h) * HOUR, 5)
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
		for id in v.trader_offer(float(h) * HOUR, 3):
			var c: ConsumableData = Database.consumables[id]
			if c.cost <= 600:
				cheap += 1
			elif c.cost >= 60000:
				dear += 1
	assert_true(cheap > dear * 3,
		"billig %d gegen teuer %d -- die Gewichtung greift nicht" % [cheap, dear])

func test_a_new_hour_clears_what_was_bought() -> void:
	var v := _fresh()
	v.refresh_trader(100.0 * HOUR)
	v.trader_buy(&"schimmer_phiole")
	assert_true(v.sold_out(&"schimmer_phiole"))
	assert_false(v.refresh_trader(100.0 * HOUR + 60.0), "dieselbe Stunde wechselt nichts")
	assert_true(v.sold_out(&"schimmer_phiole"), "in derselben Stunde bleibt es verkauft")
	assert_true(v.refresh_trader(101.0 * HOUR), "die naechste Stunde bringt ihn neu")
	assert_false(v.sold_out(&"schimmer_phiole"))

func test_rerolling_changes_the_offer() -> void:
	var v := _fresh()
	var before := v.trader_offer(77.0 * HOUR, 3)
	v.reroll()
	var after := v.trader_offer(77.0 * HOUR, 3)
	assert_true(before != after, "Neuwürfeln ändert nichts")

# --- Moewe --------------------------------------------------------------------

func test_a_raven_waits_until_it_is_collected() -> void:
	var v := _fresh()
	var now := 50.0 * FOUR
	assert_true(v.raven_waiting(now), "beim ersten Mal muss eins daliegen")
	assert_true(v.raven_waiting(now + 100000.0), "es wartet, bis man es aufhebt")
	v.collect_raven(now)
	assert_false(v.raven_waiting(now), "danach ist es weg")

func test_a_long_absence_leaves_one_raven_not_three() -> void:
	var v := _fresh()
	v.collect_raven(10.0 * FOUR)
	# Zwoelf Stunden weg = drei Bloecke.
	var later := 13.0 * FOUR
	assert_true(v.raven_waiting(later))
	v.collect_raven(later)
	assert_false(v.raven_waiting(later), "es darf sich nichts anhaeufen")

func test_the_gift_is_the_same_for_the_same_block() -> void:
	var v := _fresh()
	var a := v.raven_gift(88.0 * FOUR + 5.0)
	var b := v.raven_gift(88.0 * FOUR + 14000.0)
	assert_eq(a, b)
	assert_true(Database.consumables.has(a), "das Geschenk muss es geben")

func test_visitors_survive_a_save_and_load() -> void:
	var v := _fresh()
	v.refresh_trader(200.0 * HOUR)
	# Erst wuerfeln, dann kaufen: ein neues Angebot loescht die
	# Verkauft-Liste, und das ist richtig so.
	v.reroll()
	v.trader_buy(&"wert_phiole")
	v.collect_raven(60.0 * FOUR)
	var back := Visitors.new()
	back.load_dict(v.to_dict())
	assert_eq(back.trader_slot, v.trader_slot)
	assert_true(back.sold_out(&"wert_phiole"))
	assert_eq(back.trader_rerolls, v.trader_rerolls)
	assert_eq(back.raven_slot, v.raven_slot)

## Der Laden fuehrt Traenke NICHT mehr -- sie kommen vom Haendler und der
## Moewe. Genau wie in der Referenz, deren Laden nur Ausbau und Koeder hat.
func test_buying_a_potion_needs_the_trader() -> void:
	Game.new_game()
	Game.ctx.player_level = 60
	Game.coins = 1_000_000
	Game.visitors = Visitors.new()
	Game.upgrade_levels[&"trader"] = 1
	var offer := Game.trader_offer()
	assert_true(offer.size() > 0, "der Haendler hat nichts dabei")
	var not_offered := &""
	for c in Database.consumables_in_order():
		if not offer.has(c.id):
			not_offered = c.id
			break
	assert_false(Game.buy_from_trader(not_offered),
		"was er nicht dabei hat, kann man nicht kaufen")
	assert_true(Game.buy_from_trader(offer[0]))
	assert_eq(Game.consumable_count(offer[0]), 1)
	assert_false(Game.buy_from_trader(offer[0]), "verkauft ist verkauft")

func test_the_raven_lands_in_the_satchel() -> void:
	Game.new_game()
	Game.visitors = Visitors.new()
	assert_true(Game.raven_waiting())
	var gift := Game.collect_raven()
	assert_true(gift != &"", "das Paket war leer")
	assert_eq(Game.consumable_count(gift), 1)
	assert_false(Game.raven_waiting())
	assert_eq(Game.collect_raven(), &"", "zweimal aufheben geht nicht")

## Ein neues Angebot loescht, was verkauft war -- sonst waere ein Teil des
## frischen Angebots von Anfang an vergriffen.
func test_a_reroll_clears_the_sold_out_list() -> void:
	var v := _fresh()
	v.refresh_trader(300.0 * HOUR)
	v.trader_buy(&"schimmer_phiole")
	assert_true(v.sold_out(&"schimmer_phiole"))
	v.reroll()
	assert_false(v.sold_out(&"schimmer_phiole"))

## Die Besucher stehen in der Welt und sind nur zu sehen, wenn es etwas zu
## holen gibt -- ein Knopf, der nichts tut, ist Ballast.
func _world() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var w: Control = load("res://scenes/fishing/world.tscn").instantiate()
	tree.root.add_child(w)
	w.size = Vector2(1280, 720)
	w._layout()
	return w

func test_the_raven_is_only_visible_when_one_waits() -> void:
	Game.new_game()
	Game.paused = true
	Game.visitors = Visitors.new()
	var w := _world()
	w._update_visitors()
	assert_true(w.get_node("Visitors/Raven").visible, "das Paket fehlt")
	Game.collect_raven()
	w._update_visitors()
	assert_false(w.get_node("Visitors/Raven").visible, "es liegt noch da, obwohl geholt")
	w.free()

func test_tapping_the_raven_puts_a_potion_in_the_satchel() -> void:
	Game.new_game()
	Game.paused = true
	Game.visitors = Visitors.new()
	Game.consumable_counts.clear()
	var w := _world()
	w._update_visitors()
	w._on_raven_pressed()
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
	w._on_trader_pressed()
	assert_eq(seen[0], 1, "das Antippen meldet sich nicht")
	w.free()

## Erst kennenlernen, dann kaufen. Ohne die Ausbaustufe gibt es keinen
## Haendler -- sonst waere die Stufe ein Preisschild ohne Wirkung.
func test_the_trader_stays_away_until_you_know_him() -> void:
	Game.new_game()
	Game.ctx.player_level = 60
	Game.coins = 1_000_000
	Game.upgrade_levels[&"trader"] = 0
	assert_false(Game.trader_unlocked())
	assert_eq(Game.trader_offer_size(), 0)
	assert_true(Game.trader_offer().is_empty(), "ohne Bekanntschaft darf nichts ausliegen")

func test_each_level_brings_one_more_thing_up_to_five() -> void:
	Game.new_game()
	var u: UpgradeData = Database.upgrades[&"trader"]
	var sizes: Array[int] = []
	for level in range(1, u.max_level + 1):
		Game.upgrade_levels[&"trader"] = level
		sizes.append(Game.trader_offer_size())
	assert_eq(sizes, [2, 3, 4, 5] as Array[int],
		"die Stufen bringen %s statt 2 bis 5" % str(sizes))
	Game.upgrade_levels[&"trader"] = u.max_level
	assert_eq(Game.trader_offer().size(), 5, "auf der Hoechststufe liegen fuenf aus")

## Die Moewe kommt ungefragt -- sie ist nicht an einen Kauf gebunden.
func test_the_gull_needs_no_unlock() -> void:
	Game.new_game()
	Game.visitors = Visitors.new()
	Game.upgrade_levels[&"trader"] = 0
	assert_true(Game.raven_waiting(), "die Moewe kommt auch ohne Ausbau")

## Die Auftraege haengen an derselben Uhr wie die Besucher.
func test_quests_stay_the_same_within_a_block_and_change_after() -> void:
	var q := Quests.new()
	var pool: Array[StringName] = [&"a", &"b", &"c", &"d", &"e", &"f", &"g", &"h"]
	var a := q.offer(500.0 * Quests.INTERVAL + 10.0, 3, pool)
	var b := q.offer(500.0 * Quests.INTERVAL + 10000.0, 3, pool)
	assert_eq(a, b, "innerhalb eines Blocks muessen die Auftraege stehen")
	var later := q.offer(501.0 * Quests.INTERVAL, 3, pool)
	assert_true(a != later, "der naechste Block bringt dieselben Auftraege")

func test_quests_have_no_duplicates_and_respect_the_count() -> void:
	var q := Quests.new()
	var pool: Array[StringName] = [&"a", &"b", &"c", &"d", &"e"]
	for block in 20:
		var offer := q.offer(float(block) * Quests.INTERVAL, 3, pool)
		assert_eq(offer.size(), 3)
		var seen: Dictionary = {}
		for id in offer:
			assert_false(seen.has(id), "%s steht doppelt" % id)
			seen[id] = true

func test_a_new_block_clears_what_was_done() -> void:
	var q := Quests.new()
	q.refresh(80.0 * Quests.INTERVAL)
	q.complete(&"bluegill")
	assert_true(q.is_done(&"bluegill"))
	assert_false(q.refresh(80.0 * Quests.INTERVAL + 500.0))
	assert_true(q.refresh(81.0 * Quests.INTERVAL))
	assert_false(q.is_done(&"bluegill"), "der neue Block faengt frisch an")

## Ohne Auftragsbuch gibt es keine Auftraege, und jede Stufe bringt einen mehr.
func test_the_quest_book_unlocks_and_grows() -> void:
	Game.new_game()
	Game.upgrade_levels[&"quests"] = 0
	assert_false(Game.quests_unlocked())
	assert_eq(Game.quest_count(), 0)
	assert_true(Game.quest_offer().is_empty())
	var counts: Array[int] = []
	for level in range(1, int(Database.upgrades[&"quests"].max_level) + 1):
		Game.upgrade_levels[&"quests"] = level
		counts.append(Game.quest_count())
	assert_eq(counts, [3, 4, 5, 6] as Array[int], "die Stufen geben %s" % str(counts))

## Verlangt werden nur Arten aus erreichbaren Zonen und keine Geheimfische --
## ein Auftrag, den man nicht erfuellen kann, waere eine Sperre.
func test_quests_only_ask_for_fish_you_can_reach() -> void:
	Game.new_game()
	Game.upgrade_levels[&"quests"] = 2
	for id in Game.quest_offer():
		var f: FishData = Database.fish[id]
		assert_true(Game.unlocked_zones.has(f.zone_id),
			"%s kommt aus einer gesperrten Zone" % id)
		assert_false(f.is_secret, "%s ist ein Geheimfisch" % id)

## Abgeben muss sich lohnen -- sonst verkauft man den Fisch einfach.
func test_handing_in_pays_more_than_selling() -> void:
	Game.new_game()
	Game.upgrade_levels[&"quests"] = 2
	var id := Game.quest_offer()[0]
	var f: FishData = Database.fish[id]
	var sample := CaughtFish.make(id, 0.0, false)
	var sold := Economy.sell_price(sample, f, Game.ctx.rarity_of(f))
	assert_true(int(Game.quest_reward(id)["coins"]) > sold,
		"abgeben bringt weniger als verkaufen")

## Abgegeben wird das LEICHTESTE Exemplar, damit kein Rekord weggeht.
func test_handing_in_gives_away_the_smallest_and_never_a_favorite() -> void:
	Game.new_game()
	Game.upgrade_levels[&"quests"] = 2
	Game.ctx.inventory.capacity = 20
	var id := Game.quest_offer()[0]
	Game.ctx.inventory.add(CaughtFish.make(id, 2.5, false))
	Game.ctx.inventory.add(CaughtFish.make(id, -1.0, false))
	Game.ctx.inventory.add(CaughtFish.make(id, 0.5, false))
	assert_true(Game.hand_in_quest(id))
	for c in Game.ctx.inventory.fish:
		assert_true(c.weight_dev > -0.9, "der leichteste haette gehen muessen")
	assert_true(Game.quests.is_done(id))
	assert_false(Game.hand_in_quest(id), "zweimal geht nicht")

func test_a_favorite_is_never_handed_in() -> void:
	Game.new_game()
	Game.upgrade_levels[&"quests"] = 2
	Game.ctx.inventory.capacity = 20
	var id := Game.quest_offer()[0]
	Game.ctx.inventory.add(CaughtFish.make(id, 0.0, false))
	Game.toggle_favorite(0)
	assert_false(Game.can_hand_in(id), "ein Favorit darf nicht weggehen")
