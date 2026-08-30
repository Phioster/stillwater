## Eine Fischzeile im Inventar und in der Vitrine. Beide zeigen dasselbe --
## nur der Verkaufsknopf faellt in der Vitrine weg.
class_name FishRow
extends RefCounted

static func build(index: int, in_showcase: bool) -> Control:
	var c: CaughtFish = Game.ctx.inventory.fish[index]
	var fish: FishData = Database.fish.get(c.fish_id)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 96)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := fish.full_name(c.weight_dev) if fish != null else String(c.fish_id)
	if c.is_shiny:
		name = "✦ " + name
	var w := fish.weight_str(c.weight_dev) if fish != null else "?"
	label.text = "%s\n%s · %s" % [name, FishRoll.RANK_NAMES[c.rank], w]
	if fish != null:
		label.modulate = Game.ctx.rarity_of(fish).color
	row.add_child(label)

	var fav := TapButton.new()
	fav.text = "★" if c.is_favorite else "☆"
	fav.custom_minimum_size = Vector2(96, 96)
	# Nicht ausgrauen, sondern ablehnen und wackeln: ein grauer Knopf sagt
	# nicht, WARUM er nicht geht, ein Wackeln zeigt wenigstens, dass die
	# Berührung ankam.
	fav.tapped.connect(func() -> void:
		if not Game.toggle_favorite(index):
			fav.refuse())
	row.add_child(fav)

	if not in_showcase:
		var sell := TapButton.new()
		sell.custom_minimum_size = Vector2(120, 96)
		sell.text = "%d" % (0 if fish == null else Economy.sell_price(
			c, fish, Game.ctx.rarity_of(fish), Game.ctx.consumable_bonus))
		sell.tapped.connect(func() -> void: Game.sell_one(index))
		row.add_child(sell)

	return row
