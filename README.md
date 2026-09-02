# PirateGame

Ein Piraten-Sandbox-Spiel in der Tradition von *Sid Meier's Pirates!*, gebaut mit Godot 4.7.
3D-Präsentation, prozedural erzeugte Karibik, eigene Systeme statt originalgetreuem Nachbau.

**Status:** M4 abgeschlossen, M5 angefangen — es gibt eine Spielschleife und ein Gefecht.
Segeln, in einem Hafen anlegen, günstig kaufen, woanders teuer verkaufen, das Schiff instand
setzen, Leute anheuern — und unterwegs ein fremdes Segel längsseits nehmen. Seit Neuestem auf
zwei Wegen: zusammenschießen, bis die Flagge fällt, oder übersetzen und es an Deck ausfechten.
Seit Neuestem reagiert die Welt: Wer eine Nation ausplündert, wird von ihren Patrouillen
gejagt und aus ihren Häfen ausgesperrt — und wer sich beim Gouverneur einen Kaperbrief holt,
dem schreibt dessen Krone jede Prise gegen ihren Kriegsgegner gut. Denn die vier Kronen haben
ein Verhältnis zueinander: Jede liegt mit genau einer anderen im Krieg, und alle 24 Spieltage
wird neu verhandelt. Derselbe Gouverneur hängt Steckbriefe aus: einen benannten Kapitän
stellen, zurückfahren, Bericht erstatten — wo der Mann kreuzt, erfährt man nebenan in der
Schenke, in der man auch anheuert. Wer sich dabei genug Feinde macht, wird selbst
ausgeschrieben und bekommt einen Kopfgeldjäger auf den Hals. Offen aus M5: der Schiffskauf
und die Übernahme einer Prise — und damit der eigentliche Aufstieg.

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

718 Prüfungen: Autoloads, Eingabebelegung, Kampagnenstart, Speicher-Roundtrip,
Segelmathematik, Winkelkonvention, Wellenfeld, Schiffsgeometrie, Weltgenerierung
(Landanteil, Weltrand, Hafenabstände, Nationsbesitz, Determinismus), Ankerplätze,
Stadtterrassen, Siedlungen, Preisbildung, Handel, Werft, Anheuern und Gerüchte in der
Schenke, Fahrbarkeit unter der
Mindestbesatzung, Ballistik, Vorhalten, Trefferentscheid, Trefferzonen, Schiffs-KI, Prisen,
Enterkämpfe, Ruf und seine Folgen, Krieg und Frieden zwischen den Kronen, Kaperbriefe,
Gouverneurs-Aufträge samt dem Revier des Gesuchten, Kopfgeldjäger, die
Stellschrauben des Debug-Menüs sowie
Gelände-Chunks, Grundberührung, Projektregeln und die Frage, ob überhaupt jedes Skript
kompiliert.

Darunter die Abnahmebedingungen der Meilensteine selbst, gefahren statt behauptet:

- **M3** — 20 Ballen Tabak im billigsten Hafen kaufen, im teuersten verkaufen. Die Fahrt
  muss Gewinn abwerfen, die Route rückwärts Verlust.
- **M4** — zweimal dasselbe Gefecht mit demselben Würfel, einmal mit einem Kapitän, der
  den Gegner querab hält, einmal mit einem, der drauflosfährt. 123 gegen 18 Punkte
  Schaden, und nur der erste zwingt den Gegner zur Flagge.
- **M5 (teilweise)** — ein Gegner wird wirklich geentert: längsseits gehen, übersetzen, das
  Deck nehmen, und danach liegt er als Prise da statt als Enterziel. Die Enterhaken bleiben
  danach eine Weile unklar.
- **M6 (teilweise)** — ein Kaperbrief wird ausgestellt, eine wirklich genommene Prise gegen
  Englands Kriegsgegner kommt beim englischen Patron an, eine gegen eine Krone im Frieden
  nicht, und die englische Prise danach kostet den Brief. Dazu ein Auftrag von Anfang bis
  Ende: Der Benannte läuft in seinem Revier aus — und nur dort —, wird längsseits genommen
  und beim Gouverneur gemeldet. Und ein Kopfgeldjäger fährt aus, sobald Berüchtigtheit und
  Feindschaft zusammenkommen.

Das Gefecht wird dabei wirklich gefahren — zwei volle Duelle im Zeitraffer, deshalb
dauert der Durchlauf gut eine halbe Minute. Exit-Code 0 = bestanden.

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
godot --path . res://tests/capture_battle.tscn
```

Zeigt eine Küste vier Mal (vollständig, ohne Dunst, ohne Wasser, Drahtgitter), eine
Siedlung aus drei Abständen, den Hafenbildschirm mit Markt, Kauf, Werft, Schenke und
Gouverneurspalast (ohne Kaperbrief, mit Brief, mit ausgehängtem Steckbrief, mit bekanntem
Revier und mit erledigtem Auftrag) sowie ein Seegefecht in seinen Schritten (Segel in Sicht, längsseits,
Breitseite, Einschlag, Entern, Prise, Kopfgeldjäger).
Damit lässt sich unterscheiden, ob ein Darstellungsfehler vom Gelände, vom Wasser oder von
der Atmosphäre kommt — und ob Häuser wirklich auf dem Hang stehen.

Die Gefechtsaufnahme ist kein Luxus: Pulverdampf, fliegende Kugeln und Wassersäulen
entstehen erst beim Rendern, und die erste zeigte offene See, weil der Gegner querab lag
und die Kamera nach vorn sah.

```bash
godot --path . res://tests/duel.tscn              # spielen
godot --headless --path . res://tests/duel.tscn   # messen
```

Ein Seegefecht auf Knopfdruck. **Mit Fenster** steht man laengsseits eines Gegners auf
offener See, und es geht sofort los — kein Auslaufen, kein Warten auf ein zufälliges Segel.
**R** setzt einen frischen Gegner, **G** wechselt seine Klasse, **H** die Ausgangslage
(längsseits, achteraus, entgegenkommend). Jede Breitseite wird mitgeschrieben, mitsamt der
Abweichung von querab — daran sieht man, *warum* eine Salve vorbeiging.

**Ohne Fenster** fahren KI gegen KI fünfzehn Gefechte im Zeitraffer und am Ende steht eine
Tabelle: Dauer, Salven, Trefferanteil, Schaden, Anteil der Zeit mit anliegender Breitseite,
gestrichene Flaggen. Das ist das Messgerät für alles, was am Gefecht eingestellt wird —
Balancewerte werden gefahren, nicht geschätzt.

## Struktur

| Ordner | Inhalt |
|---|---|
| `autoload/` | Singletons: `EventBus`, `GameState`, `WorldData`, `SceneRouter`, `SaveManager`, `AudioDirector` |
| `data/` | Resource-Klassen (`ShipClass`, `TownData`, `NationData`, `CargoType`, `OfficerData`), Palette, Warenverzeichnis |
| `resources/` | Konkrete `.tres`-Instanzen — Nationen, Waren, Schiffsklassen. Hier wird balanciert, nicht im Code |
| `world/` | Weltgenerierung, Gelände-Chunks mit Streaming, Ozean-Shader und Wellenformel, Siedlungen, Wirtschaft, Gefecht |
| `modes/` | Die Modus-Szenen: `sailing`, `port`, `boarding`, `menu` |
| `entities/` | Schiffe und ihre Kapitäne |
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
- **Erst das Ergebnis, dann der Flug** — eine Breitseite wird beim Abfeuern ausgewürfelt,
  die Kugeln fliegen danach zu einem Ausgang, der schon feststeht.
- **Die Wellenformel existiert doppelt** — `OceanWaves` und `ocean.gdshader` müssen
  synchron bleiben, sonst schwebt das Schiff über der sichtbaren See.
- **Die Kamera zeigt, worauf es ankommt** — wo eine Regel den Spieler zwingt, etwas
  seitlich zu halten, muss die Kamera davon wissen. Sonst ist das Gefecht unsichtbar.

Vier davon prüft der Rauchtest automatisch: die Palette, die Winkelkonvention, das
beidseitige Gelände und die Aufsetzhöhe. Es sind die vier, deren Verletzung im laufenden
Spiel *nicht* auffällt — eine falsche Farbe sieht nur etwas anders aus, ein direkt
gelesenes `rotation.y` liefert einen plausiblen, aber gespiegelten Winkel. Der Rest fällt
auf, sobald man hinsieht.

## Steuerung

| Taste | Aktion |
|---|---|
| A / D | Ruder backbord / steuerbord |
| W / S | Segel setzen / reffen |
| Mausrad | Kamera heran und weg |
| Q / E | Breitseite backbord / steuerbord |
| Leertaste | Anlegen — eine gestrichene Flagge aufbringen — oder einen Gegner entern, der noch kämpft |
| M | Seekarte |
| F3 | Debug-Menü |
| Esc | Offenes Fenster schließen, sonst zurück ins Menü |

Die beiden Zeilen unten in der Mitte sagen, was die Batterien tun: *lädt* mit Prozent,
*bereit*, oder **liegt an** in Grün — dann bekommen die Rohre den Gegner auch wirklich.
Die Geschütze schwenken nur zwanzig Grad um querab: Bug und Heck bleiben leer, und wer
schräg steht, sieht seine Salve vorbeigehen, statt getroffen zu haben. Näher heran heißt
genauer, und ein Gegner, der sich einem zudreht, ist ein schmaleres Ziel als einer, der
längsseits liegt.

Belegt, aber noch ohne Wirkung: **F** (Fernrohr), **T** (Zeitraffer).

**F3 — Debug-Menü.** Drei Größen, auf die man beim Ausprobieren sonst am längsten wartet:
Windrichtung und -stärke (mit „festhalten", sonst dreht der Wind den Regler wieder weg),
ein Fahrtfaktor fürs eigene Schiff, sowie Abstand und Höchstzahl fremder Segel samt einem
Knopf, der sofort eines setzt. Dazu ein Schalter für das Gitternetz auf dem Wasser. Nichts
davon landet in einer Speicherdatei; der Knoten fällt vor einem Release aus
`modes/sailing/sailing_mode.tscn`.

Im Hafen: **Markt**, **Werft**, **Schenke**, **Gouverneur**, **Speichern**, **Ablegen** —
oder **Esc** zum Auslaufen. Die Werft setzt Rumpf und Segel instand, die Schenke heuert
Mannschaft an; beides geht auch anteilig, wenn das Gold nicht für alles reicht. In der
Schenke steht außerdem, was man sich erzählt: wer mit wem Krieg führt, wo der Gesuchte
kreuzt, wer ein Kopfgeld auf einen ausgesetzt hat und wo eine Ware von hier gut bezahlt
wird. Beim Gouverneur steht, was seine Krone von einem hält; dort gibt es den Kaperbrief und
darunter den Auftrag. In einem Dorf sitzt keiner — der erste Grund im Spiel, eine größere
Stadt anzulaufen, der nichts mit Preisen zu tun hat.
