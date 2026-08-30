## XP-Vergabe und Levelkurve. Bewusst flach: ein Idle-Spiel soll regelmäßig
## kleine Fortschritte zeigen, nicht wenige große.
class_name Progression
extends RefCounted

const XP_BASE: float = 80.0
const XP_EXPONENT: float = 1.55

static func xp_needed(level: int) -> int:
	return int(round(XP_BASE * pow(float(maxi(level, 1)), XP_EXPONENT)))

static func xp_for_catch(fish: FishData, rarity: RarityData, rank: int) -> int:
	var q := clampi(rank, 0, FishRoll.RANK_NAMES.size() - 1)
	return int(floor(float(fish.xp) * rarity.xp_mult * (0.75 + 0.5 * float(q) / 6.0)))

## Verrechnet gewonnene XP und gibt den neuen Stand zurück.
static func apply_xp(level: int, xp: int, gained: int) -> Dictionary:
	var l := maxi(level, 1)
	var x := xp + gained
	var gained_levels := 0
	while x >= xp_needed(l):
		x -= xp_needed(l)
		l += 1
		gained_levels += 1
	return {"level": l, "xp": x, "levels_gained": gained_levels}
