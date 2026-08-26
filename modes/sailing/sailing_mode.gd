## Der Segelmodus - Prototyp fuer M1.
##
## Verdrahtet Schiff, Kamera, Ozean und HUD miteinander. Die Szene laesst sich
## auch einzeln starten (F6 im Editor): Fehlt eine Welt, wird eine erzeugt.
extends Node3D

@onready var _ship: Ship = $PlayerShip
@onready var _camera_rig: Node3D = $CameraRig
@onready var _ocean: MeshInstance3D = $Ocean
@onready var _hud: Control = $HUD
@onready var _sun: DirectionalLight3D = $Sun
@onready var _map: Control = $WorldMap
@onready var _terrain: Node3D = $Terrain


func _ready() -> void:
	# Einzelstart aus dem Editor: ohne Welt gibt es keinen Wind.
	if not WorldData.generated:
		WorldData.generate(randi())

	GameState.time_running = true

	_place_ship_near_town()

	_camera_rig.target = _ship
	_ocean.target = _ship
	_terrain.target = _ship
	_hud.setup(_ship)
	_map.ship = _ship

	# TODO(M3): Sonnenstand aus GameState.time_of_day() ableiten.
	_sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)


## Setzt das Schiff vor einen zufaelligen Hafen, mit Blick auf die Kueste.
##
## Ein Start im Weltmittelpunkt landet je nach Seed mitten im Ozean oder in
## einem Berg - beides ein schlechter erster Eindruck.
func _place_ship_near_town() -> void:
	if WorldData.towns.is_empty():
		return

	var town: TownData = WorldData.towns[randi() % WorldData.towns.size()]
	var island: IslandData = WorldData.islands[town.island_id]

	# Seewaerts heisst: von der Inselmitte weg.
	var seaward := (town.position - island.center)
	seaward = seaward.normalized() if seaward.length() > 1.0 else Vector2.RIGHT

	# So weit hinaus, bis das Wasser tief genug ist, dann noch etwas Abstand.
	var anchor := town.position
	for step in 24:
		anchor = town.position + seaward * (200.0 + float(step) * 120.0)
		if WorldData.height_at(anchor.x, anchor.y) < WorldData.generator.deep_water:
			break
	anchor += seaward * 120.0

	_ship.global_position = Vector3(anchor.x, 0.0, anchor.y)
	# Bug zur Stadt drehen, damit beim Start Land im Bild ist.
	_ship.set_heading(SailingMath.angle_of(town.position - anchor))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
		_map.toggle()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		# Offene Karte schliessen, statt gleich das Spiel zu verlassen.
		if _map.visible:
			_map.toggle()
		else:
			SceneRouter.to_main_menu()
