## Die vier Upgrades. Werte und Kosten kommen ausschließlich aus den
## UpgradeData — hier steht keine einzige Zahl.
extends PanelBase

func refresh() -> void:
	clear(self)
	for id in Database.upgrades:
		add_child(_row(Database.upgrades[id]))

func _row(u: UpgradeData) -> Control:
	var level := int(Game.upgrade_levels.get(u.id, 0))
	var box := VBoxContainer.new()

	var title := Label.new()
	title.text = "%s  Stufe %d" % [u.display_name, level]
	box.add_child(title)

	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = "%s\nJetzt %.0f → danach %.0f" % [u.description, Game.upgrade_value(u.id), u.value_at(level + 1)]
	box.add_child(detail)

	var buy := TapButton.new()
	buy.custom_minimum_size = Vector2(0, 96)
	if level >= u.max_level:
		buy.text = "Maximum erreicht"
		buy.disabled = true
	else:
		var cost := Game.upgrade_cost(u.id)
		buy.text = "Ausbauen  %d Münzen" % cost
		buy.disabled = Game.coins < cost
		buy.tapped.connect(func() -> void: Game.buy_upgrade(u.id))
	box.add_child(buy)

	return box
