## Die Geheimfische. Der Reiter erscheint erst, wenn der erste gefangen ist --
## vorher soll das Spiel nicht einmal verraten, dass es sie gibt. Deshalb
## stehen hier auch keine verschlossenen Plaetze und keine Hinweise auf
## Arten, die noch niemand gesehen hat.
extends PanelBase

signal fish_tapped(id: StringName)

func refresh() -> void:
	clear(self)
	if not Game.ctx.journal.has_any_secret():
		return
	for zone_id in Database.zones:
		var found: Array[FishData] = []
		for f in Database.fish_of_zone(zone_id):
			if f.is_secret and Game.ctx.journal.is_discovered(f.id):
				found.append(f)
		if found.is_empty():
			continue
		var title := Label.new()
		title.text = Database.zones[zone_id].display_name
		add_child(title)
		for f in found:
			add_child(_entry(f))

func _entry(f: FishData) -> Control:
	var button := TapButton.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 84)
	button.set_meta(&"fish_id", f.id)
	button.tapped.connect(func() -> void: fish_tapped.emit(f.id))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = TextureLoader.load_texture("res://assets/art/fish_%s.png" % f.id)
	row.add_child(icon)

	var e := Game.ctx.journal.entry(f.id)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var best := ("%.2f" % float(e["best_weight"])).replace(".", ",")
	label.text = "✦ %s\n%dx · Rekord %s kg\n%s" % [
		f.display_name, int(e["caught_count"]), best, f.secret_hint
	]
	label.modulate = Palette.get_color(&"accent")
	row.add_child(label)
	return button
