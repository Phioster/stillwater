extends SceneTree

## Misst, wie viele Halme eine Runde einbringt.
##
## Der gespielte Spieler zieht zum naechsten Halm und BLEIBT dort -- ein
## glatter Schwenk verweilt nirgends und schneidet deshalb nichts. Er legt den
## Finger aber nicht AUF den Halm, sondern eine Bahnlaenge daneben: die Klinge
## kreist weit draussen, und was direkt an der Hand steht, liegt im Loch.
## Genau daran hat die erste Fassung dieses Skripts die Reichweite bestraft
## statt belohnt.
func _init() -> void:
	await process_frame
	var spiel := root.get_node("Game")
	spiel.new_game()
	var reeds := load("res://core/reeds.gd")
	var schnitt: Control = load("res://scenes/fishing/reed_cut.tscn").instantiate()
	root.add_child(schnitt)
	await process_frame
	for stufe in [0, 5, 10, 20]:
		spiel.upgrade_levels["scythe_reach"] = mini(stufe, 20)
		spiel.upgrade_levels["scythe_speed"] = mini(stufe, 20)
		spiel.upgrade_levels["scythe_edge"] = mini(stufe, 30)
		schnitt.starte()
		# Die Mitte der Schneide auf ihrer Bahn -- dorthin gehoert der Halm.
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
				# Vom Halm aus zur Beetmitte hin abruecken, damit die Hand im
				# Beet bleibt und der Ring noch mehr Halme mitnimmt.
				var weg: Vector2 = schnitt._beet_mitte() - nah
				if weg.length() < 1.0:
					weg = Vector2.RIGHT
				schnitt._ziel = nah + weg.normalized() * abstand
			schnitt._process(schritt)
			rest -= schritt
		print("Stufe %2d: %3d Halme -> %d Koeder  (Reichweite %.0f, Tempo %.1f, Schaerfe %.1f, %d Treffer je Halm, Bahn %.0f)"
			% [stufe, schnitt._geschnitten, int(schnitt._geschnitten / 6),
				spiel.scythe_reach(), spiel.scythe_speed(), spiel.scythe_edge(),
				schnitt._noetig, abstand])
	quit()
