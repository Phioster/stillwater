# Stillwater — TODO

Nach Nähe geordnet. Was hier nicht steht und auch nicht in
`GAME_DESIGN.md` als bewusste Abweichung genannt ist, wurde schlicht
noch nicht gebaut.

## Als Nächstes

- **Audio** — Wasser, Wurf, Biss, Fang, Verkauf, Upgrade, Level-Up, UI.
  Dafür entsteht dann auch der vierte Autoload `AudioManager` (siehe
  `ARCHITECTURE.md`), der in Slice 1 bewusst fehlt.
- **Echte Hintergrundgrafik für Sunset Coast.** Die Zone nutzt aktuell
  denselben Hintergrund wie Willow Lake (siehe `GAME_DESIGN.md`).
- **Fisch-Level über Mini-Quests.** `fish_level` wird bereits
  gespeichert, angezeigt und fließt in die Shiny-Formel ein, wird in
  Slice 1 aber nie erhöht.

## Danach

- Quest-System mit erneuerbaren Aufgaben.
- Consumables — **über Anzahl Fänge statt Echtzeit** („nächste 50
  Fänge" statt „nächste 15 Minuten"). Ein zeitbasierter Buff auf einem
  Handy verpufft, während der Spieler weg ist.
- Ein einziger Rückkehr-Rhythmus statt mehrerer Echtzeituhren (nicht
  drei parallele Timer wie im Referenzspiel).
- Raritäten Epic und Legendary (in der Spec bereits mit Werten
  hinterlegt, in Slice 1 aber ungenutzt).
- Weitere Zonen.

## Bedingungstypen für Secret-Fische

Slice 1 kennt `BaitCondition` und `LevelCondition`. Vorgesehen und noch
nicht gebaut:

- Aussehen (Cosmetics)
- Tageszeit
- Fänge in dieser Zone
- Journal-Fortschritt
- aktiver Trank

## Inhalte

- Willow Lake auf 12 bis 18 Arten ausbauen (aktuell 5 regulär + 1
  Secret), davon späte Epic- und Legendary-Fische, die erst mit
  späten Ködern anbeißen — sonst wird die Startzone zu totem Inhalt,
  sobald Sunset Coast freigeschaltet ist.

## Technik

- Lokalisierung über Godots eingebaute CSV-Übersetzungen. Anzeigenamen
  sind aktuell fest Deutsch im Code/in den `.tres`.
- Release-Keystore über GitHub-Secrets. `build.yml` erzeugt aktuell nur
  einen Debug-Keystore zur Laufzeit (siehe unten, "Bekannte Punkte").
- Statistiken.
- Einstellungen.

## Bekannte Punkte (geparkt, keine Bugs)

- **`SaveManager._defaults()` dupliziert die Standardwerte aus
  `Game.new_game()`.** Beide Stellen listen z. B. `coins: 0`,
  `unlocked_zones: ["willow_lake"]` und die Upgrade-Startwerte separat.
  Ändert sich ein Startwert, muss er an beiden Stellen gepflegt werden.
  Bekannt, noch nicht zusammengeführt.
- **Der Fisch-Farb-Hash im Sprite-Generator ist über Godot-Versionen
  nicht stabil.** `tools/gen_sprites.gd` leitet die Farbe jeder Art
  deterministisch aus `String(fish.id).hash()` ab — Godots
  `String.hash()` ist keine über Engine-Versionen garantiert stabile
  Funktion. Unkritisch, weil die erzeugten PNGs unter `assets/art/`
  committet sind und zur Laufzeit nie neu erzeugt werden; ein
  `gen_sprites.gd`-Lauf unter einer anderen Godot-Version könnte aber
  andere Fischfarben liefern als die bereits committeten Bilder.
