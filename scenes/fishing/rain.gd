## Der Regen über dem Wasser. Selbst gezeichnet statt als Partikelsystem:
## ein paar hundert kurze Striche kosten nichts, und der Fall ist eine
## Modulo-Rechnung ohne Zustand — es gibt also nichts, was auseinanderlaufen
## könnte, wenn das Spiel pausiert.
##
## Er endet an der Wasserkante. Vorher lief er bis zum unteren Bildrand
## durch, also quer über die Wasserfläche und über Steg und Figur davor —
## das las sich nicht als Regen auf einen See, sondern als Schleier vor der
## ganzen Szene. Die Kante kommt als fertige Punktfolge aus world.gd, dieselbe,
## die dort Wasserlinie und Wasserfläche malt: eine Quelle, nicht drei.
class_name Rain
extends Control

const DROPS: int = 90
const SPEED: float = 620.0
const LENGTH: float = 22.0
const SLANT: float = 0.18

var _time: float = 0.0
var _seeds: PackedFloat32Array = PackedFloat32Array()
## Die gewellte Wasserkante, in denselben Koordinaten wie dieser Control.
var _kante: PackedVector2Array = PackedVector2Array()
## Die RUHENDE Wasserlinie. Daran hängt die Fallstrecke, nicht an der
## gewellten Kante: die wandert jedes Bild ein paar Pixel, und mit ihr als
## Modulo würden alle Tropfen bei jedem Wellenschlag mitzucken.
var _ruhe: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 8817
	_seeds.resize(DROPS * 2)
	for i in _seeds.size():
		_seeds[i] = rng.randf()

## Wo das Wasser anfängt -- gewellt zum Zeichnen, ruhend für die Fallstrecke.
func setze_wasser(kante: PackedVector2Array, ruhe: float) -> void:
	_kante = kante
	_ruhe = ruhe

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()

## Die Höhe der Wasserkante an dieser Stelle. Zwischen den Stützpunkten
## interpoliert, sonst endete der Regen auf 28 Stufen statt auf einer Welle.
static func kante_bei(kante: PackedVector2Array, breite: float,
		x: float) -> float:
	if kante.size() < 2:
		return 0.0
	var t := clampf(x / maxf(breite, 1.0), 0.0, 1.0) * float(kante.size() - 1)
	var i := mini(int(t), kante.size() - 2)
	return lerpf(kante[i].y, kante[i + 1].y, t - float(i))

## Anfang und Ende eines Tropfenstrichs -- oder nichts, wenn er gerade ganz
## im Wasser steckt. Getrennt vom Zeichnen, damit die Tests nachrechnen
## können, dass kein Strich unter die Kante reicht.
##
## Er wird kürzer, während er eintaucht, statt an der Kante abgeschnitten zu
## werden: ein Strich, der auf voller Länge verschwindet, blinkt.
static func strich(x: float, versatz: float, zeit: float, ruhe: float,
		kante: float) -> PackedVector2Array:
	var h := maxf(ruhe, 1.0)
	# Jeder Tropfen hat sein eigenes Tempo, sonst fällt der Regen im Gleichschritt.
	var speed := SPEED * (0.7 + 0.6 * versatz)
	var y := fmod(versatz * h + zeit * speed, h + LENGTH) - LENGTH
	var ende := minf(y + LENGTH, kante)
	if ende <= y:
		return PackedVector2Array()
	# Die Neigung bleibt, auch verkürzt -- sonst stellte sich der Tropfen beim
	# Eintauchen auf.
	return PackedVector2Array([Vector2(x, y),
		Vector2(x - (ende - y) * SLANT, ende)])

func _draw() -> void:
	# Solange world.gd die Kante noch nicht gemeldet hat, wissen wir nicht, wo
	# das Wasser anfängt -- dann lieber kein Regen als Regen über allem.
	if _kante.size() < 2 or _ruhe <= 0.0:
		return
	var c := Palette.get_color(&"foam")
	c.a = 0.35
	for i in DROPS:
		var x := _seeds[i * 2] * size.x
		var s := strich(x, _seeds[i * 2 + 1], _time, _ruhe,
			kante_bei(_kante, size.x, x))
		if s.size() == 2:
			draw_line(s[0], s[1], c, 2.0)
