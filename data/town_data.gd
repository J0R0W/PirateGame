## Eine Stadt auf der generierten Karte.
##
## Wird zur Laufzeit vom WorldGenerator erzeugt, nicht von Hand angelegt.
## Deshalb Variablen statt @export - im Editor gibt es nichts einzustellen.
class_name TownData
extends Resource

const TIER_NAMES: PackedStringArray = ["Dorf", "Stadt", "Hauptstadt"]

var id: int = 0
var town_name: String = ""
## Position auf der Weltkarte in Metern.
var position: Vector2 = Vector2.ZERO
var nation_id: int = 0
## Auf welcher Landmasse liegt die Stadt?
var island_id: int = 0

## 0 = Dorf, 1 = Stadt, 2 = Kolonialhauptstadt. Steuert Angebot und Garnison.
var size_tier: int = 0

## Staerke der Hafenbefestigung, 0 = wehrlos.
var fort_strength: int = 0

## Waren-Id -> Menge pro Woche. Erzeugt profitable Handelsrouten.
var production: Dictionary = {}
var demand: Dictionary = {}
## Waren-Id -> aktueller Lagerbestand. Der einzige Wert, der sich im Spiel
## aendert - Produktion und Nachfrage stehen fest.
var stock: Dictionary = {}

## Hoehe der Terrasse, auf der die Stadt liegt - in Hoeheneinheiten wie
## [method WorldGenerator.height_at]. Der Generator ebnet das Gelaende im
## Umkreis darauf ein, damit Haeuser nicht an einem Steilhang kleben.
var terrace_height: float = 0.0

## Wurde die Stadt vom Spieler schon besucht? Steuert die Kartenanzeige.
var discovered: bool = false


func tier_name() -> String:
	return TIER_NAMES[clampi(size_tier, 0, TIER_NAMES.size() - 1)]


# --- Markt -----------------------------------------------------------------
#
# Die Stadt haelt die Bestaende, die Preisformel steht in TradeMath. Hier
# steckt nur die Verdrahtung: Welche Zahlen gehoeren zu welcher Ware?

func stock_of(cargo_id: StringName) -> float:
	return float(stock.get(cargo_id, 0.0))


func production_of(cargo_id: StringName) -> float:
	return float(production.get(cargo_id, 0.0))


func demand_of(cargo_id: StringName) -> float:
	return float(demand.get(cargo_id, 0.0))


func reference_stock(cargo_id: StringName) -> float:
	return TradeMath.reference_stock(production_of(cargo_id), demand_of(cargo_id))


func target_stock(cargo_id: StringName) -> float:
	return TradeMath.target_stock(production_of(cargo_id), demand_of(cargo_id))


## Was der Spieler hier pro Einheit zahlt.
func buy_price(cargo: CargoType) -> int:
	return TradeMath.unit_buy_price(
		cargo.base_price, stock_of(cargo.id), reference_stock(cargo.id), cargo.price_volatility
	)


## Was der Spieler hier pro Einheit bekommt.
func sell_price(cargo: CargoType) -> int:
	return TradeMath.unit_sell_price(
		cargo.base_price, stock_of(cargo.id), reference_stock(cargo.id), cargo.price_volatility
	)


func buy_cost(cargo: CargoType, amount: int) -> int:
	return TradeMath.buy_cost(
		cargo.base_price, stock_of(cargo.id), reference_stock(cargo.id),
		cargo.price_volatility, amount
	)


func sell_revenue(cargo: CargoType, amount: int) -> int:
	return TradeMath.sell_revenue(
		cargo.base_price, stock_of(cargo.id), reference_stock(cargo.id),
		cargo.price_volatility, amount
	)


## Wieviel Einheiten die Stadt ueberhaupt abgeben kann.
func available(cargo_id: StringName) -> int:
	return int(floor(stock_of(cargo_id)))


func take_stock(cargo_id: StringName, amount: int) -> void:
	stock[cargo_id] = maxf(stock_of(cargo_id) - float(amount), 0.0)


func add_stock(cargo_id: StringName, amount: int) -> void:
	stock[cargo_id] = stock_of(cargo_id) + float(amount)


## Laesst alle Bestaende um [param days] Tage altern.
func advance_economy(days: float) -> void:
	for cargo_id: StringName in stock:
		stock[cargo_id] = TradeMath.relax(stock_of(cargo_id), target_stock(cargo_id), days)


## Handelt die Stadt diese Ware im Ueberfluss? Faerbt die Marktliste ein.
func is_producer(cargo_id: StringName) -> bool:
	return production_of(cargo_id) > 0.0


func is_consumer(cargo_id: StringName) -> bool:
	return demand_of(cargo_id) > 0.0
