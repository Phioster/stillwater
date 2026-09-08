# Varianten als Tönung — Umsetzungsplan (Stufe 4)

> **Für agentische Bearbeiter:** ERFORDERLICHE UNTERFÄHIGKEIT: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, Aufgabe für Aufgabe. Die Schritte tragen Kästchen (`- [ ]`).

**Ziel:** Haut, Pullover und Hose bekommen ihre Farbwahl zurück — durch Tönung zur Laufzeit statt durch gebackene Blätter je Variante.

**Aufbau:** `scenes/fishing/angler.gd` bekommt eine Tabelle Kategorie → Palettentöne und färbt die zugehörige Kosmetikebene aller Teile mit `palette_swap.gdshader` ein. Das ist derselbe Weg, den die Haarfarbe schon geht; er wird nur von einer Kategorie auf vier verallgemeinert.

**Werkzeuge:** Godot 4.7.2, GDScript.

**Spec:** `docs/superpowers/specs/2026-09-07-figur-aus-teilen-im-spiel-design.md`

## Weltweite Vorgaben

- Godot **4.7.2**, Python-Bildwerkzeuge mit **Pillow 12.3.0** und **numpy 2.4.4**.
- **`bash tools/test.sh` läuft vollständig durch, bevor committet oder gepusht wird.**
- **Gemessen, nicht getippt.** Die Töne stehen bereits in `core/palette.gd`; sie werden dort nachgeschlagen, nicht als Hexwerte wiederholt.
- Kommentare auf Deutsch, ohne Umlaute im Code. Commit-Nachrichten ohne Zuschreibungszeilen.

---

## Ausgangslage

Stufe 3 ist auf `master` (`f0cae5e`). Die Figur kommt aus Teileblättern; jedes Teil hat je Kosmetikebene ein Sprite. `angler.gd::_tint_hair()` färbt bereits alle `hair`-Ebenen ein — für die acht Haarfarben. Haut, Pullover und Hose hatten je Variante ein gebackenes Blatt; die sind in Stufe 3 gelöscht worden, und ihre Varianten wirken seither **nicht sichtbar**. Genau das behebt dieser Plan.

### Drei Befunde aus der Vorarbeit (2026-09-08)

**1. Die Töne stehen schon in der Palette.** Der Entwurf sagt, `SKIN_TONES`, `SHIRT_TONES` und `PANTS_TONES` müssten aus dem Bauwerkzeug in die Palette wandern. Nachgeschlagen: **jeder einzelne Ton hat dort schon einen Namen.** Es ist nichts zu ergänzen, nur nachzuschlagen:

| Kategorie | Varianten | Töne (Variante 0 wird nie getönt) |
|---|---|---|
| `skin` | 9 | —, `skin_2`, `skin_3`, `skin_0`, `skin_4`, `skin_moss`, `skin_ice`, `skin_ash`, `skin_white` |
| `shirt` | 9 | —, `cloth_red`, `cloth_green`, `cloth_ochre`, `cloth_plum`, `cloth_grey`, `leather`, `oilskin`, `denim` |
| `pants` | 6 | —, `wood_dark`, `oilskin`, `cloth_plum`, `denim`, `cloth_red` |
| `hair_color` | 8 | `hair_dark`, `hair_warm`, `hair_pale`, `hair_moss`, `hair_snow`, `hair_teal`, `hair_violet`, `hair_pink` |

Die Haarfarbe ist die Ausnahme: sie hat **keine** ungetönte Variante — es gibt keine „gezeichnete Haarfarbe", die man behalten wollte.

**2. Der Shader ist genau die Formel, die die Blätter gebacken hat.** Nachgerechnet gegen die gelöschten Blätter aus der Geschichte (`f0cae5e~1`):

```
skin  Variante 3   11315 Pixel gleich, 0 daneben
skin  Variante 8   11315 Pixel gleich, 0 daneben
shirt Variante 1   20017 Pixel gleich, 0 daneben
pants Variante 4    8069 gleich, 11157 daneben
```

Bei Haut und Pullover **kein einziger Unterschied**. Bei der Hose weichen genau die Stiefel ab: `import_character.py` kopierte sie ungetönt über die gefärbte Hose. Sie sind jetzt eine eigene Ebene und bleiben damit von selbst außen vor.

(Die Rechnung muss abschneiden, nicht runden — mit `round()` weichen die Werte um bis zu eins je Kanal ab. Die Grafikkarte rundet; der Unterschied ist ein 255stel und unsichtbar.)

**3. Variante 0 darf keine Tönung bekommen.** Sie ist die gezeichnete Farbe. Durch den Shader geschickt käme sie um bis zu einen Wert je Kanal verschoben heraus — unnötig, und es macht aus einem „unberührt" ein „fast unberührt".

---

## Dateien

| Datei | Zuständig für |
|---|---|
| `scenes/fishing/angler.gd` | **ändern**: `HAIR_TINTS` und `_tint_hair()` weichen der Tabelle `TINTS` und `_tint()`, die vier Kategorien bedient |
| `tests/test_cosmetics.gd` | **ändern**: `test_every_hair_colour_has_a_tint` wird auf alle vier Kategorien verallgemeinert, dazu drei neue Zusicherungen |
| `docs/superpowers/specs/2026-09-07-figur-aus-teilen-im-spiel-design.md` | **ändern**: die Befunde festhalten |

---

## Aufgabe 1: Die Tönung je Kosmetikebene

**Dateien:**
- Ändern: `scenes/fishing/angler.gd`
- Ändern: `tests/test_cosmetics.gd`

**Schnittstellen:**
- Nutzt: `AnglerParts.ORDER`, `AnglerParts.LAYERS`, `Palette.get_color()`, `Palette.COLORS`
- Liefert:
  - `Angler.TINTS: Dictionary` — `StringName` (Kosmetikkategorie) → `Array[StringName]` (Palettennamen je Variante, `&""` heißt ungetönt)
  - `Angler.TINT_LAYER: Dictionary` — Kategorie → Kosmetikebene, die sie einfärbt
  - `Angler._tint(category: StringName, index: int) -> void`
  - `Angler.HAIR_TINTS` entfällt

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

In `tests/test_cosmetics.gd` `test_every_hair_colour_has_a_tint` samt Kommentar ersetzen durch:

```gdscript
## Haut, Pullover, Hose und Haarfarbe haben kein eigenes Sprite je Variante:
## sie faerben eine Ebene der Teileblaetter ein. Gibt es mehr Varianten als
## Toene, waehlt man stumm dieselbe -- und niemand merkt es.
func test_jede_variante_hat_einen_ton() -> void:
	var angler = load("res://scenes/fishing/angler.tscn").instantiate()
	for kategorie in angler.TINTS:
		var vorhanden := 0
		for id in Database.cosmetics:
			if (Database.cosmetics[id] as CosmeticData).category == kategorie:
				vorhanden += 1
		var toene: Array = angler.TINTS[kategorie]
		assert_eq(vorhanden, toene.size(),
			"%s: %d Varianten, aber %d Toene" % [kategorie, vorhanden, toene.size()])
	angler.free()

## Palette.get_color() gibt bei einem unbekannten Namen Magenta zurueck und
## meldet nichts. Ein Tippfehler in der Tabelle waere also eine grellrosa
## Anglerin und kein Fehler.
func test_jeder_ton_steht_in_der_palette() -> void:
	var angler = load("res://scenes/fishing/angler.tscn").instantiate()
	for kategorie in angler.TINTS:
		for name in angler.TINTS[kategorie]:
			if name == &"":
				continue
			assert_true(Palette.COLORS.has(name),
				"%s: den Ton %s kennt die Palette nicht" % [kategorie, name])
	angler.free()

## Variante 0 ist die GEZEICHNETE Farbe. Durch den Shader geschickt kaeme sie
## um bis zu einen Wert je Kanal verschoben heraus -- unsichtbar, aber es
## macht aus "unberuehrt" ein "fast unberuehrt".
func test_variante_null_wird_nicht_getoent() -> void:
	var angler = load("res://scenes/fishing/angler.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(angler)
	angler.set_cosmetics({"skin": 0, "shirt": 0, "pants": 0, "hair_color": 0,
		"hat": 0, "rod": 0})
	assert_true((angler.get_node("rumpf/skin") as Sprite2D).material == null,
		"die gezeichnete Haut wird getoent")
	assert_true((angler.get_node("rumpf/shirt") as Sprite2D).material == null,
		"der gezeichnete Pullover wird getoent")
	assert_true((angler.get_node("rumpf/pants") as Sprite2D).material == null,
		"der gezeichnete Rock wird getoent")
	## Die Haarfarbe ist die Ausnahme: sie hat keine ungetoente Variante.
	assert_true((angler.get_node("kopf/hair") as Sprite2D).material != null,
		"die Haarfarbe 0 muesste toenen")
	angler.free()

## Die Stiefel sind eine eigene Ebene und gehen die Hose nichts an -- im alten
## Backweg lagen sie ungetoent ueber der gefaerbten Hose. Die Grundebene traegt
## Umriss, Auge und Kragen und wird nie umgefaerbt.
func test_stiefel_und_grundebene_bleiben_ungetoent() -> void:
	var angler = load("res://scenes/fishing/angler.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(angler)
	angler.set_cosmetics({"skin": 3, "shirt": 5, "pants": 2, "hair_color": 4,
		"hat": 0, "rod": 0})
	assert_true((angler.get_node("beine/boots") as Sprite2D).material == null,
		"die Stiefel werden mit der Hose getoent")
	for teil in AnglerParts.ORDER:
		assert_true((angler.get_node(NodePath("%s/base" % teil)) as Sprite2D).material == null,
			"%s/base wird getoent" % teil)
	angler.free()

## Und die gewaehlte Farbe muss auch ankommen -- an JEDEM Teil, das die Ebene
## hat. Der Pullover liegt in Rumpf, Arm und fernem Arm; faerbte man nur den
## Rumpf, traege sie zwei verschiedene Aermel.
func test_der_gewaehlte_ton_liegt_auf_allen_teilen() -> void:
	var angler = load("res://scenes/fishing/angler.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(angler)
	angler.set_cosmetics({"skin": 0, "shirt": 5, "pants": 0, "hair_color": 0,
		"hat": 0, "rod": 0})
	var erwartet := Palette.get_color(angler.TINTS[&"shirt"][5])
	var geprueft := 0
	for teil in AnglerParts.ORDER:
		if not (AnglerParts.LAYERS[teil] as Array).has(&"shirt"):
			continue
		var s: Sprite2D = angler.get_node(NodePath("%s/shirt" % teil))
		assert_true(s.material != null, "%s/shirt ist ungetoent" % teil)
		if s.material == null:
			continue
		geprueft += 1
		assert_eq((s.material as ShaderMaterial).get_shader_parameter("tint"),
			erwartet, "%s/shirt traegt einen anderen Ton" % teil)
	assert_true(geprueft >= 3, "nur %d Pulloverebenen gefunden" % geprueft)
	angler.free()
```

- [ ] **Schritt 2: Tests laufen lassen, Fehlschlag bestätigen**

```
bash tools/test.sh
```

Erwartet: rot mit „Invalid access to property or key 'TINTS'".

- [ ] **Schritt 3: Die Tönung schreiben**

In `scenes/fishing/angler.gd` den Block `HAIR_TINTS` ersetzen:

```gdscript
## Welche Kosmetikkategorie welche Toene hat, als Namen aus core/palette.gd --
## die Hexwerte stehen dort und nicht hier zweimal.
##
## Der leere Name heisst: NICHT toenen. Variante 0 ist bei Haut, Pullover und
## Hose die gezeichnete Farbe; durch den Shader geschickt kaeme sie um bis zu
## einen Wert je Kanal verschoben heraus.
##
## Die Haarfarbe kennt diese Ausnahme nicht: es gibt keine "gezeichnete
## Haarfarbe", die man behalten wollte, also toent auch Variante 0.
##
## Die Reihenfolge IST die Variantennummer der Kategorie. Eine Variante mehr
## in data/cosmetics/ verlangt einen Ton mehr hier, sonst waehlt man stumm
## dieselbe Farbe -- dagegen steht test_jede_variante_hat_einen_ton.
const TINTS := {
	&"skin": [&"", &"skin_2", &"skin_3", &"skin_0", &"skin_4", &"skin_moss",
		&"skin_ice", &"skin_ash", &"skin_white"],
	&"shirt": [&"", &"cloth_red", &"cloth_green", &"cloth_ochre", &"cloth_plum",
		&"cloth_grey", &"leather", &"oilskin", &"denim"],
	&"pants": [&"", &"wood_dark", &"oilskin", &"cloth_plum", &"denim",
		&"cloth_red"],
	&"hair_color": [&"hair_dark", &"hair_warm", &"hair_pale", &"hair_moss",
		&"hair_snow", &"hair_teal", &"hair_violet", &"hair_pink"],
}

## Welche Ebene der Teileblaetter eine Kategorie einfaerbt. Die Stiefel haben
## eine eigene Ebene und gehen die Hose nichts an; die Grundebene traegt
## Umriss, Auge und Kragen und wird nie umgefaerbt.
const TINT_LAYER := {
	&"skin": &"skin",
	&"shirt": &"shirt",
	&"pants": &"pants",
	&"hair_color": &"hair",
}
```

`_tint_hair()` durch `_tint()` ersetzen:

```gdscript
## Eine Kosmetikebene einfaerben -- an JEDEM Teil, das sie hat. Der Pullover
## liegt in Rumpf, Arm und fernem Arm; faerbte man nur den Rumpf, traege sie
## zwei verschiedene Aermel.
##
## Der Shader behaelt die Helligkeit und ersetzt den Farbton
## (assets/art/palette_swap.gdshader). Nachgerechnet gegen die frueher
## gebackenen Blaetter: bei Haut und Pullover kein einziger Pixel Unterschied.
func _tint(category: StringName, index: int) -> void:
	var toene: Array = TINTS[category]
	var name: StringName = toene[clampi(index, 0, toene.size() - 1)]
	var mat: ShaderMaterial = null
	if name != &"":
		mat = ShaderMaterial.new()
		mat.shader = load("res://assets/art/palette_swap.gdshader")
		mat.set_shader_parameter("tint", Palette.get_color(name))
		mat.set_shader_parameter("strength", 1.0)
	var ebene: StringName = TINT_LAYER[category]
	for teil in AnglerParts.ORDER:
		if not (AnglerParts.LAYERS[teil] as Array).has(ebene):
			continue
		(get_node(NodePath("%s/%s" % [teil, ebene])) as Sprite2D).material = mat
```

Und in `set_cosmetics()` die Zeile `_tint_hair(int(c.get("hair_color", 0)))` ersetzen:

```gdscript
	for kategorie in TINTS:
		_tint(kategorie, int(c.get(String(kategorie), 0)))
```

- [ ] **Schritt 4: Tests laufen lassen, Erfolg bestätigen**

```
bash tools/test.sh
```

Erwartet: alles grün. Schlägt `test_jede_variante_hat_einen_ton` fehl, ist eine Tonliste zu kurz oder zu lang — die Zahl in der Meldung ist die aus `data/cosmetics/`, und die gilt.

- [ ] **Schritt 5: Ansehen**

Ein Bild mit mehreren Kombinationen erzeugen und **dem Menschen vorlegen**. Die Tönung wird dabei so gerechnet wie im Shader — abschneiden, nicht runden:

```bash
python3 - <<'ENDE'
import re
from PIL import Image, ImageDraw
from tools import figure_parts as fp
from tools import teile_bauen as tb
from tools.character_keys import load_table
from tools.character_layers import PARTS

pal = {m.group(1): m.group(2) for m in re.finditer(
    r'&"(\w+)":\s*Color\("([0-9a-fA-F]{6})"\)',
    open("core/palette.gd", encoding="utf-8").read())}
ang = open("scenes/fishing/angler.gd", encoding="utf-8").read()

def liste(kat):
    block = re.search(r'&"%s": \[(.*?)\],\n' % kat, ang, re.S).group(1)
    return [n for n in re.findall(r'&"(\w*)"', block)]

def ton(name):
    h = pal[name]
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def faerben(bild, name):
    if not name:
        return bild
    z = ton(name)
    aus = bild.copy(); px = aus.load()
    for y in range(aus.size[1]):
        for x in range(aus.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            k = 0.55 + 0.9 * (0.299*r + 0.587*g + 0.114*b) / 255.0
            px[x, y] = (min(255, int(z[0]*k)), min(255, int(z[1]*k)),
                        min(255, int(z[2]*k)), a)
    return aus

ebenen = fp.split(Image.open("assets/source/figure/parts/sit3_rumpf.png").convert("RGBA"))
koepfe = {s: fp.eye_state(ebenen["head"], s) for s in ("open", "half", "closed")}
tabelle = load_table("assets/source/figure/key_palette.json")
zust = tb.zustaende(ebenen, koepfe)
kaesten = {n: tb.rahmen(b) for n, b in zust.items()}
blaetter = {(n, e): tb.blatt(zust[n], kaesten[n], tabelle, e)
            for n in zust for e in PARTS}
TON = {"skin": liste("skin"), "shirt": liste("shirt"),
       "pants": liste("pants"), "hair": liste("hair_color")}

def figur(haut, pulli, hose, haar):
    wahl = {"skin": haut, "shirt": pulli, "pants": hose, "hair": haar}
    aus = Image.new("RGBA", (fp.FRAME, fp.FRAME), (0, 0, 0, 0))
    for name in tb.ZEICHENFOLGE:
        x, y, w, h = kaesten[name]
        i = tb._index(name, (0, 0, 0), 0, "open", 0)
        for e in PARTS:
            teil = blaetter[(name, e)].crop((i*w, 0, (i+1)*w, h))
            if e in wahl:
                teil = faerben(teil, TON[e][wahl[e]])
            aus.alpha_composite(teil, (x, y))
    return aus

proben = [(0,0,0,0), (2,1,1,0), (5,8,4,5), (7,6,3,4), (8,2,5,7)]
X, Y, K, H, S = 30, 0, 74, 124, 4
bild = Image.new("RGBA", (K*S*len(proben), H*S+26), (18, 21, 26, 255))
d = ImageDraw.Draw(bild)
for i, p in enumerate(proben):
    b = figur(*p).crop((X, Y, X+K, Y+H))
    unten = Image.new("RGBA", b.size, (24, 28, 34, 255)); unten.alpha_composite(b)
    bild.alpha_composite(unten.resize((K*S, H*S), Image.NEAREST), (i*K*S, 26))
    d.text((i*K*S+5, 8), "H%d P%d R%d Haar%d" % p, fill=(235, 235, 225))
bild.convert("RGB").save("/tmp/varianten.png")
print("geschrieben")
ENDE
```

- [ ] **Schritt 6: Commit**

```bash
git add scenes/fishing/angler.gd tests/test_cosmetics.gd
git commit -m "Haut, Pullover und Hose werden getoent statt gebacken"
```

---

## Aufgabe 2: Die Gegenprobe festhalten

Der Entwurf sagt, die Töne müssten in die Palette wandern — sie stehen längst dort. Und dass die Tönung dasselbe Bild ergibt wie die gebackenen Blätter, ist gemessen, aber nirgends aufgeschrieben. Beides gehört in die Spec, sonst rechnet es beim nächsten Mal jemand neu.

**Dateien:**
- Ändern: `docs/superpowers/specs/2026-09-07-figur-aus-teilen-im-spiel-design.md`

**Schnittstellen:**
- Nutzt: nichts. Reine Aufschrift.
- Liefert: nichts, worauf Code zugreift.

- [ ] **Schritt 1: Die Gegenprobe noch einmal fahren**

Damit die Zahlen im Dokument gemessen sind und nicht abgeschrieben:

```bash
python3 - <<'ENDE'
import subprocess, io
from PIL import Image
def aus_git(p):
    return Image.open(io.BytesIO(subprocess.run(
        ["git", "show", "f0cae5e~1:" + p],
        capture_output=True).stdout)).convert("RGBA")
def toenen(rgb, ton):
    k = 0.55 + 0.9 * (0.299*rgb[0] + 0.587*rgb[1] + 0.114*rgb[2]) / 255.0
    return tuple(min(255, int(t * k)) for t in ton)
faelle = [("skin", 3, (0xf6, 0xdd, 0xc4)), ("skin", 8, (0xf4, 0xf6, 0xf7)),
          ("shirt", 1, (0xb4, 0x52, 0x3f)), ("pants", 4, (0x39, 0x53, 0x7f))]
for art, v, ton in faelle:
    n = aus_git("assets/art/char_%s_0.png" % art).load()
    d = aus_git("assets/art/char_%s_%d.png" % (art, v)).load()
    gleich = daneben = 0
    for y in range(128):
        for x in range(3072):
            if n[x, y][3] == 0:
                continue
            if toenen(n[x, y][:3], ton) == d[x, y][:3]:
                gleich += 1
            else:
                daneben += 1
    print("%-6s Variante %d  gleich %5d  daneben %5d" % (art, v, gleich, daneben))
ENDE
```

Erwartet (am 2026-09-08 gemessen): `skin 3` und `skin 8` je 11315/0, `shirt 1` 20017/0, `pants 4` 8069/11157 — bei der Hose sind die 11157 die Stiefel.

- [ ] **Schritt 2: Die Spec nachziehen**

Im Abschnitt „Kosmetik als Tönung" (oder, falls es ihn nicht gibt, hinter „Die Blätter") einfügen:

```markdown
## Kosmetik als Tönung

Haut, Pullover, Hose und Haarfarbe haben kein eigenes Bild je Variante: sie
färben eine Ebene der Teileblätter mit `assets/art/palette_swap.gdshader` ein.
Die Töne stehen als Namen in `core/palette.gd`, die Zuordnung Kategorie → Töne
in `scenes/fishing/angler.gd::TINTS`.

**Variante 0 wird bei Haut, Pullover und Hose nicht getönt** — sie ist die
gezeichnete Farbe. Die Haarfarbe kennt diese Ausnahme nicht.

**Die Stiefel bleiben außen vor.** Sie sind eine eigene Ebene. Im alten
Backweg kopierte `import_character.py` sie ungetönt über die gefärbte Hose;
jetzt ergibt sich dasselbe von selbst.

**Nachgerechnet gegen die gebackenen Blätter** (2026-09-08, gegen
`f0cae5e~1`): der Shader rechnet `Ton · (0,55 + 0,9 · Helligkeit)` — genau die
Formel, mit der die Blätter entstanden sind.

| | Pixel gleich | daneben |
|---|---|---|
| `skin` Variante 3 | 11 315 | 0 |
| `skin` Variante 8 | 11 315 | 0 |
| `shirt` Variante 1 | 20 017 | 0 |
| `pants` Variante 4 | 8 069 | 11 157 (die Stiefel) |

Die Rechnung muss abschneiden, nicht runden; mit `round()` weichen die Werte
um bis zu eins je Kanal ab. Die Grafikkarte rundet — ein 255stel, unsichtbar.
```

Und im Abschnitt „Die Blätter" den Satz über die Tonlisten berichtigen: sie
mussten nicht in die Palette wandern, sie standen schon dort.

- [ ] **Schritt 3: Ganze Suite**

```
bash tools/test.sh
```

- [ ] **Schritt 4: Commit**

```bash
git add docs/superpowers/specs/2026-09-07-figur-aus-teilen-im-spiel-design.md
git commit -m "Spec: die Toenung ist gegen die gebackenen Blaetter geprueft"
```

---

## Selbstprüfung gegen die Spec

| Anforderung der Spec | Aufgabe |
|---|---|
| Varianten werden getönt statt gebacken | 1 |
| `SKIN_TONES`/`SHIRT_TONES`/`PANTS_TONES` liegen in der Palette | schon erfüllt, in 2 festgehalten |
| Die Grundebene wird nie umgefärbt | 1 (`test_stiefel_und_grundebene_bleiben_ungetoent`) |
| Jede Variante hat einen Ton | 1 (`test_jede_variante_hat_einen_ton`) |

**Nicht in diesem Plan, ausdrücklich:**

- **Die Charakteransicht zeigt keine Farbtupfer.** `scenes/ui/panels/character_panel.gd` stellt Kosmetik als Text dar und hat noch nie ein Sprite gezeigt; das ist kein Rückschritt dieses Umbaus.
- **Die Hutgrößen** und die **fünf Pixel der Blinzelfarben** — zurückgestellt am 2026-09-07 und 2026-09-08.
- **Die Döspose für den vollen Korb.** Sie liegt in PixelLab und ist nie ins Projekt gewandert.
