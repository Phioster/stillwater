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

## Die Stufenanzeige muss den Unterschied zeigen. Mit %.0f stand bei der
## Sichelschaerfe "Jetzt 7 → danach 7": ein Schritt von 0,3 verschwindet in
## der gerundeten Zahl, und die Stufe sah wirkungslos aus, obwohl sie wirkte.
func test_every_upgrade_step_shows_a_visible_difference() -> void:
	const PANEL := preload("res://scenes/ui/panels/upgrade_panel.gd")
	for id in Database.upgrades:
		var u: UpgradeData = Database.upgrades[id]
		for level in range(0, u.max_level):
			var text: String = PANEL.spanne(u.value_at(level), u.value_at(level + 1))
			# Beide Woerter raus, sonst stuende "danach" noch in der rechten
			# Haelfte und die beiden Seiten waeren NIE gleich -- der Test haette
			# dann nichts geprueft (genau so ist er zuerst dagestanden).
			var teile := text.replace("Jetzt", "").replace("danach", "").split("→")
			assert_eq(teile.size(), 2, "unerwarteter Text: %s" % text)
			assert_true(teile[0].strip_edges() != teile[1].strip_edges(),
				"%s Stufe %d zeigt zweimal dieselbe Zahl: %s" % [id, level, text])
