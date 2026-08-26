## Anzeigen fuer den Segelmodus.
##
## Zeigt nur, was der Spieler zum Navigieren braucht: Kurs zum Wind, Fahrt,
## Segelstellung, Windstaerke. Alles andere kommt spaeter.
extends Control

var ship: Ship

@onready var _compass: Control = %Compass
@onready var _point_of_sail: Label = %PointOfSail
@onready var _speed: Label = %Speed
@onready var _sail: Label = %Sail
@onready var _wind: Label = %Wind
@onready var _clock: Label = %Clock

const COL_GOOD := Color(0.55, 0.78, 0.72)
const COL_FAIR := Color(0.85, 0.76, 0.45)
const COL_BAD  := Color(0.85, 0.45, 0.36)


func setup(target: Ship) -> void:
	ship = target
	_compass.ship = target


func _process(_delta: float) -> void:
	if ship == null:
		return

	if ship.aground:
		_point_of_sail.text = "Auf Grund"
		_point_of_sail.add_theme_color_override("font_color", COL_BAD)
	else:
		var efficiency := ship.efficiency()
		_point_of_sail.text = ship.point_of_sail()
		_point_of_sail.add_theme_color_override("font_color", _efficiency_color(efficiency))

	_speed.text = "%.1f kn" % ship.speed
	_sail.text = ship.sail_name()
	_wind.text = "%d°  ·  %.0f %%" % [
		wrapi(int(rad_to_deg(WorldData.wind_direction)), 0, 360),
		WorldData.wind_strength * 100.0,
	]

	var minutes := int(GameState.game_minutes) % 1440
	_clock.text = "Tag %d  ·  %02d:%02d" % [
		GameState.current_day() + 1, minutes / 60, minutes % 60
	]


func _efficiency_color(efficiency: float) -> Color:
	if efficiency >= 0.9:
		return COL_GOOD
	elif efficiency >= 0.4:
		return COL_FAIR
	return COL_BAD
