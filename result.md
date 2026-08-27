# Geschützrichten — Spezifikation und Übergabe

Stand: 27. August 2026. Zwei Teile:

- **Teil A** ist die beschlossene Spezifikation für das neue Richten der Geschütze.
  Noch nicht gebaut.
- **Teil B** ist die Übergabe an die nächste Sitzung: was gerade im Arbeitsverzeichnis
  liegt, was gilt und was schiefgehen wird. Steht so weder in `CLAUDE.md` noch auf der
  veröffentlichten Konzeptseite.

---

# Teil A — Die Spezifikation

## Warum überhaupt

Heute ist Treffen ein verdeckter Würfelwurf: Aus dem Winkel zum Ziel wird eine „Lage"
zwischen 0 und 1, daraus eine Wahrscheinlichkeit, und die Kugeln fliegen *danach* zu einem
Ergebnis, das schon feststeht. Die Flugbahn ist Dekoration.

Neu ist die **Flugbahn die Wahrheit**. Wo die Rohre hinzeigen, fliegen die Kugeln, und ob
sie treffen, entscheidet die Geometrie. Ziel: nicht drücken, sondern treffen wollen.

## Die fünf Entscheidungen

| # | Frage | Entschieden |
|---|---|---|
| 1 | Wer schwenkt die Rohre? | **Die Mannschaft, automatisch.** Sie richtet auf das Ziel, solange es im Kegel liegt. Das Zielen des Spielers ist das Ruder. |
| 2 | Ziel außerhalb des Kegels? | **Bis zum Anschlag schwenken und daneben schießen.** Man sieht die Salve vorbeigehen und weiß, wohin man drehen muss. |
| 3 | Vorhalten? | **Ja, aber ungenau.** Der Fehler wächst mit der Entfernung und mit fehlenden Leuten. Dort lebt der Rest des Zufalls. |
| 4 | Streuung? | **Klein je Rohr, wachsend mit der Entfernung.** Sonst treffen immer alle oder keiner. |
| 5 | Ladezeit aus der Mannschaft? | **Mindestbesatzung plus zwei Mann je Rohr.** Siehe unten. |

**Schwenkbereich: ±20°** um querab, für alle Klassen als Startwert
(`ShipClass.gun_traverse`). Heute sind es 70° — der Kegel wird also mehr als dreimal so
eng, und genau das erzwingt das Zielen.

## 1. Die Richtung der Salve

Alle Rohre einer Seite feuern **parallel**. Es gibt genau eine Richtung je Breitseite, die
der mittleren Kanone; die anderen laufen versetzt daneben her.

```
abeam    = heading + side · 90°           side: −1 Backbord, +1 Steuerbord
offset   = angle_difference(abeam, bearing_auf_vorhaltepunkt)
aim      = abeam + clamp(offset, −TRAVERSE, +TRAVERSE)
```

Kein Ziel auf dieser Seite: `aim = abeam`. Die Salve geht genau querab, ohne Korrektur.

## 2. Der Vorhaltepunkt

Ein Gegner auf 300 Metern ist nach der Flugzeit rund zehn Meter weiter. Die Mannschaft
hält vor, aber nicht genau:

```
flight    = CannonBall.flight_time(distance)          bereits vorhanden
predicted = ziel.position + ziel.velocity · flight
error     = randf_range(−1, 1) · LEAD_SPREAD · (distance / IDEAL_RANGE) / readiness
predicted += ziel.vorwärtsrichtung · error
```

`LEAD_SPREAD` als Startwert **6 m**. Auf idealer Entfernung mit voller Bedienung sind das
±6 m Fehler entlang des gegnerischen Kurses — bei einem vierzehn Meter langen Rumpf noch
ein Treffer. Auf doppelter Entfernung ±12 m, also schon ein Vorbeischuss.

Damit ist das Nähergehen belohnt, ohne dass eine einzige Wahrscheinlichkeit im Spiel ist.

## 3. Die einzelnen Kugeln

Die Rohre stehen über die Schiffslänge verteilt, `GUN_SPACING = 1.6 m`, mittig um den
Rumpfmittelpunkt. Jede Kugel startet an ihrer eigenen Mündung und fliegt in Richtung `aim`,
gedreht um ihre eigene kleine Streuung:

```
spread_i = randf_range(−1, 1) · SPREAD_DEG · (distance / IDEAL_RANGE) / readiness
```

`SPREAD_DEG` als Startwert **1.2°**. Auf 150 m sind das ±3 m quer — genug, dass eine Salve
auch mal zwei von drei trifft, zu wenig, um das Zielen zu entwerten.

## 4. Der Trefferentscheid

Weiter ohne Kollisionskörper, weiter beim Abfeuern gerechnet (Regel B12). Neu ist nur, dass
gerechnet statt gewürfelt wird:

1. Für jede Kugel den Punkt bestimmen, an dem sie die Entfernung des Ziels erreicht.
2. Prüfen, ob dieser Punkt im **gedrehten Rechteck** des Ziels liegt: Länge
   `2 · half_length`, Breite `2 · half_beam`, gedreht auf dessen Kurs, an dessen Position
   zum Aufschlagzeitpunkt.

Das ist ein Punkt-in-Rechteck-Test, statisch prüfbar, ohne Nodes.

**Damit wird die Lage des Gegners zu einer eigenen Größe.** Ein Schiff quer zu dir ist
vierzehn Meter breit im Anschlag, dasselbe Schiff mit dem Bug zu dir drei. Wer sich dem
Feind zudreht, macht sich schmal. Das gibt es heute überhaupt nicht.

Die Trefferzonen (Rumpf nah, Takelage fern, Mannschaft immer) bleiben unverändert — sie
hängen an der Entfernung, nicht am Winkel.

## 5. Mannschaft und Ladezeit

Zwei getrennte Aufgaben:

```
segelnd   = min_crew                     nötig, um das Schiff überhaupt zu fahren
an Rohren = cannon_slots · 2             für die volle Ladegeschwindigkeit
```

```
verfügbar = max(crew − min_crew, 0)
readiness = clamp(verfügbar / (cannon_slots · CREW_PER_GUN), MIN_READINESS, 1.0)
reload    = RELOAD_SECONDS / readiness
```

`CREW_PER_GUN = 2`, `MIN_READINESS = 0.35`.

Gezählt werden **alle** Rohre, nicht die einer Seite: Beide Batterien laden bei uns
gleichzeitig, also braucht auch jede ihre eigene Bedienung. Wer das anders will — Mannschaft
läuft von Bord zu Bord, nur die größere Seite zählt — ändert eine Zeile.

`readiness` geht auch in den Vorhaltefehler und in die Streuung ein (siehe oben). Eine
dezimierte Mannschaft lädt also langsamer *und* trifft schlechter, ohne dass es dafür eine
zweite Zahl bräuchte.

### Was das für die drei Klassen heißt

| Klasse | `min_crew` | Rohre | voll bedient ab | `max_crew` |
|---|---|---|---|---|
| Schaluppe (Spieler) | **4** *(heute 8)* | 6 | 4 + 12 = **16** | 40 |
| Handelsbrigg | 10 | 6 | 10 + 12 = **22** | 26 |
| Patrouillenschaluppe | 18 | 10 | 18 + 20 = **38** | 46 |

Die Schaluppe ist damit deutlich übermannt — 40 Mann, 16 gebraucht. Das ist stimmig
(Piraten fuhren mit doppelter Besatzung, um entern zu können) und hat eine Folge, die man
kennen sollte: **Mannschaftsverluste kosten zuerst Enterstärke, erst spät Feuergeschwindigkeit.**
Kartätschen wirken beim Spieler also verzögert. Falls sich das im Spiel zahnlos anfühlt, ist
die Stellschraube `max_crew` der Schaluppe, nicht die Formel.

### Unter der Mindestbesatzung

Aus „Mindestbesatzung, die zum Steuern benötigt wird" folgt, dass es darunter nicht mehr
richtig geht. Vorschlag, klein gehalten:

```
handling = clamp(crew / min_crew, 0.3, 1.0)
```

Faktor auf die Segelwirkung, analog zu `sail_health()`. Ein Schiff mit zwei von vier Mann
kriecht dann noch, fährt aber nicht mehr.

## 6. Was der Spieler davon sieht

- Die Salve fliegt sichtbar **parallel** und geht bei falscher Lage sichtbar **vorbei**.
  Heute landet ein Fehlschuss als Fontäne irgendwo neben dem Ziel, was aussieht wie Pech.
  Künftig sieht man, dass zu weit vorn gehalten wurde.
- Die Batteriezeile im HUD („lädt / bereit / **liegt an**") behält ihre Bedeutung und wird
  sogar wörtlich: *liegt an* heißt jetzt, dass die Rohre das Ziel wirklich bekommen.
- Optional (Regel A8): eine kurze Ziellinie aus der mittleren Kanone, solange die Batterie
  geladen ist. Nicht Teil dieser Spezifikation, aber der naheliegende nächste Schritt, wenn
  sich das Zielen blind anfühlt.

## 7. Betroffene Dateien

| Datei | Änderung |
|---|---|
| `data/ship_class.gd` | `gun_traverse: float = 20.0` |
| `resources/ships/*.tres` | `gun_traverse`, `min_crew` der Schaluppe auf 4 |
| `world/combat/gunnery.gd` | `FIRING_ARC` raus; `aim_direction()`, `lead_point()`, `hits_target()`, `readiness()`; `resolve_salvo()` von Wahrscheinlichkeit auf Geometrie |
| `world/combat/shot.gd` | statt `scatter` die tatsächliche Richtung und der Aufschlagpunkt |
| `world/combat/naval_combat.gd` | `_on_fire_requested` übergibt Position, Kurs, Fahrt und Maße des Ziels; `_launch_balls` fliegt in `aim` statt zum Ziel |
| `entities/ship/ship.gd` | `readiness()` statt `crew_fraction()` für die Ladezeit; `handling()` |
| `entities/ship/ship_ai.gd` | `should_fire` auf den Kegel umstellen — **siehe Risiko unten** |
| `ui/hud/sailing_hud.gd` | „liegt an" aus dem Kegel statt aus `bearing_quality` |
| `tests/smoke_test.gd` | Ballistikprüfungen neu; Duell-Schwellen neu messen |

---

# Teil B — Übergabe

## Das größte Risiko: die KI trifft nichts mehr

**Das wird passieren, wenn man es nicht vorher behandelt.**

Die Schiffs-KI hält im Gefecht einen Platz längsseits und feuert, wenn `bearing_quality`
über 0.35 liegt. Gemessen wurde beim Bau von M4, dass sie sich bei rund **0.44** einpendelt.
Mit dem heutigen Feuerbereich von 70° entspricht das einer Abweichung von

```
(1 − 0.44) · 70° ≈ 39° von querab
```

**39° liegen außerhalb eines ±20°-Kegels.** Die KI würde also dauerhaft danebenschießen —
genau der Zustand, der beim Bau von M4 schon einmal auftrat: achtzig Sekunden Gefecht,
sieben Punkte Schaden.

Wer das umstellt, muss also gleichzeitig die Bahnführung in `ShipAI` enger machen
(`STATION_TOLERANCE`, `HELM_GAIN`, evtl. ein richtiger Regler auf den Winkel statt auf den
Platz) und **das Duell im Rauchtest neu messen**, nicht die alten Zahlen übernehmen.

Die Zahlen im Duelltest (`158 gegen 25 Punkte Schaden`, `nach 134 s`) stehen so auch in
`README.md`, `docs/KONZEPT.md` Abschnitt 10 und in `docs/RICHTLINIEN.md` C4 — alle drei
Stellen mitziehen.

## Was gerade im Arbeitsverzeichnis liegt

**Der letzte Commit ist `8677868` und enthält nur M3.** Alles, was M4 ausmacht, ist
**uncommittet**: rund 1500 Zeilen in 26 geänderten und 10 neuen Dateien.

- neu: `world/combat/` (vier Dateien), `entities/ship/ship_ai.gd`, `ui/debug/`,
  `tests/capture_battle.*`, `resources/ships/merchant_brig.tres`,
  `resources/ships/patrol_sloop.tres`, `CLAUDE.md`, diese Datei
- Der Nutzer hat **nicht** um einen Commit gebeten. Nicht ungefragt committen.

## Die veröffentlichte Seite ist auf M3-Stand

<https://claude.ai/code/artifact/e6bc946a-c855-4ece-8db9-0bb6c93042f6>

Sie beschreibt das Projekt bis einschließlich M3 (Häfen und Handel). **M4 steht dort
nicht.** Wer sie aktualisiert, muss die URL wiederverwenden, nicht neu veröffentlichen.
Quelle war eine HTML-Datei im Scratchpad der damaligen Sitzung — die ist weg, die Seite
lässt sich über `action: "read"` zurückholen.

## Fallen, die Zeit gekostet haben

**Ein neues `class_name` braucht `godot --headless --import`.** Sonst scheitert der
Rauchtest mit „Could not find type X in the current scope". Sieht aus wie ein Codefehler,
ist keiner.

**Der Editor des Nutzers läuft oft mit.** Ein gleichzeitiger Import blockiert. Einmal hat
eine Aufnahme dabei Unsinn geliefert (Gegner auf 4 statt 540 Metern); zwei saubere Läufe
danach waren korrekt. Bei absurden Messwerten erst wiederholen, bevor man sucht.

**`get_shader_parameter()` gibt Vorgabewerte nicht heraus.** Solange niemand eine Uniform
ausdrücklich gesetzt hat, kommt `null` zurück — nicht der im Shader deklarierte Wert.
Deshalb gehört so eine Einstellung dem Knoten (`Ocean.show_grid`), nicht dem Abfragenden.

**Der Rauchtest fährt zwei echte Gefechte** mit `Engine.time_scale = 15` bei 120 Hz. Das
sind rund 20 der 35 Sekunden Laufzeit. Wer den Test beschleunigen will, dreht dort — nicht
am Rest.

## Entscheidungen aus M4, die man nicht aus dem Code liest

- **Munitionstypen wurden verworfen.** Rundkugel/Kettenkugel/Kartätsche hätten dasselbe
  geleistet wie die Entfernung — Rumpf, Takelage oder Mannschaft treffen —, aber über ein
  Menü statt über das Ruder. Steht als Abweichung in `docs/KONZEPT.md` §3.2.
- **`FIRING_ARC = 70°` wurde gemessen, nicht geschätzt.** 50° waren zu eng: Eine
  Verfolgungskurve passt nicht hindurch. Mit ±20° kehrt genau dieses Problem zurück,
  diesmal absichtlich — deshalb der Punkt oben zur KI.
- **Reffen im Gefecht wurde wieder ausgebaut.** Klang richtig, kostete ein Drittel Fahrt,
  und die Beute entkam jedes Mal.
- **`spawn_now()` übergeht `max_ships` mit Absicht.** Der Debug-Knopf soll gerade dann
  helfen, wenn sonst nichts kommt.
- **Eine neue Kampagne startet mit voller Besatzung** (`crew = max_crew()`), nicht mit 20.
  Sonst führe man von Anfang an mit halber Ladegeschwindigkeit.
- **Die Werft heuert an**, obwohl das in die Taverne gehört (M6). Ohne Weg zurück wäre
  Mannschaftsverlust eine Sackgasse.

## Was der Nutzer an der See stört

Licht, Schatten und Wellen wiederholen sich wie ein Schachbrett. Diagnose und Maßnahmenliste
stehen in `docs/KONZEPT.md`, Abschnitt 11, „Vorgemerkt: Überarbeitung der Meeresoptik".
**Ausdrücklich auf später verschoben** — nicht ungefragt anfangen. Das Debug-Menü (F3) hat
einen Schalter für das Gitternetz, damit sich trennen lässt, was davon das Gitter ist und
was die Wellenformel.

## Arbeitsweise, die sich bewährt hat

Vier Fehler in M4 waren headless unsichtbar und kamen ausschließlich aus den Aufnahmen:
schwebende Häuser, durchsichtige Küste, ein Gegner außerhalb des Bildes, ein Mündungsrauch,
der das eigene Schiff verdeckte. **Nach jeder sichtbaren Änderung alle Aufnahmen ansehen**,
nicht eine.

Und: Balancewerte werden gefahren, nicht geschätzt. Für die neue Ballistik heißt das, den
Duelltest als Messgerät zu benutzen und `LEAD_SPREAD`, `SPREAD_DEG` und den Schaden je
Kugel daran einzustellen — die Trefferzahl steigt bei Breitseite gegen Breitseite deutlich,
also muss der Schaden runter.
