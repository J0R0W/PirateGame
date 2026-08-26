## Kompassrose mit Windanzeige - komplett gezeichnet, ohne Assets.
##
## Oben ist immer der Bug. Norden und Wind wandern darum herum. Der rote
## Sektor ist der Bereich, in den nicht gesegelt werden kann ("In Irons") -
## damit ist die wichtigste Regel des Spiels direkt ablesbar.
extends Control

const RADIUS: float = 62.0

const COL_RING   := Color(0.85, 0.90, 0.93, 0.55)
const COL_TICK   := Color(0.85, 0.90, 0.93, 0.35)
const COL_TEXT   := Color(0.88, 0.93, 0.96, 0.85)
const COL_WIND   := Color(0.78, 0.57, 0.19)
const COL_NOGO   := Color(0.66, 0.26, 0.18, 0.30)
const COL_SHIP   := Color(0.93, 0.95, 0.97)
const COL_NORTH  := Color(0.66, 0.26, 0.18)

var ship: Ship


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var heading := ship.heading() if ship != null else 0.0
	var wind_rel := angle_difference(heading, WorldData.wind_direction)

	# Sperrsektor: plus/minus 30 Grad um die Windquelle.
	_draw_sector(c, wind_rel, deg_to_rad(SailingMath.IRONS_LIMIT), COL_NOGO)

	draw_arc(c, RADIUS, 0.0, TAU, 64, COL_RING, 1.5, true)
	draw_arc(c, RADIUS - 9.0, 0.0, TAU, 64, COL_TICK, 1.0, true)

	# Gradmarken alle 30 Grad, die Haupthimmelsrichtungen laenger.
	for i in 12:
		var a := TAU * float(i) / 12.0
		var long := i % 3 == 0
		var inner := RADIUS - (12.0 if long else 6.0)
		var dir := _screen_dir(a - heading)
		draw_line(c + dir * inner, c + dir * RADIUS, COL_TICK, 1.0, true)

	_draw_label(c, -heading, "N", COL_NORTH)
	_draw_label(c, deg_to_rad(90.0) - heading, "O", COL_TEXT)
	_draw_label(c, deg_to_rad(180.0) - heading, "S", COL_TEXT)
	_draw_label(c, deg_to_rad(270.0) - heading, "W", COL_TEXT)

	_draw_wind_arrow(c, wind_rel)

	# Das Schiff zeigt im Kompass immer nach oben.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -15.0),
		c + Vector2(8.0, 12.0),
		c + Vector2(0.0, 7.0),
		c + Vector2(-8.0, 12.0),
	]), COL_SHIP)


## Bildschirmrichtung fuer einen Winkel relativ zum Bug. 0 = oben.
func _screen_dir(relative_angle: float) -> Vector2:
	return Vector2(sin(relative_angle), -cos(relative_angle))


func _draw_sector(c: Vector2, mid: float, half_width: float, color: Color) -> void:
	var points := PackedVector2Array([c])
	var steps := 16
	for i in steps + 1:
		var a := mid - half_width + (half_width * 2.0) * float(i) / float(steps)
		points.append(c + _screen_dir(a) * (RADIUS - 2.0))
	draw_colored_polygon(points, color)


func _draw_label(c: Vector2, relative_angle: float, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var pos := c + _screen_dir(relative_angle) * (RADIUS - 22.0)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, pos + Vector2(-width * 0.5, 4.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


## Pfeil von aussen nach innen: Er zeigt, wohin der Wind weht.
func _draw_wind_arrow(c: Vector2, wind_rel: float) -> void:
	var dir := _screen_dir(wind_rel)
	var tail := c + dir * (RADIUS + 1.0)
	var head := c + dir * (RADIUS - 26.0)
	draw_line(tail, head, COL_WIND, 2.5, true)

	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		head,
		head + dir * 9.0 + side * 5.5,
		head + dir * 9.0 - side * 5.5,
	]), COL_WIND)
