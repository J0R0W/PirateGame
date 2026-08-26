## Zeigt das Schiffsmodell aus mehreren Winkeln - Werkzeug fuer Modellarbeit.
##
##   godot --path . res://tests/capture_ship.tscn
##
## Bewusst ohne Spielszene: neutrale Beleuchtung, ruhige Wasserlinie, feste
## Kamerawinkel. Im Segelmodus verdeckt die Verfolgerkamera genau die Details,
## die man beim Modellieren beurteilen muss.
extends Node

const OUT_DIR: String = "user://captures"
## Winkel um die Hochachse und Hoehe der Kamera, je Aufnahme.
const VIEWS: Array[Dictionary] = [
	{"name": "ship_01_steuerbord", "yaw": 90.0, "pitch": 8.0, "distance": 18.0},
	{"name": "ship_02_bug", "yaw": 152.0, "pitch": 14.0, "distance": 17.0},
	{"name": "ship_03_heck", "yaw": 25.0, "pitch": 16.0, "distance": 17.0},
	{"name": "ship_04_oben", "yaw": 115.0, "pitch": 52.0, "distance": 20.0},
]

var _camera: Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	WorldData.generate(1)

	_build_stage()

	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var ship: Node3D = packed.instantiate()
	add_child(ship)
	# Ruhig stellen: kein Wellengang, keine Eingaben, feste Wasserlinie.
	ship.set("player_controlled", false)
	ship.set_physics_process(false)

	await get_tree().process_frame

	for view: Dictionary in VIEWS:
		_place_camera(view)
		await _wait(0.35)
		await _shot(view["name"])

	get_tree().quit(0)


func _build_stage() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -55.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 130.0, 0.0)
	fill.light_energy = 0.35
	add_child(fill)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.24, 0.31)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.65, 0.75)
	environment.ambient_light_energy = 0.5
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	# Wasserlinie als ruhige Flaeche - man muss sehen, was eintaucht.
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	water.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.30, 0.42, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = material
	add_child(water)

	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)


func _place_camera(view: Dictionary) -> void:
	var yaw: float = deg_to_rad(view["yaw"])
	var pitch: float = deg_to_rad(view["pitch"])
	var distance: float = view["distance"]
	var focus := Vector3(0.0, 2.2, 0.0)

	_camera.global_position = focus + Vector3(
		sin(yaw) * cos(pitch) * distance,
		sin(pitch) * distance,
		cos(yaw) * cos(pitch) * distance
	)
	_camera.look_at(focus)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("  %-22s %s" % [shot_name, "ok" if error == OK else "FEHLER %d" % error])
