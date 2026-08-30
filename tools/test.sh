#!/usr/bin/env bash
# Laesst die Testsuite laufen und ist NUR gruen, wenn auch kein
# Laufzeitfehler auftrat.
#
# Der Grund: ein Zugriff auf ein Feld, das es nicht mehr gibt, bricht in
# GDScript still die umgebende Funktion ab. Der Test meldet dann "ok",
# obwohl seine Zusicherungen nie liefen. Genau so sind beim Umbau auf
# Lebenspunkte fuenf Tests monatelang ins Leere gelaufen.
set -uo pipefail
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

# Auf dem Geraet laeuft Godot im proot-Debian (tools/godot.sh), in der CI
# direkt. Beides landet hier.
if [ -x "$(dirname "$0")/godot.sh" ] && command -v proot-distro >/dev/null 2>&1; then
	bash "$(dirname "$0")/godot.sh" --script res://tests/run_tests.gd 2>&1 | tee "$OUT"
else
	"${GODOT:-godot}" --headless --script res://tests/run_tests.gd 2>&1 | tee "$OUT"
fi

if grep -qE "^(SCRIPT ERROR|USER SCRIPT ERROR)" "$OUT"; then
	echo
	echo "FEHLGESCHLAGEN: Laufzeitfehler im Testlauf -- betroffene Tests haben nichts geprueft."
	grep -E "^(SCRIPT ERROR|USER SCRIPT ERROR)" "$OUT" | sort -u | head -20
	exit 1
fi
if grep -q "SUITE KAPUTT" "$OUT"; then
	echo
	echo "FEHLGESCHLAGEN: eine Testsuite liess sich nicht laden."
	exit 1
fi
if ! grep -qE "^[0-9]+ Tests, 0 fehlgeschlagen$" "$OUT"; then
	echo
	echo "FEHLGESCHLAGEN: Tests rot oder Zusammenfassung fehlt."
	exit 1
fi
echo "Alles gruen, keine Laufzeitfehler."
