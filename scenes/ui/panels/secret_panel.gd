## Die Geheimfische. Der Reiter erscheint erst, wenn der erste gefangen ist --
## vorher soll das Spiel nicht einmal verraten, dass es sie gibt. Deshalb
## stehen hier auch keine verschlossenen Plaetze und keine Hinweise auf
## Arten, die noch niemand gesehen hat.
extends PanelBase

signal fish_tapped(id: StringName)

## Feste Hoehe je Zeile -- daran haengt die virtuelle Liste.
const ENTRY_HEIGHT: float = 84.0

func refresh() -> void:
	clear(self)
	if not Game.ctx.journal.has_any_secret():
		return
	for zone in Database.zones_in_order():
		var zone_id := zone.id
		var found: Array[FishData] = []
		for f in Database.fish_of_zone(zone_id):
			if f.is_secret and Game.ctx.journal.is_discovered(f.id):
				found.append(f)
		if found.is_empty():
			continue
		var title := Label.new()
		title.text = zone.display_name
		add_child(title)
		# Auch hier virtuell: die Liste waechst mit jeder Zone und jedem
		# neuen Geheimfisch. Je Zone eine eigene, weil die Ueberschriften
		# dazwischen andere Hoehen haben als die Zeilen.
		var list := VirtualList.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(list)
		list.setup(found.size(), ENTRY_HEIGHT,
			func(row: int) -> Control: return _entry(found[row]))

func _entry(f: FishData) -> Control:
	var button := TapButton.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, ENTRY_HEIGHT)
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
	var best := f.weight_str(float(e["best_dev"]))
	label.text = "✦ %s\n%dx · Rekord %s\n%s" % [
		f.display_name, int(e["caught_count"]), best, f.secret_hint
	]
	label.modulate = Palette.get_color(&"accent")
	row.add_child(label)
	return button
