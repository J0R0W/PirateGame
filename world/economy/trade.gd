## Der Handel selbst: Gold gegen Ware, Ware gegen Gold.
##
## Die Preise stehen in TradeMath, die Bestaende in TownData, das Gold und der
## Laderaum in GameState. Hier laufen die drei zusammen - und zwar an genau
## einer Stelle, damit Marktbildschirm, Schmuggel und spaeter die KI dieselben
## Regeln benutzen.
##
## Jede Funktion gibt die tatsaechlich gehandelte Menge zurueck. Sie kann
## kleiner sein als gewuenscht: Gold, Laderaum und Lagerbestand begrenzen den
## Handel unabhaengig voneinander, und ein halb ausgefuehrter Kauf ist besser
## als eine Fehlermeldung.
class_name Trade
extends RefCounted


## Wieviel Einheiten der Spieler hier hoechstens kaufen kann.
##
## Der Preis steigt mit jeder Einheit, deshalb wird nicht durch den
## Stueckpreis geteilt, sondern hochgezaehlt, bis das Gold nicht mehr reicht.
static func max_buyable(town: TownData, cargo: CargoType) -> int:
	var by_stock := town.available(cargo.id)
	var by_hold := GameState.cargo_free() / maxi(cargo.unit_size, 1)
	var limit := mini(by_stock, by_hold)

	var affordable := 0
	while affordable < limit and town.buy_cost(cargo, affordable + 1) <= GameState.gold:
		affordable += 1
	return affordable


static func max_sellable(town: TownData, cargo: CargoType) -> int:
	return GameState.cargo_of(cargo.id)


## Kauft bis zu [param amount] Einheiten. Gibt die gekaufte Menge zurueck.
static func buy(town: TownData, cargo: CargoType, amount: int) -> int:
	var actual := mini(maxi(amount, 0), max_buyable(town, cargo))
	if actual <= 0:
		return 0

	var cost := town.buy_cost(cargo, actual)
	GameState.add_gold(-cost)
	GameState.add_cargo(cargo.id, actual)
	town.take_stock(cargo.id, actual)

	EventBus.trade_completed.emit(town.id, cargo.id, actual, -cost)
	return actual


## Verkauft bis zu [param amount] Einheiten. Gibt die verkaufte Menge zurueck.
static func sell(town: TownData, cargo: CargoType, amount: int) -> int:
	var actual := mini(maxi(amount, 0), max_sellable(town, cargo))
	if actual <= 0:
		return 0

	var revenue := town.sell_revenue(cargo, actual)
	GameState.add_gold(revenue)
	GameState.add_cargo(cargo.id, -actual)
	town.add_stock(cargo.id, actual)

	EventBus.trade_completed.emit(town.id, cargo.id, -actual, revenue)
	return actual
