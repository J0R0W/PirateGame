## Die Werft.
##
## Zeigt den Zustand des Schiffes und was Instandsetzung und Anheuern kosten.
## Beides sind die laufenden Ausgaben im Spiel - deshalb stehen die Preise
## gross da und nicht in einer Bestaetigung versteckt.
class_name ShipyardPanel
extends VBoxContainer

signal repaired(message: String)

var town: TownData

var _hull: Label
var _sails: Label
var _crew: Label
var _cost: Label
var _button: Button
var _crew_cost: Label
var _crew_button: Button


func setup(target: TownData) -> void:
	town = target
	add_theme_constant_override("separation", 8)

	var ship_class := GameState.ship_class
	var ship_name := ship_class.display_name if ship_class != null else "Schiff"
	add_child(PortWidgets.label(ship_name, Palette.PARCHMENT, 22))
	if ship_class != null and not ship_class.description.is_empty():
		var note := PortWidgets.label(ship_class.description, Palette.HUD_DIM, 14)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 520
		add_child(note)

	add_child(_spacer())

	# Raster statt Leerzeichen: In einer Proportionalschrift fluchten sonst
	# weder die Beschriftungen noch die Zahlen dahinter.
	var condition := GridContainer.new()
	condition.columns = 2
	condition.add_theme_constant_override("h_separation", 24)
	condition.add_theme_constant_override("v_separation", 4)
	add_child(condition)

	_hull = _condition_row(condition, "Rumpf")
	_sails = _condition_row(condition, "Segel")
	_crew = _condition_row(condition, "Mannschaft")

	add_child(_spacer())

	_cost = PortWidgets.label("", Palette.BRASS, 17)
	add_child(_cost)
	_button = _action("Instandsetzen", _on_repair_pressed)

	add_child(_spacer())

	_crew_cost = PortWidgets.label("", Palette.BRASS, 17)
	add_child(_crew_cost)
	_crew_button = _action("Mannschaft anheuern", _on_hire_pressed)

	refresh()


## Eine Zeile "Beschriftung  Zahl" im Zustandsraster. Gibt das Zahlenfeld
## zurueck - die Beschriftung aendert sich nie.
func _condition_row(grid: GridContainer, caption: String) -> Label:
	grid.add_child(PortWidgets.label(caption, Palette.HUD_DIM, 17))
	var value := PortWidgets.label("", Palette.HUD_TEXT, 17)
	grid.add_child(value)
	return value


## Ein Knopf, der links steht statt sich ueber die Breite zu ziehen.
func _action(caption: String, handler: Callable) -> Button:
	var button := PortWidgets.button(caption, 17)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(handler)
	add_child(button)
	return button


func refresh() -> void:
	var hull_max := GameState.max_hull()
	var sails_max := GameState.max_sails()
	var crew_max := GameState.max_crew()
	_hull.text = "%d / %d" % [GameState.hull, hull_max]
	_sails.text = "%d / %d" % [GameState.sails, sails_max]
	# Die Mannschaft wird nach der Bedienung gefaerbt, nicht nach dem Anteil an
	# der Hoechstzahl - genau wie im HUD. Eine Schaluppe faehrt mit vierzig Mann
	# und braucht acht: Die Haelfte zu verlieren sieht nach der Haelfte aus,
	# kostet aber noch keinen einzigen Ladevorgang. Wer unter die Mindest-
	# besatzung faellt, verliert dagegen Fahrt, und das steht dann auch da.
	if GameState.handling() < 1.0:
		_crew.text = "%d / %d — unter der Mindestbesatzung von %d" % [
			GameState.crew, crew_max, GameState.min_crew()
		]
	else:
		_crew.text = "%d / %d" % [GameState.crew, crew_max]
	PortWidgets.paint(_hull, _state_color(float(GameState.hull) / float(maxi(hull_max, 1))))
	PortWidgets.paint(_sails, _state_color(GameState.sail_condition()))
	PortWidgets.paint(_crew, _state_color(GameState.readiness()))

	_refresh_crew()

	var cost := Shipyard.full_repair_cost(town)
	if cost <= 0:
		_cost.text = "Das Schiff ist in tadellosem Zustand."
		PortWidgets.paint(_cost, Palette.HUD_DIM)
		_button.disabled = true
		return

	_button.disabled = GameState.gold <= 0
	if GameState.gold >= cost:
		_cost.text = "Instandsetzung: %d Gold" % cost
		PortWidgets.paint(_cost, Palette.BRASS)
	else:
		# Teilreparatur ist erlaubt, also wird sie auch angeboten - sonst
		# stuende hier nur ein Preis, den man nicht zahlen kann.
		_cost.text = "Instandsetzung: %d Gold — du hast %d. Der Zimmermann macht, was davon geht." % [
			cost, GameState.gold
		]
		PortWidgets.paint(_cost, Palette.FAIR)


## Anheuern kostet Gold und bringt Ladezeit und Treffsicherheit zurueck -
## deshalb steht dabei, wofuer man zahlt.
func _refresh_crew() -> void:
	var missing := Shipyard.crew_missing()
	if missing <= 0:
		_crew_cost.text = "Die Mannschaft ist vollzählig."
		PortWidgets.paint(_crew_cost, Palette.HUD_DIM)
		_crew_button.disabled = true
		return

	var cost := Shipyard.full_hire_cost(town)
	_crew_button.disabled = GameState.gold < Shipyard.hire_cost(town, 1)
	if GameState.gold >= cost:
		_crew_cost.text = "%d Mann anheuern: %d Gold" % [missing, cost]
		PortWidgets.paint(_crew_cost, Palette.BRASS)
	else:
		_crew_cost.text = "%d Mann anheuern: %d Gold — du hast %d. Es kommt, wer bezahlt wird." % [
			missing, cost, GameState.gold
		]
		PortWidgets.paint(_crew_cost, Palette.FAIR)


func _on_hire_pressed() -> void:
	var count := Shipyard.hire(town)
	refresh()
	if count <= 0:
		repaired.emit("Für Handgeld reicht das Gold nicht.")
	else:
		repaired.emit("%d Mann kommen an Bord." % count)


func _on_repair_pressed() -> void:
	var spent := Shipyard.repair(town)
	refresh()
	if spent <= 0:
		repaired.emit("Dafür reicht das Gold nicht.")
	else:
		repaired.emit("Werft: %d Gold für Ausbesserungen." % spent)


func _state_color(fraction: float) -> Color:
	if fraction >= 0.9:
		return Palette.GOOD
	elif fraction >= 0.4:
		return Palette.FAIR
	return Palette.BAD


func _spacer() -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = 10
	return node
