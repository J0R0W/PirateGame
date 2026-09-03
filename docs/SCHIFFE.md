# Ein Schiff bauen

Wie eine neue Schiffsklasse entsteht — von der Recherche bis zur Aufnahme, die zeigt,
dass sie steht.

Verbindlich sind weiterhin `docs/RICHTLINIEN.md`; dieses Dokument ist die Reihenfolge und
die Sammlung der Fallen. Alles, was hier steht, ist beim Bau der **Karavelle** einmal
falsch gemacht worden — sie ist das erste Schiff mit eigenem Rumpf und die Vorlage für
alle weiteren.

**Der Leitgedanke seit dem zweiten Durchgang: Ein Schiff ist eine Tabelle, kein
Programm.** Was ein Anker ist, wie ein Mast verwantet wird, wie eine Laterne brennt —
das weiß die Werkbank `ShipModel`. Ein Modell sagt nur, *wo* und *wie viel*.

---

## 1. Woraus ein Schiff besteht

Drei Dinge, und sie gehören verschiedenen Ebenen an:

| Was | Wo | Rolle |
|---|---|---|
| **Die Klasse** | `resources/ships/<id>.tres` | Zahlen: Fahrverhalten, Zähigkeit, Rohre, Preis. Balancing (Regel B2) |
| **Das Modell** | `entities/ship/models/<id>.gd` (+ eine `.tscn` mit einem Knoten) | Geometrie: Spantenriss, Aufbauten, Mastentabelle, Beschlagsliste. Erbt von `ShipModel` |
| **Der Node** | `entities/ship/ship.tscn` | Physik, Steuerung, Zustand — für *jede* Klasse derselbe |

`Ship.apply_class()` verbindet die drei: Es schreibt die Zahlen aus der `.tres` in den
Node und hängt das Modell unter ihn. **Es gibt keine Schiffsszene je Klasse** — wer eine
baut, hat zwei Wahrheiten über die Fahrwerte.

Dazu kommt die **Werkbank**, die keinem Schiff gehört:

| Klasse | Inhalt |
|---|---|
| `ShipModel` | Basisklasse aller Modelle: Straken, Masten, Wanten, Stagen, Segel, Anker, Spill, Luke, Drehbassen, Laterne, Taue, Materialien |
| `HullMesh` | Rumpf aus Spantquerschnitten, zwei Flächen, UV in Metern |
| `ShipTextures` | Die gerechneten Graustufenmasken für Planken und Tuch |
| `Rig`, `Flag`, `Lantern` | Die drei Knotentypen, die `Ship` an einem Modell erkennt und bewegt |

Eine Klasse **ohne** eigenes Modell ist erlaubt und der übliche Anfang: Sie benutzt den
Platzhalterrumpf aus `ship.tscn` und wird über `hull_scale` größer oder kleiner. Vier der
fünf heutigen Klassen fahren so.

---

## 2. Die Reihenfolge

Sie ist nicht beliebig. **Form vor Licht, Zahlen vor Geometrie** (Regel A11):

1. **Recherche** — was war das für ein Schiff, und woran erkennt man es?
2. **Der Umriss** — unterscheidet er sich von allem, was schon fährt?
3. **Die Klasse** — die `.tres`, und sie fährt schon, bevor es ein Modell gibt
4. **Der Rumpf** — der Spantenriss
5. **Aufbauten, Rigg, Beschläge** — als Tabellen
6. **Prüfen** — Rauchtest und Aufnahmen, auch bei Nacht

Wer bei 4 anfängt, baut ein hübsches Schiff, das sich fährt wie jedes andere.

---

## 3. Recherche

**Nicht optional, und zwar aus einem Gestaltungsgrund.** Der Stil ist sachlich (A11); er
verzeiht falsche Proportionen nicht, sondern stellt sie aus. Ein gedrungener Rumpf, ein
übergroßes Ruder, ein Mast an der falschen Stelle — das sieht bei diesem Licht nicht
stilisiert aus, sondern falsch.

Gebraucht werden fünf Zahlen und eine Frage:

- **Länge über alles, Breite, Tiefgang** und daraus das **Verhältnis Länge zu Breite**.
  Das ist die wichtigste Zahl am ganzen Schiff — eine Karacke liegt bei 2,5 bis 3 zu 1,
  eine Karavelle bei 3,4 zu 1, und darin steckt der halbe Unterschied.
- **Tonnage** und **Besatzung** — daraus werden `cargo_capacity` und `max_crew`.
- **Bewaffnung**: Batteriedeck oder nur Drehbassen auf der Reling?
- Die Frage: **Woran erkennt man das Schiff auf 500 Metern?**

Die Antwort auf die letzte Frage entscheidet über die Takelung. Die Karavelle gab es
historisch in zwei Formen; gebaut ist die *caravela latina* mit drei steilen
Lateinerrahen, weil alle anderen Schiffe im Spiel Rahsegel an waagerechten Rundhölzern
tragen. Die *redonda* wäre genauso richtig gewesen — **und als Silhouette wertlos**
(Regel A1).

**Die Recherche gehört in den Dateikopf des Modells**, nicht in eine Notiz. Im Kopf von
`caravel.gd` steht sie vollständig, und wer die Maße später ändern will, liest dort, warum
sie so sind.

---

## 4. Der Maßstab

**Die Schaluppe ist acht Meter lang, nicht zwanzig.** Das Spiel läuft in einem verkleinerten
Maßstab, ungefähr 1:2,3 gegenüber der Wirklichkeit. Historische Maße werden also nicht
übernommen, sondern die **Verhältnisse**.

Praktisch: Nimm die Länge der Schaluppe (`BASE_HALF_LENGTH = 3.6`, also 7,2 m) als Anker
und rechne von dort. Die Karavelle war historisch etwa doppelt so lang wie eine kleine
Schaluppe und liegt im Spiel bei 9,6 m.

Das gilt auch für Details: Eine Decksplanke ist real 25 bis 30 cm breit, im Spiel also
etwa 12 cm — und genau darauf ist `ShipTextures.PLANKS_PER_METRE` eingestellt.

---

## 5. Die Klasse (`.tres`)

Anlegen unter `resources/ships/<id>.tres`, Feldbedeutungen stehen in `data/ship_class.gd`.
Drei Stellen, an denen man sich vertut:

### `half_length` und `half_beam` statt `hull_scale`

`hull_scale` ist ein **einzelner** Faktor. Er beschreibt „größer" und „kleiner", aber
nicht „länger *und dabei* schlanker" — und genau das ist eine Karavelle gegenüber einer
Schaluppe.

> **Klasse mit eigenem Modell:** `hull_scale = 1.0`, dafür `half_length` und `half_beam`
> in Metern eintragen.
> **Klasse ohne eigenes Modell:** `hull_scale` setzen, die beiden anderen auf `0.0`
> lassen (dann werden sie gerechnet).

Das sind keine Anzeigewerte. `Gunnery.hits_target()` prüft gegen genau dieses Rechteck —
falsche Zahlen heißen, dass Kugeln neben einem Schiff einschlagen, das sie sichtbar
getroffen haben.

### `cannon_slots` ist die Gesamtzahl — und das Modell muss sie zeigen

Nicht die Breitseite. Die Hälfte davon liegt auf jeder Seite, und beide Batterien laden
gleichzeitig — sie brauchen also auch beide ihre Bedienung. Vier Rohre heißen zwei je
Seite.

**Der Rauchtest zählt nach.** `ShipModel.gun_count()` zählt, was das Modell an Rohren
aufstellt, und die Zahl muss `cannon_slots` treffen. Ein Schiff soll so bewaffnet
aussehen, wie es schießt — sonst steht in der `.tres` eine Fregatte und auf dem Wasser
ein Kutter.

### `warship` steuert die KI, nicht die Bewaffnung

Ein Handelsschiff **jagt nie**, auch wenn seine Krone den Spieler sucht; es flieht und
wehrt sich. Ein Kriegsschiff sucht das Gefecht. Das ist die Grundhaltung in `ShipAI` und
hat mit `cannon_slots` nichts zu tun.

### Die Beschreibung

`description` steht im Hafen unter dem Schiff. Sie sagt, **wofür man es nimmt**, nicht wie
es aussieht — das sieht man ja.

**Jetzt schon prüfen, vor jeder Geometrie:** `tests/duel.tscn` fährt die Klasse gegen eine
andere und misst; `tests/rig.tscn` lässt sie fahren. Beide nehmen die Klasse ohne Modell.

---

## 6. Der Rumpf: ein Spantenriss, keine Kisten

Ein Rumpf wird **nicht** aus Quadern zusammengestellt, sondern aus Querschnitten geloftet.
`HullMesh.build()` erledigt das; die Eingabe ist eine Zahlentabelle, die das Modell in
`stations()` zurückgibt:

```gdscript
const STATIONS: Array[Dictionary] = [
    {"z": -4.80, "beam": 0.07, "deck": 1.06, "keel": -0.08, "floor": 0.04},
    ...
    {"z":  4.80, "beam": 0.87, "deck": 0.94, "keel": -0.20, "floor": 0.27},
]

func stations() -> Array:
    return STATIONS
```

| Spalte | Bedeutung |
|---|---|
| `z` | Längsposition. **Bug negativ**, Spiegel positiv. Aufsteigend sortiert |
| `beam` | **halbe** Breite an der Oberkante |
| `deck` | Höhe der Decklinie — das ist der **Sprung** |
| `keel` | Höhe des Bodens. Negativ heißt unter Wasser |
| `floor` | halbe Breite des Bodens, also wo die **Kimm** sitzt |

Alle `x`-Werte sind halbe Breiten; der Rumpf wird gespiegelt. Neun Spanten reichen — mehr
macht die Form nicht besser, nur die Tabelle unlesbar.

**Der Sprung ist kein Detail.** Die Spalte `deck` muss zur Mitte hin durchhängen (vorne
1,06 → mittschiffs 0,63 → achtern 0,94). Ohne dieses Durchhängen sieht ein Rumpf aus wie
ein Brett, und zwar bei jedem Licht.

**Die Wasserlinie liegt bei `y = 0`.** Die `keel`-Werte gehören also überwiegend ins Negative,
sonst schwebt das Schiff.

Was `HullMesh` daraus baut, steht in `WIDEST`, `TUMBLEHOME`, `BILGE_RISE` und
`RAIL_THICKNESS` — das sind Konstanten *aller* Rümpfe, nicht dieser Klasse. Wer sie
ändert, ändert jedes Schiff.

Die Werkbank liest die Tabelle für alles Weitere: `_deck_at(z)` und
`_rail_half_beam_at(z)` straken zwischen zwei Spanten, `_rail_point(z, side)` liefert
den Punkt auf der Reling, an dem Wanten, Drehbassen und Laternen ansetzen. **Ein Modell
rechnet keine Deckshöhe selbst aus.**

### Zwei Flächen, kein Override

`HullMesh.build()` liefert ein Mesh mit **zwei Surfaces** und deren Materialien:

- **Surface 0 — Außenhaut.** Planken laufen längs um den Spant herum.
- **Surface 1 — Deck.** Planken laufen von vorn nach achtern.

> **Niemals `material_override` auf ein Mesh aus `HullMesh` setzen.** Es übermalt beide
> Flächen mit demselben Material, und eine der beiden Plankenrichtungen liegt danach quer.

### Die Farbbänder

Sie stehen in `HullMesh.strips()` und gelten für alle Rümpfe: dunkler Boden (`HULL`),
darüber ein schwarzes Bergholz (`TAR`), darüber das hellere Freibord (`TOPSIDE`), oben der
helle Handlauf (`TIMBER`), innen das Deck (`DECK`).

**Drei Bänder, nicht zwei.** Vorher war alles über der größten Breite `TAR`, und ein
Schiff war von der Seite ein schwarzer Klumpen, an dem man das Achterdeck nicht vom Rumpf
unterscheiden konnte.

---

## 7. Aufbauten

Ein Aufbau (Halbdeck, Kastell) ist **kein zweiter Rumpf**. Er folgt der Breite des Rumpfes
an derselben Stelle und ist ein Deckel darauf. Gebaut wird er von Hand mit
`HullMesh.quad()`, zusammengefügt mit `HullMesh.finish(walls, planks)` — dasselbe Muster
wie oben: Wände in die eine Fläche, Gehflächen in die andere. Das ist der eine Teil eines
Modells, der wirklich Code ist und bleibt.

Der Querschnitt eines Aufbaus ist derselbe wie der eines Schanzkleids, und aus demselben
Grund: **Außenwand hoch, Handlauf quer, Innenwand herunter, dann die Gehfläche.** Eine
bloße Platte mit einer Kante sieht aus wie ein Deckel, nicht wie ein Deck.

### Die Falle: Zwischenmaße werden gestrakt, nicht gerundet

Die Vorderkante eines Halbdecks liegt selten genau auf einem Spant. Wer dafür den
*nächstgelegenen* Spant nimmt, bekommt sie sechs Zentimeter zu breit — und sie steht
seitlich aus dem Rumpf heraus. Dafür gibt es `_column_at(z, key)` in der Werkbank.

### Ein Aufbau überschreibt zwei Fragen

Die Werkbank weiß nichts von Halbdecks. Ein Modell mit Aufbau überschreibt deshalb genau
die beiden Methoden, deren Antwort sich achtern ändert:

| Methode | Warum |
|---|---|
| `_rail_point(z, side)` | Achtern gilt die Reling des Achterdecks. Ohne das laufen die Wanten des Besans quer durch das Halbdeck hindurch |
| `_mast_foot(index)` | Ein Mast auf dem Achterdeck steht um `TOLDA_HEIGHT` höher |

Beide rufen `super()` für den Normalfall und ändern nur den Fall achtern — siehe
`caravel.gd`. Alles, was Wanten, Stagen, Drehbassen und Laternen betrifft, folgt dann von
selbst.

---

## 8. Das Rigg

Ein Mast ist eine Tabellenzeile. Die Werkbank baut daraus Rundholz, Topp, Rah, Segel,
Wanten — und die Flagge, wenn die Zeile es sagt:

```gdscript
const LATEEN: Dictionary = {
    "sail": "lateen", "pitch": 42.0, "length": 1.24, "hoist": 0.52,
    "belly": 0.34, "swing": 52.0,
}
const MASTS: Array[Dictionary] = [
    {"z": -2.85, "height": 5.90},
    {"z":  0.10, "height": 7.35, "flag": true},
    {"z":  3.25, "height": 4.90},
]

func masts() -> Array:
    var rigged: Array = []
    for spec: Dictionary in MASTS:
        rigged.append(LATEEN.merged(spec))
    return rigged
```

| Schlüssel | Bedeutung |
|---|---|
| `z`, `height` | Fuß und Höhe über dem Fuß. Der Fuß liegt auf dem Deck (oder dem Aufbau, siehe 7) |
| `sail` | Takelung. Heute nur `"lateen"`; das Rahsegel steht in Abschnitt 14 |
| `pitch`, `length`, `hoist`, `belly` | Rah gegen die Waagerechte in Grad, Rahlänge als Vielfaches der Masthöhe, Anschlaghöhe als Anteil, Segelbauch in Metern |
| `swing` | Wie weit die Rah höchstens ausschwenkt (`Rig.max_swing_deg`) |
| `flag` | Hier weht die Flagge. Der höchste Mast |

Der Fall aller Masten kommt aus `mast_rake_deg()`, die Stagen aus einem Aufruf:
`_add_stays(STEM_HEAD, backstay_foot)` — jeder Mast hält sich am Fuß des nächsten vor
ihm fest, der vorderste am Vorsteven, der hinterste zusätzlich mit einem Backstag.

### Drei Knotentypen, die `Ship` bewegt

`Ship` erkennt sie **nicht am Namen**, sondern am Typ bzw. an der Gruppe. Ein Modell darf
seine Masten nennen, wie es will:

| Knoten | Wie erkannt | Was passiert damit |
|---|---|---|
| `Rig` (Klasse) | Typ | Schwenkt zum Wind (`Rig.aim()`) |
| `Flag` (Klasse) | Typ | Steht in Weltrichtung, flattert, trägt die Nationsfarbe |
| `Lantern` (Klasse) | Typ | Brennt bei schlechter Sicht (Abschnitt 9) |
| Segel | Gruppe `&"sail"` | Wird beim Reffen über `scale.y` an die Rah gezogen |

### Der Mast dreht nicht mit

> **`Rig` ist ein Geschwister des Mastes, kein Kind.**

Hinge die Rah unter dem Mast, kippte beim Schwenken der Fall des Mastes zur Seite, und die
Wanten liefen ins Leere. Also: `Mast%d` trägt nur das Rundholz, `Rig%d` daneben trägt Rah
und Segel, beide am selben Fußpunkt. Die Werkbank macht das von selbst; der Rauchtest hält
es fest: Kein `Rig` darf `Mast*` heißen.

### Der Masttopp liegt nicht über dem Mastfuß

Ein Mast fällt nach achtern. Der Topp ist deshalb

```gdscript
var up := Vector3(0.0, cos(rake), sin(rake))
var head := foot + up * height
```

und **nicht** `Vector3(0, foot.y + height * cos(rake), foot.z)`. Genau das stand zuerst da:
Die Wanten endeten in der richtigen Höhe und einen halben Meter zu weit vorn. Der
Rauchtest misst den Abstand jetzt und lässt höchstens acht Zentimeter durchgehen.

### Das Achsenkreuz des Segelknotens

`Ship` refft, indem es `scale.y` des Segelknotens verkleinert. Bei einer schrägen Rah muss
die lokale y-Achse deshalb **zum Schothorn** zeigen und die lokale z-Achse **auf der Rah
liegen** — sonst zieht sich das Tuch senkrecht nach unten zusammen und sieht aus wie ein
Riss. `_add_lateen()` baut die Basis so; wer eine andere Takelung schreibt, muss es
genauso halten.

### Rundhölzer schräg stellen

Zylindermeshes stehen in Godot auf ihrer lokalen y-Achse. Nicht in Euler-Winkeln herumdrehen,
sondern die Basis direkt bauen — `_basis_from_up(richtung)`. Das spart die Frage, in welcher
Reihenfolge Euler-Winkel angewandt werden.

### `rest_chord_deg`: Rahsegler oder Lateiner

Die Ruhelage der Rah relativ zum Schiff. `90.0` heißt quer (Rahsegler), `0.0` heißt
längsschiffs (Lateiner). Aus derselben Formel (`SailingMath.sail_trim`) folgt dann von
selbst, dass ein Lateiner am Wind dichter holt und ein Rahsegler schärfer brasst.

### Stehendes Gut

Wanten und Stagen kosten fast nichts und tragen den Umriss erheblich: Ohne sie steht ein
Mast wie ein Besenstiel im Deck. Zwei Wanten je Seite (`SHROUD_OFFSETS`) reichen.

---

## 9. Beschläge — und die Laterne

Alles, was auf dem Deck steht, ist ein Aufruf mit einer Position. Der Katalog in
`ShipModel`:

| Aufruf | Was entsteht | Bemerkung |
|---|---|---|
| `_add_hatch(z, width, length)` | Ladeluke mit Süllrand und Grating | Ohne sie ist das Deck in der Aufsicht eine leere Fläche |
| `_add_windlass(z)` | Ankerspill | Gehört zum Anker wie der Anker zum Bug |
| `_add_anchor(z, side)` | Stockanker außenbords | Sagt aus jeder Entfernung: das ist ein Schiff |
| `_add_swivels([z, ...])` | Drehbassen, je eine pro Seite und Position | **Zählt als Bewaffnung** (`gun_count()`) |
| `_add_lantern(name, at, rise)` | Laterne am Eisenbügel | `at` ist der Fuß auf dem Handlauf, `rise` die Höhe darüber |

Ein neuer Beschlag kommt **in die Werkbank**, nicht ins Modell — selbst wenn ihn zunächst
nur ein Schiff trägt. Der Grund ist derselbe wie beim Anker: Das zweite Schiff hätte ihn
sonst kopiert.

### Die Laterne brennt bei schlechter Sicht

Die Laterne ist der erste Beschlag, der etwas *tut*. Ob sie brennt, entscheidet nicht das
Modell, sondern `Ship._update_lanterns()` — aus einer Zahl, die es vorher nicht gab:

**`WorldData.visibility()`**, 0 bis 1, gerechnet in `Skylight` aus Uhrzeit und Wetter.
Ein klarer Mittag ist 1, ein Sturm am Mittag 0,25, eine klare Nacht 0. Angezündet wird
unter 0,45, gelöscht erst wieder über 0,6 — zwei Schwellen, sonst flackern die Lichter in
der Dämmerung minutenlang um den Grenzwert.

Damit das überhaupt etwas heißt, wandert seit demselben Schritt die **Sonne**
(`SailingMode._update_skylight`, je Bild aus `Skylight`): auf im Osten um sechs, Zenit um
zwölf, unter im Westen um achtzehn; nachts steht ihr ein Mond gegenüber, und der Dunst
wird dunkel statt dicht. Ein Spieltag dauert vier Minuten, die Nacht ist also kurz — und
**mondhell, nicht schwarz**, sonst wäre sie nicht spielbar.

Für ein Modell heißt das nur: **eine Laterne dort, wo sie historisch hing** — die
Hecklaterne auf dem Spiegel (der *farol*, nach dem ein Geleit nachts dem Vorausfahrenden
folgte). Größere Schiffe tragen drei. Was fehlt, steht in Abschnitt 14: Ein Licht, das man
selbst löschen kann, lohnt sich erst, wenn der Ausguck die Sicht liest.

Im Debug-Menü (F3) stehen unter **Himmel** Uhrzeit, „Uhr anhalten" und Wetter — sonst
wartete man zwei Minuten auf jede Nacht, und in den Regen käme man gar nicht, weil noch
keine Wetteruhr läuft.

---

## 10. Farbe und Textur

Es gilt A3 und A11 unverändert:

- **Kein `Color(...)` außerhalb von `palette.gd`.** Farben kommen als Vertexfarben ins
  Mesh, und zwar durch `Palette.for_vertex()` — Godot liest Mesh-Farben als linear, ohne
  die Umrechnung sehen alle Modelle ausgewaschen aus.
- **Texturen sind gerechnete Graustufenmasken** (`ShipTextures`), die nur an der Fuge
  Helligkeit wegnehmen. Keine Bilddateien, keine Normal Maps, keine Farbtexturen.
- **UV-Koordinaten sind Meter.** Eine Kachel ist ein Meter. Ohne diese Regel ist die
  Planke am Bug schmaler als mittschiffs, weil der Spant dort kleiner ist.

Die V-Achse liegt **quer zur Planke**: an der Außenhaut die Bogenlänge um den Spant, auf
dem Deck die Querlage `x`, an einer senkrechten Wand die Höhe `y`.

**Tuch** (Segel, Flagge) bekommt `ShipTextures.canvas()`, dazu `cull_mode = CULL_DISABLED`,
`backlight_enabled` (die Sonne scheint hindurch) und **`disable_receive_shadows = true`**.
Das letzte ist kein Geschmack: Eine Fläche ohne Dicke beschattet sich in der Schattenkarte
selbst, und über jedem Segel lag ein feines Karomuster. `_canvas_material()` in der
Werkbank hat das alles.

**Licht ist ein Palettenton wie jeder andere.** `Palette.LANTERN` ist der einzige Ton im
Spiel, der nachts leuchtet, `SUN_HIGH`/`SUN_LOW`/`MOONLIGHT` sind das gerichtete Licht,
`HAZE`/`NIGHT_HAZE` der Dunst. Der Segelmodus setzt sie zur Laufzeit; die Werte in
`sailing_mode.tscn` sind nur die Vorschau im Editor.

---

## 11. Einhängen

Das Skript erbt von `ShipModel` und füllt `_assemble()`:

```gdscript
class_name BrigModel
extends ShipModel

func stations() -> Array: return STATIONS
func masts() -> Array: return ...
func mast_rake_deg() -> float: return MAST_RAKE
func bulwark() -> float: return BULWARK
func hull_parts() -> PackedStringArray: return ["Plating"]
func interior_probes() -> Array[Dictionary]: return [...]

func _assemble() -> void:
    _add_mesh("Plating", HullMesh.build(STATIONS, BULWARK))
    _add_hatch(...)
    for i in masts().size():
        _add_mast(i, masts()[i])
    _add_stays(STEM_HEAD, taffrail)
    _add_lantern("SternLantern", taffrail, 0.30)
```

Die Modellszene ist eine `.tscn` mit **einem einzigen Knoten**, der das Skript trägt:

```
[node name="Hull" type="Node3D"]
script = ExtResource("1_brig")
```

Wie der Wurzelknoten heißt, ist gleichgültig — `Ship._install_model()` tauft ihn ohnehin
in `Hull` um. In der `.tres` der Klasse zeigt `model` auf diese Szene.

Zwei Dinge, die die Werkbank schon erledigt, damit man sie nicht vergisst: **`build()` ist
öffentlich** (`apply_class()` ruft es ausdrücklich, weil `_ready()` je nach Baumzustand
zu spät kommt) und **gegen Doppelaufruf gesichert** (sonst steht das Rigg zweimal da).
Ein Modell überschreibt `_assemble()`, nie `build()`.

Nach einer neuen Datei mit `class_name`:

```bash
godot --headless --import
```

Ohne das scheitert der Rauchtest mit „Could not find type X in the current scope" — das
ist kein Codefehler.

---

## 12. Prüfen

### Rauchtest

Die Prüfungen für die Karavelle stehen in `_check_caravel_model()` und sind die Vorlage.
Vier davon laufen über die Antworten des Modells und gehören deshalb an **jedes** neue
Schiff, ohne dass man den Test umschreibt:

- **`_check_hull_is_closed(ship, model)`** — von jedem Punkt aus `interior_probes()` geht
  je ein Strahl in alle sechs Achsenrichtungen durch die Flächen aus `hull_parts()`, und
  überall muss etwas im Weg sein (Regel C7). So kam heraus, dass die Kajüte unter dem
  Achterdeck keine Heckwand hatte und der Bug keinen Steven. **Ein Modell nennt seine
  Innenräume selbst** — der Test weiß nichts von Karavellen.
- **`gun_count()` gegen `cannon_slots`** — was das Modell aufstellt, muss die Klasse
  schießen.
- Die **gezeichnete Länge und Breite** muss `half_length` und `half_beam` aus der `.tres`
  treffen. Sonst schießt die Ballistik auf ein Rechteck, das nicht auf dem Bildschirm steht.
- **Wanten enden am Topp**, auf acht Zentimeter.

Dazu, für jedes Schiff einmal: Zahl der Segel, der Rahen, der Flaggen und der Laternen.

```bash
godot --headless --path . res://tests/smoke_test.tscn
```

### Aufnahmen

**Was man nicht rendert, hat man nicht geprüft** (Regel C2). Shader werden headless nie
kompiliert, ein Licht ist headless gar nichts, und Geometriefehler fallen aus der
Verfolgerkamera nicht auf.

```bash
godot --path . res://tests/capture_ship.tscn    # vier Winkel bei Tag, einer bei Nacht
godot --path . res://tests/rig.tscn             # Rigg gegen den Wind drehen
```

Ein neues Schiff wird in `tests/capture_ship.gd` unter `SUBJECTS` eingetragen — dann steht
es auch auf der **Silhouettenaufnahme** neben den anderen. Die ist der eigentliche Test zu
Regel A1: Aus der Nahaufnahme sieht jedes Modell nach etwas aus.

Die **Nachtaufnahme** (`*_05_nacht.png`) zeigt, ob die Laterne brennt, ob sie das Deck
und ein Segel streift und ob sie dort hängt, wo sie hingehört. Die Bühne nimmt dafür die
Zahlen aus `Skylight`, nicht eigene — sie zeigt dieselbe Nacht wie der Segelmodus.

`tests/rig.tscn` nimmt die Klasse in `CLASSES` auf und beantwortet genau eine Frage: Stehen
Rah, Segel und Flagge richtig zum Wind? Pfeiltasten drehen den Wind, `G` wechselt die
Klasse.

---

## 13. Die Fallen auf einen Blick

Alle einmal passiert, alle in einem Test festgehalten:

| Falle | Symptom |
|---|---|
| `material_override` auf ein `HullMesh` | Decksplanken liegen quer |
| Nächstgelegener Spant statt gestrakt | Aufbau steht seitlich aus dem Rumpf |
| `Rig` als Kind des Mastes | Mast kippt beim Schwenken, Wanten lösen sich |
| Masttopp ohne Fall gerechnet | Wanten enden einen halben Meter vor dem Topp |
| Rumpfende nicht geschlossen | Man sieht von achtern oder von vorn ins Schiff |
| Reling achtern = Reling des Rumpfes | Wanten laufen durch das Halbdeck |
| Segelmaterial fängt Schatten | Karomuster über jedem Segel |
| `Color(...)` im Modell | Linter schlägt an (A3) |
| UV ohne Maßstab | Planken am Bug schmaler als mittschiffs |
| `hull_scale` statt `half_length`/`half_beam` | Treffer liegen neben dem sichtbaren Rumpf |
| `queue_free()` beim Modelltausch | Zwei Knoten heißen `Hull`, Godot tauft um, der alte bleibt |
| Rohre im Modell ≠ `cannon_slots` | Sieht aus wie ein Kutter, schießt wie eine Fregatte |
| Innenpunkte im Test statt im Modell | Das zweite Schiff wird nie auf Dichtheit geprüft |
| Ein Test auf „Licht von oben" mit `< 0` | Fällt um Punkt sechs Uhr durch: Am Horizont ist das Licht waagerecht |
| Uhr, die bei null anfängt | Sobald die Sonne wandert, beginnt jede Kampagne um Mitternacht |

---

## 14. Vorschläge — was als Nächstes an der Werkbank fehlt

In der Reihenfolge, in der es sich lohnt. Nichts davon ist gebaut; alles hat einen
konkreten Anlass.

1. **Das Rahsegel** (`_add_square` in `ShipModel`, Takelung `"square"` in der Tabelle).
   Der Anlass ist zwingend: Brigg und Fregatte sind Rahsegler, und ohne diesen Bauer
   bleibt jede weitere Klasse beim Platzhalterrumpf. Eine Zeile je Mast, dazu die Zahl
   der Rahen übereinander (Unter-, Mars-, Bramsegel), `rest_chord_deg = 90`, die lokale
   y-Achse des Segels zeigt nach unten zum Fußliek — dann refft `Ship` es wie den
   Lateiner.
2. **Das Batteriedeck** (`_add_battery(z_first, z_last, count_per_side)`): Stückpforten
   als dunkle Rechtecke in der Außenhaut, je ein kurzes Rohr dahinter, zählt in
   `gun_count()`. Ohne das kann keine Klasse mit mehr als vier Rohren den Rauchtest
   bestehen — und genau die Klassen sind die nächsten.
3. **Die Schaluppe als `ShipModel`** (`sloop.gd`, Spantenriss statt drei Quader). Dann
   läuft *jedes* Schiff durch dieselbe Werkbank, `ship.tscn` trägt keinen Rumpf mehr,
   und `hull_scale` kann gehen. Die Silhouettenaufnahme zeigt danach zum ersten Mal zwei
   Rümpfe, die sich vergleichen lassen.
4. **Ein Schiff, das irgendwo fährt.** `NavalCombat._spawn()` setzt fest
   Patrouillenschaluppe und Handelsbrigg; die Werft verkauft nichts. Eine Tabelle
   *Krone × Rolle → Klassen* an einer Stelle (etwa in `NationData`) wäre der kleinste
   Schritt, der eine neue Klasse auf See bringt.
5. **Die Silhouette messen statt ansehen.** `capture_ship` kann die Silhouetten aller
   Schiffe als Masken rendern und paarweise den Überlapp rechnen. Zwei Klassen, die sich
   auf 500 m zu mehr als, sagen wir, neunzig Prozent decken, fallen durch — Regel A1 als
   Zahl. Heute ist das eine Aufnahme, die jemand anschauen muss.
6. **Lichter löschen können.** Sobald der Ausguck die Sicht liest (Sichtungsweite aus
   `WorldData.visibility()`), wird eine brennende Laterne zu etwas, das einen verrät —
   und dann lohnt ein Befehl „Lichter löschen", mit dem Preis, dass die eigene Mannschaft
   im Dunkeln langsamer lädt. Vorher wäre es ein Knopf ohne Entscheidung (siehe Regel
   „Eine Achse, die nur kostet, ist so wenig eine Entscheidung wie eine, die nur hilft").
7. **Schaden am Modell zeigen.** `Ship.sails` fällt im Gefecht, das Tuch bleibt heil.
   Ein zerschossenes Segel als kleinerer `scale.y` und dunklere Vertexfarbe ab einer
   Schwelle wäre die billigste Fassung — und die erste, bei der man einem Gegner den
   Zustand ansieht, statt ihn im HUD zu lesen (Regel A8).

Was **nicht** vorgeschlagen wird, und warum: Beiboot, Galionsfigur, Heckgalerie. Sie
kosten Modellarbeit und tragen zur Silhouette nichts bei; A11 sagt, der Umriss macht den
Ernst, nicht das Detail.

---

## 15. Was noch fehlt

Ehrlich vermerkt, damit niemand danach sucht:

- **Eine neue Klasse fährt nirgends von selbst** (siehe Vorschlag 4).
- **Eine Prise lässt sich nicht behalten.** Das erbeutete Schiff wird ausgeräumt und treibt
  davon (`NavalCombat._release`). Das Prisenschiff zu übernehmen gehört zu M5.
- **Der Spieler fährt schwarz.** Nichts setzt seine `nation_id`; der naheliegende Anlass
  wäre die Patronskrone des Kaperbriefs.
- **Es gibt keine Wetteruhr.** `WorldData.weather` liest jetzt alles, was auf Sicht
  reagiert, aber setzen tut es nur das Debug-Menü. Das ist KONZEPT 5.6 und bewusst nicht
  hier angefangen.
- **Der Himmel selbst färbt sich nicht.** Die Himmelsfarben stehen in
  `sailing_mode.tscn`; nachts wird der Himmel nur gedimmt, abends nicht rot. Das Licht
  auf Land und Wasser wird warm, der Himmel dahinter bleibt blau — auf den Aufnahmen
  sichtbar, und die nächste Stelle, an der A11 „Atmosphäre" einfordert.

---

*Entstanden beim Bau der Karavelle, umgeschrieben beim Umzug in die Werkbank. Wer beim
nächsten Schiff eine neue Falle findet, trägt sie in Abschnitt 13 ein — und den Test
dazu in den Rauchtest.*
