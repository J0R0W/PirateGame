## Baut einen Schiffsrumpf als Mesh aus Spantquerschnitten.
##
## Bisher bestand jeder Rumpf im Spiel aus drei Quadern. Regel A11 verlangt
## richtige seemaennische Verhaeltnisse, und die bekommt man aus Kisten nicht -
## ein Rumpf hat einen Sprung (die Decklinie faellt zur Mitte durch), eine Kimm
## (den Knick vom Boden zur Bordwand) und einen Steven, der vorne zusammenlaeuft.
##
## Ein Spantenriss ist ausserdem die Form, in der ein Schiff ohnehin beschrieben
## wird: eine Handvoll Querschnitte in Laengsrichtung, dazwischen wird gestrakt.
## Wer die Form aendert, aendert eine Zahlentabelle - nicht eine Szene mit
## dreissig verschobenen Quadern.
##
## Nodefrei und ohne Szene pruefbar (Regel B3).
##
## [b]Achsen[/b] wie im ganzen Spiel: Bug nach -Z, Steuerbord nach +X, oben +Y.
##
## [b]Zwei Flaechen, zwei Materialien[/b]: Aussenhaut und Deck kommen als
## getrennte Surfaces heraus. Sie tragen dieselbe Textur, aber die Planken
## laufen verschieden - laengs des Rumpfes um den Spant herum, quer ueber das
## Deck von Bord zu Bord. Mit einem einzigen Material bekaeme man eines von
## beidem falsch.
class_name HullMesh
extends RefCounted

## Ein Spant. Alle Masse in Metern, x-Werte sind [i]halbe[/i] Breiten.
##
## [code]z[/code]     Laengsposition, Bug negativ.
## [code]beam[/code]  halbe Breite an der Oberkante des Rumpfes.
## [code]deck[/code]  Hoehe der Decklinie an dieser Stelle - das ist der Sprung.
## [code]keel[/code]  Hoehe des Bodens. Negativ heisst unter Wasser.
## [code]floor[/code] halbe Breite des Bodens, also wo die Kimm sitzt.

## Wo zwischen Boden und Deck die groesste Breite liegt.
##
## Bei 1.0 waere die Bordwand oben am breitesten; ein Rumpf zieht sich nach oben
## aber wieder ein (Einfallen). Der Wert setzt die Wasserlinie.
const WIDEST: float = 0.66
## Wie weit sich die Bordwand von der groessten Breite bis zur Decklinie einzieht.
const TUMBLEHOME: float = 0.965
## Hoehe der Kimm ueber dem Kiel, als Anteil der Seitenhoehe.
const BILGE_RISE: float = 0.10
## Wandstaerke des Schanzkleids.
const RAIL_THICKNESS: float = 0.09

## Indizes im Querschnitt - siehe [method _section].
const P_KEEL: int = 0
const P_BILGE: int = 1
const P_WIDEST: int = 2
const P_SHEER: int = 3
const P_RAIL_TOP: int = 4
const P_RAIL_IN: int = 5
const P_DECK_EDGE: int = 6


## Baut den Rumpf. [param bulwark] ist die Hoehe des Schanzkleids ueber Deck.
##
## Das Ergebnis traegt Vertexfarben (Regel A2/A3), UV-Koordinaten in Metern und
## seine Materialien gleich mit - der Aufrufer setzt kein material_override.
static func build(stations: Array, bulwark: float) -> ArrayMesh:
	# Querschnitte einmal vorrechnen, damit sie nicht je Ring erneut entstehen.
	var sections: Array[PackedVector2Array] = []
	var girths: Array[PackedFloat32Array] = []
	for station: Dictionary in stations:
		var section := _section(station, bulwark)
		sections.append(section)
		girths.append(_girth(section))

	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	_plate(shell, stations, sections, girths)
	# Beide Enden zumachen. Der Steven fehlte zuerst: Der vorderste Spant ist
	# nur vierzehn Zentimeter breit, und durch diesen Schlitz sah man von vorn
	# in den Rumpf hinein.
	_cap(shell, sections[0], float(stations[0]["z"]), Vector3.FORWARD)
	_cap(shell, sections[sections.size() - 1],
		float(stations[stations.size() - 1]["z"]), Vector3.BACK)

	var planks := SurfaceTool.new()
	planks.begin(Mesh.PRIMITIVE_TRIANGLES)
	_deck(planks, stations, sections)

	return finish(shell, planks)


## Fasst Aussenhaut und Deck zu einem Mesh mit zwei Flaechen zusammen.
##
## Auch von [CaravelModel] benutzt: Das Achterdeck ist derselbe Fall - Waende
## aus Aussenhaut, oben eine Decksflaeche.
static func finish(shell: SurfaceTool, planks: SurfaceTool) -> ArrayMesh:
	shell.generate_normals()
	planks.generate_normals()
	var mesh: ArrayMesh = shell.commit()
	planks.commit(mesh)
	mesh.surface_set_material(0, shell_material())
	mesh.surface_set_material(1, deck_material())
	return mesh


## Das Material der Aussenhaut: Vertexfarben, kein PBR (Regel A2).
##
## Die Textur nimmt an den Fugen nur Helligkeit weg; die Farbe kommt aus den
## Vertexfarben und damit aus [Palette].
static func shell_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.78
	mat.metallic = 0.0
	ShipTextures.apply(mat, ShipTextures.planking())
	return mat


## Das Material der Decksflaechen. Dieselbe Textur, nur eine andere UV-Achse -
## siehe [method _deck].
static func deck_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.86
	mat.metallic = 0.0
	ShipTextures.apply(mat, ShipTextures.planking())
	return mat


## Farbe und Glaettung je Laengsstreifen, von unten nach oben.
##
## Der Rumpf unter dem Bergholz ist glatt vernaeht (kravel gebaut, daher der
## Name Karavelle) - dort wird gemittelt. Bergholz, Schanzkleid und Reling
## bekommen harte Kanten, sonst verwaschen sie zu einem Wulst.
##
## [b]Drei Baender, nicht zwei[/b]: dunkler Boden, ein schwarzes Bergholz ueber
## der Wasserlinie, darueber das hellere Freibord. Vorher war alles ueber der
## groessten Breite [code]TAR[/code], und ein Schiff war von der Seite ein
## schwarzer Klumpen, an dem man das Achterdeck nicht vom Rumpf unterscheiden
## konnte.
##
## Der Index eines Streifens ist zugleich der seines unteren Punktes - darauf
## verlaesst sich [method _cap], damit der Spiegel dieselben Baender traegt.
static func strips() -> Array[Dictionary]:
	return [
		{"from": P_KEEL, "to": P_BILGE, "color": Palette.HULL, "smooth": 0},
		{"from": P_BILGE, "to": P_WIDEST, "color": Palette.HULL, "smooth": 0},
		{"from": P_WIDEST, "to": P_SHEER, "color": Palette.TAR, "smooth": -1},
		{"from": P_SHEER, "to": P_RAIL_TOP, "color": Palette.TOPSIDE, "smooth": -1},
		{"from": P_RAIL_TOP, "to": P_RAIL_IN, "color": Palette.TIMBER, "smooth": -1},
		{"from": P_RAIL_IN, "to": P_DECK_EDGE, "color": Palette.DECK, "smooth": -1},
	]


## Der Querschnitt eines Spants, von unten nach oben und dann nach innen.
##
## Die Punkte sind (halbe Breite, Hoehe). Die Reihenfolge ist die Kette, an der
## entlang gestrakt wird - jedes Paar aufeinanderfolgender Punkte spannt einen
## Laengsstreifen auf.
static func _section(station: Dictionary, bulwark: float) -> PackedVector2Array:
	var beam: float = station["beam"]
	var deck: float = station["deck"]
	var keel: float = station["keel"]
	var floor_beam: float = station["floor"]

	var depth := deck - keel
	var inner := maxf(beam * TUMBLEHOME - RAIL_THICKNESS, 0.0)

	var points := PackedVector2Array()
	points.resize(7)
	points[P_KEEL] = Vector2(0.0, keel)
	points[P_BILGE] = Vector2(floor_beam, keel + depth * BILGE_RISE)
	points[P_WIDEST] = Vector2(beam, keel + depth * WIDEST)
	points[P_SHEER] = Vector2(beam * TUMBLEHOME, deck)
	points[P_RAIL_TOP] = Vector2(beam * TUMBLEHOME, deck + bulwark)
	points[P_RAIL_IN] = Vector2(inner, deck + bulwark)
	points[P_DECK_EDGE] = Vector2(inner, deck)
	return points


## Aufgelaufene Bogenlaenge entlang des Querschnitts, vom Kiel aus.
##
## Das ist die V-Achse der Aussenhaut: Eine Linie gleichen V laeuft laengs des
## Rumpfes um die Spanten herum - also genau dort, wo eine Planke liegt. Weil in
## Metern gerechnet wird, bleiben die Planken am Bug so breit wie mittschiffs,
## obwohl der Spant dort viel kleiner ist.
static func _girth(points: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(points.size())
	out[0] = 0.0
	for i in range(1, points.size()):
		out[i] = out[i - 1] + points[i - 1].distance_to(points[i])
	return out


## Die Aussenhaut, Streifen fuer Streifen von Spant zu Spant.
static func _plate(
	tool: SurfaceTool,
	stations: Array,
	sections: Array[PackedVector2Array],
	girths: Array[PackedFloat32Array]
) -> void:
	for side: int in [1, -1]:
		for strip: Dictionary in strips():
			var lower: int = strip["from"]
			var upper: int = strip["to"]
			var color: Color = Palette.for_vertex(strip["color"])
			var smooth: int = strip["smooth"]

			for i in range(stations.size() - 1):
				var za: float = stations[i]["z"]
				var zb: float = stations[i + 1]["z"]
				var a: PackedVector2Array = sections[i]
				var b: PackedVector2Array = sections[i + 1]
				var ga: PackedFloat32Array = girths[i]
				var gb: PackedFloat32Array = girths[i + 1]

				var p0 := Vector3(a[lower].x * side, a[lower].y, za)
				var p1 := Vector3(a[upper].x * side, a[upper].y, za)
				var p2 := Vector3(b[upper].x * side, b[upper].y, zb)
				var p3 := Vector3(b[lower].x * side, b[lower].y, zb)

				# Nach aussen zeigt bei einer Bordwand die Seite, auf der man
				# steht. Fuer die innere Schanzkleidwand ist das nach innen -
				# daher der Vorzeichenwechsel.
				var outward := Vector3(float(side), 0.0, 0.0)
				if lower == P_RAIL_IN:
					outward = -outward
				elif lower == P_RAIL_TOP:
					outward = Vector3.UP

				quad(tool, p0, p1, p2, p3, color, smooth, outward,
					Vector2(za, ga[lower]), Vector2(za, ga[upper]),
					Vector2(zb, gb[upper]), Vector2(zb, gb[lower]))


## Das Deck zwischen den beiden Decksmalkanten.
##
## Die UV-Achsen liegen hier andersherum als an der Aussenhaut: V quer zum
## Schiff, damit die Planken laengs laufen. So liegen sie auf einem Schiff auch.
static func _deck(
	tool: SurfaceTool,
	stations: Array,
	sections: Array[PackedVector2Array]
) -> void:
	var color := Palette.for_vertex(Palette.DECK)
	for i in range(stations.size() - 1):
		var za: float = stations[i]["z"]
		var zb: float = stations[i + 1]["z"]
		var a: Vector2 = sections[i][P_DECK_EDGE]
		var b: Vector2 = sections[i + 1][P_DECK_EDGE]

		quad(tool,
			Vector3(-a.x, a.y, za),
			Vector3(a.x, a.y, za),
			Vector3(b.x, b.y, zb),
			Vector3(-b.x, b.y, zb),
			color, -1, Vector3.UP,
			Vector2(za, -a.x), Vector2(za, a.x),
			Vector2(zb, b.x), Vector2(zb, -b.x))


## Ein Rumpfende: der Spiegel achtern, der Steven vorn.
##
## Beide sind dieselbe Sache - der aeusserste Spant, als Flaeche geschlossen.
## Der Faecher laeuft nur ueber die Aussenkontur bis zur Relingoberkante: Das
## oberste Band deckt bereits die ganze Breite ab, alles darueber laege doppelt
## und flimmerte.
static func _cap(
	tool: SurfaceTool,
	section: PackedVector2Array,
	z: float,
	outward: Vector3
) -> void:
	var bands := strips()
	for i in range(P_KEEL, P_RAIL_TOP):
		var lower: Vector2 = section[i]
		var upper: Vector2 = section[i + 1]
		# Dieselbe Farbe wie der Laengsstreifen daneben. Einfarbig war der
		# Spiegel ein Brett, das nicht zum Rumpf gehoerte.
		var color: Color = Palette.for_vertex(bands[i]["color"])
		quad(tool,
			Vector3(-lower.x, lower.y, z),
			Vector3(-upper.x, upper.y, z),
			Vector3(upper.x, upper.y, z),
			Vector3(lower.x, lower.y, z),
			color, -1, outward,
			Vector2(-lower.x, lower.y), Vector2(-upper.x, upper.y),
			Vector2(upper.x, upper.y), Vector2(lower.x, lower.y))


## Ein Viereck als zwei Dreiecke, mit garantiert nach aussen zeigender Normale.
static func quad(
	tool: SurfaceTool,
	p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
	color: Color, smooth: int, outward: Vector3,
	uv0: Vector2 = Vector2.ZERO, uv1: Vector2 = Vector2.ZERO,
	uv2: Vector2 = Vector2.ZERO, uv3: Vector2 = Vector2.ZERO
) -> void:
	face(tool, p0, p1, p2, color, smooth, outward, uv0, uv1, uv2)
	face(tool, p0, p2, p3, color, smooth, outward, uv0, uv2, uv3)


## Ein Dreieck. Die Reihenfolge wird notfalls getauscht.
##
## Godot nimmt im Uhrzeigersinn gewickelte Dreiecke als Vorderseite und rechnet
## die Normale als (v0-v2) x (v0-v1). Statt sich bei jedem Streifen neu zu
## ueberlegen, herum welche Ecke zuerst kommt, wird hier gemessen: Zeigt die
## Normale nach innen, tauschen zwei Ecken den Platz.
##
## Grund: Eine falsch gewickelte Flaeche ist nicht unsichtbar, sondern nur
## falsch beleuchtet - und das faellt an einem gekruemmten Rumpf erst auf, wenn
## die Sonne von der anderen Seite steht.
##
## Die UV-Koordinaten wandern beim Tausch mit. Ohne das laege die Planke auf
## jeder umgedrehten Flaeche gespiegelt - und zwar nur auf manchen.
static func face(
	tool: SurfaceTool,
	v0: Vector3, v1: Vector3, v2: Vector3,
	color: Color, smooth: int, outward: Vector3,
	uv0: Vector2 = Vector2.ZERO, uv1: Vector2 = Vector2.ZERO,
	uv2: Vector2 = Vector2.ZERO
) -> void:
	var a := v1
	var b := v2
	var ua := uv1
	var ub := uv2
	if (v0 - b).cross(v0 - a).dot(outward) < 0.0:
		a = v2
		b = v1
		ua = uv2
		ub = uv1

	_vertex(tool, v0, color, smooth, uv0)
	_vertex(tool, a, color, smooth, ua)
	_vertex(tool, b, color, smooth, ub)


static func _vertex(
	tool: SurfaceTool, point: Vector3, color: Color, smooth: int, uv: Vector2
) -> void:
	tool.set_smooth_group(smooth)
	tool.set_color(color)
	tool.set_uv(uv)
	tool.add_vertex(point)
