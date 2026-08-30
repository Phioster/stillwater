## Die Fanganzeige während eines Kampfes: Fischstärke, Leinenspannung und
## die antippbaren Orbs.
extends Control

const ORB_SCENE := preload("res://scenes/fishing/orb.tscn")
const POP_TEXT_SCENE := preload("res://scenes/effects/pop_text.tscn")
## Immer genau ein Punkt. Faellt er weg -- getroffen oder abgelaufen -- rueckt
## sofort der naechste nach. Bei zwei poppten zu Beginn beide auf einmal auf,
## danach kam ohnehin nur einer nach: der Anfang passte nicht zum Rest.
const ORB_TARGET: int = 1
## Kein Nachrueck-Halt mehr: die Referenz ruft beim Treffer sofort den
## naechsten Punkt auf. Der Wert bleibt als Regler stehen, steht aber auf 0.
const ORB_RESPAWN: float = 0.0
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
@onready var _health_slot: Control = $Panel/Box/Health
@onready var _line_slot: Control = $Panel/Box/Line
var _health: GhostBar
var _line: GhostBar
## Fläche für die Orbs; deckungsgleich mit World.orb_area, aber lokal in
## dieser Szene, damit CatchView ohne Weltreferenz eigenständig lädt.
@onready var spawn_area: Control = $Orbs
## Schadenszahlen liegen bewusst NICHT bei den Orbs: _living_orbs() zaehlt die
## Kinder von spawn_area, eine Zahl darin galt als lebender Punkt und
## blockierte den Nachruecker fuer ihre ganze Lebenszeit.
@onready var _pops: Control = $Pops

var _spawn_timer: float = 0.0
## Stand des Rutenzaehlers beim letzten Bild. Die Simulation schickt keine
## Ereignisse pro Schlag -- ein Offline-Nachlauf ueber Stunden haette sonst
## zehntausende erzeugt -- also wird der Zaehler abgelesen.
var _seen_rod_hits: int = 0

func _ready() -> void:
	# Im Android-Export kommt die Szenenwurzel mit Standardankern an. Selbst
	# setzen, damit die Ansicht ueberall traegt und nicht davon abhaengt, wer
	# sie einhaengt.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health = _fill(_health_slot, Palette.get_color(&"cloth_red"), Palette.get_color(&"accent"))
	_line = _fill(_line_slot, Palette.get_color(&"foam"), Palette.get_color(&"water_mid"))
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
	_health.set_max(Game.sim.hooked_max_health)
	_health.set_value(maxf(Game.sim.hooked_health, 0.0))
	# Das Zeitfenster haengt am Rang, nicht mehr an der Zone.
	_line.set_max(maxf(Game.sim.hooked_max_time, 0.001))
	_line.set_value(maxf(Game.sim.timer, 0.0))
	# Jeder Rutenschlag hinterlaesst seine Zahl. Ohne sie arbeitet die Rute
	# unsichtbar, und niemand sieht, wofuer Rutenkraft gut ist.
	var hits := Game.sim.rod_hits
	if hits > _seen_rod_hits:
		# Nach einem Sprung (Offline-Nachlauf) nicht hundert Zahlen werfen.
		if hits - _seen_rod_hits <= 3:
			for i in hits - _seen_rod_hits:
				_pop_damage(int(round(Game.ctx.rod_power)), Palette.get_color(&"foam"))
			Audio.play(&"rod", 0.15)
		_seen_rod_hits = hits
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _living_orbs() < ORB_TARGET:
		_spawn_timer = ORB_RESPAWN
		_spawn_orb()

## Der Rang steht im Namen: er sagt, was auf dem Spiel steht, und erklaert
## nebenbei, warum dieser Fisch schwerer ist als der davor.
## Die Leiste haengt in einem leeren Platzhalter aus der Szene: so bleibt das
## Aussehen im Code, wo auch das Verhalten steht.
func _fill(slot: Control, front: Color, ghost: Color) -> GhostBar:
	var bar := GhostBar.new()
	slot.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.set_colors(front, ghost)
	return bar

func _on_bite(fish: FishData) -> void:
	_seen_rod_hits = 0
	var rank := FishRoll.RANK_NAMES[clampi(Game.sim.hooked_rank, 0, FishRoll.RANK_NAMES.size() - 1)]
	# Ansagen, ob die Rute allein reicht. Die Referenz spielt dafuer einen
	# eigenen Klang; bis wir Ton haben, steht es in der Zeile.
	Audio.play(&"bite")
	var call := "  ·  ✋ antippen!" if Game.sim.needs_hands else ""
	_name.text = "%s  ·  Rang %s%s" % [fish.display_name, rank, call]
	_name.modulate = Palette.get_color(&"accent") if Game.sim.needs_hands else Color.WHITE
	# Beim Anbiss darf nichts hinterherlaufen -- sonst zeigt die Leiste kurz
	# den Rest des vorigen Kampfes.
	_health.set_max(Game.sim.hooked_max_health)
	_health.reset_to(Game.sim.hooked_max_health)
	_line.set_max(maxf(Game.sim.hooked_max_time, 0.001))
	_line.reset_to(Game.sim.hooked_max_time)
	_spawn_timer = 0.25

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	_clear_orbs()

func _on_escaped(_f: FishData) -> void:
	Audio.play(&"escape")
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
func _on_orb_tapped(_orb: Node) -> void:
	Audio.play(&"orb", 0.0)
	_pop_damage(int(round(Game.ctx.orb_power)), Palette.get_color(&"accent"))
	Game.tap()

## Alle Schadenszahlen erscheinen an DERSELBEN Stelle neben der Leiste, nicht
## dort, wo gerade getippt wurde: sonst springt das Auge dem Finger hinterher,
## statt die Leiste im Blick zu behalten.
func _pop_damage(amount: int, color: Color) -> void:
	var pop := POP_TEXT_SCENE.instantiate()
	_pops.add_child(pop)
	var anchor := _panel.position + Vector2(_panel.size.x + 24.0, _panel.size.y * 0.5)
	anchor.y += randf_range(-14.0, 14.0)
	pop.setup("-%d" % amount, anchor, color)

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

