## Die Seekarte - zeigt die generierte Welt, ihre Haefen und das eigene Schiff.
##
## Das Kartenbild wird beim ersten Oeffnen einmal gerendert und dann behalten.
## Staedte und Schiffsposition werden bei jedem Frame darueber gezeichnet.
extends Control

## Wessen Position zeigt der Pfeil?
var ship: Node3D

@onready var _canvas: Control = %MapCanvas
@onready var _title: Label = %MapTitle
@onready var _legend: HBoxContainer = %Legend

var _texture: ImageTexture
var _map_rect: Rect2


func _ready() -> void:
	visible = false
	_canvas.draw.connect(_draw_map)


## Blendet die Karte ein oder aus. Beim ersten Mal wird das Bild gerendert.
func toggle() -> void:
	visible = not visible
	if visible:
		_ensure_texture()
		_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		_canvas.queue_redraw()


func _ensure_texture() -> void:
	if _texture != null or WorldData.generator == null:
		return
	_texture = MapImage.build(WorldData.generator)
	_title.text = "Karibik  ·  Seed %d  ·  %d Häfen" % [
		WorldData.world_seed, WorldData.towns.size()
	]
	_build_legend()


func _build_legend() -> void:
	for child in _legend.get_children():
		child.queue_free()
	for nation: NationData in WorldData.nations:
		var count := 0
		for town: TownData in WorldData.towns:
			if town.nation_id == nation.id:
				count += 1
		var label := Label.new()
		label.text = "■ %s %d" % [nation.display_name, count]
		label.add_theme_color_override("font_color", nation.color)
		label.add_theme_font_size_override("font_size", 14)
		_legend.add_child(label)


func _draw_map() -> void:
	if _texture == null:
		return

	# Quadratisch und zentriert, damit die Karte nicht verzerrt.
	var side := minf(_canvas.size.x, _canvas.size.y)
	_map_rect = Rect2(
		(_canvas.size - Vector2(side, side)) * 0.5,
		Vector2(side, side)
	)
	_canvas.draw_texture_rect(_texture, _map_rect, false)
	_canvas.draw_rect(_map_rect, Palette.fade(Palette.HUD_DIM, 0.35), false, 1.0)

	_draw_towns()
	_draw_ship()


func _draw_towns() -> void:
	var font := ThemeDB.fallback_font
	for town: TownData in WorldData.towns:
		var nation := WorldData.get_nation(town.nation_id)
		var color := nation.color if nation != null else Color.WHITE
		var point := _world_to_map(town.position)

		# Hauptstaedte groesser, Doerfer als kleine Punkte.
		var radius := 3.0 + float(town.size_tier) * 2.0
		_canvas.draw_circle(point, radius + 1.5, Palette.fade(Palette.BACKDROP, 0.8))
		_canvas.draw_circle(point, radius, color)

		# Nur Staedte und Hauptstaedte beschriften - sonst wird es unleserlich.
		if town.size_tier >= 1:
			var offset := Vector2(radius + 4.0, 4.0)
			_canvas.draw_string_outline(
				font, point + offset, town.town_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Palette.fade(Palette.BACKDROP, 0.9)
			)
			_canvas.draw_string(
				font, point + offset, town.town_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.HUD_TEXT
			)


func _draw_ship() -> void:
	if ship == null:
		return
	var point := _world_to_map(Vector2(ship.global_position.x, ship.global_position.z))
	var heading: float = ship.heading()

	# Dreieck in Fahrtrichtung. Auf der Karte ist oben Norden, und die
	# Kartenrichtung ist dieselbe wie die Weltrichtung in XZ.
	var tip := point + SailingMath.direction(heading) * 9.0
	var left := point + SailingMath.direction(heading + 2.4) * 6.0
	var right := point + SailingMath.direction(heading - 2.4) * 6.0

	_canvas.draw_colored_polygon(
		PackedVector2Array([tip, left, point, right]), Palette.HUD_TEXT
	)
	_canvas.draw_arc(point, 12.0, 0.0, TAU, 24, Palette.fade(Palette.HUD_TEXT, 0.5), 1.0, true)


## Weltkoordinaten (Meter, zentriert um 0) auf Kartenpixel.
func _world_to_map(position: Vector2) -> Vector2:
	var half := WorldData.WORLD_SIZE * 0.5
	var normalized := (position + Vector2(half, half)) / WorldData.WORLD_SIZE
	return _map_rect.position + normalized * _map_rect.size
