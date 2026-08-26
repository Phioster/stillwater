## Offline-Fortschritt. Bewusst winzig: die eigentliche Arbeit macht
## FishingSim.tick() mit einem großen Delta. Es gibt kein zweites
## Fangsystem, das auseinanderdriften könnte.
class_name OfflineSim
extends RefCounted

const MAX_OFFLINE_SECONDS: float = 12.0 * 3600.0

static func run(elapsed_seconds: float, sim: FishingSim, ctx: SimContext, rng: StillRNG, fish_by_id: Dictionary) -> Dictionary:
	var capped := clampf(elapsed_seconds, 0.0, MAX_OFFLINE_SECONDS)
	var events := sim.tick(capped, ctx, rng)

	var caught := 0
	var escaped := 0
	var xp := 0
	var coins := 0
	var discovered: Array[StringName] = []
	for e in events:
		match e["type"]:
			"caught":
				caught += 1
				xp += int(e["xp"])
				var c: CaughtFish = e["caught"]
				var fish: FishData = fish_by_id.get(c.fish_id)
				if fish != null:
					coins += Economy.sell_price(c, fish, ctx.rarity_of(fish), ctx.consumable_bonus)
				if bool(e["discovered"]):
					discovered.append(c.fish_id)
			"escaped":
				escaped += 1

	return {
		"elapsed": capped,
		"was_capped": elapsed_seconds > MAX_OFFLINE_SECONDS,
		"caught": caught,
		"escaped": escaped,
		"xp": xp,
		"discovered": discovered,
		"potential_coins": coins,
		"inventory_full": ctx.inventory.is_full(),
	}
