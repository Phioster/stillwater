## Die vier Upgrades. Werte und Kosten kommen ausschließlich aus den
## UpgradeData — hier steht keine einzige Zahl.
extends PanelBase

func refresh() -> void:
	clear(self)
	for id in Database.upgrades:
		add_child(_row(Database.upgrades[id]))

## "Jetzt x → danach y" mit so vielen Nachkommastellen, wie noetig sind,
## damit die beiden Zahlen sich unterscheiden.
##
## Vorher stand hier %.0f. Bei der Ködertasche (30 → 50) stimmte das, bei der
## Sichelschärfe stand "Jetzt 7 → danach 7" da: ein Schritt von 0,3
## verschwindet in der gerundeten Zahl, und die Stufe sah wirkungslos aus,
## obwohl sie wirkte.
static func spanne(jetzt: float, danach: float) -> String:
	for stellen in 3:
		var a := String.num(jetzt, stellen)
		var b := String.num(danach, stellen)
		if a != b:
			return "Jetzt %s → danach %s" % [a, b]
	# Wirklich gleich -- dann ist auch "7 → 7" die Wahrheit.
	return "Jetzt %s → danach %s" % [String.num(jetzt, 0), String.num(danach, 0)]

func _row(u: UpgradeData) -> Control:
	var level := int(Game.upgrade_levels.get(u.id, 0))
	var box := VBoxContainer.new()

	box.add_child(zeile("%s  Stufe %d" % [u.display_name, level]))
	box.add_child(zeile("%s\n%s" % [u.description,
		spanne(Game.upgrade_value(u.id), u.value_at(level + 1))]))

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
