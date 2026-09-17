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
@onready var _clouds: Clouds = $Clouds
@onready var _reeds: Sprite2D = $Reeds
@onready var _water_body: Polygon2D = $WaterBody
@onready var _water_view: WaterView = $Water
@onready var _seam: Sprite2D = $Seam
@onready var _raven: TextureButton = $Visitors/Raven
@onready var _trader: TextureButton = $Visitors/Trader
var _rain: Rain = null
var _rabe_besuch: Visitor = null
var _baer_besuch: Visitor = null

## Der Hintergrund ist 320x180: Himmel bis Zeile 77, Ufer 78-83, Wasser ab 84.
const BG_SIZE := Vector2(320.0, 180.0)
const BG_WATER_ROW := 84.0
## Auf welcher Zeile ueber der Wasserlinie die Schilffuesse stehen. Die
## gemalte Uferbande reicht HOEHER hinauf (tools/ufer_bauen.py): so liegt
## Gras hinter den Halmen und nicht nur davor.
const BG_REED_ROW := 6.0
## Wo die Wasserlinie auf dem SCHIRM sitzt -- daran haengt alles andere: Steg,
## Figur, Schwimmer, Welle. Das ist die Bildkomposition und nicht mehr die
## Zeile im Hintergrundbild: bei 84/180 sass der Horizont so hoch, dass die
## Figur im oberen Drittel klebte. Der Hintergrund wird jetzt passend dazu
## gelegt (_place_background), statt umgekehrt.
const WATERLINE := 0.60
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
## denselben Massstab. Bei 40 lagen sie knapp ueber der RUHENDEN Wasserlinie
## -- seit das Wasser sichtbar wellt, griff der Kamm darueber. 46 laesst rund
## acht Figurpixel Luft, auch ueber dem Stoss eines Bisses.
##
## Zwei fehlgeschlagene Versuche, ihn tiefer zu setzen (8, dann 30), zeigten:
## die Wasserflaeche schneidet Deck UND Pfosten an einer FESTEN Linie ab
## (water_y - SHORE_OVERLAP, siehe _update_water_line) -- nicht erst am Fuss
## der Pfosten, sondern praktisch am Ufer. Ein KLEINERER Wert rueckt darum
## sowohl die Fuesse naeher an die Welle ALS AUCH weniger Pfosten ueber diese
## Linie -- die Wirkrichtung war falsch angenommen. Zurueck auf den
## urspruenglichen, gemessenen Wert.
const DECK_OVER_WATER := 46.0
## Wo die Anglerin sitzt, vom linken Stegende in Stegpixeln. Ihr Sprite haengt
## an der oberen linken Ecke; bei 187 liegt ihre Sitzflaeche (Figurspalten
## 44 bis 68) genau auf den letzten Planken, und die Beine haengen ueber der
## Kante. Steg und Figur haben denselben Massstab, ein Pixel ist ein Pixel.
const ANGLER_ON_DECK := 187.0
## Wie weit hinter dem Stegende der Schwimmer liegt, in Stegpixeln. Halbiert
## mit dem Massstab: 120 alte Stegpixel sind 60 neue.
const BOBBER_OFF_DOCK := 60.0
## Wie weit UNTER der Wasserlinie der Schwimmer liegt, als Bruchteil der
## Bildhoehe. Er wird vom Steg hinaus geworfen, liegt also weit draussen --
## und weit draussen heisst in dieser Ansicht NAH AN DER WASSERLINIE, nicht
## tief unten im Vordergrundwasser. Vorher stand hier 0.14; damit sass er
## gut hundert Punkte unter der Kante, mitten im Wasser statt darauf.
const BOBBER_BELOW_WATER := 0.04
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
##
## War kurz auf 5 herabgesetzt, damit die Pfosten naeher an die Welle reichen
## -- genau die vorhergesagte Kante wurde sichtbar. Zurueck auf den sicheren
## Wert: dass die Pfosten bis an die Welle reichen, loest jetzt die
## Zeichenreihenfolge in world.tscn, nicht dieser Abstand.
const WAVE_BIAS := 9.5
## Wie weit die Uferfarbe ins Gras hinaufreicht. Die Farbkante des skalierten
## Hintergrundbilds liegt nicht exakt auf 84/180 -- ohne Reserve blitzte dort
## ein zwei Pixel duenner Streifen Wasser durch (am Screenshot ausgemessen).
##
## Bei 10 schnitt die Wasserflaeche die Stegpfosten so weit oberhalb der
## Welle ab, dass sie sichtbar darueber zu schweben schienen -- der ganze
## Streifen dazwischen ist Uferfarbe, nicht Wellenwasser. Knapp ueber dem
## dokumentierten Mindestwert von 2 belassen.
const SHORE_OVERLAP := 3.0
## Wie weit der Uferstreifen unter dem Uferton der Zone liegt. Er schliesst
## an die UNTERSTE Zeile der gemalten Uferbande an (tools/ufer_bauen.py), und
## die ist abgedunkelt: im vollen Uferton stand er als hellerer gruener Balken
## zwischen Gras und Welle.
const SHORE_STRIP_DARKEN := 0.27
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
## Wie die Flugzeit verteilt ist -- als AUSKLINGEN: 1 - (1-t)^CAST_EASE.
## Der Schwimmer schiesst hinaus und wird langsamer, so wie eine Schnur
## ausrollt. Vorher stand hier pow(t, 1.45), also das Gegenteil: er hing
## erst hinterher und stuerzte dann in einem Satz ins Wasser.
##
## Ein blosser Exponent unter 1 reichte nicht. Die Bahn ist hinten viel
## laenger als vorn -- rund 60 Punkte hinauf, aber 220 wieder hinunter --,
## also muss die Zeit am Ende deutlich langsamer laufen und nicht nur etwas.
const CAST_EASE := 2.2
## Wann er die Rutenspitze verlaesst, als Anteil des Wurfs. Bis dahin haengt
## er an ihr.
##
## Der Wert gehoert zum Umkehrpunkt der Anglerin: der liegt bei
## CAST_SWING * CAST_WINDUP (angler.gd), also bei 0.315, und der Schwimmer
## loest sich kurz DANACH -- im Schnalzen nach vorn, nicht im Ausholen.
## tests/test_zone_look.gd haelt beide Zahlen zusammen.
const CAST_RELEASE := 0.34
## Wie weit die Schnur durchhaengt, als Anteil ihrer eigenen Laenge. Ein
## fester Wert waere im Flug ein Klumpen und in Ruhe kaum zu sehen; so haengt
## sie ueberall gleich, und der Bogen ist schon im Flug da.
const LINE_POINTS := 12
const LINE_SAG := 0.28
## Wohin der Bauch zeigt. In der Luft folgt die Schnur dem Wurf: der Bogen
## steht nach aussen und faellt nur wenig. Sitzt der Schwimmer, faellt sie in
## den senkrechten Durchhang -- ueber LINE_SETTLE Sekunden, sonst springt sie.
const LINE_BELLY_AIR := Vector2(0.86, 0.51)
## Etwas mehr Bauch als der reine senkrechte Durchhang (1.0), auf Wunsch.
const LINE_BELLY_WATER := Vector2(0.0, 1.4)
const LINE_SETTLE := 0.14
## Wie weit der Koeder unter dem Schwimmer haengt, in Figurpixeln. Er sitzt am
## Vorfach: beim Ausholen baumelt er an der Rutenspitze, im Flug zieht er
## hinterher, und mit dem Aufsetzen ist er unter Wasser.
const BAIT_HANG := 12.0
## Fallback, solange nicht jeder Koeder ein eigenes Bild hat.
const BAIT_FALLBACK := &"pond_grub"
const POP_TEXT_SCENE := preload("res://scenes/effects/pop_text.tscn")

## Das Schilf (tools/schilf_bauen.py) laeuft im Massstab der FIGUR, nicht in
## dem des Hintergrunds: dort waere ein Halm dreimal so grob wie alles andere.
## Das Blatt kachelt in der Breite; seine unterste Zeile ist die Standlinie
## und kommt auf die Wasserlinie. Gezeichnet wird es vor dem Uferstreifen und
## hinter dem Steg (world.tscn) -- so ziehen die Wolken dahinter vorbei.
const REED_SIZE := Vector2(192.0, 72.0)
const REED_SCALE := ANGLER_SCALE

## Rabe und Waschbaer (tools/besucher_bauen.py) laufen im Massstab der Figur.
## Vorher waren sie 18 Pixel breit und wurden auf eine 96er-Box gestreckt --
## 5,33fach, also zweieinhalb Mal so grob wie alles andere im Bild.
const VISITOR_PX := 48.0
const VISITOR_SCALE := ANGLER_SCALE
## Wo sie auf dem Steg stehen, vom linken Stegende in Stegpixeln. Beide sind
## 48 Stegpixel breit, 28 und 88 lassen ihnen also Luft zueinander und bis zur
## Anglerin auf 187. Bei 4 klebte der Rabe am Bildrand -- seit die Welt
## randlos laeuft, stand er damit halb im Kameraausschnitt.
const RAVEN_ON_DECK := 28.0
const TRADER_ON_DECK := 88.0
## Wie schnell sie wippen. Verschiedene Takte, sonst huepfen sie im
## Gleichschritt wie ein Uhrwerk.
const RAVEN_BOB := 2.3
const TRADER_BOB := 1.7
## Bilder je Reihe (tools/besucher_bauen.py).
const VISITOR_FRAMES := 8

## Womit der Himmel bei Regen eingefaerbt wird. Multiplikativ, also eine
## Entsaettigung ins Graue statt einer zweiten, gemalten Himmelsfarbe.
const REGEN_HIMMEL := Color(0.62, 0.66, 0.72)

var _bob_time: float = 0.0
var _bobber_home: Vector2
## Wo der Schwimmer wirklich sitzt. Nicht dasselbe wie seine Sprite-Position:
## schwimmend ist er halb abgeschnitten und sein Sprite sitzt hoeher.
var _bobber_mitte: Vector2
## Wie lange der Schwimmer schon sitzt -- daran kippt der Bauch der Schnur.
var _line_settle: float = 0.0
## Gehoert der Schwimmer gerade zur Szene? Nicht dasselbe wie _bobber.visible
## -- das schaltet der Schnitt an der Wasserlinie ab, wenn er untergeht.
var _bobber_sichtbar: bool = false
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
	_reeds.texture = TextureLoader.load_texture("res://assets/art/schilf.png")
	_reeds.scale = Vector2(REED_SCALE, REED_SCALE)
	_angler.scale = Vector2(ANGLER_SCALE, ANGLER_SCALE)
	_bobber.scale = Vector2(BOBBER_SCALE, BOBBER_SCALE)
	_bait.scale = Vector2(BOBBER_SCALE, BOBBER_SCALE)
	## Der Saum zeigt EINE Zeile desselben Bildes, flach in der Randfarbe --
	## dadurch hat er genau den Umriss, den der Schwimmer dort hat.
	_seam.texture = _bobber.texture
	_seam.region_enabled = true
	_seam.scale = Vector2(BOBBER_SCALE, BOBBER_SCALE)
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
	_place_background(water_y)
	# Der Steg liegt mit seiner Deckoberkante ueber der Wasserlinie, die
	# Pfosten ragen ins Wasser. Reihenfolge in world.tscn: WaterBody (der
	# flache Uferstreifen) VOR dem Steg, die Wasserflaeche danach -- so
	# verschluckt ihn die WELLE und nicht die gerade Oberkante des
	# Uferstreifens. Andersherum endeten die Pfosten an einer Linie ueber dem
	# Wasser und schienen darueber zu schweben.
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
		water_y + size.y * BOBBER_BELOW_WATER)
	_bobber_mitte = _bobber_home
	_bobber.position = _bobber_home

## Den Hintergrund so legen, dass seine gemalte Uferkante GENAU auf der
## Wasserlinie liegt. Sonst zeigt er Wasser, wo die Welt noch Gras rechnet --
## und die Welle liefe sichtbar neben der gemalten Kante.
##
## Der Massstab muss dafuer gross genug sein, dass weder oben noch unten etwas
## frei bleibt; die Seiten duerfen dabei beschnitten werden (der Himmel ist
## ein Verlauf, das Wasser eine Flaeche -- da faellt es nicht auf). Dass sie
## wirklich beschnitten werden und nicht links aus dem Weltfenster quellen,
## macht clip_contents am Wurzelknoten (world.tscn).
func _place_background(water_y: float) -> void:
	var s := maxf(size.x / BG_SIZE.x, maxf(water_y / BG_WATER_ROW,
		(size.y - water_y) / (BG_SIZE.y - BG_WATER_ROW)))
	var gemalt := BG_SIZE * s
	_background.size = gemalt
	_background.position = Vector2((size.x - gemalt.x) * 0.5,
		water_y - BG_WATER_ROW * s)
	# Die Wolken zeichnen im selben Pixelraster wie der Himmel hinter ihnen.
	_clouds.setze(s, water_y, size.x)
	# Das Schilf steht mit seiner untersten Zeile auf der Boeschung. An der
	# Wasserlinie sass es zu tief -- es stand dann vor dem Gras statt darin.
	var schilf_fuss := water_y - BG_REED_ROW * s
	_reeds.region_rect = Rect2(0.0, 0.0, size.x / REED_SCALE, REED_SIZE.y)
	_reeds.position = Vector2(0.0, schilf_fuss - REED_SIZE.y * REED_SCALE)

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
	## Der Schnitt darf ihn spaeter noch verstecken, also merken wir uns
	## getrennt, ob er ueberhaupt dazugehoert.
	_bobber_sichtbar = Game.sim.state in visible_states
	_bobber.visible = _bobber_sichtbar
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
	## Seine eigene Wasserlinie: die Welle an seiner Stelle. Nicht die
	## gezeichnete Wellenlinie am Ufer -- er liegt weiter draussen.
	var wasserlinie := _bobber_home.y + _wellenhoehe(
		clampf(_bobber_home.x / maxf(size.x, 1.0), 0.0, 1.0))
	## Nur schneiden, wenn er ueberhaupt dazugehoert -- sonst setzt der Schnitt
	## sprite.visible selbst wieder auf true, sobald ein Stueck ueber der
	## Wasserlinie liegt, und die Sperre von oben waere umsonst gewesen.
	var zeilen := _schneide(_bobber, _bobber_mitte, wasserlinie, true) \
		if _bobber_sichtbar else 0.0
	_setze_saum(zeilen, wasserlinie)
	# Der Koeder haengt am Vorfach unter dem Schwimmer. Er taucht vor ihm ein
	# und verschwindet dabei von selbst -- derselbe Schnitt.
	_update_bait(wasserlinie)
	# Schnur von der Rutenspitze zum Schwimmer -- folgt dadurch von selbst
	# dem Auf und Ab und dem Zappeln im Kampf. Im Flug haengt das Vorfach
	# darunter weiter.
	_line.visible = _bobber_sichtbar
	if _line.visible:
		var spitze: Vector2 = _angler.rod_tip()
		var gesetzt := clampf(_line_settle / LINE_SETTLE, 0.0, 1.0)
		var punkte := _schnur(spitze, _bobber_mitte,
			LINE_BELLY_AIR.lerp(LINE_BELLY_WATER, gesetzt))
		if _bait.visible:
			## Das Vorfach endet an der Wasserlinie -- darunter sieht man es
			## nicht, und der Koeder ist dort ohnehin schon weggeschnitten.
			punkte.append(Vector2(_bobber_mitte.x,
				minf(_bobber_mitte.y + BAIT_HANG * BOBBER_SCALE,
					wasserlinie)))
		_line.points = punkte
	# Die Orbs erscheinen rund um den Schwimmer, nicht ueber dem ganzen Bild.
	$CatchView.focus_point = _bobber_mitte
	# ... und nie oberhalb des Wassers. Seit der Schwimmer dicht unter der
	# Kante liegt, reicht sein Streukreis (ORB_RADIUS) sonst bis in den Himmel.
	$CatchView.water_line = wasserlinie
	_update_visitors(delta)
	if _rain != null:
		_rain.visible = Game.ctx.raining
	# Bei Regen zieht der Himmel grau zu. Die Ueberblendung kommt von den
	# Wolken, damit Himmelfarbe und Bewoelkung nicht getrennt voneinander
	# umschalten -- ein Wetter, eine Uhr.
	_background.modulate = Color.WHITE.lerp(REGEN_HIMMEL, _clouds.nass())
	_water_time += delta
	_water.step(delta)
	if _bobber_sichtbar and kaempft:
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
	## koennen dadurch nicht auseinanderlaufen. Und der Regen hoert darauf
	## auf, statt quer ueber das Wasser weiterzulaufen.
	_water_view.setze(pts, size.x, size.y, _water_time)
	if _rain != null:
		_rain.setze_wasser(pts, water_y + WAVE_BIAS)
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
func _update_bait(wasserlinie: float) -> void:
	if not _bobber_sichtbar:
		_bait.visible = false
		return
	if _bait.texture == null or _bait_id != _active_bait_id():
		_bait_id = _active_bait_id()
		var tex := TextureLoader.load_texture(
			"res://assets/art/bait_%s.png" % _bait_id)
		if tex == null:
			tex = TextureLoader.load_texture(
				"res://assets/art/bait_%s.png" % BAIT_FALLBACK)
		_bait.texture = tex
	_schneide(_bait, _bobber_mitte + Vector2(0.0, BAIT_HANG * BOBBER_SCALE),
		wasserlinie)

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

## Ein Sprite an der Wasserlinie abschneiden -- immer, nicht erst beim
## Aufsetzen. Vorher war es ein Umschalten: ganz im Flug, halb im Wasser, und
## im Bild dazwischen sprang es. Jetzt wird beim Eintauchen Zeile fuer Zeile
## geschluckt, und was ganz unten ist, verschwindet.
##
## Geschnitten wird ueber region_rect, es bleibt also ein Sprite. Das Sprite
## haengt an seiner Mitte, deshalb wandert die Position um die halbe
## weggeschnittene Hoehe mit.
## Gibt zurueck, wie viele Pixelzeilen ueber Wasser stehen -- daran haengt der
## Saum. mit_saum laesst die unterste davon frei: die malt _setze_saum().
func _schneide(sprite: Sprite2D, mitte: Vector2, wasserlinie: float,
		mit_saum: bool = false) -> float:
	if sprite.texture == null:
		return 0.0
	var groesse := sprite.texture.get_size()
	var oben := mitte.y - groesse.y * 0.5 * BOBBER_SCALE
	var sichtbar := floorf(clampf((wasserlinie - oben) / BOBBER_SCALE,
		0.0, groesse.y))
	if sichtbar < 1.0:
		sprite.visible = false
		return 0.0
	var gemalt := sichtbar
	if mit_saum and sichtbar < groesse.y:
		gemalt -= 1.0
	if gemalt < 1.0:
		sprite.visible = false
		return sichtbar
	sprite.visible = true
	sprite.region_enabled = gemalt < groesse.y
	if not sprite.region_enabled:
		sprite.position = mitte
		return sichtbar
	sprite.region_rect = Rect2(0.0, 0.0, groesse.x, gemalt)
	## Unten ausrichten, nicht oben: die Kante muss GENAU auf der Wasserlinie
	## liegen. Wer den Kopf festhaelt und unten abschneidet, laesst je nach
	## Rundung eine Pixelzeile Luft dazwischen. Der Saum belegt die letzte.
	var unterkante := wasserlinie - (BOBBER_SCALE if mit_saum else 0.0)
	sprite.position = Vector2(mitte.x,
		unterkante - gemalt * 0.5 * BOBBER_SCALE)
	return sichtbar

## Die unterste Zeile ueber Wasser in der Farbe des Wasserrandes. Ohne sie
## endet der Schwimmer an einer harten Kante, und die faellt beim Auf und Ab
## der Welle staerker auf als die Bewegung selbst.
func _setze_saum(zeilen: float, wasserlinie: float) -> void:
	var groesse: Vector2 = _seam.texture.get_size() if _seam.texture != null 		else Vector2.ZERO
	if not _bobber_sichtbar or zeilen < 1.0 or zeilen >= groesse.y:
		_seam.visible = false
		return
	_seam.visible = true
	_seam.region_rect = Rect2(0.0, zeilen - 1.0, groesse.x, 1.0)
	_seam.position = Vector2(_bobber_mitte.x, wasserlinie
		- 0.5 * BOBBER_SCALE)

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
	_water_body.color = Palette.get_color(zone.shore_key).darkened(SHORE_STRIP_DARKEN)
	_water_view.faerbe(schaum, Palette.get_color(zone.water_light_key),
		Palette.get_color(zone.water_deep_key))
	var stoff := _seam.material as ShaderMaterial
	if stoff != null:
		stoff.set_shader_parameter("saum", schaum)

## Der Schwimmer auf seinem Flug: eine quadratische Bezierkurve von der
## Rutenspitze zur Ruhelage, mit einem Scheitel darueber. Der Fortschritt
## kommt aus der Simulationsuhr, damit Flug und Wurfdauer nicht auseinander
## laufen koennen.
func _cast_position() -> Vector2:
	var roh := 1.0 - clampf(Game.sim.timer / FishingSim.CAST_TIME, 0.0, 1.0)
	# Der Schwimmer bleibt an der Rutenspitze, bis sie nach vorn schnellt --
	# vorher flog er schon los, waehrend sie noch ausholte.
	var t := clampf((roh - CAST_RELEASE) / (1.0 - CAST_RELEASE), 0.0, 1.0)
	var from: Vector2 = _angler.rod_tip()
	var to := _bobber_home
	var peak := Vector2(to.x + CAST_OVERSHOOT, from.y - CAST_ARC)
	t = 1.0 - pow(1.0 - t, CAST_EASE)
	var inv := 1.0 - t
	return inv * inv * from + 2.0 * inv * t * peak + t * t * to

## Besucher stehen am Steg und wollen angetippt werden. Sichtbar nur, wenn
## es wirklich etwas zu holen gibt -- ein Knopf, der nichts tut, ist Ballast.
func _setup_visitors() -> void:
	var rabe_ruhe := TextureLoader.load_texture("res://assets/art/raven.png")
	var baer_ruhe := TextureLoader.load_texture("res://assets/art/trader.png")
	_raven.texture_normal = rabe_ruhe
	_trader.texture_normal = baer_ruhe
	for b in [_raven, _trader]:
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var kante := VISITOR_PX * VISITOR_SCALE
		b.custom_minimum_size = Vector2(kante, kante)
		b.size = Vector2(kante, kante)
	# Der Rabe fliegt an und zieht nach rechts uebers Wasser ab, der
	# Waschbaer laeuft von links herein und links wieder hinaus.
	_rabe_besuch = Visitor.new(_raven, rabe_ruhe,
		TextureLoader.load_texture("res://assets/art/raven_fly.png"),
		VISITOR_FRAMES, true, false, RAVEN_BOB)
	_baer_besuch = Visitor.new(_trader, baer_ruhe,
		TextureLoader.load_texture("res://assets/art/trader_walk.png"),
		VISITOR_FRAMES, false, true, TRADER_BOB)
	if not _raven.pressed.is_connected(_on_raven_pressed):
		_raven.pressed.connect(_on_raven_pressed)
	if not _trader.pressed.is_connected(_on_trader_pressed):
		_trader.pressed.connect(_on_trader_pressed)

func _update_visitors(delta: float) -> void:
	if _rabe_besuch == null:
		return
	# Beide Bilder stehen mit den Fuessen auf ihrer untersten Zeile
	# (tools/besucher_bauen.py), ihre Standlinie ist also die Bildunterkante.
	var deck_oben := _dock.position.y + DECK_IM_BILD * DOCK_SCALE
	var kante := VISITOR_PX * VISITOR_SCALE
	var fuss := deck_oben - kante
	_rabe_besuch.setze(fuss, _dock.position.x + RAVEN_ON_DECK * DOCK_SCALE,
		kante, size.x)
	_baer_besuch.setze(fuss, _dock.position.x + TRADER_ON_DECK * DOCK_SCALE,
		kante, size.x)
	# Die Welt sagt nur, ob sie da sein SOLLEN -- Ankommen und Weggehen
	# regelt scenes/fishing/visitor.gd.
	_rabe_besuch.tick(delta, Game.raven_waiting())
	_baer_besuch.tick(delta, Game.trader_visible())

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
