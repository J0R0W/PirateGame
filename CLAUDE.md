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

- **`docs/RICHTLINIEN.md`** — verbindliche Regeln für Gestaltung (A1–A11), Code (B1–B15) und
  Tests (C1–C7). Jede Regel steht dort mit dem konkreten Fehler, aus dem sie entstanden ist.
- **`docs/KONZEPT.md`** — Vision, Systeme, Roadmap (M0–M7), Abschnitt 10 „Stand" und
  Abschnitt 11 „Nächste Schritte". Wird mit jedem Meilenstein fortgeschrieben.
- **`docs/STORY.md`** — Story-Konzept: Prämisse, Herkunft, Akte, Pfade, Mehrspieler-Ausblick.
  Optionaler Erzählstrang über der Sandbox aus `KONZEPT.md` 1, kein Ersatz dafür.
- **`docs/SCHIFFE.md`** — wie eine neue Schiffsklasse entsteht: Recherche, Maßstab, `.tres`,
  Spantenriss, Rigg, Beschläge, Prüfung. Abschnitt 13 ist die Liste der Fallen, alle einmal
  passiert; Abschnitt 14 die Vorschläge, was der Werkbank als Nächstes fehlt.

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
godot --path . res://tests/capture_sailing.tscn   # Segelmodus, 9 Aufnahmen (auch Abend, Nacht, Regen) + Bildrate
godot --path . res://tests/capture_battle.tscn    # Seegefecht: Sichtung, längsseits, Salve, Einschlag, Prise, Jäger
godot --path . res://tests/capture_ship.tscn      # Schiffsmodell aus vier Winkeln, dazu bei Nacht
godot --path . res://tests/capture_island.tscn    # Küste: normal, ohne Dunst, ohne Wasser, Drahtgitter
godot --path . res://tests/capture_town.tscn      # Siedlung aus drei Abständen
godot --path . res://tests/capture_port.tscn      # Hafen: Markt, Kauf, Werft, Palast, Auftrag, Schenke
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
godot --path . res://tests/rig.tscn                         # Takelage fahren: Wind drehen, Rah und Flagge beobachten
```

`tests/rig.tscn` braucht ein Fenster und beantwortet genau eine Frage: Stehen Rah, Segel und
Flagge richtig zum Wind? Der Wind ist dort festgenagelt und wird mit den Pfeiltasten gedreht
(G wechselt die Schiffsklasse, N die Flagge, L lässt den Wind wieder laufen). Die Szene ist
der Segelmodus selbst, nur ohne Begegnungen — eine eigene Bühne hätte genau die Fehler
versteckt, die man dort sucht. Die Zahlen links im Bild sind der Messwert:
**Rahstellung in Grad.**

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
| `Standing` | Was eine Nation vom Spieler hält — und was daraus folgt |
| `Diplomacy` | Wer mit wem Krieg führt — aus Seed und Spieltag gerechnet, nicht gehalten |
| `LetterOfMarque` | Der Kaperbrief: wer ihn ausstellt, was er deckt, was er kostet |
| `Adversary` | Ein benannter Kapitän auf einem bestimmten Schiff — die Grundlage von Auftrag und Kopfgeld |
| `Commission` | Der Auftrag des Gouverneurs: Steckbrief, Frist, Lohn |
| `Bounty` | Wann eine Krone einen Jäger schickt, auf welchem Schiff und mit wieviel Gold |
| `ShipAI` | Die Entscheidungen eines KI-Kapitäns (statisch), der Node reicht sie nur weiter |
| `TradeMath` | Preisbildung aus Lagerbestand |
| `Tavern` | Handgeld und Gerede: was ein Mann kostet, was man sich erzählt |
| `OceanWaves` | Wellenfeld — **doppelt vorhanden**, siehe unten |
| `TerrainChunk` | Chunk-Meshbau und die gezeichnete Oberflächenhöhe |
| `HullMesh` | Rumpfbau aus einem Spantenriss — Außenhaut, Deck, Steven, Spiegel |
| `Skylight` | Der Himmel: Sonnenstand, Mond, Dunst und **Sicht** aus Uhrzeit und Wetter |
| `ShipTextures` | Die gerechneten Graustufenmasken für Planken und Segeltuch |
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

### Der Ruf entscheidet, wer schießt

**Bis M6 griff jede Patrouille jeden an.** Ansehen wurde geführt (`GameState.reputation`,
−100 bis +100 je Nation) und von Prisen verändert, aber **nichts las es je aus** — ebenso
wenig `NationData.aggression` und `reputation_sensitivity`, die seit M2 in allen vier
`.tres`-Dateien stehen.

`Standing` beantwortet drei Fragen, alle nodefrei und ohne Szene prüfbar:

| Frage | Antwort |
|---|---|
| `port_open(level)` | Erst bei **feindlich** macht der Hafen zu, nicht schon beim Misstrauen |
| `hunts_player(level, aggression)` | Feindlich: immer. Misstrauisch: nur eine Nation, die schnell zur Sache kommt |
| `weighted_change(amount, sensitivity)` | Spanien (1,2) nimmt dieselbe Prise schwerer als die Niederlande (0,8) |

**Ein Kapitän braucht einen Grund.** `ShipAI.wants_battle()` ist `hostile or provoked`, und
**beide** Fragen hängen daran: der Gefechtskurs (`stance`) *und* das Feuer (`_shoot`). Als
die getrennt gerechnet wurden, floh ein provozierter Kapitän und schoss dabei — er lief
davon und feuerte nach hinten. `hostile` setzt `NavalCombat` aus dem Ruf, `provoked` das
Beschossenwerden.

Ein Handelsschiff jagt nie, auch wenn seine Krone den Spieler sucht — es flieht und wehrt
sich nur.

### Der Kaperbrief ist die Gegenrichtung

Der Ruf konnte danach immer noch nur **fallen**. Jede Prise kostete Ansehen, nichts brachte
je welches ein — wer lange genug spielte, stand irgendwann bei allen vier Kronen unten und
hatte keinen Hafen mehr. `LetterOfMarque` macht daraus eine Entscheidung: Wer einen Brief
trägt, dem schreibt seine Krone jede Prise gegen ihren **Kriegsgegner** gut (+5).

| | |
|---|---|
| Ausgestellt ab | *gleichgültig* — nicht erst ab *wohlgesonnen*, sonst wäre er ein Preis dafür, das System schon zu kennen |
| Ausgestellt wo | Stadt oder Hauptstadt (`has_seat`). Ein Dorf hat keinen Gouverneur |
| Kostet | kein Gold, sondern −5 Ansehen bei **jeder** der übrigen drei Kronen |
| Davon gibt es | genau einen. Vier Briefe wären vier Freunde und keine Wahl |

**Der Seitenwechsel braucht keine eigene Regel.** Wer einen zweiten Brief annimmt, dessen
bisheriger Patron ist ab dem Moment eine der übrigen Kronen und bucht denselben Verlust wie
sie — ein Wechsel kostet damit von selbst mehr als der erste Brief.

**Zurückgeben ist frei, Verrat nicht.** Einen Auftrag niederzulegen schadet niemandem.
Wer dagegen das Schiff des eigenen Auftraggebers aufbringt, verliert den Brief auf der
Stelle und zahlt obendrauf (−12).

**Unterm Strich bleibt Kapern ein Verlust:** Der Patron schreibt +5 gut, der Bestohlene
bucht −8 ab. Der Brief verschiebt nur, *wo* der Verlust anfällt. Ohne dieses Gefälle wäre
er ein Freibrief statt einer Entscheidung — der Rauchtest hält es fest.

**Gedeckt ist genau eine Flagge, und welche, steht nicht fest.** Bis M6 deckte der Brief
alles außer der eigenen Krone — das ist ein Freibrief und keine Entscheidung. Seit es
Kriege gibt (`Diplomacy`, unten), deckt er den Kriegsgegner des Patrons und sonst niemanden.
Damit sucht man sich mit dem Patron zugleich sein Jagdrevier aus — und ein Friedensschluss
verschiebt es, ohne dass man etwas getan hätte.

Die Regel selbst (`LetterOfMarque.covers`) bekommt den Gegner als Parameter und schlägt ihn
nicht selbst nach — sie soll ohne Welt und ohne Uhr prüfbar bleiben (Regel B3). Wer mit dem
laufenden Spiel fragt, nimmt `GameState.letter_covers()`; Anzeige und Buchung fragen
dieselbe Funktion, sonst schreibt das HUD „wird gutgeschrieben" über eine Prise, die
niemand gutschreibt.

Sichtbar an drei Stellen (Regel A8): im **Gouverneurspalast** (`ui/port/governor_panel.gd`),
in der **Legende der Seekarte** neben der Nation, für die man fährt, und in der
**Prisenmeldung** auf See.

### Der Auftrag ist der Grund, der Brief nur die Erlaubnis

Der Kaperbrief zählte seine Prisen mit, und **die Zahl hing an nichts.** Ein Auftrag ist
das, woran sie hängt: Der Gouverneur der eigenen Patronskrone hängt einen Steckbrief aus —
Kapitän, Schiff, Flagge, acht Spieltage Frist.

**Bezahlt wird an Land.** Wer den Benannten aufgebracht *oder versenkt* hat, muss zurück in
eine Stadt seiner Krone und Bericht erstatten (`GameState.report_commission`). Das ist die
erste Schleife im Spiel, die nicht auf See endet — und der erste Anlass, einen *bestimmten*
Hafen anzulaufen statt des nächstbesten.

| | |
|---|---|
| Voraussetzung | Ein Kaperbrief dieser Krone. Ohne ihn vergibt kein Gouverneur etwas |
| Bringt | Gold (400 → 2400, steigt mit jedem Bericht) und **+10 Ansehen** beim Patron |
| Kostet ein Fehlschlag | −4 beim Patron. Ohne Gegenseite wäre die Annahme ein Knopf ohne Entscheidung |
| Ziel ab dem dritten | Eine **Fregatte** (`resources/ships/frigate.tres`) — vierzehn Rohre, dreht träge |

**Der Auftrag ist die einzige Tat, bei der das Ansehen unterm Strich steigt.** Bloßes
Kapern unter dem Brief bleibt ein Verlust (+5 gegen −8); der Auftrag steht bei +10 gegen
−8. Der Unterschied ist der zwischen *geduldet* und *beauftragt* — und die Bezahlung dafür,
gegen ein Kriegsschiff zu fahren statt gegen einen Frachter. Bei +8 wäre es ein
Nullsummenspiel gewesen, das erst die Gutschrift des Briefs zum Gewinn macht; der Rauchtest
hält jetzt das Einfache fest.

**Der Steckbrief wird gerechnet, nicht gehalten.** Der Würfel hängt an Seed, Krone und der
Zahl der *eingelösten* Aufträge (`Commission.offer`). Damit steht bei jedem Blick derselbe
Mann da, ohne gespeichertes Angebot — und wer eine Frist verstreichen lässt, bekommt
denselben Mann noch einmal ausgeschrieben. Ein Gesuchter bleibt gesucht, bis ihn jemand
bringt.

**Der Brief trägt den Auftrag.** Rückgabe oder Seitenwechsel lassen einen offenen Auftrag
liegen und werden angerechnet — sonst wäre die Rückgabe der Schlupfweg aus jeder Frist.
Beim Einzug nach Verrat entfällt die zweite Rechnung: `BETRAYAL_COST` hat sie schon bezahlt.

### Und dieselbe Mechanik von der anderen Seite

`Bounty` ist `Commission` mit umgekehrtem Steckbrief. Beide setzen denselben `Adversary` —
einen Kapitän mit Namen, absichtlich gesetzt statt aus dem Zufall gespült
(`NavalCombat._place_named`; höchstens einer gleichzeitig, und er zählt nicht gegen
`max_ships`).

**Berüchtigtheit kostet zum ersten Mal etwas.** Sie wuchs seit M4 mit jeder Prise und sank
nie, tat aber nur eines: Gegner strichen früher die Flagge. Ab 35 Punkten schickt eine
**feindliche** Krone einen benannten Jäger — nicht schon eine misstrauische, die schickt
ohnehin Patrouillen. Ab 65 kommt er auf einer Fregatte.

**Sein Vorschuss ist das eigene Kopfgeld** (`Bounty.purse`). Damit ist der Mann, den man am
wenigsten treffen will, zugleich die beste Prise auf See. Nach einem erledigten Jäger sind
vier Minuten Ruhe, sonst käme ein berüchtigter Kapitän nie mehr zum Handeln.

**Ein Auftragsziel wird erkannt, nicht wiedergefunden.** `Adversary.is_ship()` vergleicht
Name und Flagge, nicht die Objektidentität: Zwischen Annahme und Treffen liegen Häfen und
Szenenwechsel, und der Node von vorhin ist dann längst weg.

### Vier Kronen, zwei Kriege

`Diplomacy` ist der einzige neue **Weltzustand** aus M6 — und trotzdem steht er in keinem
Spielstand: Die Lage ist eine reine Funktion aus Weltseed und Spieltag, genau wie der
Steckbrief im Palast.

**Zu jeder Zeit liegt jede Krone mit genau einer anderen im Krieg.** Vier Nationen lassen
sich auf genau drei Arten so paaren; die Lage ist immer eine dieser drei. Das ist an beiden
Enden enger als „jeder gegen jeden nach Würfel", und das mit Absicht:

- Ein **allgemeiner Friede** schaltete Kaperbrief und Auftrag ab, also das halbe Spiel — und
  der Spieler hätte nichts in der Hand dagegen.
- Ein **allgemeiner Krieg** wäre der Zustand von vorher: ein Brief, der alles deckt.

Die Paarung ist die interessante Mitte. Der Brief deckt genau eine Flagge, und welche das
ist, sucht man sich mit dem Patron aus.

| | |
|---|---|
| Wechselt alle | 24 Spieltage (`ERA_DAYS`) — dreimal die Frist eines Auftrags, damit ein Krieg die Jagd überdauert, die unter ihm begonnen wurde |
| Und dann | **wirklich**: Der Schritt durch die drei Lagen ist immer eins oder zwei, nie null. Jede Krone bekommt dabei einen anderen Feind |
| Wirkt auf | was der Kaperbrief deckt (`LetterOfMarque.covers`) und wen der Gouverneur ausschreibt (`Commission.offer`) |

**Ein laufender Auftrag überlebt den Friedensschluss.** Der Gouverneur hat den Mann
ausgeschrieben, und ein Steckbrief wird nicht dadurch gegenstandslos, dass die Kronen sich
vertragen — im Gegenteil: Wer danach weiterkapert, ist für beide Seiten ein Pirat. Die
Alternative wäre gewesen, ihn zu annullieren; dann verlöre etwa jeder dritte Auftrag durch
einen Würfel, den der Spieler nicht sieht.

Sichtbar an drei Stellen (Regel A8): in der **Zeile über der Seekarte** (wer gegen wen), im
**Gouverneurspalast** (was der Brief deshalb deckt), in der **Schenke** (dasselbe als
Gerede) — und als **Meldung im HUD** an dem Tag, an dem neu verhandelt wird. Ohne die
Meldung fände man erst beim nächsten Aufbringen heraus, dass der Brief eine andere Flagge
deckt als gestern.

### Die Schenke ist, wo man erfährt, wohin

Der vierte Hafenbildschirm (`ui/port/tavern_panel.gd`). Zwei Dinge stehen dort:

**Anheuern**, aus der Werft hierher gezogen — der Kommentar dort sagte seit M4 selbst, dass
es nicht dorthin gehört. Die Rechnung ist dieselbe geblieben und hat einen zweiten Grund
bekommen: **Berüchtigtheit senkt das Handgeld** (`Tavern.FAME_DISCOUNT`, bis zu einem
Drittel). Das ist die erste Folge dieser Achse, die dem Spieler *nützt* — bis dahin hat sie
ihm nur Jäger geschickt. Eine Achse, die nur kostet, ist so wenig eine Entscheidung wie
eine, die nur hilft.

**Das Gerede**, und das ist der eigentliche Grund für den Bildschirm. Ein Auftragsziel wurde
bis M6 einfach in Sichtweite gesetzt, egal wo man fuhr — man konnte einen Auftrag nicht
*suchen*, nur abwarten:

| Gerücht | Wann |
|---|---|
| Politik | immer — wer mit wem Krieg führt, und was der eigene Brief deshalb deckt |
| Der Gesuchte | mit laufendem Auftrag: **vor welchem Hafen er kreuzt** |
| Der Jäger | wenn eine feindliche Krone ein Kopfgeld ausgesetzt hat (`Bounty.due`) |
| Handel | welche Ware von hier in einem Nachbarhafen gut bezahlt wird (`Tavern.trade_tip`) |
| Über dich | ab 15 Punkten Berüchtigtheit |

**Der Gesuchte kreuzt jetzt irgendwo.** Bei der Annahme wird sein Revier festgelegt
(`Commission.waters_for`): der Hafen seiner eigenen Flagge, der dem Ort der Zusage am
nächsten liegt. `NavalCombat` setzt ihn nur innerhalb von 3000 m davon (`WATERS_RANGE`,
deutlich mehr als `DESPAWN_DISTANCE` — sonst führe man ihm während der Verfolgung aus
seinem eigenen Revier heraus); außerhalb bleibt der Platz frei und der Kopfgeldjäger rückt
nach.

**Das Revier steht nicht auf dem Steckbrief.** Der Palast sagt, *wer* gesucht wird, und
verweist auf die Schenke; der Wirt sagt, *wo*. Erst danach steht der Ort auf der Seekarte
(`Commission.waters_known` — das einzige Bit Zustand, das der Besuch hinterlässt). Ohne
diese Trennung wäre die Schenke ein Bildschirm, den niemand je öffnen müsste.

Ohne Revier — ein Auftrag aus einem Spielstand vor Version 5, oder einer, der außerhalb
eines Hafens angenommen wurde — kreuzt er überall, also genau wie vorher.

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

### Der Rumpf ist ein Spantenriss, keine Szene

Die Karavelle (`entities/ship/models/`) ist das erste Schiff mit eigenem Modell und der
Bauplan für alle weiteren. Wer die Form ändert, ändert die Zahlentabelle `STATIONS` —
neun Querschnitte, dazwischen strakt `HullMesh`.

**Zwei Flächen, zwei Materialien.** Außenhaut und Deck kommen als getrennte Surfaces
heraus, weil die Planken verschieden laufen: längs des Rumpfes um den Spant herum, quer
über das Deck von Bord zu Bord. Deshalb setzt niemand ein `material_override` auf ein
Mesh aus `HullMesh` — es übermalte beide mit demselben.

**Texturen sind Graustufenmasken und werden gerechnet** (Regel A11): `ShipTextures`
zeichnet Plankenfuge und Segelnaht als Helligkeit, die Farbe kommt weiter aus der
Palette. **UV-Koordinaten sind Meter** — eine Kachel ist ein Meter, damit dieselbe
Textur auf Rumpf, Deck und Tuch dieselbe Plankenbreite ergibt.

**Ein Rumpf wird von innen geprüft** (Regel C7): Der Rauchtest schießt aus drei Punkten
im Inneren je sechs Strahlen und verlangt, dass überall etwas im Weg steht. So kam die
fehlende Heckwand der Kajüte heraus, und so käme die nächste heraus.

### Ein Schiff ist eine Tabelle, kein Programm

`ShipModel` (`entities/ship/models/ship_model.gd`) ist die Werkbank aller Modelle: Straken,
Masten mit Wanten und Stagen, Lateinersegel, Anker, Spill, Luke, Drehbassen, Laterne,
Taue, Materialien. Ein Modell erbt davon und beschreibt sich in Tabellen — `stations()`,
`masts()`, und in `_assemble()` die Beschläge mit ihren Positionen. Was ein Anker ist,
weiß die Werkbank; **ein neuer Beschlag kommt dorthin, nie ins Modell**, sonst kopiert ihn
das zweite Schiff.

Drei Fragen beantwortet ein Modell dem Rauchtest selbst, damit derselbe Test über jedes
künftige Schiff läuft: `hull_parts()` und `interior_probes()` (Regel C7, Dichtheit von
innen) und `gun_count()` — was das Modell aufstellt, muss `cannon_slots` treffen.

Ein Aufbau überschreibt genau `_rail_point()` und `_mast_foot()` (achtern gilt die Reling
des Achterdecks) und ruft sonst `super()`.

### Der Himmel wandert, und die Laterne weiß es

Bis hierher stand die Sonne fest und `WorldData.weather` las niemand. `Skylight` rechnet
aus `GameState.time_of_day()` und Wetter alles, was der Segelmodus je Bild in Sonne und
Umgebung schreibt (`_update_skylight`): Sonne auf im Osten um sechs, unter im Westen um
achtzehn, nachts ein Mond gegenüber, Dunst dunkel statt dicht. **Ein Spieltag dauert vier
Minuten**, die Nacht ist deshalb mondhell und nicht schwarz. Eine Kampagne beginnt um
acht Uhr (`GameState.START_MINUTES`) — mit dem alten Startwert null begänne sie im Dunkeln.

`WorldData.visibility()` (0 bis 1) ist die daraus gewonnene Zahl, die alles liest, was auf
Sicht reagiert. Heute ist das die **Laterne** (`Lantern`, dritter Knotentyp neben `Rig` und
`Flag`): `Ship._update_lanterns()` zündet unter 0,45 an und löscht erst über 0,6 — zwei
Schwellen, sonst flackert es in der Dämmerung. Sturm und Regen liegen darunter, also
brennt sie auch mittags. Das Wetter setzt bislang nur das Debug-Menü (Abschnitt
**Himmel**: Uhrzeit, Uhr anhalten, Wetter); eine Wetteruhr ist KONZEPT 5.6.

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
- kein `rotation.y` außerhalb von `ship.gd` (außer mit `# kein Kurs`) — die Sonne wird
  deshalb über `Basis.looking_at()` gestellt
- Geländematerial rendert beidseitig und nutzt Vertex-Farben
- die Aufsetzhöhe trifft das gezeichnete Mesh auf den Millimeter

Dazu prüft `_check_everything_loads()`, dass jedes Skript wirklich *kompiliert* — `load()`
liefert bei einem Parse-Fehler trotzdem ein Objekt zurück, nur eben ein nicht kompiliertes;
`can_instantiate()` unterscheidet das.

## Vier Godot-Fallen, die niemand sieht

- **Vertex-Farben sind linear, nicht sRGB.** Für Mesh-Arrays immer `Palette.for_vertex()`,
  sonst sehen die Inseln aus wie Schneefelder.
- **Transform-Basen stehen in `.tscn` zeilenweise.** Eine spaltenweise gerechnete
  Rotationsmatrix landet dort transponiert — also als ihre Umkehrung.
- **`custom_minimum_size` ist eine Untergrenze, keine Obergrenze.** Ein umbrechendes Label
  in einem dehnbaren Container nimmt sich die ganze Breite. Für Lesebreite zusätzlich
  `size_flags_horizontal = Control.SIZE_SHRINK_BEGIN`.
- **`queue_free()` wirkt erst am Bildende.** Ein KI-Kapitän entscheidet in der Lücke noch
  einmal — und feuert. Erst `set_physics_process(false)`, dann freigeben.

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
