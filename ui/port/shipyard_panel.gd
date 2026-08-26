## Die Werft.
##
## Zeigt den Zustand des Schiffes und was die Instandsetzung kostet. Reparieren
## ist die einzige laufende Ausgabe im Spiel - deshalb steht der Preis gross da
## und nicht in einer Bestaetigung versteckt.
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

	_hull = PortWidgets.label("", Palette.HUD_TEXT, 17)
	_sails = PortWidgets.label("", Palette.HUD_TEXT, 17)
	add_child(_hull)
	add_child(_sails)

	add_child(_spacer())

	_cost = PortWidgets.label("", Palette.BRASS, 17)
	add_child(_cost)

	_button = PortWidgets.button("Instandsetzen", 17)
	_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_button.pressed.connect(_on_repair_pressed)
	add_child(_button)

	refresh()


func refresh() -> void:
	var hull_max := GameState.max_hull()
	var sails_max := GameState.max_sails()
	_hull.text = "Rumpf    %d / %d" % [GameState.hull, hull_max]
	_sails.text = "Segel    %d / %d" % [GameState.sails, sails_max]
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
