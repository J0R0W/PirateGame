## Der Segelmodus.
##
## Verdrahtet Schiff, Kamera, Ozean und HUD miteinander. Die Szene laesst sich
## auch einzeln starten (F6 im Editor): Fehlt eine Welt, wird eine erzeugt.
extends Node3D

## Rumpfschaden je Knoten Fahrt beim Auflaufen.
const GROUNDING_DAMAGE_PER_KNOT: float = 1.6

@onready var _ship: Ship = $PlayerShip
@onready var _camera_rig: Node3D = $CameraRig
@onready var _ocean: MeshInstance3D = $Ocean
@onready var _hud: Control = $HUD
@onready var _sun: DirectionalLight3D = $Sun
@onready var _map: Control = $WorldMap
@onready var _terrain: Node3D = $Terrain
@onready var _towns: TownMarkers = $Towns

## Stadt in Anlegereichweite, oder null.
var _dock_target: TownData = null


func _ready() -> void:
	# Einzelstart aus dem Editor: ohne Welt gibt es keinen Wind.
	if not WorldData.generated:
		GameState.new_campaign("Kapitaen", randi())

	GameState.time_running = true

	_apply_ship_class()
	_place_ship()

	_ship.ran_aground.connect(_on_ran_aground)
	EventBus.ship_condition_changed.connect(_on_condition_changed)

	_camera_rig.target = _ship
	# Das Schiff wurde gesetzt, nicht gefahren - die Kamera darf ihm nicht
	# erst hinterherfliegen.
	_camera_rig.snap()
	_ocean.target = _ship
	_terrain.target = _ship
	_towns.target = _ship
	_hud.setup(_ship)
	_map.ship = _ship

	# TODO(M4): Sonnenstand aus GameState.time_of_day() ableiten.
	_sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)


func _process(_delta: float) -> void:
	_update_dock_target()


## Uebertraegt die Werte der Schiffsklasse auf das sichtbare Schiff.
##
## Die .tres-Datei ist die Wahrheit, nicht die Szene: Sonst stuenden dieselben
## Fahrwerte zweimal da und die Werft wuerde ein anderes Schiff reparieren, als
## man steuert.
func _apply_ship_class() -> void:
	var ship_class := GameState.ship_class
	if ship_class == null:
		return
	_ship.base_speed = ship_class.base_speed
	_ship.turn_rate_deg = ship_class.turn_rate_deg
	_ship.speed_inertia = ship_class.speed_inertia
	_ship.turn_inertia = ship_class.turn_inertia
	_ship.sail_condition = GameState.sail_condition()


## Setzt das Schiff an seinen Startplatz.
##
## Kommt es aus einem Hafen, liegt es wieder vor genau diesem. Sonst - beim
## Kampagnenstart oder beim Einzelstart der Szene - vor einer zufaelligen Stadt:
## Ein Start im Weltmittelpunkt landet je nach Seed mitten im Ozean oder in
## einem Berg, beides ein schlechter erster Eindruck.
func _place_ship() -> void:
	if WorldData.towns.is_empty():
		return

	var town := WorldData.get_town(GameState.current_port_id)
	if town == null:
		town = WorldData.towns[randi() % WorldData.towns.size()]
	# Der Hafen ist abgearbeitet - der Spieler ist wieder auf See.
	GameState.current_port_id = -1

	var anchor := WorldData.anchorage_for(town)
	_ship.global_position = Vector3(anchor.x, 0.0, anchor.y)
	# Bug zur Stadt drehen, damit beim Start Land im Bild ist.
	_ship.set_heading(SailingMath.angle_of(town.position - anchor))


# --- Anlegen ---------------------------------------------------------------

func _update_dock_target() -> void:
	var where := Vector2(_ship.global_position.x, _ship.global_position.z)
	var found := WorldData.dockable_town(where)
	if found == _dock_target:
		return

	_dock_target = found
	EventBus.dock_target_changed.emit(found.id if found != null else -1)


func _on_ran_aground(impact_speed: float) -> void:
	# Das Schiff kennt seinen Rumpfzustand nicht - der gehoert dem Spieler und
	# liegt in GameState. Deshalb wird der Schaden hier berechnet.
	var damage := maxi(1, int(round(impact_speed * GROUNDING_DAMAGE_PER_KNOT)))
	GameState.damage_hull(damage)
	EventBus.ran_aground.emit(damage)


func _on_condition_changed(_hull: int, _sails: int) -> void:
	_ship.sail_condition = GameState.sail_condition()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
		_map.toggle()
	elif event.is_action_pressed("interact") and _dock_target != null and not _map.visible:
		get_viewport().set_input_as_handled()
		SceneRouter.enter_port(_dock_target.id)
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		# Offene Karte schliessen, statt gleich das Spiel zu verlassen.
		if _map.visible:
			_map.toggle()
		else:
			SceneRouter.to_main_menu()
