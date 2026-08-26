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


func _ready() -> void:
	# Einzelstart aus dem Editor: ohne Welt gibt es keinen Wind.
	if not WorldData.generated:
		WorldData.generate(randi())

	GameState.time_running = true

	_camera_rig.target = _ship
	_ocean.target = _ship
	_hud.setup(_ship)
	_map.ship = _ship

	# TODO(M2): Sonnenstand aus GameState.time_of_day() ableiten.
	_sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)


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
