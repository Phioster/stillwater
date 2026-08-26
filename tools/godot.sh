#!/usr/bin/env bash
# Startet Godot headless im proot-Debian mit dem Projekt aus dem Termux-Home.
#
# Erzeugt vorher den Script-Class-Cache neu. Das uebernimmt sonst der Godot-
# Editor, der auf diesem Geraet aber deterministisch abstuerzt (siehe
# tools/gen_class_cache.py). Ohne den Cache loest kein `class_name` auf.
set -euo pipefail
PROJECT="${PROJECT:-$HOME/stillwater}"
python3 "$PROJECT/tools/gen_class_cache.py" "$PROJECT" >/dev/null
exec proot-distro login debian --bind "$PROJECT:/work" -- \
  /bin/bash -lc 'export GODOT_SILENCE_ROOT_WARNING=1; cd /work && godot --headless "$@"' -- "$@"
