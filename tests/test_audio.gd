extends TestCase

## Geprüft wird das Handwerk, nicht wie es klingt: Pool, Abklingzeit,
## Tonhöhenstreuung, und dass ein fehlender Klang nichts aufhält.

func _quiet() -> void:
	Audio.enabled = true
	Audio._cooldowns.clear()

func test_every_named_sound_exists() -> void:
	_quiet()
	for id in [&"cast", &"bite", &"orb", &"rod", &"catch", &"escape",
			&"coin", &"click", &"error", &"level_up", &"shiny"]:
		assert_true(Audio.stream_for(id) != null, "der Klang %s fehlt" % id)

## Ein fehlender Klang darf nichts aufhalten -- er schweigt einfach.
func test_a_missing_sound_is_silent_not_fatal() -> void:
	_quiet()
	assert_false(Audio.play(&"gibt_es_nicht"), "ein fehlender Klang darf nicht spielen")

## Ohne Abklingzeit uebersteuert sich ein Klang selbst, wenn er in einem
## Bild mehrfach ausgeloest wird.
func test_the_cooldown_blocks_a_repeat() -> void:
	_quiet()
	assert_true(Audio.play(&"orb", 0.5), "der erste muss spielen")
	assert_false(Audio.play(&"orb", 0.5), "der zweite muss geschluckt werden")
	Audio._process(0.6)
	assert_true(Audio.play(&"orb", 0.5), "nach der Sperre wieder")

func test_a_zero_cooldown_allows_rapid_fire() -> void:
	_quiet()
	assert_true(Audio.play(&"orb", 0.0))
	assert_true(Audio.play(&"orb", 0.0), "ohne Sperre muss schnelles Tippen durchkommen")

## Immer dieselbe Tonhöhe nutzt sich ab. Der Test prüft die Streuung, nicht
## einen einzelnen Wert.
func test_the_pitch_varies_between_plays() -> void:
	_quiet()
	var seen: Dictionary = {}
	for i in 20:
		Audio.play(&"click", 0.0)
		seen[snappedf(Audio._voices[(Audio._next - 1 + Audio.VOICES) % Audio.VOICES].pitch_scale, 0.001)] = true
	assert_true(seen.size() > 3, "die Tonhöhe streut nicht: %d verschiedene" % seen.size())
	for p in seen:
		assert_between(float(p), 1.0 - Audio.PITCH_SPREAD - 0.001, 1.0 + Audio.PITCH_SPREAD + 0.001)

## Der Pool wird reihum benutzt, statt pro Klang einen Abspieler anzulegen.
func test_voices_are_reused_in_a_ring() -> void:
	_quiet()
	var before := Audio.get_child_count()
	for i in Audio.VOICES * 3:
		Audio.play(&"click", 0.0)
	assert_eq(Audio.get_child_count(), before, "es wurden Abspieler nachgelegt")

func test_muting_stops_everything() -> void:
	_quiet()
	Audio.enabled = false
	assert_false(Audio.play(&"catch", 0.0), "stumm heißt stumm")
	Audio.enabled = true
