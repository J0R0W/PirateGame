## Eine Kugel auf ihrem Weg zum Ziel - reine Darstellung.
##
## Der Ausgang des Schusses steht schon fest, bevor sie startet (siehe
## [Gunnery]). Diese Klasse zeigt ihn nur: Sie fliegt eine Wurfparabel zu dem
## Punkt, den [Shot] vorgibt, und hinterlaesst dort eine Fontaene oder eine
## Rauchwolke.
##
## Der Bogen ist deutlich hoeher als physikalisch richtig. Eine flach fliegende
## Kugel ist aus der Verfolgerkamera unsichtbar - Regel A1 zaehlt mehr als
## Ballistik.
class_name CannonBall
extends Node3D

## Kugelradius in Metern. Grob viermal uebertrieben, sonst sieht man nichts.
const BALL_RADIUS: float = 0.45
## Flugzeit fuer die volle Schussweite, in Sekunden.
const FLIGHT_SECONDS: float = 1.4
## Scheitelhoehe der Bahn, als Anteil der Schussweite.
##
## Deutlich hoeher als physikalisch richtig - eine flach fliegende Kugel ist aus
## der Verfolgerkamera unsichtbar. Aber auch nicht zu hoch: Mit 0.09 stand die
## Salve auf 180 Metern doppelt so hoch wie der Masttopp des Gegners und sah aus
## wie Moerserfeuer.
const ARC_HEIGHT: float = 0.05
## Kleinster Bogen, damit auch ein Nahschuss sichtbar steigt.
const MIN_ARC: float = 2.5

## Wie lange eine Wolke steht, in Sekunden.
const PUFF_SECONDS: float = 1.2
## Auf das Wievielfache sie dabei waechst.
const PUFF_GROWTH: float = 3.0
## Deckkraft frischer Wolken.
##
## Der erste Entwurf war undurchsichtig und mass fast zwei Meter - aus 22
## Metern Kameraabstand verschwand das eigene Schiff hinter der eigenen
## Breitseite. Pulverdampf soll das Bild wuerzen, nicht ersetzen.
const PUFF_ALPHA: float = 0.5
## Radius des Muendungsrauchs in Metern.
const MUZZLE_RADIUS: float = 0.9
## Und der Einschlagswolke am getroffenen Rumpf.
const IMPACT_RADIUS: float = 1.1
## Fontaene eines Fehlschusses: Fuss und Hoehe in Metern. Groesser und
## deckender als Pulverdampf - eine Wassersaeule auf 400 Metern muss man noch
## sehen, sonst weiss man nicht, ob man kurz oder weit geschossen hat.
const SPLASH_RADIUS: float = 1.4
const SPLASH_HEIGHT: float = 9.0
const SPLASH_ALPHA: float = 0.75

var _from: Vector3
var _to: Vector3
var _arc: float = 0.0
var _duration: float = 1.0
var _elapsed: float = 0.0
var _splash: bool = true


## Schickt eine Kugel los. [param splash] entscheidet, was am Ende steht:
## eine Fontaene (Fehlschuss) oder eine Rauchwolke am Rumpf (Treffer).
func launch(from: Vector3, to: Vector3, splash: bool) -> void:
	_from = from
	_to = to
	_splash = splash
	global_position = from

	var distance := from.distance_to(to)
	_duration = flight_time(distance)
	_arc = maxf(distance * ARC_HEIGHT, MIN_ARC)

	add_child(_ball_mesh())


## Wie lange eine Kugel auf diese Entfernung braucht.
##
## Auch der Schaden wartet darauf: Er faellt erst, wenn die Kugel ankommt -
## sonst sinkt ein Gegner, waehrend die Breitseite noch in der Luft steht.
static func flight_time(distance: float) -> float:
	return maxf(FLIGHT_SECONDS * distance / Gunnery.MAX_RANGE, 0.25)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / _duration
	if t >= 1.0:
		_impact()
		return

	# Gerade Strecke plus Parabel, die an beiden Enden null ist.
	global_position = _from.lerp(_to, t) + Vector3.UP * (_arc * 4.0 * t * (1.0 - t))


func _impact() -> void:
	var world := get_parent()
	if world != null:
		if _splash:
			splash(world, _to)
		else:
			puff(world, _to, IMPACT_RADIUS, Palette.SMOKE)
	queue_free()


func _ball_mesh() -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = BALL_RADIUS
	mesh.height = BALL_RADIUS * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3

	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _material(Palette.IRON, false)
	return view


## Eine Wolke, die aufgeht und verschwindet. Auch der Muendungsrauch benutzt sie.
static func puff(parent: Node, at: Vector3, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	_fade_in_place(parent, mesh, at, color, Vector3.ONE * PUFF_GROWTH, PUFF_ALPHA)


## Die Wassersaeule eines Fehlschusses. Steht senkrecht und wird nach oben hin
## breiter - eine Kugel im Wasser sieht anders aus als Rauch an einer Bordwand.
static func splash(parent: Node, at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = SPLASH_RADIUS * 1.6
	mesh.bottom_radius = SPLASH_RADIUS
	mesh.height = SPLASH_HEIGHT
	mesh.radial_segments = 8
	mesh.rings = 1
	_fade_in_place(
		parent, mesh, Vector3(at.x, SPLASH_HEIGHT * 0.4, at.z), Palette.FOAM,
		Vector3(1.5, 1.0, 1.5), SPLASH_ALPHA
	)


static func _fade_in_place(
	parent: Node, mesh: Mesh, at: Vector3, color: Color, grown: Vector3, alpha: float
) -> void:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _material(Palette.fade(color, alpha), true)
	parent.add_child(view)
	view.global_position = at

	var tween := view.create_tween()
	tween.tween_property(view, "scale", grown, PUFF_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(view, "transparency", 1.0, PUFF_SECONDS)
	tween.tween_callback(view.queue_free)


static func _material(color: Color, soft: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if soft:
		# Rauch und Gischt werden nicht beleuchtet - sonst liegt die Wolke im
		# Schatten des eigenen Segels und verschwindet gegen die See.
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		material.roughness = 0.9
	return material
