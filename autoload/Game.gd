## Hält den Spielzustand und treibt die Simulation. Übersetzt deren
## Ereignisse in Signale — Spielregeln bleiben in core/.
extends Node

signal state_changed
## Feuert genau nach Verkauf, Upgrade-Kauf, Köderkauf und Zonenwechsel --
## SaveManager hängt den Autosave hier ein, statt dass jede Aktion save()
## selbst ruft.
signal progress_changed
signal bite(fish: FishData)
signal caught(fish_caught: CaughtFish, fish: FishData)
signal escaped(fish: FishData)
signal level_up(level: int)
signal inventory_full
signal coins_changed(value: int)

var coins: int = 0:
	set(value):
		var changed := value != coins
		coins = value
		if changed:
			coins_changed.emit(coins)
var upgrade_levels: Dictionary = {}
var unlocked_zones: Array[StringName] = []
var cosmetics: Dictionary = {}

var sim: FishingSim
var ctx: SimContext
var rng: StillRNG
var paused: bool = false

## Beschleunigt die Simulation für Entwicklung/Debug. Im Release 1 ungenutzt.
var time_scale: float = 1.0

func _ready() -> void:
	if ctx == null:
		new_game()

func new_game() -> void:
	rng = StillRNG.new(randi())
	sim = FishingSim.new()
	coins = 0
	upgrade_levels = {&"rod_power": 0, &"orb_power": 0, &"fish_inventory": 0, &"bait_capacity": 0}
	unlocked_zones = [&"willow_lake"]
	cosmetics = {"skin": 0, "hair": 0, "hair_color": 0, "shirt": 0, "pants": 0, "hat": 0}

	ctx = SimContext.new()
	ctx.zone = Database.zones[&"willow_lake"]
	ctx.fallback_bait = Database.basic_bait()
	ctx.bait = ctx.fallback_bait
	ctx.bait_counts = {}
	ctx.rarities = Database.rarities
	ctx.inventory = Inventory.new()
	ctx.journal = Journal.new()
	ctx.cosmetics = cosmetics
	ctx.player_level = 1
	ctx.player_xp = 0
	apply_upgrades()
	state_changed.emit()

func _process(delta: float) -> void:
	if paused or ctx == null:
		return
	_dispatch(sim.tick(delta * time_scale, ctx, rng))

func tap() -> void:
	if ctx == null:
		return
	_dispatch(sim.tap(ctx))

func _dispatch(events: Array) -> void:
	for e in events:
		match e["type"]:
			"bite":
				bite.emit(e["fish"])
			"caught":
				caught.emit(e["caught"], e["fish"])
			"escaped":
				escaped.emit(e["fish"])
			"level_up":
				level_up.emit(int(e["level"]))
			"inventory_full":
				inventory_full.emit()
	if not events.is_empty():
		state_changed.emit()

# --- Upgrades -------------------------------------------------------------

func upgrade_cost(id: StringName) -> int:
	var u: UpgradeData = Database.upgrades[id]
	return u.cost_at(int(upgrade_levels.get(id, 0)))

func upgrade_value(id: StringName) -> float:
	var u: UpgradeData = Database.upgrades[id]
	return u.value_at(int(upgrade_levels.get(id, 0)))

func buy_upgrade(id: StringName) -> bool:
	if not Database.upgrades.has(id):
		return false
	var u: UpgradeData = Database.upgrades[id]
	var level := int(upgrade_levels.get(id, 0))
	if level >= u.max_level:
		return false
	var cost := u.cost_at(level)
	if coins < cost:
		return false
	upgrade_levels[id] = level + 1
	apply_upgrades()
	coins -= cost
	state_changed.emit()
	progress_changed.emit()
	return true

## Setzt Rutenkraft/Orb-Kraft/Kapazität aus den aktuellen Upgrade-Stufen neu —
## wiederholtes Aufrufen (z.B. nach dem Laden) darf nicht doppelt wirken,
## weil hier immer der absolute Wert geschrieben wird statt addiert.
func apply_upgrades() -> void:
	ctx.rod_power = upgrade_value(&"rod_power")
	ctx.orb_power = upgrade_value(&"orb_power")
	ctx.inventory.capacity = int(upgrade_value(&"fish_inventory"))

func bait_capacity() -> int:
	return int(upgrade_value(&"bait_capacity"))

func bait_used() -> int:
	var total := 0
	for id in ctx.bait_counts:
		total += int(ctx.bait_counts[id])
	return total

# --- Verkauf ----------------------------------------------------------------

func _price(c: CaughtFish) -> int:
	var f: FishData = Database.fish.get(c.fish_id)
	if f == null:
		return 0
	return Economy.sell_price(c, f, ctx.rarity_of(f), ctx.consumable_bonus)

func sell_all() -> int:
	var earned := 0
	for c in ctx.inventory.take_sellable():
		earned += _price(c)
	coins += earned
	state_changed.emit()
	progress_changed.emit()
	return earned

func sell_one(index: int) -> int:
	if index < 0 or index >= ctx.inventory.fish.size():
		return 0
	var c: CaughtFish = ctx.inventory.fish[index]
	if c.is_favorite:
		return 0
	ctx.inventory.remove_at(index)
	var earned := _price(c)
	coins += earned
	state_changed.emit()
	progress_changed.emit()
	return earned

func toggle_favorite(index: int) -> void:
	if index < 0 or index >= ctx.inventory.fish.size():
		return
	ctx.inventory.fish[index].is_favorite = not ctx.inventory.fish[index].is_favorite
	state_changed.emit()

# --- Köder --------------------------------------------------------------------

## Einzige Stelle, die den Preis fuer eine Koeder-Kaufmenge kennt --
## buy_bait() und die Laden-Anzeige fragen beide hier ab statt selbst zu rechnen.
func bait_cost(id: StringName, amount: int) -> int:
	var b: BaitData = Database.baits.get(id)
	if b == null:
		return 0
	return b.cost * amount

func buy_bait(id: StringName, amount: int) -> bool:
	var b: BaitData = Database.baits.get(id)
	if b == null or b.unlimited or amount <= 0:
		return false
	if bait_used() + amount > bait_capacity():
		return false
	var cost := bait_cost(id, amount)
	if coins < cost:
		return false
	ctx.bait_counts[id] = int(ctx.bait_counts.get(id, 0)) + amount
	coins -= cost
	state_changed.emit()
	progress_changed.emit()
	return true

func set_active_bait(id: StringName) -> void:
	var b: BaitData = Database.baits.get(id)
	if b == null:
		return
	if not b.unlimited and int(ctx.bait_counts.get(id, 0)) <= 0:
		return
	ctx.bait = b
	state_changed.emit()

# --- Zonen --------------------------------------------------------------------

func unlock_zone(id: StringName) -> bool:
	var z: ZoneData = Database.zones.get(id)
	if z == null or id in unlocked_zones:
		return false
	if ctx.player_level < z.unlock_level or coins < z.unlock_cost:
		return false
	unlocked_zones.append(id)
	coins -= z.unlock_cost
	state_changed.emit()
	return true

func travel_to(id: StringName) -> bool:
	if not id in unlocked_zones:
		return false
	var z: ZoneData = Database.zones.get(id)
	if z == null:
		return false
	ctx.zone = z
	sim = FishingSim.new()
	state_changed.emit()
	progress_changed.emit()
	return true
