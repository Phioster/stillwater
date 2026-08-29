extends TestCase

# Absichtlicher Parse-Fehler fuer den Testrunner-Wächter (Task 3c):
# NichtVorhandeneKlasse existiert nirgends im Projekt. Kein class_name,
# damit tools/gen_class_cache.py diese Datei ignoriert.

func test_placeholder() -> void:
	var x = NichtVorhandeneKlasse.new()
	assert_eq(x, x)
