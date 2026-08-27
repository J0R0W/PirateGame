## Rendert ein Seegefecht und legt Aufnahmen ab - Sichtpruefung fuer M4.
##
## Laufen lassen mit:
##   godot --path . res://tests/capture_battle.tscn
##
## Braucht ein echtes Fenster. Muendungsrauch, fliegende Kugeln und die
## Wassersaeulen eines Fehlschusses sind Geometrie, die erst beim Rendern
## entsteht - headless gibt es sie nicht. Und die Flagge im Masttopp ist die
## einzige Auskunft darueber, wem das fremde Segel gehoert: Ist sie zu klein
## oder in der falschen Farbe, faellt das nur im Bild auf.
extends Node

const OUT_DIR: String = "user://captures"
## Entfernung fuer die erste Aufnahme: ein fremdes Segel, gerade eben in
## Gefechtsreichweite. Weiter draussen zeigt weder Kamera noch HUD etwas an,
## und die Aufnahme waere ein Bild von leerer See.
const SIGHTING_RANGE: float = 540.0
## Und fuer das Gefecht selbst.
const FIGHTING_RANGE: float = 180.0

var _ship: Ship
var _camera_rig: Node3D
var _combat: NavalCombat
var _enemy: Ship
var _last_salvo: String = "-"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("Aufnahmen nach: ", ProjectSettings.globalize_path(OUT_DIR))

	var packed: PackedScene = load("res://modes/sailing/sailing_mode.tscn")
	var mode: Node = packed.instantiate()
	add_child(mode)
	await get_tree().process_frame
	_ship = mode.get_node("PlayerShip")
	_camera_rig = mode.get_node("CameraRig")
	_combat = mode.get_node("Combat")

	EventBus.broadside_landed.connect(_on_broadside)
	# Wind festnageln, sonst dreht er waehrend der Aufnahme weg.
	WorldData.set_wind(deg_to_rad(180.0), 1.0)

	var spot := _open_sea()
	_ship.global_position = Vector3(spot.x, 0.0, spot.y)
	_ship.set_heading(0.0)
	_camera_rig.snap()
	await _wait(2.0)

	_enemy = _summon(SIGHTING_RANGE)
	print("  Gegner: %s (%s)" % [_enemy.ship_name, _enemy.ship_class.display_name])
	await _wait(2.0)
	await _shot("01_segel_in_sicht")

	# Laengsseits auf Gefechtsabstand: Von hier aus liegt die Breitseite an.
	_enemy.global_position = Vector3(spot.x + FIGHTING_RANGE, 0.0, spot.y)
	_enemy.set_heading(0.0)
	await _wait(1.0)
	await _shot("02_laengsseits")

	_ship.fire(Gunnery.STARBOARD)
	# Die Kugeln brauchen fuer 180 Meter rund eine halbe Sekunde - hier soll
	# der Muendungsrauch stehen und die Salve noch in der Luft sein.
	await _wait(0.28)
	await _shot("03_breitseite")

	# Kurz nach dem Aufschlag: Fontaenen und Rauch stehen nur gut eine Sekunde.
	await _wait(0.45)
	await _shot("04_einschlag")

	# Die Flagge streichen lassen: Danach muss die Aufforderung im HUD stehen.
	_enemy.global_position = Vector3(spot.x + 70.0, 0.0, spot.y + 20.0)
	_enemy.take_hit(Gunnery.Zone.HULL, int(float(_enemy.max_hull) * 0.8))
	_enemy.strike()
	EventBus.ship_struck.emit(_enemy.ship_name)
	await _wait(2.0)
	await _shot("05_prise")

	get_tree().quit(0)


## Setzt ein fremdes Segel in eine bestimmte Entfernung querab.
func _summon(distance: float) -> Ship:
	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var enemy: Ship = packed.instantiate()
	enemy.player_controlled = false
	_combat.add_child(enemy)
	enemy.apply_class(load("res://resources/ships/merchant_brig.tres"))
	enemy.ship_name = "Zeelandia"
	enemy.nation_id = 3
	enemy.global_position = _ship.global_position + Vector3(distance, 0.0, 0.0)
	enemy.set_heading(0.0)
	_combat.adopt(enemy)
	# Der Kapitaen wuerde sofort fliehen - fuer eine Aufnahme soll das Schiff
	# stehen bleiben, wo es hingestellt wurde.
	var captain := enemy.get_node_or_null("Kapitaen")
	if captain != null:
		captain.queue_free()
	return enemy


func _open_sea() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldData.world_seed
	var half := WorldData.WORLD_SIZE * 0.45
	for attempt in 500:
		var spot := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var clear := true
		for i in 12:
			var angle := TAU * float(i) / 12.0
			var probe := spot + Vector2(sin(angle), cos(angle)) * 900.0
			if not WorldData.is_navigable(probe.x, probe.y):
				clear = false
				break
		if clear:
			return spot
	return Vector2.ZERO


func _on_broadside(by_player: bool, hits: int, shots: int) -> void:
	_last_salvo = "%s %d/%d" % ["eigene" if by_player else "gegnerische", hits, shots]


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	var error := image.save_png(path)
	var distance := _ship.plan_position().distance_to(_enemy.plan_position()) if _enemy != null else 0.0
	print("  %-18s  %5.0f m   Gegner Rumpf %3d Segel %3d   Salve %-14s [%s]" % [
		shot_name, distance, _enemy.hull, _enemy.sails, _last_salvo,
		"ok" if error == OK else "FEHLER %d" % error,
	])
