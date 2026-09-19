extends SceneTree

## Faehrt allein die Reichweite durch, Tempo und Schaerfe fest. Der Ring der
## Klinge hat ein LOCH in der Mitte, und je weiter er wird, desto mehr von ihm
## liegt neben dem Beet -- irgendwo dazwischen kippt der Ausbau von Gewinn zu
## Verlust, und diese Zahl will man nicht raten.
func _init() -> void:
	await process_frame
	var spiel := root.get_node("Game")
	spiel.new_game()
	var reeds := load("res://core/reeds.gd")
	var schnitt: Control = load("res://scenes/fishing/reed_cut.tscn").instantiate()
	root.add_child(schnitt)
	await process_frame
	for tempo in [0, 20]:
		spiel.upgrade_levels["scythe_speed"] = tempo
		spiel.upgrade_levels["scythe_edge"] = 0
		print("--- Tempo-Stufe %d" % tempo)
		for stufe in range(0, 21, 2):
			spiel.upgrade_levels["scythe_reach"] = stufe
			var summe := 0
			for lauf in 3:
				schnitt.starte()
				var g: Vector2i = reeds.klinge_groesse()
				var stahl: Vector2 = reeds.schneide_bereich()
				var abstand: float = spiel.scythe_reach() \
					- (float(g.x) - (stahl.x + stahl.y) * 0.5) * schnitt.SKALA
				var schritt := 1.0 / 60.0
				var rest := 18.0
				while rest > 0.0:
					var nah := Vector2.INF
					var weit := INF
					for s in schnitt._halme.values():
						var d: float = (s.position - schnitt._hand).length()
						if d < weit:
							weit = d
							nah = s.position
					if nah != Vector2.INF:
						var weg: Vector2 = schnitt._beet_mitte() - nah
						if weg.length() < 1.0:
							weg = Vector2.RIGHT
						schnitt._ziel = nah + weg.normalized() * abstand
					schnitt._process(schritt)
					rest -= schritt
				summe += schnitt._geschnitten
			print("  Reichweite %3.0f: %4.1f Halme" % [spiel.scythe_reach(),
				float(summe) / 3.0])
	quit()
