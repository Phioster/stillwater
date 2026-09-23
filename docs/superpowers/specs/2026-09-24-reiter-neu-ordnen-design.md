# Reiter neu ordnen: kaufen hier, benutzen dort

**Stand 2026-09-24.** Mit dem Nutzer abgestimmt („genau so habe ich mir das
vorgestellt“), noch nicht umgesetzt. Kommt vor den Fischbildern.

## Warum

Heute: 5 Reiter, 13 Unterreiter.

| Reiter | Unterreiter |
|---|---|
| Fische | Inventar · Vitrine · Beutel · Aufträge · Geheim |
| Journal | Arten · Bilanz |
| Laden | Köder · Händler · Kosmetik · Ausbau |
| Welt | – |
| Optionen | – |

- „Fische“ ist eine Sammelkiste: Tränke („Beutel“) und Aufträge haben mit
  gefangenen Fischen nichts zu tun, Geheimfische gehören zu den Arten.
- Kaufen und Benutzen sind vermischt: Köder anlegen und sich anziehen geht
  nur im Laden.
- Die Wörter passen nicht zusammen: „Inventar“ heißt im Kopf „Fischkiste“,
  „Beutel“ sind Tränke, „Welt“ sind Orte.

Cornerpond (`~/cornerpond-research/scn/MainScene.txt`, `src/Shop/ShopPopup.gd`,
`src/Equips/EquipsPopup.gd`): sechs Knöpfe mit je einer Aufgabe — My Fish,
Shop (alles **kaufen**: Köder, Ausbau, Aussehen), Equips (alles **benutzen**:
Köder wählen, Tränke trinken; zweiter Reiter Aussehen anziehen), Journal,
Quests (Punkt, wenn fertig), Locations (Regentropfen). Die Maus hat keinen
Reiter, sie öffnet sich beim Antippen.

## Neue Ordnung

| # | Reiter | Unterreiter | Aufgabe |
|---|---|---|---|
| 0 | **Fische** | Kiste · Vitrine | was du gefangen hast |
| 1 | **Ausrüstung** | Köder · Tränke · Aussehen | benutzen, was du hast |
| 2 | **Laden** | Köder · Aussehen · Ausbau · Händler | kaufen |
| 3 | **Journal** | Arten · Geheim · Statistik | die Sammlung |
| 4 | **Aufträge** | – | eigener Takt |
| 5 | **Orte** | – | reisen |
| 6 | **Optionen** | – | Einstellungen |

Umbenannt: Inventar → Kiste, Beutel → Tränke, Kosmetik → Aussehen,
Bilanz → Statistik, Welt → Orte.

### Regeln

- **Ausrüstung → Köder:** nur Köder, die du hast (unbegrenzt oder Vorrat
  > 0), mit Beschreibung und „Anlegen“. Kein Kaufen.
- **Laden → Köder:** nur kaufbare Köder (nicht der unbegrenzte Grundköder),
  mit „Auffüllen“. Kein „Anlegen“; ein Kauf ändert den aktiven Köder nicht.
- **Ausrüstung → Aussehen:** je Kategorie nur, was du besitzt; antippen
  zieht es an.
- **Laden → Aussehen:** alle Varianten; gekaufte zeigen „✓ gekauft“ und sind
  nicht antippbar, der Rest wie heute (Preis, Sperrgrund, kaufen). Kaufen
  zieht nicht an.
- **Händler:** Unterreiter nur sichtbar, solange `Game.trader_visible()`.
  Antippen des Waschbären öffnet Laden → Händler wie bisher.
- **Geheim:** zieht von Fische ins Journal, weiterhin erst sichtbar nach dem
  ersten Geheimfang.
- **Knopf-Hinweise:** Aufträge bekommt einen Punkt, sobald ein Auftrag
  abgebbar ist (nicht erledigt, ein nicht-favorisierter passender Fisch in
  der Kiste). Orte bekommt „☂“, wenn es irgendwo regnet (`Game.rain_zone()`).
- Die Trankreihe öffnet Ausrüstung → Tränke.
- Beim Verlassen des Laden-Reiters weiterhin `Game.close_shop()`.
- Fanganzeige/Kampfleiste bei offenem Menü aus — gilt für alle Reiter.

## Nicht Teil davon

- Figurvorschau beim Anziehen (Cornerpond hat eine; bei uns steht die
  Anglerin ohnehin links neben dem Menü).
- Sortieren in der Kiste, neue Inhalte.
