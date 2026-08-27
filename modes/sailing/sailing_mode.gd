## Der Segelmodus.
##
## Verdrahtet Schiff, Kamera, Ozean, Gefecht und HUD miteinander. Die Szene
## laesst sich auch einzeln starten (F6 im Editor): Fehlt eine Welt, wird eine
## erzeugt.
##
## Der Modus haelt die Bruecke zwischen dem Schiff als Node und dem Spieler in
## GameState: Beim Start werden Zustand und Ladung von dort uebernommen, danach
## schreibt jede Aenderung am Schiff dorthin zurueck. Waehrend der Szene ist das
## Schiff die Wahrheit, zwischen zwei Szenen GameState.
extends Node3D

## Rumpfschaden je Knoten Fahrt beim Auflaufen.
const GROUNDING_DAMAGE_PER_KNOT: float = 1.6

@onready var _ship: Ship = $PlayerShip
@onready var _camera_rig: Node3D = $CameraRig
@onready var _ocean: Ocean = $Ocean
@onready var _hud: Control = $HUD
@onready var _sun: DirectionalLight3D = $Sun
@onready var _map: Control = $WorldMap
@onready var _terrain: Node3D = $Terrain
@onready var _towns: TownMarkers = $Towns
@onready var _combat: NavalCombat = $Combat
@onready var _debug: DebugMenu = $DebugMenu

## Stadt in Anlegereichweite, oder null.
var _dock_target: TownData = null
## Gestrichenes Schiff laengsseit, oder null.
var _prize_target: Ship = null


func _ready() -> void:
	# Einzelstart aus dem Editor: ohne Welt gibt es keinen Wind.
	if not WorldData.generated:
		GameState.new_campaign("Kapitaen", randi())

	GameState.time_running = true

	_apply_ship_class()
	_place_ship()

	_ship.ran_aground.connect(_on_ran_aground)
	_ship.condition_changed.connect(_on_condition_changed)
	_combat.setup(_ship)

	_camera_rig.target = _ship
	# Das Schiff wurde gesetzt, nicht gefahren - die Kamera darf ihm nicht
	# erst hinterherfliegen.
	_camera_rig.snap()
	_ocean.target = _ship
	_terrain.target = _ship
	_towns.target = _ship
	_hud.setup(_ship, _combat)
	_map.ship = _ship
	_debug.setup(_ship, _combat, _ocean)

	# TODO(M7): Sonnenstand aus GameState.time_of_day() ableiten.
	_sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)


func _process(_delta: float) -> void:
	_update_dock_target()
	_update_prize_target()
	# Die Kamera rahmt das Gefecht ein, statt stur nach vorn zu sehen -
	# querab liegt sonst ausserhalb des Bildes.
	_camera_rig.focus = _combat.nearest_enemy(_camera_rig.focus_range)


## Uebertraegt Schiffsklasse und Zustand auf das sichtbare Schiff.
func _apply_ship_class() -> void:
	_ship.apply_class(GameState.ship_class)
	_ship.ship_name = "%s" % GameState.captain_name
	_ship.set_condition(GameState.hull, GameState.sails, GameState.crew)


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


# --- Anlegen und Aufbringen ------------------------------------------------

func _update_dock_target() -> void:
	var where := Vector2(_ship.global_position.x, _ship.global_position.z)
	var found := WorldData.dockable_town(where)
	if found == _dock_target:
		return

	_dock_target = found
	EventBus.dock_target_changed.emit(found.id if found != null else -1)


func _update_prize_target() -> void:
	var found := _combat.prize_in_reach()
	if found == _prize_target:
		return

	_prize_target = found
	EventBus.prize_target_changed.emit(found.ship_name if found != null else "")


func _on_ran_aground(impact_speed: float) -> void:
	var damage := maxi(1, int(round(impact_speed * GROUNDING_DAMAGE_PER_KNOT)))
	_ship.take_hit(Gunnery.Zone.HULL, damage)
	EventBus.ran_aground.emit(damage)


## Schreibt den Zustand des Schiffs in GameState fort.
##
## Nur diese Richtung: Sonst schreiben sich Schiff und GameState gegenseitig um
## und der erste Treffer laeuft im Kreis.
func _on_condition_changed(hull: int, sails: int, crew: int) -> void:
	GameState.hull = hull
	GameState.sails = sails
	GameState.crew = crew


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		get_viewport().set_input_as_handled()
		_debug.toggle()
	elif event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
		_map.toggle()
	elif event.is_action_pressed("interact") and not _map.visible:
		# Eine Prise geht vor: Wer laengsseit einer gestrichenen Flagge liegt,
		# will sie ausraeumen und nicht in den Hafen davor.
		if _prize_target != null:
			get_viewport().set_input_as_handled()
			_combat.take_prize(_prize_target)
		elif _dock_target != null:
			get_viewport().set_input_as_handled()
			SceneRouter.enter_port(_dock_target.id)
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		# Offenes Fenster schliessen, statt gleich das Spiel zu verlassen.
		if _debug.visible:
			_debug.toggle()
		elif _map.visible:
			_map.toggle()
		else:
			SceneRouter.to_main_menu()
