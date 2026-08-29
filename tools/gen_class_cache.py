#!/usr/bin/env python3
"""Erzeugt .godot/global_script_class_cache.cfg aus dem Quellcode.

Normalerweise schreibt der Godot-Editor diese Datei. Auf dem Entwicklungsgerät
(Android/Termux, proot-Debian, Godot-4.7.2-ARM64-Build) stuerzt jeder
Editor-Modus deterministisch ab -- sowohl `--editor` als auch `--headless
--import` enden in `signal 11` in `__libc_free`. Ohne die Datei loest GDScript
keinen einzigen `class_name` auf und jeder `--script`-Lauf bricht mit
"Could not find type" ab.

Reine Entwicklungshilfe: die Datei liegt unter .godot/ und ist gitignored.
In der CI (x86_64) erzeugt Godot sie selbst per `--headless --import`.
"""
import pathlib
import re
import sys

CLASS_RE = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.M)
EXTENDS_RE = re.compile(r"^\s*extends\s+([A-Za-z_]\w*)", re.M)
TOOL_RE = re.compile(r"^\s*@tool\b", re.M)
ABSTRACT_RE = re.compile(r"^\s*@abstract\b", re.M)

SKIP_DIRS = {".godot", ".git", ".superpowers", "build"}


def scan(root: pathlib.Path):
    found = []
    for path in sorted(root.rglob("*.gd")):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        text = path.read_text(encoding="utf-8")
        m = CLASS_RE.search(text)
        if not m:
            continue
        base = EXTENDS_RE.search(text)
        found.append({
            "class": m.group(1),
            "base": base.group(1) if base else "RefCounted",
            "path": "res://" + path.relative_to(root).as_posix(),
            "is_tool": bool(TOOL_RE.search(text)),
            "is_abstract": bool(ABSTRACT_RE.search(text)),
        })
    return sorted(found, key=lambda e: e["class"])


def render(entries) -> str:
    if not entries:
        return "list=Array[Dictionary]([])\n"
    blocks = []
    for e in entries:
        blocks.append(
            '{\n'
            f'"base": &"{e["base"]}",\n'
            f'"class": &"{e["class"]}",\n'
            '"icon": "",\n'
            f'"is_abstract": {str(e["is_abstract"]).lower()},\n'
            f'"is_tool": {str(e["is_tool"]).lower()},\n'
            '"language": &"GDScript",\n'
            f'"path": "{e["path"]}"\n'
            '}'
        )
    return "list=Array[Dictionary]([" + ", ".join(blocks) + "])\n"


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    if not (root / "project.godot").exists():
        print(f"kein Godot-Projekt in {root}", file=sys.stderr)
        return 1
    entries = scan(root)
    out = root / ".godot" / "global_script_class_cache.cfg"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(entries), encoding="utf-8")
    print(f"{len(entries)} Klassen -> {out.relative_to(root)}")
    for e in entries:
        print(f"  {e['class']} extends {e['base']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
