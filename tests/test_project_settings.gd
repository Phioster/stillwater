extends TestCase

## Godots orientation ist ein Enum: 0 Landscape, 1 Portrait, 2 Reverse
## Landscape, 3 Reverse Portrait, 4 Sensor Landscape. Die 1 sah wie
## "Querformat" aus und hat die App im Hochformat gestartet.
func test_orientation_is_a_landscape_variant() -> void:
	var o: int = ProjectSettings.get_setting("display/window/handheld/orientation")
	assert_true(o == 0 or o == 2 or o == 4, "Querformat verlangt 0, 2 oder 4, ist aber %d" % o)

func test_base_resolution_is_landscape() -> void:
	var w: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var h: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_true(w > h, "Basisaufloesung muss breiter als hoch sein: %dx%d" % [w, h])
