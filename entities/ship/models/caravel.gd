## Das Modell einer Karavelle - das erste Schiff mit eigenem Rumpf.
##
## [b]Was eine Karavelle war[/b] (Recherche, weil der Umriss danach gebaut ist):
##
## Portugiesisch-spanisch, 15. und 16. Jahrhundert, aus portugiesischen
## Fischerbooten entwickelt und ab den 1440er Jahren fuer die Entdeckungsfahrten
## verfeinert. Gebaut wurde sie nicht fuer Fracht und nicht fuer das Gefecht,
## sondern fuers Suchen: flach gehend, damit sie in Flussmuendungen einlaufen
## kann, und vor allem [i]hoch am Wind[/i] - sie kam zurueck, wo ein Rahsegler
## haette kreuzen muessen.
##
## - [b]Groesse[/b] rund 50 bis 60 Tonnen: etwa 20 bis 25 m ueber alles, 6 bis
##   7 m breit, 2 bis 2,5 m Tiefgang. Verhaeltnis Laenge zu Breite etwa 3,4 zu 1
##   und damit deutlich schlanker als eine Karacke (2,5 bis 3 zu 1). Zwanzig bis
##   dreissig Mann.
## - [b]Kravelbauweise[/b], daher der Name: Planken stossen Kante an Kante auf
##   einem vorher aufgerichteten Spantgeruest, statt sich wie beim Klinkerbau
##   der Nordsee zu ueberlappen. Die Aussenhaut ist deshalb glatt.
## - [b]Umriss[/b]: niedriges Freibord, [i]kein Vorkastell[/i], achtern ein
##   einzelnes erhoehtes Halbdeck (die tolda) ueber der Kajuete. Flach, lang,
##   tief - das Gegenteil der Karacke mit ihren zwei Kastellen.
## - [b]Heck[/b] bei den spaeteren Schiffen ein flacher Spiegel, Ruder aussen am
##   Achtersteven, die Pinne kommt unter dem Halbdeck herein.
## - [b]Takelung[/b] in zwei Formen. Die [i]caravela latina[/i] fuehrt zwei oder
##   drei Lateinersegel: dreieckige Tuecher an sehr langen, steil gestellten
##   Rahen, die weit ueber den Bug hinausreichen und achtern hoch ueber den
##   Masttopp stehen. Die [i]caravela redonda[/i] setzt vorne ein Rahsegel und
##   segelt damit den Passat besser ab - die Nina wurde 1492 auf den Kanaren
##   genau so umgetakelt.
## - [b]Bewaffnung[/b] leicht: eine Handvoll Drehbassen auf der Reling, kein
##   Batteriedeck. Eine Karavelle laeuft davon, sie schlaegt sich nicht.
##
## [b]Gebaut ist die caravela latina[/b], und zwar wegen Regel A1: Alle anderen
## Schiffe im Spiel tragen Rahsegel an waagerechten Rundhoelzern. Drei steil
## stehende Lateinerrahen sind der einzige Umriss, den man auf 500 m nicht mit
## etwas anderem verwechseln kann. Die redonda waere historisch genauso richtig
## und als Silhouette wertlos.
##
## Die Masse unten sind die historischen Verhaeltnisse im Massstab des Spiels -
## die Schaluppe ist hier acht Meter lang, nicht zwanzig.
##
## Was hier steht, ist nur das, was an der Karavelle [i]anders[/i] ist: der
## Spantenriss, das Halbdeck, der Steven, und die Tabellen, wo was sitzt.
## Anker, Spill, Luke, Drehbassen, Masten und Taue baut [ShipModel].
class_name CaravelModel
extends ShipModel

## Spantenriss. Bug bei -Z, Spiegel bei +Z; alle x-Werte sind halbe Breiten.
##
## Der Sprung steckt in der Spalte "deck": vorne 1,06, mittschiffs 0,63, achtern
## 0,94. Ohne dieses Durchhaengen sieht ein Rumpf aus wie ein Brett.
const STATIONS: Array[Dictionary] = [
	{"z": -4.80, "beam": 0.07, "deck": 1.06, "keel": -0.08, "floor": 0.04},
	{"z": -4.05, "beam": 0.44, "deck": 0.96, "keel": -0.44, "floor": 0.12},
	{"z": -3.05, "beam": 0.88, "deck": 0.83, "keel": -0.67, "floor": 0.26},
	{"z": -1.75, "beam": 1.23, "deck": 0.71, "keel": -0.77, "floor": 0.45},
	{"z": -0.35, "beam": 1.42, "deck": 0.64, "keel": -0.79, "floor": 0.56},
	{"z": 0.95, "beam": 1.40, "deck": 0.63, "keel": -0.76, "floor": 0.55},
	{"z": 2.25, "beam": 1.26, "deck": 0.69, "keel": -0.68, "floor": 0.45},
	{"z": 3.45, "beam": 1.07, "deck": 0.81, "keel": -0.51, "floor": 0.33},
	{"z": 4.80, "beam": 0.87, "deck": 0.94, "keel": -0.20, "floor": 0.27},
]

## Hoehe des Schanzkleids ueber Deck. Niedrig - das ist der halbe Charakter des
## Schiffs, man steht an Deck fast auf Wasserhoehe.
const BULWARK: float = 0.30

## Wo das erhoehte Achterdeck beginnt und wie hoch es liegt.
const TOLDA_START: float = 1.55
const TOLDA_HEIGHT: float = 0.72
## Hoehe der Reling um das Achterdeck.
##
## Ohne sie war das Halbdeck ein Deckel mit einer Kante, von der man faellt -
## und aus der Ferne ein dunkler Kasten ohne Oberkante. Die Reling gibt ihm
## dieselbe Gliederung wie dem Hauptdeck: Wand, Handlauf, vertiefte Gehflaeche.
const TOLDA_RAIL: float = 0.24

## Der Vorsteven: das Holz, in dem die Planken vorne zusammenlaufen.
##
## Er ragt ueber die Decklinie hinaus. Das ist kein Schmuck - der Bug einer
## Karavelle ist sonst eine abgeschnittene Spitze, und im Gegenlicht sieht man
## an einer Silhouette vorne und hinten dasselbe (Regel A1).
const STEM_FOOT := Vector3(0.0, -0.42, -4.15)
const STEM_HEAD := Vector3(0.0, 1.58, -4.86)

## Die Ladeluke: Laengsmitte und Masse des Suellrands.
const HATCH_Z: float = -0.60
const HATCH_WIDTH: float = 0.86
const HATCH_LENGTH: float = 1.10

## Wo die Drehbassen auf der Reling stehen. Zwei je Seite - das sind die vier
## Rohre aus [code]caravel.tres[/code], und mehr trug ein solches Schiff nicht.
const SWIVEL_Z: Array[float] = [-1.60, 0.60]

## Wo der Anker aussenbords haengt und wo das Spill an Deck steht.
##
## Historisch trug eine Karavelle zwei bis drei Anker. Einer reicht: Er gibt
## dem Vorschiff etwas, das dem Achterschiff das Halbdeck gibt.
const ANCHOR_Z: float = -3.55
const WINDLASS_Z: float = -3.30

## Das Lateinersegel, fuer alle drei Masten gleich.
##
## [code]pitch[/code] Steil, 42 Grad. Genau das macht den Umriss aus - bei 25
## Grad saehe es aus wie ein schlecht gesetztes Gaffelsegel.
## [code]length[/code] Ueber eins: Die Antenne eines Lateiners ist laenger als
## der Mast, der sie traegt.
## [code]hoist[/code] Tief angeschlagen: Der Hals einer Lateinerrah wird bis
## dicht ueber Deck niedergeholt. Stand sie hoeher, schwebte das Tuch mit
## sichtbarer Luft ueber der Reling und das Schiff wirkte kopflastig.
## [code]swing[/code] Enger als bei einem Rahsegler: Die Antenne ist neuneinhalb
## Meter lang und das Schiff keine drei breit. Quer gestellt stuende sie zu
## beiden Seiten weiter ueber der See als der Rumpf.
const LATEEN: Dictionary = {
	"sail": "lateen", "pitch": 42.0, "length": 1.24, "hoist": 0.52,
	"belly": 0.34, "swing": 52.0,
}

## Masten: Laengsposition und Hoehe ueber ihrem Fuss.
##
## Der Grossmast steht knapp vor der Mitte, ist der laengste und traegt die
## Flagge; der Besan steht auf dem Achterdeck. Alle fallen leicht nach achtern.
const MASTS: Array[Dictionary] = [
	{"z": -2.85, "height": 5.90},
	{"z": 0.10, "height": 7.35, "flag": true},
	{"z": 3.25, "height": 4.90},
]
## Fall der Masten nach achtern, in Grad.
const MAST_RAKE: float = 4.0

## Die Hecklaterne: wie weit sie hinter der Reling des Achterdecks haengt und
## wie hoch darueber. Historisch der [i]farol[/i] am Spiegel - das Licht, an
## dem ein Geleit nachts dem Vorausfahrenden folgte.
const LANTERN_OVERHANG: float = 0.06
const LANTERN_RISE: float = 0.30


func stations() -> Array:
	return STATIONS


func masts() -> Array:
	var rigged: Array = []
	for spec: Dictionary in MASTS:
		rigged.append(LATEEN.merged(spec))
	return rigged


func mast_rake_deg() -> float:
	return MAST_RAKE


func bulwark() -> float:
	return BULWARK


func hull_parts() -> PackedStringArray:
	return PackedStringArray(["Plating", "Tolda"])


## Die drei Raeume, die der Rumpf umschliesst. Von jedem aus muss in alle
## sechs Richtungen etwas im Weg sein - so kam die fehlende Heckwand der
## Kajuete heraus und der fehlende Steven am Bug.
func interior_probes() -> Array[Dictionary]:
	return [
		{"at": Vector3(0.0, 1.30, 4.10), "was": "Kajuete unter dem Achterdeck"},
		{"at": Vector3(0.0, 0.20, 0.00), "was": "Laderaum mittschiffs"},
		{"at": Vector3(0.0, 0.30, -4.10), "was": "Vorpiek"},
	]


func _assemble() -> void:
	_add_mesh("Plating", HullMesh.build(STATIONS, BULWARK))
	_add_mesh("Tolda", _tolda_mesh())
	_add_stem()
	_add_rudder()

	_add_hatch(HATCH_Z, HATCH_WIDTH, HATCH_LENGTH)
	_add_windlass(WINDLASS_Z)
	_add_anchor(ANCHOR_Z, 1)
	_add_swivels(SWIVEL_Z)

	var rigged := masts()
	for i in rigged.size():
		_add_mast(i, rigged[i])
	var taffrail := _taffrail()
	_add_stays(STEM_HEAD, taffrail + Vector3(0.0, 0.0, -0.10))
	_add_lantern("SternLantern",
		taffrail + Vector3(0.0, 0.0, LANTERN_OVERHANG), LANTERN_RISE)


# --- Rumpf -----------------------------------------------------------------

## Das erhoehte Achterdeck samt Reling, Vorderwand und Heckwand.
##
## Kein eigener Spantenriss: Es folgt der Breite des Rumpfes an derselben
## Stelle, ist also ein Aufbau auf dem Achterschiff und keine zweite Huelle.
##
## Der Querschnitt ist derselbe wie beim Schanzkleid des Rumpfes und aus
## demselben Grund: Aussenwand hoch, Handlauf quer, Innenwand herunter, dann
## die Gehflaeche. Eine blosse Platte mit einer Kante sieht aus wie ein Deckel.
func _tolda_mesh() -> ArrayMesh:
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planks := SurfaceTool.new()
	planks.begin(Mesh.PRIMITIVE_TRIANGLES)

	var deck_color := Palette.for_vertex(Palette.DECK)
	var wall_color := Palette.for_vertex(Palette.TOPSIDE)
	var rail_color := Palette.for_vertex(Palette.TIMBER)

	var edges: Array[Dictionary] = []
	for station: Dictionary in STATIONS:
		var z: float = station["z"]
		if z < TOLDA_START:
			continue
		edges.append(_tolda_edge(z))
	# Vorderkante des Halbdecks liegt zwischen zwei Spanten - eingeschoben.
	edges.push_front(_tolda_edge(TOLDA_START))

	for i in range(edges.size() - 1):
		var a: Dictionary = edges[i]
		var b: Dictionary = edges[i + 1]

		# Die Gehflaeche liegt zwischen den Innenkanten der Reling.
		HullMesh.quad(planks,
			Vector3(-a["inner"], a["y"], a["z"]),
			Vector3(a["inner"], a["y"], a["z"]),
			Vector3(b["inner"], b["y"], b["z"]),
			Vector3(-b["inner"], b["y"], b["z"]),
			deck_color, -1, Vector3.UP,
			Vector2(a["z"], -a["inner"]), Vector2(a["z"], a["inner"]),
			Vector2(b["z"], b["inner"]), Vector2(b["z"], -b["inner"]))

		for side: int in [1, -1]:
			var out := Vector3(float(side), 0.0, 0.0)

			# Die Aussenwand. Ohne sie schwebte das Halbdeck als Platte ueber
			# dem Achterschiff - im Aufriss war zwischen Reling und Deckel Luft.
			#
			# Sie setzt auf der Relingoberkante des Rumpfes auf, nicht auf dem
			# Deck: Achtern wird das Schanzkleid einfach hoeher, es steht dort
			# keine zweite Wand daneben.
			HullMesh.quad(walls,
				Vector3(a["x"] * side, a["rail"], a["z"]),
				Vector3(a["x"] * side, a["top"], a["z"]),
				Vector3(b["x"] * side, b["top"], b["z"]),
				Vector3(b["x"] * side, b["rail"], b["z"]),
				wall_color, -1, out,
				Vector2(a["z"], a["rail"]), Vector2(a["z"], a["top"]),
				Vector2(b["z"], b["top"]), Vector2(b["z"], b["rail"]))

			# Der Handlauf oben drauf.
			HullMesh.quad(walls,
				Vector3(a["x"] * side, a["top"], a["z"]),
				Vector3(a["inner"] * side, a["top"], a["z"]),
				Vector3(b["inner"] * side, b["top"], b["z"]),
				Vector3(b["x"] * side, b["top"], b["z"]),
				rail_color, -1, Vector3.UP,
				Vector2(a["z"], a["x"]), Vector2(a["z"], a["inner"]),
				Vector2(b["z"], b["inner"]), Vector2(b["z"], b["x"]))

			# Und die Innenwand herunter auf die Gehflaeche.
			HullMesh.quad(walls,
				Vector3(a["inner"] * side, a["top"], a["z"]),
				Vector3(a["inner"] * side, a["y"], a["z"]),
				Vector3(b["inner"] * side, b["y"], b["z"]),
				Vector3(b["inner"] * side, b["top"], b["z"]),
				deck_color, -1, -out,
				Vector2(a["z"], a["top"]), Vector2(a["z"], a["y"]),
				Vector2(b["z"], b["y"]), Vector2(b["z"], b["top"]))

	# Der Decksbruch: die Wand, an der das Halbdeck anfaengt. Sie ist im Profil
	# die einzige senkrechte Kante am ganzen Schiff und traegt den Umriss mit.
	#
	# Eine volle Flaeche ueber die ganze Breite, vom Hauptdeck bis zur
	# Relingoberkante: Damit ist das gesamte Profil des Aufbaus geschlossen,
	# ohne dass man Wand, Handlauf und Innenwand einzeln nachbilden muesste.
	var front: Dictionary = edges[0]
	var front_deck: float = _deck_at(TOLDA_START)
	HullMesh.quad(walls,
		Vector3(-front["x"], front_deck, TOLDA_START),
		Vector3(front["x"], front_deck, TOLDA_START),
		Vector3(front["x"], front["top"], TOLDA_START),
		Vector3(-front["x"], front["top"], TOLDA_START),
		wall_color, -1, Vector3.FORWARD,
		Vector2(-front["x"], front_deck), Vector2(front["x"], front_deck),
		Vector2(front["x"], front["top"]), Vector2(-front["x"], front["top"]))

	# Und dasselbe achtern.
	#
	# Diese Wand fehlte. Von hinten sah man ueber die Reling hinweg in den Rumpf
	# hinein, weil zwischen Relingoberkante und Halbdeck nichts stand - die
	# Kajuete war offen. Aus der Verfolgerkamera faellt so etwas nie auf, aus
	# der Heckaufnahme sofort. Seitdem prueft der Rauchtest den Rumpf mit
	# Strahlen von innen nach aussen, statt Flaechen zu zaehlen (Regel C7).
	var stern: Dictionary = edges[edges.size() - 1]
	HullMesh.quad(walls,
		Vector3(-stern["x"], stern["rail"], stern["z"]),
		Vector3(stern["x"], stern["rail"], stern["z"]),
		Vector3(stern["x"], stern["top"], stern["z"]),
		Vector3(-stern["x"], stern["top"], stern["z"]),
		wall_color, -1, Vector3.BACK,
		Vector2(-stern["x"], stern["rail"]), Vector2(stern["x"], stern["rail"]),
		Vector2(stern["x"], stern["top"]), Vector2(-stern["x"], stern["top"]))

	return HullMesh.finish(walls, planks)


## Eine Querkante des Halbdecks: wo es steht, wie breit, wie hoch.
func _tolda_edge(z: float) -> Dictionary:
	var outer := _rail_half_beam_at(z)
	var walk := _deck_at(z) + TOLDA_HEIGHT
	return {
		"z": z,
		"x": outer,
		"inner": maxf(outer - HullMesh.RAIL_THICKNESS, 0.0),
		"y": walk,
		"top": walk + TOLDA_RAIL,
		"rail": _deck_at(z) + BULWARK,
	}


## Die Mitte der Heckreling - wo Backstag und Laterne ansetzen.
func _taffrail() -> Vector3:
	var transom := _transom_z()
	return Vector3(0.0, _deck_at(transom) + TOLDA_HEIGHT + TOLDA_RAIL, transom)


## Der Vorsteven, als schraeg stehendes Holz vor dem vordersten Spant.
func _add_stem() -> void:
	var along := STEM_HEAD - STEM_FOOT
	var post := BoxMesh.new()
	post.size = Vector3(0.15, along.length(), 0.17)

	var node := MeshInstance3D.new()
	node.name = "Stem"
	node.mesh = post
	node.material_override = _solid(Palette.TAR)
	node.transform = Transform3D(
		_basis_from_up(along.normalized()), (STEM_HEAD + STEM_FOOT) * 0.5)
	add_child(node)


## Ruder am Achtersteven, aussen angeschlagen.
##
## Es faellt mit dem Achtersteven nach achtern. Senkrecht sah es aus wie ein
## angeschraubtes Brett.
func _add_rudder() -> void:
	var blade := BoxMesh.new()
	blade.size = Vector3(0.13, 1.30, 0.46)
	var node := MeshInstance3D.new()
	node.name = "Rudder"
	node.mesh = blade
	node.material_override = _solid(Palette.HULL)
	node.position = Vector3(0.0, -0.26, 4.98)
	# Eine Drehung um die Querachse ist kein Kurs (Regel B7).
	node.rotation_degrees = Vector3(-9.0, 0.0, 0.0)
	add_child(node)


# --- Was am Achterdeck anders ist -------------------------------------------

## Der Besan steht auf dem Achterdeck, nicht im Rumpf.
func _mast_foot(index: int) -> Vector3:
	var foot := super(index)
	if foot.z >= TOLDA_START:
		foot.y += TOLDA_HEIGHT
	return foot


## Achtern gilt die Reling des Achterdecks und nicht die des Rumpfes.
##
## Zuerst stand hier nur die Hauptreling, und die Wanten des Besans liefen
## dadurch quer durch das Halbdeck hindurch bis auf das Hauptdeck hinunter.
func _rail_point(z: float, side: int) -> Vector3:
	if z < TOLDA_START:
		return super(z, side)
	var x := _rail_half_beam_at(z) - HullMesh.RAIL_THICKNESS
	return Vector3(x * float(side), _deck_at(z) + TOLDA_HEIGHT + TOLDA_RAIL, z)
