## Das Fisch-Journal. Unentdeckte Arten erscheinen als Silhouette,
## Secret-Fische als verschlossener Platz mit Hinweis. Ein Tipp auf eine
## Zeile meldet die Fisch-ID nach aussen -- main.gd oeffnet darauf das
## grosse Fisch-Fenster (fish_window.gd), das Journal zeigt selbst nichts mehr auf.
extends PanelBase

signal fish_tapped(id: StringName)

func refresh() -> void:
	clear(self)
	for zone_id in Database.zones:
		var zone: ZoneData = Database.zones[zone_id]
		var fish := Database.fish_of_zone(zone_id)

		var title := Label.new()
		title.text = "%s   %d %%" % [zone.display_name, int(round(Game.ctx.journal.completion(fish) * 100.0))]
		add_child(title)

		# Geheime Fische kommen ans Ende der Zone: die Spec sieht dafuer einen
		# eigenen verschlossenen Platz vor, keine Zeile mitten in der Liste.
		var normal: Array[FishData] = []
		var secret: Array[FishData] = []
		for f in fish:
			if f.is_secret:
				secret.append(f)
			else:
				normal.append(f)
		for f in normal + secret:
			if f.is_secret and not Game.ctx.journal.is_discovered(f.id):
				add_child(_locked(f))
				continue
			add_child(_entry(f))

## Die Zeile ist ein Knopf, kein Container mit gui_input: Knoepfe nehmen
## Beruehrungen zuverlaessig an, auch innerhalb eines Scroll-Bereichs. Die
## Tab-Leiste macht es genauso und funktioniert auf dem Geraet.
func _entry(f: FishData) -> Control:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 84)
	button.set_meta(&"fish_id", f.id)
	button.pressed.connect(func(): fish_tapped.emit(f.id))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var known := Game.ctx.journal.is_discovered(f.id)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var suffix := "" if known else "_silhouette"
	icon.texture = TextureLoader.load_texture("res://assets/art/fish_%s%s.png" % [f.id, suffix])
	row.add_child(icon)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if known:
		var e := Game.ctx.journal.entry(f.id)
		var shiny := "  ✦" if bool(e["shiny_found"]) else ""
		var lo := ("%.2f" % float(e["worst_weight"])).replace(".", ",")
		var hi := ("%.2f" % float(e["best_weight"])).replace(".", ",")
		label.text = "%s%s\n%dx · beste %s · Level %d · %s–%s kg" % [
			f.display_name, shiny, int(e["caught_count"]),
			FishRoll.QUALITY_NAMES[int(e["best_quality"])], int(e["fish_level"]), lo, hi
		]
		label.modulate = Game.ctx.rarity_of(f).color
	else:
		label.text = "???"
		label.modulate = Palette.get_color(&"shadow")
	row.add_child(label)
	return button

## Tipp per Maus (Desktop) oder Finger (Android, per Standardeinstellung als
## Mausereignis emuliert) meldet die Fisch-ID -- das Fenster entscheidet
## selbst, was es dazu zeigt.
func _locked(f: FishData) -> Control:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 64)
	button.set_meta(&"fish_id", f.id)
	button.pressed.connect(func(): fish_tapped.emit(f.id))
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "🔒 %s" % f.secret_hint
	label.modulate = Palette.get_color(&"accent")
	button.add_child(label)
	return button
