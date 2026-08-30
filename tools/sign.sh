#!/usr/bin/env bash
# Signiert eine gebaute APK mit dem festen Schluessel und installiert sie.
#
# Der Schluessel liegt AUSSCHLIESSLICH auf diesem Geraet, in
# ~/.stillwater-release/. Er geht weder ins Repo noch zu GitHub: die CI
# signiert nur mit einem Wegwerf-Schluessel, damit ihre APK ueberhaupt
# installierbar waere, und hier wird sie nachsigniert.
#
# Dadurch traegt jede Installation dieselbe Signatur, und `adb install -r`
# genuegt -- ohne Deinstallation, ohne Spielstandverlust.
set -euo pipefail

KEYDIR="${STILLWATER_KEYDIR:-$HOME/.stillwater-release}"
KEYSTORE="$KEYDIR/stillwater.keystore"
PWFILE="$KEYDIR/password.txt"
ALIAS="${STILLWATER_ALIAS:-stillwater}"

APK="${1:?Aufruf: tools/sign.sh <apk> [--install]}"
[ -f "$KEYSTORE" ] || { echo "Kein Schluessel in $KEYDIR -- siehe TODO.md"; exit 1; }
[ -f "$PWFILE" ] || { echo "Kein Passwort in $PWFILE"; exit 1; }

PW="$(cat "$PWFILE")"
OUT="${APK%.apk}-signiert.apk"

# apksigner ersetzt vorhandene Signaturen. v1 allein reicht Android 11+ nicht,
# deshalb v2 und v3 mit.
apksigner sign \
	--ks "$KEYSTORE" --ks-key-alias "$ALIAS" \
	--ks-pass "pass:$PW" --key-pass "pass:$PW" \
	--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
	--out "$OUT" "$APK"

apksigner verify --print-certs "$OUT" | grep -i "SHA-256 digest" | head -1
echo "signiert: $OUT"

if [ "${2:-}" = "--install" ]; then
	adb install -r "$OUT"
fi
