## Einstellungen. Jede Änderung wirkt sofort und wird gemerkt — ein Regler,
## der erst nach einem „Übernehmen" greift, fühlt sich kaputt an.
extends PanelBase

func refresh() -> void:
	clear(self)
	var s := Game.settings

	add_child(_title("Ton"))
	add_child(_toggle("Ton an", s.sound_enabled, func(on: bool) -> void:
		s.sound_enabled = on))
	add_child(_slider("Lautstärke Spiel", s.volume, func(v: float) -> void:
		s.volume = v))
	add_child(_slider("Lautstärke Menü", s.ui_volume, func(v: float) -> void:
		s.ui_volume = v))

	add_child(_title("Bequemlichkeit"))
	add_child(_toggle("Köder automatisch zurücksetzen", s.auto_fallback_bait,
		func(on: bool) -> void: s.auto_fallback_bait = on))
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Geht ein gekaufter Köder aus, wird auf die Teichmade zurückgeschaltet, statt das Angeln anzuhalten."
	hint.modulate = Palette.get_color(&"reed_light")
	add_child(hint)

	_dev_bereich()

## Schalter, die sonst an Uhrzeit, Zufall und Fangstand haengen. Ohne sie
## laesst sich weder der Anflug des Raben noch der Regen noch die Does-Pose
## ansehen, wenn das Spiel sie gerade nicht vorsieht.
func _dev_bereich() -> void:
	add_child(_title("Entwickler"))
	add_child(_dreifach("Rabe", Game.dev_raven, func(w: int) -> void:
		Game.dev_raven = w))
	add_child(_dreifach("Waschbär", Game.dev_trader, func(w: int) -> void:
		Game.dev_trader = w))
	add_child(_dreifach("Regen", Game.dev_rain, func(w: int) -> void:
		Game.dev_rain = w))

	var voll := Game.ctx != null and Game.ctx.inventory.dev_full
	var pose := TapButton.new()
	pose.custom_minimum_size = Vector2(0, 88)
	pose.text = "%s   Dös-Pose (Kiste „voll“)" % ["☑" if voll else "☐"]
	pose.tapped.connect(func() -> void:
		if Game.ctx == null:
			return
		Game.ctx.inventory.dev_full = not voll
		# Der Zustand wechselt sonst erst, wenn der laufende Wurf vorbei ist.
		if not voll:
			Game.sim.dev_pause()
		elif Game.sim.state == FishingSim.State.INVENTORY_FULL:
			Game.sim.state = FishingSim.State.IDLE
		refresh())
	add_child(pose)

	# Aufraeumen. Beim Ausprobieren ist nach kurzer Zeit alles voll, und dann
	# laesst sich nichts mehr pruefen, ohne neu anzufangen.
	add_child(_leeren("Fischkiste leeren", func() -> int:
		return Game.dev_clear_fish()))
	add_child(_leeren("Ködertasche leeren", func() -> int:
		return Game.dev_clear_bait()))

	# Ausbaustufen einzeln zurueck. Nicht alles auf einmal: zum Ausprobieren
	# will man EINEN Regler wieder am Anfang haben, nicht den Spielstand
	# verlieren.
	add_child(_title("Ausbau zurücksetzen"))
	for id in Database.upgrades:
		add_child(_stufe_zurueck(id))

	var zurueck := TapButton.new()
	zurueck.custom_minimum_size = Vector2(0, 88)
	zurueck.text = "Alles zurück auf Spielregeln"
	zurueck.tapped.connect(func() -> void:
		Game.dev_raven = -1
		Game.dev_trader = -1
		Game.dev_rain = -1
		if Game.ctx != null:
			Game.ctx.inventory.dev_full = false
			if Game.sim.state == FishingSim.State.INVENTORY_FULL:
				Game.sim.state = FishingSim.State.IDLE
		refresh())
	add_child(zurueck)

	var dev_hint := Label.new()
	dev_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dev_hint.text = "„Spielregeln“ heißt: das Spiel entscheidet wie sonst. Ein Wechsel auf „da“ oder „weg“ spielt Ankunft beziehungsweise Abgang ab und wird nicht gespeichert. Die Aufräumknöpfe darüber wirken dagegen sofort und bleiben — was weg ist, ist weg."
	dev_hint.modulate = Palette.get_color(&"reed_light")
	add_child(dev_hint)

## Ein Ausbau, mit seiner Stufe im Text. Ohne die Zahl weiss man nicht, ob
## der Knopf noch etwas zu tun hat.
func _stufe_zurueck(id: StringName) -> Control:
	var u: UpgradeData = Database.upgrades[id]
	var stufe := int(Game.upgrade_levels.get(id, 0))
	var b := TapButton.new()
	b.custom_minimum_size = Vector2(0, 72)
	b.text = "%s — Stufe %d" % [u.display_name, stufe]
	b.disabled = stufe <= 0
	b.tapped.connect(func() -> void:
		Game.dev_reset_upgrade(id)
		SaveManager.save()
		refresh())
	return b

## Ein Knopf, der etwas leert und sagt, wie viel es war. Ohne die Zahl weiss
## man nicht, ob er etwas getan hat oder schon leer war.
func _leeren(text: String, tun: Callable) -> Control:
	var b := TapButton.new()
	b.custom_minimum_size = Vector2(0, 88)
	b.text = text
	b.tapped.connect(func() -> void:
		var zahl: int = tun.call()
		b.text = "%s  (%d weg)" % [text, zahl]
		SaveManager.save())
	return b

## Ein Schalter mit drei Stellungen: Spielregeln, erzwungen da, erzwungen weg.
## Ein Knopf statt dreier -- die Liste ist ohnehin lang genug.
func _dreifach(text: String, wert: int, apply: Callable) -> Control:
	var wie := {-1: "Spielregeln", 0: "weg", 1: "da"}
	var b := TapButton.new()
	b.custom_minimum_size = Vector2(0, 88)
	b.text = "%s:   %s" % [text, wie[wert]]
	b.tapped.connect(func() -> void:
		apply.call(1 if wert == -1 else (0 if wert == 1 else -1))
		refresh())
	return b

func _title(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.modulate = Palette.get_color(&"accent")
	l.custom_minimum_size = Vector2(0, 56)
	return l

func _toggle(text: String, on: bool, apply: Callable) -> Control:
	var b := TapButton.new()
	b.custom_minimum_size = Vector2(0, 88)
	b.text = "%s   %s" % ["☑" if on else "☐", text]
	b.tapped.connect(func() -> void:
		apply.call(not on)
		Game.apply_settings())
	return b

func _slider(text: String, value: float, apply: Callable) -> Control:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s   %d %%" % [text, int(round(value * 100.0))]
	box.add_child(label)

	var row := HBoxContainer.new()
	for step in [-0.1, 0.1]:
		var b := TapButton.new()
		b.text = "−" if step < 0.0 else "+"
		b.custom_minimum_size = Vector2(112, 88)
		b.tapped.connect(func() -> void:
			var next := clampf(value + step, 0.0, 1.0)
			if is_equal_approx(next, value):
				b.refuse()
				return
			apply.call(next)
			Game.apply_settings()
			# Direkt hörbar machen, worauf der Regler wirkt.
			Audio.play(&"click", 0.0, text.ends_with("Menü")))
		row.add_child(b)
	box.add_child(row)
	return box
