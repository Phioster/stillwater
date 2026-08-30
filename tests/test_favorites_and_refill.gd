extends TestCase

## Zwei Griffe aus dem Cornerpond-Dossier: Favoriten bekommen ihren eigenen
## Platz, und Köder werden aufgefüllt statt stückweise gekauft.

func test_a_favorite_does_not_fill_the_fish_box() -> void:
	Game.new_game()
	var inv := Game.ctx.inventory
	inv.capacity = 2
	inv.favorite_capacity = 3
	for i in 2:
		inv.add(CaughtFish.make(&"bluegill", 0.0, false))
	assert_true(inv.is_full(), "zwei Fische füllen eine Kiste für zwei")

	assert_true(Game.toggle_favorite(0), "favorisieren muss gehen")
	assert_false(inv.is_full(), "ein Favorit belegt keinen Kistenplatz mehr")
	assert_eq(inv.count_stored(), 1)
	assert_eq(inv.count_favorites(), 1)

func test_the_showcase_has_its_own_limit() -> void:
	Game.new_game()
	var inv := Game.ctx.inventory
	inv.capacity = 20
	inv.favorite_capacity = 2
	for i in 3:
		inv.add(CaughtFish.make(&"bluegill", 0.0, false))
	assert_true(Game.toggle_favorite(0))
	assert_true(Game.toggle_favorite(1))
	assert_true(inv.favorites_full())
	assert_false(Game.toggle_favorite(2), "die dritte Vitrine gibt es nicht")
	assert_false(inv.fish[2].is_favorite, "der Fisch darf dabei nicht heimlich gesetzt werden")

func test_unfavoriting_always_works_even_when_full() -> void:
	Game.new_game()
	var inv := Game.ctx.inventory
	inv.favorite_capacity = 1
	inv.add(CaughtFish.make(&"bluegill", 0.0, false))
	assert_true(Game.toggle_favorite(0))
	assert_true(Game.toggle_favorite(0), "herausnehmen muss auch bei voller Vitrine gehen")
	assert_eq(inv.count_favorites(), 0)

func test_refill_fills_the_bag_and_charges_for_it() -> void:
	Game.new_game()
	Game.coins = 100000
	var id := &"mayfly_nymph"
	var b: BaitData = Database.baits[id]
	var space := Game.bait_refill_amount()
	assert_true(space > 0, "eine frische Tasche muss Platz haben")
	var before := Game.coins

	var bought := Game.refill_bait(id)
	assert_eq(bought, space, "es muss bis zum Rand gefüllt werden")
	assert_eq(Game.bait_used(), Game.bait_capacity(), "die Tasche ist danach voll")
	assert_eq(Game.coins, before - b.cost * space, "der Preis muss aus bait_cost kommen")
	assert_eq(Game.refill_bait(id), 0, "eine volle Tasche kauft nichts nach")

## Wer wenig Geld hat, soll trotzdem kaufen können, was er sich leisten kann --
## statt eines Knopfes, der einfach nichts tut.
func test_refill_buys_only_what_the_purse_allows() -> void:
	Game.new_game()
	var id := &"mayfly_nymph"
	var b: BaitData = Database.baits[id]
	Game.coins = b.cost * 3 + b.cost - 1
	var bought := Game.refill_bait(id)
	assert_eq(bought, 3, "für 3,x Köder gibt es 3")
	assert_true(Game.coins < b.cost, "der Rest reicht nicht für einen weiteren")

func test_refill_ignores_the_free_starter_bait() -> void:
	Game.new_game()
	var basic := Database.basic_bait()
	assert_true(basic.unlimited, "der Grundköder muss unbegrenzt sein")
	assert_eq(Game.refill_bait(basic.id), 0, "unbegrenzte Köder kauft man nicht nach")
