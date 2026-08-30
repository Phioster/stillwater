extends TestCase

## Nachschwung: beim Loslassen rollt die Liste aus. Geprüft wird das
## Verhalten am Rand und beim Anhalten -- dort geht so etwas kaputt.

func _scroller() -> ScrollContainer:
	var tree := Engine.get_main_loop() as SceneTree
	var sc := ScrollContainer.new()
	sc.size = Vector2(200, 200)
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(200, 4000)
	sc.add_child(inner)
	tree.root.add_child(sc)
	return sc

func _press(g: GlideScroll, y: float, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = down
	e.position = Vector2(0, y)
	g.on_input(e)

func test_a_release_keeps_the_list_rolling() -> void:
	var sc := _scroller()
	var g := GlideScroll.new(sc)
	_press(g, 100.0, true)
	# Ziehen: die Liste bewegt sich, die Geschwindigkeit wird daraus gemessen.
	for i in 5:
		sc.scroll_vertical += 30
		g.update(0.016)
	_press(g, 40.0, false)
	var at_release := sc.scroll_vertical
	g.update(0.016)
	assert_true(sc.scroll_vertical > at_release, "die Liste bleibt sofort stehen")
	sc.free()

func test_it_slows_down_and_stops() -> void:
	var sc := _scroller()
	var g := GlideScroll.new(sc)
	_press(g, 100.0, true)
	for i in 5:
		sc.scroll_vertical += 30
		g.update(0.016)
	_press(g, 40.0, false)
	for i in 400:
		g.update(0.016)
	assert_almost_eq(g._velocity, 0.0, 0.001, "der Nachschwung endet nicht")
	sc.free()

## Am Ende der Liste muss der Rest verworfen werden, sonst rechnet der
## Nachschwung stumm weiter und die Liste ruckt beim nächsten Zug.
func test_hitting_the_end_drops_the_momentum() -> void:
	var sc := _scroller()
	var g := GlideScroll.new(sc)
	sc.scroll_vertical = 999999
	var top := sc.scroll_vertical
	g._velocity = 3000.0
	g.update(0.016)
	assert_eq(sc.scroll_vertical, top, "weiter geht es nicht")
	assert_almost_eq(g._velocity, 0.0, 0.001, "der Schwung muss verworfen sein")
	sc.free()

## Ein neuer Griff hält die Liste sofort an -- sonst kämpft der Finger gegen
## den alten Schwung.
func test_touching_again_stops_the_glide_at_once() -> void:
	var sc := _scroller()
	var g := GlideScroll.new(sc)
	g._velocity = 2000.0
	_press(g, 100.0, true)
	assert_almost_eq(g._velocity, 0.0, 0.001)
	sc.free()

func test_the_speed_is_capped() -> void:
	var sc := _scroller()
	var g := GlideScroll.new(sc)
	_press(g, 100.0, true)
	sc.scroll_vertical += 3000
	g.update(0.001)
	assert_between(g._velocity, -GlideScroll.MAX_SPEED - 0.1, GlideScroll.MAX_SPEED + 0.1)
	sc.free()
