extends TestCase

const MAIN := preload("res://scenes/main.gd")

func _bar() -> BuffBar:
	var b := BuffBar.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	return b

func test_zeit_format() -> void:
	assert_eq(BuffBar.zeit(760.0), "12:40")
	assert_eq(BuffBar.zeit(59.2), "1:00")
	assert_eq(BuffBar.zeit(5.0), "0:05")

func test_ohne_trank_unsichtbar() -> void:
	Game.new_game()
	var b := _bar()
	b.refresh()
	assert_false(b.visible)
	b.free()

func test_zeigt_die_laufenden_in_trinkreihenfolge() -> void:
	Game.new_game()
	Game.buffs.apply(Database.consumables[&"wert_trank"])
	Game.buffs.apply(Database.consumables[&"mondglas"])
	var b := _bar()
	b.refresh()
	assert_true(b.visible)
	assert_eq(b.ids(), [&"wert_trank", &"mondglas"])
	b.free()

## Alle acht Gruppen gleichzeitig -- mehr geht nicht, gleiche Gruppe ersetzt.
func test_passt_links_neben_das_offene_menue() -> void:
	var frei := 1280.0 - MAIN.RAIL_WIDTH - MAIN.PANEL_WIDTH
	assert_true(16.0 + 8.0 * BuffBar.EINTRAG_BREITE + 7.0 * 8.0 <= frei,
		"acht Eintraege reichen bis unter das Menue")
	assert_true(MAIN.BUFF_TOP >= 116.0, "liegt in der Kopfzeile")

## Die Szene traegt den Startwert, main.gd setzt ihn je Durchlauf neu -- beide
## muessen dieselbe Zahl meinen.
func test_main_haengt_die_reihe_an_die_konstante() -> void:
	var m: Control = load("res://scenes/main.tscn").instantiate()
	var b: Control = m.get_node("BuffBar")
	assert_true(b.get_script() == load("res://scenes/ui/buff_bar.gd"))
	assert_almost_eq(b.offset_top, MAIN.BUFF_TOP, 0.5)
	assert_almost_eq(b.offset_left, 16.0, 0.5)
	m.free()

## Solange dieselben Traenke laufen, bleiben die Knoepfe dieselben -- nur die
## Zeit laeuft weiter.
func test_die_knoepfe_bleiben_beim_ticken_stehen() -> void:
	Game.new_game()
	Game.buffs.apply(Database.consumables[&"wert_trank"])
	var b := _bar()
	b.refresh()
	var vorher := b.get_child(0)
	Game.buffs.tick(5.0)
	b.refresh()
	assert_true(b.get_child(0) == vorher, "Knopf wurde neu gebaut")
	var label: Label = b._teile[&"wert_trank"][0]
	assert_eq(label.text, BuffBar.zeit(Game.buffs.remaining(&"wert_trank")))
	b.free()
