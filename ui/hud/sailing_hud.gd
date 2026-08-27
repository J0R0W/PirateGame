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

## Ab hier wird ein fremdes Segel als Ziel angezeigt.
##
## Dieselbe Reichweite, ab der die Kamera es einrahmt: Was hier steht, ist auch
## zu sehen. Vorher waren es 900 Meter, und das HUD meldete Gegner, die
## ausserhalb des Bildes lagen.
const TARGET_RANGE: float = Gunnery.ENGAGEMENT_RANGE

var ship: Ship
## Das Gefecht - dieselbe Szene, nicht ein anderer Modus. Das HUD fragt hier
## nach, wer in Reichweite ist, statt fuer jede Zahl ein Signal zu bekommen.
var combat: NavalCombat

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
@onready var _target_name: Label = %TargetName
@onready var _target_class: Label = %TargetClass
@onready var _target_condition: Label = %TargetCondition
@onready var _port_battery: Label = %PortBattery
@onready var _starboard_battery: Label = %StarboardBattery

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
	_paint(_target_name, Palette.PARCHMENT)
	_paint(_target_class, Palette.HUD_DIM)
	_paint(_target_condition, Palette.HUD_TEXT)
	_paint(_port_battery, Palette.HUD_TEXT)
	_paint(_starboard_battery, Palette.HUD_TEXT)

	EventBus.dock_target_changed.connect(_on_dock_target_changed)
	EventBus.prize_target_changed.connect(_on_prize_target_changed)
	EventBus.ran_aground.connect(_on_ran_aground)
	EventBus.sail_sighted.connect(_on_sail_sighted)
	EventBus.ship_struck.connect(_on_ship_struck)
	EventBus.prize_taken.connect(_on_prize_taken)
	EventBus.player_struck.connect(_on_player_struck)


func setup(target: Ship, battle: NavalCombat = null) -> void:
	ship = target
	combat = battle
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

	# Die Mannschaft steht mit dabei, seit sie im Gefecht etwas bedeutet: Wer
	# Leute verliert, laedt langsamer und trifft schlechter (siehe Gunnery).
	var worst := minf(
		minf(
			float(GameState.hull) / float(maxi(GameState.max_hull(), 1)),
			GameState.sail_condition()
		),
		float(GameState.crew) / float(maxi(GameState.max_crew(), 1))
	)
	_condition.text = "Rumpf %d  ·  Segel %d  ·  %d Mann" % [
		GameState.hull, GameState.sails, GameState.crew
	]
	_paint(_condition, _state_color(worst))

	_purse.text = "%d Gold" % GameState.gold
	_hold.text = "Laderaum %d / %d" % [GameState.cargo_used(), GameState.cargo_capacity()]

	var minutes := int(GameState.game_minutes) % 1440
	_clock.text = "Tag %d  ·  %02d:%02d" % [
		GameState.current_day() + 1, minutes / 60, minutes % 60
	]

	_update_target()
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


# --- Gefecht ---------------------------------------------------------------

## Zeigt den naechsten Gegner und den Zustand der eigenen Batterien.
##
## Die Batterieanzeige ist der Kern von Regel A8: Sie leuchtet genau dann auf,
## wenn eine Breitseite auch treffen wuerde. Wer darauf achtet, lernt den
## Feuerbereich, ohne dass ihn jemand erklaert.
func _update_target() -> void:
	var enemy := _nearest_enemy()
	if enemy == null:
		_target_name.text = ""
		_target_class.text = ""
		_target_condition.text = ""
		_paint_battery(_port_battery, "Q   Backbord",
			ship.battery_progress(Gunnery.PORT), -1.0)
		_paint_battery(_starboard_battery, "Steuerbord   E",
			ship.battery_progress(Gunnery.STARBOARD), -1.0)
		return

	var distance := ship.plan_position().distance_to(enemy.plan_position())
	var nation := WorldData.get_nation(enemy.nation_id)
	var class_name_text := enemy.ship_class.display_name if enemy.ship_class != null else "Segler"

	_target_name.text = enemy.ship_name
	_target_class.text = "%s%s   ·   %d m" % [
		"%se " % nation.adjective.capitalize() if nation != null else "",
		class_name_text,
		int(distance),
	]
	if enemy.struck:
		_target_condition.text = "Flagge gestrichen"
		_paint(_target_condition, Palette.GOOD)
	else:
		_target_condition.text = "Rumpf %d %%   ·   Segel %d %%" % [
			int(round(enemy.hull_fraction() * 100.0)),
			int(round(enemy.sail_health() * 100.0)),
		]
		_paint(_target_condition, _state_color(enemy.hull_fraction()))

	var bearing := SailingMath.bearing(ship.plan_position(), enemy.plan_position())
	for side: int in [Gunnery.PORT, Gunnery.STARBOARD]:
		var quality := Gunnery.bearing_quality(ship.heading(), bearing, side)
		if distance > Gunnery.MAX_RANGE:
			quality = 0.0
		var label := _port_battery if side == Gunnery.PORT else _starboard_battery
		var caption := "Q   Backbord" if side == Gunnery.PORT else "Steuerbord   E"
		_paint_battery(label, caption, ship.battery_progress(side), quality)


## Die Beschriftung einer Batterie. [param quality] unter null heisst: kein
## Ziel - dann steht dort nur, ob geladen ist.
##
## Farbregel A5: Gruen heisst gut fuer dich. Nachladen wird abgeblendet, nicht
## rot - rot bedeutet in diesem Spiel Schaden.
func _paint_battery(label: Label, caption: String, progress: float, quality: float) -> void:
	if progress < 1.0:
		label.text = "%s   lädt %d %%" % [caption, int(progress * 100.0)]
		_paint(label, Palette.fade(Palette.HUD_DIM, 0.45))
	elif quality >= ShipAI.FIRE_QUALITY:
		label.text = "%s   liegt an" % caption
		_paint(label, Palette.GOOD)
	else:
		label.text = "%s   bereit" % caption
		_paint(label, Palette.HUD_TEXT)


func _nearest_enemy() -> Ship:
	return combat.nearest_enemy(TARGET_RANGE) if combat != null else null


func _on_sail_sighted(ship_name: String, nation_id: int, warship: bool) -> void:
	var nation := WorldData.get_nation(nation_id)
	var flag := "%ses " % nation.adjective.capitalize() if nation != null else ""
	show_notice("Segel in Sicht:  %s%s" % [
		flag, "Kriegsschiff" if warship else "Handelsschiff"
	], Palette.PARCHMENT)


func _on_ship_struck(ship_name: String) -> void:
	show_notice("%s streicht die Flagge!" % ship_name, Palette.GOOD)


func _on_prize_taken(ship_name: String, gold: int, units: int) -> void:
	show_notice("Prise %s:  %d Gold, %d Einheiten" % [ship_name, gold, units], Palette.BRASS)


func _on_player_struck(lost_gold: int, lost_units: int) -> void:
	show_notice("Gefecht verloren:  %d Gold und %d Einheiten geplündert"
		% [lost_gold, lost_units], Palette.BAD)


func _on_prize_target_changed(ship_name: String) -> void:
	if ship_name.is_empty():
		_dock_prompt.text = ""
		return
	_dock_prompt.text = "Leertaste   ·   %s aufbringen" % ship_name


# --- Hafen -----------------------------------------------------------------

func _on_dock_target_changed(town_id: int) -> void:
	var town := WorldData.get_town(town_id)
	if town == null:
		_dock_prompt.text = ""
		return
	_dock_prompt.text = "Leertaste   ·   In %s anlegen" % town.town_name


func _on_ran_aground(damage: int) -> void:
	show_notice("Aufgelaufen!   %d Rumpfschaden" % damage)


## Blendet eine Meldung ein, die von selbst wieder verschwindet.
func show_notice(text: String, color: Color = Palette.BAD) -> void:
	_notice.text = text
	_paint(_notice, color)
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
