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
	{"name": "01_steuerbord", "yaw": 90.0, "pitch": 8.0, "distance": 18.0},
	{"name": "02_bug", "yaw": 152.0, "pitch": 14.0, "distance": 17.0},
	{"name": "03_heck", "yaw": 25.0, "pitch": 16.0, "distance": 17.0},
	{"name": "04_oben", "yaw": 115.0, "pitch": 52.0, "distance": 20.0},
]

## Was gezeigt wird. Leerer Pfad heisst: der Rumpf aus ship.tscn, den jede
## Klasse ohne eigenes Modell benutzt.
## Die Flagge bekommt jedes Schiff eine andere, damit man auf der
## Silhouettenaufnahme beide auseinanderhaelt.
const SUBJECTS: Array[Dictionary] = [
	{"prefix": "ship", "ship_class": "", "nation": 2},
	{"prefix": "caravel", "ship_class": "res://resources/ships/caravel.tres",
		"nation": 0},
]

var _camera: Camera3D
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _environment: Environment


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	WorldData.generate(1)

	_build_stage()

	# Wind von schraeg vorn an Steuerbord: Dabei stehen Rah und Flagge sichtbar
	# ausgeschwenkt. Bei Wind genau von achtern staende alles gerade und man
	# saehe der Aufnahme nicht an, ob die Stellung ueberhaupt gerechnet wird.
	WorldData.set_wind(deg_to_rad(55.0), 1.0)
	WorldData.wind_locked = true

	for subject: Dictionary in SUBJECTS:
		var ship: Node3D = _spawn(subject["ship_class"], subject["nation"])
		await get_tree().process_frame

		for view: Dictionary in VIEWS:
			_place_camera(view, Vector3.ZERO)
			await _wait(0.35)
			await _shot("%s_%s" % [subject["prefix"], view["name"]])

		# Und einmal bei Nacht: Die Laterne muss brennen und man muss sie
		# sehen - beides laesst sich headless nicht pruefen, ein Licht ist
		# nur im Bild etwas.
		_night(true)
		_place_camera(VIEWS[2], Vector3.ZERO)
		await _wait(Lantern.FADE + 0.3)
		await _shot("%s_05_nacht" % subject["prefix"])
		_night(false)

		ship.queue_free()
		await get_tree().process_frame

	await _silhouettes()
	get_tree().quit(0)


## Alle Rumpfformen nebeneinander, von weit weg und querab.
##
## Regel A1 verlangt Silhouetten, die man auf Entfernung auseinanderhaelt. Aus
## der Nahaufnahme laesst sich das nicht beurteilen - dort sieht jedes Modell
## nach etwas aus.
func _silhouettes() -> void:
	var spacing := 16.0
	var offset := -spacing * (SUBJECTS.size() - 1) * 0.5
	for subject: Dictionary in SUBJECTS:
		var ship: Node3D = _spawn(subject["ship_class"], subject["nation"])
		ship.position = Vector3(0.0, 0.0, offset)
		offset += spacing

	await get_tree().process_frame
	_place_camera(
		{"yaw": 90.0, "pitch": 6.0, "distance": 78.0}, Vector3(0.0, 3.0, 0.0))
	await _wait(0.35)
	await _shot("ship_00_silhouetten")


## Setzt ein Schiff, wahlweise mit einer Klasse und deren eigenem Modell.
func _spawn(class_path: String, nation: int) -> Node3D:
	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var ship: Node3D = packed.instantiate()
	# Ruhig stellen: kein Wellengang, keine Eingaben, feste Wasserlinie. Rah und
	# Flagge laufen trotzdem - sie haengen an _process, nicht an der Physik.
	ship.set("player_controlled", false)
	add_child(ship)
	ship.set_physics_process(false)
	if class_path != "":
		var ship_class: ShipClass = load(class_path)
		ship.call("apply_class", ship_class)
	ship.set("nation_id", nation)
	return ship


func _build_stage() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42.0, -55.0, 0.0)
	_sun.light_energy = 1.2
	_sun.shadow_enabled = true
	add_child(_sun)

	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-20.0, 130.0, 0.0)
	_fill.light_energy = 0.35
	add_child(_fill)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.16, 0.24, 0.31)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.55, 0.65, 0.75)
	_environment.ambient_light_energy = 0.5
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
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


## Buehne auf Nacht stellen - und die Uhr des Spiels gleich mit, denn
## danach richtet sich, ob das Schiff seine Laterne anzuendet.
##
## Die Buehnenlichter folgen den Zahlen aus [Skylight], nicht eigenen:
## So zeigt die Aufnahme dieselbe Nacht wie der Segelmodus.
func _night(on: bool) -> void:
	var t := 22.0 / 24.0 if on else 0.5
	GameState.game_minutes = t * 1440.0
	var weather := WorldData.Weather.CLEAR
	_sun.light_energy = Skylight.light_energy(t, weather) * (1.0 if on else 1.05)
	_sun.light_color = Skylight.light_colour(t)
	_fill.light_energy = 0.0 if on else 0.35
	_environment.ambient_light_energy = Skylight.ambient_energy(t) * (0.25 if on else 0.85)
	_environment.background_color = Palette.NIGHT_HAZE if on else Color(0.16, 0.24, 0.31)


func _place_camera(view: Dictionary, centre: Vector3) -> void:
	var yaw: float = deg_to_rad(view["yaw"])
	var pitch: float = deg_to_rad(view["pitch"])
	var distance: float = view["distance"]
	var focus := centre + Vector3(0.0, 2.2, 0.0)

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
