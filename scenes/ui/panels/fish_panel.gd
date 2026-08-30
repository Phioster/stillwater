## Das Inventar. Zeigt jeden Fang mit Preis, Qualität und Gewicht, erlaubt
## Einzelverkauf, Favorisieren und Alles-Verkaufen.
extends PanelBase

func refresh() -> void:
	clear(self)

	var inv := Game.ctx.inventory
	var header := Label.new()
	header.text = "Fischkiste  %d / %d" % [inv.count_stored(), inv.capacity]
	if inv.is_full():
		header.modulate = Palette.get_color(&"cloth_red")
	add_child(header)

	if inv.is_full():
		var warn := Label.new()
		warn.text = "Voll — das Angeln pausiert."
		warn.modulate = Palette.get_color(&"cloth_red")
		add_child(warn)

	var total := 0
	for c in inv.sellable():
		var fd: FishData = Database.fish.get(c.fish_id)
		if fd != null:
			total += Economy.sell_price(c, fd, Game.ctx.rarity_of(fd), Game.ctx.consumable_bonus)
	var sell_all := TapButton.new()
	sell_all.text = "Alles verkaufen  ·  %d" % total
	sell_all.disabled = total <= 0
	sell_all.custom_minimum_size = Vector2(0, 96)
	sell_all.tapped.connect(func() -> void: Game.sell_all())
	add_child(sell_all)

	if inv.fish.is_empty():
		var empty := Label.new()
		empty.text = "Noch nichts gefangen."
		add_child(empty)

	# Favoriten stehen im eigenen Reiter (Vitrine) und tauchen hier nicht auf.
	for i in inv.fish.size():
		if not inv.fish[i].is_favorite:
			add_child(FishRow.build(i, false))
