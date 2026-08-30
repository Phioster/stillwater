#!/usr/bin/env bash
# Spielstaende auf dem Geraet umschalten, ohne etwas zu verlieren.
#
#   tools/save.sh sichern          # aktuellen Stand nach ~/stillwater-saves/
#   tools/save.sh dev              # Entwicklerstand aufspielen (sichert vorher)
#   tools/save.sh zurueck          # letzte Sicherung zurueckspielen
#   tools/save.sh liste            # vorhandene Sicherungen
#
# Der Umweg ueber /data/local/tmp und `run-as` ist noetig, weil adb nicht
# direkt in das private Verzeichnis der App schreiben darf.
set -euo pipefail
PKG=org.phioster.stillwater
STORE="$HOME/stillwater-saves"
mkdir -p "$STORE"

pull() {
	adb shell "run-as $PKG cat files/save.json" > "$1" 2>/dev/null || true
	[ -s "$1" ] || { echo "kein Spielstand auf dem Geraet"; rm -f "$1"; return 1; }
}
push() {
	adb push "$1" /data/local/tmp/sw_save.json >/dev/null
	adb shell "run-as $PKG sh -c 'mkdir -p files && cp /data/local/tmp/sw_save.json files/save.json && chmod 600 files/save.json'"
	adb shell rm /data/local/tmp/sw_save.json
}

case "${1:-}" in
sichern)
	F="$STORE/save-$(date +%Y%m%d-%H%M%S).json"
	pull "$F" && echo "gesichert: $F"
	;;
dev)
	DEV="${2:-$STORE/dev_save.json}"
	[ -f "$DEV" ] || { echo "kein Entwicklerstand unter $DEV"; exit 1; }
	F="$STORE/save-vor-dev-$(date +%Y%m%d-%H%M%S).json"
	pull "$F" && echo "vorher gesichert: $F" || echo "(nichts zu sichern)"
	push "$DEV"
	echo "Entwicklerstand aufgespielt. Zurueck mit: tools/save.sh zurueck"
	;;
zurueck)
	LAST="$(ls -1t "$STORE"/save-*.json 2>/dev/null | head -1)"
	[ -n "$LAST" ] || { echo "keine Sicherung vorhanden"; exit 1; }
	push "$LAST"
	echo "zurueckgespielt: $LAST"
	;;
liste)
	ls -1t "$STORE"/*.json 2>/dev/null || echo "keine Sicherungen"
	;;
*)
	echo "Aufruf: tools/save.sh {sichern|dev|zurueck|liste}"
	exit 1
	;;
esac
