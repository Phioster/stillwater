## Ein einmaliger Partikelstoss aus einfachen Punkten -- keine Bilddatei,
## nur eine Farbe aus core/palette.gd. CPUParticles2D ohne Textur zeichnet
## selbst kleine Quadrate, das genuegt fuer Platschen und Funkeln.
extends CPUParticles2D

const LIFETIME: float = 0.5

var _age: float = 0.0

func setup_splash(pos: Vector2) -> void:
	position = pos
	amount = 10
	spread = 50.0
	initial_velocity_min = 60.0
	initial_velocity_max = 140.0
	gravity = Vector2(0.0, 260.0)
	scale_amount_min = 0.6
	scale_amount_max = 1.1
	color = Palette.get_color(&"foam")
	_start()

## Deutlich sichtbar und rundum verteilt -- ein Shiny-Fang ist mit 1/800
## der seltenste Moment des Spiels und soll danach aussehen.
func setup_sparkle(pos: Vector2) -> void:
	position = pos
	amount = 18
	spread = 180.0
	initial_velocity_min = 40.0
	initial_velocity_max = 110.0
	gravity = Vector2.ZERO
	scale_amount_min = 0.5
	scale_amount_max = 1.0
	color = Palette.get_color(&"accent")
	_start()

func _start() -> void:
	direction = Vector2.UP
	lifetime = LIFETIME
	one_shot = true
	explosiveness = 1.0
	emitting = true

## Eigene Alterung statt auf das "finished"-Signal von CPUParticles2D zu
## warten -- so laesst sich das Ende in Tests direkt herbeifuehren, ohne
## Partikel-Timing nachzubilden (gleiches Muster wie orb.gd).
func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
