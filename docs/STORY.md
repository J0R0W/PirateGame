# Story-Konzept — Arbeitstitel „Der Kaperbrief"

Ergänzt `KONZEPT.md`, ersetzt nichts daran. Die Sandbox-Vision (KONZEPT Abschnitt 1) bleibt die
Grundlage — dieses Dokument beschreibt einen **optionalen Erzählstrang**, der von Kampagnenbeginn
an neben ihr läuft und am Ende organisch in dieselbe offene Spielwelt übergeht. Kein Ersatz für
„Freiheit vor Führung", sondern ein Angebot innerhalb davon.

**Status:** Konzeptentwurf (31.08.2026), noch nicht in Meilensteine eingeplant. Wird nach M6
(„Welt reagiert") relevant, weil er auf Ruf, Kaperbriefen und Gouverneurs-Aufträgen aufsetzt.

---

## 1. Grundton

Politisch-intrigant, **kein Übernatürliches**. Der Konflikt entsteht aus Verrat, Bündnissen und
Informationshoheit zwischen den vier Kolonialmächten (KONZEPT 4.2, Schritt 5 „Nationen") — nicht
aus Flüchen, Legenden oder verborgener Magie.

## 2. Prämisse

Die vier Nationen sitzen bereits als verzahnte Regionen in der Weltgenerierung — das ist die
Bühne, nicht neu zu bauen. Aufhänger: Der Spieler stolpert früh über ein **Dokument** — eine
geheime Absprache zwischen zwei Gouverneuren (Marktabsprache, Kriegsvorbereitung, Verrat an der
eigenen Krone). Ab diesem Moment ist er kein neutraler Handelskapitän mehr, sondern ein Faktor,
um den vier Höfe konkurrieren. Das trägt „Spielball der Nationen" wörtlich.

## 3. Herkunft — die persönliche Ebene

Kurze Wahl bei Kampagnenstart (wie die Schiffsklassenwahl: ein paar Karten, kein
Charaktereditor). Sie färbt, *warum* das Dokument den Spieler persönlich trifft — nicht *was*
passiert. Alle vier Optionen sind Varianten desselben Akt-1-Ereignisses, kein eigener
Handlungsstrang.

| Herkunft | Ausgangslage | Verknüpfung zu Akt 1 | Tendenz |
|---|---|---|---|
| **Die Enteigneten** *(empfohlener Standard)* | Ein Gouverneur hat der Familie Land oder Schiff genommen, formal legal, faktisch Willkür | Genau dieser Gouverneur taucht im Dokument auf | Kampf & Furcht |
| **Die/der Gesuchte** | Desertiert aus Marine oder Handelsflotte, Gründe werden erst spät offengelegt | Das Dokument kommt über das Schmugglernetz, das damals half | Kampf & Furcht oder Diplomatie (Rehabilitierung) |
| **Der/die Verschollene** | Sucht eine verschwundene Person (Geschwister, Mentor, alte Kapitänin) | Das Dokument enthält einen Namen/Hinweis, der weiterhilft | Entdeckung & Wissen |
| **Der Aufsteiger ohne Namen** | Keine Vorgeschichte, nur Ehrgeiz | Reiner Zufallsfund | neutral |

Mechanisch: Dialog-/Flavortext plus ein Start-Ruf-Modifikator bei einer Nation (nutzt KONZEPT
5.3, keine neue Zahl). Die vierte Option hält die Wahl selbst optional — wer keine persönliche
Vorgeschichte will, muss keine nehmen.

## 4. Drei Akte

**Akt 1 — Der Kaperbrief.** Leicht geführt, nicht erzwungen. Spieler erhält von einer
Startnation einen Kaperbrief, macht seine erste Prise, gerät dabei an das Dokument. Vermittelt
nebenbei die Grundmechaniken (Segeln, Hafen, Gefecht, Entern). Endet damit, dass er auffällt.

**Akt 2 — Die vier Höfe.** Keine Questline, sondern benannte NPCs (Gouverneur, Agent, Rivale),
die über Taverne/Gouverneurspalast (KONZEPT 3.3) Angebote machen — je eines pro Pfad, siehe
Abschnitt 5. Pfade schließen sich nicht hart aus; der Spieler bindet sich über die Zeit, weil
sich Ruf/Berüchtigtheit/Wissen natürlich in eine Richtung aufsummieren.

**Akt 3 — Das Gleichgewicht kippt.** Wendepunkt, dessen Ausprägung vom dominanten Pfad abhängt:
als gefürchteter Freibeuter-Fürst mit eigener Basis anerkannt (→ KONZEPT 5.4/5.5, als *Ziel*,
nicht als Voraussetzung), als Adliger mit Landbesitz, oder als unabhängiger Chronist mit
Sonderzugang zu allen Häfen. Kein Abspann: Der letzte Story-Beat schreibt dauerhaft in
`GameState` (Titel, Freischaltungen, Beziehungen), danach läuft dieselbe Sandbox weiter.

## 5. Pfade

| Pfad | Wie er andockt | Nutzt bestehende/geplante Systeme |
|---|---|---|
| **Kampf & Furcht** | Eine Fraktion will das Dokument als Kriegsgrund — Spieler soll Terror säen, Handelsschiffe kapern, Kopfgelder auf sich ziehen | Berüchtigtheit, Kopfgeldjäger (KONZEPT 5.3) |
| **Diplomatie & Beziehungen** | Ein Gouverneur bietet Amt, Landbesitz, ggf. eine arrangierte Ehe als politisches Bündnis | Ruf, Gouverneurspalast (KONZEPT 3.3) |
| **Entdeckung & Wissen** | Spieler verfolgt die Herkunft des Dokuments selbst statt Partei zu ergreifen | Erkundungspunkte (KONZEPT 3.5) |

**Zur Beziehungsfrage:** Bewusst **keine** eigene Romantik-Mechanik (keine Zuneigungs-Leiste,
kein Geschenke-System) — `KONZEPT.md` 1 schließt das explizit aus, aus Scope-Gründen. Die
arrangierte Ehe im Diplomatie-Pfad ist nur ein Dialog-Angebot mit Folgen im bestehenden
Ruf-System plus Landbesitz-Zugang, keine neue Zahl, kein neues Fenster.

## 6. Gimmicks

Alle als Resource-Varianten bestehender Systeme (KONZEPT B2: Balancing in Dateien), keine neuen
Systeme:

- **Nations-Kanonen** — ein `CannonType` pro Nation mit Eigenart statt reiner Zahlen (z. B.
  weittragend, aber langsam nachladend), nur über Ruf/Kaperbrief bei dieser Nation käuflich.
- **Empfehlungsschreiben** (Diplomatie) — öffnet einen sonst gesperrten Hafen trotz schlechtem
  Ruf bei einer anderen Nation.
- **Berüchtigt-Rabatt** (Kampf) — der Hehler (KONZEPT 3.3) und bestimmte Häfen heuern billiger
  an, reguläre Häfen verweigern Zugang.
- **Gerüchtekarten** (Entdeckung) — zeigen Windvorhersagen oder Abkürzungen zwischen Inseln
  früher als sonst.

## 7. Mehrspieler (Ausblick)

**Ganz am Ende, als eigener Tier — nicht parallel zu den Einzelspieler-Meilensteinen gebaut.**
Ziel: **kleine Sessions, 2–8 Spieler**, kein dauerhaft-persistenter Server, kein
Matchmaking-Unterbau. Ko-op und PvP laufen in derselben Session, ohne getrennte Modi bauen zu
müssen — reine Frage, wie sich die Spieler zueinander verhalten.

Drei bestehende Entscheidungen zahlen bereits darauf ein, ohne dass heute etwas geändert werden
müsste:

- **Die Welt entsteht aus einem Seed** (KONZEPT 4.1). Nur die Zahl muss über das Netz, nicht die
  Heightmap oder Städteliste — jeder Client generiert dieselbe Welt lokal. Synchronisiert wird
  nur, was vom generierten Zustand *abweicht*, und genau das speichert `SaveManager` bereits als
  „Seed + Abweichungen" (KONZEPT 7.6).
- **„Erst das Ergebnis, dann der Flug"** (RICHTLINIEN B12). Eine Breitseite wird komplett
  berechnet, bevor sie animiert wird — ein Host ruft `resolve_salvo()` auf, verschickt nur das
  Ergebnis, jeder Client spielt nur die Flugbahn ab. Keine Echtzeit-Ballistik-Synchronisation
  nötig.
- **`GameState` (pro Spieler) vs. `WorldData` (geteilt)** (KONZEPT 7.3). Exakt die Trennung, die
  ein Multiplayer-Modell braucht: „mein Zustand" vs. „Server-Wahrheit über die Welt".

Segeln selbst (kontinuierliche Bewegung) ist der einzige Teil mit echtem Sync-Aufwand — bei
Segelschiff-Geschwindigkeiten vermutlich mit einfacher Positions-Replikation und Interpolation
lösbar, ohne Rollback-Netcode.

| Idee | Ko-op oder PvP | Aufwand | Warum günstig |
|---|---|---|---|
| Gemeinsames Meer | beides möglich | mittel | jeder Spieler = eigenes Schiff, wie im Einzelspieler, nur mit echten statt KI-Kapitänen |
| Duell-Modus | PvP | klein | `tests/duel.tscn` existiert bereits als Gefechts-Sandbox |
| Wettlauf um die vier Höfe | kompetitiv, aus der Story | klein–mittel | zwei Spieler verfolgen unterschiedliche Pfade (Abschnitt 5), nutzt das Rufsystem direkt |
| Enterkampf zu zweit | Ko-op oder PvP | größer, Stretch-Goal | rundenbasiertes Gitterfeld (KONZEPT 3.4) ist diskret, leichter zu synchronisieren als Echtzeit |

**Bewusst nicht verfolgt:** mehrere Spieler auf *einem* Schiff (Steuermann/Kanonier-Rollen wie
Sea of Thieves). Bräuchte ein Rollen- und Eingabesystem, das heute nicht existiert — deutlich
teurer als „jeder hat sein eigenes Schiff". Höchstens ein Stretch-Goal weit hinter allem anderen.

**Leitplanke fürs Bauen bis dahin:** keine neuen Regeln nötig, nur Disziplin bei den
bestehenden — RICHTLINIEN B1 (Modi kennen einander nicht), B3 (Kernlogik ohne Nodes), B12
(Ergebnis vor Flug) halten die Tür offen, ohne heute eine Zeile Netzwerkcode zu kosten.

## 8. Verhältnis zu den bestehenden Prinzipien

- Kein Widerspruch zu „Kein Story-Spiel mit festem Ende" (KONZEPT 1): Der Strang schließt sich,
  das Spiel nicht — Akt 3 ist ein Zustandswechsel, kein Abspann.
- Kein neues System für den Kern der Story: Sie ist eine Erzählschicht über Ruf (5.3),
  Gouverneurspalast (3.3) und Erkundung (3.5), die ohnehin für M6/Tier 1 geplant sind.
- Multiplayer bleibt vollständig getrennt von den Einzelspieler-Meilensteinen und wird erst
  angefasst, wenn diese abgeschlossen sind.

---

*Lebendes Dokument. Entsteht aus Gesprächen mit dem Autor, nicht am Reißbrett — wird
überarbeitet, sobald Teile davon tatsächlich gebaut werden.*
