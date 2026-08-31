## Hält das Querformat-Layout zusammen: links die Welt, rechts das Panel,
## ganz rechts die Tab-Leiste. Das Panel überdeckt die Welt nie — ein Fisch
## kann mitten im Laden gedrillt werden.
extends Control

const PANEL_WIDTH := 420.0
const RAIL_WIDTH := 96.0
## Unterreiter der Fischgruppe: Inventar, Vitrine, Geheim.
const FISH_SUB_SECRET := 2

@onready var _side: PanelContainer = $SidePanel
@onready var _panels: Control = $SidePanel/Panels
@onready var _rail = $Row/TabRail
@onready var _journal_panel = $SidePanel/Panels/JournalGroup/JournalScroll/JournalPanel
@onready var _secret_panel = $SidePanel/Panels/FishGroup/SecretScroll/SecretPanel
@onready var _fish_group: TabGroup = $SidePanel/Panels/FishGroup
@onready var _fish_window = $FishWindow

func _ready() -> void:
	# Umriss und Schatten fuer alles auf einmal.
	theme = UiTheme.build()
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
	_side.visible = valid
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
	$Row.offset_left = left
	$Row.offset_top = top
	$Row.offset_right = -right
	$Row.offset_bottom = -bottom
	$Hud.offset_left = left + 16.0
	$Hud.offset_top = top + 16.0
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
## entsteht erst mit dem Fang. Das war frueher ein eigener Hauptreiter.
func _update_secret_sub() -> void:
	if _fish_group == null:
		return
	var known := Game.ctx != null and Game.ctx.journal.has_any_secret()
	_fish_group.set_sub_visible(FISH_SUB_SECRET, known)
