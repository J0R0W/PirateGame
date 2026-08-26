## Baut das Ozean-Mesh als radiales Netz um den Betrachter.
##
## Warum nicht einfach eine grosse Plane: Die Wellen brauchen nah rund vier
## Meter Aufloesung. Eine gleichmaessige Plane mit vier Metern ueber fuenf
## Kilometer haette anderthalb Millionen Vertices.
##
## Vorher lagen deshalb zwei Flaechen uebereinander - eine feine Wellenplane
## und eine grosse flache "Fernsee" darunter. Das erzeugte Z-Fighting mit dem
## flachen Kuestengelaende: Sandbaenke schienen ueber dem Wasser zu schweben.
##
## Das radiale Netz loest beides. Ringabstand und Bogenlaenge wachsen mit dem
## Radius, die Zellen bleiben dabei ungefaehr quadratisch - nah fein, fern grob,
## und ohne Naht dazwischen.
class_name OceanMesh
extends RefCounted

## Speichen. Bestimmt die Aufloesung entlang des Umfangs.
const SPOKES: int = 128
## Ringe zwischen innerem und aeusserem Radius.
const RINGS: int = 160
## Innerster Ring. Darunter schliesst ein Faecher zum Mittelpunkt.
const INNER_RADIUS: float = 3.0
## Bis hierhin reicht das Wasser. Weiter draussen ist ohnehin nur Dunst.
const OUTER_RADIUS: float = 5000.0


static func build() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	# Mittelpunkt zuerst, damit der innerste Faecher ihn ansprechen kann.
	vertices.append(Vector3.ZERO)

	var growth: float = pow(OUTER_RADIUS / INNER_RADIUS, 1.0 / float(RINGS))
	for ring in RINGS + 1:
		var radius: float = INNER_RADIUS * pow(growth, float(ring))
		for spoke in SPOKES:
			var angle := TAU * float(spoke) / float(SPOKES)
			vertices.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))

	# Faecher vom Mittelpunkt zum innersten Ring.
	for spoke in SPOKES:
		var a := 1 + spoke
		var b := 1 + (spoke + 1) % SPOKES
		indices.append_array([0, a, b])

	# Quads zwischen benachbarten Ringen.
	for ring in RINGS:
		var inner_base := 1 + ring * SPOKES
		var outer_base := inner_base + SPOKES
		for spoke in SPOKES:
			var next := (spoke + 1) % SPOKES
			var a := inner_base + spoke
			var b := inner_base + next
			var c := outer_base + spoke
			var d := outer_base + next
			indices.append_array([a, c, b, b, c, d])

	# Normalen kommen aus dem Shader, der die Wellen kennt. Hier reicht "oben".
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Ohne eigene AABB verschwindet das Meer, sobald der Mittelpunkt aus dem
	# Bild laeuft - Godot kennt die Wellenauslenkung des Shaders nicht.
	mesh.custom_aabb = AABB(
		Vector3(-OUTER_RADIUS, -50.0, -OUTER_RADIUS),
		Vector3(OUTER_RADIUS * 2.0, 100.0, OUTER_RADIUS * 2.0)
	)
	return mesh
