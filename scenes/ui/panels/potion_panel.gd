## Der Trankbeutel: was man hat und was gerade wirkt.
##
## Gekauft wird hier NICHT. Tränke kommen vom Maus-Händler und aus dem Paket
## der Möwe — genau wie in der Referenz, deren Laden nur Ausbau und Köder
## führt. Das macht aus einem Trank ein Fundstück statt einer Ware aus dem
## Automaten, und deshalb fühlt sich dort ein Elixier nach etwas an.
extends PanelBase

func refresh() -> void:
	clear(self)
	add_child(_active_block())

	var header := Label.new()
	header.text = "Beutel"
	header.modulate = Palette.get_color(&"accent")
	add_child(header)

	var any := false
	for c in Database.consumables_in_order():
		if Game.consumable_count(c.id) <= 0:
			continue
		any = true
		add_child(_row(c))
	if not any:
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = "Noch nichts da. Tränke bringt der Händler vorbei — oder die Möwe legt eins ab."
		empty.modulate = Palette.get_color(&"reed_light")
		add_child(empty)

## Was gerade wirkt, mit Restzeit. Ohne das ist ein Trank Geld, das man
## ausgibt, ohne zu sehen wofür.
func _active_block() -> Control:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Wirkt gerade"
	title.modulate = Palette.get_color(&"accent")
	box.add_child(title)
	if Game.buffs.active.is_empty():
		var none := Label.new()
		none.text = "  nichts"
		none.modulate = Palette.get_color(&"reed_light")
		box.add_child(none)
		return box
	for id in Game.buffs.active:
		var c: ConsumableData = Database.consumables.get(id)
		if c == null:
			continue
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = "  %s — noch %s" % [c.display_name, _time_left(Game.buffs.remaining(id))]
		box.add_child(line)
	return box

func _time_left(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 60:
		return "%d:%02d min" % [s / 60, s % 60]
	return "%d s" % s

func _row(c: ConsumableData) -> Control:
	var box := VBoxContainer.new()

	var owned := Game.consumable_count(c.id)
	var title := Label.new()
	var running := "  ← wirkt" if Game.buffs.is_active(c.id) else ""
	title.text = "%s  (%d)%s" % [c.display_name, owned, running]
	box.add_child(title)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = "  %s · %d min" % [c.description, int(round(c.duration / 60.0))]
	desc.modulate = Palette.get_color(&"reed_light")
	box.add_child(desc)

	var use := TapButton.new()
	use.text = "Trinken"
	use.custom_minimum_size = Vector2(0, 96)
	use.tapped.connect(func() -> void:
		if not Game.use_consumable(c.id):
			use.refuse())
	box.add_child(use)
	return box
