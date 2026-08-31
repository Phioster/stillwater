## Der Waschbär-Händler. Er kommt jede Stunde vorbei und hat dabei, was er
## gerade hat — nicht, was man bestellen würde.
##
## Das Angebot wird aus der Stunde gesät, nicht gewürfelt und gespeichert:
## dieselbe Stunde gibt immer dasselbe, auch nach einem Neustart, und es
## verfällt nichts, während man weg ist.
extends PanelBase

func refresh() -> void:
	clear(self)

	var header := Label.new()
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not Game.trader_unlocked():
		header.text = "Am Ufer huscht manchmal etwas vorbei. Solange es dich nicht kennt, bleibt es weg — im Ausbau steht, was das ändert."
		header.modulate = Palette.get_color(&"reed_light")
		add_child(header)
		return
	if not Game.trader_present():
		header.text = "Er hat eingepackt und ist weitergezogen. Nächste Stunde schaut er wieder vorbei."
		header.modulate = Palette.get_color(&"reed_light")
		add_child(header)
		return
	header.text = "Der Händler hat %d Sachen dabei. Nächste Stunde bringt er andere." \
		% Game.trader_offer_size()
	add_child(header)

	for id in Game.trader_offer():
		var c: ConsumableData = Database.consumables.get(id)
		if c != null:
			add_child(_row(c))

	var reroll := TapButton.new()
	reroll.text = "Anderes zeigen lassen  ·  %d" % Visitors.REROLL_COST
	reroll.custom_minimum_size = Vector2(0, 96)
	reroll.tapped.connect(func() -> void:
		if not Game.reroll_trader():
			reroll.refuse())
	add_child(reroll)

func _row(c: ConsumableData) -> Control:
	var box := VBoxContainer.new()
	var sold := Game.visitors.sold_out(c.id)

	var title := Label.new()
	title.text = "%s  (im Beutel: %d)" % [c.display_name, Game.consumable_count(c.id)]
	box.add_child(title)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = "  %s · %d min" % [c.description, int(round(c.duration / 60.0))]
	desc.modulate = Palette.get_color(&"reed_light")
	box.add_child(desc)

	var buy := TapButton.new()
	buy.custom_minimum_size = Vector2(0, 96)
	# Verkauft ist verkauft, bis er wiederkommt. Ein Angebot, das sich
	# nachfuellt, waere ein Automat und kein Besuch.
	buy.text = "Schon verkauft" if sold else "Kaufen  ·  %d" % c.cost
	buy.disabled = sold
	buy.tapped.connect(func() -> void:
		if not Game.buy_from_trader(c.id):
			buy.refuse())
	box.add_child(buy)
	return box
