## Der Simulationskern. Enthält keine Nodes und keinen Szenenbezug:
## dieselbe Klasse treibt das laufende Spiel und den Offline-Fortschritt.
class_name FishingSim
extends RefCounted

enum State { IDLE, CASTING, WAITING, FIGHT, INVENTORY_FULL }

const CAST_TIME: float = 1.0
const ESCAPE_COOLDOWN: float = 2.0
## Schutz gegen Endlosschleifen bei einem sehr großen Delta.
const MAX_SEGMENTS: int = 500000

var state: int = State.IDLE
var timer: float = 0.0
var hooked: FishData = null
## Der Kampf ist ein Schadensrennen: hooked_health muss auf null, bevor
## timer ablaeuft. rod_power traegt ununterbrochen ab (das ist die
## Idle-Haelfte), jeder Tipp schlaegt orb_power heraus.
var hooked_health: float = 0.0
var hooked_max_health: float = 0.0
var hooked_dev: float = 0.0
var hooked_rank: int = 0
var hooked_shiny: bool = false

## Bewusst segmentweise geschlossen gerechnet statt in festen Schritten:
## dadurch liefert ein einziger tick(43200.0) dasselbe Ergebnis wie
## 432000 mal tick(0.1) — genau das braucht der Offline-Fortschritt.
func tick(delta: float, ctx: SimContext, rng: StillRNG) -> Array:
	var events: Array = []
	var remaining := delta
	var segments := 0
	while remaining > 0.0:
		segments += 1
		if segments > MAX_SEGMENTS:
			break
		match state:
			State.IDLE:
				_start_cast(ctx, events)
			State.INVENTORY_FULL:
				if ctx.inventory.is_full():
					remaining = 0.0
				else:
					state = State.IDLE
			State.CASTING, State.WAITING:
				if remaining < timer:
					timer -= remaining
					remaining = 0.0
				else:
					remaining -= timer
					timer = 0.0
					if state == State.CASTING:
						_begin_wait(ctx, rng)
					else:
						_on_bite(ctx, rng, events)
			State.FIGHT:
				var time_to_land := INF
				if ctx.rod_power > 0.0:
					time_to_land = hooked_health / ctx.rod_power
				var segment := minf(time_to_land, timer)
				if remaining < segment:
					hooked_health -= ctx.rod_power * remaining
					timer -= remaining
					remaining = 0.0
				else:
					remaining -= segment
					if time_to_land <= timer:
						_land(ctx, events)
					else:
						_escape(events)
	return events

## Ein Tipp auf einen Orb. Wirkt nur während eines Kampfes.
func tap(ctx: SimContext) -> Array:
	var events: Array = []
	if state != State.FIGHT:
		return events
	hooked_health -= ctx.orb_power
	if hooked_health <= 0.0:
		_land(ctx, events)
	return events

func _start_cast(ctx: SimContext, events: Array) -> void:
	if ctx.inventory.is_full():
		state = State.INVENTORY_FULL
		events.append({"type": "inventory_full"})
		return
	state = State.CASTING
	timer = CAST_TIME

func _begin_wait(ctx: SimContext, rng: StillRNG) -> void:
	state = State.WAITING
	timer = rng.randf_range(ctx.zone.bite_time_min, ctx.zone.bite_time_max)

func _on_bite(ctx: SimContext, rng: StillRNG, events: Array) -> void:
	var fish := select_fish(ctx, rng)
	if fish == null:
		state = State.IDLE
		return
	ctx.consume_bait()
	var rarity := ctx.rarity_of(fish)
	hooked = fish
	# Der Koeder verschiebt die Groessenverteilung, nicht die Artenauswahl.
	hooked_dev = FishRoll.roll_deviation(ctx.bait_rank_shift(), rng)
	hooked_rank = FishRoll.rank_for_deviation(hooked_dev)
	hooked_shiny = FishRoll.roll_shiny(ctx.journal.fish_level(fish.id), ctx.shiny_bonus, rng)
	hooked_max_health = FishRoll.health_for(fish, hooked_rank)
	hooked_health = hooked_max_health
	state = State.FIGHT
	timer = FishRoll.time_for(fish, hooked_rank, ctx.zone.fight_window)
	events.append({"type": "bite", "fish": fish, "health": hooked_health})

func _land(ctx: SimContext, events: Array) -> void:
	var fish := hooked
	var caught := CaughtFish.make(fish.id, hooked_dev, hooked_shiny)
	var rarity := ctx.rarity_of(fish)
	var stored := ctx.inventory.add(caught)
	# Vor dem Eintragen lesen: danach IST die Abweichung der neue Bestwert.
	var previous_best := -INF
	var had_rank := false
	if ctx.journal.is_discovered(fish.id):
		previous_best = float(ctx.journal.entry(fish.id)["best_dev"])
		had_rank = ctx.journal.has_rank(fish.id, hooked_rank)
	var discovered := ctx.journal.record(caught, fish.is_secret)
	var is_record := discovered or hooked_dev > previous_best
	var new_rank := not had_rank
	var xp := Progression.xp_for_catch(fish, rarity, hooked_rank)
	var after := Progression.apply_xp(ctx.player_level, ctx.player_xp, xp)
	ctx.player_level = int(after["level"])
	ctx.player_xp = int(after["xp"])
	events.append({
		"type": "caught",
		"fish": fish,
		"caught": caught,
		"xp": xp,
		"discovered": discovered,
		"record": is_record,
		"new_rank": new_rank,
		"stored": stored,
	})
	if int(after["levels_gained"]) > 0:
		events.append({"type": "level_up", "level": ctx.player_level})
	_clear_hooked()
	if ctx.inventory.is_full():
		state = State.INVENTORY_FULL
		events.append({"type": "inventory_full"})
	else:
		state = State.CASTING
		timer = CAST_TIME

func _escape(events: Array) -> void:
	events.append({"type": "escaped", "fish": hooked})
	_clear_hooked()
	state = State.CASTING
	timer = ESCAPE_COOLDOWN

## Ein beendeter Kampf darf keine Reste hinterlassen -- sonst zeigt die
## Kampfansicht (Task 15) oder ein Offline-Vergleich Werte aus dem letzten,
## längst abgeschlossenen Kampf statt keinen Kampf.
func _clear_hooked() -> void:
	hooked = null
	hooked_health = 0.0
	hooked_max_health = 0.0
	hooked_dev = 0.0
	hooked_rank = 0
	hooked_shiny = false

## Wählt den Fisch für einen Biss.
## Reihenfolge: erst der Secret-Durchgang, dann Rarität, dann Art.
static func select_fish(ctx: SimContext, rng: StillRNG) -> FishData:
	var secret := _roll_secret(ctx, rng)
	if secret != null:
		return secret
	var rarity_id := _roll_rarity(ctx, rng)
	if rarity_id == &"":
		return null
	return _roll_fish_of_rarity(ctx, rarity_id, rng)

static func _roll_secret(ctx: SimContext, rng: StillRNG) -> FishData:
	var state := ctx.condition_state()
	for f in ctx.zone.fish:
		if not f.is_secret:
			continue
		if not _conditions_met(f, state):
			continue
		if rng.randf() < f.secret_chance:
			return f
	return null

static func _conditions_met(fish: FishData, state: Dictionary) -> bool:
	for c in fish.conditions:
		if c == null:
			continue
		if not c.is_met(state):
			return false
	return true

static func _roll_rarity(ctx: SimContext, rng: StillRNG) -> StringName:
	# Nur Raritäten zulassen, die einen ziehbaren Fisch haben — sonst
	# könnte eine leere oder komplett abgeschaltete Stufe gezogen werden.
	var available := {}
	for f in ctx.zone.fish:
		if not f.is_secret and f.spawn_weight > 0.0:
			available[f.rarity_id] = true
	var ids: Array = ctx.zone.rarity_weights.keys()
	var weights := PackedFloat64Array()
	for id in ids:
		var w := float(ctx.zone.rarity_weights[id]) if available.has(id) else 0.0
		# Seltene Stufen laufen mit der Spielerstufe an: am Anfang beisst fast
		# nur Gewoehnliches, spaeter wird es bunter.
		var rarity: RarityData = ctx.rarities.get(id)
		if rarity != null:
			w *= rarity.availability(ctx.player_level)
		if ctx.bait != null:
			w *= float(ctx.bait.rarity_weight_bonus.get(id, 1.0))
		weights.append(w)
	var i := rng.weighted_pick(weights)
	return ids[i] if i >= 0 else &""

static func _roll_fish_of_rarity(ctx: SimContext, rarity_id: StringName, rng: StillRNG) -> FishData:
	var pool: Array[FishData] = []
	var weights := PackedFloat64Array()
	for f in ctx.zone.fish:
		if f.is_secret or f.rarity_id != rarity_id:
			continue
		var w := f.spawn_weight
		if ctx.bait != null and ctx.bait.id in f.preferred_baits:
			w *= f.preferred_bait_mult
		pool.append(f)
		weights.append(w)
	if pool.is_empty():
		return null
	var i := rng.weighted_pick(weights)
	return pool[i] if i >= 0 else null
