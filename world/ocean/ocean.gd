## Haelt die Ozean-Plane unter dem Spieler und versorgt den Shader mit der Zeit.
##
## Die Plane wandert mit, die Wellen aber nicht - der Shader rechnet in
## Weltkoordinaten. Gesnappt wird, damit die Vertices nicht dauernd zwischen
## Rasterpunkten wandern und dabei flimmern.
extends MeshInstance3D

## Wem folgt das Meer? Wird von der Modus-Szene gesetzt.
var target: Node3D

## Rasterweite des Nachfuehrens in Metern.
const SNAP: float = 8.0

@onready var _material: ShaderMaterial = material_override as ShaderMaterial


func _ready() -> void:
	mesh = OceanMesh.build()


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
