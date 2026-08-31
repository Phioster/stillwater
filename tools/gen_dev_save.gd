## Erzeugt einen Entwickler-Spielstand: alles freigeschaltet, alles entdeckt.
##
## Ueber das Spiel selbst erzeugt statt von Hand als JSON geschrieben -- so
## kann er gar nicht vom Schema abweichen, und er waechst automatisch mit,
## wenn Zonen oder Arten dazukommen.
##
##   PROJECT=$HOME/stillwater bash tools/godot.sh --script res://tools/gen_dev_save.gd
##
## Schreibt nach user://dev_save.json.
extends SceneTree

const LEVEL: int = 60
const COINS: int = 9_000_000

func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var saver: Node = root.get_node("SaveManager")
	var db: Node = root.get_node("Database")
	game.paused = true
	game.new_game()

	game.coins = COINS
	game.ctx.player_level = LEVEL
	game.ctx.player_xp = 0

	for id in db.zones:
		if not game.unlocked_zones.has(id):
			game.unlocked_zones.append(id)

	# Ausbau auf die Haelfte der Hoechststufe: hoch genug, um alles zu sehen,
	# niedrig genug, dass Kaufen noch etwas zeigt.
	for id in db.upgrades:
		var u: UpgradeData = db.upgrades[id]
		game.upgrade_levels[id] = maxi(u.max_level / 2, 5)
	game.apply_upgrades()

	for id in db.cosmetics:
		var c: CosmeticData = db.cosmetics[id]
		var owned: Array = game.owned_cosmetics.get(String(c.category), [])
		if not owned.has(c.variant):
			owned.append(c.variant)
		game.owned_cosmetics[String(c.category)] = owned

	# Von jedem Trank ein paar, damit sich alles ausprobieren laesst.
	for id in db.consumables:
		game.consumable_counts[id] = 5

	for id in db.baits:
		var b: BaitData = db.baits[id]
		if not b.unlimited:
			game.ctx.bait_counts[b.id] = 99

	# Jede Art einmal je Rang eintragen: dann ist das Journal voll, die
	# Rangleiste zeigt etwas, und die Geheimreiter existieren.
	var rng := StillRNG.new(4242)
	for id in db.fish:
		var f: FishData = db.fish[id]
		# Die MITTE jedes Rangbandes, nicht die Schwelle plus Aufschlag: sonst
		# faellt der Wert fuer Rang E ueber die Grenze und E fehlt im Journal.
		for rank in FishRoll.RANK_NAMES.size():
			var dev: float = [-2.5, -1.0, 0.0, 1.0, 1.9, 2.6, 3.3][rank]
			var shiny := rank == 6 and rng.randf() < 0.35
			game.ctx.journal.record(CaughtFish.make(f.id, dev, shiny), f.is_secret)

	# Ein paar Fische im Inventar, damit Verkaufen und Vitrine etwas zeigen.
	var zone_fish: Array = db.fish_of_zone(&"star_lake")
	for i in mini(6, zone_fish.size()):
		var caught := CaughtFish.make(zone_fish[i].id, 1.8, i == 0)
		game.ctx.inventory.add(caught)

	var path := "user://dev_save.json"
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(JSON.stringify(saver.serialize()))
	f2.close()
	print("DEV-SPIELSTAND geschrieben: ", ProjectSettings.globalize_path(path))
	print("  Stufe ", game.ctx.player_level, ", ", game.coins, " Muenzen, ",
		game.unlocked_zones.size(), " Zonen, ",
		game.ctx.journal.entries.size(), " Arten im Journal")
	quit()
