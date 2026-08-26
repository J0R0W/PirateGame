## Laedt Gelaende-Chunks um den Spieler und entlaedt sie wieder.
##
## Ohne Streaming existierte die ganze 20-km-Welt gleichzeitig. Geladen wird
## nur, was in Sichtweite liegt UND Land enthaelt - ueber offener See uebernimmt
## der Ozean-Shader.
##
## Pro Frame wird nur ein kleines Budget gebaut: Das Meshen eines Chunks kostet
## rund tausend Auswertungen der Hoehenfunktion, alle auf einmal waeren ein
## sichtbarer Ruckler.
extends Node3D

## Sichtweite in Chunks. 5 decken rund 1,3 km ab. Das kostet wenig, weil nur
## Chunks mit Land ueberhaupt gebaut werden - bei 14 Prozent Landanteil bleibt
## von 121 Feldern nur ein Bruchteil uebrig.
@export var view_radius: int = 5
## Wieviele Chunks duerfen pro Frame entstehen?
@export var chunks_per_frame: int = 3
## Quads je Chunkkante.
@export var resolution: int = 32

var target: Node3D

var _material: StandardMaterial3D
var _loaded: Dictionary = {}
var _queue: Array[Vector2i] = []
var _center := Vector2i(9999, 9999)


func _ready() -> void:
	_material = StandardMaterial3D.new()
	# Farben stecken in den Vertices, nicht in Texturen.
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.92
	_material.metallic_specular = 0.15


func _process(_delta: float) -> void:
	if target == null or WorldData.generator == null:
		return

	var coord := WorldData.chunk_coord_at(target.global_position)
	if coord != _center:
		_center = coord
		_refresh_queue()
		_drop_distant()

	_build_budget()


## Sammelt fehlende Chunks in Sichtweite, die naechsten zuerst.
func _refresh_queue() -> void:
	_queue.clear()
	for dz in range(-view_radius, view_radius + 1):
		for dx in range(-view_radius, view_radius + 1):
			var coord := _center + Vector2i(dx, dz)
			if _loaded.has(coord):
				continue
			if not WorldData.generator.chunk_has_land(coord):
				continue
			_queue.append(coord)

	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - _center).length_squared() < (b - _center).length_squared()
	)


func _build_budget() -> void:
	var built := 0
	while built < chunks_per_frame and not _queue.is_empty():
		_build_chunk(_queue.pop_front())
		built += 1


func _build_chunk(coord: Vector2i) -> void:
	var mesh := TerrainChunk.build(
		WorldData.generator, coord, resolution, WorldData.TERRAIN_HEIGHT_SCALE
	)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	var origin := WorldData.generator.chunk_origin(coord)
	instance.position = Vector3(origin.x, 0.0, origin.y)
	add_child(instance)
	_loaded[coord] = instance


## Ein Chunk Puffer ueber der Sichtweite, damit an der Grenze nicht dauernd
## geladen und entladen wird.
func _drop_distant() -> void:
	var limit := view_radius + 1
	for coord: Vector2i in _loaded.keys():
		var offset := coord - _center
		if absi(offset.x) > limit or absi(offset.y) > limit:
			_loaded[coord].queue_free()
			_loaded.erase(coord)


func loaded_count() -> int:
	return _loaded.size()
