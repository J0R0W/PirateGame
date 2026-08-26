## Anzeigen fuer den Segelmodus.
##
## Zeigt nur, was der Spieler zum Navigieren und Handeln braucht: Kurs zum
## Wind, Fahrt, Segelstellung, Wind, Zustand, Gold und Laderaum.
##
## Die Farben stehen hier und nicht in der Szene: In der .tscn waeren es
## Zahlenkolonnen, die niemand mit der Palette abgleicht. Die Szene bestimmt
## die Anordnung, dieses Skript die Farbe.
extends Control

## So lange bleibt eine Meldung stehen.
const NOTICE_SECONDS: float = 3.5

var ship: Ship

@onready var _compass: Control = %Compass
@onready var _point_of_sail: Label = %PointOfSail
@onready var _speed: Label = %Speed
@onready var _sail: Label = %Sail
@onready var _wind: Label = %Wind
@onready var _condition: Label = %Condition
@onready var _clock: Label = %Clock
@onready var _purse: Label = %Purse
@onready var _hold: Label = %Hold
@onready var _dock_prompt: Label = %DockPrompt
@onready var _notice: Label = %Notice

var _notice_timer: float = 0.0


func _ready() -> void:
	_paint(_clock, Palette.HUD_DIM)
	_paint(_purse, Palette.BRASS)
	_paint(_hold, Palette.HUD_DIM)
	_paint($Hint as Label, Palette.fade(Palette.HUD_DIM, 0.55))
	_paint(_speed, Palette.HUD_TEXT)
	_paint(_sail, Palette.HUD_DIM)
	_paint(_wind, Palette.BRASS)
	_paint(_point_of_sail, Palette.GOOD)
	_paint(_condition, Palette.GOOD)
	_paint(_dock_prompt, Palette.PARCHMENT)
	_paint(_notice, Palette.BAD)

	EventBus.dock_target_changed.connect(_on_dock_target_changed)
	EventBus.ran_aground.connect(_on_ran_aground)


func setup(target: Ship) -> void:
	ship = target
	_compass.ship = target


func _process(delta: float) -> void:
	if ship == null:
		return

	if ship.aground:
		_point_of_sail.text = "Auf Grund"
		_paint(_point_of_sail, Palette.BAD)
	else:
		_point_of_sail.text = ship.point_of_sail()
		_paint(_point_of_sail, _state_color(ship.efficiency()))

	_speed.text = "%.1f kn" % ship.speed
	_sail.text = ship.sail_name()
	_wind.text = "%d°  ·  %.0f %%" % [
		wrapi(int(rad_to_deg(WorldData.wind_direction)), 0, 360),
		WorldData.wind_strength * 100.0,
	]

	var worst := minf(
		float(GameState.hull) / float(maxi(GameState.max_hull(), 1)),
		GameState.sail_condition()
	)
	_condition.text = "Rumpf %d  ·  Segel %d" % [GameState.hull, GameState.sails]
	_paint(_condition, _state_color(worst))

	_purse.text = "%d Gold" % GameState.gold
	_hold.text = "Laderaum %d / %d" % [GameState.cargo_used(), GameState.cargo_capacity()]

	var minutes := int(GameState.game_minutes) % 1440
	_clock.text = "Tag %d  ·  %02d:%02d" % [
		GameState.current_day() + 1, minutes / 60, minutes % 60
	]

	_update_notice(delta)


## Zustandsfarbe fuer einen Anteil von 0 bis 1. Dieselben Schwellen fuer
## Segelwirkung und Schiffszustand - der Spieler soll eine Farbe lernen, nicht
## zwei Skalen.
func _state_color(fraction: float) -> Color:
	if fraction >= 0.9:
		return Palette.GOOD
	elif fraction >= 0.4:
		return Palette.FAIR
	return Palette.BAD


func _on_dock_target_changed(town_id: int) -> void:
	var town := WorldData.get_town(town_id)
	if town == null:
		_dock_prompt.text = ""
		return
	_dock_prompt.text = "Leertaste   ·   In %s anlegen" % town.town_name


func _on_ran_aground(damage: int) -> void:
	show_notice("Aufgelaufen!   %d Rumpfschaden" % damage)


## Blendet eine Meldung ein, die von selbst wieder verschwindet.
func show_notice(text: String) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	_notice_timer = NOTICE_SECONDS


func _update_notice(delta: float) -> void:
	if _notice_timer <= 0.0:
		return
	_notice_timer -= delta
	# Die letzte Sekunde ausblenden, statt die Meldung wegzuschalten.
	_notice.modulate.a = clampf(_notice_timer, 0.0, 1.0)
	if _notice_timer <= 0.0:
		_notice.text = ""


func _paint(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.HUD_OUTLINE)
