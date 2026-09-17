## Eine Fischzeile im Inventar und in der Vitrine. Beide zeigen dasselbe --
## nur der Verkaufsknopf faellt in der Vitrine weg.
class_name FishRow
extends RefCounted

## Alle Zeilen sind gleich hoch -- daran haengt die virtuelle Liste: nur mit
## fester Hoehe laesst sich aus der Scrollposition ausrechnen, welche Zeilen
## sichtbar sind, ohne sie zu bauen.
const HEIGHT: float = 96.0
## Die beiden Knoepfe am rechten Rand -- Daumengroesse, nicht Textgroesse.
## Sie stehen hier als Konstanten, weil tests/test_ui_theme.gd nachrechnet,
## ob Name plus Knoepfe noch ins Seitenpanel passen.
const FAV_WIDTH: float = 96.0
const SELL_WIDTH: float = 120.0
## So schmal darf der Name werden, bevor er umbricht, und so viele Zeilen
## darf er hoechstens brauchen. Beide Werte sind gemessen: unter 150 Punkten
## braucht "✦ Schwarzwasserstör (klein)" mehr als drei Zeilen, und drei Zeilen
## sind 93 Punkte -- gerade noch innerhalb von HEIGHT.
const NAME_WIDTH: float = 240.0
const NAME_LINES: int = 3

static func build(index: int, in_showcase: bool) -> Control:
	var c: CaughtFish = Game.ctx.inventory.fish[index]
	var fish: FishData = Database.fish.get(c.fish_id)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, HEIGHT)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ohne Umbruch ist die MINDESTBREITE einer Beschriftung ihr ganzer Text:
	# "✦ Schwarzwasserstör (klein)" plus die beiden Knoepfe sind 524 Punkte,
	# und ein Container wird nicht schmaler als sein Inhalt -- die Zeile schob
	# sich damit ueber die Reiterleiste daneben.
	#
	# Umbruch allein reicht aber NICHT: ohne Mindestbreite faellt die auf 1
	# Punkt, und dann steht derselbe Text auf acht Zeilen -- die Mindesthoehe
	# sprang damit auf 165. VirtualList rechnet die sichtbaren Zeilen aus der
	# Scrollposition aus und setzt dafuer ueberall dieselbe Hoehe voraus; mit
	# zu hohen Zeilen ruckelt das Wischen sichtbar. Beides muss also stehen:
	# eine Mindestbreite, und ein Deckel auf der Zeilenzahl.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	label.max_lines_visible = NAME_LINES
	var name := fish.full_name(c.weight_dev) if fish != null else String(c.fish_id)
	if c.is_shiny:
		name = "✦ " + name
	var w := fish.weight_str(c.weight_dev) if fish != null else "?"
	label.text = "%s\n%s · %s" % [name, FishRoll.RANK_NAMES[c.rank], w]
	if fish != null:
		label.modulate = Game.ctx.rarity_of(fish).color
	row.add_child(label)

	var fav := TapButton.new()
	fav.text = "★" if c.is_favorite else "☆"
	fav.custom_minimum_size = Vector2(FAV_WIDTH, HEIGHT)
	# Nicht ausgrauen, sondern ablehnen und wackeln: ein grauer Knopf sagt
	# nicht, WARUM er nicht geht, ein Wackeln zeigt wenigstens, dass die
	# Berührung ankam.
	fav.tapped.connect(func() -> void:
		if not Game.toggle_favorite(index):
			fav.refuse())
	row.add_child(fav)

	if not in_showcase:
		var sell := TapButton.new()
		sell.custom_minimum_size = Vector2(SELL_WIDTH, HEIGHT)
		sell.text = "%d" % (0 if fish == null else Economy.sell_price(
			c, fish, Game.ctx.rarity_of(fish), Game.ctx.consumable_bonus))
		sell.tapped.connect(func() -> void: Game.sell_one(index))
		row.add_child(sell)

	return row
