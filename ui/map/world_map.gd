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
@onready var _treaties: Label = %Treaties
@onready var _orders: Label = %Orders
@onready var _backdrop: ColorRect = %Backdrop
@onready var _hint: Label = %Hint

var _texture: ImageTexture
var _map_rect: Rect2


func _ready() -> void:
	visible = false
	_backdrop.color = Palette.BACKDROP
	_title.add_theme_color_override("font_color", Palette.PARCHMENT)
	_hint.add_theme_color_override("font_color", Palette.MUTED)
	_canvas.draw.connect(_draw_map)


## Blendet die Karte ein oder aus. Beim ersten Mal wird das Bild gerendert.
func toggle() -> void:
	visible = not visible
	if visible:
		_ensure_texture()
		# Bei jedem Oeffnen neu: Das Bild der Karibik aendert sich nie, das
		# Verhaeltnis zu ihren Nationen bei jeder Prise.
		_build_legend()
		_build_treaties()
		_build_orders()
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


## Die Legende: welche Nation wieviele Haefen hat - und wie sie zu einem steht.
##
## Der eine Ort, an dem alle vier nebeneinander stehen. Ohne ihn lernt niemand,
## dass es eine Skala gibt: Auf See sieht man immer nur das eine Segel, das
## gerade da ist, und im Hafen nur den einen, in dem man steht (Regel A8).
func _build_legend() -> void:
	for child in _legend.get_children():
		_legend.remove_child(child)
		child.queue_free()

	for nation: NationData in WorldData.nations:
		var count := 0
		for town: TownData in WorldData.towns:
			if town.nation_id == nation.id:
				count += 1

		# Zwei Beschriftungen statt einer: Die Nation traegt ihre Flaggenfarbe,
		# das Verhaeltnis die Zustandsfarbe. In einem Label ginge nur eines von
		# beidem - und die Nationsfarbe saehe aus wie eine Wertung.
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 6)

		var flag := Label.new()
		flag.text = "■ %s %d" % [nation.display_name, count]
		flag.add_theme_color_override("font_color", nation.color)
		flag.add_theme_font_size_override("font_size", 14)
		entry.add_child(flag)

		var level := GameState.standing_with(nation.id)
		var mood := Label.new()
		mood.text = "· %s" % Standing.title_of(level)
		mood.add_theme_color_override("font_color", Standing.color_of(level))
		mood.add_theme_font_size_override("font_size", 14)
		entry.add_child(mood)

		# Und wessen Brief man faehrt. Nur bei der einen Nation, und in der
		# Akzentfarbe statt in einer Zustandsfarbe: Ein Kaperbrief ist kein
		# Verhaeltnis, sondern eine eigene Entscheidung daneben (Regel A4).
		if GameState.letter_nation == nation.id:
			var letter := Label.new()
			letter.text = "· Kaperbrief"
			letter.add_theme_color_override("font_color", Palette.BRASS)
			letter.add_theme_font_size_override("font_size", 14)
			entry.add_child(letter)

		_legend.add_child(entry)


## Wer mit wem Krieg fuehrt - die politische Lage in einer Zeile.
##
## Eigene Zeile statt eines Zusatzes je Nation in der Legende: Jeder Krieg hat
## zwei Seiten und stuende dort zweimal, und vier Eintraege mit je einem
## Nationsnamen mehr sind breiter als das Fenster.
##
## In der abgeblendeten Farbe und nicht in einer Zustandsfarbe: Dass Spanien
## und England einander bekriegen, ist fuer den Spieler weder gut noch
## schlecht - es ist die Lage, in der er sich einen Patron aussucht (Regel A4).
func _build_treaties() -> void:
	var parts: PackedStringArray = []
	for war: Vector2i in WorldData.wars():
		var first := WorldData.get_nation(war.x)
		var second := WorldData.get_nation(war.y)
		if first != null and second != null:
			parts.append("%s gegen %s" % [first.subject_name(), second.subject_name()])
	if parts.is_empty():
		_treaties.text = ""
		return
	_treaties.text = "Krieg:  %s" % "      ·      ".join(parts)
	_treaties.add_theme_color_override("font_color", Palette.MUTED)


## Was man gerade schuldet - die eine Zeile ueber der Karibik.
##
## Die Seekarte ist der Ort dafuer, und nicht das HUD auf See: Dort ist jede
## Zeile fuer das da, was im naechsten Augenblick passiert. Ein Auftrag laeuft
## ueber Tage, und der Blick auf die Karte ist genau der Moment, in dem man
## fragt, wohin als Naechstes (Regel A8).
##
## Ohne Auftrag bleibt sie leer statt "Kein Auftrag" zu behaupten. Der Palast
## sagt schon, dass es Auftraege gibt; hier waere es eine Zeile, die nie etwas
## anderes tut, als Platz zu belegen.
func _build_orders() -> void:
	var order := GameState.commission
	if order == null or order.target == null:
		_orders.text = ""
		return

	var patron := WorldData.get_nation(order.patron_id)
	var crown := patron.display_name if patron != null else "eine Krone"
	if order.done:
		_orders.text = "Auftrag erledigt  ·  %s wartet auf deinen Bericht  ·  %d Gold" % [
			crown, order.reward_gold
		]
		_orders.add_theme_color_override("font_color", Palette.GOOD)
		return

	var left := order.days_left(GameState.current_day())
	_orders.text = "Auftrag für %s  ·  gesucht: %s%s  ·  noch %d %s" % [
		crown, order.target.title(), _waters_note(order),
		maxi(left, 0), "Tag" if left == 1 else "Tage"
	]
	# Die letzten beiden Tage in der Warnfarbe. Nicht rot - rot heisst in diesem
	# Spiel Schaden, und eine ablaufende Frist ist keiner (Regel A5).
	_orders.add_theme_color_override(
		"font_color", Palette.FAIR if left <= 2 else Palette.BRASS
	)


## Wo der Gesuchte kreuzt, sobald der Wirt es erzaehlt hat.
##
## Vorher steht hier nichts - nicht einmal "unbekannt". Der Ort ist der ganze
## Ertrag eines Schenkenbesuchs; ihn ungefragt auf die Karte zu schreiben
## naehme dem einzigen Grund, eine zu betreten, seinen Sinn.
func _waters_note(order: Commission) -> String:
	if not order.waters_known:
		return ""
	var waters := WorldData.get_town(order.waters_town_id)
	return "  ·  vor %s" % waters.town_name if waters != null else ""


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
