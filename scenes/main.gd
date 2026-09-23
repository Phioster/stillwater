## Hält das Querformat-Layout zusammen: links die Welt, rechts das Panel,
## ganz rechts die Tab-Leiste. Das Panel überdeckt die Welt nie — ein Fisch
## kann mitten im Laden gedrillt werden.
extends Control

## Die WIRKLICHEN Masse des Seitenlayouts. _layout() schreibt daraus jeden
## Durchlauf die Offsets von $SidePanel -- was in main.tscn steht, ist nur der
## Anfangswert und wird ueberschrieben. Wer hier etwas aendert, aendert es
## also fuer das Spiel; wer es nur in der Szene aendert, aendert nichts.
##
## Das Panel liegt UEBER der Welt (siehe _layout), es kostet also keine
## Bildbreite -- nur die Leiste tut das dauerhaft.
const PANEL_WIDTH := 520.0
const RAIL_WIDTH := 140.0
## Reiter und Unterreiter, die von aussen angesprungen werden. Die Reihenfolge
## steht in TabRail.TABS und in den Kindern von SidePanel/Panels.
const FISH_TAB := 0
const GEAR_TAB := 1
const GEAR_SUB_POTION := 1
const SHOP_TAB := 2
const SHOP_SUB_TRADER := 3
const JOURNAL_TAB := 3
const JOURNAL_SUB_SECRET := 1
## Die Trankreihe steht, wo frueher die Fanganzeige stand: unter der Kopfzeile.
const BUFF_TOP := 132.0

var _tab: int = -1

@onready var _side: PanelContainer = $SidePanel
@onready var _panels: Control = $SidePanel/Panels
@onready var _rail = $Row/TabRail
@onready var _journal_panel = $SidePanel/Panels/JournalGroup/JournalScroll/JournalPanel
@onready var _secret_panel = $SidePanel/Panels/JournalGroup/SecretScroll/SecretPanel
@onready var _journal_group: TabGroup = $SidePanel/Panels/JournalGroup
@onready var _gear_group: TabGroup = $SidePanel/Panels/GearGroup
@onready var _shop_group: TabGroup = $SidePanel/Panels/ShopGroup
@onready var _fish_window = $FishWindow

func _ready() -> void:
	# Umriss und Schatten fuer alles auf einmal.
	theme = UiTheme.build()
	# Der Haendler in der Welt oeffnet seinen Reiter: Laden, Unterreiter 1.
	var world := $Row/World
	if world.has_signal("visitor_tapped") and not world.visitor_tapped.is_connected(_open_trader):
		world.visitor_tapped.connect(_open_trader)
	if not $BuffBar.tapped.is_connected(_open_potions):
		$BuffBar.tapped.connect(_open_potions)
	if not _rail.tab_selected.is_connected(show_tab):
		_rail.tab_selected.connect(show_tab)
	if not _journal_panel.fish_tapped.is_connected(_fish_window.open):
		_journal_panel.fish_tapped.connect(_fish_window.open)
	if not _secret_panel.fish_tapped.is_connected(_fish_window.open):
		_secret_panel.fish_tapped.connect(_fish_window.open)
	_setup_scrolling()
	if not Game.state_changed.is_connected(_update_secret_sub):
		Game.state_changed.connect(_update_secret_sub)
	_update_secret_sub()
	if not Game.state_changed.is_connected(_update_trader_sub):
		Game.state_changed.connect(_update_trader_sub)
	_update_trader_sub()
	_apply_safe_area()
	if not get_viewport().size_changed.is_connected(_apply_safe_area):
		get_viewport().size_changed.connect(_apply_safe_area)
	show_tab(-1)


## Seitwaerts scrollen ergibt in einem 420 breiten Panel keinen Sinn und
## kaempft nur mit dem senkrechten. Die Wischschwelle sagt Godot, ab wann eine
## Bewegung ein Scrollen ist und kein Tippen.
var _glides: Array[GlideScroll] = []

## Rekursiv: die Listen stecken seit der Gruppierung eine Ebene tiefer, und
## eine Schleife nur ueber die direkten Kinder haette sie stumm uebersehen --
## das Scrollen waere ueberall weg gewesen, ohne dass ein Test anschlaegt.
func _setup_scrolling(node: Node = null) -> void:
	var parent: Node = node if node != null else _panels
	for child in parent.get_children():
		if child is ScrollContainer:
			var sc: ScrollContainer = child
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			sc.scroll_deadzone = 8
			var glide := GlideScroll.new(sc)
			_glides.append(glide)
			sc.gui_input.connect(glide.on_input)
		else:
			_setup_scrolling(child)

## Blendet genau ein Panel ein. -1 schließt alle. Ein Index außerhalb der
## vorhandenen Panels wirkt wie -1: alles bleibt zu, statt abzustürzen.
func show_tab(index: int) -> void:
	var count := _panels.get_child_count()
	var valid := index >= 0 and index < count
	# Den Laden zu schliessen verabschiedet den Haendler, falls man bei ihm
	# gekauft hat. Deshalb haengt das hier und nicht am Kaufknopf.
	if _tab == SHOP_TAB and index != SHOP_TAB:
		Game.close_shop()
	_update_trader_sub()
	_tab = index if valid else -1
	_side.visible = valid
	var welt := $Row/World
	if welt.has_method("set_menu_open"):
		welt.set_menu_open(valid)
	for i in count:
		(_panels.get_child(i) as Control).visible = (valid and i == index)

## Hält HUD und Tab-Leiste aus Notch und Gestenleiste heraus.
func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.window_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return
	var scale_x := float(size.x) / float(screen.x)
	var scale_y := float(size.y) / float(screen.y)
	var left := float(safe.position.x) * scale_x
	var top := float(safe.position.y) * scale_y
	var right := float(screen.x - safe.end.x) * scale_x
	var bottom := float(screen.y - safe.end.y) * scale_y
	# Die WELT laeuft randlos bis an die Geraetekante: der Kameraausschnitt
	# soll nicht als grauer Streifen neben dem Bild stehen. Nur was gelesen
	# oder getroffen werden muss, bleibt im sicheren Bereich -- HUD und Panel
	# weiter unten, und rechts die Tab-Leiste, die am Ende dieser Zeile sitzt.
	$Row.offset_left = 0.0
	$Row.offset_top = 0.0
	$Row.offset_right = -right
	$Row.offset_bottom = 0.0
	$Hud.offset_left = left + 16.0
	$Hud.offset_top = top + 16.0
	$BuffBar.offset_left = left + 16.0
	$BuffBar.offset_top = top + BUFF_TOP
	# Das Panel liegt UEBER der Welt statt neben ihr -- sonst schrumpfte das
	# Wasser, sobald man das Menue oeffnet. Es haengt rechts, links neben der
	# Tab-Leiste, und wandert mit dem sicheren Bereich mit.
	$SidePanel.offset_left = -(PANEL_WIDTH + RAIL_WIDTH) - right
	$SidePanel.offset_right = -RAIL_WIDTH - right
	$SidePanel.offset_top = top
	$SidePanel.offset_bottom = -bottom

## Nachschwung fuer alle Listen. Eine Stelle, damit kein Panel es vergessen kann.
func _process(delta: float) -> void:
	for g in _glides:
		g.update(delta)

## Vor dem ersten Geheimfang soll nichts auf sie hindeuten -- der Unterreiter
## entsteht erst mit dem Fang.
func _update_secret_sub() -> void:
	if _journal_group == null:
		return
	var known := Game.ctx != null and Game.ctx.journal.has_any_secret()
	_journal_group.set_sub_visible(JOURNAL_SUB_SECRET, known)

func _open_potions() -> void:
	_rail.select(GEAR_TAB)
	_gear_group.select_sub(GEAR_SUB_POTION)

func _open_trader() -> void:
	_update_trader_sub()
	_rail.select(SHOP_TAB)
	_shop_group.select_sub(SHOP_SUB_TRADER)

## Der Haendler hat keinen festen Reiter: sein Unterreiter gibt es nur, solange
## er am Steg steht -- wie Cornerponds Maus, die sich nur beim Antippen oeffnet.
func _update_trader_sub() -> void:
	if _shop_group != null:
		_shop_group.set_sub_visible(SHOP_SUB_TRADER, Game.trader_visible())
