## Die Fanganzeige während eines Kampfes: Fischstärke, Leinenspannung und
## die antippbaren Orbs.
extends Control

const ORB_SCENE := preload("res://scenes/fishing/orb.tscn")
const POP_TEXT_SCENE := preload("res://scenes/effects/pop_text.tscn")
## Immer genau ein Punkt. Faellt er weg -- getroffen oder abgelaufen -- rueckt
## sofort der naechste nach. Bei zwei poppten zu Beginn beide auf einmal auf,
## danach kam ohnehin nur einer nach: der Anfang passte nicht zum Rest.
const ORB_TARGET: int = 1
## Nur eine Atempause, damit zwei Punkte nicht im selben Frame aufpoppen --
## kurz genug, dass sie beim schnellen Tippen nicht zu spueren ist.
const ORB_RESPAWN: float = 0.05
const ORB_LIFETIME: float = 2.2
const ORB_MARGIN: float = 80.0
## Die Orbs erscheinen rund um den Schwimmer statt ueber dem ganzen Bild.
const ORB_RADIUS: float = 190.0

## Mittelpunkt des Fangbereichs, von der Welt jeden Frame auf den Schwimmer
## gesetzt. Ohne Welt bleibt es die Mitte der Flaeche, damit CatchView
## eigenstaendig laedt.
var focus_point: Vector2 = Vector2.ZERO

@onready var _panel: PanelContainer = $Panel
@onready var _name: Label = $Panel/Box/FishName
@onready var _strength: ProgressBar = $Panel/Box/Strength
@onready var _line: ProgressBar = $Panel/Box/Line
## Fläche für die Orbs; deckungsgleich mit World.orb_area, aber lokal in
## dieser Szene, damit CatchView ohne Weltreferenz eigenständig lädt.
@onready var spawn_area: Control = $Orbs
## Schadenszahlen liegen bewusst NICHT bei den Orbs: _living_orbs() zaehlt die
## Kinder von spawn_area, eine Zahl darin galt als lebender Punkt und
## blockierte den Nachruecker fuer ihre ganze Lebenszeit.
@onready var _pops: Control = $Pops

var _spawn_timer: float = 0.0

func _ready() -> void:
	# Im Android-Export kommt die Szenenwurzel mit Standardankern an. Selbst
	# setzen, damit die Ansicht ueberall traegt und nicht davon abhaengt, wer
	# sie einhaengt.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	if not Game.bite.is_connected(_on_bite):
		Game.bite.connect(_on_bite)
	if not Game.caught.is_connected(_on_caught):
		Game.caught.connect(_on_caught)
	if not Game.escaped.is_connected(_on_escaped):
		Game.escaped.connect(_on_escaped)

func _process(delta: float) -> void:
	var fighting := Game.sim.state == FishingSim.State.FIGHT
	_panel.visible = fighting
	if not fighting:
		_clear_orbs()
		return
	_strength.max_value = Game.sim.hooked_max_health
	_strength.value = maxf(Game.sim.hooked_health, 0.0)
	# Das Zeitfenster haengt am Rang, nicht mehr an der Zone.
	_line.max_value = maxf(Game.sim.hooked_max_time, 0.001)
	_line.value = maxf(Game.sim.timer, 0.0)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _living_orbs() < ORB_TARGET:
		_spawn_timer = ORB_RESPAWN
		_spawn_orb()

## Der Rang steht im Namen: er sagt, was auf dem Spiel steht, und erklaert
## nebenbei, warum dieser Fisch schwerer ist als der davor.
func _on_bite(fish: FishData) -> void:
	var rank := FishRoll.RANK_NAMES[clampi(Game.sim.hooked_rank, 0, FishRoll.RANK_NAMES.size() - 1)]
	_name.text = "%s  ·  Rang %s" % [fish.display_name, rank]
	_spawn_timer = 0.25

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	_clear_orbs()

func _on_escaped(_f: FishData) -> void:
	_clear_orbs()

func _clear_orbs() -> void:
	for child in spawn_area.get_children():
		child.queue_free()
	for child in _pops.get_children():
		child.queue_free()

func _spawn_orb() -> void:
	var orb := ORB_SCENE.instantiate()
	spawn_area.add_child(orb)
	orb.setup(_orb_position(), ORB_LIFETIME)
	orb.tapped.connect(_on_orb_tapped.bind(orb))

## Ein Tipp muss eine Zahl hinterlassen. Ohne sie ist nicht zu sehen, dass
## Tippen ueberhaupt etwas bewirkt -- und damit auch nicht, wozu Orb-Kraft gut ist.
func _on_orb_tapped(orb: Node) -> void:
	var damage := int(round(Game.ctx.orb_power))
	var at: Vector2 = (orb as Control).position if orb is Control else Vector2.ZERO
	var pop := POP_TEXT_SCENE.instantiate()
	_pops.add_child(pop)
	pop.setup("-%d" % damage, at, Palette.get_color(&"accent"))
	Game.tap()

## queue_free() wirkt erst am Frameende -- ein sterbender Punkt zaehlt sonst
## noch mit und blockiert den Nachruecker.
func _living_orbs() -> int:
	var n := 0
	for child in spawn_area.get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n

## Ein Punkt im Kreis um den Schwimmer, aber immer so weit vom Rand entfernt,
## dass der Orb vollstaendig im Bild bleibt -- sonst waere er am Ufer halb ab.
func _orb_position() -> Vector2:
	var area := spawn_area.size
	var center := focus_point if focus_point != Vector2.ZERO else area * 0.5
	var angle := randf() * TAU
	var distance := sqrt(randf()) * ORB_RADIUS
	var pos := center + Vector2(cos(angle), sin(angle)) * distance
	return Vector2(
		clampf(pos.x, ORB_MARGIN, maxf(area.x - ORB_MARGIN, ORB_MARGIN + 1.0)),
		clampf(pos.y, ORB_MARGIN, maxf(area.y - ORB_MARGIN, ORB_MARGIN + 1.0))
	)

