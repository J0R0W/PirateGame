## Eine Flagge am Masttopp, die im Wind steht.
##
## Sie ist die einzige Stelle am Schiff, die den Wind [i]zeigt[/i], statt ihn
## nur zu erleiden - Regel A8: Systeme sichtbar machen, nicht erklaeren. Wer
## eine fremde Flagge sieht, liest daran zweierlei ab: unter welcher Krone der
## andere faehrt, und woher es weht.
##
## [b]Die Ausrichtung laeuft ueber global_basis, nicht ueber eine Drehung.[/b]
## Der Wind ist eine Weltrichtung; die Flagge haengt aber unter einem Schiff,
## das sich selbst dreht. Ueber die Weltbasis gesetzt, muss niemand den Kurs
## des Traegers herausrechnen - und die Regel gegen [code]rotation.y[/code]
## ausserhalb von ship.gd (B7) bleibt unberuehrt.
class_name Flag
extends Node3D

## Masse des Tuchs in Metern: Laenge im Wind, Hoehe am Stock.
const FLY: float = 1.15
const HOIST: float = 0.52
## Unterteilung in Laengsrichtung. Mehr Felder, mehr Welle.
const SEGMENTS: int = 7
## Tiefe der stehenden Welle im Tuch, am Ende am staerksten.
const RIPPLE: float = 0.16

## Ausschlag des Flatterns in Grad, um Hoch- und Laengsachse.
const FLUTTER_YAW: float = 6.0
const FLUTTER_ROLL: float = 4.5

var _phase: float = 0.0
var _cloth: MeshInstance3D = null
var _material: StandardMaterial3D = null


func _ready() -> void:
	build()


## Baut das Tuch. Wie beim Modell ausdruecklich aufrufbar, damit die Farbe
## gesetzt werden kann, bevor der Knoten im Baum haengt.
func build() -> void:
	if _cloth != null:
		return

	_material = StandardMaterial3D.new()
	# Die Nationsfarbe steht im Albedo, der Verlauf im Tuch in den Vertexfarben -
	# Godot multipliziert beides. So laesst sich die Flagge umfaerben, ohne das
	# Mesh neu zu bauen.
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Palette.IRON
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = 0.9
	_material.backlight_enabled = true
	_material.backlight = Palette.CANVAS_SHADE
	# Wie beim Segel: wirft Schatten, faengt keine. Eine Flaeche ohne Dicke
	# beschattet sich sonst selbst.
	_material.disable_receive_shadows = true
	# Dasselbe Tuch wie am Segel. Eine Flagge ist genaeht wie ein Segel, nur
	# kleiner - und die Naht ist das einzige, was eine einfarbige Flaeche
	# ueberhaupt als Stoff lesbar macht.
	ShipTextures.apply(_material, ShipTextures.canvas())

	_cloth = MeshInstance3D.new()
	_cloth.name = "Cloth"
	_cloth.mesh = _build_cloth()
	_cloth.material_override = _material
	_cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(_cloth)


## Setzt die Farbe der Flagge - in der Regel die der Nation.
func raise(color: Color) -> void:
	build()
	_material.albedo_color = color


## Richtet die Flagge in den Wind und laesst sie flattern.
func stream(wind_direction: float, wind_strength: float, delta: float) -> void:
	_phase += delta * (2.2 + wind_strength * 2.0)

	# Der Wind kommt AUS wind_direction - das Tuch steht in die Gegenrichtung.
	var lee := SailingMath.direction(wind_direction + PI)
	var along := Vector3(lee.x, 0.0, lee.y).normalized()
	var aim := Basis(along, Vector3.UP, along.cross(Vector3.UP))

	var flutter := Basis.from_euler(Vector3(
		sin(_phase * 1.7) * deg_to_rad(FLUTTER_ROLL),
		sin(_phase) * deg_to_rad(FLUTTER_YAW),
		0.0))

	# Die Skalierung des Traegers muss mit hinein: Eine Weltbasis enthaelt sie,
	# und wer sie beim Setzen weglaesst, nimmt sie dem Knoten weg. Klassen ohne
	# eigenes Modell werden ueber hull_scale vergroessert - die Fregatte haette
	# sonst als einziges Schiff eine Flagge in Originalgroesse getragen.
	var host := get_parent_node_3d()
	var host_scale := host.global_basis.get_scale() if host != null else Vector3.ONE
	global_basis = (aim * flutter).scaled(host_scale)


## Das Tuch: ein Band vom Stock (x = 0) in den Wind (x = FLY).
##
## Die Welle steht fest im Mesh und waechst zum fliegenden Ende hin. Bewegt
## wird nicht das Tuch, sondern der ganze Knoten - ein Mesh je Bild neu zu
## bauen waere fuer ein Dutzend Schiffe auf See verschwendet.
func _build_cloth() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Heller am Stock, dunkler im fliegenden Ende - das gibt dem Tuch Tiefe.
	# Die Nationsfarbe kommt darueber als Albedo, diese beiden Toene sind nur
	# der Verlauf.
	var at_staff := Palette.for_vertex(Palette.CANVAS)
	var at_fly := Palette.for_vertex(Palette.CANVAS_SHADE)

	for i in range(SEGMENTS):
		var a := float(i) / float(SEGMENTS)
		var b := float(i + 1) / float(SEGMENTS)
		var za := _ripple(a)
		var zb := _ripple(b)
		# Das Tuch haengt zum fliegenden Ende hin leicht durch.
		var sag_a := -HOIST * 0.10 * a
		var sag_b := -HOIST * 0.10 * b

		# UV in Metern wie ueberall am Schiff: U laengs des Tuchs, V ueber die
		# Hoehe - die Naht liegt damit waagerecht und laeuft in den Wind.
		HullMesh.quad(tool,
			Vector3(a * FLY, sag_a - HOIST * 0.5, za),
			Vector3(a * FLY, sag_a + HOIST * 0.5, za),
			Vector3(b * FLY, sag_b + HOIST * 0.5, zb),
			Vector3(b * FLY, sag_b - HOIST * 0.5, zb),
			at_staff.lerp(at_fly, a), 0, Vector3.BACK,
			Vector2(a * FLY, sag_a - HOIST * 0.5),
			Vector2(a * FLY, sag_a + HOIST * 0.5),
			Vector2(b * FLY, sag_b + HOIST * 0.5),
			Vector2(b * FLY, sag_b - HOIST * 0.5))

	tool.generate_normals()
	return tool.commit()


func _ripple(t: float) -> float:
	return sin(t * PI * 2.0) * RIPPLE * t
