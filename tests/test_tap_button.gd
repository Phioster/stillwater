extends TestCase

## TapButton loest zwei Dinge auf einmal: die Liste muss sich ueber den
## Knoepfen wischen lassen, und ein Wischen darf den Knopf nicht ausloesen.

func _button() -> TapButton:
	var b := TapButton.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	return b

func _press_at(b: TapButton, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.global_position = pos
	b._gui_input(e)

func test_events_pass_through_to_the_scroll_container() -> void:
	var b := _button()
	assert_eq(b.mouse_filter, Control.MOUSE_FILTER_PASS,
		"mit STOP sieht der ScrollContainer die Wischgeste nie")
	b.free()

func test_a_clean_press_taps() -> void:
	var b := _button()
	var hits := [0]
	b.tapped.connect(func() -> void: hits[0] += 1)
	_press_at(b, b.get_global_mouse_position())
	b.pressed.emit()
	assert_eq(hits[0], 1)
	b.free()

func test_a_press_that_wandered_far_does_not_tap() -> void:
	var b := _button()
	var hits := [0]
	b.tapped.connect(func() -> void: hits[0] += 1)
	# Aufgesetzt weit weg von der Stelle, an der jetzt losgelassen wird:
	# genau das passiert, wenn die Liste unter dem Finger weggescrollt ist.
	_press_at(b, b.get_global_mouse_position() + Vector2(0, 400))
	b.pressed.emit()
	assert_eq(hits[0], 0, "ein Wischen darf den Knopf nicht ausloesen")
	b.free()

func test_without_a_recorded_start_it_still_taps() -> void:
	var b := _button()
	var hits := [0]
	b.tapped.connect(func() -> void: hits[0] += 1)
	b.pressed.emit()
	assert_eq(hits[0], 1, "ohne Startpunkt lieber ausloesen als tot sein")
	b.free()

## Jede Zeile in jeder Liste muss durchlassen -- ein einzelner gewoehnlicher
## Button reisst wieder ein Loch in den Scrollbereich.
func test_every_panel_row_lets_the_drag_through() -> void:
	Game.new_game()
	var tree := Engine.get_main_loop() as SceneTree
	var main: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	var checked := 0
	var panels: Node = main.get_node("SidePanel/Panels")
	for i in panels.get_child_count():
		# Panels bauen ihre Zeilen erst beim Sichtbarwerden.
		main.show_tab(i)
		for button in _buttons_in(panels.get_child(i)):
			checked += 1
			assert_eq(button.mouse_filter, Control.MOUSE_FILTER_PASS,
				"%s laesst nicht durch" % button.get_path())
	assert_true(checked > 0, "keine Knoepfe gefunden -- der Test prueft nichts")
	main.free()

func _buttons_in(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button:
		found.append(node as Button)
	for child in node.get_children():
		found.append_array(_buttons_in(child))
	return found

## Ein Knopf muss auf die Berührung sichtbar reagieren, sonst wirkt er tot.
func test_pressing_a_button_makes_it_spring() -> void:
	var b := _button()
	b.size = Vector2(100, 100)
	b._process(0.016)
	assert_almost_eq(b.scale.x, 1.0, 0.001, "in Ruhe steht er still")
	b.button_down.emit()
	b._process(0.016)
	assert_true(b.scale.x < 1.0, "beim Drücken muss er einfedern")
	for i in 400:
		b._process(0.016)
	assert_almost_eq(b.scale.x, 1.0, 0.001, "danach muss er zurückkommen")
	b.free()

## Eine abgelehnte Aktion muss man sehen. Ohne das wirkt der Knopf kaputt.
func test_a_refused_action_shakes_and_settles() -> void:
	var b := _button()
	b.position = Vector2(50, 20)
	b._process(0.016)
	b.refuse()
	b._process(0.016)
	assert_true(absf(b.position.x - 50.0) > 0.01, "der Knopf muss wackeln")
	for i in 60:
		b._process(0.016)
	assert_almost_eq(b.position.x, 50.0, 0.001, "danach muss er wieder still stehen")
	b.free()

## Der Ausgangspunkt darf beim Wackeln nicht mitwandern -- sonst kriecht der
## Knopf mit jedem Fehlversuch weiter nach rechts.
func test_repeated_refusals_do_not_drift() -> void:
	var b := _button()
	b.position = Vector2(50, 20)
	b._process(0.016)
	for round in 5:
		b.refuse()
		for i in 60:
			b._process(0.016)
	assert_almost_eq(b.position.x, 50.0, 0.001, "der Knopf ist weggewandert")
	b.free()
