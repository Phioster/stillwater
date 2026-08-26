#!/usr/bin/env bash
# Startet Godot headless im proot-Debian mit dem Projekt aus dem Termux-Home.
set -euo pipefail
PROJECT="${PROJECT:-$HOME/stillwater}"
exec proot-distro login debian --bind "$PROJECT:/work" -- \
  /bin/bash -lc 'export GODOT_SILENCE_ROOT_WARNING=1; cd /work && godot --headless "$@"' -- "$@"
