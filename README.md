# PirateGame

Ein Piraten-Sandbox-Spiel in der Tradition von *Sid Meier's Pirates!*, gebaut mit Godot 4.7.
3D-Präsentation, prozedural erzeugte Karibik, eigene Systeme statt originalgetreuem Nachbau.

**Status:** M1 abgenommen (Segeln fühlt sich gut an). M2 — Weltgenerierung und Seekarte stehen,
als Nächstes 3D-Terrain mit Chunk-Streaming.

## Dokumentation

- [Projektkonzept](docs/KONZEPT.md) — Vision, Gameplay-Systeme, technische Architektur, Roadmap

## Starten

Projekt in Godot 4.7 öffnen, oder direkt:

```bash
godot --path .
```

## Tests

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

101 Prüfungen: Autoloads, Eingabebelegung, Kampagnenstart, Speicher-Roundtrip,
Segelmathematik, Wellenfeld, Schiffsgeometrie und die komplette Weltgenerierung
(Landanteil, Weltrand, Hafenabstände, Nationsbesitz, Wirtschaft, Determinismus).
Exit-Code 0 = bestanden.

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
| `world/` | Weltgenerierung, Chunk-Streaming, Ozean-Shader und Wellenformel |
| `modes/` | Die Modus-Szenen: `sailing`, `port`, `boarding`, `menu` |
| `entities/` | Schiffe, Geschosse |
| `ui/` | HUD, Seekarte, Hafenbildschirme, Theme |
| `tests/` | Rauchtests |

## Architekturregeln

**Modus-Szenen kennen einander nie direkt.** Kommunikation läuft über `GameState`
(Zustand) und `EventBus` (Signale); Szenenwechsel ausschließlich über `SceneRouter`.

**Transform-Basen stehen in `.tscn` zeilenweise.** Eine spaltenweise gerechnete
Rotationsmatrix landet transponiert in der Szene — und die Transponierte einer
Rotation ist ihre *Umkehrung*. So zeigte der Klüverbaum nach unten statt nach
oben. Wer eine gedrehte Transform von Hand einträgt, prüft sie mit
`tests/capture_ship.tscn` nach; `_check_ship_model()` im Rauchtest fängt den
Fall inzwischen ab.

**Der Meeresspiegel steht nicht fest, er wird kalibriert.** `WorldGenerator`
tastet die Höhenverteilung ab und legt `sea_level` auf das Perzentil, das
`TARGET_LAND_SHARE` trifft. Deshalb liefert *jeder* Seed eine brauchbare Karibik
statt mal einen leeren Ozean und mal einen Kontinent. Wer den Landanteil ändern
will, ändert die Zielgröße — nie den Meeresspiegel direkt.

**Die Heightmap wird nie gespeichert.** `WorldGenerator.height_at()` ist die
maßgebliche, kontinuierliche Quelle und jederzeit an beliebiger Stelle
auswertbar. Das Analyse-Raster (512²) dient nur dazu, Inseln und Häfen zu
*finden*; das Terrain-Meshing sampelt später direkt die Funktion.

**Die Wellenformel existiert doppelt und muss synchron bleiben.** `OceanWaves`
(GDScript) und `ocean.gdshader` berechnen dieselbe Wasserhöhe — der Shader zeichnet
die See, das Schiff reitet darauf. Wird eine Konstante geändert, muss die andere
Seite mitgezogen werden, sonst schwebt oder versinkt das Schiff. Beide teilen sich
auch die Uhr: `ocean.gd` reicht `OceanWaves.time_now()` als Uniform weiter, statt
im Shader `TIME` zu benutzen.

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
