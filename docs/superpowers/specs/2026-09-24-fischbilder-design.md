# Fischbilder

**Stand 2026-09-24.** Mit dem Nutzer abgestimmt. Letztes großes
Pixelart-Teilprojekt vor den Accessoires.

## Warum

Alle 107 Arten sind heute dieselbe Grundform in 32×16, nur umgefärbt
(`tools/gen_sprites.gd::_fish_sprite`). Im Journal sieht jeder Fisch gleich aus.

## Entscheidungen

- **Jede Art ein eigenes PixelLab-Bild**, `create_image_pixflux`, **48×24**
  (Nutzer), `no_background`, `view="side"`, `direction="west"` — Kopf links,
  denn `world.gd` hängt den Fisch am Maul auf (um 90° gedreht, links = oben).
- **Echte Fische naturgetreu**, **erfundene verspielt und „etwas crazy“**
  (Nutzer). Die Beschreibung je Art steht in `tools/fische_bauen.py::FISCHE`.
- Eine gemeinsame Palette **je Zone** (`reduce_colors`, bis 8 Bilder je
  Aufruf) — die Zonen dürfen sich im Farbton unterscheiden, eine Zone nicht.
- Rohbilder nach `assets/source/fische/<id>.png`; `tools/fische_bauen.py`
  kopiert nach `assets/art/fish_<id>.png` und rechnet `fish_<id>_silhouette.png`
  (jedes sichtbare Pixel in einem Ton) — keine zweite Generation dafür.
- **Probelauf: Willow Lake (16 Arten)**, Abnahme auf der Vorschauseite, erst
  danach die übrigen sechs Zonen.
- Anzeigen, die heute 32×16 annehmen (`fish_window.gd` `ICON_SCALE`,
  Journal, Geheimreiter, Haken `HOOK_FISH_SCALE`), rechnen danach mit 48×24;
  `test_sprite_assets.gd` erwartet 48×24.

## Nicht Teil davon

- Animierte Fische, Rang- oder Größenvarianten derselben Art.
