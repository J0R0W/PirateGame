## Eine Schiffslaterne: Gehaeuse, Glas und das Licht darin.
##
## Der erste Beschlag, der etwas [i]tut[/i], statt nur dazustehen. Bei
## schlechter Sicht - Nacht, Regen, Sturm - laesst der Kapitaen sie anzuenden
## (siehe [method Ship._update_lanterns] und [method Skylight.lanterns_lit]);
## bei Tag ist sie ein kaltes Glas in einem Eisenrahmen.
##
## Sie ist ein eigener Knotentyp wie [Rig] und [Flag], damit [Ship] sie am
## Typ findet und nicht an einem Namen: Ein Modell darf so viele davon
## aufhaengen, wie es will, und nennen, wie es will.
##
## Das Licht ist ein [OmniLight3D] ohne Schatten. Ein halbes Dutzend Schiffe
## in Sichtweite sind ein halbes Dutzend Lichter; in Forward+ kostet das
## nichts, solange keines davon eine Schattenkarte braucht.
class_name Lantern
extends Node3D

## Reichweite des Lichts in Metern. Weit genug, dass es Deck und Segel
## streift, nicht so weit, dass das Wasser um das Schiff leuchtet.
const RANGE: float = 9.0
## Staerke des Lichts, wenn es brennt.
const ENERGY: float = 2.6
## Wie hell das Glas selbst leuchtet. Das ist der Teil, den man aus der
## Ferne sieht - das Licht auf dem Deck sieht man erst von nahem.
const GLOW: float = 4.0
## Sekunden, bis eine Laterne ganz brennt oder ganz aus ist.
const FADE: float = 1.4

## Masse des Glases: Radius und Hoehe.
const GLASS_RADIUS: float = 0.055
const GLASS_HEIGHT: float = 0.15
## Kappe und Boden aus Eisen.
const CAP: Vector3 = Vector3(0.15, 0.03, 0.15)

var _built: bool = false
var _lit: bool = false
var _light: OmniLight3D = null
var _glass: StandardMaterial3D = null
var _fade: Tween = null


func _ready() -> void:
	build()


## Baut Gehaeuse, Glas und Licht. Ausdruecklich aufrufbar wie beim Modell.
func build() -> void:
	if _built:
		return
	_built = true

	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Palette.GLASS
	_glass.roughness = 0.35
	_glass.emission_enabled = true
	_glass.emission = Palette.LANTERN
	_glass.emission_energy_multiplier = 0.0

	var pane := CylinderMesh.new()
	pane.top_radius = GLASS_RADIUS
	pane.bottom_radius = GLASS_RADIUS
	pane.height = GLASS_HEIGHT
	pane.radial_segments = 6
	pane.rings = 1
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	glass.mesh = pane
	glass.material_override = _glass
	glass.position = Vector3(0.0, GLASS_HEIGHT * 0.5, 0.0)
	add_child(glass)

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Palette.IRON
	iron.roughness = 0.7
	for part: Array in [["Cap", GLASS_HEIGHT + CAP.y * 0.5], ["Base", -CAP.y * 0.5]]:
		var plate := BoxMesh.new()
		plate.size = CAP
		var node := MeshInstance3D.new()
		node.name = part[0]
		node.mesh = plate
		node.material_override = iron
		node.position = Vector3(0.0, part[1], 0.0)
		add_child(node)

	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.omni_range = RANGE
	_light.omni_attenuation = 1.3
	_light.light_color = Palette.LANTERN
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, GLASS_HEIGHT * 0.5, 0.0)
	add_child(_light)


## Brennt sie?
func is_lit() -> bool:
	return _lit


## Anzuenden oder loeschen. [param instant] ueberspringt das Aufflackern -
## fuer Aufnahmen und fuer ein Schiff, das schon bei Nacht gesetzt wird.
func set_lit(on: bool, instant: bool = false) -> void:
	build()
	if on == _lit:
		return
	_lit = on

	if _fade != null:
		_fade.kill()
	var energy := ENERGY if on else 0.0
	var glow := GLOW if on else 0.0
	if instant or not is_inside_tree():
		_light.light_energy = energy
		_glass.emission_energy_multiplier = glow
		return

	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(_light, "light_energy", energy, FADE)
	_fade.tween_property(_glass, "emission_energy_multiplier", glow, FADE)
