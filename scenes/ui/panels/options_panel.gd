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
