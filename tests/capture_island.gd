## Diagnose: eine Insel aus der Naehe, Schicht fuer Schicht abgeschaltet.
##
##   godot --path . res://tests/capture_island.tscn
##
## Zeigt dasselbe Bild vier Mal: vollstaendig, ohne Dunst, ohne Wasser und als
## Drahtgitter. Damit laesst sich unterscheiden, ob ein Darstellungsfehler vom
## Gelaende, vom Wasser oder von der Atmosphaere kommt.
extends Node

const OUT_DIR: String = "user://captures"

var _mode: Node3D
var _camera: Camera3D
var _environment: Environment


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	WorldData.generate(1)

	var packed: PackedScene = load("res://modes/sailing/sailing_mode.tscn")
	_mode = packed.instantiate()
	add_child(_mode)
	await get_tree().process_frame

	var ship: Node3D = _mode.get_node("PlayerShip")
	ship.set("player_controlled", false)
	ship.set_physics_process(false)

	# Dicht an die naechste Kueste heranfahren, damit das Gelaende gross im
	# Bild steht - aus 1,5 km sieht man Loecher nicht.
	var town: TownData = _nearest_town(Vector2(ship.global_position.x, ship.global_position.z))
	var approach := _water_near(town.position, 420.0)
	ship.global_position = Vector3(approach.x, 0.0, approach.y)
	ship.set("speed", 0.0)

	_camera = _mode.get_node("CameraRig/Camera3D")
	var rig: Node3D = _mode.get_node("CameraRig")
	rig.set_process(false)
	rig.global_position = Vector3(approach.x, 55.0, approach.y)
	rig.look_at(Vector3(town.position.x, 40.0, town.position.y))

	_environment = (_mode.get_node("WorldEnvironment") as WorldEnvironment).environment
	var terrain: Node3D = _mode.get_node("Terrain")
	var ocean: Node3D = _mode.get_node("Ocean")
	var hud: Control = _mode.get_node("HUD")
	hud.visible = false

	# Chunks stehen lassen, bis alles geladen ist.
	await _wait(3.0)
	print("  Chunks: %d   Kamera bei %s" % [terrain.loaded_count(), rig.global_position])

	await _shot("isl_1_normal")

	_environment.fog_enabled = false
	await _wait(0.3)
	await _shot("isl_2_ohne_dunst")

	ocean.visible = false
	await _wait(0.3)
	await _shot("isl_3_ohne_wasser")

	get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	await _wait(0.3)
	await _shot("isl_4_drahtgitter")

	get_tree().quit(0)


func _nearest_town(from: Vector2) -> TownData:
	var best: TownData = WorldData.towns[0]
	var best_distance := INF
	for town: TownData in WorldData.towns:
		var d := town.position.distance_squared_to(from)
		if d < best_distance:
			best_distance = d
			best = town
	return best


func _water_near(target: Vector2, distance: float) -> Vector2:
	for step in 36:
		var angle := TAU * float(step) / 36.0
		var candidate := target + Vector2(cos(angle), sin(angle)) * distance
		if not WorldData.is_land(candidate.x, candidate.y):
			return candidate
	return target


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("  %-22s %s" % [shot_name, "ok" if error == OK else "FEHLER %d" % error])
