## Die beiden Besucher: der Waschbär-Händler und der Rabe.
##
## Beide hängen an der Uhr, nicht an einem Countdown. Die Referenz zählt
## herunter (`trader_time -= delta`), was nur läuft, solange das Spiel
## offen ist — für ein Handy-Spiel falsch herum: wer einen Tag nicht spielt,
## verpasst nichts, aber wer zusieht, wartet.
##
## Aus der Zeit abgeleitet heißt: dieselbe Stunde gibt immer dasselbe Angebot,
## nichts läuft ab, während man weg ist, und es gibt keinen Stand, der
## driften könnte. Das ist derselbe Griff, mit dem die Referenz ihre Quests
## baut — nur wenden wir ihn auf alles an.
class_name Visitors
extends RefCounted

## Der Händler wechselt stündlich, der Rabe kommt alle vier Stunden.
const TRADER_INTERVAL: float = 3600.0
const RAVEN_INTERVAL: float = 14400.0
## Was ein neues Angebot kostet.
const REROLL_COST: int = 750

## In welcher Stunde bzw. welchem Vier-Stunden-Block wir gerade sind.
static func slot(now: float, interval: float) -> int:
	return int(floor(now / interval))

var trader_slot: int = -1
## Was in diesem Angebot schon gekauft wurde.
var trader_bought: Array[StringName] = []
## Jedes Neuwürfeln verändert den Samen, also auch das Angebot.
var trader_rerolls: int = 0
## Ist er für diesen Besuch schon weitergezogen? Er geht, sobald man bei ihm
## gekauft und den Laden wieder geschlossen hat -- so wie in der Referenz.
## Ohne das stünde er die ganze Stunde da, obwohl nichts mehr zu holen ist.
var trader_gone: bool = false
var raven_slot: int = -1

# --- Waschbaer-Haendler ------------------------------------------------------------

func refresh_trader(now: float) -> bool:
	var s := slot(now, TRADER_INTERVAL)
	if s == trader_slot:
		return false
	trader_slot = s
	trader_bought = []
	trader_rerolls = 0
	trader_gone = false
	return true

## Das Angebot dieser Stunde. Aus dem Zeitfenster gesät, also für dieselbe
## Stunde immer dasselbe -- auch nach einem Neustart.
func trader_offer(now: float, size: int) -> Array[StringName]:
	var s := slot(now, TRADER_INTERVAL)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("haendler:%d:%d" % [s, trader_rerolls])
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

func trader_buy(id: StringName) -> void:
	if not trader_bought.has(id):
		trader_bought.append(id)

func sold_out(id: StringName) -> bool:
	return trader_bought.has(id)

## Er zieht weiter -- aber nur, wenn er auch etwas verkauft hat. Wer nur
## geschaut hat, soll nicht mit einem geschlossenen Menü den Besuch verlieren.
## Gibt zurück, ob sich dadurch etwas geändert hat.
func trader_leave() -> bool:
	if trader_gone or trader_bought.is_empty():
		return false
	trader_gone = true
	return true

func reroll() -> void:
	trader_rerolls += 1
	trader_bought = []

# --- Rabe --------------------------------------------------------------------

## Wartet ein Paket? Nach langer Abwesenheit liegt EINES da, nicht drei --
## sonst wäre Wegbleiben die beste Strategie.
func raven_waiting(now: float) -> bool:
	return slot(now, RAVEN_INTERVAL) > raven_slot

## Was im Paket liegt. Auch das aus dem Zeitfenster gesät.
func raven_gift(now: float) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rabe:%d" % slot(now, RAVEN_INTERVAL))
	var pool := Database.consumables_in_order()
	if pool.is_empty():
		return &""
	var weights := PackedFloat64Array()
	for c in pool:
		weights.append(1000.0 / maxf(float(c.cost), 1.0))
	return pool[_weighted(rng, weights)].id

func collect_raven(now: float) -> void:
	raven_slot = slot(now, RAVEN_INTERVAL)

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
	for id in trader_bought:
		bought.append(String(id))
	return {
		"trader_slot": trader_slot,
		"trader_bought": bought,
		"trader_rerolls": trader_rerolls,
		"trader_gone": trader_gone,
		"raven_slot": raven_slot,
	}

func load_dict(d: Dictionary) -> void:
	trader_slot = int(d.get("trader_slot", -1))
	trader_rerolls = int(d.get("trader_rerolls", 0))
	trader_gone = bool(d.get("trader_gone", false))
	raven_slot = int(d.get("raven_slot", -1))
	trader_bought = []
	for id in d.get("trader_bought", []):
		trader_bought.append(StringName(id))
