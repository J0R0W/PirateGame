# PirateGame

Ein Piraten-Sandbox-Spiel in der Tradition von *Sid Meier's Pirates!*, gebaut mit Godot 4.7.
3D-Präsentation, prozedural erzeugte Karibik, eigene Systeme statt originalgetreuem Nachbau.

**Status:** M3 abgeschlossen — es gibt eine Spielschleife. Segeln, in einem Hafen anlegen,
günstig kaufen, woanders teuer verkaufen, das Schiff instand setzen.
Als Nächstes M4: Seekampf.

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

217 Prüfungen: Autoloads, Eingabebelegung, Kampagnenstart, Speicher-Roundtrip,
Segelmathematik, Winkelkonvention, Wellenfeld, Schiffsgeometrie, Weltgenerierung
(Landanteil, Weltrand, Hafenabstände, Nationsbesitz, Determinismus), Ankerplätze,
Stadtterrassen, Siedlungen, Preisbildung, Handel, Werft, Schaden sowie Gelände-Chunks,
Grundberührung, Projektregeln und die Frage, ob überhaupt jedes Skript kompiliert.

Darunter die Abnahmebedingung von M3 selbst: 20 Fass Zucker im billigsten Hafen kaufen,
im teuersten verkaufen, und die Fahrt muss Gewinn abwerfen — die Route rückwärts Verlust.
Exit-Code 0 = bestanden.

```bash
godot --path . res://tests/capture_sailing.tscn
```

Sichtprüfung: rendert den Segelmodus und legt fünf Aufnahmen unter `user://captures/` ab
(Standardkurs, Wende, In Irons, Seekarte, Hafen in Reichweite). Braucht ein echtes
Fenster — der Ozean-Shader wird headless nie kompiliert und bliebe ungeprüft.

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
godot --headless --path . res://tests/terrain_report.tscn
```

Statistik über fünf generierte Welten (Landanteil, Inseln, Hafenplätze, Städte
je Nation, Beispielwirtschaft) und Kennzahlen eines Küstenchunks (Vertexbereich,
Höhensprünge, Kantenpassung, Chunk-Belegung). Zum Justieren der Parameter.

```bash
godot --path . res://tests/capture_island.tscn
godot --path . res://tests/capture_town.tscn
godot --path . res://tests/capture_port.tscn
```

Zeigt eine Küste vier Mal (vollständig, ohne Dunst, ohne Wasser, Drahtgitter), eine
Siedlung aus drei Abständen und den Hafenbildschirm mit Markt, Kauf und Werft. Damit
lässt sich unterscheiden, ob ein Darstellungsfehler vom Gelände, vom Wasser oder von der
Atmosphäre kommt — und ob Häuser wirklich auf dem Hang stehen.

## Struktur

| Ordner | Inhalt |
|---|---|
| `autoload/` | Singletons: `EventBus`, `GameState`, `WorldData`, `SceneRouter`, `SaveManager`, `AudioDirector` |
| `data/` | Resource-Klassen (`ShipClass`, `TownData`, `NationData`, `CargoType`, `OfficerData`), Palette, Warenverzeichnis |
| `resources/` | Konkrete `.tres`-Instanzen — Nationen, Waren, Schiffsklassen. Hier wird balanciert, nicht im Code |
| `world/` | Weltgenerierung, Gelände-Chunks mit Streaming, Ozean-Shader und Wellenformel, Siedlungen, Wirtschaft |
| `modes/` | Die Modus-Szenen: `sailing`, `port`, `boarding`, `menu` |
| `entities/` | Schiffe, Geschosse |
| `ui/` | HUD, Seekarte, Hafenbildschirme, Theme |
| `tests/` | Rauchtests |

## Regeln

Verbindlich in [docs/RICHTLINIEN.md](docs/RICHTLINIEN.md). Die wichtigsten:

- **Modus-Szenen kennen einander nie** — Kommunikation über `GameState` und `EventBus`,
  Szenenwechsel über `SceneRouter`.
- **Alle Farben aus `data/palette.gd`** — kein `Color(...)` im Code, keine Textfarbe in
  einer `.tscn`. Die Szene bestimmt die Anordnung, das Skript die Farbe.
- **Kurse sind Navigationswinkel** — `heading()` statt `rotation.y`.
- **Vertex-Farben sind linear** — `Palette.for_vertex()` benutzen.
- **Gelände rendert beidseitig** — mit Rückseiten-Culling zerfallen steile Küsten
  in schwebende Fetzen.
- **Was auf dem Gelände steht, fragt `terrain_surface_y()`** — die Höhenfunktion und die
  gezeichnete Fläche weichen an einer Küste um Meter voneinander ab.
- **Die Wellenformel existiert doppelt** — `OceanWaves` und `ocean.gdshader` müssen
  synchron bleiben, sonst schwebt das Schiff über der sichtbaren See.

Alle bis auf die letzte prüft der Rauchtest automatisch.

## Steuerung

| Taste | Aktion |
|---|---|
| A / D | Ruder backbord / steuerbord |
| W / S | Segel setzen / reffen |
| Mausrad | Kamera heran und weg |
| Leertaste | Anlegen, wenn ein Hafen in Reichweite ist |
| M | Seekarte |
| Esc | Karte schließen, sonst zurück ins Menü |

Belegt, aber noch ohne Wirkung: **Q / E** (Breitseiten, M4), **F** (Fernrohr),
**T** (Zeitraffer).

Im Hafen: **Markt**, **Werft**, **Speichern**, **Ablegen** — oder **Esc** zum Auslaufen.
