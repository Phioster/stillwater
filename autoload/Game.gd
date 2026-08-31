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
var buffs := Buffs.new()
var visitors := Visitors.new()
var quests := Quests.new()
var records := Records.new()
## Wie viele Traenke jeder Sorte im Vorrat sind.
var consumable_counts: Dictionary = {}
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
	upgrade_levels = {&"rod_power": 0, &"orb_power": 0, &"fish_inventory": 0, &"favorite_inventory": 0, &"bait_capacity": 0, &"trader": 0, &"quests": 0}
	visitors = Visitors.new()
	quests = Quests.new()
	records = Records.new()
	unlocked_zones = [&"willow_lake"]
	cosmetics = {"skin": 0, "hair": 0, "hair_color": 0, "shirt": 0, "pants": 0,
		"hat": 0, "rod": 0}
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
	records.playtime += delta
	# Traenke laufen NUR bei offenem Spiel ab -- siehe core/buffs.gd.
	# Besucher haengen an der Uhr, nicht an einem Countdown -- der Wechsel
	# faellt hier nur auf, damit die Anzeige sich neu zeichnet.
	var now := Time.get_unix_time_from_system()
	if visitors.refresh_trader(now) or quests.refresh(now):
		state_changed.emit()
	var wet := raining()
	if wet != ctx.raining:
		ctx.raining = wet
		state_changed.emit()
	var before := buffs.active.size()
	buffs.tick(delta * time_scale)
	if buffs.active.size() != before:
		apply_buffs()
		state_changed.emit()
	_dispatch(sim.tick(delta * time_scale, ctx, rng))

func tap() -> void:
	if ctx == null:
		return
	if sim.state == FishingSim.State.FIGHT:
		records.orbs_tapped += 1
	_dispatch(sim.tap(ctx))

func _dispatch(events: Array) -> void:
	for e in events:
		match e["type"]:
			"cast":
				records.casts += 1
			"bite":
				bite.emit(e["fish"])
			"caught":
				records.fish_caught += 1
				if (e["caught"] as CaughtFish).is_shiny:
					records.shiny_caught += 1
				caught.emit(e["caught"], e["fish"], bool(e["discovered"]), bool(e["record"]))
			"escaped":
				records.fish_escaped += 1
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
	records.coins_spent += cost
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
	var sold := ctx.inventory.take_sellable()
	for c in sold:
		earned += _price(c)
	if earned > 0:
		Audio.play(&"coin")
		records.fish_sold += sold.size()
	records.coins_earned += earned
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
	records.fish_sold += 1
	records.coins_earned += earned
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
	records.coins_spent += cost
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
	records.coins_spent += z.unlock_cost
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
	records.coins_spent += c.cost
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

# --- Traenke ------------------------------------------------------------------

## Traegt die laufenden Traenke in den Simulationskontext. Eine Stelle, damit
## ein neuer Trank nicht vergessen kann, sich irgendwo einzutragen.
func apply_buffs() -> void:
	if ctx == null:
		return
	ctx.shiny_bonus = buffs.product(&"shiny_mult")
	ctx.consumable_bonus = buffs.product(&"value_mult")
	ctx.xp_bonus = buffs.product(&"xp_mult")
	ctx.bite_bonus = buffs.product(&"bite_time_mult")
	ctx.fight_bonus = buffs.product(&"fight_time_mult")
	ctx.rarity_bonus = buffs.rarity_bonus()
	ctx.rank_bonus = buffs.rank_shift()
	ctx.free_bait = buffs.flag(&"free_bait")
	ctx.ignore_time_of_day = buffs.flag(&"ignore_time_of_day")

func consumable_count(id: StringName) -> int:
	return int(consumable_counts.get(id, 0))

func buy_consumable(id: StringName, amount: int = 1) -> bool:
	var c: ConsumableData = Database.consumables.get(id)
	if c == null or amount <= 0 or ctx.player_level < c.unlock_level:
		return false
	var price := c.cost * amount
	if coins < price:
		return false
	coins -= price
	records.coins_spent += price
	consumable_counts[id] = consumable_count(id) + amount
	state_changed.emit()
	progress_changed.emit()
	return true

## Trinken. Gibt false zurueck, wenn keiner im Vorrat ist -- das Panel laesst
## den Knopf dann wackeln, statt stumm nichts zu tun.
func use_consumable(id: StringName) -> bool:
	var c: ConsumableData = Database.consumables.get(id)
	if c == null or consumable_count(id) <= 0:
		return false
	consumable_counts[id] = consumable_count(id) - 1
	if consumable_counts[id] <= 0:
		consumable_counts.erase(id)
	records.potions_drunk += 1
	buffs.apply(c)
	apply_buffs()
	state_changed.emit()
	progress_changed.emit()
	return true

# --- Besucher -----------------------------------------------------------------

## Stufe 0 heisst: man kennt ihn noch nicht. Erst der Kauf macht ihn
## ueberhaupt sichtbar, danach bringt er mehr mit -- zwei bis fuenf.
func trader_unlocked() -> bool:
	return int(upgrade_levels.get(&"trader", 0)) > 0

func trader_offer_size() -> int:
	return int(upgrade_value(&"trader")) if trader_unlocked() else 0

## Steht er gerade am Steg? Nach einem Kauf verschwindet er, sobald der Laden
## zugeht, und kommt erst zur nächsten Stunde wieder.
func trader_present() -> bool:
	return trader_unlocked() and not visitors.trader_gone

## Der Laden wurde geschlossen. Wer gekauft hat, sieht den Händler danach
## weiterziehen -- der Abschied hängt am Schließen, nicht am Kauf selbst,
## sonst verschwände er dem Spieler unter den Fingern weg.
func close_shop() -> void:
	if visitors.trader_leave():
		state_changed.emit()

func trader_offer() -> Array[StringName]:
	if not trader_present():
		return []
	return visitors.trader_offer(Time.get_unix_time_from_system(), trader_offer_size())

## Beim Haendler kaufen. Was gekauft ist, ist fuer diese Stunde weg -- ein
## Angebot, das sich nachfuellt, waere ein Automat und kein Besuch.
func buy_from_trader(id: StringName) -> bool:
	var c: ConsumableData = Database.consumables.get(id)
	if c == null or visitors.sold_out(id) or not trader_offer().has(id):
		return false
	if not buy_consumable(id, 1):
		return false
	visitors.trader_buy(id)
	state_changed.emit()
	return true

func reroll_trader() -> bool:
	if not trader_present() or coins < Visitors.REROLL_COST:
		return false
	coins -= Visitors.REROLL_COST
	records.coins_spent += Visitors.REROLL_COST
	visitors.reroll()
	state_changed.emit()
	progress_changed.emit()
	return true

func raven_waiting() -> bool:
	return visitors.raven_waiting(Time.get_unix_time_from_system())

## Das Paket des Raben. Es wartet, bis es jemand aufhebt -- verfallen zu
## lassen, was man verpasst hat, bestraft Abwesenheit.
func collect_raven() -> StringName:
	var now := Time.get_unix_time_from_system()
	if not visitors.raven_waiting(now):
		return &""
	var gift := visitors.raven_gift(now)
	visitors.collect_raven(now)
	if gift != &"":
		consumable_counts[gift] = consumable_count(gift) + 1
	Audio.play(&"coin")
	state_changed.emit()
	progress_changed.emit()
	return gift

# --- Auftraege ----------------------------------------------------------------

func quests_unlocked() -> bool:
	return int(upgrade_levels.get(&"quests", 0)) > 0

func quest_count() -> int:
	return int(upgrade_value(&"quests")) + 1 if quests_unlocked() else 0

## Nur Arten aus Zonen, die man erreichen kann, und keine Geheimfische --
## ein Auftrag, den man nicht erfuellen kann, waere eine Sperre.
func quest_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for zone_id in unlocked_zones:
		for f in Database.fish_of_zone(zone_id):
			if not f.is_secret:
				out.append(f.id)
	out.sort()
	return out

func quest_offer() -> Array[StringName]:
	if not quests_unlocked():
		return []
	return quests.offer(Time.get_unix_time_from_system(), quest_count(), quest_pool())

## Lohn fuer einen Auftrag: ein Vielfaches des Verkaufswerts, damit Abgeben
## sich lohnt, statt den Fisch einfach zu verkaufen.
func quest_reward(id: StringName) -> Dictionary:
	var f: FishData = Database.fish.get(id)
	if f == null:
		return {"coins": 0, "xp": 0}
	var rarity := ctx.rarity_of(f)
	var sample := CaughtFish.make(id, 0.0, false)
	return {
		"coins": int(round(float(Economy.sell_price(sample, f, rarity)) * Quests.MONEY_FACTOR)),
		"xp": int(round(float(Progression.xp_for_catch(f, rarity, 2)) * Quests.XP_FACTOR)),
	}

## Findet den passendsten Fisch im Inventar: den LEICHTESTEN, damit ein
## Rekordexemplar nicht versehentlich weggegeben wird. Favoriten bleiben tabu.
func _cheapest_matching(id: StringName) -> int:
	var best := -1
	for i in ctx.inventory.fish.size():
		var c: CaughtFish = ctx.inventory.fish[i]
		if c.fish_id != id or c.is_favorite:
			continue
		if best < 0 or c.weight_dev < ctx.inventory.fish[best].weight_dev:
			best = i
	return best

func can_hand_in(id: StringName) -> bool:
	return quests_unlocked() and not quests.is_done(id) \
		and quest_offer().has(id) and _cheapest_matching(id) >= 0

func hand_in_quest(id: StringName) -> bool:
	if not can_hand_in(id):
		return false
	var index := _cheapest_matching(id)
	ctx.inventory.remove_at(index)
	var reward := quest_reward(id)
	coins += int(reward["coins"])
	var after := Progression.apply_xp(ctx.player_level, ctx.player_xp, int(reward["xp"]))
	ctx.player_level = int(after["level"])
	ctx.player_xp = int(after["xp"])
	quests.complete(id)
	records.quests_done += 1
	records.coins_earned += int(reward["coins"])
	if int(after["levels_gained"]) > 0:
		Audio.play(&"level_up")
		level_up.emit(ctx.player_level)
	else:
		Audio.play(&"coin")
	state_changed.emit()
	progress_changed.emit()
	return true

## Regnet es gerade dort, wo geangelt wird?
func raining() -> bool:
	if ctx == null or ctx.zone == null:
		return false
	return Weather.is_raining(Time.get_unix_time_from_system(), ctx.zone.id)

## Über welcher Zone es gerade regnet -- die Weltliste zeigt es an, sonst
## bliebe die Ein-Zonen-Regel für den Spieler unsichtbar.
func rain_zone() -> StringName:
	return Weather.rain_zone(Time.get_unix_time_from_system())

func rain_minutes_left() -> float:
	if ctx == null or ctx.zone == null:
		return 0.0
	return Weather.minutes_left(Time.get_unix_time_from_system(), ctx.zone.id)
