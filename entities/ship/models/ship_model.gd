## Die gemeinsame Werkbank aller Schiffsmodelle.
##
## Die Karavelle war das erste Schiff mit eigenem Rumpf, und alles, was man
## fuer ein zweites gebraucht haette - Taue, Anker, Spill, Luke, Drehbassen,
## Masten mit Wanten und Stagen, das Straken zwischen zwei Spanten -, stand
## in ihrer Datei. Das naechste Schiff haette es kopiert, und ab dann gaebe es
## zwei Anker, die verschieden altern.
##
## Deshalb steht es jetzt hier. Ein Modell erbt von dieser Klasse und
## beschreibt sich in [b]Tabellen[/b]: der Spantenriss ([method stations]),
## die Masten ([method masts]), und in [method _assemble] die Liste der
## Beschlaege mit ihren Positionen. Was ein Anker ist, weiss die Werkbank.
##
## [b]Achsen[/b] wie im ganzen Spiel: Bug nach -Z, Steuerbord nach +X,
## oben +Y, Wasserlinie bei y = 0.
##
## Alle Farben aus [Palette] (Regel A3), alle Rundhoelzer ueber
## [method _basis_from_up] gestellt statt in Euler-Winkeln gedreht.
class_name ShipModel
extends Node3D

## Gruppe, in der [Ship] die Segel zum Reffen einsammelt.
const SAIL_GROUP: StringName = &"sail"

## Staerke der stehenden Taue. Duenn: Bei 0.028 waren die Wanten dicker als
## die Rahnocken und legten sich als schwarze Balken ueber die Segel.
const ROPE_RADIUS: float = 0.019

## Unterteilung eines Segels laengs der Rah und quer dazu.
##
## Bei 8 mal 4 zeichnete sich die Dreiecksteilung der Vierecke als Diagonalen
## im Tuch ab - der Bauch macht jedes Viereck windschief, und die Schattierung
## bricht dann entlang der Diagonale. Feiner unterteilt verschwindet das, und
## drei Segel kosten die Bildrate nichts.
const SAIL_STEPS: int = 14
const SAIL_BANDS: int = 6

## Wo die Wanten eines Mastes an der Reling ansetzen, in Metern hinter dem
## Mastfuss. Zwei je Seite reichen fuer den Umriss.
const SHROUD_OFFSETS: Array[float] = [0.55, 1.15]

var _built: bool = false
## Rohre, die das Modell sichtbar traegt. Der Rauchtest vergleicht die Zahl
## mit [member ShipClass.cannon_slots] - ein Schiff soll so bewaffnet
## aussehen, wie es schiesst.
var _gun_count: int = 0


func _ready() -> void:
	build()


## Baut das Modell auf. Wird von [method Ship.apply_class] direkt gerufen und
## nicht nur ueber [method _ready] - sonst haengt es davon ab, ob das Schiff im
## Moment des Einsetzens schon im Baum haengt, und die Segel waeren manchmal
## noch nicht da, wenn jemand nach ihnen sucht.
##
## Gegen Doppelaufruf gesichert, sonst steht das Rigg zweimal da.
func build() -> void:
	if _built:
		return
	_built = true
	_assemble()


# --- Was ein Modell beantwortet -------------------------------------------
#
# Diese Methoden ueberschreibt ein Modell. Sie sind Funktionen und keine
# Konstanten, weil GDScript Konstanten nicht ueberschreiben kann - die
# Tabellen selbst bleiben trotzdem const im Modell.

## Hier baut das Modell seinen Rumpf und haengt seine Beschlaege ein.
func _assemble() -> void:
	pass


## Der Spantenriss. Bug negativ, aufsteigend nach z sortiert - siehe [HullMesh].
func stations() -> Array:
	return []


## Die Masten, jeder ein Dictionary mit mindestens "z" und "height".
func masts() -> Array:
	return []


## Fall der Masten nach achtern, in Grad.
func mast_rake_deg() -> float:
	return 0.0


## Hoehe des Schanzkleids ueber Deck.
func bulwark() -> float:
	return 0.0


## Knoten unter dem Modell, die zusammen die geschlossene Huelle bilden.
## Der Rauchtest prueft sie mit Strahlen von innen (Regel C7).
func hull_parts() -> PackedStringArray:
	return PackedStringArray(["Plating"])


## Je ein Punkt im Inneren jedes Raumes, den der Rumpf umschliesst, mit
## Namen: [code]{"at": Vector3, "was": "Laderaum"}[/code]. Von dort muss in
## alle sechs Richtungen etwas im Weg sein.
func interior_probes() -> Array[Dictionary]:
	return []


## Wieviele Rohre das Modell zeigt.
func gun_count() -> int:
	return _gun_count


# --- Masse aus dem Spantenriss --------------------------------------------

## Ein Wert aus dem Spantenriss an beliebiger Laengsposition, gestrakt.
##
## Zuerst wurde hier der [i]naechstgelegene[/i] Spant genommen. Das ging so
## lange gut, wie nur ganze Spanten gefragt waren - die Vorderkante des
## Halbdecks liegt aber zwischen zweien, und sie kam dadurch sechs Zentimeter
## zu breit heraus und stand seitlich aus dem Rumpf heraus.
func _column_at(z: float, key: String) -> float:
	var table := stations()
	for i in range(table.size() - 1):
		var a: Dictionary = table[i]
		var b: Dictionary = table[i + 1]
		if z >= float(a["z"]) and z <= float(b["z"]):
			var t := (z - float(a["z"])) / (float(b["z"]) - float(a["z"]))
			return lerpf(float(a[key]), float(b[key]), t)
	return float(table[0][key]) if z < float(table[0]["z"]) \
		else float(table[table.size() - 1][key])


## Hoehe der Decklinie an dieser Laengsposition.
func _deck_at(z: float) -> float:
	return _column_at(z, "deck")


## Halbe Breite an der Reling - dort, wo Wanten, Drehbassen und Aufbauten
## ansetzen.
func _rail_half_beam_at(z: float) -> float:
	return _column_at(z, "beam") * HullMesh.TUMBLEHOME - HullMesh.RAIL_THICKNESS


## Wo ein Tau oder ein Rohr auf der Reling ansetzt.
##
## Ein Modell mit Aufbauten ueberschreibt das: Achtern gilt dann die Reling
## des Achterdecks und nicht die des Rumpfes. Sonst laufen die Wanten des
## Besans quer durch das Halbdeck hindurch.
func _rail_point(z: float, side: int) -> Vector3:
	return Vector3(
		_rail_half_beam_at(z) * float(side), _deck_at(z) + bulwark(), z)


## Laengsposition des vordersten und des hintersten Spants.
func _stem_z() -> float:
	return float(stations()[0]["z"])


func _transom_z() -> float:
	var table := stations()
	return float(table[table.size() - 1]["z"])


# --- Masten ----------------------------------------------------------------

## Die Achse, auf der ein Mast steht - senkrecht, aber nach achtern gefallen.
func _mast_axis() -> Vector3:
	var rake := deg_to_rad(mast_rake_deg())
	return Vector3(0.0, cos(rake), sin(rake))


## Fuss eines Mastes: auf dem Deck an seiner Laengsposition. Ein Modell mit
## Aufbauten ueberschreibt das fuer Masten, die auf einem Aufbau stehen.
func _mast_foot(index: int) -> Vector3:
	var z: float = masts()[index]["z"]
	return Vector3(0.0, _deck_at(z), z)


## Topp eines Mastes, den Fall eingerechnet.
##
## Der Topp liegt durch den Fall nicht ueber dem Mastfuss, sondern ein Stueck
## weiter achtern. Genau das stand zuerst nicht da: Die Wanten endeten in der
## richtigen Hoehe und einen halben Meter zu weit vorn.
func _mast_head(index: int) -> Vector3:
	return _mast_foot(index) + _mast_axis() * float(masts()[index]["height"])


## Ein Mast mit Rah, Segel und Wanten - und, wenn die Tabelle es sagt, der
## Flagge.
##
## Die Tabellenzeile: [code]z[/code], [code]height[/code], [code]sail[/code]
## ("lateen"), dazu die Masse des Segels (siehe [method _add_lateen]) und
## [code]flag[/code], wenn dort die Flagge weht.
func _add_mast(index: int, spec: Dictionary) -> void:
	var height: float = spec["height"]
	var foot := _mast_foot(index)
	var up := _mast_axis()
	var head := _mast_head(index)

	var mast := Node3D.new()
	mast.name = "Mast%d" % index
	mast.position = foot
	add_child(mast)

	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.095
	pole.height = height
	pole.radial_segments = 7
	pole.rings = 1
	var pole_node := MeshInstance3D.new()
	pole_node.name = "Spar"
	pole_node.mesh = pole
	pole_node.material_override = _solid(Palette.TIMBER)
	pole_node.position = up * (height * 0.5)
	# Eine Neigung um die Querachse ist kein Kurs (Regel B7).
	pole_node.rotation_degrees = Vector3(mast_rake_deg(), 0.0, 0.0)
	mast.add_child(pole_node)

	# Der Knopf am Topp. Ein glatt abgeschnittener Zylinder sieht aus wie ein
	# abgebrochener Mast, und drei davon nebeneinander fallen auf.
	var knob := SphereMesh.new()
	knob.radius = 0.075
	knob.height = 0.15
	knob.radial_segments = 7
	knob.rings = 3
	var truck := MeshInstance3D.new()
	truck.name = "Truck"
	truck.mesh = knob
	truck.material_override = _solid(Palette.TIMBER)
	truck.position = up * height
	mast.add_child(truck)

	# Die Rah schwenkt, der Mast nicht - deshalb steht sie als eigener Knoten
	# neben ihm und nicht unter ihm. Stuende sie darunter, kippte der Fall des
	# Mastes beim Schwenken zur Seite und die Wanten liefen ins Leere.
	var rig := Rig.new()
	rig.name = "Rig%d" % index
	rig.position = foot
	add_child(rig)
	match String(spec.get("sail", "lateen")):
		"lateen":
			rig.rest_chord_deg = 0.0
			rig.max_swing_deg = float(spec["swing"])
			_add_lateen(rig, height, up, spec)
		_:
			push_error("ShipModel: unbekannte Takelung '%s'" % spec.get("sail"))

	_add_shrouds(index, float(spec["z"]), head)

	if bool(spec.get("flag", false)):
		_add_flag(head)


## Rah und Segel eines Lateiners.
##
## Die Rah laeuft schraeg durch den Mast: das untere Ende (der Hals) steht weit
## vorn dicht ueber Deck, das obere (das Piek) hoch achtern. Das Segel ist das
## Dreieck aus Hals, Piek und Schothorn.
##
## Aus der Tabelle: [code]pitch[/code] Winkel der Rah gegen die Waagerechte in
## Grad, [code]length[/code] Laenge der Rah als Vielfaches der Masthoehe,
## [code]hoist[/code] wie hoch am Mast sie angeschlagen ist (Anteil der
## Masthoehe), [code]belly[/code] Tiefe des Segelbauchs in Metern.
func _add_lateen(rig: Rig, height: float, up: Vector3, spec: Dictionary) -> void:
	var pitch := deg_to_rad(float(spec["pitch"]))
	# Die Rah liegt in der Mittschiffsebene: vorne unten, achtern oben.
	var along := Vector3(0.0, sin(pitch), cos(pitch))
	var half := height * float(spec["length"]) * 0.5
	var centre := up * (height * float(spec["hoist"]))

	var yard := CylinderMesh.new()
	yard.top_radius = 0.035
	yard.bottom_radius = 0.055
	yard.height = half * 2.0
	yard.radial_segments = 6
	yard.rings = 1
	var yard_node := MeshInstance3D.new()
	yard_node.name = "Yard"
	yard_node.mesh = yard
	yard_node.material_override = _solid(Palette.TIMBER)
	# Der Zylinder steht auf seiner y-Achse; sie muss auf die Rah zeigen.
	yard_node.transform = Transform3D(_basis_from_up(along), centre)
	rig.add_child(yard_node)

	# Das Schothorn: achtern, dicht ueber Deck, nach aussen geschotet.
	var peak := centre + along * half
	var tack := centre - along * half
	var clew := Vector3(0.0, tack.y + 0.22, peak.z * 0.90)

	# Eigenes Achsenkreuz fuer das Segel: die lokale z-Achse liegt auf der Rah,
	# die lokale y-Achse steht senkrecht darauf und zeigt zum Schothorn. Damit
	# refft Ship das Segel mit scale.y an die Rah heran - und nicht senkrecht
	# nach unten, was bei einer schraegen Rah aussaehe wie ein Riss im Tuch.
	var axis_z := along
	var axis_y := Vector3(0.0, -along.z, along.y)
	if axis_y.dot(clew - centre) < 0.0:
		axis_y = -axis_y
	var basis := Basis(axis_y.cross(axis_z), axis_y, axis_z)

	var sail := Node3D.new()
	sail.name = "Sail"
	sail.transform = Transform3D(basis, centre)
	sail.add_to_group(SAIL_GROUP)
	rig.add_child(sail)

	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	canvas.mesh = _sail_mesh(half, basis.inverse() * (clew - centre), float(spec["belly"]))
	canvas.material_override = _canvas_material()
	# Ein Segel ist eine Flaeche ohne Dicke: Vorder- und Rueckseite liegen in
	# der Schattenkarte auf derselben Tiefe. Beide Seiten muessen hinein, sonst
	# wirft ein gewendetes Segel keinen Schatten - siehe dazu
	# disable_receive_shadows in [method _canvas_material].
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	sail.add_child(canvas)


## Das Segeltuch als gewoelbtes Dreieck in der lokalen Ebene des Segelknotens.
##
## [param clew] ist das Schothorn in eben diesen Koordinaten. Die Breite des
## Tuchs quer zur Rah waechst vom Hals bis zum Schothorn und faellt von dort
## zum Piek - das ist genau das Dreieck, nur streifenweise gerechnet, damit es
## einen Bauch bekommen kann.
##
## Die UV-Koordinaten sind Meter im Tuch: V laeuft laengs der Rah, die Naehte
## der Segelbahnen liegen also quer dazu - vom Rundholz zum Liek, wie genaeht.
func _sail_mesh(half: float, clew: Vector3, belly: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var head := Palette.for_vertex(Palette.CANVAS)
	var foot := Palette.for_vertex(Palette.CANVAS_SHADE)

	for i in range(SAIL_STEPS):
		for j in range(SAIL_BANDS):
			var corners: Array[Vector3] = []
			var shades: Array[Color] = []
			for step: Vector2i in [
				Vector2i(i, j), Vector2i(i + 1, j),
				Vector2i(i + 1, j + 1), Vector2i(i, j + 1)
			]:
				var along := float(step.x) / float(SAIL_STEPS)
				var across := float(step.y) / float(SAIL_BANDS)
				corners.append(_sail_point(half, clew, belly, along, across))
				shades.append(head.lerp(foot, across))

			HullMesh.quad(tool,
				corners[0], corners[1], corners[2], corners[3],
				shades[0], 0, Vector3.RIGHT,
				Vector2(corners[0].y, corners[0].z),
				Vector2(corners[1].y, corners[1].z),
				Vector2(corners[2].y, corners[2].z),
				Vector2(corners[3].y, corners[3].z))

	tool.generate_normals()
	return tool.commit()


## Ein Punkt im Segel. [param along] laeuft vom Hals zum Piek, [param across]
## von der Rah zum Liek.
func _sail_point(
	half: float, clew: Vector3, belly: float, along: float, across: float
) -> Vector3:
	var z := lerpf(-half, half, along)
	# Anteil der Strecke Hals - Schothorn - Piek, an der dieser Schnitt liegt.
	var split := (clew.z + half) / (half * 2.0)
	var width: float = 0.0
	if along <= split:
		width = clew.y * (along / maxf(split, 0.0001))
	else:
		width = clew.y * ((1.0 - along) / maxf(1.0 - split, 0.0001))

	# Bauch: null an Rah, Hals und Piek, am tiefsten in der Mitte des Tuchs.
	var bulge := belly * sin(PI * across) * sin(PI * along)
	return Vector3(bulge, width * across, z)


## Wanten - die Taue, mit denen der Mast seitlich gehalten wird.
##
## Sie kosten fast nichts und tragen den Umriss erheblich: Ohne sie steht ein
## Mast wie ein Besenstiel im Deck (Regel A11 - der Umriss macht den Ernst).
func _add_shrouds(index: int, z: float, head: Vector3) -> void:
	for side: int in [1, -1]:
		for offset: float in SHROUD_OFFSETS:
			_add_rope("Shroud%d_%d_%d" % [index, side, int(offset * 100.0)],
				_rail_point(z + offset, side), head)


## Stagen - die Taue, die die Masten nach vorn und achtern halten.
##
## Jeder Mast steht mit seinem Stag auf dem Fuss des naechsten vor ihm; der
## vorderste haelt sich an [param stem_head] fest, dem Kopf des Vorstevens.
## Der hinterste bekommt zusaetzlich ein Backstag nach [param backstay_foot].
## So ist es an Bord auch, und der Vorteil dabei ist nicht die Genauigkeit,
## sondern der Umriss: Die schraegen Linien fuellen die Luecken zwischen den
## Segeln und machen aus drei einzelnen Masten ein Rigg.
func _add_stays(stem_head: Vector3, backstay_foot: Vector3) -> void:
	var count := masts().size()
	for i in count:
		var anchor := stem_head
		if i > 0:
			var ahead := _mast_foot(i - 1)
			anchor = Vector3(0.0, ahead.y + bulwark(), ahead.z)
		_add_rope("Stay%d" % i, anchor, _mast_head(i))

	# Ohne das Backstag zoege das Rigg das Achterschiff optisch nach vorn.
	if count > 0:
		_add_rope("Backstay", backstay_foot, _mast_head(count - 1))


## Die Flagge an einem Masttopp.
func _add_flag(head: Vector3) -> void:
	var flag := Flag.new()
	flag.name = "Flag"
	# Knapp ueber den Topp, damit sie nicht im Rundholz steckt.
	flag.position = head + Vector3(0.0, 0.22, 0.0)
	add_child(flag)


# --- Beschlaege ------------------------------------------------------------

## Eine Ladeluke: Suellrand und Grating, mittschiffs auf dem Deck.
##
## Ohne sie ist das Deck in der Aufsicht eine leere braune Flaeche - und die
## Aufsicht ist genau der Blick, den man im Hafen und beim Entern hat.
func _add_hatch(z: float, width: float, length: float) -> void:
	var deck := _deck_at(z)

	var coaming := BoxMesh.new()
	coaming.size = Vector3(width, 0.16, length)
	var frame := MeshInstance3D.new()
	frame.name = "Hatch"
	frame.mesh = coaming
	frame.material_override = _solid(Palette.TIMBER)
	frame.position = Vector3(0.0, deck + 0.07, z)
	add_child(frame)

	var cover := BoxMesh.new()
	cover.size = Vector3(width - 0.14, 0.06, length - 0.14)
	var grating := MeshInstance3D.new()
	grating.name = "Grating"
	grating.mesh = cover
	grating.material_override = _solid(Palette.TAR)
	grating.position = Vector3(0.0, deck + 0.16, z)
	add_child(grating)


## Das Ankerspill: die Winde, mit der der Anker gehievt wird.
##
## Sie gehoert zum Anker wie der Anker zum Bug - eines ohne das andere sieht
## aus wie vergessen.
func _add_windlass(z: float) -> void:
	var deck := _deck_at(z)

	var drum := CylinderMesh.new()
	drum.top_radius = 0.085
	drum.bottom_radius = 0.085
	drum.height = 0.72
	drum.radial_segments = 7
	drum.rings = 1
	var barrel := MeshInstance3D.new()
	barrel.name = "Windlass"
	barrel.mesh = drum
	barrel.material_override = _solid(Palette.TIMBER)
	# Die Welle liegt quer zum Schiff.
	barrel.transform = Transform3D(
		_basis_from_up(Vector3.RIGHT), Vector3(0.0, deck + 0.26, z))
	add_child(barrel)

	for side: int in [1, -1]:
		var stand := BoxMesh.new()
		stand.size = Vector3(0.10, 0.40, 0.18)
		var post := MeshInstance3D.new()
		post.name = "WindlassPost_%s" % _side_tag(side)
		post.mesh = stand
		post.material_override = _solid(Palette.TAR)
		post.position = Vector3(float(side) * 0.42, deck + 0.20, z)
		add_child(post)


## Ein Buganker, aussenbords an der Wange.
##
## Gebaut aus Rundhoelzern statt aus einem Mesh: Ein Stockanker ist ein Schaft,
## ein Querholz und zwei Arme, und genau so viele Zylinder sind es dann auch.
## Er sagt aus jeder Entfernung, dass das ein Schiff ist und keine Kiste mit
## Masten.
func _add_anchor(z: float, side: int) -> void:
	var hull_x := _rail_half_beam_at(z)

	var anchor := Node3D.new()
	anchor.name = "Anchor_%s" % _side_tag(side)
	# Aussen an der Bordwand, knapp unter der Reling, leicht angelegt. Die
	# Drehung ist keine um die Hochachse und damit kein Kurs (Regel B7).
	anchor.position = Vector3(
		(hull_x + 0.09) * float(side), _deck_at(z) - 0.14, z)
	anchor.rotation_degrees = Vector3(8.0, 0.0, -7.0 * float(side))
	add_child(anchor)

	var shank := CylinderMesh.new()
	shank.top_radius = 0.032
	shank.bottom_radius = 0.038
	shank.height = 0.94
	shank.radial_segments = 5
	shank.rings = 1
	var spine := MeshInstance3D.new()
	spine.name = "Shank"
	spine.mesh = shank
	spine.material_override = _solid(Palette.IRON)
	anchor.add_child(spine)

	# Das Querholz sitzt oben und liegt laengsschiffs - so legt sich der Anker
	# an der Bordwand flach an, statt quer abzustehen.
	var bar := CylinderMesh.new()
	bar.top_radius = 0.026
	bar.bottom_radius = 0.026
	bar.height = 0.62
	bar.radial_segments = 5
	bar.rings = 1
	var stock := MeshInstance3D.new()
	stock.name = "Stock"
	stock.mesh = bar
	stock.material_override = _solid(Palette.TIMBER)
	stock.transform = Transform3D(
		_basis_from_up(Vector3.BACK), Vector3(0.0, 0.38, 0.0))
	anchor.add_child(stock)

	# Die beiden Arme steigen vom Kreuz aus schraeg nach oben, an ihren Enden
	# sitzen die Flunken.
	var crown := Vector3(0.0, -0.47, 0.0)
	for arm_side: int in [1, -1]:
		var lift := Vector3(0.0, 0.56, float(arm_side) * 0.83).normalized()

		var limb := CylinderMesh.new()
		limb.top_radius = 0.026
		limb.bottom_radius = 0.032
		limb.height = 0.44
		limb.radial_segments = 5
		limb.rings = 1
		var arm := MeshInstance3D.new()
		arm.name = "Arm_%d" % arm_side
		arm.mesh = limb
		arm.material_override = _solid(Palette.IRON)
		arm.transform = Transform3D(_basis_from_up(lift), crown + lift * 0.22)
		anchor.add_child(arm)

		var blade := BoxMesh.new()
		blade.size = Vector3(0.05, 0.20, 0.17)
		var fluke := MeshInstance3D.new()
		fluke.name = "Fluke_%d" % arm_side
		fluke.mesh = blade
		fluke.material_override = _solid(Palette.IRON)
		fluke.transform = Transform3D(_basis_from_up(lift), crown + lift * 0.46)
		anchor.add_child(fluke)


## Drehbassen auf der Reling, je eine pro Seite an jeder Laengsposition.
##
## Zaehlt als Bewaffnung: Zwei Positionen sind vier Rohre.
func _add_swivels(positions: Array) -> void:
	for side: int in [1, -1]:
		for z: float in positions:
			var rail := _rail_point(z, side)
			var tag := "%s%d" % [_side_tag(side), int(absf(z) * 100.0)]

			var stock := CylinderMesh.new()
			stock.top_radius = 0.026
			stock.bottom_radius = 0.034
			stock.height = 0.20
			stock.radial_segments = 5
			stock.rings = 1
			var post := MeshInstance3D.new()
			post.name = "SwivelPost_%s" % tag
			post.mesh = stock
			post.material_override = _solid(Palette.TIMBER)
			post.position = rail + Vector3(0.0, 0.10, 0.0)
			add_child(post)

			# Das Rohr zeigt nach aussen und ein wenig nach oben.
			var aim := Vector3(float(side) * 0.94, 0.34, 0.0).normalized()
			var tube := CylinderMesh.new()
			tube.top_radius = 0.028
			tube.bottom_radius = 0.040
			tube.height = 0.42
			tube.radial_segments = 6
			tube.rings = 1
			var barrel := MeshInstance3D.new()
			barrel.name = "Swivel_%s" % tag
			barrel.mesh = tube
			barrel.material_override = _solid(Palette.IRON)
			barrel.transform = Transform3D(
				_basis_from_up(aim), rail + Vector3(0.0, 0.21, 0.0) + aim * 0.10)
			add_child(barrel)
			_gun_count += 1


## Eine Laterne an einem Eisenbuegel.
##
## [param at] ist der Fuss des Buegels - in der Regel ein Punkt auf einem
## Handlauf -, [param rise] wie hoch die Laterne darueber haengt. Ob sie
## brennt, entscheidet nicht das Modell, sondern [Ship] nach der Sicht.
func _add_lantern(lantern_name: String, at: Vector3, rise: float) -> Lantern:
	var post := CylinderMesh.new()
	post.top_radius = 0.016
	post.bottom_radius = 0.016
	post.height = rise
	post.radial_segments = 4
	post.rings = 1
	var bracket := MeshInstance3D.new()
	bracket.name = "%sBracket" % lantern_name
	bracket.mesh = post
	bracket.material_override = _solid(Palette.IRON)
	bracket.position = at + Vector3(0.0, rise * 0.5, 0.0)
	add_child(bracket)

	var lantern := Lantern.new()
	lantern.name = lantern_name
	lantern.position = at + Vector3(0.0, rise, 0.0)
	add_child(lantern)
	return lantern


# --- Werkzeug --------------------------------------------------------------

## Haengt ein fertig gerechnetes Mesh als Kind ein.
##
## Ohne material_override: Die Meshes aus [HullMesh] bringen je Flaeche ihr
## eigenes Material mit, und ein Override wuerde beide mit demselben
## uebermalen - Deck und Aussenhaut haetten dann dieselbe Plankenrichtung.
func _add_mesh(node_name: String, mesh: ArrayMesh) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	add_child(node)


## Ein stehendes Tau zwischen zwei Punkten.
func _add_rope(rope_name: String, from: Vector3, to: Vector3) -> void:
	var rope := CylinderMesh.new()
	rope.top_radius = ROPE_RADIUS
	rope.bottom_radius = ROPE_RADIUS
	rope.height = from.distance_to(to)
	rope.radial_segments = 3
	rope.rings = 1

	var node := MeshInstance3D.new()
	node.name = rope_name
	node.mesh = rope
	node.material_override = _solid(Palette.TAR)
	node.transform = Transform3D(
		_basis_from_up((to - from).normalized()), (to + from) * 0.5)
	add_child(node)


## Achsenkreuz, dessen y-Achse auf [param up] zeigt.
##
## Zylindermeshes in Godot stehen auf ihrer lokalen y-Achse. Wer ein Rundholz
## schraeg stellen will, dreht also nicht in Winkeln herum, sondern baut sich
## die Basis direkt - das spart die Frage, in welcher Reihenfolge Euler-Winkel
## angewandt werden.
func _basis_from_up(up: Vector3) -> Basis:
	var reference := Vector3.RIGHT
	if absf(up.dot(reference)) > 0.9:
		reference = Vector3.FORWARD
	var right := reference.cross(up).normalized()
	return Basis(right, up, right.cross(up).normalized())


## Einfarbiges Material aus der Palette.
func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat


## Segeltuch: beidseitig sichtbar, und die Sonne scheint hindurch.
##
## backlight statt emission - ein Segel leuchtet nicht von selbst, es laesst
## Licht durch. Der Unterschied faellt genau dann auf, wenn man gegen die Sonne
## segelt, und das ist die halbe Zeit.
func _canvas_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.94
	mat.backlight_enabled = true
	mat.backlight = Palette.CANVAS_SHADE
	# Das Tuch wirft Schatten, faengt aber keine.
	#
	# Gemessen, nicht geraten: Ueber jedem Segel lag ein feines Karomuster.
	# Eine Aufnahme mit abgeschaltetem Schattenwurf zeigte, dass es der
	# Eigenschatten war - eine Flaeche ohne Dicke beschattet in der
	# Schattenkarte sich selbst. Den Wurf abzuschalten nahm dem Schiff aber die
	# Segelschatten auf Deck und machte es flach. Nur das Empfangen abzuschalten
	# behebt beides; dass ein Segel das andere nicht mehr abschattet, faellt bei
	# hellem Tuch nicht auf und passt zu Regel A11.
	mat.disable_receive_shadows = true
	ShipTextures.apply(mat, ShipTextures.canvas())
	return mat


## "stb" oder "bb" fuer Knotennamen.
func _side_tag(side: int) -> String:
	return "stb" if side > 0 else "bb"
