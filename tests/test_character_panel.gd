extends TestCase

## Reihenfolge folgt character_panel.gd::SLOTS. Kindindex 0 ist der
## Hinweistext, HAT_ROW_INDEX zeigt auf die letzte Kategoriezeile.
const HAT_ROW_INDEX := 6

func _panel() -> PanelBase:
	# character_panel.gd ist ein Szenenskript ohne eigenen class_name, deshalb
	# per load() statt eines bare Bezeichners (wie in test_upgrade_panel.gd).
	var panel: PanelBase = load("res://scenes/ui/panels/character_panel.gd").new()
	panel.refresh()
	return panel

## Container-Typ absichtlich offen: die Varianten stehen in einem Raster,
## seit es elf Kopfteile sind -- der Test prueft die Knoepfe, nicht die Form.
func _hat_buttons(panel: PanelBase) -> Container:
	var row: VBoxContainer = panel.get_child(HAT_ROW_INDEX)
	return row.get_child(1)

func test_owned_variant_is_shown_as_a_toggled_wear_button() -> void:
	Game.new_game()
	var panel := _panel()
	var owned_button: Button = _hat_buttons(panel).get_child(0)  # Variante 0, immer frei
	assert_false(owned_button.disabled)
	assert_true(owned_button.toggle_mode)
	assert_true(owned_button.button_pressed, "Variante 0 ist die aktuell getragene")
	panel.free()

func test_unowned_variant_shows_price_from_game_cosmetic_cost() -> void:
	Game.new_game()
	var panel := _panel()
	var buy_button: Button = _hat_buttons(panel).get_child(1)  # Variante 1, nicht gekauft
	assert_true(("%d" % Game.cosmetic_cost(&"hat", 1)) in buy_button.text,
		"Preis muss aus Game.cosmetic_cost() kommen")
	panel.free()

func test_unowned_variant_is_disabled_when_level_too_low() -> void:
	Game.new_game()
	Game.coins = 100000
	Game.ctx.player_level = 1
	var panel := _panel()
	var buy_button: Button = _hat_buttons(panel).get_child(2)  # Variante 2, braucht Stufe 5
	assert_true(buy_button.disabled)
	assert_true("Stufe" in buy_button.text)
	panel.free()

func test_unowned_variant_is_disabled_when_coins_too_low() -> void:
	Game.new_game()
	Game.ctx.player_level = 10
	Game.coins = 0
	var panel := _panel()
	var buy_button: Button = _hat_buttons(panel).get_child(1)
	assert_true(buy_button.disabled)
	panel.free()

func test_unowned_variant_is_enabled_when_affordable() -> void:
	Game.new_game()
	Game.coins = 100000
	Game.ctx.player_level = 10
	var panel := _panel()
	var buy_button: Button = _hat_buttons(panel).get_child(1)
	assert_false(buy_button.disabled)
	panel.free()

func test_pressing_the_buy_button_purchases_the_cosmetic() -> void:
	Game.new_game()
	Game.coins = 100000
	Game.ctx.player_level = 10
	var panel := _panel()
	var buy_button: Button = _hat_buttons(panel).get_child(1)
	buy_button.pressed.emit()
	assert_true(Game.owns_cosmetic(&"hat", 1))
	panel.free()

func test_pressing_a_wear_button_only_works_when_owned() -> void:
	Game.new_game()
	var panel := _panel()
	var locked_button: Button = _hat_buttons(panel).get_child(1)  # nicht gekauft -> Kauf-Button
	assert_false(locked_button.toggle_mode, "eine nicht gekaufte Variante darf keinen Trage-Button zeigen")
	panel.free()
