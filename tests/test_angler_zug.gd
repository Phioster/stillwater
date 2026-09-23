extends TestCase

## Der Zug im Kampf und das Absetzen danach -- aus vorhandenen Wurfbildern.

func _angler() -> Node2D:
	var a: Node2D = load("res://scenes/fishing/angler.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(a)
	return a

func test_ohne_tipp_zittert_sie_zwischen_neun_und_acht() -> void:
	var a := _angler()
	assert_eq(a.zug_bild(0.0, 0.0), 9, "Ruhelage im Kampf")
	assert_eq(a.zug_bild(0.0, 1.0), 8, "voller Zupfer zieht runter")
	a.free()

func test_ein_tipp_reisst_die_rute_hoch() -> void:
	var a := _angler()
	assert_eq(a.zug_bild(1.0, 0.0), 6)
	assert_eq(a.zug_bild(1.0, 1.0), 6, "oben zittert nichts mehr")
	a.free()

func test_nach_dem_tipp_bleibt_sie_kurz_oben_und_sinkt_dann() -> void:
	var a := _angler()
	a.zug_tipp()
	for i in 10:
		a.zug_schritt(0.02)
	assert_almost_eq(a._zug, 1.0, 0.001, "nach 0,2 s ist sie oben")
	a.zug_schritt(a.ZUG_HALT - 0.2 - 0.01)
	assert_almost_eq(a._zug, 1.0, 0.001, "sie haelt noch")
	for i in 100:
		a.zug_schritt(0.02)
	assert_almost_eq(a._zug, 0.0, 0.001, "ohne weiteren Tipp sinkt sie zurueck")
	a.free()

func test_absetzen_endet_in_der_ruhehaltung() -> void:
	var a := _angler()
	a.zug_tipp()
	a.zug_schritt(1.0)
	a.absetzen_beginnen()
	var t := 0.0
	while t < a.absetz_dauer():
		a.absetz_schritt(0.02)
		t += 0.02
	a.absetz_schritt(0.02)
	assert_eq(a._arm, 1, "Wurfbild 0 = Ruhehaltung")
	a.free()

## Das Absetzen muss vor dem Ausholen fertig sein, bei Fang wie bei Flucht --
## sonst springt die Figur vom Zug direkt in den Schwung.
func test_absetzen_passt_in_die_pause() -> void:
	var a := _angler()
	var dauer: float = a.ZUG_HALT + a.ZUG_RUNTER + a.RUHE_ZEIT
	assert_true(dauer <= FishingSim.LAND_PAUSE + 0.0001, "Fang: %f > %f" % [dauer, FishingSim.LAND_PAUSE])
	assert_true(dauer <= FishingSim.ESCAPE_COOLDOWN - FishingSim.CAST_TIME + 0.0001, "Flucht")
	a.free()

## Jede Zwischenstellung auf dem Weg braucht ein gebackenes Blatt.
func test_jede_zwischenstellung_hat_ein_blatt() -> void:
	var a := _angler()
	for weg in [a.ZUG_WEG, a.ABSETZ_WEG]:
		for s in 61:
			var p := float(s) / 60.0 * float(weg.size() - 1)
			var w: Vector3i = a.weg_werte(weg, p)
			for i in AnglerParts.BREATH_STEPS:
				var b: Vector2i = a.breath_at(float(i) / float(AnglerParts.BREATH_STEPS))
				assert_true(AnglerParts.zopf_index(b.x, b.y + w.x, w.y) >= 0,
					"%s bei %f: Zopf %d/%d/%d fehlt" % [weg, p, b.x, b.y + w.x, w.y])
				assert_true(AnglerParts.LEG_SPREADS.has(w.z), "Bein %d" % w.z)
	a.free()

## Die Rute zieht auch ohne Tipp -- jeder Rutenschub hebt sie halb, auf 7.
## Ein Tipp bleibt der staerkere Zug.
func test_ein_rutenschub_hebt_nur_halb() -> void:
	var a := _angler()
	a.rute_zug()
	for i in 10:
		a.zug_schritt(0.01)
	assert_almost_eq(a._zug, a.RUTE_ZUG, 0.001)
	assert_eq(a.zug_bild(a._zug, 0.0), 7)
	for i in 100:
		a.zug_schritt(0.01)
	assert_almost_eq(a._zug, 0.0, 0.001, "danach wieder runter ins Zittern")
	a.free()

func test_ein_rutenschub_bremst_keinen_tipp() -> void:
	var a := _angler()
	a.zug_tipp()
	a.rute_zug()
	for i in 20:
		a.zug_schritt(0.01)
	assert_almost_eq(a._zug, 1.0, 0.001)
	a.free()
