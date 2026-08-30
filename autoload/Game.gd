## Hält den Spielzustand und treibt die Simulation. Übersetzt deren
## Ereignisse in Signale — Spielregeln bleiben in core/.
extends Node

signal state_changed
## Feuert genau nach Verkauf, Upgrade-Kauf, Köderkauf und Zonenwechsel --
## SaveManager hängt den Autosave hier ein, statt dass jede Aktion save()
## selbst ruft.
signal progress_changed
signal bite(fish: FishData)
signal caught(fish_caught: CaughtFish, fish: FishData, discovered: bool, record: bool)
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
var settings := Settings.new()
var unlocked_zones: Array[StringName] = []
var cosmetics: Dictionary = {}
## Kategorie (String) -> Array der besessenen Varianten. Variante 0 jeder
## Kategorie ist immer dabei, siehe new_game().
var owned_cosmetics: Dictionary = {}

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
	upgrade_levels = {&"rod_power": 0, &"orb_power": 0, &"fish_inventory": 0, &"favorite_inventory": 0, &"bait_capacity": 0}
	unlocked_zones = [&"willow_lake"]
	cosmetics = {"skin": 0, "hair": 0, "hair_color": 0, "shirt": 0, "pants": 0, "hat": 0}
	owned_cosmetics = {}
	for category in cosmetics:
		owned_cosmetics[category] = [0]

	# Fehlen die Daten, bricht der Aufbau sonst mitten drin ab und hinterlaesst
	# ein ctx ohne Inventar -- worauf die Simulation in JEDEM Frame scheitert.
	# Lieber gar kein ctx als ein halbes.
	if not Database.zones.has(&"willow_lake") or Database.basic_bait() == null:
		push_error("Spieldaten fehlen, kein neues Spiel moeglich")
		ctx = null
		return

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
	# Einmal pro Frame die echte Stunde nachfuehren. Der Offline-Nachlauf
	# rechnet mit der Stunde der Rueckkehr -- ein Tagesfenster ueber Stunden
	# hinweg nachzubilden waere Aufwand ohne spuerbaren Gewinn.
	ctx.hour_of_day = Time.get_datetime_dict_from_system()["hour"]
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
				caught.emit(e["caught"], e["fish"], bool(e["discovered"]), bool(e["record"]))
			"escaped":
				escaped.emit(e["fish"])
			"level_up":
				Audio.play(&"level_up")
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
	ctx.inventory.favorite_capacity = int(upgrade_value(&"favorite_inventory"))

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
	if earned > 0:
		Audio.play(&"coin")
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
	Audio.play(&"coin")
	coins += earned
	state_changed.emit()
	progress_changed.emit()
	return earned

## Gibt false zurueck, wenn die Favoritenkiste voll ist -- das Panel sagt es
## dann, statt den Tipp stumm verschwinden zu lassen.
func toggle_favorite(index: int) -> bool:
	if index < 0 or index >= ctx.inventory.fish.size():
		return false
	var c: CaughtFish = ctx.inventory.fish[index]
	if not c.is_favorite and ctx.inventory.favorites_full():
		return false
	c.is_favorite = not c.is_favorite
	state_changed.emit()
	progress_changed.emit()
	return true

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
	# Auch im Modell pruefen, nicht nur in der Anzeige: der Laden ist nicht
	# der einzige moegliche Aufrufer, und eine Regel, die nur die Oberflaeche
	# kennt, ist keine Regel.
	if ctx.player_level < b.unlock_level:
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

## Wie viele Koeder noch in die Tasche passen. Der Vorrat ist gemeinsam, also
## zaehlt der Gesamtbestand -- nicht der dieser einen Sorte.
func bait_refill_amount() -> int:
	return maxi(bait_capacity() - bait_used(), 0)

func bait_refill_cost(id: StringName) -> int:
	return bait_cost(id, bait_refill_amount())

## Ein Griff statt einer Mengenwahl: die Tasche wird voll, soweit das Geld
## reicht. Wer nur ein Stueck will, waehlt keine Menge -- er will einfach
## weiterangeln.
func refill_bait(id: StringName) -> int:
	var b: BaitData = Database.baits.get(id)
	if b == null or b.unlimited:
		return 0
	var amount := bait_refill_amount()
	# Erst grob ueber den Stueckpreis schaetzen, dann nachtrimmen: die
	# Schleife allein waere bei grosser Tasche unnoetig lang, die Schaetzung
	# allein wuerde eine spaeter nichtlineare Preisformel verfehlen.
	var unit := bait_cost(id, 1)
	if unit > 0:
		amount = mini(amount, coins / unit)
	while amount > 0 and bait_cost(id, amount) > coins:
		amount -= 1
	if amount <= 0:
		return 0
	buy_bait(id, amount)
	return amount

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

# --- Kosmetik -----------------------------------------------------------------

enum CosmeticState { UNKNOWN, OWNED, LOCKED_LEVEL, LOCKED_COINS, BUYABLE }

func owns_cosmetic(category: StringName, variant: int) -> bool:
	var owned: Array = owned_cosmetics.get(String(category), [])
	return variant in owned

## Einzige Stelle, die die Freischaltregel kennt -- buy_cosmetic() entscheidet
## danach, das Charakter-Panel zeigt danach an. Keine zweite Kopie der Regel.
func cosmetic_state(category: StringName, variant: int) -> CosmeticState:
	var c: CosmeticData = Database.cosmetic_of(category, variant)
	if c == null:
		return CosmeticState.UNKNOWN
	if owns_cosmetic(category, variant):
		return CosmeticState.OWNED
	if ctx.player_level < c.unlock_level:
		return CosmeticState.LOCKED_LEVEL
	if coins < c.cost:
		return CosmeticState.LOCKED_COINS
	return CosmeticState.BUYABLE

## Einzige Stelle, die den Kosmetik-Preis kennt -- buy_cosmetic() und das
## Charakter-Panel fragen beide hier ab statt selbst zu rechnen.
func cosmetic_cost(category: StringName, variant: int) -> int:
	var c: CosmeticData = Database.cosmetic_of(category, variant)
	return c.cost if c != null else 0

func buy_cosmetic(category: StringName, variant: int) -> bool:
	if cosmetic_state(category, variant) != CosmeticState.BUYABLE:
		return false
	var c: CosmeticData = Database.cosmetic_of(category, variant)
	var key := String(category)
	var owned: Array = owned_cosmetics.get(key, [])
	owned.append(variant)
	owned_cosmetics[key] = owned
	coins -= c.cost
	state_changed.emit()
	progress_changed.emit()
	return true

## Zieht nur an, was owns_cosmetic() bereits bestätigt -- kein Wechsel ohne Besitz.
func set_cosmetic(category: StringName, variant: int) -> bool:
	if not owns_cosmetic(category, variant):
		return false
	cosmetics[String(category)] = variant
	ctx.cosmetics = cosmetics
	state_changed.emit()
	return true

## Einstellungen wirken sofort und werden gemerkt. Eine Stelle, damit ein
## Regler nicht vergessen kann, sein Ziel zu benachrichtigen.
func apply_settings() -> void:
	Audio.enabled = settings.sound_enabled
	Audio.volume = settings.volume
	Audio.ui_volume = settings.ui_volume
	if ctx != null:
		ctx.auto_fallback_bait = settings.auto_fallback_bait
	state_changed.emit()
	progress_changed.emit()
