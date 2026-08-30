## Das Inventar. Zeigt jeden Fang mit Preis, Qualität und Gewicht, erlaubt
## Einzelverkauf, Favorisieren und Alles-Verkaufen.
extends PanelBase

func refresh() -> void:
	clear(self)

	var inv := Game.ctx.inventory
	var header := Label.new()
	header.text = "Fischkiste  %d / %d" % [inv.count_stored(), inv.capacity]
	add_child(header)

	if inv.is_full():
		var warn := Label.new()
		warn.text = "Voll — das Angeln pausiert."
		warn.modulate = Palette.get_color(&"cloth_red")
		add_child(warn)

	var sell_all := TapButton.new()
	sell_all.text = "Alles verkaufen"
	sell_all.custom_minimum_size = Vector2(0, 96)
	sell_all.tapped.connect(func() -> void: Game.sell_all())
	add_child(sell_all)

	if inv.fish.is_empty():
		var empty := Label.new()
		empty.text = "Noch nichts gefangen."
		add_child(empty)

	# Favoriten zuerst und unter eigener Ueberschrift: sie haben ihren eigenen
	# Platz und blockieren die Fischkiste nicht mehr.
	if inv.count_favorites() > 0:
		var vitrine := Label.new()
		vitrine.text = "Vitrine  %d / %d" % [inv.count_favorites(), inv.favorite_capacity]
		vitrine.modulate = Palette.get_color(&"accent")
		add_child(vitrine)
		for i in inv.fish.size():
			if inv.fish[i].is_favorite:
				add_child(_row(i))
		var sep := Label.new()
		sep.text = "Zum Verkauf"
		add_child(sep)

	for i in inv.fish.size():
		if not inv.fish[i].is_favorite:
			add_child(_row(i))

func _row(index: int) -> Control:
	var c: CaughtFish = Game.ctx.inventory.fish[index]
	var fish: FishData = Database.fish.get(c.fish_id)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 96)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := fish.display_name if fish != null else String(c.fish_id)
	if c.is_shiny:
		name = "✦ " + name
	var fd: FishData = Database.fish.get(c.fish_id)
	var w := fd.weight_str(c.weight_dev) if fd != null else "?"
	label.text = "%s\n%s · %s" % [name, FishRoll.RANK_NAMES[c.rank], w]
	if fish != null:
		label.modulate = Game.ctx.rarity_of(fish).color
	row.add_child(label)

	var fav := TapButton.new()
	fav.text = "★" if c.is_favorite else "☆"
	fav.custom_minimum_size = Vector2(96, 96)
	# Eine volle Vitrine muss man sehen koennen, bevor man tippt.
	fav.disabled = not c.is_favorite and Game.ctx.inventory.favorites_full()
	fav.tapped.connect(func() -> void: Game.toggle_favorite(index))
	row.add_child(fav)

	var sell := TapButton.new()
	sell.custom_minimum_size = Vector2(120, 96)
	sell.disabled = c.is_favorite
	sell.text = "%d" % (0 if fish == null else Economy.sell_price(c, fish, Game.ctx.rarity_of(fish), Game.ctx.consumable_bonus))
	sell.tapped.connect(func() -> void: Game.sell_one(index))
	row.add_child(sell)

	return row
