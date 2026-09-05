## Die Spielwelt links im Querformat. Zeigt Hintergrund, Angler und Bobber
## und stellt die Fläche bereit, über der die Orbs erscheinen dürfen.
extends Control

## Meldet, dass jemand den Haendler angetippt hat -- main.gd oeffnet dann
## seinen Reiter. Die Welt kennt das Menue nicht und soll es nicht kennen.
signal visitor_tapped

@onready var orb_area: Control = $CatchView.spawn_area
@onready var _bobber: Sprite2D = $Bobber
@onready var _bait: Sprite2D = $Bait
@onready var _background: TextureRect = $Background
@onready var _dock: Sprite2D = $Dock
@onready var _angler: Node2D = $Angler
@onready var _line: Line2D = $Line
@onready var _water_line: Line2D = $WaterLine
@onready var _water_body: Polygon2D = $WaterBody
@onready var _water_view: WaterView = $Water
@onready var _raven: TextureButton = $Visitors/Raven
@onready var _trader: TextureButton = $Visitors/Trader
var _rain: Rain = null

## Der Hintergrund ist 320x180: Himmel bis Zeile 77, Ufer 78-83, Wasser ab 84.
## Alles andere richtet sich danach, damit es bei jedem Seitenverhaeltnis passt.
const WATERLINE := 84.0 / 180.0
## Steg und Figur laufen wieder im selben Massstab: der neue Steg (262x98,
## tools/steg_bauen.py) hat Pixel in Figurengroesse. Vorher war er 512x192 bei
## 1.08 -- gleich gross auf dem Schirm, aber mit halb so feinen Pixeln, und
## nebeneinander sah das aus wie zwei Zeichnungen aus verschiedenen Spielen.
const DOCK_SCALE := 2.16
const ANGLER_SCALE := 2.16
const DOCK_W := 262.0
## Der Steg ist zweimal uebereinander gezeichnet, das hintere Bild um zwei
## Zeilen hoeher. Die vordere Deckoberkante -- die, auf der sie sitzt --
## liegt deshalb nicht in Zeile 0.
const DECK_IM_BILD := 2.0
## Schwimmer und Koeder laufen im Massstab von Steg und Figur. Vorher stand
## der Schwimmer auf 1.0 -- gleich gross auf dem Schirm, aber mit doppelt so
## feinen Pixeln wie alles um ihn herum.
const BOBBER_SCALE := 2.16
## Wie hoch die vordere Deckoberkante ueber der Wasserlinie liegt, in
## Stegpixeln. Massgeblich sind ihre Beine: vom Rocksaum (Zeile 84) bis zur
## Stiefelspitze (122) sind es 38 Figurpixel, und Figur und Steg haben
## denselben Massstab. Bei 40 haengen die Stiefel knapp ueber dem Wasser
## statt darin.
const DECK_OVER_WATER := 40.0
## Wo die Anglerin sitzt, vom linken Stegende in Stegpixeln. Ihr Sprite haengt
## an der oberen linken Ecke; bei 187 liegt ihre Sitzflaeche (Figurspalten
## 44 bis 68) genau auf den letzten Planken, und die Beine haengen ueber der
## Kante. Steg und Figur haben denselben Massstab, ein Pixel ist ein Pixel.
const ANGLER_ON_DECK := 187.0
## Wie weit hinter dem Stegende der Schwimmer liegt, in Stegpixeln. Halbiert
## mit dem Massstab: 120 alte Stegpixel sind 60 neue.
const BOBBER_OFF_DOCK := 60.0
## Die Angler-Ebenen haben centered = false: ihr Ursprung ist die obere linke
## Ecke, nicht die Mitte. Alle Offsets zaehlen deshalb von dort.
## Sie SITZT auf dem Steg, sie steht nicht darauf: massgeblich ist der Rocksaum
## bei Zeile 84, nicht die Stiefelsohle bei 125. Sonst stehen die Stiefel auf
## dem Deck und die Beine koennen nicht baumeln.
const CHAR_SEAT := 84.0

## Stuetzpunkte der Wasserlinie -- sparsam gewaehlt, siehe Bericht fuer die
## gemessenen Kosten pro Frame.
const WATER_POINTS := 28
## Wellen-Einheiten (core/water_surface.gd) -> Bildschirmpixel. Bewusst klein:
## die Grundbewegung soll man suchen muessen, nicht ertragen (GAME_DESIGN.md,
## "Auffaellig nur, was selten ist").
const WAVE_SCALE := 7.0
## Die Welle schwingt komplett UNTERHALB der Uferlinie. Sonst lief sie ins Gras
## und die kerzengerade Kante des Hintergrundbilds blieb daneben sichtbar.
const WAVE_BIAS := 9.5
## Wie weit die Uferfarbe ins Gras hinaufreicht. Die Farbkante des skalierten
## Hintergrundbilds liegt nicht exakt auf 84/180 -- ohne Reserve blitzte dort
## ein zwei Pixel duenner Streifen Wasser durch (am Screenshot ausgemessen).
const SHORE_OVERLAP := 10.0
## Kleiner, laufender Antrieb durchs Zappeln im Kampf -- daraus entsteht die
## Stoerung, die von seiner Position nach aussen laeuft. Beim Warten treibt er
## nichts an: dort traegt IHN das Wasser, nicht umgekehrt.
const BOBBER_DRIVE := 0.05
## Wie weit der Fisch im Kampf am Schwimmer zieht. Das ist eine Kraft von
## aussen und deshalb ein eigener Ausschlag -- die Duenung allein reicht
## dafuer nicht.
const FIGHT_TUG := 10.0
const BITE_KICK := 12.0
const CATCH_KICK := 20.0
## Der Spritzer beim Aufsetzen. Kleiner als ein Biss -- der Wurf soll das
## Wasser anstossen, nicht aufschrecken.
const SPLASH_KICK := 7.0
## Der Scheitel der Wurfkurve liegt RECHTS des Ziels und ueber der
## Rutenspitze: der Koeder fliegt erst hinaus und faellt dann steil ins
## Wasser. Ein Scheitel auf halber Strecke ergaebe eine Diagonale.
const CAST_ARC := 60.0
const CAST_OVERSHOOT := 90.0
## Der Koeder faellt, er schwebt nicht: die Kurve wird beschleunigt abgefahren,
## also oben langsam und unten schnell. Die Wurfdauer selbst bleibt, die
## gehoert der Simulation.
const CAST_FALL := 1.45
## Wie weit die Schnur durchhaengt, als Anteil ihrer eigenen Laenge. Ein
## fester Wert waere im Flug ein Klumpen und in Ruhe kaum zu sehen; so haengt
## sie ueberall gleich, und der Bogen ist schon im Flug da.
const LINE_POINTS := 12
const LINE_SAG := 0.28
## Wohin der Bauch zeigt. In der Luft folgt die Schnur dem Wurf: der Bogen
## steht nach aussen und faellt nur wenig. Sitzt der Schwimmer, faellt sie in
## den senkrechten Durchhang -- ueber LINE_SETTLE Sekunden, sonst springt sie.
const LINE_BELLY_AIR := Vector2(0.86, 0.51)
const LINE_BELLY_WATER := Vector2(0.0, 1.0)
const LINE_SETTLE := 0.14
## Wie weit der Koeder unter dem Schwimmer haengt, in Figurpixeln. Er sitzt am
## Vorfach: beim Ausholen baumelt er an der Rutenspitze, im Flug zieht er
## hinterher, und mit dem Aufsetzen ist er unter Wasser.
const BAIT_HANG := 12.0
## Fallback, solange nicht jeder Koeder ein eigenes Bild hat.
const BAIT_FALLBACK := &"pond_grub"
const POP_TEXT_SCENE := preload("res://scenes/effects/pop_text.tscn")

var _bob_time: float = 0.0
var _bobber_home: Vector2
## Wo der Schwimmer wirklich sitzt. Nicht dasselbe wie seine Sprite-Position:
## schwimmend ist er halb abgeschnitten und sein Sprite sitzt hoeher.
var _bobber_mitte: Vector2
## Wie lange der Schwimmer schon sitzt -- daran kippt der Bauch der Schnur.
var _line_settle: float = 0.0
var _water := WaterSurface.new(WATER_POINTS)
## Laeuft immer weiter, anders als _bob_time (das bei jedem Biss auf 0
## zurueckspringt) -- die Grundbewegung des Wassers darf davon nicht mitreissen.
var _water_time: float = 0.0
## Verhindert, dass jedes state_changed Textur und Farben neu setzt.
var _applied_zone: StringName = &""
## Welches Koederbild gerade haengt -- damit der Wechsel nicht in jedem Bild
## neu geladen wird.
var _bait_id: StringName = &""

func _ready() -> void:
	_bobber.texture = TextureLoader.load_texture("res://assets/art/bobber.png")
	_dock.texture = TextureLoader.load_texture("res://assets/art/dock.png")
	_dock.scale = Vector2(DOCK_SCALE, DOCK_SCALE)
	_angler.scale = Vector2(ANGLER_SCALE, ANGLER_SCALE)
	_bobber.scale = Vector2(BOBBER_SCALE, BOBBER_SCALE)
	_bait.scale = Vector2(BOBBER_SCALE, BOBBER_SCALE)
	_setup_visitors()
	_rain = Rain.new()
	add_child(_rain)
	_rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain.visible = false
	_water_line.width = 4.0
	_apply_zone()
	_layout()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	if not Game.state_changed.is_connected(_apply_zone):
		Game.state_changed.connect(_apply_zone)
	if not Game.bite.is_connected(_on_bite):
		Game.bite.connect(_on_bite)
	if not Game.caught.is_connected(_on_caught):
		Game.caught.connect(_on_caught)


## Steg ans Ufer, Figur darauf, Schwimmer aufs Wasser -- aus der Weltgroesse
## gerechnet statt fest eingetragen.
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var water_y := size.y * WATERLINE
	# Der Steg liegt mit seiner Deckoberkante ueber der Wasserlinie, die
	# Pfosten ragen ins Wasser. Er wird VOR dem Wasser gezeichnet (world.tscn),
	# damit die Wasserflaeche die Pfosten abschneidet statt sie zu ueberdecken.
	# Buendig mit dem linken Rand: ein Steg, der frei im Wasser beginnt, sieht
	# abgeschnitten aus statt am Ufer angebaut.
	_dock.position = Vector2(0.0,
		water_y - (DECK_OVER_WATER + DECK_IM_BILD) * DOCK_SCALE)
	var deck_y := _dock.position.y
	# Sitzflaeche auf die vordere Deckoberkante.
	_angler.position = Vector2(_dock.position.x + ANGLER_ON_DECK * DOCK_SCALE,
		deck_y + (DECK_IM_BILD - CHAR_SEAT) * ANGLER_SCALE)
	# Der Schwimmer haengt am ENDE des Stegs, nicht an einem Bruchteil der
	# Bildbreite: die Schnur lief sonst je nach Seitenverhaeltnis quer ueber
	# die Planken. So beginnt sie immer erst hinter dem Steg.
	var dock_right := _dock.position.x + DOCK_W * DOCK_SCALE
	_bobber_home = Vector2(min(dock_right + BOBBER_OFF_DOCK * DOCK_SCALE, size.x * 0.75),
		water_y + size.y * 0.14)
	_bobber_mitte = _bobber_home
	_bobber.position = _bobber_home

## Der Wurfklang haengt am Zustandswechsel, nicht an einem Ereignis: die
## Simulation schickt fuer den Wurf keins, und im Offline-Nachlauf duerfte
## sie es auch gar nicht.
var _last_state: int = -1

func _process(delta: float) -> void:
	if Game.sim.state != _last_state:
		if Game.sim.state == FishingSim.State.CASTING and _last_state != -1:
			Audio.play(&"cast", 0.3)
		# Aufsetzen: ein Spritzer da, wo der Schwimmer landet.
		if Game.sim.state == FishingSim.State.WAITING and _last_state == FishingSim.State.CASTING:
			_water.disturb_at(_bobber_fraction(), SPLASH_KICK)
		_last_state = Game.sim.state

	_bob_time += delta
	var casting := Game.sim.state == FishingSim.State.CASTING
	## Solange geworfen wird, steht die Schnur nach aussen; danach faellt sie.
	_line_settle = 0.0 if casting else _line_settle + delta
	var visible_states := [FishingSim.State.CASTING, FishingSim.State.WAITING, FishingSim.State.FIGHT]
	_bobber.visible = Game.sim.state in visible_states
	var kaempft := Game.sim.state == FishingSim.State.FIGHT
	if casting:
		# Der Schwimmer war waehrend des Wurfs unsichtbar und tauchte am Ende
		# an seiner Endstelle auf -- er teleportierte. Jetzt fliegt er einen
		# Bogen, und die Schnur folgt ihm von selbst.
		_bobber_mitte = _cast_position()
	else:
		# Er wippt nicht nach eigenem Takt, er LIEGT auf dem Wasser: seine
		# Hoehe ist die Welle an seiner Stelle. Damit hebt ihn die Duenung,
		# und der Stoss eines Bisses reisst ihn nach unten, statt neben ihm
		# vorbeizulaufen. Im Kampf kommt der Zug des Fisches obendrauf.
		var zupfen := sin(_bob_time * 3.0) * FIGHT_TUG if kaempft else 0.0
		## Die Stelle kommt aus der Ruhelage, nicht aus _bobber_mitte -- das
		## traegt im ersten Bild nach dem Wurf noch die Flugposition.
		var anteil := clampf(_bobber_home.x / maxf(size.x, 1.0), 0.0, 1.0)
		_bobber_mitte = Vector2(_bobber_home.x,
			_bobber_home.y + _wellenhoehe(anteil) + zupfen)
	_setze_schwimmer(not casting)
	# Der Koeder haengt am Vorfach unter dem Schwimmer. Sichtbar nur im Flug:
	# sobald der Schwimmer sitzt, ist er unter Wasser.
	_update_bait(casting)
	# Schnur von der Rutenspitze zum Schwimmer -- folgt dadurch von selbst
	# dem Auf und Ab und dem Zappeln im Kampf. Im Flug haengt das Vorfach
	# darunter weiter.
	_line.visible = _bobber.visible
	if _line.visible:
		var spitze: Vector2 = _angler.rod_tip()
		var gesetzt := clampf(_line_settle / LINE_SETTLE, 0.0, 1.0)
		var punkte := _schnur(spitze, _bobber_mitte,
			LINE_BELLY_AIR.lerp(LINE_BELLY_WATER, gesetzt))
		if _bait.visible:
			punkte.append(_bait.position)
		_line.points = punkte
	# Die Orbs erscheinen rund um den Schwimmer, nicht ueber dem ganzen Bild.
	$CatchView.focus_point = _bobber_mitte
	_update_visitors()
	if _rain != null:
		_rain.visible = Game.ctx.raining
	_water_time += delta
	_water.step(delta)
	if _bobber.visible and kaempft:
		# Nur im Kampf stoesst er das Wasser an -- da wird er gezogen. Beim
		# Warten waere es eine Rueckkopplung: er schoebe das Wasser, das ihn
		# schiebt, ohne dass Kraft von aussen dazukaeme.
		var zug := FIGHT_TUG * 3.0 * cos(_bob_time * 3.0)
		_water.disturb_at(_bobber_fraction(), zug * BOBBER_DRIVE * delta)
	_update_water_line()

func _update_water_line() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var water_y := size.y * WATERLINE
	var pts := PackedVector2Array()
	pts.resize(WATER_POINTS)
	for i in WATER_POINTS:
		var fraction := float(i) / float(WATER_POINTS - 1)
		var wave := WaterSurface.ambient_offset(fraction, _water_time) + _water.heights[i]
		pts[i] = Vector2(size.x * fraction, water_y + WAVE_BIAS + wave * WAVE_SCALE)
	_water_line.points = pts
	## Dieselbe Punktfolge malt die Flaeche darunter -- Linie und Wasser
	## koennen dadurch nicht auseinanderlaufen.
	_water_view.setze(pts, size.x, size.y, _water_time)
	# Ufer bis zur Welle herunterziehen: hin entlang der Welle, zurueck entlang
	# der geraden Uferlinie.
	var poly := PackedVector2Array()
	poly.resize(WATER_POINTS * 2)
	for i in WATER_POINTS:
		poly[i] = pts[i]
		poly[WATER_POINTS * 2 - 1 - i] = Vector2(pts[i].x, water_y - SHORE_OVERLAP)
	_water_body.polygon = poly

## Der Koeder folgt dem Schwimmer, haengt aber darunter. Sein Bild kommt vom
## aktiven Koeder; wer noch keins hat, bekommt das der Teichmade.
func _update_bait(casting: bool) -> void:
	_bait.visible = casting
	if not _bait.visible:
		return
	if _bait.texture == null or _bait_id != _active_bait_id():
		_bait_id = _active_bait_id()
		var tex := TextureLoader.load_texture(
			"res://assets/art/bait_%s.png" % _bait_id)
		if tex == null:
			tex = TextureLoader.load_texture(
				"res://assets/art/bait_%s.png" % BAIT_FALLBACK)
		_bait.texture = tex
	_bait.position = _bobber_mitte + Vector2(0.0, BAIT_HANG * BOBBER_SCALE)

func _active_bait_id() -> StringName:
	var bait: BaitData = Game.ctx.bait
	return bait.id if bait != null else BAIT_FALLBACK

## Die Schnur als Kurve. Eine Gerade sieht aus wie ein Draht; bauch ist die
## Richtung, in die sie ausbaucht, wie weit kommt aus ihrer eigenen Laenge.
func _schnur(von: Vector2, nach: Vector2, bauch: Vector2) -> PackedVector2Array:
	var mitte := (von + nach) * 0.5 + bauch * (von.distance_to(nach) * LINE_SAG)
	var punkte := PackedVector2Array()
	punkte.resize(LINE_POINTS)
	for i in LINE_POINTS:
		var t := float(i) / float(LINE_POINTS - 1)
		var g := 1.0 - t
		punkte[i] = g * g * von + 2.0 * g * t * mitte + t * t * nach
	return punkte

## Der Schwimmer liegt IM Wasser, nicht darauf: schwimmend wird nur seine obere
## Haelfte gezeichnet, und die endet auf der Wasserlinie. Im Flug ist er ganz
## zu sehen. Geschnitten wird ueber region_rect -- so bleibt es ein Sprite.
func _setze_schwimmer(getaucht: bool) -> void:
	if _bobber.texture == null:
		return
	var groesse := _bobber.texture.get_size()
	_bobber.region_enabled = getaucht
	if getaucht:
		var sichtbar := floorf(groesse.y * 0.5)
		_bobber.region_rect = Rect2(0.0, 0.0, groesse.x, sichtbar)
		_bobber.position = Vector2(_bobber_mitte.x,
			_bobber_mitte.y - sichtbar * 0.5 * BOBBER_SCALE)
	else:
		_bobber.position = _bobber_mitte

## Der Ausschlag der Welle an dieser Stelle, in Bildschirmpixeln -- dieselbe
## Rechnung wie in _update_water_line(), nur an einem einzelnen Punkt.
func _wellenhoehe(anteil: float) -> float:
	var i := int(round(clampf(anteil, 0.0, 1.0) * float(WATER_POINTS - 1)))
	return (WaterSurface.ambient_offset(anteil, _water_time)
		+ _water.heights[i]) * WAVE_SCALE

func _bobber_fraction() -> float:
	if size.x <= 0.0:
		return 0.5
	return clampf(_bobber_mitte.x / size.x, 0.0, 1.0)

func _on_bite(_fish: FishData) -> void:
	_bob_time = 0.0
	_water.disturb_at(_bobber_fraction(), BITE_KICK)

## Keine Spiellogik hier -- nur die Stoerung, die das Aufspritzen zeigt. Die
## eigentliche Reaktion (Text, Partikel) macht effects.gd auf dasselbe Signal.
func _on_caught(_c: CaughtFish, _fish: FishData, _discovered: bool, _record: bool) -> void:
	_water.disturb_at(_bobber_fraction(), CATCH_KICK)

## Hintergrund und Wasserfarben kommen aus der Zone. Die Flaeche zwischen
## gerader Uferlinie und Welle wird in der FARBE DES UFERS gefuellt: dadurch
## liegt die sichtbare Grenze auf der Welle und nicht auf einer zweiten,
## geraden Kante.
func _apply_zone() -> void:
	var zone: ZoneData = Game.ctx.zone
	if zone == null or zone.id == _applied_zone:
		return
	_applied_zone = zone.id
	_background.texture = TextureLoader.load_texture(
		"res://assets/art/bg_%s.png" % zone.background_id)
	var schaum := Palette.get_color(zone.foam_key)
	var crest := schaum
	crest.a = 0.85
	_water_line.default_color = crest
	_water_body.color = Palette.get_color(zone.shore_key)
	_water_view.faerbe(schaum, Palette.get_color(zone.water_light_key),
		Palette.get_color(zone.water_deep_key))

## Der Schwimmer auf seinem Flug: eine quadratische Bezierkurve von der
## Rutenspitze zur Ruhelage, mit einem Scheitel darueber. Der Fortschritt
## kommt aus der Simulationsuhr, damit Flug und Wurfdauer nicht auseinander
## laufen koennen.
func _cast_position() -> Vector2:
	var t := 1.0 - clampf(Game.sim.timer / FishingSim.CAST_TIME, 0.0, 1.0)
	var from: Vector2 = _angler.rod_tip()
	var to := _bobber_home
	var peak := Vector2(to.x + CAST_OVERSHOOT, from.y - CAST_ARC)
	t = pow(t, CAST_FALL)
	var inv := 1.0 - t
	return inv * inv * from + 2.0 * inv * t * peak + t * t * to

## Besucher stehen am Steg und wollen angetippt werden. Sichtbar nur, wenn
## es wirklich etwas zu holen gibt -- ein Knopf, der nichts tut, ist Ballast.
func _setup_visitors() -> void:
	_raven.texture_normal = TextureLoader.load_texture("res://assets/art/raven.png")
	_trader.texture_normal = TextureLoader.load_texture("res://assets/art/trader.png")
	for b in [_raven, _trader]:
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(96, 96)
		b.size = Vector2(96, 96)
	if not _raven.pressed.is_connected(_on_raven_pressed):
		_raven.pressed.connect(_on_raven_pressed)
	if not _trader.pressed.is_connected(_on_trader_pressed):
		_trader.pressed.connect(_on_trader_pressed)

func _update_visitors() -> void:
	_raven.visible = Game.raven_waiting()
	_trader.visible = Game.trader_present() and not Game.trader_offer().is_empty()
	var deck_y := _dock.position.y
	_raven.position = Vector2(_dock.position.x + 8.0, deck_y - 104.0)
	_trader.position = Vector2(_dock.position.x + 116.0, deck_y - 96.0)

func _on_raven_pressed() -> void:
	var gift := Game.collect_raven()
	if gift == &"":
		return
	var c: ConsumableData = Database.consumables.get(gift)
	var name := c.display_name if c != null else String(gift)
	var pop := POP_TEXT_SCENE.instantiate()
	$Visitors.add_child(pop)
	pop.setup(name, _raven.position + Vector2(48.0, 0.0), Palette.get_color(&"accent"))

func _on_trader_pressed() -> void:
	Audio.click()
	visitor_tapped.emit()
