## Zonenauswahl mit Freischaltbedingungen.
extends PanelBase

func refresh() -> void:
	clear(self)
	for id in Database.zones:
		add_child(_row(Database.zones[id]))

func _row(z: ZoneData) -> Control:
	var box := VBoxContainer.new()
	var unlocked := z.id in Game.unlocked_zones
	var here := Game.ctx.zone.id == z.id

	var title := Label.new()
	title.text = z.display_name + ("  ← hier" if here else "")
	box.add_child(title)

	var detail := Label.new()
	var fish := Database.fish_of_zone(z.id)
	detail.text = "%d Arten · Biss %.0f–%.0f s" % [fish.size(), z.bite_time_min, z.bite_time_max]
	box.add_child(detail)

	var button := TapButton.new()
	button.custom_minimum_size = Vector2(0, 96)
	if here:
		button.text = "Du bist hier"
		button.disabled = true
	elif unlocked:
		button.text = "Hinreisen"
		button.tapped.connect(func() -> void: Game.travel_to(z.id))
	else:
		button.text = "Freischalten  Lvl %d · %d Münzen" % [z.unlock_level, z.unlock_cost]
		button.disabled = Game.ctx.player_level < z.unlock_level or Game.coins < z.unlock_cost
		button.tapped.connect(func() -> void: Game.unlock_zone(z.id))
	box.add_child(button)

	return box
