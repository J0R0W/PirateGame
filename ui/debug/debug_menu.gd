## Stellschrauben zum Anfassen, waehrend das Spiel laeuft. Taste F3.
##
## Kein Teil des Spiels, sondern ein Werkzeug: Wind, Fahrt und Begegnungen sind
## die drei Groessen, auf die man beim Ausprobieren am laengsten warten muss.
## Wer pruefen will, wie sich Am-Wind-Fahren anfuehlt, soll den Wind dorthin
## drehen koennen, statt zehn Minuten zu segeln, bis er von selbst passt.
##
## Zwei bewusste Abweichungen von den Richtlinien, beide nur hier:
##
## - Das Menue traegt einen Kasten. Regel A7 verbietet das fuer das HUD, weil
##   Panels die See verdecken - genau das ist hier aber der Zweck, und Zahlen
##   auf bewegtem Wasser sind sonst nicht zu lesen.
## - Es wird im Code gebaut statt in einer .tscn. Dieselbe Bauweise wie die
##   Hafenbildschirme unter ui/port/: Ein Dutzend Regler mit Beschriftung und
##   Wertanzeige ist als Szenentext unlesbar.
##
## Vor einem Release faellt der Knoten aus modes/sailing/sailing_mode.tscn.
class_name DebugMenu
extends Control

## Breite der Beschriftungsspalte, damit die Regler untereinander fluchten.
const CAPTION_WIDTH: float = 120.0
## Und der Wertspalte rechts.
const VALUE_WIDTH: float = 74.0
const PANEL_WIDTH: float = 430.0
const MARGIN: int = 18
## Beschriftung der Wetterstufen, Reihenfolge wie [enum WorldData.Weather].
const WEATHER_NAMES: PackedStringArray = ["klar", "bedeckt", "Regen", "Sturm"]

var ship: Ship
var combat: NavalCombat
var ocean: Ocean

var _wind_direction: HSlider
var _wind_strength: HSlider
var _wind_lock: CheckBox
var _speed: HSlider
var _interval: HSlider
var _ships: HSlider
var _ship_count: Label
var _grid: CheckBox
var _clock: HSlider
var _clock_hold: CheckBox
var _weather: HSlider
## Regler -> Label rechts daneben. Spart einen Haufen einzelner Felder.
var _values: Dictionary = {}


func setup(player_ship: Ship, battle: NavalCombat, sea: Ocean) -> void:
	ship = player_ship
	combat = battle
	ocean = sea
	_read_back()


func _ready() -> void:
	visible = false
	# Sonst schluckt das unsichtbare Menue Klicks auf der ganzen Flaeche.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)

	# PanelContainer statt ColorRect: Er waechst von selbst mit seinem Inhalt.
	# Eine Flaeche fester Groesse muesste man bei jeder neuen Zeile nachziehen.
	var frame := PanelContainer.new()
	frame.position = Vector2(24.0, 110.0)
	frame.custom_minimum_size.x = PANEL_WIDTH
	frame.add_theme_stylebox_override("panel", _backdrop())
	add_child(frame)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, MARGIN)
	frame.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	column.add_child(_heading("Debug   ·   F3"))
	column.add_child(_note("Änderungen hier stehen in keiner Speicherdatei."))

	column.add_child(_section("Wind"))
	_wind_direction = _slider(column, "Richtung", 0.0, 359.0, 1.0, _on_wind_direction)
	_wind_strength = _slider(column, "Stärke", 0.0, 1.5, 0.05, _on_wind_strength)
	_wind_lock = _check(column, "festhalten (dreht sonst weiter)", _on_wind_lock)

	column.add_child(_section("Schiff"))
	_speed = _slider(column, "Fahrt", 0.25, 5.0, 0.25, _on_speed)

	column.add_child(_section("Begegnungen"))
	_interval = _slider(column, "Abstand", 5.0, 180.0, 5.0, _on_interval)
	_ships = _slider(column, "höchstens", 0.0, 6.0, 1.0, _on_max_ships)
	var button := Button.new()
	button.text = "Segel setzen"
	button.flat = true
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(_on_spawn)
	_paint_button(button)
	column.add_child(button)
	_ship_count = _note("")
	column.add_child(_ship_count)

	column.add_child(_section("Wasser"))
	_grid = _check(column, "Gitternetz zeichnen", _on_grid)

	# Ein Spieltag dauert vier Minuten. Wer die Nacht sehen will, soll nicht
	# zwei davon warten muessen - und wer die Laternen im Regen pruefen will,
	# hat sonst gar keinen Weg dorthin, weil noch keine Wetteruhr laeuft.
	column.add_child(_section("Himmel"))
	_clock = _slider(column, "Uhrzeit", 0.0, 23.75, 0.25, _on_clock)
	_clock_hold = _check(column, "Uhr anhalten", _on_clock_hold)
	_weather = _slider(column, "Wetter", 0.0, 3.0, 1.0, _on_weather)


func toggle() -> void:
	visible = not visible
	if visible:
		_read_back()


func _process(_delta: float) -> void:
	if not visible:
		return
	# Der Wind dreht auch ohne Zutun - der Regler soll dann mitgehen.
	if not WorldData.wind_locked:
		_set_silently(_wind_direction, wrapf(rad_to_deg(WorldData.wind_direction), 0.0, 360.0))
		_set_silently(_wind_strength, WorldData.wind_strength)
	if combat != null:
		var count := combat.ships().size()
		_ship_count.text = "%d fremde Segel in der Welt" % count
	# Die Uhr laeuft weiter - der Regler geht mit.
	if GameState.time_running:
		_set_silently(_clock, GameState.time_of_day() * 24.0)


## Holt den aktuellen Stand in die Regler. Beim Öffnen und beim Aufsetzen -
## sonst zeigt das Menue Werte an, die nie gesetzt wurden.
func _read_back() -> void:
	if _wind_direction == null:
		return
	_set_silently(_wind_direction, wrapf(rad_to_deg(WorldData.wind_direction), 0.0, 360.0))
	_set_silently(_wind_strength, WorldData.wind_strength)
	_wind_lock.set_pressed_no_signal(WorldData.wind_locked)
	if ship != null:
		_set_silently(_speed, ship.speed_multiplier)
	if combat != null:
		_set_silently(_interval, combat.spawn_interval)
		_set_silently(_ships, float(combat.max_ships))
	_grid.set_pressed_no_signal(ocean.show_grid if ocean != null else false)
	_set_silently(_clock, GameState.time_of_day() * 24.0)
	_clock_hold.set_pressed_no_signal(not GameState.time_running)
	_set_silently(_weather, float(WorldData.weather))


# --- Regler ----------------------------------------------------------------

func _on_wind_direction(value: float) -> void:
	# Wer den Wind von Hand dreht, will ihn dort haben. Ohne das Festhalten
	# waere der Regler nach zwei Sekunden wirkungslos - er saehe kaputt aus.
	_hold_wind()
	WorldData.set_wind(deg_to_rad(value))
	_show(_wind_direction, "%d°" % int(value))


func _on_wind_strength(value: float) -> void:
	_hold_wind()
	WorldData.set_wind(WorldData.wind_direction, value)
	_show(_wind_strength, "%.2f" % value)


func _hold_wind() -> void:
	if WorldData.wind_locked:
		return
	WorldData.wind_locked = true
	_wind_lock.set_pressed_no_signal(true)


func _on_wind_lock(pressed: bool) -> void:
	WorldData.wind_locked = pressed


func _on_speed(value: float) -> void:
	if ship != null:
		ship.speed_multiplier = value
	_show(_speed, "%.2f ×" % value)


func _on_interval(value: float) -> void:
	if combat != null:
		combat.spawn_interval = value
	_show(_interval, "%d s" % int(value))


func _on_max_ships(value: float) -> void:
	if combat != null:
		combat.max_ships = int(value)
	_show(_ships, "%d" % int(value))


func _on_spawn() -> void:
	if combat != null and not combat.spawn_now():
		_ship_count.text = "Kein Platz auf offener See — zu nah an der Küste?"


func _on_grid(pressed: bool) -> void:
	if ocean != null:
		ocean.show_grid = pressed


## Stellt die Uhr innerhalb des laufenden Tages. Der Tag selbst bleibt:
## Fristen und Kriege haengen an ihm, und die soll ein Blick auf die Nacht
## nicht verschieben.
func _on_clock(value: float) -> void:
	var day := floorf(GameState.game_minutes / 1440.0)
	GameState.game_minutes = day * 1440.0 + value * 60.0
	_show(_clock, Skylight.clock(value / 24.0))


func _on_clock_hold(pressed: bool) -> void:
	GameState.time_running = not pressed


func _on_weather(value: float) -> void:
	WorldData.weather = int(value) as WorldData.Weather
	_show(_weather, WEATHER_NAMES[int(value)])


# --- Bauteile --------------------------------------------------------------

func _backdrop() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.BACKDROP
	box.set_corner_radius_all(4)
	return box


## Eine Zeile: Beschriftung, Regler, Wert. Gibt den Regler zurueck.
func _slider(
	column: VBoxContainer, caption: String, low: float, high: float,
	step: float, handler: Callable
) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	var label := _note(caption)
	label.custom_minimum_size.x = CAPTION_WIDTH
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 20.0
	row.add_child(slider)

	var value := _note("")
	value.custom_minimum_size.x = VALUE_WIDTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_paint(value, Palette.BRASS)
	row.add_child(value)

	_values[slider] = value
	slider.value_changed.connect(handler)
	return slider


func _check(column: VBoxContainer, caption: String, handler: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = caption
	box.add_theme_font_size_override("font_size", 14)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		box.add_theme_color_override(state, Palette.HUD_DIM)
	box.toggled.connect(handler)
	column.add_child(box)
	return box


## Setzt einen Regler, ohne den Handler auszuloesen - und schreibt trotzdem
## die Wertanzeige fort.
func _set_silently(slider: HSlider, value: float) -> void:
	slider.set_value_no_signal(value)
	_refresh_value(slider, value)


func _refresh_value(slider: HSlider, value: float) -> void:
	if slider == _wind_direction:
		_show(slider, "%d°" % int(value))
	elif slider == _wind_strength:
		_show(slider, "%.2f" % value)
	elif slider == _speed:
		_show(slider, "%.2f ×" % value)
	elif slider == _interval:
		_show(slider, "%d s" % int(value))
	elif slider == _ships:
		_show(slider, "%d" % int(value))
	elif slider == _clock:
		_show(slider, Skylight.clock(value / 24.0))
	elif slider == _weather:
		_show(slider, WEATHER_NAMES[clampi(int(value), 0, WEATHER_NAMES.size() - 1)])


func _show(slider: HSlider, text: String) -> void:
	var label: Label = _values.get(slider)
	if label != null:
		label.text = text


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	_paint(label, Palette.PARCHMENT)
	return label


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	_paint(label, Palette.HUD_TEXT)
	return label


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	_paint(label, Palette.HUD_DIM)
	return label


func _paint(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)


func _paint_button(button: Button) -> void:
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Palette.PARCHMENT)
	button.add_theme_font_size_override("font_size", 15)
