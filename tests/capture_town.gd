## Zeigt eine Siedlung aus der Naehe.
##
## Laufen lassen mit:
##   godot --path . res://tests/capture_town.tscn
##
## Aus der Verfolgerkamera sind Haeuser dreissig Pixel gross - ob sie auf dem
## Hang stehen oder darueber schweben, sieht man erst von hier.
extends Node

const OUT_DIR: String = "user://captures"
const SEED: int = 42

var _town: TownData


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	GameState.new_campaign("Kapitaen", SEED)

	var packed: PackedScene = load("res://modes/sailing/sailing_mode.tscn")
	var mode: Node3D = packed.instantiate()
	add_child(mode)
	await get_tree().process_frame

	var ship: Ship = mode.get_node("PlayerShip")
	_town = _pick_town()
	print("  Siedlung: %s (%s), %d Haeuser erwartet" % [
		_town.town_name, _town.tier_name(),
		TownMarker.HOUSE_COUNT[clampi(_town.size_tier, 0, 2)],
	])

	# Das Schiff dient nur als Anker fuer Gelaende- und Stadtstreaming.
	var anchor := WorldData.anchorage_for(_town)
	ship.global_position = Vector3(anchor.x, 0.0, anchor.y)
	await get_tree().create_timer(3.0).timeout

	var camera: Camera3D = mode.get_node("CameraRig/Camera3D")
	camera.get_parent().set_process(false)
	camera.set_as_top_level(true)

	await _view(camera, "20_stadt_von_see", 210.0, 40.0)
	await _view(camera, "21_stadt_von_nah", 95.0, 32.0)
	await _view(camera, "22_stadt_von_oben", 130.0, 150.0)

	get_tree().quit(0)


## Die groesste Stadt - dort stehen die meisten Haeuser.
func _pick_town() -> TownData:
	var best: TownData = WorldData.towns[0]
	for town: TownData in WorldData.towns:
		if town.size_tier > best.size_tier:
			best = town
	return best


## Blickt aus [param distance] Metern Entfernung und [param height] Metern
## Hoehe auf die Stadtmitte.
func _view(camera: Camera3D, shot_name: String, distance: float, height: float) -> void:
	var island: IslandData = WorldData.islands[_town.island_id]
	var seaward := (_town.position - island.center).normalized()
	var eye := _town.position + seaward * distance
	var ground := WorldData.terrain_y(_town.position.x, _town.position.y)

	camera.global_position = Vector3(eye.x, ground + height, eye.y)
	camera.look_at(Vector3(_town.position.x, ground + 6.0, _town.position.y), Vector3.UP)

	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("%s/%s.png" % [OUT_DIR, shot_name])
	print("  %-20s  Abstand %4.0f m, Hoehe %3.0f m ueber Gelaende %.1f m   [%s]" % [
		shot_name, distance, height, ground, "ok" if error == OK else "FEHLER %d" % error,
	])
