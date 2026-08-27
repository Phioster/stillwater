extends TestCase

func test_known_colors_exist() -> void:
	assert_true(Palette.COLORS.has(&"water_mid"))
	assert_true(Palette.COLORS.has(&"outline"))

func test_unknown_color_is_magenta() -> void:
	assert_eq(Palette.get_color(&"gibt_es_nicht"), Color.MAGENTA)

func test_palette_has_no_duplicates() -> void:
	var seen := {}
	for name in Palette.COLORS:
		var hex: String = Palette.COLORS[name].to_html(false)
		assert_false(seen.has(hex), "Farbe %s doppelt vergeben (%s)" % [hex, name])
		seen[hex] = name
