## Die Vitrine: Fische, die behalten werden. Eigener Reiter statt eines
## Abschnitts im Inventar -- sie haben eigenen Platz, eigene Zählung und
## sollen die Verkaufsliste nicht laenger machen.
extends PanelBase

func refresh() -> void:
	clear(self)
	var inv := Game.ctx.inventory

	var header := Label.new()
	header.text = "Vitrine  %d / %d" % [inv.count_favorites(), inv.favorite_capacity]
	header.modulate = Palette.get_color(&"cloth_red") if inv.favorites_full() \
		else Palette.get_color(&"accent")
	add_child(header)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Was hier steht, wird nie verkauft und belegt keinen Platz in der Fischkiste."
	add_child(hint)

	var any := false
	for i in inv.fish.size():
		if inv.fish[i].is_favorite:
			any = true
			add_child(FishRow.build(i, true))
	if not any:
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = "Noch leer. Tippe im Inventar auf den Stern, um einen Fisch hierher zu legen."
		add_child(empty)
