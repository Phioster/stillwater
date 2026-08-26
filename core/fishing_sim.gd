## Der Simulationskern. Enthält keine Nodes und keinen Szenenbezug:
## dieselbe Klasse treibt das laufende Spiel und den Offline-Fortschritt.
class_name FishingSim
extends RefCounted

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
	# Nur Raritäten zulassen, für die es auch einen (nicht-geheimen) Fisch
	# gibt — sonst könnte eine leere Raritätsstufe gezogen werden.
	var available := {}
	for f in ctx.zone.fish:
		if not f.is_secret:
			available[f.rarity_id] = true
	var ids: Array = ctx.zone.rarity_weights.keys()
	var weights := PackedFloat64Array()
	for id in ids:
		var w := float(ctx.zone.rarity_weights[id]) if available.has(id) else 0.0
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
