extends TestCase

## Kaufen im Laden, benutzen in der Ausruestung -- wie Cornerpond.

func _main() -> Control:
	var m: Control = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m

func _knoepfe(node: Node) -> Array[String]:
	var out: Array[String] = []
	for b in node.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return out

func _hat(texte: Array[String], teil: String) -> bool:
	for t in texte:
		if t.contains(teil):
			return true
	return false

func _koeder_mit_vorrat() -> BaitData:
	for b in Database.baits_in_order():
		if not b.unlimited:
			return b
	return null

func test_der_laden_verkauft_koeder_legt_sie_aber_nicht_an() -> void:
	Game.new_game()
	var b := _koeder_mit_vorrat()
	Game.ctx.player_level = b.unlock_level
	Game.ctx.bait_counts[b.id] = 3
	var m := _main()
	var laden: PanelBase = m.get_node("SidePanel/Panels/ShopGroup/ShopScroll/ShopPanel")
	laden.refresh()
	var texte := _knoepfe(laden)
	assert_false(_hat(texte, "Anlegen"), "der Laden legt an")
	assert_true(_hat(texte, "Auffüllen") or _hat(texte, "Tasche voll"), "der Laden verkauft nichts")
	m.free()

func test_die_ausruestung_legt_an_und_verkauft_nicht() -> void:
	Game.new_game()
	var b := _koeder_mit_vorrat()
	Game.ctx.player_level = b.unlock_level
	Game.ctx.bait_counts[b.id] = 3
	var m := _main()
	var aus: PanelBase = m.get_node("SidePanel/Panels/GearGroup/BaitScroll/BaitPanel")
	aus.refresh()
	var texte := _knoepfe(aus)
	assert_true(_hat(texte, "Anlegen"), "kein Anlegen in der Ausruestung")
	assert_false(_hat(texte, "Auffüllen"), "die Ausruestung verkauft")
	m.free()

func test_ein_koeder_ohne_vorrat_steht_nicht_in_der_ausruestung() -> void:
	Game.new_game()
	var b := _koeder_mit_vorrat()
	Game.ctx.player_level = b.unlock_level
	Game.ctx.bait_counts[b.id] = 0
	var m := _main()
	var aus: PanelBase = m.get_node("SidePanel/Panels/GearGroup/BaitScroll/BaitPanel")
	aus.refresh()
	var labels: Array[String] = []
	for l in aus.find_children("*", "Label", true, false):
		labels.append((l as Label).text)
	assert_false(_hat(labels, b.display_name), "%s ohne Vorrat in der Ausruestung" % b.display_name)
	m.free()

func test_auffuellen_wechselt_den_koeder_nicht() -> void:
	Game.new_game()
	Game.coins = 1_000_000
	var b := _koeder_mit_vorrat()
	Game.ctx.player_level = b.unlock_level
	var vorher := Game.ctx.bait.id
	Game.refill_bait(b.id)
	assert_eq(Game.ctx.bait.id, vorher)

func test_aussehen_tragen_zeigt_nur_was_man_hat() -> void:
	Game.new_game()
	var m := _main()
	var look: PanelBase = m.get_node("SidePanel/Panels/GearGroup/LookScroll/LookPanel")
	look.refresh()
	for b in look.find_children("*", "Button", true, false):
		assert_false((b as Button).text.contains("kaufen") or (b as Button).text.contains("⨀"),
			"im Tragen-Modus steht etwas Kaufbares: %s" % (b as Button).text)
	m.free()

func test_aussehen_kaufen_zeigt_gekauftes_als_gekauft() -> void:
	Game.new_game()
	var m := _main()
	var laden: PanelBase = m.get_node("SidePanel/Panels/ShopGroup/CharacterScroll/CharacterPanel")
	laden.refresh()
	var gekauft := 0
	for b in laden.find_children("*", "Button", true, false):
		if (b as Button).text.contains("✓ gekauft"):
			gekauft += 1
			assert_true((b as Button).disabled, "Gekauftes laesst sich im Laden antippen")
	assert_true(gekauft > 0, "die Grundausstattung fehlt als gekauft")
	m.free()

func test_der_haendler_reiter_nur_wenn_er_da_ist() -> void:
	Game.new_game()
	Game.dev_trader = 0
	var m := _main()
	var laden: TabGroup = m.get_node("SidePanel/Panels/ShopGroup")
	m._update_trader_sub()
	assert_false(laden._buttons[m.SHOP_SUB_TRADER].visible, "Haendler-Reiter ohne Haendler")
	Game.dev_trader = 1
	m._open_trader()
	assert_true(laden._buttons[m.SHOP_SUB_TRADER].visible)
	assert_eq(laden.active_sub(), m.SHOP_SUB_TRADER)
	Game.dev_trader = -1
	m.free()

func test_quest_ready() -> void:
	Game.new_game()
	Game.ctx.player_level = 60
	var angebot := Game.quest_offer()
	if angebot.is_empty():
		return
	assert_false(Game.quest_ready(), "ohne Fisch ist nichts abgebbar")
	var c := CaughtFish.make(angebot[0], 0.0)
	Game.ctx.inventory.add(c)
	assert_true(Game.quest_ready())
	c.is_favorite = true
	assert_false(Game.quest_ready(), "ein Vitrinenfisch zaehlt nicht")

func test_der_orte_knopf_zeigt_regen() -> void:
	Game.new_game()
	var m := _main()
	var rail = m.get_node("Row/TabRail")
	rail.refresh_hints()
	var nass := Game.rain_zone() in Game.unlocked_zones
	assert_eq(rail._buttons[rail.PLACES_TAB].text.contains("☂"), nass)
	m.free()
