## Feder-Kette entlang der Wasserlinie: jeder Stuetzpunkt ist eine gedaempfte
## Feder zur Ruhelage, benachbarte Punkte ziehen zusaetzlich aneinander. Eine
## Stoerung an einem Punkt breitet sich dadurch von selbst auf die Nachbarn
## aus und klingt durch die Daempfung wieder ab. Reine Rechnung, kein Node --
## die Szene zeichnet die Werte und entscheidet, wann sie stoert.
class_name WaterSurface
extends RefCounted

const STIFFNESS := 40.0 ## zieht jeden Punkt zurueck zur Ruhelage (y = 0)
const SPREAD := 25.0 ## Kopplung zu den Nachbarn -- treibt die Ausbreitung an
const DAMPING := 8.0 ## bremst die Geschwindigkeit, sonst schwingt es dauerhaft
## Feste Schrittweite fuer die Integration. Ein einzelner grosser delta (z.B.
## nach einem Frame-Ruckler) wird in mehrere davon zerlegt -- sonst reisst
## die explizite Integration bei grossem Schritt aus (siehe step()).
const MAX_SUBSTEP := 1.0 / 60.0

## Sanfte Dauerbewegung, unabhaengig von der Feder-Kette: ein Sinus, der ueber
## die Wasserlinie laeuft. Eigene Funktion statt Teil der Feder-Kette, weil
## eine Feder ohne staendigen Antrieb abklingen wuerde -- "dauerhaft" heisst
## hier bewusst kein Federzustand, sondern eine reine Funktion von Ort/Zeit.
const AMBIENT_AMPLITUDE := 1.2
const AMBIENT_WAVELENGTH := 0.6 ## Anteil der Wasserbreite je Wellenlaenge
const AMBIENT_SPEED := 0.5 ## Wellen pro Sekunde -- bewusst langsam

var heights: PackedFloat64Array
var velocities: PackedFloat64Array
var point_count: int

func _init(points: int) -> void:
	point_count = maxi(points, 2)
	heights = PackedFloat64Array()
	heights.resize(point_count)
	velocities = PackedFloat64Array()
	velocities.resize(point_count)

## Zerlegt ein grosses delta in mehrere feste Teilschritte -- haelt die
## Integration stabil, egal wie gross delta wird.
func step(delta: float) -> void:
	var remaining := delta
	while remaining > 0.0:
		var dt := minf(remaining, MAX_SUBSTEP)
		_step_once(dt)
		remaining -= dt

func _step_once(dt: float) -> void:
	var new_velocities := PackedFloat64Array()
	new_velocities.resize(point_count)
	for i in point_count:
		# Offene Enden: fehlt ein Nachbar, zaehlt der Punkt sich selbst --
		# das entspricht einem freien Rand ohne Ausschlag von aussen.
		var left: float = heights[i - 1] if i > 0 else heights[i]
		var right: float = heights[i + 1] if i < point_count - 1 else heights[i]
		var accel := -STIFFNESS * heights[i] + SPREAD * (left + right - 2.0 * heights[i]) - DAMPING * velocities[i]
		new_velocities[i] = velocities[i] + accel * dt
	for i in point_count:
		heights[i] += new_velocities[i] * dt
	velocities = new_velocities

## Stoesst einen Stuetzpunkt an (Geschwindigkeit, nicht Position) -- die Feder
## traegt die Stoerung von selbst zu den Nachbarn weiter.
func disturb(index: int, amount: float) -> void:
	if index < 0 or index >= point_count:
		return
	velocities[index] += amount

## Wie disturb(), aber ueber eine Position 0..1 entlang der Wasserlinie statt
## eines Index -- so muss die Szene die Punktzahl nicht kennen.
func disturb_at(fraction: float, amount: float) -> void:
	var index := int(round(clampf(fraction, 0.0, 1.0) * float(point_count - 1)))
	disturb(index, amount)

## Groesste Auslenkung ueber alle Punkte -- fuer Stabilitaetspruefungen.
func max_abs_height() -> float:
	var m := 0.0
	for h in heights:
		m = maxf(m, absf(h))
	return m

static func ambient_offset(fraction: float, time: float) -> float:
	var phase := fraction / AMBIENT_WAVELENGTH - time * AMBIENT_SPEED
	return sin(phase * TAU) * AMBIENT_AMPLITUDE
