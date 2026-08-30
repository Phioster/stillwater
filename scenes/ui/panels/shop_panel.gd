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

	# Was der Köder verspricht, steht auf dem Köder. Das ist der eigentliche
	# Gewinn der Rangtabelle: eine verschobene Verteilung ließe sich gar
	# nicht in einem Satz zusagen.
	var ranks := b.main_ranks()
	if not ranks.is_empty():
		var names: Array[String] = []
		for r in ranks:
			names.append(FishRoll.RANK_NAMES[r])
		var promise := Label.new()
		promise.text = "  am besten für Rang %s" % "/".join(names)
		promise.modulate = Palette.get_color(&"accent")
		box.add_child(promise)

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
		var amount := Game.bait_refill_amount()
		var cost := Game.bait_refill_cost(b.id)
		var buy := TapButton.new()
		buy.custom_minimum_size = Vector2(0, 96)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if amount <= 0:
			buy.text = "Tasche voll"
		elif Game.coins < Game.bait_cost(b.id, 1):
			buy.text = "Auffüllen  %d" % cost
		else:
			buy.text = "Auffüllen  +%d  ·  %d" % [amount, cost]
		buy.tapped.connect(func() -> void:
			if Game.refill_bait(b.id) <= 0:
				buy.refuse())
		row.add_child(buy)

	box.add_child(row)
	return box
