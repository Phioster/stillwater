extends TestCase

## Einstellungen müssen sofort wirken und den Neustart überleben. Beides
## wird hier geprüft, nicht das Aussehen der Regler.

func test_applying_settings_reaches_the_audio_and_the_simulation() -> void:
	Game.new_game()
	Game.settings.sound_enabled = false
	Game.settings.volume = 0.25
	Game.settings.ui_volume = 0.1
	Game.settings.auto_fallback_bait = false
	Game.apply_settings()
	assert_false(Audio.enabled)
	assert_almost_eq(Audio.volume, 0.25)
	assert_almost_eq(Audio.ui_volume, 0.1)
	assert_false(Game.ctx.auto_fallback_bait, "die Simulation hat es nicht mitbekommen")
	Game.settings = Settings.new()
	Game.apply_settings()

func test_settings_survive_a_save_and_load() -> void:
	Game.new_game()
	Game.settings.volume = 0.35
	Game.settings.sound_enabled = false
	Game.settings.auto_fallback_bait = false
	var raw := SaveManager.serialize()

	Game.new_game()
	Game.settings = Settings.new()
	SaveManager.deserialize(raw)
	assert_almost_eq(Game.settings.volume, 0.35)
	assert_false(Game.settings.sound_enabled)
	assert_false(Game.settings.auto_fallback_bait)
	Game.settings = Settings.new()
	Game.apply_settings()

## Ein kaputter oder alter Spielstand darf keine unsinnige Lautstärke setzen.
func test_broken_settings_fall_back_to_something_sane() -> void:
	var s := Settings.new()
	s.load_dict({"volume": 9.0, "ui_volume": -3.0, "sound_enabled": "ja",
		"auto_fallback_bait": {"x": 1}})
	assert_between(s.volume, 0.0, 1.0)
	assert_between(s.ui_volume, 0.0, 1.0)
	assert_true(s.sound_enabled, "ein Text ist kein Schalter -- Vorgabe behalten")
	assert_true(s.auto_fallback_bait, "ein Wörterbuch ist kein Schalter")

func test_an_empty_settings_block_keeps_the_defaults() -> void:
	var s := Settings.new()
	var before := s.volume
	s.load_dict({})
	assert_almost_eq(s.volume, before)
	assert_true(s.sound_enabled, "ohne Angabe ist der Ton an")

## Ohne Rückfall hält das Angeln an, wenn der Köder leer ist — das ist der
## Sinn des Schalters.
func test_the_bait_fallback_can_be_switched_off() -> void:
	var basic := BaitData.new()
	basic.id = &"basic"
	basic.unlimited = true
	var fancy := BaitData.new()
	fancy.id = &"fancy"

	var ctx := SimContext.new()
	ctx.fallback_bait = basic
	ctx.bait = fancy
	ctx.bait_counts = {&"fancy": 1}
	ctx.auto_fallback_bait = false
	ctx.consume_bait()
	assert_eq(ctx.bait.id, &"fancy", "ohne Rückfall bleibt der leere Köder liegen")

	ctx.bait = fancy
	ctx.bait_counts = {&"fancy": 1}
	ctx.auto_fallback_bait = true
	ctx.consume_bait()
	assert_eq(ctx.bait.id, &"basic", "mit Rückfall wird umgeschaltet")
