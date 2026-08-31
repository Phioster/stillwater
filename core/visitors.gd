## Die beiden Besucher: der Maus-Händler und die Möwe.
##
## Beide hängen an der Uhr, nicht an einem Countdown. Die Referenz zählt
## herunter (`mouse_shop_time -= delta`), was nur läuft, solange das Spiel
## offen ist — für ein Handy-Spiel falsch herum: wer einen Tag nicht spielt,
## verpasst nichts, aber wer zusieht, wartet.
##
## Aus der Zeit abgeleitet heißt: dieselbe Stunde gibt immer dasselbe Angebot,
## nichts läuft ab, während man weg ist, und es gibt keinen Stand, der
## driften könnte. Das ist derselbe Griff, mit dem die Referenz ihre Quests
## baut — nur wenden wir ihn auf alles an.
class_name Visitors
extends RefCounted

## Der Händler wechselt stündlich, die Möwe kommt alle vier Stunden.
const MOUSE_INTERVAL: float = 3600.0
const BIRD_INTERVAL: float = 14400.0
## Was ein neues Angebot kostet.
const REROLL_COST: int = 750

## In welcher Stunde bzw. welchem Vier-Stunden-Block wir gerade sind.
static func slot(now: float, interval: float) -> int:
	return int(floor(now / interval))

var mouse_slot: int = -1
## Was in diesem Angebot schon gekauft wurde.
var mouse_bought: Array[StringName] = []
## Jedes Neuwürfeln verändert den Samen, also auch das Angebot.
var mouse_rerolls: int = 0
var bird_slot: int = -1

# --- Maus-Haendler ------------------------------------------------------------

func refresh_mouse(now: float) -> bool:
	var s := slot(now, MOUSE_INTERVAL)
	if s == mouse_slot:
		return false
	mouse_slot = s
	mouse_bought = []
	mouse_rerolls = 0
	return true

## Das Angebot dieser Stunde. Aus dem Zeitfenster gesät, also für dieselbe
## Stunde immer dasselbe -- auch nach einem Neustart.
func mouse_offer(now: float, size: int) -> Array[StringName]:
	var s := slot(now, MOUSE_INTERVAL)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("maus:%d:%d" % [s, mouse_rerolls])
	var pool: Array[ConsumableData] = []
	for c in Database.consumables_in_order():
		pool.append(c)
	var out: Array[StringName] = []
	while out.size() < size and not pool.is_empty():
		var weights := PackedFloat64Array()
		for c in pool:
			# Billiges liegt oft aus, Teures selten -- ohne das waere ein
			# Legenden-Elixier jede Stunde zu haben.
			weights.append(1000.0 / maxf(float(c.cost), 1.0))
		var pick := _weighted(rng, weights)
		out.append(pool[pick].id)
		pool.remove_at(pick)
	return out

func mouse_buy(id: StringName) -> void:
	if not mouse_bought.has(id):
		mouse_bought.append(id)

func mouse_sold_out(id: StringName) -> bool:
	return mouse_bought.has(id)

func reroll() -> void:
	mouse_rerolls += 1
	mouse_bought = []

# --- Moewe --------------------------------------------------------------------

## Wartet ein Paket? Nach langer Abwesenheit liegt EINES da, nicht drei --
## sonst wäre Wegbleiben die beste Strategie.
func package_waiting(now: float) -> bool:
	return slot(now, BIRD_INTERVAL) > bird_slot

## Was im Paket liegt. Auch das aus dem Zeitfenster gesät.
func package_gift(now: float) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("moewe:%d" % slot(now, BIRD_INTERVAL))
	var pool := Database.consumables_in_order()
	if pool.is_empty():
		return &""
	var weights := PackedFloat64Array()
	for c in pool:
		weights.append(1000.0 / maxf(float(c.cost), 1.0))
	return pool[_weighted(rng, weights)].id

func collect_package(now: float) -> void:
	bird_slot = slot(now, BIRD_INTERVAL)

# --- Hilfen -------------------------------------------------------------------

func _weighted(rng: RandomNumberGenerator, weights: PackedFloat64Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 0
	var roll := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if roll < acc:
			return i
	return weights.size() - 1

func to_dict() -> Dictionary:
	var bought: Array = []
	for id in mouse_bought:
		bought.append(String(id))
	return {
		"mouse_slot": mouse_slot,
		"mouse_bought": bought,
		"mouse_rerolls": mouse_rerolls,
		"bird_slot": bird_slot,
	}

func load_dict(d: Dictionary) -> void:
	mouse_slot = int(d.get("mouse_slot", -1))
	mouse_rerolls = int(d.get("mouse_rerolls", 0))
	bird_slot = int(d.get("bird_slot", -1))
	mouse_bought = []
	for id in d.get("mouse_bought", []):
		mouse_bought.append(StringName(id))
