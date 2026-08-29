extends TestCase

func test_add_until_full() -> void:
	var inv := Inventory.new()
	inv.capacity = 3
	for i in 3:
		assert_true(inv.add(CaughtFish.make(&"a", 1.0, 0, false)))
	assert_true(inv.is_full())
	assert_false(inv.add(CaughtFish.make(&"a", 1.0, 0, false)), "voll heißt: nichts geht mehr rein")
	assert_eq(inv.fish.size(), 3)

func test_favorites_are_not_sellable() -> void:
	var inv := Inventory.new()
	inv.capacity = 10
	var keeper := CaughtFish.make(&"a", 1.0, 0, false)
	keeper.is_favorite = true
	inv.add(keeper)
	inv.add(CaughtFish.make(&"b", 1.0, 0, false))
	assert_eq(inv.sellable().size(), 1)

func test_take_sellable_leaves_favorites_behind() -> void:
	var inv := Inventory.new()
	inv.capacity = 10
	var keeper := CaughtFish.make(&"a", 1.0, 0, false)
	keeper.is_favorite = true
	inv.add(keeper)
	inv.add(CaughtFish.make(&"b", 1.0, 0, false))
	var sold := inv.take_sellable()
	assert_eq(sold.size(), 1)
	assert_eq(inv.fish.size(), 1)
	assert_true(inv.fish[0].is_favorite)

func test_array_roundtrip() -> void:
	var inv := Inventory.new()
	inv.capacity = 10
	inv.add(CaughtFish.make(&"bluegill", 0.3, 4, true))
	var other := Inventory.new()
	other.load_array(inv.to_array())
	assert_eq(other.fish.size(), 1)
	assert_eq(other.fish[0].fish_id, &"bluegill")
	assert_true(other.fish[0].is_shiny)
