## Haelt die Ozean-Plane unter dem Spieler und versorgt den Shader mit der Zeit.
##
## Die Plane wandert mit, die Wellen aber nicht - der Shader rechnet in
## Weltkoordinaten. Gesnappt wird, damit die Vertices nicht dauernd zwischen
## Rasterpunkten wandern und dabei flimmern.
class_name Ocean
extends MeshInstance3D

## Wem folgt das Meer? Wird von der Modus-Szene gesetzt.
var target: Node3D

## Rasterweite des Nachfuehrens in Metern.
const SNAP: float = 8.0

## Staerke des Gitternetzes, wenn es an ist.
const GRID_STRENGTH: float = 0.07

## Weltfestes Gitternetz auf dem Wasser.
##
## Lernhilfe aus M1: Es macht Fahrt und Drift sichtbar, wo eine gleichfoermige
## Wasserflaeche beides verschluckt. Es ist zugleich der buchstaebliche Teil des
## Schachbrettmusters, das die See derzeit ueberzieht - mit der Ueberarbeitung
## der Meeresoptik faellt es weg (siehe KONZEPT.md, Abschnitt 11). Im
## Debug-Menue (F3) laesst es sich abschalten, um zu sehen, wieviel davon auf
## das Gitter geht und wieviel auf die Wellenformel selbst.
##
## Die Einstellung steht hier und nicht im Debug-Menue, weil der Shader den
## Vorgabewert einer Uniform nicht herausgibt: get_shader_parameter() liefert
## null, solange niemand sie ausdruecklich gesetzt hat.
@export var show_grid: bool = true:
	set(value):
		show_grid = value
		_apply_grid()


@onready var _material: ShaderMaterial = material_override as ShaderMaterial


func _ready() -> void:
	mesh = OceanMesh.build()
	_apply_grid()


func _apply_grid() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("grid_strength", GRID_STRENGTH if show_grid else 0.0)


func _process(_delta: float) -> void:
	# Dieselbe Uhr wie OceanWaves.height_at() - sonst passen Bild und Physik
	# nicht zusammen.
	if _material != null:
		_material.set_shader_parameter("wave_time", OceanWaves.time_now())

	if target == null:
		return
	global_position = Vector3(
		snappedf(target.global_position.x, SNAP),
		0.0,
		snappedf(target.global_position.z, SNAP)
	)
