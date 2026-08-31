# Entern gebaut, Unterbesetzung sichtbar

Stand: 31. August 2026. Übergabe an die nächste Sitzung.

Die vorige Sitzung hat das Geschützrichten neu gebaut; das steckt jetzt in Commit `13a2d93`
(„Geschützrichten: die Flugbahn entscheidet, nicht der Würfel"). Diese Sitzung hat den
Nutzer gefragt, wie es weitergeht, und drei Antworten bekommen:

1. **Das Gefecht fühlt sich für ein MVP gut an** — keine Stellschraube anzufassen.
2. **„Prise behalten statt verwerten" zunächst draußen lassen** — später im Gespräch
   zurückgenommen: Die Prise **soll** behalten werden können, nur nicht jetzt.
3. Committen und weitermachen.

---

## Was gebaut wurde

**Das Entern** (`world/combat/boarding.gd`). Bis hierher führte genau ein Weg zur Prise —
den Gegner beschießen, bis er streicht. Damit war Mannschaft im Gefecht nur etwas, das man
*verliert*. `Ship.readiness()` behauptet seit M4 im eigenen Kommentar, die ersten Verluste
kosteten „Enterstärke"; es gab keine. Jetzt gibt es zwei Antworten auf ein fremdes Segel:

| | Reichweite | Kosten | Dauer |
|---|---|---|---|
| Zusammenschießen | 420 m | Zeit, Pulver, eigener Rumpf | Minuten |
| Entern | 45 m | Leute | ein Zug |

Als **Wurf-Auflösung**, nicht als Taktikgefecht — Abschnitt 6 des Konzepts sieht das für
Tier 0 ausdrücklich so vor; das Gitterfeld aus 3.4 ist Tier 1 und braucht Offiziere, die es
noch nicht gibt. Beschrieben in `docs/KONZEPT.md` 7.8b.

**Die ganze Auflösung hängt an einer Zahl.** `Boarding.odds()` liefert den Anteil des
Angreifers an der Gesamtstärke und ist zugleich seine Siegchance **und** das Maß für die
Verluste beider Seiten. Damit braucht es keine getrennte Regel für Sieger und Verlierer: Ein
aussichtsloser Sturm ist ein Gemetzel für den Angreifer, ein übermächtiger kostet fast
nichts, Augenhöhe kostet beide die Hälfte.

**Die Unterbesetzung ist sichtbar geworden.** `Ship.handling()` nimmt seit dem
Geschützrichten Fahrt weg, wenn die Mannschaft unter `min_crew` fällt — nur stand das
nirgends. Der Knotenmesser zeigte zu wenig, und das Schiff sah unbeschädigt aus. Jetzt nennt
die Zustandszeile den Grund („5 von 8 Mann · unterbesetzt") und färbt die Fahrt rot; die
Werft schreibt dasselbe dazu. Die Formel ist dafür von `Ship` nach `SailingMath` gewandert —
HUD und Hafen brauchen sie, wenn gar kein Schiff in der Szene hängt.

**Anheuern gab es schon.** Ich hatte in der Bestandsaufnahme behauptet, Mannschaft sei eine
Einbahnstraße. Falsch: `Shipyard.hire()` sitzt seit M4 in der Werft, mit Handgeld je Mann und
Teilanheuerung. Ich hatte in `modes/port/port_mode.gd` gesucht statt in
`ui/port/shipyard_panel.gd`.

---

## Die Zahlen, die die Mechanik tragen

Bei gleicher Mannschaft steht der Sturm auf **0,43** — schlecht. Das ist Absicht
(`DEFENCE_BONUS` 1,35): Ohne den Verteidigungsvorteil wäre Entern immer die richtige Antwort
und das ganze Schießen überflüssig. Drei Dinge verschieben ihn:

- **Ein zerschossener Rumpf** nimmt den Verteidigern den Mut (`HULL_MORALE`). Eine Breitseite
  vor dem Übersetzen lohnt sich also, auch wenn sie den Gegner nicht zum Streichen bringt.
- **Berüchtigtheit** zählt an Deck (`FEAR_BONUS`) — der gefürchtete Pirat aus 3.4. Zum ersten
  Mal zahlt sich ein Ruf im Spiel überhaupt aus.
- **Überzahl**, offensichtlich.

In Klassen gerechnet: volle Schaluppe (40 Mann) gegen unversehrte Handelsbrigg (26) = 0,53,
knapp lohnend. Gegen eine unversehrte Patrouillenschaluppe (46) = 0,39 — dafür muss man erst
schießen oder sich einen Ruf erarbeitet haben. Genau diese Abwägung soll die Mechanik tragen.

Nach einem Sturm sind die Enterhaken 25 Sekunden unklar. Ohne diese Sperre wäre ein
abgeschlagener Sturm nur ein zweiter Tastendruck.

---

## Der Fehler, der eine Regel wurde

Prise, Entern und Anlegen liegen alle auf der Leertaste und teilen sich eine Zeile im HUD.
Jedes der drei Signale hat die Zeile für sich beschrieben — und beim Leerwerden *gelöscht*.
Fuhr man an einem Hafen vorbei und geriet dabei ein Gegner aus der Enterreichweite,
verschwand die Aufforderung zum Anlegen, obwohl der Hafen noch dalag.

Angelegt war der Fehler schon zwischen Prise und Hafen; mit dem dritten Schreiber wurde er
echt. Steht jetzt als **Regel B15** in `docs/RICHTLINIEN.md`: *Ein Anzeigefeld hat einen
Schreiber* — und zwar ab dem zweiten Signal, nicht ab dem dritten.

---

## Geprüft

- **Rauchtest: 413 Prüfungen, bestanden.** Darunter der Enterkampf gerechnet (Reichweite,
  Stärkeverhältnis, Verluste, 400 Läufe gegen die Siegchance) *und* durch die Szene gefahren
  (Regel C6): längsseits gehen, übersetzen, Deck nehmen, danach liegt er als Prise da und die
  Haken sind unklar.
- **`tests/capture_battle.tscn` hat drei Aufnahmen dazubekommen** — Enterreichweite, der
  Sturm mit seiner Verlustmeldung, und die rote Zustandszeile danach. Alle acht angesehen.
- `capture_sailing` und `capture_port` ebenfalls: Zustandszeile und Werft stimmen.
- `capture_island`, `capture_town` und `capture_ship` **nicht** neu gefahren — an Gelände,
  Siedlungen und Schiffsmodell wurde nichts angefasst.

Eine Prüfung schlug zunächst fehl und war selbst falsch: Sie erwartete, dass die
Enterverluste in `GameState` landen. Diese Verdrahtung macht `SailingMode`, das im Rauchtest
gar nicht läuft. Geprüft wird jetzt das Signal `Ship.condition_changed`, an dem sie hängt.

---

## Was offen ist

An M5 hängt die Abnahmebedingung „ein kompletter Aufstieg vom Startschiff zu einem größeren
Schiff ist spielbar". Dafür fehlen **beide** Wege zu einem besseren Schiff:

- **Der Schiffskauf.** `base_price` steht bereits in jeder `.tres`; es fehlt der Bildschirm
  in der Werft und der Wechsel der Klasse im laufenden Spiel.
- **Die Prise übernehmen.** Der Nutzer wollte das zuerst herauslassen und hat es im selben
  Gespräch zurückgenommen: Es **soll** gebaut werden, nur später. Heute räumt
  `NavalCombat.take_prize()` das Schiff aus und `_release()` lässt es davontreiben; dort
  gehört die Entscheidung hin. Gemeint ist **ein** Schiff — das Prisenschiff gegen das eigene
  tauschen, mit allem, was daran hängt: Ladung umladen oder verlieren, Mannschaft aufteilen,
  der eigene Rumpf ist weg. *Mehrere* Schiffe zu führen ist Flottenführung (KONZEPT 5.4) und
  bleibt Tier 2. Wer das verwechselt, baut aus einem M5-Schritt ein Tier-2-System.
- **Ziellinie aus der mittleren Kanone** (Regel A8). Der Nutzer sagt, das Gefecht fühle sich
  für ein MVP gut an — also nicht gebaut. Bleibt vorgemerkt, falls sich das Zielen später
  doch blind anfühlt.
- **Die Meeresoptik** — Diagnose und Maßnahmen in `docs/KONZEPT.md` 11. **Weiterhin
  ausdrücklich auf später verschoben, nicht ungefragt anfangen.**

## Fallen

**Ein neues `class_name` braucht `godot --headless --import`.** Bei `Boarding` wieder
zugeschlagen — das dritte Mal in zwei Sitzungen. `Boarding.Result` ist deshalb eine *innere*
Klasse: eine Datei weniger, ein Import weniger, den man vergessen kann.

**`godot` liegt auf diesem Rechner nicht im PATH.** Der volle Pfad ist
`%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe`.

**Der Rauchtest braucht länger als das Werkzeug-Zeitlimit von drei Minuten.** Im Hintergrund
laufen lassen und in eine Logdatei schreiben — und zwar in **je eine eigene**: Zwei Läufe auf
dieselbe Datei haben mich einmal einen Fehlschlag lesen lassen, der aus dem älteren Lauf kam.

**Ein zwei Stunden alter, leerer `.git/index.lock` blockierte git.** Abgestürzter Vorgang,
kein laufender — entfernt.

## Arbeitsverzeichnis

`13a2d93` enthält das Geschützrichten. **Alles aus dieser Sitzung ist uncommittet.** Der
Nutzer hat für den vorigen Stand um einen Commit gebeten, nicht pauschal für alles Weitere —
also nachfragen.

Die veröffentlichte Seite ist weiterhin auf M3-Stand:
<https://claude.ai/code/artifact/e6bc946a-c855-4ece-8db9-0bb6c93042f6> — wer sie
aktualisiert, benutzt diese URL wieder und holt sich den Bestand vorher über
`action: "read"`.
