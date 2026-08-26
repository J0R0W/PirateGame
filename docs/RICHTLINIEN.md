# Richtlinien

Verbindliche Regeln für Gestaltung und Code. Sie sind nicht am Reißbrett entstanden,
sondern aus dem, was bisher gebaut wurde — jede Regel mit dem Grund, aus dem es sie gibt.
Wo eine Regel aus einem konkreten Fehler stammt, steht der Fehler dabei.

Ein Teil davon wird automatisch geprüft, siehe [Durchsetzung](#durchsetzung).

---

## Teil A — Gestaltung

### A1. Lesbarkeit vor Realismus

Das Spiel wird aus 20 bis 60 Metern Entfernung gespielt, bei Wellengang, oft in Bewegung.
Was auf einem Standbild schön ist, aber in Fahrt nicht mehr erkennbar, hat verloren.

Praktisch: Silhouetten müssen auf 500 Meter unterscheidbar bleiben. Ein Schiffstyp ist an
seinem Umriss zu erkennen, nicht an seiner Textur.

### A2. Low Poly mit Flächenfarben

Kein PBR, keine Materialtexturen, keine Normal Maps. Farbe steckt in Vertices und
Materialfarben.

**Warum:** Bei 3D als Solo-Projekt entscheidet der Stil über die Machbarkeit. Ein
Schiff mit 2000 Tris entsteht an einem Abend, eines mit 50 000 in zwei Wochen. Der Stil
verzeiht außerdem Ungenauigkeiten in Modellierung und Animation.

### A3. Eine Palette, eine Quelle

Alle Farben stehen in `data/palette.gd`. Im übrigen Code steht **kein** `Color(...)`.

**Warum:** Vorher lagen dieselben Töne in sechs Dateien, teils leicht verschieden — Karte
und Gelände zeigten unterschiedliches Grün für dieselbe Wiese. Wird automatisch geprüft.

Ausnahme: Nationsfarben stehen in `resources/nations/*.tres`, weil sie Spieldaten sind
und nicht Gestaltung.

| Gruppe | Konstanten |
|---|---|
| **See** | `DEEP_SEA` `SHALLOW_SEA` `SHOAL` `SEABED` `FOAM` |
| **Land** | `SAND` `GRASS` `SCRUB` `ROCK` `PEAK` |
| **Schiff** | `HULL` `TIMBER` `CANVAS` |
| **Anzeigen** | `HUD_TEXT` `HUD_DIM` `HUD_OUTLINE` `BACKDROP` |
| **Zustand** | `GOOD` `FAIR` `BAD` |
| **Akzent** | `BRASS` (Wind, Gold, Nautisches) · `DANGER` (Warnung, Sperrsektor) |

### A4. Zustandsfarben sind kein Akzent

`GOOD` / `FAIR` / `BAD` bedeuten etwas. Sie werden nie zur Dekoration benutzt, und der
Akzent `BRASS` wird nie zur Zustandsanzeige. Sonst verlieren beide ihre Aussage.

### A5. Karte zeigt, was die Welt zeigt

Eine Wiese hat auf der Seekarte dieselbe Farbe wie unter dem Kiel. `MapImage` und
`TerrainChunk` greifen auf dieselben Palettenkonstanten zu.

### A6. Das HUD trägt keine Kästen

Text steht frei über der Szene, lesbar durch Kontur (`HUD_OUTLINE`), nicht durch
Hintergrundflächen. Angezeigt wird nur, was zum Navigieren nötig ist.

**Warum:** Panels verdecken die See. Das Spiel besteht daraus, den Horizont zu beobachten.

### A7. Systeme sichtbar machen, nicht erklären

Der rote Sperrsektor im Kompass ist das Vorbild: Er zeigt ohne ein Wort, wohin man nicht
segeln kann. Wo eine Regel des Spiels wichtig ist, bekommt sie eine Anzeige — kein
Tutorial-Fenster.

Folgt aus dem Design-Pillar *Lesbare Systeme* (siehe `KONZEPT.md`).

### A8. Atmosphäre statt Sichtbegrenzung

Dunst färbt Entferntes blaugrau und gibt Tiefe. Er ist nicht dazu da, Renderweiten zu
verstecken.

**Warum:** Genau das war er zwischenzeitlich. Die Ozean-Plane reichte 450 Meter, also
musste der Dunst dicht genug sein, ihren Rand zu verbergen — und verschluckte die Inseln
gleich mit. Erst eine große flache Fernsee unter den Wellen hat beides entkoppelt.

---

## Teil B — Code

### B1. Modus-Szenen kennen einander nie

Kommunikation läuft über `GameState` (Zustand) und `EventBus` (Signale). Szenenwechsel
ausschließlich über `SceneRouter`.

**Warum:** Direkte Verweise zwischen Szenen sind die Hauptursache dafür, dass
Hobbyprojekte unwartbar werden. Die Regel kostet am Anfang Tipparbeit und erlaubt später,
jeden Modus einzeln auszutauschen.

### B2. Daten in Resources, Balancing in Dateien

Werte, an denen gedreht wird, gehören in `.tres`-Dateien, nicht in `if`-Blöcke.
Werte, die man beim Ausprobieren ändert, bekommen `@export`.

### B3. Mathematik ohne Nodes

Kernlogik steht in statischen Klassen ohne Szenenbezug: `SailingMath`, `OceanWaves`,
`TerrainChunk`, `Palette`.

**Warum:** So lässt sich das Herzstück des Spiels prüfen, ohne eine Szene zu starten.
Die 30 Prüfungen zur Segelmathematik laufen in Millisekunden.

### B4. Eine Wahrheit, oder eine dokumentierte Doppelung

Wo eine Formel zwingend doppelt existiert — GDScript und Shader können sich keinen Code
teilen —, steht an beiden Stellen ein Hinweis auf die andere, und beide teilen ihre
Eingaben.

Beispiel: `OceanWaves` und `ocean.gdshader` berechnen dieselbe Wasserhöhe. Der Shader
zeichnet die See, das Schiff reitet darauf. Sie teilen sich sogar die Uhr — `ocean.gd`
reicht `OceanWaves.time_now()` als Uniform weiter, statt im Shader `TIME` zu benutzen.
Sonst driften Bild und Physik auseinander.

### B5. Kalibrieren statt feste Schwellen

Wo ein Schwellwert von erzeugten Daten abhängt, wird er aus den Daten abgeleitet.

**Warum:** Ein fester Meeresspiegel lieferte je nach Seed 1,6 % Land oder einen
Kontinent. Jetzt tastet der Generator die Höhenverteilung ab und legt den Meeresspiegel
auf das Perzentil, das den Ziel-Landanteil trifft. Der Landanteil ist damit per
Konstruktion richtig — bei jedem Seed.

### B6. Kein Collider, wo eine Funktion reicht

Land hält das Schiff auf, indem `height_at()` die Position des nächsten Schrittes prüft.
Kein Collision-Mesh für Inseln.

### B7. Kurse sind Navigationswinkel

`heading()` liefert 0 = Nord, 90° = Ost. Godots `rotation.y` dreht genau andersherum.
Die Umrechnung steht ausschließlich in `Ship.heading()` und `Ship.set_heading()`.
Richtungsvektoren kommen aus `SailingMath.direction()` und `angle_of()`.

**Warum:** Das Segelverhalten blieb trotz des Fehlers korrekt, weil `sail_efficiency` nur
die Differenz nutzt — aber Kompass, Seekarte und Startausrichtung zeigten spiegelverkehrt,
und das Schiff startete mit Blick aufs offene Meer statt auf die Küste. Wird automatisch
geprüft.

### B8. Zwei Godot-Fallen, die niemand sieht

**Vertex-Farben sind linear, nicht sRGB.** Godot 4 interpretiert Farben in Mesh-Arrays als
linear. Eine sRGB-Palette wirkt dort ausgewaschen — die Inseln sahen aus wie Schneefelder.
Für Vertex-Farben immer `Palette.for_vertex()`.

**Transform-Basen stehen in `.tscn` zeilenweise.** Eine spaltenweise gerechnete
Rotationsmatrix landet transponiert in der Szene, und die Transponierte einer Rotation ist
ihre Umkehrung. So zeigte der Klüverbaum nach unten. Gedrehte Transforms werden mit
`tests/capture_ship.tscn` nachgeprüft.

### B9. Kommentare erklären das Warum

Was der Code tut, steht im Code. Kommentare begründen Entscheidungen, nennen
Größenordnungen und warnen vor Fallen. Jede Konstante, deren Wert nicht offensichtlich
ist, bekommt einen Satz dazu.

### B10. Sprache

| Wo | Sprache |
|---|---|
| Bezeichner im Code | Englisch (`sail_efficiency`, `chunk_has_land`) |
| Kommentare und Dokumentation | Deutsch, **ohne Umlaute** im Code (`Kuestenzelle`) |
| Sichtbare Texte, Commit-Meldungen, Markdown | Deutsch mit Umlauten |

Umlaute in Code-Kommentaren wurden bewusst vermieden, damit Encoding-Fragen in Editoren
und Werkzeugen gar nicht erst aufkommen. In Markdown und UI-Strings gibt es diese Sorge
nicht.

Godot-Konventionen im Übrigen: `snake_case` für Variablen und Funktionen, `PascalCase`
für Klassen, `SCREAMING_CASE` für Konstanten, führender Unterstrich für Privates,
`##` für Dokumentationskommentare.

---

## Teil C — Tests

### C1. Jeder gefundene Fehler wird ein Test

Nicht nachträglich Abdeckung erzeugen, sondern gezielt das festhalten, was schiefging.
Deshalb prüft der Rauchtest Dinge wie „der Klüverbaum steckt im Bug" und „Kurs 90 Grad
zeigt nach Osten" — beides waren echte Fehler.

### C2. Was man nicht rendert, hat man nicht geprüft

Shader werden headless nie kompiliert. Geometriefehler fallen aus der Verfolgerkamera
nicht auf. Deshalb gibt es zwei Sichtprüfungen, die wirklich rendern:

| Werkzeug | Zweck |
|---|---|
| `tests/capture_sailing.tscn` | Segelmodus, vier Aufnahmen, dazu Bildrate und Chunk-Zahl |
| `tests/capture_ship.tscn` | Schiffsmodell aus vier festen Winkeln, ruhige Wasserlinie |

### C3. Messen statt raten

Parameter der Weltgenerierung werden über `tests/world_report.tscn` eingestellt, nicht
durch Probieren. Performance wird beziffert, nicht geschätzt.

### <a id="durchsetzung"></a>C4. Was automatisch geprüft wird

`_check_code_conventions()` im Rauchtest durchsucht `autoload/`, `data/`, `world/`,
`ui/`, `entities/` und `modes/` nach Regelverstößen:

- **A3** — kein `Color(...)` außerhalb von `palette.gd`
- **B7** — kein `rotation.y` außerhalb von `ship.gd`

Beide Regeln stehen hier, weil ihre Verletzung im laufenden Spiel *nicht auffällt*: Eine
falsche Farbe sieht nur etwas anders aus, ein direkt gelesenes `rotation.y` liefert einen
plausiblen, aber gespiegelten Winkel. Genau solche Fehler gehören in einen Linter.

---

*Lebendes Dokument. Neue Regeln entstehen aus Fehlern, nicht aus Vermutungen.*
