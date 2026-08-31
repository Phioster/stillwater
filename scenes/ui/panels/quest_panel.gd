## Das Auftragsbuch. Alle drei Stunden neue Aufträge; abgeben bringt mehr,
## als denselben Fisch zu verkaufen — sonst würde niemand abgeben.
##
## Abgegeben wird immer das LEICHTESTE passende Exemplar, damit kein
## Rekordfisch versehentlich weggeht. Favoriten bleiben ohnehin tabu.
extends PanelBase

func refresh() -> void:
	clear(self)

	if not Game.quests_unlocked():
		var locked := Label.new()
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked.text = "Ohne Auftragsbuch fragt dich niemand nach Fischen. Es liegt im Ausbau."
		locked.modulate = Palette.get_color(&"reed_light")
		add_child(locked)
		return

	var header := Label.new()
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.text = "%d Aufträge. Alle drei Stunden kommen neue." % Game.quest_count()
	add_child(header)

	for id in Game.quest_offer():
		add_child(_row(id))

func _row(id: StringName) -> Control:
	var f: FishData = Database.fish.get(id)
	var box := VBoxContainer.new()
	if f == null:
		return box

	var done := Game.quests.is_done(id)
	var have := 0
	for c in Game.ctx.inventory.fish:
		if c.fish_id == id and not c.is_favorite:
			have += 1

	var title := Label.new()
	title.text = "%s  (im Inventar: %d)" % [f.display_name, have]
	title.modulate = Game.ctx.rarity_of(f).color
	box.add_child(title)

	var zone: ZoneData = Database.zones.get(f.zone_id)
	var reward := Game.quest_reward(id)
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "  aus %s · %d Münzen · %d XP" % [
		zone.display_name if zone != null else "?", int(reward["coins"]), int(reward["xp"])]
	info.modulate = Palette.get_color(&"reed_light")
	box.add_child(info)

	var give := TapButton.new()
	give.custom_minimum_size = Vector2(0, 96)
	give.text = "Erledigt" if done else "Abgeben"
	give.disabled = done
	give.tapped.connect(func() -> void:
		if not Game.hand_in_quest(id):
			give.refuse())
	box.add_child(give)
	return box
