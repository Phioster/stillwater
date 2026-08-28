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

func _entry(f: FishData) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 84)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta(&"fish_id", f.id)
	row.gui_input.connect(_on_row_input.bind(f.id))

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
	return row

## Tipp per Maus (Desktop) oder Finger (Android, per Standardeinstellung als
## Mausereignis emuliert) meldet die Fisch-ID -- das Fenster entscheidet
## selbst, was es dazu zeigt.
func _on_row_input(event: InputEvent, id: StringName) -> void:
	var mouse_tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch_tap: bool = event is InputEventScreenTouch and event.pressed
	if not (mouse_tap or touch_tap):
		return
	fish_tapped.emit(id)

## Der gesperrte Platz eines noch nicht entdeckten Secret-Fischs ist ebenso
## antippbar wie eine normale Zeile -- das Fenster zeigt dann nur den Hinweis.
func _locked(f: FishData) -> Control:
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 64)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.set_meta(&"fish_id", f.id)
	label.gui_input.connect(_on_row_input.bind(f.id))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "🔒 %s" % f.secret_hint
	label.modulate = Palette.get_color(&"accent")
	return label
