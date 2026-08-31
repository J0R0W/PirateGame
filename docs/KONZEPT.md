# Projektkonzept — Arbeitstitel "PirateGame"

Ein Piraten-Sandbox-Spiel in der Tradition von *Sid Meier's Pirates!*, gebaut mit **Godot 4.7**.
3D-Präsentation im Stil des 2004er-Remakes, prozedural erzeugte Karibik, eigene Systeme statt
originalgetreuem Nachbau.

**Status:** M4 abgeschlossen · **Engine:** Godot 4.7.1 stable · **Sprache:** GDScript

---

## 1. Vision

> Du bist Kapitän eines Schiffes in einer Karibik, die es so noch nie gab. Du segelst,
> handelst, kämpfst und intrigierst zwischen vier Kolonialmächten — und die Welt merkt sich,
> was du tust.

Kein Story-Spiel mit festem Ende, sondern eine **Sandbox mit Aufstiegskurve**: vom klapprigen
Einmaster zum gefürchteten Flottenführer. Jede Kampagne beginnt mit einem neuen Seed und damit
einer neuen Inselwelt, neuen Städten, neuen Machtverhältnissen.

### Design-Pillars

Vier Leitsätze. Jede Feature-Entscheidung wird an ihnen gemessen — passt sie zu keinem, fliegt sie raus.

| Pillar | Bedeutung |
|---|---|
| **Freiheit vor Führung** | Kein Questlog, das dich an die Hand nimmt. Die Welt bietet Gelegenheiten, du entscheidest. |
| **Lesbare Systeme** | Wind, Preise, Ruf — der Spieler soll die Regeln durchschauen und *planen* können. Keine versteckten Würfe. |
| **Kurze Sitzungen, lange Kampagne** | Ein Handelszug, ein Gefecht, ein Hafenbesuch — jeweils 5–15 Minuten. Alles ist ein sauberer Ausstiegspunkt. |
| **Konsequenz statt Bestrafung** | Ein verlorenes Gefecht beendet nicht den Lauf. Es verändert ihn — weniger Crew, schlechterer Ruf, neue Feinde. |

### Bewusste Abgrenzung zum Original

Da eigene Ideen gewünscht sind, weicht dieses Konzept an vier Stellen ab:

- **Kein Fecht-Minispiel.** Stattdessen ein taktisches **Enter-Gefecht** an Deck (siehe 3.4) — passt
  besser zu 3D und lässt sich mit Crew-Fähigkeiten verzahnen.
- **Kein Tanz-Minispiel, keine Romanzen.** Die soziale Ebene läuft über Fraktionsbeziehungen und
  Offiziere statt über Gouverneurstöchter.
- **Kein Altern/Ruhestand als Zwangsende.** Stattdessen ein offener Lauf mit Legacy-Punkten beim
  freiwilligen Rückzug.
- **Crew ist eine Person, keine Zahl.** Siehe Signature Feature "Mannschaft & Meuterei".

### Ein optionaler Erzählstrang

Über der Sandbox liegt ein politisch-intriganter Handlungsstrang — Details in `docs/STORY.md`.
Er beginnt mit der Kampagne, lässt sich aber jederzeit ignorieren: Ein Dokument bringt den
Spieler zwischen die vier Kolonialmächte, drei Pfade (Kampf & Furcht, Diplomatie & Beziehungen,
Entdeckung & Wissen) führen zu einem Wendepunkt, der dauerhaft in `GameState` geschrieben wird —
danach läuft dieselbe offene Sandbox weiter. Kein Cutscene-Ende, kein Widerspruch zu "Kein
Story-Spiel mit festem Ende" oben: Der Strang schließt sich, das Spiel nicht.

---

## 2. Der Kern-Loop

```
                    ┌──────────────────────────────┐
                    │      SEGELN (Weltkarte)      │
                    │  Wind, Wetter, Ausguck-Kontakt │
                    └───────────┬──────────────────┘
                                │
              ┌─────────────────┼──────────────────┐
              ▼                 ▼                  ▼
      ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
      │   SEEKAMPF   │  │    HAFEN     │  │   ERKUNDUNG  │
      │ Manöver +    │  │ Handel,      │  │ Wracks, Buch- │
      │ Breitseiten  │  │ Aufträge,    │  │ ten, Gerüchte │
      └──────┬───────┘  │ Werft, Crew  │  └──────┬───────┘
             │          └──────┬───────┘         │
             ▼                 │                 │
      ┌──────────────┐         │                 │
      │    ENTERN    │         │                 │
      │ Deck-Taktik  │         │                 │
      └──────┬───────┘         │                 │
             │                 │                 │
             └────────┬────────┴─────────────────┘
                      ▼
            ┌───────────────────────┐
            │   BEUTE & AUFSTIEG    │
            │ Gold, Schiffe, Ruf,   │
            │ Offiziere, Ausbau     │
            └──────────┬────────────┘
                       │
                       ▼
            ┌───────────────────────┐
            │  WELT REAGIERT        │
            │ Preise, Patrouillen,  │
            │ Kopfgeld, Kriege      │
            └──────────┬────────────┘
                       │
                       └──────► zurück zum Segeln
```

**Die Schleife in einem Satz:** Du suchst eine Gelegenheit, verwandelst sie in Beute, investierst
die Beute in Fähigkeiten — und die Welt zieht daraus ihre eigenen Schlüsse.

---

## 3. Spielmodi

Jeder Modus ist eine **eigene Godot-Szene**. Der Wechsel läuft über einen zentralen `SceneRouter`
(siehe 7.2). Das ist der wichtigste Architekturentscheid des ganzen Projekts: Modi kennen einander
nicht, sie kennen nur den Router.

### 3.1 Segeln (Hauptmodus)

Die Welt, in der du dich 60 % der Spielzeit aufhältst.

- **Kamera:** Verfolgerkamera hinter/über dem Schiff, per Mausrad zoombar von "Deckansicht" bis
  "taktische Übersicht".
- **Steuerung:** Ruder links/rechts (A/D), Segelstellung in Stufen (W/S: gerefft → halb → voll).
  Keine direkte Geschwindigkeitskontrolle.
- **Wind ist das Kernsystem.** Windrichtung und -stärke ändern sich langsam über die Zeit. Deine
  Geschwindigkeit ergibt sich aus dem Winkel zum Wind:
  - *Raumschots/vor dem Wind* (Wind von hinten/schräg hinten): schnell
  - *Am Wind* (schräg gegenan): langsam, aber möglich
  - *In Irons* (direkt gegenan, ±30°): fast Stillstand — du musst kreuzen
- **Zeit:** 1 Realsekunde ≈ 2 Spielminuten, mit Zeitraffer 4×/16× auf leerem Meer. Zeitraffer
  bricht automatisch ab bei Schiffskontakt, Landsicht oder Wetterwechsel.
- **Ausguck:** Kontakte erscheinen zuerst als Segelspitze am Horizont, Identifikation (Nation,
  Größe) erst bei Annäherung — mit Fernrohr früher.

### 3.2 Seekampf

Startet nahtlos aus dem Segeln, kein Ladebildschirm, kein separates Kampfareal.

- **Manöver schlägt Feuerkraft.** Ziel ist, den Gegner in die eigene Breitseite zu bekommen und
  seiner auszuweichen. Wind bleibt aktiv und ist die Hauptvariable.
- **Die Entfernung entscheidet, was man trifft.** Auf kurze Distanz liegt die Bahn flach und
  schlägt in die Bordwand; von weit her kommt die Kugel von oben durch die Takelage. Daraus
  folgt die Entscheidung, die man im Gefecht dauernd trifft: Abstand halten und die Segel
  zerlegen, oder rangehen und den Rumpf brechen.
- **Schadensmodell** an drei Werten statt einer HP-Leiste: **Rumpf** (Sinken), **Segel**
  (Geschwindigkeit), **Mannschaft** (Nachladezeit + Enterstärke). Ein Schiff, das du versenkst,
  bringt keine Beute — wer reich werden will, zwingt den Gegner zur Flagge.
- **Nachladen** dauert neun Sekunden je Seite. Die andere Breitseite ist der Grund zu wenden.

> **Abweichung vom ursprünglichen Konzept:** Hier standen einmal drei Munitionstypen
> (Rundkugel, Kettenkugel, Kartätsche). Sie hätten dasselbe geleistet wie die Entfernung —
> Rumpf, Takelage oder Mannschaft treffen — aber über ein Menü statt über das Ruder. Die
> Entfernung ist die bessere Wahl: Sie kostet keine Bedienung, sie ist im Bild sichtbar,
> und sie belohnt Manövrieren statt Vorausplanung. Munitionstypen bleiben als spätere
> Verfeinerung möglich (Tier 2), sind aber kein Teil des Kerns mehr.

### 3.3 Hafen### 3.3 Hafen

Kein 3D-Rundgang durch die Stadt (Scope!), sondern eine **stimmungsvolle 2D/UI-Szene**: gemaltes
Hafenpanorama im Hintergrund, davor Gebäude als anklickbare Orte.

| Ort | Funktion |
|---|---|
| **Markt** | Waren kaufen/verkaufen, Preise abhängig von lokalem Angebot/Nachfrage |
| **Werft** | Reparatur, Umbau (Kanonen, Laderaum, Segel), Schiffskauf/-verkauf |
| **Werft (vorläufig)** | Auch Anheuern — gehört in die Taverne, steht aber schon hier, weil ein Gefecht seit M4 Leute kostet |
| **Taverne** | Crew anheuern, Gerüchte hören, Offiziere rekrutieren |
| **Gouverneurspalast** | Aufträge der Nation, Kaperbriefe, Beförderungen, Landbesitz |
| **Hehler** *(nur bei schlechtem Ruf)* | Beute ohne Fragen verkaufen, schlechterer Kurs |

Zugang zum Hafen hängt vom Ruf ab: Bei einer Nation, die dich jagt, kommst du nicht in den Hafen —
oder nur verkleidet unter falscher Flagge, mit Entdeckungsrisiko.

### 3.4 Enter-Gefecht *(Signature-Ersatz fürs Fechten)*

Wenn du ein Schiff längsseits nimmst: ein kompaktes, **rundenbasiertes Taktikgefecht** auf dem
Deck des Gegners.

- Kleines Gitterfeld (ca. 8×6) über dem Deck, 4–6 eigene Einheiten gegen die Verteidiger.
- Deine Einheiten sind **deine Offiziere plus Crew-Trupps** — sie haben Namen, sie können sterben.
- Wenige, klar lesbare Aktionen: Bewegen, Angreifen, Pistole (einmal pro Gefecht), Deckung.
- **Moral statt Auslöschung:** Verteidiger ergeben sich, wenn ihre Moral bricht — durch Verluste,
  durch den Tod ihres Kapitäns, durch deinen Ruf. Ein gefürchteter Pirat gewinnt Gefechte, ohne
  einen Schuss abzugeben.
- Dauer: 1–3 Minuten. Wird es länger, ist das Design falsch.

### 3.5 Erkundung

Kein eigener Modus im Sinne einer Szene, sondern **Punkte auf der Weltkarte**, die im Segelmodus
angelaufen werden: verlassene Buchten, Wracks, versteckte Siedlungen. Liefern Gold, Karten,
Crew-Mitglieder oder Gerüchte. Der Grund, warum es sich lohnt, vom kürzesten Weg abzuweichen.

---

## 4. Die prozedurale Karibik

Kernstück und größtes technisches Risiko. Deshalb hier konkret.

### 4.1 Grundprinzip

Ein **Seed** (Zahl) erzeugt deterministisch die komplette Welt. Die Welt wird **einmal beim
Kampagnenstart generiert**, das Ergebnis wird in den Spielstand geschrieben und danach nie wieder
neu berechnet. Das ist wichtig: Prozedural heißt hier "einmalig generiert", nicht "ständig
nachgeneriert" — das spart enorm viel Komplexität.

### 4.2 Generierungs-Pipeline

```
Seed
 │
 ├─► 1. HEIGHTMAP        FastNoiseLite (in Godot eingebaut!)
 │      Simplex-Noise, mehrere Oktaven, Domain-Warping für
 │      unregelmäßige Küsten. Ergebnis: 2048×2048 Höhenwerte.
 │
 ├─► 2. INSEL-MASKE      height > Schwelle = Land.
 │      Radialer Falloff am Rand → geschlossenes Meer, kein
 │      Land an der Weltgrenze.
 │
 ├─► 3. LANDMASSEN       Flood-Fill über die Maske → Liste von
 │      Inseln mit Fläche, Schwerpunkt, Küstenlinie.
 │      Inseln unter Mindestgröße = unbewohnte Felsen.
 │
 ├─► 4. STADTPLÄTZE      Kandidaten: Küstenpunkte mit tiefem
 │      Wasser davor (Hafenzugang) + flachem Land dahinter.
 │      Auswahl per Mindestabstand (Poisson-Disk-artig).
 │      Ziel: 25–40 Städte.
 │
 ├─► 5. NATIONEN         4 Startregionen per K-Means über die
 │      Stadtpositionen → jede Nation bekommt ein Kerngebiet.
 │      Danach 15 % der Städte zufällig umverteilt → verzahnte,
 │      konfliktträchtige Grenzen.
 │
 ├─► 6. NAMEN            Kuratierte Silben-/Namenslisten pro
 │      Nation (span./engl./frz./niederl. Klang).
 │
 └─► 7. WIRTSCHAFT       Jede Stadt bekommt Produktion & Bedarf
        (Tabak, Rum, Kakao, Holz, Gewürze, Kanonen, Stoffe...)
        abhängig von Inselgröße, Nation und Zufall.
        → erzeugt automatisch profitable Handelsrouten.
```

### 4.3 Darstellung in 3D

Der Punkt, an dem Performance entschieden wird:

- **Ozean:** Eine große Plane mit einem **Shader** (Gerstner-Wellen für Bewegung, Schaum an
  Küstenlinien). Kein Mesh mit Millionen Vertices.
- **Inseln:** Die Heightmap wird in **Chunks** (z. B. 64×64 Weltmeter) unterteilt. Nur Chunks im
  Umkreis der Kamera existieren als `MeshInstance3D`; weiter entfernte werden entladen oder durch
  ein grobes LOD-Mesh ersetzt. Das ist **Streaming** und ohne das läuft eine 2048²-Welt nicht.
- **Vegetation/Gebäude:** `MultiMeshInstance3D` für Palmen und Hütten — tausende Instanzen in
  einem Draw-Call.
- **Fernsicht:** Nebel/Dunst am Horizont, damit das Nachladen von Chunks nie sichtbar aufploppt.

### 4.4 Artstyle-Empfehlung: Low Poly

Bei 3D als Solo-Projekt entscheidet der Stil über Machbarkeit. **Low-Poly mit kräftigen
Flächenfarben** (statt Fotorealismus) bedeutet:

- Schiffe mit 500–2000 Tris statt 50.000, in Blender in Stunden statt Wochen baubar
- Keine aufwendigen PBR-Texturen — Farbpaletten-Texturen reichen
- Verzeiht Ungenauigkeiten in Modellierung und Animation
- Sieht auch in fünf Jahren noch gut aus

Kostenlose Startpunkte: **Kenney.nl** (CC0, hat ein fertiges Pirate-Kit), **Quaternius**,
**Poly Pizza**. Damit kannst du Monate an Prototyping überbrücken, bevor du eigene Assets brauchst.

---

## 5. Signature Features (nach dem Kern)

Die Systeme, die dieses Spiel von einem generischen Piratenspiel unterscheiden. **Bewusst alle
nach dem MVP** — sie sind das Ausbaupotenzial, nicht der Start.

### 5.1 Mannschaft & Meuterei
Crew ist keine Zahl, sondern eine Gruppe mit **Moral**. Moral sinkt durch: lange Fahrt ohne Beute,
knappe Rationen, verlorene Gefechte, ungerechte Beuteteilung. Sinkt sie zu weit: erst Murren, dann
Arbeitsverweigerung, dann Meuterei — du wirst auf einer Insel ausgesetzt und startest mit einem
kleinen Schiff neu. **Offiziere** (Steuermann, Kanonier, Zimmermann, Quartiermeister) sind
benannte Charaktere mit Werten und eigener Loyalität.

### 5.2 Lebendige Wirtschaft
Städte produzieren und verbrauchen tatsächlich. Preise entstehen aus Lagerbeständen, nicht aus
einer Zufallstabelle. Konsequenz: Wenn du eine Stadt blockierst oder ihre Versorgungsschiffe
kaperst, steigen dort die Preise wirklich — und du kannst das gezielt ausnutzen.

### 5.3 Ruf & Kopfgeld
Zwei getrennte Achsen statt einer: **Ansehen bei jeder Nation** (−100 bis +100) und **Berüchtigt**
(0–100, wächst mit jeder Tat, sinkt nie). Berüchtigt beeinflusst: Kapitulationsbereitschaft von
Gegnern, Crew-Rekrutierung, Warenpreise, und ab Schwellenwerten schicken Nationen **Kopfgeldjäger**
— benannte Kapitäne mit starken Schiffen, die dich aktiv suchen.

### 5.4 Flottenführung
Erbeutete Schiffe kannst du behalten. Ab Schiff Nr. 2 brauchst du einen Kapitän aus deinen
Offizieren, und die Flotte bringt eigene Probleme: mehr Crew zu versorgen, langsamster Verband,
aber Feuerkraft für Angriffe auf befestigte Städte.

### 5.5 Eigene Basis
Eine unbewohnte Bucht zur Piratenbasis ausbauen: Lager, Werft, Palisade, Ausguck. Wird zum
sicheren Hafen bei schlechtem Ruf — und zum Ziel, wenn eine Nation genug von dir hat.

### 5.6 Wetter & Hurrikan-Saison
Der Spielkalender hat Jahreszeiten. In der Sturmsaison wird die Karibik gefährlich: Wind dreht
plötzlich, Sicht sinkt, Schäden entstehen ohne Gefecht. Erhöhtes Risiko, aber weniger Patrouillen —
eine echte Abwägung.

---

## 6. Feature-Priorisierung

Was wann gebaut wird. **Tier 0 ist das Spiel.** Alles andere ist Ausbau.

### Tier 0 — MVP (das spielbare Fundament)
- [ ] Schiffssteuerung mit Windsystem
- [ ] Ozean-Shader + Verfolgerkamera
- [ ] Prozedurale Weltgenerierung (Inseln, Städte, Nationen)
- [ ] Chunk-Streaming der Inseln
- [ ] Ein funktionierender Hafen mit Markt + Werft
- [ ] Warenhandel mit Preisunterschieden
- [ ] Seekampf gegen einfache KI-Schiffe
- [ ] Entern (zunächst als Würfelwurf-Auflösung, noch nicht taktisch)
- [ ] Speichern/Laden
- [ ] Minimal-UI: Kompass, Segelstellung, Gold, Zeit

### Tier 1 — Kern-Ausbau
- [ ] Taktisches Enter-Gefecht (3.4)
- [ ] Taverne, Gouverneur, Aufträge
- [ ] Ruf- & Kopfgeldsystem (5.3)
- [ ] Mehrere Schiffsklassen mit echten Unterschieden
- [ ] Offiziere & Crew-Moral (5.1)
- [ ] Wetter (5.6)
- [ ] Erkundungspunkte, Gerüchte

### Tier 2 — Tiefe
- [ ] Lebendige Wirtschaft (5.2)
- [ ] Flottenführung (5.4)
- [ ] Städte angreifen / Landkämpfe
- [ ] Eigene Basis (5.5)
- [ ] Nationen-Kriege mit dynamischen Frontverläufen

### Tier 3 — Politur
- [ ] Musik & Sounddesign
- [ ] Optionen, Barrierefreiheit, Rebinding
- [ ] Steam-Build / Export-Pipeline
- [ ] Lokalisierung (DE/EN)

### Tier 4 — Mehrspieler *(erst nach Abschluss des Einzelspielers)*
- [ ] Session-Hosting für 2–8 Spieler (kein persistenter Server)
- [ ] Seed-Sync statt Weltübertragung
- [ ] Ergebnis-Sync für Gefechte, nutzt B12 statt Echtzeit-Ballistik
- [ ] Duell-Modus auf Basis von `tests/duel.tscn`
- [ ] Geteilte/gegenläufige Pfade in der Story (Wettlauf um die vier Höfe)

Details, Architektur-Vorteile und Begründung: `docs/STORY.md` Abschnitt 7.

---

## 7. Technisches Konzept

### 7.1 Godot-Grundlagen, die du für dieses Projekt brauchst

Du steigst neu in Godot ein. Es gibt sehr viel zu lernen — aber für dieses Projekt sind es im
Kern **sieben Konzepte**. Lerne diese gründlich und ignoriere den Rest erstmal.

**1. Node** — der Baustein von allem. Ein Node kann etwas Bestimmtes: `MeshInstance3D` zeigt ein
3D-Modell, `RigidBody3D` bewegt sich physikalisch, `Timer` zählt runter. Nodes werden zu Bäumen
zusammengesteckt; Kind-Nodes bewegen sich mit ihrem Eltern-Node mit.

**2. Szene** — ein gespeicherter Node-Baum (`.tscn`). Dein Schiff ist eine Szene: ein
`RigidBody3D` mit Mesh, Kollisionsform, Kanonen-Positionen und Skript. Wichtig: **Eine Szene ist
kein "Level"** — sie ist ein wiederverwendbarer Baustein. Ein Level ist auch nur eine Szene.

**3. Instanziierung** — dieselbe Szene mehrfach in die Welt setzen. 30 Handelsschiffe = 30
Instanzen von `ship.tscn`, jedes mit eigenem Zustand.

**4. Signal** — Godots Ereignissystem. Ein Node ruft `emit_signal("ship_sunk", ship)`, andere
hören zu. **Das ist der wichtigste Punkt für saubere Architektur:** Der Sender muss den Empfänger
nicht kennen. Dein Seekampf muss nichts über die UI wissen — er sendet ein Signal, die UI hört zu.

**5. Autoload (Singleton)** — ein Skript, das immer existiert, egal welche Szene läuft. Perfekt
für globalen Zustand: dein Gold, die Spielzeit, die Weltdaten. Einrichtung:
*Projekt → Projekteinstellungen → Autoload*.

**6. Resource** — ein Datencontainer, den du als Datei speichern kannst (`.tres`). Damit
definierst du Schiffsklassen, Warentypen, Städte — als Daten statt als Code. Du kannst sie im
Editor bearbeiten wie Einstellungen. **Das ist der Schlüssel zu einem wartbaren Spiel:** Balancing
passiert dann in Dateien, nicht in `if`-Blöcken.

**7. `_process` vs. `_physics_process`** — `_process(delta)` läuft jeden Frame (für UI, Kamera),
`_physics_process(delta)` läuft in festem Takt (für alles, was sich physikalisch bewegt).
Schiffsbewegung gehört in `_physics_process`.

Dazu drei kleine Dinge, die dir viel Zeit sparen:
```gdscript
@onready var mast = $Hull/Mast    # Referenz auf Kind-Node, sicher ab Szenenstart
@export var max_speed: float = 12.0  # Wert im Editor einstellbar statt im Code
add_to_group("enemy_ships")        # Nodes gruppieren und gesammelt ansprechen
```

### 7.2 Architektur-Überblick

```
                   ┌───────────────────────────────────┐
   AUTOLOADS       │  Immer aktiv, überall erreichbar  │
   (Singletons)    └───────────────────────────────────┘
   ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐
   │ GameState  │ │ WorldData  │ │  EventBus  │ │SceneRouter │
   │ Gold, Zeit │ │ Karte,     │ │ globale    │ │ Moduswechsel│
   │ Ruf, Crew  │ │ Städte,    │ │ Signals    │ │ + Übergänge │
   │ Schiff(e)  │ │ Nationen   │ │            │ │             │
   └────────────┘ └────────────┘ └────────────┘ └────────────┘
   ┌────────────┐ ┌────────────┐
   │SaveManager │ │AudioDirect.│
   └────────────┘ └────────────┘
          │
          │  werden gelesen/geschrieben von ▼
          │
   ┌──────┴──────────────────────────────────────────────┐
   │                  MODUS-SZENEN                        │
   │  Nur eine ist gleichzeitig aktiv. Kennen einander    │
   │  NICHT — nur den SceneRouter.                        │
   ├──────────────┬──────────────┬──────────────┬─────────┤
   │ SailingMode  │  PortMode    │ BoardingMode │  Menus  │
   │ (3D-Welt)    │  (2D/UI)     │ (Taktik)     │         │
   └──────────────┴──────────────┴──────────────┴─────────┘
```

**Die eine Regel, an die du dich halten solltest:** Modi kommunizieren nie direkt miteinander.
Wenn der Seekampf dem Hafen etwas mitteilen will, schreibt er in `GameState` oder sendet ein
Signal über den `EventBus`. Das klingt umständlich, rettet dir aber ab Monat drei das Projekt —
direkte Verweise zwischen Szenen sind die Hauptursache dafür, dass Hobbyprojekte unwartbar werden.

### 7.3 Die Autoloads im Detail

| Autoload | Verantwortung | Beispiel-API |
|---|---|---|
| `GameState` | Alles, was den Spieler betrifft: Gold, Schiffe, Crew, Ruf, Spielzeit | `GameState.add_gold(500)` |
| `WorldData` | Die generierte Welt: Heightmap, Städte, Nationen, Wirtschaft | `WorldData.get_town_at(pos)` |
| `EventBus` | Reine Signal-Sammelstelle, hat keine eigene Logik | `EventBus.ship_sunk.emit(ship)` |
| `SceneRouter` | Moduswechsel mit Ladebalken/Blende, kennt alle Modus-Szenen | `SceneRouter.enter_port(town_id)` |
| `SaveManager` | Serialisieren/Deserialisieren nach `user://` | `SaveManager.save_slot(1)` |
| `AudioDirector` | Musik-Layer, adaptive Übergänge (ruhig ↔ Gefecht) | `AudioDirector.set_mood("combat")` |

Der `EventBus` in seiner ganzen Größe — mehr braucht es nicht:

```gdscript
# autoload/event_bus.gd
extends Node

signal ship_sunk(ship_id: int)
signal ship_boarded(ship_id: int)
signal port_entered(town_id: int)
signal gold_changed(new_amount: int)
signal reputation_changed(nation: int, value: int)
signal weather_changed(state: int)
signal day_passed(day: int)
```

### 7.4 Datenmodell über Resources

Statt Werte im Code zu verstreuen, definierst du sie als Resource-Klassen. Beispiel Schiffsklasse:

```gdscript
# data/ship_class.gd
class_name ShipClass
extends Resource

@export var display_name: String = "Schaluppe"
@export var mesh: PackedScene              # Low-Poly-Modell
@export var max_hull: int = 100
@export var max_sails: int = 100
@export var base_speed: float = 10.0       # Knoten bei idealem Wind
@export var turn_rate: float = 2.0         # Grad pro Sekunde
@export var cannon_slots: int = 8
@export var cargo_capacity: int = 40
@export var min_crew: int = 10
@export var max_crew: int = 60
@export var base_price: int = 2000
```

Damit legst du jede Schiffsklasse als eigene `.tres`-Datei an
(`sloop.tres`, `brigantine.tres`, `frigate.tres`, ...) und balancierst sie im Editor —
ohne eine Zeile Code anzufassen.

Analog entstehen: `TownData`, `NationData`, `CargoType`, `OfficerData`, `CannonType`, `QuestData`.

### 7.5 Schiffsbewegung — das Herzstück

Weil Wind das Kernsystem ist, hier die zentrale Formel als Skizze:

```gdscript
# Wie effizient steht mein Segel zum Wind?
func sail_efficiency(ship_heading: float, wind_dir: float) -> float:
    var angle := abs(angle_difference(ship_heading, wind_dir))
    if angle < deg_to_rad(30.0):
        return 0.05          # "In Irons" — direkt gegen den Wind, fast Stillstand
    elif angle < deg_to_rad(60.0):
        return 0.45          # Am Wind — langsam, aber Höhe gewinnend
    elif angle < deg_to_rad(150.0):
        return 1.00          # Halber Wind bis raumschots — optimal
    else:
        return 0.75          # Vor dem Wind — schnell, aber nicht optimal

# Zielgeschwindigkeit; Beschleunigung erfolgt träge dorthin (Massenträgheit)
var target_speed := ship_class.base_speed \
    * sail_efficiency(heading, WorldData.wind_direction) \
    * WorldData.wind_strength \
    * sail_setting \
    * (current_sails / float(ship_class.max_sails))
```

Wichtig für das Spielgefühl: Ein Schiff **beschleunigt und dreht träge**. Interpoliere die
tatsächliche Geschwindigkeit langsam zur Zielgeschwindigkeit, sonst fühlt sich das Segeln an wie
ein Auto.

### 7.6 Speichersystem

- Format: **JSON** in `user://saves/slot_N.json` (in Godot lesbar über `FileAccess` + `JSON`).
  Vorteil gegenüber Binärformat: du kannst Spielstände beim Debuggen einfach im Texteditor öffnen.
- Gespeichert wird: **Weltseed + alle Abweichungen vom generierten Zustand** (Stadtbesitzer,
  Lagerbestände, Preise) sowie der komplette Spielerzustand. Die Heightmap selbst wird **nie**
  gespeichert — sie wird aus dem Seed rekonstruiert. Das hält Spielstände bei wenigen hundert
  Kilobyte statt vielen Megabyte.
- **Von Tag eins mit einer Versionsnummer im Save.** Wenn sich das Format ändert, kannst du alte
  Stände migrieren statt sie wegzuwerfen.

### 7.7 Die Wirtschaft — ein Preis aus einer einzigen Zahl

Der Preis einer Ware in einer Stadt hängt an genau einer Größe: ihrem **Lagerbestand im
Verhältnis zu ihrem Umschlag**. Volles Lager heißt billig, leeres Lager heißt teuer.
Produktion, Bedarf und Stadtgröße wirken nur darüber, indem sie den Bestand verschieben.

```
Umschlag   = Grundbedarf + Produktion + Bedarf     (pro Woche)
Faktor     = (Bestand / Umschlag) ^ -0.5           begrenzt durch die Volatilität der Ware
Kaufpreis  = Basispreis × Faktor × (1 + Spanne/2)
Verkauf    = Basispreis × Faktor × (1 - Spanne/2)
```

Drei Entscheidungen darin sind wichtiger als die Formel selbst:

**Keine Buchhaltung.** Es wandern keine Waren von Stadt zu Stadt. Jeder Bestand läuft
stattdessen auf seinen natürlichen Wert zu — ein Erzeuger auf das Dreifache seines
Umschlags, ein Abnehmer auf ein Viertel. Solche Modelle kippen sonst: Entweder ersäuft
die Karibik in Tabak oder alle Lager sind nach zwei Wochen leer, und man verbringt den
Rest des Projekts damit, Zahlen nachzuregeln.

**Die Handelsspanne.** Kaufen und sofort zurückverkaufen *muss* Geld kosten. Ohne diese
Spanne wäre der Markt ein zinsloses Sparbuch, in dem man Gold zwischenparkt.

**Preise steigen beim Kauf.** Eine Menge wird Stück für Stück abgerechnet: Jede gekaufte
Einheit senkt den Bestand und hebt damit den Preis der nächsten. Wer den Markt leerkauft,
zahlt für die letzten Einheiten deutlich mehr. Der Handel begrenzt sich dadurch selbst,
ohne dass es eine künstliche Obergrenze bräuchte.

Jede Stadt führt **jede** Ware, auch die, die sie weder erzeugt noch braucht — sonst hätte
sie dafür ein leeres Lager, und ein leeres Lager heißt Höchstpreis. Man hätte Holz an
jedes Dorf zum Doppelten verkaufen können.

### 7.8 Das Gefecht — die Flugbahn ist die Wahrheit

Bis M4 war Treffen ein verdeckter Würfelwurf: Aus dem Winkel zum Ziel wurde eine
Wahrscheinlichkeit, und die Kugeln flogen danach zu einem Ergebnis, das schon feststand.
Die Flugbahn war Dekoration.

Heute zeigen die Rohre wirklich dorthin, wohin sie zeigen. Wo die Kugeln niedergehen,
entscheidet die Geometrie — ein Punkt-in-Rechteck-Test gegen den Rumpf des Gegners.

```
Schwenkbereich  ±20° um querab            ShipClass.gun_traverse
Richtung        querab, bis zum Anschlag auf den Vorhaltepunkt geschwenkt
Vorhalten       Zielposition + Fahrt × Flugzeit, ±6 m Fehler entlang seines Kurses
Streuung        ±1,2° je Rohr
beide Fehler    × (Entfernung / 150 m) ÷ Bedienung
Treffer         Kugel landet im gedrehten Rechteck 2·half_length × 2·half_beam
```

**Der Schwenkbereich ist die Regel, die alles trägt.** Zwanzig Grad um querab sind so eng,
dass das Ruder die Waffe ist: Wer dem Gegner ins Heck fällt, kann nicht schießen, und wer
schräg steht, sieht seine Salve vorbeigehen — die Rohre stehen dann am Anschlag. Das HUD
zeigt für jede Breitseite, ob sie *lädt*, *bereit* ist oder *anliegt*; „liegt an" heißt
seitdem wörtlich, dass die Kugeln den Gegner bekommen.

**Die Lage des Gegners ist eine eigene Größe.** Ein Schiff quer zu dir ist zehn Meter breit
im Anschlag, dasselbe Schiff mit dem Bug voran keine vier. Wer sich dem Feind zudreht,
macht sich schmal. Dass die Kugel dabei auf Entfernung stimmt und nur seitlich streut, ist
kein Versehen, sondern die Voraussetzung dafür — mit einem Streuen in der Tiefe wäre ein
Schiff mit dem Bug zu dir das *leichtere* Ziel, weil es in Schussrichtung länger ist.

**Die Mannschaft hat zwei Aufgaben, und Fahren geht vor.** `min_crew` Leute halten das
Schiff überhaupt in Fahrt; erst was darüber hinausgeht, bedient die Geschütze — zwei Mann
je Rohr für die volle Ladegeschwindigkeit. Daraus folgt ein Zug, der sich lesen lässt: Eine
Schaluppe fährt mit vierzig Mann und braucht sechzehn, also kosten die ersten Verluste
Enterstärke und erst die späten Feuergeschwindigkeit. Unter die Mindestbesatzung zu fallen
kostet Fahrt (`Ship.handling()`); ganz stehen bleibt niemand.

**Das Ergebnis steht trotzdem fest, bevor die Kugel fliegt.** Eine Breitseite wird im
Moment des Abfeuerns fertig gerechnet — Richtung, Bahnen, Treffer —, danach fliegt die
Darstellung nur noch die Strecke ab. Das hat dieselben zwei Gründe wie vorher: Die
Ballistik lässt sich so ohne Szene prüfen, und es braucht keine Kollisionskörper für ein
Dutzend Geschosse zwischen zwei fahrenden Zielen. Neu ist nur, dass gerechnet statt
gewürfelt wird.

**Aufgeben statt Sinken.** Unter 30 % Rumpf streicht ein Kapitän die Flagge — bei einem
gefürchteten Gegner früher. Erst dann gibt es Beute. Wer weiter auf den Rumpf schießt,
versenkt seine eigene Prise: Ladung und Kasse gehen mit unter. Das ist der Preis für den
kurzen Weg, und der Grund, warum sich Fernbeschuss auf die Takelage lohnt.

**Die KI dreht ein, statt hinterherzufahren.** Ein Kapitän legt einen Vorhalt auf die
Peilung: weit draußen null, sodass wirklich aufgeschlossen wird, auf hundert Metern volle
neunzig Grad, sodass der Gegner querab steht. Dazwischen ergibt sich eine Spirale, die von
selbst in einen Kreis um den Gegner einläuft — und dieser Kreis ist genau die Bahn, auf der
die Breitseite anliegt. Wer stattdessen den Gegner selbst ansteuert, landet in seinem
Kielwasser; dort liegt kein Rohr an, und beide fahren bis zum Sonnenuntergang geradeaus.
Genau das ist im ersten Probelauf von M4 passiert: achtzig Sekunden Gefecht, sieben Punkte
Schaden.

M4 hat das über einen festen Platz längsseits gelöst. Mit einem Schwenkbereich von zwanzig
Grad reichte das nicht mehr: Der Platz fährt mit, ein Verfolger mit vier Knoten Vorsprung
braucht Minuten, um ihn einzuholen, und solange steht der Gegner schräg voraus. Gemessen
mit `tests/duel.tscn` — zwölf Prozent der Zeit lag ein Rohr an. Mit der Spirale sind es
fünfundfünfzig.

### 7.8b Das Entern — die zweite Antwort

Bis M4 führte genau ein Weg zur Prise: den Gegner beschießen, bis er streicht. Damit war
Mannschaft im Gefecht nur etwas, das man *verliert* — ein Nachteil, den man erleidet, ohne
ihn je einsetzen zu können. `Ship.readiness()` behauptet seit M4 im eigenen Kommentar, die
ersten Verluste kosteten „Enterstärke". Es gab keine.

Jetzt gibt es zwei Antworten auf ein fremdes Segel, und sie kosten Verschiedenes:

| | Reichweite | Kosten | Dauer |
|---|---|---|---|
| **Zusammenschießen** | 420 m | Zeit, Pulver, eigener Rumpf | Minuten |
| **Entern** | 45 m | Leute | ein Zug |

Der Ausgang ist ein **Wurf, kein Taktikgefecht** — Abschnitt 6 sieht das für Tier 0
ausdrücklich so vor; das Gitterfeld aus 3.4 ist Tier 1 und braucht Offiziere, die es noch
nicht gibt.

Die ganze Auflösung hängt an einer Zahl: `Boarding.odds()`, der Anteil des Angreifers an der
Gesamtstärke. Sie ist zugleich seine Siegchance **und** das Maß für die Verluste beider
Seiten. Damit braucht es keine getrennte Regel für Sieger und Verlierer: Ein aussichtsloser
Sturm ist ein Gemetzel für den Angreifer, ein übermächtiger kostet fast nichts, und ein
Gefecht auf Augenhöhe kostet beide die Hälfte.

Drei Dinge verschieben sie:

- **Verteidigen ist im Vorteil** (`DEFENCE_BONUS` 1,35). Bei gleicher Mannschaft steht der
  Sturm auf 0,43 — schlecht. Ohne diesen Faktor wäre Entern immer die richtige Antwort und
  das ganze Schießen überflüssig.
- **Ein zerschossener Rumpf nimmt den Mut** (`HULL_MORALE`). Deshalb lohnt eine Breitseite
  vor dem Übersetzen, auch wenn sie den Gegner nicht zum Streichen bringt.
- **Berüchtigtheit zählt an Deck** (`FEAR_BONUS`). Bei 100 kämpft die eigene Mannschaft wie
  ein gutes Drittel mehr Leute — der gefürchtete Pirat aus 3.4, der Gefechte gewinnt, ohne
  einen Schuss abzugeben.

In Zahlen der aktuellen Klassen: Eine volle Schaluppe (40 Mann) gegen eine unversehrte
Handelsbrigg (26) steht auf 0,53 — knapp lohnend. Gegen eine unversehrte
Patrouillenschaluppe (46) auf 0,39 — dafür muss man erst schießen oder sich einen Ruf
erarbeitet haben. Genau diese Abwägung soll die Mechanik tragen.

Nach einem Sturm sind die Enterhaken 25 Sekunden unklar (`RECOVERY_SECONDS`). Ohne diese
Sperre wäre ein abgeschlagener Sturm nur ein zweiter Tastendruck.

### 7.9 Ordnerstruktur

```
PirateGame/
├── project.godot
├── docs/
│   └── KONZEPT.md              ← dieses Dokument
├── autoload/                   Singletons
│   ├── game_state.gd
│   ├── world_data.gd
│   ├── event_bus.gd
│   ├── scene_router.gd
│   └── save_manager.gd
├── data/                       Resource-Klassen (Code)
│   ├── ship_class.gd
│   ├── town_data.gd
│   ├── nation_data.gd
│   └── cargo_type.gd
├── resources/                  Konkrete Instanzen (.tres)
│   ├── ships/
│   ├── cargo/
│   └── nations/
├── world/                      Weltgenerierung
│   ├── world_generator.gd
│   ├── island_builder.gd
│   ├── town_placer.gd
│   ├── chunk_manager.gd
│   ├── combat/
│   │   ├── gunnery.gd          Ballistik, ohne Nodes
│   │   ├── naval_combat.gd     Begegnungen, Breitseiten, Prisen
│   │   └── cannon_ball.gd      Kugeln, Rauch, Fontänen
│   └── ocean/
│       ├── ocean.tscn
│       └── ocean.gdshader
├── modes/                      Die Modus-Szenen
│   ├── sailing/
│   ├── port/
│   ├── boarding/
│   └── menu/
├── entities/
│   ├── ship/
│   │   ├── ship.tscn
│   │   ├── ship.gd
│   │   └── ship_ai.gd
│   └── cannonball/
├── ui/
│   ├── hud/
│   ├── port_screens/
│   └── theme/
├── assets/
│   ├── models/
│   ├── textures/
│   ├── audio/
│   └── fonts/
└── tests/
```

---

## 8. Roadmap

Meilensteine, jeder mit einem klaren **"fertig, wenn..."**-Kriterium. Die Zeitangaben gehen von
Teilzeit-Entwicklung (10–15 Std./Woche) aus und beinhalten Einarbeitungszeit in Godot.

### M0 — Fundament & Godot lernen ✅
Godot-Projekt anlegen, Ordnerstruktur, Git-Workflow, Autoloads als leere Gerüste.
Parallel: Godots offizielles "Dodge the Creeps"-Tutorial in **3D** durchgehen.
> **Fertig, wenn:** Du eine Kugel mit WASD über eine Ebene steuerst, mit Verfolgerkamera.

### M1 — Ein Schiff auf dem Wasser ✅
Ozean-Shader, Schiffsmodell (Kenney-Asset genügt), Wind-System, Segelsteuerung, Kamera,
Kompass-UI.
> **Fertig, wenn:** Segeln sich gut anfühlt und du merkst, wenn der Wind dreht. **Dieser
> Meilenstein entscheidet über das Projekt** — wenn Segeln keinen Spaß macht, hilft kein Feature
> der Welt. Nimm dir hier Zeit.

### M2 — Die Welt ✅
Weltgenerator (Heightmap → Inseln → Städte → Nationen), Chunk-Streaming, Minimap, Namensgenerator.
> **Fertig, wenn:** Du eine Stunde lang durch eine generierte Karibik segeln kannst, ohne dass
> die Framerate einbricht oder Land aufploppt.

### M3 — Der erste Hafen ✅
Andocken, Hafen-Szene, Markt mit Preisen, Werft für Reparatur, Gold-Wirtschaft.
> **Fertig, wenn:** Du günstig kaufen, woanders teuer verkaufen und dein Schiff reparieren kannst.
> **Ab hier existiert eine Gameplay-Schleife.**

### M4 — Seekampf ✅
Kanonen, Geschosse, Trefferzonen, Schadensmodell, Schiffs-KI (Verfolgen, Manövrieren, Feuern,
Fliehen), Beute.
> **Fertig, wenn:** Ein Gefecht gegen ein KI-Schiff spannend ist und Manövrieren belohnt wird.

### M5 — Entern & Progression *(4–5 Wochen)*  ← läuft
Enter-Gefecht, Crew, Schiffsklassen, Schiffskauf, Speichern/Laden.
Speichern/Laden, Crew und die Schiffsklassen stehen seit M3/M4; das Entern ist gebaut — als
Wurf-Auflösung, wie es Abschnitt 6 für Tier 0 vorsieht (siehe 7.8b). Das taktische
Deckgefecht aus 3.4 bleibt Tier 1: Es braucht Offiziere, die es noch nicht gibt.
**Offen: die beiden Wege zu einem besseren Schiff** — der Schiffskauf und die Übernahme
einer Prise. Solange keiner von beiden geht, gibt es keinen Aufstieg, und die
Abnahmebedingung ist nicht erfüllt.
> **Fertig, wenn:** Ein kompletter Aufstieg vom Startschiff zu einem größeren Schiff spielbar ist.

### M6 — Welt reagiert *(4 Wochen)*
Ruf, Kaperbriefe, Nationen-Beziehungen, Gouverneurs-Aufträge, Kopfgeldjäger, Taverne.
> **Fertig, wenn:** Deine Taten spürbare Folgen in der Welt haben.

### M7+ — Signature Features & Politur
Wirtschaft, Flotte, Basis, Wetter, **Meeresoptik** (siehe Abschnitt 11), Audio, Export.

**Realistische Gesamteinschätzung:** M0–M6 sind grob **6–9 Monate Teilzeit** bis zu einem runden,
vorzeigbaren Spiel. Das ist kein Grund zur Sorge — es ist die normale Größenordnung. Es ist nur
ein Grund, **M1 bis M3 nicht zu überspringen**.

---

## 9. Risiken

| Risiko | Warum es gefährlich ist | Gegenmaßnahme |
|---|---|---|
| **Scope-Explosion** | Pirates! hat sehr viele Systeme; jedes einzelne klingt machbar | Tier-Liste in Abschnitt 6 strikt einhalten. Kein Tier-1-Feature, bevor Tier 0 vollständig spielbar ist. |
| **Performance der 3D-Welt** | 2048²-Heightmap in 3D bringt jede Engine um, wenn alles gleichzeitig existiert | Chunk-Streaming von Anfang an (M2), nicht nachträglich. `MultiMesh` für Vegetation. Früh auf Zielhardware testen. |
| **3D-Assets als Solo-Dev** | Modellieren, Texturieren, Animieren ist ein eigener Vollzeitberuf | Low-Poly-Stil + CC0-Assets (Kenney, Quaternius) für alles bis M6. Eigene Assets erst, wenn das Spiel steht. |
| **Godot-Lernkurve parallel zum Bauen** | Erste Systeme werden zwangsläufig schlecht strukturiert | Ist normal und eingeplant. M0/M1 sind bewusst als Lernphase gesetzt. Rechne damit, den Weltgenerator einmal komplett neu zu schreiben. |
| **Prozedurale Welt fühlt sich beliebig an** | Noise erzeugt leicht gleichförmigen Inselbrei ohne Wiedererkennungswert | Handgebaute Elemente einstreuen: kuratierte Namen, feste Stadt-Archetypen, garantierte Landmarken (eine große Hauptinsel pro Nation). |
| **Motivationsloch bei Monat 4** | Das übliche Hobbyprojekt-Muster nach der Anfangseuphorie | Jeder Meilenstein endet mit etwas **Spielbarem**, nicht mit etwas Fertigem. Kurze Videos vom Fortschritt aufnehmen — sichtbarer Fortschritt trägt. |

---

## 10. Stand

**M0 abgeschlossen.** Projekt, Ordnerstruktur, sechs Autoloads, Resource-Klassen,
Eingabebelegung, Speichersystem, Startmenü. Rauchtest mit 68 Prüfungen.

**M1 abgenommen.** Ozean mit Wellen-Shader, Schiffssteuerung über
Wind und Segelstellung, Verfolgerkamera mit Zoom, Kompass mit Sperrsektor. Das Schiff
reitet auf denselben Wellen, die der Shader zeichnet — `OceanWaves` und
`ocean.gdshader` teilen sich Formel und Uhr.

**M2 zur Hälfte.** Die Generierungs-Pipeline aus Abschnitt 5.2 läuft vollständig:
Heightmap, Inselmaske, Flood-Fill, Hafenplätze, K-Means-Nationen, Namen, Wirtschaft.
Ergebnis pro Welt: 26–40 Häfen auf 10–20 Inseln, vier Nationen mit je einer Hauptstadt,
Produktion und Bedarf, die Handelsgefälle erzeugen. Die Seekarte (Taste M) zeigt das
Ergebnis. Generierungsdauer rund 0,3 Sekunden.

Zwei Abweichungen vom ursprünglichen Konzept, beide aus der Praxis:

- **Der Meeresspiegel steht nicht fest.** Er wird pro Seed aus der Höhenverteilung
  kalibriert, damit der Landanteil immer trifft. Eine feste Schwelle lieferte je nach
  Seed 1,6 % Land oder einen Kontinent.
- **Tiefwasser wird im Umkreis gesucht, nicht direkt am Kai.** Die harte Bedingung
  „Tiefwasser als direkter Nachbar“ verwarf jeden Hafenplatz — direkt neben der Küste
  ist das Wasser immer flach.

**M2 abgeschlossen.** Das Gelände wird als Chunks von 256 Metern gestreamt, aber nur
dort, wo Land ist — über offener See übernimmt der Ozean-Shader. Bei 14 % Landanteil
trägt nur rund ein Viertel der Chunks in Sichtweite überhaupt Geometrie. Gemessen:
74 fps bei 60 geladenen Chunks, 1,3 km Sichtweite.

Kollision mit Land läuft ohne Collision-Mesh: Die Höhenfunktion beantwortet die Frage
direkt und billiger, als ein Collider für jede Insel es könnte.

Drei weitere Korrekturen aus der Praxis:

- **Die Winkelkonvention war gespiegelt.** Godots `rotation.y` dreht nach Westen, die
  Navigation nach Osten. Das Segelverhalten blieb korrekt — `sail_efficiency` nutzt nur
  die Differenz — aber Kompass, Seekarte und Startausrichtung zeigten spiegelverkehrt.
  Das Schiff startete mit Blick aufs offene Meer statt auf die Küste.
- **Vertex-Farben sind in Godot 4 linear, nicht sRGB.** Ohne Umrechnung wirkte jede
  Insel wie ein Schneefeld.
- **Die Sichtweite hing an der Ozean-Plane.** Sie reichte 450 m weit, also musste der
  Dunst dicht genug sein, ihren Rand zu verbergen — und verschluckte damit auch die
  Inseln. Eine große flache Fernsee unter den Wellen entkoppelt beides.

Das Gate ist genommen: Segeln fühlt sich gut an. Am Modell wurde der Klüverbaum
korrigiert — er zeigte nach unten und schwebte neben dem Rumpf, weil Godot
Transform-Basen in `.tscn` zeilenweise speichert und eine spaltenweise gerechnete
Rotationsmatrix dort transponiert, also als Umkehrung, ankommt.

**M3 abgeschlossen.** Ab hier existiert eine Gameplay-Schleife. Damals zwölf Warenarten als
`.tres`-Dateien, ein Preismodell (Abschnitt 7.7), Anlegen bei 240 m Entfernung, ein
Hafenbildschirm mit Markt und Werft, Auflaufen kostet Rumpf, die Werft nimmt Gold dafür.
Der Rauchtest fährt die Abnahmebedingung selbst: 20 Ballen Tabak im billigsten Hafen
gekauft und im teuersten verkauft, 3000 → 3585 Gold — und dieselbe Route rückwärts ein
Verlust.

Vier Dinge kamen aus dem Rendern, nicht aus dem Code:

- **Häfen waren in der Welt unsichtbar.** Man konnte anlegen, sah aber nur leere Küste.
  Jede Stadt hat jetzt Häuser und eine Fahnenstange in Nationsfarbe — von See aus
  erkennt man, wem der Hafen gehört, ohne die Karte zu öffnen.
- **Die Häuser schwebten über dem Hang**, während die Fahnenstange daneben im Boden
  steckte. Beide standen auf der mathematisch richtigen Höhe: `elevation_at()` liefert
  die Höhenfunktion, gezeichnet werden aber die geraden Flächen zwischen den
  Gitterpunkten, und die liegen acht Meter auseinander.
- **Städte klebten an Steilküsten.** Der Generator ebnet jetzt einen Uferstreifen von
  120 m um jede Stadt ein — nach unten *und* nach oben begrenzt, sonst standen Dörfer
  auf Kliffs sechzig Meter über ihrem eigenen Hafen.
- **Beim Auslaufen flog die Kamera quer über die Karibik.** Das Schiff wird versetzt,
  nicht gefahren; die Kamera folgte träge und stand sekundenlang im Nirgendwo.

Stellschrauben fürs Fahrverhalten jetzt in `resources/ships/sloop.tres` statt im Skript —
der Segelmodus schreibt die Werte beim Start ins Schiff. Wellenbild in
`world/ocean/ocean_waves.gd` (Konstanten dort und im Shader gemeinsam ändern).
Preisbildung in `world/economy/trade_math.gd`, Warenpreise in `resources/cargo/*.tres`.

**M4 abgeschlossen.** Auf der See sind fremde Segel unterwegs: Handelsschiffe, die
fliehen, und Patrouillen, die angreifen. Q und E geben Breitseiten ab, jede Seite lädt
neun Sekunden. Rumpf, Takelage und Mannschaft nehmen getrennt Schaden; zerschossene
Segel kosten Fahrt, fehlende Leute Ladezeit und Treffsicherheit. Unter 30 % Rumpf
streicht der Gegner die Flagge und lässt sich mit der Leertaste aufbringen. Der
Rauchtest fährt die Abnahmebedingung: dieselbe Ausgangslage zweimal, derselbe Würfel,
einmal mit einem Kapitän, der den Gegner querab hält, und einmal mit einem, der
drauflosfährt. (Die Zahlen dazu stehen weiter unten beim Geschützrichten — sie sind mit
der neuen Ballistik neu gemessen worden.)

Die Werft heuert seit M4 auch an. Das gehört eigentlich in die Taverne (M6), musste aber
vorgezogen werden: Ein Gefecht kostet Mannschaft, fehlende Leute kosten Ladezeit und
Treffsicherheit, und ohne Weg zurück fährt man nach zwei Gefechten dauerhaft mit halber
Besatzung. Eine Sackgasse ohne Ausweg ist kein System, sondern ein Fehler.

Zwei Entwurfsentscheidungen sind wichtiger als die Zahlen:

- **Die Entfernung ersetzt die Munitionstypen.** Nah bricht der Rumpf, fern fällt die
  Takelage. Das gibt dieselbe Entscheidung wie Rundkugel gegen Kettenkugel, aber über das
  Ruder statt über ein Menü — und man sieht es im Bild statt in einer Anzeige.
- **Wer versenkt, verliert die Beute.** Ladung und Kasse gehen mit unter. Deshalb lohnt
  es sich, aus der Entfernung die Segel zu zerlegen und den Gegner dann zu stellen, statt
  ihn kurz und klein zu schießen.

Drei Fehler, die erst das Fahren und Rendern gezeigt hat:

- **Der Verfolger fuhr ins Kielwasser.** Wer auf den Gegner selbst zuhält, landet hinter
  ihm, und hinter ihm liegt kein Rohr an. Achtzig Sekunden Gefecht, sieben Punkte
  Schaden. Die KI steuert jetzt einen Punkt *neben* dem Gegner an, nicht ihn selbst.
- **Der Feuerbereich war zu eng.** 50 Grad um querab klang taktisch; durch dieses Fenster
  passt keine Verfolgungskurve. Bei 70 Grad bleiben Bug und Heck weiterhin leer — worauf
  es ankommt —, aber ein Gefecht kommt zustande.
- **Das Gefecht war unsichtbar.** Die Heckkamera zeigt nach vorn, geschossen wird querab.
  Im HUD stand „Zeelandia · 180 m", auf dem Bildschirm war offene See. Die Kamera rahmt
  jetzt beide Schiffe ein, sobald ein Gegner in Schussweite kommt.

Der erste Mündungsrauch war außerdem so groß und undurchsichtig, dass das eigene Schiff
hinter der eigenen Breitseite verschwand.

Stellschrauben fürs Gefecht in `world/combat/gunnery.gd` (Schwenkbereich, Reichweite,
Vorhalten, Streuung, Trefferzonen, Aufgeben), fürs Verhalten der Gegner in
`entities/ship/ship_ai.gd`, für Begegnungen und Beute in `world/combat/naval_combat.gd`,
für die Schiffe selbst in `resources/ships/*.tres`.

**Das Geschützrichten neu gebaut.** Die Ballistik von M4 war eine Wahrscheinlichkeit mit
einer Flugbahn davor; jetzt ist die Flugbahn die Wahrheit (Abschnitt 7.8). Der
Schwenkbereich fiel von 70 auf ±20 Grad, die Mannschaft richtet selbst und hält vor, und
ob getroffen wird, entscheidet ein Punkt-in-Rechteck-Test gegen den Rumpf des Gegners.

Gemessen wurde mit `tests/duel.tscn` — derselben Szene, in der man das Gefecht auch
spielen kann. Aus dem ersten Messlauf kamen drei Zahlen, die man nicht raten kann:

- Eine richtig gelegte Breitseite trifft auf 150 Metern **rund drei von vier Kugeln**
  statt wie bisher jede zweite. Der Schaden je Kugel bleibt trotzdem bei den Werten aus
  M4 (8 / 10 / 2) — es fallen dafür deutlich weniger Salven, weil der enge Kegel und die
  Feuerdisziplin der KI zusammen mehr kosten, als die Treffsicherheit einbringt.
- Die KI musste umgebaut werden, sonst hätte sie gar nichts mehr getroffen: Der Platz
  längsseits aus M4 wich der Spirale, die Ruderverstärkung stieg von 2,4 auf 3,4, die
  Seitenhysterese von 25 auf 70 Grad, und auf über 225 Meter wird nicht mehr gefeuert.
  Anteil der Zeit, in der ein Rohr anlag: **12 % vorher, 55 % nachher.**
- Eine fliehende Handelsbrigg entkommt der KI in vier von fünf Läufen. Das bleibt so —
  eine Beute zu stellen ist die Aufgabe des Spielers, nicht die eines Skripts.

Die Abnahmebedingung im Rauchtest läuft jetzt gegen ein Kriegsschiff statt gegen eine
Handelsbrigg: **123 gegen 18 Punkte Schaden**, Flagge nach 30 Sekunden. Gegen einen
Fliehenden sagt ein Duell nur, wer schneller ist.

**Das Entern kam dazu** (M5, Abschnitt 7.8b). Bis dahin führte genau ein Weg zur Prise —
den Gegner beschießen, bis er streicht. Damit war Mannschaft im Gefecht nur etwas, das man
verliert. Jetzt lässt sich ein Gegner, der noch kämpft, auf 45 Metern stürmen: schneller
als ihn zusammenzuschießen, aber es kostet Leute, die danach an Schoten und Rohren fehlen.
Verteidigen ist im Vorteil, also lohnt eine Breitseite vorher; Berüchtigtheit hilft an Deck,
also zahlt sich ein Ruf zum ersten Mal aus.

**Von zwölf Waren auf neun.** Zucker, Kaffee und Werkzeug sind heraus: Zwei Rohstoffe mit
ähnlichem Preis unterscheiden sich für den Spieler durch nichts als ihren Namen, und eine
Marktliste, die man nicht mehr überblickt, hilft niemandem.

Dabei kam ein Fehler heraus, der vorher unbemerkt Handel gekostet hat. Die Zuteilung von
Produktion und Bedarf zog eine Ware und *übersprang* sie, wenn die Stadt sie schon hatte —
sie zog nicht neu. Mit kleinerem Warenvorrat fiel das auf: Der Bedarf einer Hauptstadt sank
von 2,75 auf 2,00 und lag damit unter dem eines Dorfes, und eine Stadt hatte gar keinen
Bedarf mehr — ein Hafen, in dem sich nichts verkaufen lässt. Seit die Ziehung neu zieht,
statt zu überspringen, steht es besser als je zuvor:

| Bedarfe je Stadt | 12 Waren, alt | 9 Waren, alt | 9 Waren, neu |
|---|---|---|---|
| Hauptstadt | 2,75 | 2,00 | **3,25** |
| Stadt | 2,33 | 1,33 | **3,00** |
| Dorf | 1,86 | 1,81 | **2,00** |
| ohne Bedarf | 0 | 1 | **0** |

`tests/world_report.tscn` druckt diese Zahlen jetzt mit. Wer Waren hinzufügt oder
herausnimmt, sieht sofort, was es mit dem Handel macht — die Warenzahl steht der Wirtschaft
näher, als sie aussieht.

**Und die Unterbesetzung wurde sichtbar.** `Ship.handling()` nimmt seit dem Umbau des
Geschützrichtens Fahrt weg, wenn die Mannschaft unter `min_crew` fällt — nur stand das
nirgends. Der Knotenmesser zeigte zu wenig, und das Schiff sah unbeschädigt aus. Jetzt
nennt die Zustandszeile den Grund („3 von 8 Mann · unterbesetzt") und färbt die Fahrt rot;
die Werft schreibt dasselbe dazu. Die Formel steht dafür in `SailingMath`, nicht mehr im
`Ship` — HUD und Hafen brauchen sie, wenn gar kein Schiff in der Szene hängt.

---

## 11. Nächste Schritte

0. **F3 drücken.** Das Debug-Menü dreht Wind, Fahrt und Begegnungen direkt — damit lassen
   sich die folgenden Fragen in Minuten beantworten statt in Stunden. „Segel setzen" holt
   sofort einen Gegner heran, statt auf ein zufälliges Treffen zu warten.
1. **`godot --path . res://tests/duel.tscn`** ist der kurze Weg ins Gefecht: Man liegt sofort
   längsseits, R holt einen frischen Gegner, G wechselt seine Klasse, H die Ausgangslage.
   Ohne Fenster (`--headless`) fährt dieselbe Szene fünfzehn Gefechte KI gegen KI und druckt
   die Kennzahlen — darunter **„liegt an"**, der Anteil der Zeit, in dem überhaupt ein Rohr
   am Ziel war. Das ist die Spalte, an der man eine KI-Änderung erkennt; der Schaden je
   Gefecht schwankt zwischen zwei Läufen um den Faktor drei und sagt gar nichts.
2. **Stellschrauben.** `Gunnery.RELOAD_SECONDS` (Takt des Gefechts),
   `ShipClass.gun_traverse` (wie streng die Lage sein muss — der Kegel um querab),
   `Gunnery.HULL_DAMAGE` / `SAIL_DAMAGE` / `CREW_DAMAGE` (wie schnell es vorbei ist),
   `Gunnery.STRIKE_HULL` (wann aufgegeben wird), `Gunnery.IDEAL_RANGE` (ab wo die Streuung
   wächst), `NavalCombat.spawn_interval` (wie oft überhaupt jemand kommt). Fürs Entern:
   `Boarding.DEFENCE_BONUS` (wie sehr Verteidigen im Vorteil ist), `Boarding.LOSS_RATE`
   (was ein Sturm kostet), `Boarding.FEAR_BONUS` (was der Ruf an Deck wert ist).
3. **`godot --path . res://tests/capture_battle.tscn`** rendert ein Gefecht in fünf
   Aufnahmen — schneller als eines zu suchen, wenn es nur um die Darstellung geht.

**Stand M5:** Das Entern ist gebaut, als Wurf-Auflösung wie in Abschnitt 6 (Tier 0)
vorgesehen — das taktische Deckgefecht aus 3.4 ist Tier 1 und braucht Offiziere, die es
noch nicht gibt. Damit ist die Mannschaft zum ersten Mal etwas, das man *einsetzt*, statt
nur zu verlieren. Offen bleibt aus M5 der **Schiffskauf**: Solange ein besseres Schiff nicht
zu haben ist, gibt es keinen Aufstieg, und M5 ist nicht abgeschlossen.

Offen aus M4, bewusst zurückgestellt:

- Der Ruf hat noch keine Folge. Prisen kosten Ansehen und bringen Berüchtigtheit, und
  Berüchtigtheit wirkt inzwischen an zwei Stellen — sie macht Gegner mürber
  (`Gunnery.will_strike`) und die eigene Mannschaft an Deck stärker (`Boarding.FEAR_BONUS`).
  Aber niemand *reagiert* darauf. Das ist M6.
- Ein verlorenes Gefecht nimmt Gold und Ladung und setzt den Rumpf auf ein Viertel. Das
  bleibt ein Platzhalter, bis die Entscheidung über Schiff und Mannschaft dazugehört.
- **Eine erbeutete Prise lässt sich noch nicht behalten.** Sie wird ausgeräumt und treibt
  davon (`NavalCombat._release`). Das gehört zu M5 und ist nur zurückgestellt, nicht
  verworfen. Gemeint ist dabei ausdrücklich **ein** Schiff: das Prisenschiff gegen das eigene
  tauschen, mit allem, was daran hängt (Ladung umladen oder verlieren, Mannschaft aufteilen,
  der eigene Rumpf ist weg). *Mehrere* Schiffe gleichzeitig zu führen ist Flottenführung
  (5.4) und bleibt Tier 2 — dort kommen Kapitän, Verband und Versorgung dazu.
- Die KI flieht stur vom Gegner weg und nimmt in Kauf, dabei in den Wind gedrängt zu
  werden. Wer die Luvposition hält, kann jede Beute stellen. Das ist ein System zum
  Durchschauen und vorerst kein Fehler.

### Vorgemerkt: Überarbeitung der Meeresoptik

Licht, Schatten und Wellen wiederholen sich sichtbar wie ein Schachbrett. Das ist kein
Zufallsfehler, sondern folgt direkt aus der Formel in `world/ocean/ocean_waves.gd` und
`world/ocean/ocean.gdshader` — vier Ursachen, die sich überlagern:

1. **Ein echtes Gitternetz liegt darüber.** Der Shader zeichnet mit `grid_size = 30.0` und
   `grid_strength = 0.07` alle 30 Meter eine weltfeste Linie. Das war eine Lernhilfe aus M1,
   um Fahrt und Drift sichtbar zu machen — im Shader steht seit damals „für die fertige
   Optik später auf 0.0 setzen". Das ist der buchstäbliche Teil des Schachbretts und mit
   einer Zahl erledigt. Im Debug-Menü (F3) lässt sich das Gitter abschalten, um zu sehen,
   wieviel davon es ausmacht.

2. **Die Wellen laufen entlang der Achsen.** Die vier Lagen sind `sin(x)`, `sin(z)`,
   `sin(x+z)` und `sin(x−z)` — also zwei achsenparallele und zwei diagonale Richtungen,
   sonst nichts. Eine Summe aus `sin(x)` und `sin(z)` erzeugt zwangsläufig ein rechtwinkliges
   Gitter aus Bergen und Tälern: den Eierkarton. Echte Dünung kommt aus vielen Richtungen,
   die zueinander schief stehen.

3. **Alle Frequenzen sind rationale Vielfache voneinander** (1.0, 1.30, 0.70, 3.10). Damit
   hat das gesamte Feld eine endliche Wiederholung — es kachelt exakt, nur mit größerer
   Kantenlänge als die einzelne Welle. Irrationale Verhältnisse (oder eine fünfte Lage mit
   krummem Faktor) verschieben die Wiederholung weit über die Sichtweite hinaus.

4. **Die Beleuchtung erbt das Muster.** Die Normale entsteht aus finiten Differenzen
   derselben Funktion, also glänzt die See auf genau demselben Gitter. Bei einer einzigen
   gerichteten Lichtquelle sind die Glanzstellen dadurch regelmäßig gereiht.

Was eine Überarbeitung angehen müsste, grob nach Wirkung je Aufwand:

- Gitternetz aus, `grid_strength = 0.0` (eine Zeile)
- Sechs bis acht Lagen mit **gedrehten** Richtungen statt Achsen und Diagonalen, Winkel und
  Frequenzen aus einer festen Tabelle mit krummen Verhältnissen
- **Gerstner** statt reiner Sinus: Wellen bekommen spitze Kämme und flache Täler, was das
  regelmäßige Auf und Ab optisch bricht
- Feine Kräuselung über eine Normal-Map oder eine Rauschfunktion — sie muss die *Höhe* nicht
  verändern und darf deshalb allein im Shader stehen
- Schaum an den Kämmen und ein Fresnel-Anteil, damit die See nicht überall gleich hell ist

**Achtung bei jeder dieser Änderungen:** Die Formel existiert doppelt und muss doppelt
geändert werden — `OceanWaves.height_at()` und `swell()` im Shader müssen exakt dieselbe
Höhe liefern, sonst reitet das Schiff nicht mehr auf der See, die es sieht (Regel B4). Die
Kräuselung ist die einzige Ausnahme: Was den Rumpf nicht hebt, gehört nur in den Shader.

Prüfen lässt sich das mit `godot --path . res://tests/capture_sailing.tscn` und
`res://tests/capture_island.tscn` — letzteres zeigt die Küste auch ohne Wasser und im
Drahtgitter.

### Empfohlene Lernquellen
- **Godot Docs — "Your first 3D game"**: der offizielle Einstieg, sehr gut gepflegt
- **GDQuest** (YouTube/Web): Godot-4-Tutorials mit sauberer Architektur
- **Godot Shaders** (godotshaders.com): fertige Ozean-Shader zum Lernen und Anpassen
- **Kenney.nl** — CC0-Assets, inklusive Pirate-Kit

---

*Lebendes Dokument. Wird mit jedem Meilenstein überarbeitet — insbesondere Abschnitt 6 und 8.*
