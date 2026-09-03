## Takelage zum Anfassen - ein Schiff auf freier See, das man fahren kann.
##
##   godot --path . res://tests/rig.tscn
##
## Gebaut fuer genau eine Frage: Stehen Rah, Segel und Flagge richtig zum Wind?
## Das laesst sich weder rechnen noch aus einem Standbild ablesen - man muss
## den Wind drehen und dabei zusehen, was das Tuch macht. Deshalb ist der Wind
## hier festgenagelt und von Hand zu drehen, statt wie im Spiel selbst zu
## wandern.
##
## Die Szene ist der Segelmodus selbst, nur ohne Begegnungen - so sieht man das
## Rigg unter demselben Licht, in derselben See und aus derselben Kamera wie im
## Spiel. Eine eigene Buehne haette genau die Fehler versteckt, die man sucht.
##
## [b]Steuerung[/b] wie im Spiel: A/D Ruder, W/S Segel, Mausrad Zoom, M Seekarte,
## F3 Debug-Menue. Dazu:
##   Pfeil links/rechts - Wind drehen (10 Grad, mit Umschalt 45)
##   Pfeil hoch/runter  - Windstaerke
##   G                  - Schiffsklasse wechseln
##   N                  - Flagge wechseln (Nation)
##   L                  - Wind festhalten oder laufen lassen
##   R                  - zurueck auf Nordkurs, freie See
extends Node

## Alle Klassen der Reihe nach - auch die ohne eigenes Modell, damit man sieht,
## dass das alte Rigg genauso zum Wind steht wie das neue.
const CLASSES: PackedStringArray = [
	"res://resources/ships/caravel.tres",
	"res://resources/ships/sloop.tres",
	"res://resources/ships/patrol_sloop.tres",
	"res://resources/ships/merchant_brig.tres",
	"res://resources/ships/frigate.tres",
]

## Wieviel ein Tastendruck den Wind dreht, in Grad.
const WIND_STEP: float = 10.0
const WIND_STEP_FAST: float = 45.0

var _mode: Node3D = null
var _ship: Ship = null
var _readout: Label = null
var _class_index: int = 0
var _nation_id: int = 0
var _spot: Vector2 = Vector2.ZERO


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("tests/rig.tscn braucht ein Fenster - ohne Fenster gibt es "
			+ "nichts zu sehen. Ohne --headless starten.")
		get_tree().quit(0)
		return

	var packed: PackedScene = load("res://modes/sailing/sailing_mode.tscn")
	_mode = packed.instantiate()
	add_child(_mode)
	await get_tree().process_frame

	_ship = _mode.get_node("PlayerShip")
	# Leere See: Wer die Takelage beurteilt, will kein Segel am Horizont.
	_mode.get_node("Combat").max_ships = 0

	# Der Wind soll stehen, bis man ihn dreht - sonst weiss man nach einer
	# Minute nicht mehr, ob sich die Rah bewegt hat oder der Wind.
	WorldData.wind_locked = true
	WorldData.set_wind(deg_to_rad(180.0), 1.0)

	_spot = _open_sea()
	_build_readout()
	_reset()
	_apply_class()

	print_rich("[b]Takelage[/b] - Pfeiltasten Wind, G Klasse, N Flagge, "
		+ "L Wind halten, R zurueck")


func _process(_delta: float) -> void:
	if _ship == null or _readout == null:
		return

	var lines: PackedStringArray = []
	lines.append("%s   %s" % [
		_ship.ship_class.display_name if _ship.ship_class != null else "-",
		_nation_name()])
	lines.append("Wind aus %3d Grad   Staerke %.2f%s" % [
		int(round(rad_to_deg(wrapf(WorldData.wind_direction, 0.0, TAU)))),
		WorldData.wind_strength,
		"   [gehalten]" if WorldData.wind_locked else ""])
	lines.append("Kurs %3d Grad   %s   %.1f kn" % [
		int(round(rad_to_deg(wrapf(_ship.heading(), 0.0, TAU)))),
		_ship.point_of_sail(),
		_ship.speed])

	# Der eigentliche Messwert dieser Szene: Wie weit steht die Rah aus?
	var trims: PackedStringArray = []
	for rig: Rig in _rigs():
		trims.append("%+.0f" % rig.trim_degrees())
	lines.append("Rahstellung  %s Grad" % ", ".join(trims))

	_readout.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if _ship == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	var step := deg_to_rad(WIND_STEP_FAST if key.shift_pressed else WIND_STEP)

	match key.physical_keycode:
		KEY_LEFT:
			WorldData.set_wind(WorldData.wind_direction - step)
		KEY_RIGHT:
			WorldData.set_wind(WorldData.wind_direction + step)
		KEY_UP:
			WorldData.set_wind(WorldData.wind_direction,
				minf(WorldData.wind_strength + 0.1, 2.0))
		KEY_DOWN:
			WorldData.set_wind(WorldData.wind_direction,
				maxf(WorldData.wind_strength - 0.1, 0.0))
		KEY_L:
			WorldData.wind_locked = not WorldData.wind_locked
		KEY_G:
			_class_index = (_class_index + 1) % CLASSES.size()
			_apply_class()
		KEY_N:
			_nation_id = (_nation_id + 1) % 4
			_ship.nation_id = _nation_id
		KEY_R:
			_reset()


## Setzt die gewaehlte Klasse auf das Schiff des Spielers.
##
## Genau der Weg, den auch die Werft spaeter gehen wird - inklusive Modelltausch
## mitten in der Szene. Wenn dabei etwas haengen bleibt, sieht man es hier.
func _apply_class() -> void:
	_ship.apply_class(load(CLASSES[_class_index]))
	_ship.nation_id = _nation_id
	print("--- %s ---" % _ship.ship_class.display_name)


func _reset() -> void:
	_ship.global_position = Vector3(_spot.x, 0.0, _spot.y)
	_ship.set_heading(0.0)
	_ship.speed = 0.0
	_ship.nation_id = _nation_id
	_mode.get_node("CameraRig").snap()


func _rigs() -> Array[Rig]:
	var found: Array[Rig] = []
	var body := _ship.get_node_or_null("Hull")
	if body == null:
		return found
	for node: Node in body.find_children("*", "Node3D", true, false):
		if node is Rig:
			found.append(node as Rig)
	return found


func _nation_name() -> String:
	var nation: NationData = WorldData.get_nation(_nation_id)
	return nation.display_name if nation != null else "ohne Flagge"


## Anzeige der Messwerte. Ein Kasten waere hier erlaubt (Regel A7 nimmt
## Werkzeuge aus), aber die Kontur reicht und verdeckt die See nicht.
func _build_readout() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_readout = Label.new()
	_readout.position = Vector2(24.0, 150.0)
	_readout.add_theme_color_override("font_color", Palette.HUD_TEXT)
	_readout.add_theme_color_override("font_outline_color", Palette.HUD_OUTLINE)
	_readout.add_theme_constant_override("outline_size", 6)
	layer.add_child(_readout)


## Ein Fleck offener See, weit genug von jeder Kueste.
func _open_sea() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldData.world_seed
	var half := WorldData.WORLD_SIZE * 0.45
	for attempt in 500:
		var spot := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if _water_around(spot, 1200.0):
			return spot
	return Vector2.ZERO


func _water_around(center: Vector2, radius: float) -> bool:
	for i in 12:
		var angle := TAU * float(i) / 12.0
		for factor: float in [0.5, 1.0]:
			var probe := center + Vector2(sin(angle), cos(angle)) * radius * factor
			if not WorldData.is_navigable(probe.x, probe.y):
				return false
	return WorldData.is_navigable(center.x, center.y)
