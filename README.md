# PirateGame

Ein Piraten-Sandbox-Spiel in der Tradition von *Sid Meier's Pirates!*, gebaut mit Godot 4.7.
3D-Präsentation, prozedural erzeugte Karibik, eigene Systeme statt originalgetreuem Nachbau.

**Status:** M2 abgeschlossen — die Welt existiert als Land, an dem man vorbeisegelt.
Als Nächstes M3: Andocken und der erste Hafen.

## Dokumentation

- [Projektkonzept](docs/KONZEPT.md) — Vision, Gameplay-Systeme, technische Architektur, Roadmap
- [Richtlinien](docs/RICHTLINIEN.md) — verbindliche Regeln für Gestaltung und Code

## Starten

Projekt in Godot 4.7 öffnen, oder direkt:

```bash
godot --path .
```

## Tests

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

137 Prüfungen: Autoloads, Eingabebelegung, Kampagnenstart, Speicher-Roundtrip,
Segelmathematik, Winkelkonvention, Wellenfeld, Schiffsgeometrie, Weltgenerierung
(Landanteil, Weltrand, Hafenabstände, Nationsbesitz, Wirtschaft, Determinismus)
sowie Gelände-Chunks, Grundberührung, Projektregeln und die Frage, ob überhaupt
jedes Skript kompiliert. Exit-Code 0 = bestanden.

```bash
godot --path . res://tests/capture_sailing.tscn
```

Sichtprüfung: rendert den Segelmodus und legt vier Aufnahmen unter
`user://captures/` ab (Standardkurs, Wende, In Irons, Seekarte). Braucht ein
echtes Fenster — der Ozean-Shader wird headless nie kompiliert und bliebe
ungeprüft.

```bash
godot --path . res://tests/capture_ship.tscn
```

Zeigt das Schiffsmodell aus vier festen Winkeln vor ruhiger Wasserlinie. Im
Segelmodus verdeckt die Verfolgerkamera genau die Details, die man beim
Modellieren beurteilen muss.

Die Sichtprüfung meldet nebenbei Bildrate und Chunk-Zahl — Performance war das
erklärte Hauptrisiko von M2.

```bash
godot --headless --path . res://tests/world_report.tscn
```

Statistik über fünf generierte Welten: Landanteil, Inseln, Hafenplätze,
Städte je Nation, Beispielwirtschaft. Zum Justieren der Generator-Parameter.

## Struktur

| Ordner | Inhalt |
|---|---|
| `autoload/` | Singletons: `EventBus`, `GameState`, `WorldData`, `SceneRouter`, `SaveManager`, `AudioDirector` |
| `data/` | Resource-Klassen (`ShipClass`, `TownData`, `NationData`, `CargoType`, `OfficerData`) |
| `resources/` | Konkrete `.tres`-Instanzen — hier wird balanciert, nicht im Code |
| `world/` | Weltgenerierung, Gelände-Chunks mit Streaming, Ozean-Shader und Wellenformel |
| `modes/` | Die Modus-Szenen: `sailing`, `port`, `boarding`, `menu` |
| `entities/` | Schiffe, Geschosse |
| `ui/` | HUD, Seekarte, Hafenbildschirme, Theme |
| `tests/` | Rauchtests |

## Regeln

Verbindlich in [docs/RICHTLINIEN.md](docs/RICHTLINIEN.md). Die wichtigsten:

- **Modus-Szenen kennen einander nie** — Kommunikation über `GameState` und `EventBus`,
  Szenenwechsel über `SceneRouter`.
- **Alle Farben aus `data/palette.gd`** — kein `Color(...)` im übrigen Code.
- **Kurse sind Navigationswinkel** — `heading()` statt `rotation.y`.
- **Vertex-Farben sind linear** — `Palette.for_vertex()` benutzen.
- **Die Wellenformel existiert doppelt** — `OceanWaves` und `ocean.gdshader` müssen
  synchron bleiben, sonst schwebt das Schiff über der sichtbaren See.

Die ersten drei prüft der Rauchtest automatisch.

## Steuerung

| Taste | Aktion |
|---|---|
| A / D | Ruder backbord / steuerbord |
| W / S | Segel setzen / reffen |
| Q / E | Breitseite backbord / steuerbord |
| Leertaste | Interagieren |
| F | Fernrohr |
| M | Karte |
| T | Zeitraffer |
| M | Seekarte |
| Esc | Karte schließen, sonst zurück ins Menü |
