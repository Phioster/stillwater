## Der Köderladen. Der Grundköder ist gratis und unbegrenzt und steht
## deshalb nur zur Auswahl, nicht zum Kauf.
extends PanelBase

func refresh() -> void:
	clear(self)

	var header := Label.new()
	header.text = "Ködertasche  %d / %d" % [Game.bait_used(), Game.bait_capacity()]
	add_child(header)

	for id in Database.baits:
		var b: BaitData = Database.baits[id]
		if Game.ctx.player_level < b.unlock_level:
			continue
		add_child(_row(b))

func _row(b: BaitData) -> Control:
	var box := VBoxContainer.new()

	var title := Label.new()
	var owned := "unbegrenzt" if b.unlimited else "%d Stück" % int(Game.ctx.bait_counts.get(b.id, 0))
	var active := "  ← aktiv" if Game.ctx.bait.id == b.id else ""
	title.text = "%s  (%s)%s" % [b.display_name, owned, active]
	box.add_child(title)

	if not b.rarity_weight_bonus.is_empty():
		var effect := Label.new()
		var parts: Array[String] = []
		for rarity_id in b.rarity_weight_bonus:
			var r: RarityData = Database.rarities.get(rarity_id)
			var label := r.display_name if r != null else String(rarity_id)
			parts.append("%s ×%.1f" % [label, float(b.rarity_weight_bonus[rarity_id])])
		effect.text = "  " + ", ".join(parts)
		box.add_child(effect)

	var row := HBoxContainer.new()

	var use := TapButton.new()
	use.text = "Anlegen"
	use.custom_minimum_size = Vector2(0, 96)
	use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use.disabled = not b.unlimited and int(Game.ctx.bait_counts.get(b.id, 0)) <= 0
	use.tapped.connect(func() -> void: Game.set_active_bait(b.id))
	row.add_child(use)

	if not b.unlimited:
		for amount in [1, 10]:
			var cost := Game.bait_cost(b.id, amount)
			var buy := TapButton.new()
			buy.text = "%d ×  %d" % [amount, cost]
			buy.custom_minimum_size = Vector2(0, 96)
			buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buy.disabled = Game.coins < cost or Game.bait_used() + amount > Game.bait_capacity()
			buy.tapped.connect(func() -> void: Game.buy_bait(b.id, amount))
			row.add_child(buy)

	box.add_child(row)
	return box
