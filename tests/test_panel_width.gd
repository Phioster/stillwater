extends TestCase

## Kein Panel darf breiter sein WOLLEN, als das Seitenmenue ist.
##
## Eine Beschriftung ohne Umbruch verlangt als Mindestbreite ihre volle
## Textbreite. Ein einziger langer Satz schiebt damit die ganze Gruppe ueber
## den Rahmen hinaus: der Sandgrund hoert an der richtigen Stelle auf, die
## Knoepfe laufen darueber weiter und verschwinden unter der Bildlaufleiste.
## Genau so sah der Koederreiter aus, und am Bild war die Ursache nicht zu
## sehen -- an dieser Zahl schon.

const MAIN := preload("res://scenes/main.gd")

## Was einem Panel wirklich zur Verfuegung steht: die Panelbreite ohne die
## beiden Rahmenraender und ohne die Bildlaufleiste.
func _platz() -> float:
	return MAIN.PANEL_WIDTH - 2.0 * float(UiTheme.RAHMEN_SEITE + 2) - 8.0

func _voll_ausgestattet() -> void:
	Game.new_game()
	# Auf Stufe 1 ist fast nichts freigeschaltet -- dann prueft der Test die
	# leeren Panels und nicht die vollen.
	Game.ctx.player_level = 99
	Game.coins = 9_000_000
	Game.unlocked_zones = []
	for id in Database.zones:
		Game.unlocked_zones.append(id)
	for id in Database.baits:
		Game.gain_bait(id, 1)
	for id in Database.consumables:
		Game.consumable_counts[id] = 3
	for id in Database.upgrades:
		Game.upgrade_levels[id] = 3

func _panels(n: Node, raus: Array[PanelBase]) -> void:
	if n is PanelBase:
		raus.append(n as PanelBase)
	for k in n.get_children():
		_panels(k, raus)

func test_no_panel_wants_more_width_than_the_side_panel_has() -> void:
	_voll_ausgestattet()
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	await tree.process_frame
	var gefunden: Array[PanelBase] = []
	_panels(m.get_node("SidePanel"), gefunden)
	assert_true(gefunden.size() >= 8,
		"nur %d Panels gefunden -- der Test sucht an der falschen Stelle"
			% gefunden.size())
	var platz := _platz()
	for p in gefunden:
		p.refresh()
		var will: float = p.get_combined_minimum_size().x
		assert_true(will <= platz,
			"%s will %.0f Punkte breit sein, hat aber nur %.0f"
				% [p.name, will, platz])
	m.free()
