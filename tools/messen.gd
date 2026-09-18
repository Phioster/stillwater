extends SceneTree

## Misst, wie viele Halme eine Runde einbringt -- mit einem Spieler, der auf
## den naechsten Halm zieht und dort BLEIBT. Ein glatter Schwenk verweilt
## nirgends und schneidet deshalb nichts.
func _init() -> void:
	await process_frame
	var spiel := root.get_node("Game")
	spiel.new_game()
	var schnitt: Control = load("res://scenes/fishing/reed_cut.tscn").instantiate()
	root.add_child(schnitt)
	await process_frame
	for stufe in [0, 5, 10, 20]:
		spiel.upgrade_levels["scythe_reach"] = mini(stufe, 20)
		spiel.upgrade_levels["scythe_speed"] = mini(stufe, 20)
		spiel.upgrade_levels["scythe_edge"] = mini(stufe, 30)
		schnitt.starte()
		var schritt := 1.0 / 60.0
		var rest := 18.0
		while rest > 0.0:
			# Zum naechsten Halm ziehen und dort bleiben.
			var nah := Vector2.INF
			var weit := INF
			for s in schnitt._halme.values():
				var d: float = (s.position - schnitt._hand).length()
				if d < weit:
					weit = d
					nah = s.position
			if nah != Vector2.INF:
				schnitt._ziel = nah
			schnitt._process(schritt)
			rest -= schritt
		print("Stufe %2d: %3d Halme -> %d Koeder  (Reichweite %.0f, Tempo %.1f, Schaerfe %.1f, %d Treffer je Halm)"
			% [stufe, schnitt._geschnitten,
				int(schnitt._geschnitten / 6),
				spiel.scythe_reach(), spiel.scythe_speed(), spiel.scythe_edge(),
				schnitt._noetig])
	quit()
