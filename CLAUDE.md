# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Ein *Sid Meier's Pirates!*-Remake in Godot 4.7.1 (GDScript, Forward+). Prozedural erzeugte
Karibik, eigene Systeme statt originalgetreuem Nachbau.

**Der Autor ist Godot-Neuling.** Engine-Konzepte nicht als bekannt voraussetzen — Antworten
und Kommentare erklären, *warum* etwas so gebaut ist.

## Sprache

| Wo | Sprache |
|---|---|
| Bezeichner im Code | Englisch (`sail_efficiency`, `chunk_has_land`) |
| Kommentare, Doku, Gespräch mit dem Nutzer | Deutsch |
| Kommentare **im Code** | Deutsch **ohne Umlaute** (`Kuestenzelle`) — Encoding-Fragen gar nicht erst aufkommen lassen |
| Sichtbare UI-Texte, Commit-Meldungen, Markdown | Deutsch **mit** Umlauten |

## Verbindliche Dokumente

Vor größeren Änderungen lesen — sie sind die Quelle, nicht diese Datei:

- **`docs/RICHTLINIEN.md`** — verbindliche Regeln für Gestaltung (A1–A10), Code (B1–B15) und
  Tests (C1–C6). Jede Regel steht dort mit dem konkreten Fehler, aus dem sie entstanden ist.
- **`docs/KONZEPT.md`** — Vision, Systeme, Roadmap (M0–M7), Abschnitt 10 „Stand" und
  Abschnitt 11 „Nächste Schritte". Wird mit jedem Meilenstein fortgeschrieben.
- **`docs/STORY.md`** — Story-Konzept: Prämisse, Herkunft, Akte, Pfade, Mehrspieler-Ausblick.
  Optionaler Erzählstrang über der Sandbox aus `KONZEPT.md` 1, kein Ersatz dafür.

Neue Regeln entstehen aus Fehlern, nicht aus Vermutungen. Wer eine Regel hinzufügt, schreibt
den Fehler dazu.

## Befehle

```bash
godot --path .                                            # Spiel starten (F3 = Debug-Menü)
godot --headless --path . res://tests/smoke_test.tscn      # Rauchtest, Exit 0 = bestanden
godot --headless --import                                  # nach neuen class_name-Dateien nötig
```

Der Rauchtest ist **eine** Szene mit knapp vierhundert Prüfungen; es gibt kein Test-Framework
und keine Einzeltest-Auswahl. Einen einzelnen Block fährt man, indem man die anderen `_check_*`-Aufrufe
in `_ready()` von `tests/smoke_test.gd` auskommentiert. Er dauert rund 35 Sekunden, weil er
zwei vollständige Seegefechte im Zeitraffer fährt.

**Ein neues `class_name` wird erst nach `godot --headless --import` aufgelöst.** Ohne das
scheitert der Rauchtest mit „Could not find type X in the current scope" — kein Codefehler.

**Die Godot-Ausgabe wird gelesen, nicht gefiltert** (Regel C3). Ein Parse-Fehler ist eine
einzelne Zeile zwischen Warnungen, und das Spiel läuft weiter — nur ohne den betroffenen Node.
Genau so ist der Kompass einmal unbemerkt verschwunden.

### Sichtprüfungen — brauchen ein echtes Fenster

```bash
godot --path . res://tests/capture_sailing.tscn   # Segelmodus, 6 Aufnahmen + Bildrate/Chunk-Zahl
godot --path . res://tests/capture_battle.tscn    # Seegefecht: Sichtung, längsseits, Salve, Einschlag, Prise
godot --path . res://tests/capture_ship.tscn      # Schiffsmodell aus vier Winkeln
godot --path . res://tests/capture_island.tscn    # Küste: normal, ohne Dunst, ohne Wasser, Drahtgitter
godot --path . res://tests/capture_town.tscn      # Siedlung aus drei Abständen
godot --path . res://tests/capture_port.tscn      # Hafenbildschirm: Markt, nach Kauf, Werft
```

PNG-Ablage: `~/.local/share/godot/app_userdata/PirateGame/captures/`. **Nach jeder sichtbaren
Änderung ansehen, und zwar alle** — Shader werden headless nie kompiliert, Geometrie- und
Bildausschnittsfehler fallen aus der Verfolgerkamera nicht auf. In diesem Projekt kamen
Häuser auf Stelzen, ein durchsichtiges Gelände und ein vollständig unsichtbares Seegefecht
ausschließlich aus diesen Aufnahmen.

### Messwerkzeuge

```bash
godot --headless --path . res://tests/world_report.tscn     # 5 Welten: Landanteil, Inseln, Häfen, Beispielpreise
godot --headless --path . res://tests/terrain_report.tscn   # Kennzahlen eines Küstenchunks
godot --headless --path . res://tests/duel.tscn             # 15 Gefechte KI gegen KI: Salven, Treffer, Schaden
godot --path . res://tests/duel.tscn                        # dieselbe Szene mit Fenster: Gefecht zum Spielen
```

Parameter der Weltgenerierung werden hierüber eingestellt, nicht durch Probieren (Regel C4).
Für das Gefecht gilt dasselbe: `tests/duel.tscn` ist beides — der Messlauf für Ballistik,
Schaden und Bahnführung *und* die Szene, in der man ein Gefecht ohne Umweg ausprobiert
(R neuer Gegner, G Gegnerklasse, H Ausgangslage). Die aussagekräftigste Spalte ist
**„liegt an"**: der Anteil der Zeit, in dem überhaupt ein Rohr am Ziel war. Sinkt sie, liegt
es an der KI, nicht an der Ballistik. `TRACE` schreibt den Verlauf eines Gefechts Sekunde
für Sekunde mit, `TRACE_RUNS` jeden Einzellauf statt nur den Mittelwert.

## Architektur

### Autoloads sind der einzige Kitt

Modus-Szenen (`modes/sailing`, `modes/port`, `modes/menu`) kennen einander **nie**. Alles läuft
über sechs Singletons in `autoload/`:

| Autoload | Rolle |
|---|---|
| `EventBus` | Nur Signale, keine Logik. Sender und Empfänger kennen einander nicht. |
| `GameState` | Der Spieler: Gold, Ruf, Zeit — und sein Schiff zwischen zwei Szenen. |
| `WorldData` | Die generierte Welt: Seed, Wind, Wetter, Städte, Wirtschaftsuhr. |
| `SceneRouter` | Der einzige Weg zu einem Szenenwechsel (`enter_port`, `leave_port`, `to_sailing`). |
| `SaveManager` | JSON unter `user://saves/`, versioniert mit `_migrate()`. |
| `AudioDirector` | Noch Gerüst. |

### Wer ist die Wahrheit über das Schiff?

**Während einer Szene der `Ship`-Node, zwischen zwei Szenen `GameState`.** Der Segelmodus liest
beim Start aus `GameState` (`apply_class`, `set_condition`) und schreibt bei jeder Änderung über
`Ship.condition_changed` dorthin zurück — nur in diese Richtung, sonst schreiben sich beide
gegenseitig um. Die `.tres`-Datei der Schiffsklasse ist die Wahrheit über Fahrwerte und
Zähigkeit, nicht die Szene.

### Kernlogik ohne Nodes

Alles Prüfbare steht in statischen Klassen ohne Szenenbezug — das ist der Grund, warum der
Rauchtest ohne Fenster läuft:

| Klasse | Inhalt |
|---|---|
| `SailingMath` | Segelmathematik, Winkelkonvention, fahrbare Kurse, Fahrbarkeit bei fehlender Mannschaft |
| `Gunnery` | Ballistik: Richten, Vorhalten, Streuung, Trefferentscheid, Aufgeben |
| `TargetProfile` | Was die Ballistik über ein Ziel weiß: Position, Fahrt, Kurs, Maße |
| `Boarding` | Der Enterkampf: Stärke, Siegchance, Verluste |
| `ShipAI` | Die Entscheidungen eines KI-Kapitäns (statisch), der Node reicht sie nur weiter |
| `TradeMath` | Preisbildung aus Lagerbestand |
| `OceanWaves` | Wellenfeld — **doppelt vorhanden**, siehe unten |
| `TerrainChunk` | Chunk-Meshbau und die gezeichnete Oberflächenhöhe |
| `Palette` | Alle Farben des Spiels |

### Winkelkonvention — die häufigste Fehlerquelle

`heading()` liefert Navigationswinkel: 0 = Nord, 90° = Ost. **Godots `rotation.y` dreht genau
andersherum.** Die Umrechnung steht ausschließlich in `Ship.heading()` / `Ship.set_heading()`;
Richtungsvektoren kommen aus `SailingMath.direction()` und `angle_of()`. Der Linter verbietet
`rotation.y` außerhalb von `ship.gd` — eine Drehung, die kein Kurs ist (ein schräg stehendes
Haus), trägt den Vermerk `# kein Kurs`.

### Zwei bewusste Doppelungen

- **`OceanWaves` ↔ `world/ocean/ocean.gdshader`** berechnen dieselbe Wasserhöhe; GDScript und
  Shader können keinen Code teilen. Beide teilen sich sogar die Uhr (`OceanWaves.time_now()`
  als Uniform statt `TIME` im Shader), sonst driften Bild und Physik auseinander. **Konstanten
  immer an beiden Stellen ändern.**
- **`Palette` ↔ `MapImage`/`TerrainChunk`**: Seekarte und Gelände greifen auf dieselben
  Konstanten zu, damit eine Wiese oben wie unten gleich aussieht.

### Keine Collider, wo eine Funktion reicht

Land hält das Schiff auf, indem `WorldData.is_land()` die Position des nächsten Schrittes
prüft. Kanonenkugeln haben keine Kollisionskörper: Eine Breitseite wird beim Abfeuern
vollständig gerechnet (`Gunnery.resolve_salvo`) — Richtung, Bahn und Aufschlagpunkt jeder
einzelnen Kugel —, die Kugeln fliegen danach nur noch zu einem Ergebnis, das feststeht; der
Schaden fällt beim Aufschlag über einen `create_timer`-Callback.

### Die Flugbahn ist die Wahrheit

Getroffen wird nicht gewürfelt, sondern gerechnet. Die Rohre schwenken ±20° um querab
(`ShipClass.gun_traverse`), alle Rohre einer Seite feuern parallel, und ob eine Kugel
trifft, entscheidet ein Punkt-in-Rechteck-Test gegen den Rumpf des Gegners
(`Gunnery.hits_target`). Der Zufall sitzt nur noch im Vorhalten (`LEAD_SPREAD`) und in der
Streuung je Rohr (`SPREAD_DEG`); beide wachsen mit der Entfernung und mit fehlender
Bedienung.

**Die Kugel streut seitlich, nicht in der Tiefe** — sie liegt immer auf der geschätzten
Entfernung. Das ist kein vergessener Fehler, sondern die Voraussetzung dafür, dass ein
Schiff quer zu dir ein großes Ziel ist und eines mit dem Bug voran ein schmales. Mit einem
Streuen in der Tiefe kehrte sich das um, weil ein bugvorausstehendes Schiff in
Schussrichtung länger ist.

**`Ship.readiness()`, nicht `crew_fraction()`.** Mannschaft zählt im Gefecht erst, was über
`min_crew` hinausgeht; zwei Mann je Rohr für volle Ladegeschwindigkeit. `crew_fraction()`
bleibt für die Moral (`Gunnery.will_strike`) — wer aufgibt, zählt Köpfe, nicht Bedienung.

### Zwei Wege zur Prise

**Schießen oder entern.** Ein Gegner, der die Flagge gestrichen hat, wird mit der Leertaste
ausgeräumt (`NavalCombat.take_prize`, 110 m). Einer, der noch kämpft, lässt sich stürmen
(`NavalCombat.board`, 45 m) — schneller, aber es kostet Leute, die danach an Schoten und
Rohren fehlen. Das ist die Stelle, an der Mannschaft zum ersten Mal etwas ist, das man
*einsetzt*, statt nur zu verlieren.

Der Ausgang ist ein Wurf, kein Taktikgefecht: `Boarding.odds()` liefert den Anteil des
Angreifers an der Gesamtstärke, und **dieselbe Zahl** entscheidet über Sieg *und* über die
Verluste beider Seiten — ein aussichtsloser Sturm ist ein Gemetzel, ein übermächtiger
kostet fast nichts. Verteidigen ist im Vorteil (`DEFENCE_BONUS`), ein zerschossener Rumpf
nimmt den Verteidigern den Mut (`HULL_MORALE`), Berüchtigtheit hilft dem Angreifer
(`FEAR_BONUS`). Das taktische Deckgefecht aus `docs/KONZEPT.md` 3.4 ist Tier 1 und braucht
Offiziere, die es noch nicht gibt.

**Eine erbeutete Prise lässt sich noch nicht behalten** — sie wird ausgeräumt und treibt
davon (`NavalCombat._release`). Das ist eine Lücke, kein Entwurf: Das Prisenschiff zu
übernehmen gehört zu M5 und ist nur zurückgestellt. **Nicht mit Flottenführung verwechseln**
— *ein* Schiff gegen das eigene tauschen ist M5, *mehrere* Schiffe führen ist 5.4 und
Tier 2.

### Drei Aufforderungen, eine Taste

Prise, Entern und Anlegen liegen alle auf der Leertaste und teilen sich eine Zeile im HUD.
Die Reihenfolge steht an **zwei** Stellen und muss dieselbe sein: `SailingMode._unhandled_input`
entscheidet, was passiert, `SailingHud._refresh_prompt` schreibt, was dasteht. Vorher hat
jedes der drei Signale die Zeile für sich überschrieben — dann verschwand die Hafen-
aufforderung, weil ein Gegner außer Enterreichweite geriet.

### Höhen: mathematisch ≠ gezeichnet

`WorldData.terrain_y()` liefert die Höhenfunktion. Das Mesh zeigt aber die geraden Flächen
zwischen Gitterpunkten, die acht Meter auseinander liegen. **Wer etwas auf den Boden setzt,
benutzt `WorldData.terrain_surface_y()`** — an einer Steilküste weichen beide um Meter
voneinander ab. Wird automatisch geprüft.

### Debug-Menü (F3)

`ui/debug/debug_menu.gd` hängt als Knoten in `modes/sailing/sailing_mode.tscn` und dreht an
Wind (`WorldData.wind_locked` hält ihn fest), Fahrt (`Ship.speed_multiplier`, lässt die
`.tres`-Werte unberührt) und Begegnungen (`NavalCombat.spawn_interval` / `max_ships` /
`spawn_now()`). Es ist im Code gebaut wie die Hafenbildschirme, hat also keine `.tscn` — die
einzige Ansicht ist die sechste Aufnahme von `capture_sailing.tscn`. Vor einem Release fällt
der Knoten aus der Szene.

### Farben

Alle Farben stehen in `data/palette.gd`. Im übrigen Code steht **kein** `Color(...)`, in
`.tscn`-Dateien **kein** `theme_override_colors/` — die Szene bestimmt die Anordnung, das
Skript setzt die Farbe in `_ready()`. Ausnahmen: Nationsfarben in `resources/nations/*.tres`
(Spieldaten), 3D-Materialien und Umgebung in der Szene (Live-Vorschau im Editor).

Grün heißt „gut für dich", nicht „hoher Wert". Die Gegenrichtung wird abgeblendet, nicht rot —
rot bedeutet in diesem Spiel Schaden.

### Balancing in Dateien, nicht im Code

`resources/ships/*.tres`, `resources/cargo/*.tres`, `resources/nations/*.tres`. Werte, an denen
gedreht wird, bekommen `@export`.

## Was der Rauchtest automatisch durchsetzt

`_check_code_conventions()` durchsucht `autoload/`, `data/`, `world/`, `ui/`, `entities/`,
`modes/`:

- kein `Color(...)` außerhalb von `palette.gd`, kein `theme_override_colors/` in `.tscn`
- kein `rotation.y` außerhalb von `ship.gd` (außer mit `# kein Kurs`)
- Geländematerial rendert beidseitig und nutzt Vertex-Farben
- die Aufsetzhöhe trifft das gezeichnete Mesh auf den Millimeter

Dazu prüft `_check_everything_loads()`, dass jedes Skript wirklich *kompiliert* — `load()`
liefert bei einem Parse-Fehler trotzdem ein Objekt zurück, nur eben ein nicht kompiliertes;
`can_instantiate()` unterscheidet das.

## Zwei Godot-Fallen, die niemand sieht

- **Vertex-Farben sind linear, nicht sRGB.** Für Mesh-Arrays immer `Palette.for_vertex()`,
  sonst sehen die Inseln aus wie Schneefelder.
- **Transform-Basen stehen in `.tscn` zeilenweise.** Eine spaltenweise gerechnete
  Rotationsmatrix landet dort transponiert — also als ihre Umkehrung.

## Beim Bauen

- **Jeder gefundene Fehler wird ein Test** — gezielt festhalten, was schiefging, statt
  nachträglich Abdeckung zu erzeugen.
- **Die Abnahmebedingung eines Meilensteins wird gefahren, nicht behauptet** (Regel C6). M3
  kauft und verkauft im Rauchtest wirklich, M4 fährt zwei vollständige Gefechte.
- **Wer versetzt, versetzt alles mit**: Wird ein Objekt gesetzt statt bewegt (Kampagnenstart,
  Auslaufen), muss alles Träge mitgesetzt werden — die Kamera hat dafür `snap()`.

---

Auf diesem Rechner liegen Konfigurationen von OpenAI Codex (`~/.codex/config.toml`) und Gemini
CLI (`~/.gemini/settings.json`). Falls daraus etwas übernommen werden soll: `/import` listet
auf, was importierbar ist (MCP-Server, Slash-Commands, Subagents, Skills, Anweisungen),
`/import --yes=<digest>` übernimmt es. Ohne diese Fassung im Terminal: `claude import`.
