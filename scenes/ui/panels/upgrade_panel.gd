## Die vier Upgrades. Werte und Kosten kommen ausschließlich aus den
## UpgradeData — hier steht keine einzige Zahl.
extends PanelBase

func refresh() -> void:
	clear(self)
	for id in Database.upgrades:
		add_child(_row(Database.upgrades[id]))

## Wie viele Nachkommastellen ein Ausbau braucht, damit EIN Schritt sichtbar
## ist. Das haengt am Schritt, nicht am aktuellen Wert.
##
## Vorher suchte das hier die wenigsten Stellen, mit denen sich die beiden
## Zahlen unterscheiden -- und damit wechselte die Genauigkeit von Stufe zu
## Stufe. Bei der Klingenschaerfe (Schritt 0,3) stand auf Stufe 0 "1,0 → 1,3",
## auf Stufe 1 aber "1 → 2", weil sich die GERUNDETEN Zahlen dort zufaellig
## schon unterschieden. Die Reihe sprang, obwohl sie gleichmaessig waechst.
static func stellen(schritt: float) -> int:
	var s := absf(schritt)
	for n in 3:
		if s >= pow(10.0, -float(n)) * 0.95:
			return n
	return 3

## "Jetzt x → danach y", mit der Genauigkeit des Ausbaus -- auf allen seinen
## Stufen derselben, damit das "danach" der einen Stufe genau das "Jetzt" der
## naechsten ist.
static func spanne(jetzt: float, danach: float, schritt: float) -> String:
	var n := stellen(schritt)
	return "Jetzt %s → danach %s" % [String.num(jetzt, n), String.num(danach, n)]

func _row(u: UpgradeData) -> Control:
	var level := int(Game.upgrade_levels.get(u.id, 0))
	var box := VBoxContainer.new()

	box.add_child(zeile("%s  Stufe %d" % [u.display_name, level]))
	box.add_child(zeile("%s\n%s" % [u.description,
		spanne(Game.upgrade_value(u.id), u.value_at(level + 1),
			u.value_per_level)]))

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
