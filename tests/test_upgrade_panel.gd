extends TestCase

## I5: das Panel darf den Preis nicht selbst aus u.cost_at(level) rechnen,
## sondern muss Game.upgrade_cost() zeigen -- die einzige Stelle mit der
## Formel-Zuordnung "welche Stufe gilt fuer dieses Upgrade".
func test_upgrade_panel_shows_game_upgrade_cost() -> void:
	Game.new_game()
	Game.coins = 100000
	Game.upgrade_levels[&"rod_power"] = 2

	# upgrade_panel.gd ist ein Szenenskript ohne eigenen class_name, deshalb
	# per load() statt eines bare Bezeichners.
	var panel: PanelBase = load("res://scenes/ui/panels/upgrade_panel.gd").new()
	panel.refresh()

	var i := 0
	for id in Database.upgrades:
		var u: UpgradeData = Database.upgrades[id]
		var row: VBoxContainer = panel.get_child(i)
		var buy: Button = row.get_child(2)
		if int(Game.upgrade_levels.get(id, 0)) < u.max_level:
			assert_eq(buy.text, "Ausbauen  %d Münzen" % Game.upgrade_cost(id),
				"Preis fuer %s muss aus Game.upgrade_cost() kommen" % id)
		i += 1
	panel.free()
