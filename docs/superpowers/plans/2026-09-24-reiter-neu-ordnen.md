# Reiter neu ordnen — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sieben Reiter mit je einer Aufgabe; Kaufen (Laden) und Benutzen
(Ausrüstung) getrennt; klare Namen.

**Architecture:** Reihenfolge der Kinder von `SidePanel/Panels` = Reihenfolge
in `TabRail.TABS`. Köder- und Aussehen-Liste bleiben EIN Skript je Sache mit
einem `@export`-Schalter (`nur_kaufen` bzw. `modus`), zwei Instanzen in
`main.tscn`. Sichtbarkeit der Unterreiter Händler/Geheim über
`TabGroup.set_sub_visible`, gesetzt in `main.gd`.

**Tech Stack:** Godot 4.7.2 / GDScript.

**Spec:** `docs/superpowers/specs/2026-09-24-reiter-neu-ordnen-design.md`

## Global Constraints

- Testtor `bash tools/test.sh`, Rückgabewert prüfen.
- Knotennamen in `main.tscn` (Pfade, die Tests benutzen):
  - `Panels/FishGroup/{FishScroll/FishPanel, VitrineScroll/VitrinePanel}`
  - `Panels/GearGroup/{BaitScroll/BaitPanel, PotionScroll/PotionPanel, LookScroll/LookPanel}`
  - `Panels/ShopGroup/{ShopScroll/ShopPanel, CharacterScroll/CharacterPanel, UpgradeScroll/UpgradePanel, TraderScroll/TraderPanel}`
  - `Panels/JournalGroup/{JournalScroll/JournalPanel, SecretScroll/SecretPanel, RecordScroll/RecordPanel}`
  - `Panels/QuestGroup/QuestScroll/QuestPanel`, `Panels/WorldGroup/…`, `Panels/OptionsGroup/…`
- `main.gd`-Konstanten: `FISH_TAB 0`, `GEAR_TAB 1`, `GEAR_SUB_POTION 1`,
  `SHOP_TAB 2`, `SHOP_SUB_TRADER 3`, `JOURNAL_TAB 3`, `JOURNAL_SUB_SECRET 1`.
- `TabRail.TABS = ["Fische", "Ausrüstung", "Laden", "Journal", "Aufträge", "Orte", "Optionen"]`.
- Kommentare kurz, das Warum.

---

### Task 1: Neue Reiterordnung in Szene und Code

**Files:** `scenes/ui/tab_rail.gd`, `scenes/main.tscn`, `scenes/main.gd`,
alle Tests mit alten Pfaden (`grep -n "Panels/\|show_tab\|select_sub" tests/*.gd`).

- [ ] Test anpassen: `tests/test_tabs_and_journal_order.gd` erwartet
  `["FishGroup", "GearGroup", "ShopGroup", "JournalGroup", "QuestGroup", "WorldGroup", "OptionsGroup"]`
  und die Unterreiter-Beschriftungen je Gruppe:
  Fische `Kiste, Vitrine`; Ausrüstung `Köder, Tränke, Aussehen`;
  Laden `Köder, Aussehen, Ausbau, Händler`; Journal `Arten, Geheim, Statistik`.
- [ ] Rot laufen lassen.
- [ ] `TABS` ändern; `main.tscn` umbauen (Knoten verschieben, neue Gruppen
  `GearGroup` mit `BaitScroll/BaitPanel` (Skript `shop_panel.gd`,
  `nur_kaufen = false`) und `LookScroll/LookPanel` (Skript
  `character_panel.gd`, `modus = "tragen"`), `QuestGroup`);
  `labels` der Gruppen setzen.
- [ ] `main.gd`: Konstanten wie oben; `_open_potions` → `GEAR_TAB/GEAR_SUB_POTION`;
  `_open_trader` → `SHOP_TAB/SHOP_SUB_TRADER`; `_update_secret_sub` →
  JournalGroup/`JOURNAL_SUB_SECRET`; `_secret_panel`-Pfad.
- [ ] Übrige Tests auf neue Pfade und Reiternummern ziehen, grün, Commit.

### Task 2: Köder — kaufen im Laden, anlegen in der Ausrüstung

**Files:** `scenes/ui/panels/shop_panel.gd`, Test `tests/test_order_and_bait.gd`.

- [ ] Tests: Laden-Köderliste enthält keinen Knopf „Anlegen“ und nicht den
  unbegrenzten Grundköder; Ausrüstungsliste enthält nur Köder mit Vorrat
  oder unbegrenzt, jeder mit „Anlegen“, und keinen „Auffüllen“-Knopf;
  Auffüllen ändert `Game.ctx.bait` nicht.
- [ ] `@export var nur_kaufen: bool = true`; in `refresh` filtern
  (`nur_kaufen`: `not b.unlimited`; sonst `b.unlimited or Vorrat > 0`);
  in `_row` den „Anlegen“-Knopf nur ohne `nur_kaufen`, den Kaufknopf nur mit.
- [ ] Grün, Commit.

### Task 3: Aussehen — kaufen im Laden, tragen in der Ausrüstung

**Files:** `scenes/ui/panels/character_panel.gd`, Test `tests/test_cosmetics.gd`.

- [ ] Tests: im Tragen-Modus nur Varianten mit `CosmeticState.OWNED`, antippen
  zieht an; im Kauf-Modus erscheinen gekaufte als „✓ gekauft“, deaktiviert.
- [ ] `@export_enum("kaufen", "tragen") var modus: String = "kaufen"`;
  `_variant_count`/Schleife nur über erlaubte Varianten; `OWNED` im
  Kauf-Modus: Text `"%s\n✓ gekauft"`, `disabled = true`.
- [ ] Grün, Commit.

### Task 4: Händler-Unterreiter nur, solange er da ist

**Files:** `scenes/main.gd`, Test `tests/test_visitors_and_bag.gd`.

- [ ] Test: `Game.dev_trader = 0` → Laden-Knopf „Händler“ unsichtbar;
  `= 1` → sichtbar; `_open_trader` landet auf `SHOP_SUB_TRADER`.
- [ ] `_update_trader_sub()` an `Game.state_changed`, in `show_tab` und
  `_open_trader` (vor `select_sub`) aufrufen.
- [ ] Grün, Commit.

### Task 5: Hinweise an den Reiterknöpfen

**Files:** `scenes/ui/tab_rail.gd`, `autoload/Game.gd` (`quest_ready() -> bool`),
Test `tests/test_tabs_and_journal_order.gd`.

- [ ] Tests: `Game.quest_ready()` falsch ohne passenden Fisch, wahr mit einem
  nicht-favorisierten passenden Fisch, falsch wenn erledigt; Rail-Knopf
  Orte trägt „☂“ genau dann, wenn `Game.rain_zone() != &""`.
- [ ] `quest_ready`: über `quest_offer()`, `not quests.is_done(id)`, Fisch in
  `ctx.inventory.fish` mit `fish_id == id and not is_favorite`.
- [ ] `TabRail`: `refresh_hints()` an `Game.state_changed`; Punkt = kleines
  `ColorRect` (12×12, `accent`) oben rechts im Aufträge-Knopf, `☂` als
  Textanhang am Orte-Knopf.
- [ ] Grün, Commit.

### Task 6: Wörter

**Files:** `fish_panel.gd` (Kopf „Kiste“), `potion_panel.gd` (Kopf „Tränke“,
Kommentar), `records_panel.gd`, `world_panel.gd`, Hinweistexte, die „Inventar“
oder „Beutel“ sagen (`grep -rn "Inventar\|Beutel\|Kosmetik\|Bilanz" scenes`).

- [ ] Texte angleichen; Tests, die Texte prüfen, mitziehen; grün, Commit.

### Task 7: Gerät

- [ ] Push, Build + Tests in CI grün, installieren, Nutzer prüfen lassen.
