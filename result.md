# Geschützrichten — gebaut und gemessen

Stand: 31. August 2026. Die Spezifikation aus der vorigen Sitzung (hier früher als „Teil A")
ist umgesetzt. Was jetzt hier steht, ist die Übergabe an die nächste Sitzung: was gebaut
wurde, welche Zahlen dabei herauskamen, was davon *nicht* in der Spezifikation stand und
was offen bleibt.

Die Spezifikation selbst steht nicht mehr in dieser Datei — sie ist Code geworden, und die
Begründungen stehen dort, wo die Konstanten stehen (`world/combat/gunnery.gd`,
`entities/ship/ship_ai.gd`). `docs/KONZEPT.md` §7.8 beschreibt das System, §10 den Umbau.

---

## Was gebaut wurde

**Treffen wird gerechnet, nicht gewürfelt.** Die Rohre schwenken ±20° um querab
(`ShipClass.gun_traverse`), alle Rohre einer Seite feuern parallel, jede Kugel hat ihre
eigene Mündung und ihren eigenen Aufschlagpunkt, und ob sie trifft, entscheidet ein
Punkt-in-Rechteck-Test gegen den Rumpf des Gegners. `BASE_ACCURACY`, `FIRING_ARC`,
`range_factor()`, `hit_chance()` und `Shot.scatter` sind ersatzlos weg.

**Die Mannschaft hat zwei Aufgaben.** `min_crew` fährt das Schiff, der Rest bedient die
Rohre (`Gunnery.readiness`, zwei Mann je Rohr). Darunter kostet es Fahrt
(`Ship.handling()`). Die Schaluppe steht auf `min_crew = 4`, ist also mit 40 Mann deutlich
übermannt — Mannschaftsverluste kosten beim Spieler zuerst Enterstärke, erst spät
Feuergeschwindigkeit.

**Neue Datei:** `world/combat/target_profile.gd` (`TargetProfile`) — Position, Fahrt, Kurs
und Maße eines Ziels. Ohne sie bräuchte `resolve_salvo()` zwölf Parameter.

**`CannonBall.flight_time()` ist nach `Gunnery` gewandert.** Das Vorhalten braucht die
Flugzeit; die Ballistik darf die Darstellung nicht kennen, sonst zeigen zwei `class_name`
aufeinander und Godot löst keine von beiden mehr auf.

**Neue Szene `tests/duel.tscn`** — mit Fenster ein Gefecht zum Spielen (R neuer Gegner,
G Klasse, H Ausgangslage), ohne Fenster fünfzehn Gefechte KI gegen KI mit Kennzahlen.
Details in `README.md` und `CLAUDE.md`.

---

## Die eine Entscheidung, die nicht in der Spezifikation stand

**Die Kugel streut seitlich, nicht in der Tiefe.** Sie liegt immer auf der geschätzten
Entfernung. Das sieht nach einer Lücke aus und ist keine: Genau daran hängt der Satz „wer
sich dem Feind zudreht, macht sich schmal". Mit einem Streuen auch in der Tiefe wäre ein
Schiff mit dem Bug voran das *leichtere* Ziel, weil es in Schussrichtung länger ist als
breit — das Gegenteil dessen, was der Spieler sieht. Der Vermerk steht in
`Gunnery.hits_target()` und in `CLAUDE.md`; wer das ändern will, muss zuerst diesen Satz
aufgeben.

---

## Was die Messung erzwungen hat

Die Spezifikation hat richtig vorhergesagt, dass die KI im engen Kegel nichts mehr trifft.
Sie hat nur unterschätzt, wie tief der Umbau geht. Gemessen wurde mit
`tests/duel.tscn --headless`; die entscheidende Spalte ist **„liegt an"** — der Anteil der
Zeit, in dem überhaupt ein Rohr am Ziel war.

| Schritt | liegt an | Bemerkung |
|---|---|---|
| KI aus M4, Platz längsseits | 12 % | Verfolger läuft über den Platz hinaus und dreht ewig zurück |
| Segelstellung nach Position | 12 % | brachte nichts — das Problem war der Kurs, nicht die Fahrt |
| Abfangkurs auf den mitfahrenden Platz | 13 % | besser, aber der Platz bleibt zu weit vorn |
| Spirale (Vorhalt auf die Peilung) | **55 %** | der Platz ist ersatzlos entfallen |

`ShipAI.station()`, `station_course()` und `station_lead()` gibt es nicht mehr. An ihrer
Stelle steht `engage_course()`: ein Vorhalt auf die Peilung, weit draußen null, auf
`BEAM_RANGE` (100 m) volle neunzig Grad. Dazu drei Werte, die alle aus Messungen kommen und
nicht aus Überlegung: `HELM_GAIN` 2,4 → 3,4, `SIDE_HYSTERESIS` 0,44 → 1,2 rad (die Seite
flatterte und das Schiff fuhr Schlangenlinien), und `FIRE_RANGE` = 225 m, weil die KI sonst
auf 400 Meter schoss und pro Salve neun Sekunden Nachladen verschenkte.

**Der Schaden je Kugel blieb bei den M4-Werten (8 / 10 / 2).** Der erste Ansatz war 4 / 5 / 1
— „eine richtig gelegte Breitseite trifft jetzt fast alles, also muss der Schaden runter".
Gefahren stimmte das nicht: Es fallen so viel *weniger* Salven, dass sich beides aufhebt.
Bei 4 / 5 / 1 hat in fünf Läufen kein einziger Gegner die Flagge gestrichen.

**Der Duelltest im Rauchtest läuft jetzt gegen ein Kriegsschiff.** Gegen eine fliehende
Handelsbrigg sagt ein Duell nur, wer schneller ist — sie entkommt der KI in vier von fünf
Läufen, und das soll auch so bleiben. Ergebnis: **123 gegen 18 Punkte Schaden**, Flagge
nach 30 Sekunden. Der Wind steht dabei querab statt aus Nord: Beide Schiffe starten auf
Nordkurs und lägen sonst in Irons — das „Gefecht" war bis M4 eines zwischen zwei Schiffen,
die sich kaum bewegen.

---

## Was offen ist

- **Ziellinie aus der mittleren Kanone.** Die Spezifikation nennt sie als naheliegenden
  nächsten Schritt (Regel A8), falls sich das Zielen blind anfühlt. Noch nicht gebaut —
  erst spielen, dann entscheiden. `tests/duel.tscn` ist genau dafür da.
- **Die Schaluppe des Spielers gegen alles.** Gemessen ist bisher nur, wie sich die KI
  schlägt. Ob sich das Zielen mit der Hand am Ruder *gut anfühlt*, sagt keine Tabelle.
- **`Ship.handling()` hat noch keine Anzeige.** Wer unter die Mindestbesatzung fällt, wird
  langsamer und erfährt es nur daran, dass die Knotenzahl nicht mehr stimmt.
- **Die Meeresoptik** — Licht, Schatten und Wellen wiederholen sich wie ein Schachbrett.
  Diagnose und Maßnahmen in `docs/KONZEPT.md` §11. **Ausdrücklich auf später verschoben,
  nicht ungefragt anfangen.** F3 hat einen Schalter fürs Gitternetz, um zu trennen, was
  davon das Gitter ist und was die Wellenformel.

## Fallen, die auch diesmal Zeit gekostet haben

**Ein neues `class_name` braucht `godot --headless --import`.** Bei `TargetProfile` wieder
zugeschlagen. Sieht aus wie ein Codefehler, ist keiner.

**Zwei `class_name`, die aufeinander zeigen, lösen sich nicht auf.** Deshalb ist
`flight_time()` von `CannonBall` nach `Gunnery` gewandert und nicht umgekehrt.

**Balancewerte am Ergebnis zu messen führt in die Irre.** Der Schaden je Gefecht schwankt
zwischen zwei Läufen um den Faktor drei. Drei verschiedene KI-Umbauten hätte man daran
nicht auseinanderhalten können — erst die Spalte „liegt an" hat gezeigt, welcher davon
wirkt. Steht jetzt als Regel in `docs/RICHTLINIEN.md` C4.

**Die veröffentlichte Seite ist weiterhin auf M3-Stand.**
<https://claude.ai/code/artifact/e6bc946a-c855-4ece-8db9-0bb6c93042f6> — weder M4 noch das
Geschützrichten stehen dort. Wer sie aktualisiert, benutzt diese URL wieder, statt neu zu
veröffentlichen, und holt sich den Bestand vorher über `action: "read"`.

## Arbeitsverzeichnis

Alles oben Beschriebene ist **uncommittet**. Der letzte Commit ist `e8f5e35` und enthält M4.
Der Nutzer hat nicht um einen Commit gebeten — nicht ungefragt committen.
