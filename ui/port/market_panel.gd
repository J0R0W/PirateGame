## Der Markt einer Stadt.
##
## Eine Zeile je Ware: Lagerbestand, Kauf- und Verkaufspreis, eigener Bestand,
## zwei Schaltflaechen. Die Preise stehen nicht nur da, sie sind eingefaerbt -
## gruen heisst "guter Preis fuer dich". Ohne das muesste man zwoelf
## Basispreise auswendig koennen, um zu erkennen, wo sich Handel lohnt.
class_name MarketPanel
extends VBoxContainer

## Handelsmengen je Klick. -1 steht fuer "so viel wie geht".
const AMOUNTS: Array[int] = [1, 5, 20, -1]
const AMOUNT_LABELS: PackedStringArray = ["1", "5", "20", "Alles"]

## Ab dieser Abweichung vom Basispreis gilt ein Preis als gut oder schlecht.
const BARGAIN: float = 0.88
const STEEP: float = 1.12

const COLUMN_WIDTHS: PackedInt32Array = [150, 70, 80, 90, 80]

signal traded(message: String)

var town: TownData

var _amount_index: int = 0
var _amount_buttons: Array[Button] = []
var _rows: Dictionary = {}


func setup(target: TownData) -> void:
	town = target
	add_theme_constant_override("separation", 10)
	_build_amount_selector()
	_build_table()
	refresh()


func _build_amount_selector() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var caption := PortWidgets.label("Menge je Klick", Palette.HUD_DIM, 14)
	caption.custom_minimum_size.x = 150
	row.add_child(caption)

	for i in AMOUNTS.size():
		var button := PortWidgets.button(AMOUNT_LABELS[i])
		button.custom_minimum_size.x = 64
		button.pressed.connect(_on_amount_pressed.bind(i))
		row.add_child(button)
		_amount_buttons.append(button)
	_highlight_amount()


func _build_table() -> void:
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)

	for text: String in ["Ware", "Vorrat", "Kauf", "Verkauf", "An Bord"]:
		grid.add_child(_header(text))
	grid.add_child(_header(""))
	grid.add_child(_header(""))

	for cargo: CargoType in CargoRegistry.all():
		var name_label := PortWidgets.label(cargo.display_name, Palette.HUD_TEXT, 15)
		name_label.custom_minimum_size.x = COLUMN_WIDTHS[0]
		grid.add_child(name_label)

		var stock_label := PortWidgets.number(COLUMN_WIDTHS[1])
		var buy_label := PortWidgets.number(COLUMN_WIDTHS[2])
		var sell_label := PortWidgets.number(COLUMN_WIDTHS[3])
		var hold_label := PortWidgets.number(COLUMN_WIDTHS[4])
		grid.add_child(stock_label)
		grid.add_child(buy_label)
		grid.add_child(sell_label)
		grid.add_child(hold_label)

		var buy_button := PortWidgets.button("Kaufen")
		buy_button.pressed.connect(_on_buy_pressed.bind(cargo))
		grid.add_child(buy_button)

		var sell_button := PortWidgets.button("Verkaufen")
		sell_button.pressed.connect(_on_sell_pressed.bind(cargo))
		grid.add_child(sell_button)

		_rows[cargo.id] = {
			"name": name_label,
			"stock": stock_label,
			"buy": buy_label,
			"sell": sell_label,
			"hold": hold_label,
			"buy_button": buy_button,
			"sell_button": sell_button,
		}


## Schreibt alle Zahlen neu. Nach jedem Handel noetig - ein Kauf verschiebt
## den Bestand und damit jeden folgenden Preis.
func refresh() -> void:
	if town == null:
		return
	for cargo: CargoType in CargoRegistry.all():
		var row: Dictionary = _rows[cargo.id]
		var buy := town.buy_price(cargo)
		var sell := town.sell_price(cargo)
		var on_board := GameState.cargo_of(cargo.id)

		var stock_label: Label = row["stock"]
		stock_label.text = str(town.available(cargo.id))

		var buy_label: Label = row["buy"]
		buy_label.text = str(buy)
		PortWidgets.paint(buy_label, _price_color(buy, cargo.base_price, true))

		var sell_label: Label = row["sell"]
		sell_label.text = str(sell)
		PortWidgets.paint(sell_label, _price_color(sell, cargo.base_price, false))

		var hold_label: Label = row["hold"]
		hold_label.text = str(on_board) if on_board > 0 else "–"
		PortWidgets.paint(hold_label, Palette.HUD_TEXT if on_board > 0 else Palette.HUD_DIM)

		var name_label: Label = row["name"]
		# Was die Stadt selbst erzeugt, bekommt einen Stern - das ist der
		# Grund fuer den niedrigen Preis und bleibt auch dann sichtbar, wenn
		# man das Lager leergekauft hat.
		name_label.text = cargo.display_name + ("  *" if town.is_producer(cargo.id) else "")

		var buy_button: Button = row["buy_button"]
		buy_button.disabled = Trade.max_buyable(town, cargo) <= 0
		var sell_button: Button = row["sell_button"]
		sell_button.disabled = on_board <= 0


## Gruen heisst immer: gut fuer den Spieler. Beim Kauf ist das ein niedriger
## Preis, beim Verkauf ein hoher.
##
## Die Gegenrichtung wird abgeblendet statt rot eingefaerbt. Rot ist im Spiel
## die Farbe fuer Schaden und Gefahr - ein maessiger Tabakpreis ist keine
## Gefahr, und zwoelf rote Zahlen in einer Liste laesst die Farbe ihre
## Bedeutung verlieren. Siehe RICHTLINIEN A4.
func _price_color(price: int, base_price: int, buying: bool) -> Color:
	var ratio := float(price) / float(maxi(base_price, 1))
	var good := ratio <= BARGAIN if buying else ratio >= STEEP
	var poor := ratio >= STEEP if buying else ratio <= BARGAIN
	if good:
		return Palette.GOOD
	return Palette.fade(Palette.HUD_DIM, 0.45) if poor else Palette.HUD_TEXT


func _on_amount_pressed(index: int) -> void:
	_amount_index = index
	_highlight_amount()


func _highlight_amount() -> void:
	for i in _amount_buttons.size():
		var chosen := i == _amount_index
		_amount_buttons[i].add_theme_color_override(
			"font_color", Palette.BRASS if chosen else Palette.MUTED
		)


func _on_buy_pressed(cargo: CargoType) -> void:
	var wanted := AMOUNTS[_amount_index]
	var possible := Trade.max_buyable(town, cargo)
	var amount := possible if wanted < 0 else mini(wanted, possible)

	if amount <= 0:
		traded.emit(_refusal(cargo))
		return

	var cost := town.buy_cost(cargo, amount)
	Trade.buy(town, cargo, amount)
	refresh()
	traded.emit("%d %s gekauft für %d Gold." % [amount, cargo.display_name, cost])


func _on_sell_pressed(cargo: CargoType) -> void:
	var wanted := AMOUNTS[_amount_index]
	var owned := GameState.cargo_of(cargo.id)
	var amount := owned if wanted < 0 else mini(wanted, owned)

	if amount <= 0:
		traded.emit("Du hast kein %s an Bord." % cargo.display_name)
		return

	var revenue := town.sell_revenue(cargo, amount)
	Trade.sell(town, cargo, amount)
	refresh()
	traded.emit("%d %s verkauft für %d Gold." % [amount, cargo.display_name, revenue])


## Warum der Kauf nicht ging. Drei Gruende, und der Spieler soll wissen, welcher.
func _refusal(cargo: CargoType) -> String:
	if town.available(cargo.id) <= 0:
		return "%s ist hier ausverkauft." % cargo.display_name
	if GameState.cargo_free() < cargo.unit_size:
		return "Der Laderaum ist voll."
	return "Dafür reicht das Gold nicht."


func _header(text: String) -> Label:
	var node := PortWidgets.label(text, Palette.MUTED, 13)
	node.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if text == "Ware" else HORIZONTAL_ALIGNMENT_RIGHT
	)
	return node
