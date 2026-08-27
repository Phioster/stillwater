## Das Fisch-Journal. Unentdeckte Arten erscheinen als Silhouette,
## Secret-Fische als verschlossener Platz mit Hinweis.
extends PanelBase

func refresh() -> void:
	clear(self)
	for zone_id in Database.zones:
		var zone: ZoneData = Database.zones[zone_id]
		var fish := Database.fish_of_zone(zone_id)

		var title := Label.new()
		title.text = "%s   %d %%" % [zone.display_name, int(round(Game.ctx.journal.completion(fish) * 100.0))]
		add_child(title)

		for f in fish:
			if f.is_secret and not Game.ctx.journal.is_discovered(f.id):
				add_child(_locked(f))
				continue
			add_child(_entry(f))

func _entry(f: FishData) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 84)

	var known := Game.ctx.journal.is_discovered(f.id)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var suffix := "" if known else "_silhouette"
	icon.texture = TextureLoader.load_texture("res://assets/art/fish_%s%s.png" % [f.id, suffix])
	row.add_child(icon)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if known:
		var e := Game.ctx.journal.entry(f.id)
		var shiny := "  ✦" if bool(e["shiny_found"]) else ""
		label.text = "%s%s\n%dx · beste %s · Level %d · %.2f–%.2f kg" % [
			f.display_name, shiny, int(e["caught_count"]),
			FishRoll.QUALITY_NAMES[int(e["best_quality"])], int(e["fish_level"]),
			float(e["worst_weight"]), float(e["best_weight"])
		]
		label.modulate = Game.ctx.rarity_of(f).color
	else:
		label.text = "???"
		label.modulate = Palette.get_color(&"shadow")
	row.add_child(label)
	return row

func _locked(f: FishData) -> Control:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 64)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "🔒 %s" % f.secret_hint
	label.modulate = Palette.get_color(&"accent")
	return label
