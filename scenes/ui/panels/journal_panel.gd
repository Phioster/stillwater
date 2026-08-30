## Das Fisch-Journal. Unentdeckte Arten erscheinen als Silhouette.
## Geheimfische kommen hier nicht vor — sie haben einen eigenen Reiter.
##
## Eine Zone auf einmal, umgeschaltet über ein Raster kleiner Knöpfe.
##
## Cornerpond nimmt dafür ein Aufklappmenü. Ich hatte notiert, ab fünf Zonen
## umzuschalten — ein Raster ist aber besser als beides: es trägt beliebig
## viele Zonen, jede bleibt mit EINEM Tipp erreichbar (ein Aufklappmenü
## braucht zwei), und es benutzt denselben Knopf, der auf dem Gerät
## nachweislich funktioniert, statt eines Popup-Menüs mit eigener
## Eingabebehandlung.
extends PanelBase

signal fish_tapped(id: StringName)

## Mehr als drei nebeneinander werden auf einem Handy zu schmal zum Lesen.
const SWITCH_COLUMNS: int = 3

var _zone: StringName = &""

## Zonen in Freischaltreihenfolge, nicht in Ordner-Reihenfolge: die
## Dateisystem-Reihenfolge ist zwischen Geräten nicht einmal stabil.
func _zones_in_order() -> Array[ZoneData]:
	var out: Array[ZoneData] = []
	for id in Database.zones:
		out.append(Database.zones[id])
	out.sort_custom(func(a: ZoneData, b: ZoneData) -> bool:
		if a.unlock_level != b.unlock_level:
			return a.unlock_level < b.unlock_level
		return a.unlock_cost < b.unlock_cost)
	return out

## Innerhalb einer Zone: erst die gewöhnlichen, dann die seltenen, und
## gleichrangige alphabetisch. Vorher stand hier die Reihenfolge, in der die
## Arten ins Datenverzeichnis gewandert sind — also gar keine.
func _fish_in_order(zone_id: StringName) -> Array[FishData]:
	var out: Array[FishData] = []
	for f in Database.fish_of_zone(zone_id):
		if not f.is_secret:
			out.append(f)
	out.sort_custom(func(a: FishData, b: FishData) -> bool:
		# Nach Wertfaktor, nicht nach unlock_level: gewoehnlich und
		# ungewoehnlich schalten beide ab Stufe 1 frei und wuerden sich sonst
		# alphabetisch ineinandermischen.
		var va := _rarity_order(a.rarity_id)
		var vb := _rarity_order(b.rarity_id)
		if not is_equal_approx(va, vb):
			return va < vb
		return a.display_name < b.display_name)
	return out

func _rarity_order(id: StringName) -> float:
	var r: RarityData = Database.rarities.get(id)
	return r.value_mult if r != null else 1.0

func refresh() -> void:
	clear(self)
	var zones := _zones_in_order()
	if zones.is_empty():
		return
	if _zone == &"" or not Database.zones.has(_zone):
		_zone = zones[0].id

	add_child(_zone_switch(zones))
	var zone: ZoneData = Database.zones[_zone]
	var fish := _fish_in_order(_zone)
	add_child(_progress(zone, fish))
	for f in fish:
		add_child(_entry(f))

func _zone_switch(zones: Array[ZoneData]) -> Control:
	var grid := GridContainer.new()
	grid.columns = SWITCH_COLUMNS
	for z in zones:
		var b := TapButton.new()
		b.text = z.display_name
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = z.id == _zone
		b.disabled = z.id == _zone
		b.tapped.connect(func() -> void:
			_zone = z.id
			refresh())
		grid.add_child(b)
	return grid

## Zwei Vollständigkeiten: Arten und Art-mal-Rang. Die zweite ist die lange.
func _progress(zone: ZoneData, fish: Array[FishData]) -> Control:
	var box := VBoxContainer.new()
	var j := Game.ctx.journal
	var species := j.completion(fish)
	var ranks := j.rank_completion(fish)

	var label := Label.new()
	label.text = "Arten %d %%   ·   Ränge %d %%" % [
		int(round(species * 100.0)), int(round(ranks * 100.0))]
	box.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = species
	box.add_child(bar)
	return box

## Die Zeile ist ein Knopf, kein Container mit gui_input: Knoepfe nehmen
## Beruehrungen zuverlaessig an, auch innerhalb eines Scroll-Bereichs.
func _entry(f: FishData) -> Control:
	var button := TapButton.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0, 84)
	button.set_meta(&"fish_id", f.id)
	button.tapped.connect(func(): fish_tapped.emit(f.id))
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
		var lo := f.weight_str(float(e["worst_dev"]))
		var hi := f.weight_str(float(e["best_dev"]))
		var ranks: Array = e["caught_ranks"]
		label.text = "%s%s\n%dx · Level %d · %s–%s\nRänge %d/%d" % [
			f.display_name, shiny, int(e["caught_count"]),
			Game.ctx.journal.fish_level(f.id), lo, hi,
			ranks.size(), FishRoll.RANK_NAMES.size()
		]
		label.modulate = Game.ctx.rarity_of(f).color
	else:
		label.text = "???"
		label.modulate = Palette.get_color(&"shadow")
	row.add_child(label)
	return button
