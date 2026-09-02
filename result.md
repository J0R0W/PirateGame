# M6, vierter Schritt: die Kronen unter sich, und eine Schenke

Stand: 3. September 2026. Übergabe an die nächste Sitzung.

Zuletzt abgelegt: `6e1a484` (Entern und neun Waren). Seitdem lagen **alle vier M6-Schritte
uncommittet** im Arbeitsverzeichnis; dieser Schritt wird mit ihnen zusammen abgelegt.

---

## Was vorher offen war

Zwei Dinge, und beide standen als Kommentar im Code:

- **Der Kaperbrief deckte alles außer der eigenen Flagge.** In `LetterOfMarque.covers` stand
  dazu, dass es eigentlich der Krieg entscheiden müsste — den es nicht gab. Ein Brief, der
  jede fremde Prise gutschreibt, ist aber ein Freibrief und keine Entscheidung.
- **Ein Auftragsziel wurde einfach in Sichtweite gesetzt**, egal wo man fuhr. Man konnte
  einen Auftrag nicht *suchen*, nur abwarten — und `Commission.DAYS` = 8 befristete nichts.

## Was gebaut wurde

### `world/politics/diplomacy.gd` — wer mit wem Krieg führt

**Zu jeder Zeit liegt jede Krone mit genau einer anderen im Krieg.** Vier Nationen lassen
sich auf genau drei Arten so paaren; die Lage ist immer eine dieser drei. Das ist an beiden
Enden enger als „jeder gegen jeden nach Würfel", und mit Absicht:

- Ein **allgemeiner Friede** schaltete Kaperbrief und Auftrag ab, also das halbe Spiel — und
  der Spieler hätte nichts in der Hand dagegen.
- Ein **allgemeiner Krieg** wäre der Zustand von vorher.

Die Paarung ist die interessante Mitte: Der Brief deckt genau eine Flagge, und welche das
ist, sucht man sich mit dem Patron aus.

| | |
|---|---|
| Gehalten wird | **nichts.** Die Lage ist eine reine Funktion aus Weltseed und Spieltag, wie der Steckbrief in `Commission.offer`. Kein Feld im Spielstand, keine zweite Wahrheit |
| Wechselt alle | 24 Spieltage (`ERA_DAYS`) — dreimal die Frist eines Auftrags, damit ein Krieg die Jagd überdauert, die unter ihm begonnen wurde |
| Und dann wirklich | Der Schritt durch die drei Lagen ist immer eins oder zwei, nie null. Jede Krone bekommt dabei einen anderen Feind |
| Wirkt auf | `LetterOfMarque.covers` (was der Brief deckt) und `Commission.offer` (wen der Gouverneur ausschreibt) — genau die beiden markierten Stellen |

**Ein laufender Auftrag überlebt den Friedensschluss.** Ihn zu annullieren war die
naheliegende Alternative und wäre falsch gewesen: Bei 8 Tagen Frist und 24 Tagen Legislatur
verlöre etwa jeder dritte Auftrag durch einen Würfel, den der Spieler nicht sieht und gegen
den er nichts tun kann. Der Gouverneur hat den Mann ausgeschrieben, und ein Steckbrief wird
nicht dadurch gegenstandslos, dass die Kronen sich vertragen.

### `world/economy/tavern.gd` + `ui/port/tavern_panel.gd` — die Schenke

Der vierte Hafenbildschirm. **Anheuern** ist aus der Werft hierher gezogen, wo der Kommentar
seit M4 selbst sagte, dass es nicht dorthin gehört — und hat einen zweiten Grund bekommen:
**Berüchtigtheit senkt das Handgeld** um bis zu ein Drittel. Das ist die erste Folge dieser
Achse, die dem Spieler *nützt*; bis dahin hat sie ihm nur Jäger geschickt. Eine Achse, die
nur kostet, ist so wenig eine Entscheidung wie eine, die nur hilft.

**Das Gerede** ist der eigentliche Ertrag. Fünf Zeilen, jede aus einer eigenen Bedingung:
Politik (und was der eigene Brief deshalb deckt), der Gesuchte, der Jäger, ein Handelstipp
in einen Nachbarhafen, und was man über einen selbst sagt.

**Der Gesuchte kreuzt jetzt irgendwo.** Bei der Annahme wird sein Revier festgelegt
(`Commission.waters_for`): der Hafen seiner eigenen Flagge, der dem Ort der Zusage am
nächsten liegt. `NavalCombat` setzt ihn nur innerhalb von 3000 m davon; außerhalb bleibt der
Platz frei und der Kopfgeldjäger rückt nach.

**Und das Revier steht nicht auf dem Steckbrief.** Der Palast sagt, *wer* gesucht wird, und
verweist auf die Schenke; der Wirt sagt, *wo*. Erst danach steht der Ort auf der Seekarte
(`Commission.waters_known` — das einzige Bit Zustand, das ein Besuch hinterlässt). Ohne
diese Trennung wäre die Schenke ein Bildschirm, den niemand je öffnen müsste.

**Sichtbar an vier Stellen** (Regel A8): die Zeile *„Krieg: …"* über der **Seekarte**, der
Absatz im **Gouverneurspalast** („Er deckt Prisen gegen englische Segel — der Krieg dieser
Krone geht gegen England"), dasselbe als Gerede in der **Schenke**, und eine **Meldung im
HUD** an dem Tag, an dem neu verhandelt wird. Die HUD-Meldung ist keine Zugabe: Ohne sie
fände man erst beim nächsten Aufbringen heraus, dass der Brief eine andere Flagge deckt als
gestern.

## Was Grammatik gekostet hat

Drei der vier Kronen sind Eigennamen ohne Artikel, die vierte ist ein Plural mit einem. Im
Bild stand zuerst *„Niederlande liegt im Krieg mit England"* und *„die Niederlande hat ein
Kopfgeld ausgesetzt"* — beides falsch, und beides nur in der Aufnahme zu sehen.

Behoben mit **einem** neuen Feld (`NationData.name_article`, nur bei den Niederlanden
gefüllt) und einer Regel: `subject_name()` liefert den Nominativ („die Niederlande"), und
der ist bei allen vieren auch der Akkusativ — deshalb funktioniert *„gegen die
Niederlande"* damit ebenfalls. Jeder Satz, der einen anderen Fall oder ein anderes Verb
bräuchte, wird stattdessen über das **Adjektiv** gebaut („eine niederländische Fregatte",
„gegen englische Segel"), das im Projekt ohnehin überall benutzt wird.

## Geprüft

- **Rauchtest: 718 Prüfungen, bestanden** (vorher 607). Darunter die Paarungstabelle
  vollständig durchgegangen — jede Zeile ist ihre eigene Umkehrung, jede Krone hat genau
  einen Feind, und jede Umwälzung gibt jeder Krone einen *anderen*. Dazu der Kalender, die
  Determinismus- und die Wechsel-Eigenschaft, die Meldung genau am Tag der Neuordnung, und
  durch die Szene gefahren (Regel C6): **Der Gesuchte läuft in seinem Revier aus und
  außerhalb nicht.**
- **Der Kaperbrief wird jetzt am Kriegsgegner geprüft, nicht an Spanien.** Die alten
  Prüfungen nahmen an, dass ein englischer Brief eine spanische Prise deckt — das hängt seit
  diesem Schritt am Seed. Sie fragen jetzt `WorldData.enemy_of()` und prüfen zusätzlich, dass
  eine Prise gegen eine Krone im Frieden **nichts** einbringt.
- **Der Spielstand** ist auf Version 5 gegangen und trägt Revier und Gehörtes mit. Die Lage
  der Kronen steht bewusst *nicht* darin.
- **Sichtprüfungen angesehen:** `capture_port` (jetzt neun Aufnahmen — Schenke als 16,
  Palast mit bekanntem Revier als 17), `capture_sailing` (die Kriegszeile und der Ortsname
  in der Auftragszeile passen beide in die Breite), `capture_battle` (unverändert im Inhalt,
  zur Sicherheit gefahren).
- **Duell-Messlauf nicht gefahren** — an Ballistik, KI und Kampfbereitschaft wurde nichts
  angefasst. `NavalCombat` hat nur eine Bedingung mehr davor, *ob* ein Benannter gesetzt wird.

## Was als Nächstes zu M6 gehört

**Offiziere** (`KONZEPT.md` 5.1) — der letzte offene Punkt der Schenke, und er ist bewusst
liegengeblieben: Offiziere sind dort Charaktere mit eigener Loyalität, die im Enter-Gefecht
eigene Einheiten führen und sterben können. Beides — Crew-Moral und taktisches Deckgefecht —
gibt es nicht. Ein Offizier ohne das wäre ein Zahlenaufschlag mit Namen, also genau das, was
5.1 ausschließt. Er gehört zu Tier 1, zusammen mit dem, was ihn trägt.

**Nicht gebaut und ausdrücklich Tier 2:** dass Kriegsparteien einander auf See angreifen.
`ShipAI` kennt genau einen Gegner, den Spieler (`NavalCombat._opponent_of` sagt das auch so);
eine Seeschlacht mit drei Parteien ist ein eigener Brocken und steht in Abschnitt 6 als
„Nationen-Kriege mit dynamischen Frontverläufen".

**Und weiter offen aus M5:** der Schiffskauf und die Übernahme einer Prise. Das ist jetzt der
größte Mangel im Spiel — ab dem dritten Auftrag ist das Ziel eine Fregatte, und eine Fregatte
mit einer Startschaluppe zu stellen ist eine Zumutung. Gemeint ist **ein** Schiff (das
Prisenschiff gegen das eigene tauschen), nicht mehrere; Flottenführung bleibt Tier 2.

## Offene Kalibrierung

Drei Zahlen sind abgeleitet oder geraten, keine ist gemessen:

- **`Diplomacy.ERA_DAYS` = 24** ist aus `Commission.DAYS` abgeleitet (dreimal die Frist),
  nicht gespielt. Rund anderthalb Stunden Echtzeit — wenn sich eine Umwälzung zu selten
  anfühlt, ist das die Zahl.
- **`Commission.WATERS_RANGE` = 3000 m** ist gegen `NavalCombat.DESPAWN_DISTANCE` (2600 m)
  gesetzt, damit man dem Gesuchten während der Verfolgung nicht aus seinem eigenen Revier
  fährt. Ob die Frist von acht Tagen für die Anfahrt reicht, hängt daran, wie weit der
  nächste Hafen der gesuchten Flagge liegt — das ist noch nicht gemessen. `world_report.tscn`
  wäre der Ort dafür (Regel C4).
- **`Tavern.FAME_DISCOUNT` = 0,35** und **`Bounty.HUNTED_FROM` = 35** sind beide geraten.

## Fallen

**Backslashes überleben ein Heredoc nicht.** Der Bash-Kanal in dieser Umgebung wandelt `\\`
in `\` um, bevor Python die Zeile sieht — ein Suchmuster mit `\n` darin findet nichts, und
die Meldung ist ein nacktes `AssertionError`. Wer per Skript in Formatzeichenketten patcht,
baut den Backslash über `chr(92)`.

**`const` nimmt kein `PackedInt32Array(...)`.** „Assigned value for constant isn't a constant
expression" — verschachtelte einfache Arrays gehen, der typisierte Konstruktor nicht.

**`godot` liegt nicht im PATH.** Voller Pfad:
`%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe`

**Der Rauchtest braucht hier gut fünf Minuten**, nicht die im README genannte halbe Minute.
Nicht mit einem Hänger verwechseln — im Vordergrund läuft er in eine Zeitüberschreitung.

**Aufnahmen liegen unter `%APPDATA%\Godot\app_userdata\PirateGame\captures`**, nicht unter
dem in `CLAUDE.md` genannten Linux-Pfad.

**Ein neues `class_name` braucht `godot --headless --import`.** Bei `Diplomacy` und `Tavern`
erneut.

**Jeder Testlauf in eine eigene Logdatei.** Zwei Läufe auf dieselbe Datei haben schon einmal
einen Fehlschlag aus einem älteren Lauf vorgetäuscht.

## Veröffentlichte Seite

<https://claude.ai/code/artifact/e6bc946a-c855-4ece-8db9-0bb6c93042f6> — steht auf dem Stand
nach M4 und dem Entern. **M6 fehlt dort noch, inzwischen in vier Schritten.** Wer sie
aktualisiert, benutzt diese URL wieder und holt sich den Bestand vorher über
`action: "read"`; sie wurde zuletzt von anderer Seite neu veröffentlicht, die lokale Kopie
ist also nicht maßgeblich.
