## Die Werft.
##
## Zeigt Rumpf und Segel und was ihre Instandsetzung kostet. Der Preis steht
## gross da und nicht in einer Bestaetigung versteckt: Reparieren ist die
## laufende Ausgabe im Spiel.
##
## Die Mannschaft stand hier bis M6 mit dabei. Sie steht jetzt in der Schenke,
## wo sie hingehoert ([TavernPanel]) - eine Werft setzt Holz instand, keine
## Leute.
class_name ShipyardPanel
extends VBoxContainer

signal repaired(message: String)

var town: TownData

var _hull: Label
var _sails: Label
var _cost: Label
var _button: Button


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

	add_child(_spacer())

	_cost = PortWidgets.label("", Palette.BRASS, 17)
	add_child(_cost)
	_button = _action("Instandsetzen", _on_repair_pressed)

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
	_hull.text = "%d / %d" % [GameState.hull, hull_max]
	_sails.text = "%d / %d" % [GameState.sails, sails_max]
	PortWidgets.paint(_hull, _state_color(float(GameState.hull) / float(maxi(hull_max, 1))))
	PortWidgets.paint(_sails, _state_color(GameState.sail_condition()))

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
