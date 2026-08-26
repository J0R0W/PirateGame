## Die Preisbildung - reine Mathematik, ohne Nodes und ohne Autoloads.
##
## Ein Preis entsteht aus einer einzigen Groesse: dem Lagerbestand einer Stadt
## im Verhaeltnis zu ihrem Umschlag. Volles Lager heisst billig, leeres Lager
## heisst teuer. Alles andere - Produktion, Nachfrage, Stadtgroesse - wirkt nur
## darueber, indem es den Bestand verschiebt.
##
## Bewusst KEINE Buchhaltung mit Waren, die von Stadt zu Stadt wandern. Solche
## Modelle kippen: Entweder ersaeuft die Karibik in Zucker oder alle Lager sind
## nach zwei Wochen leer, und man verbringt den Rest des Projekts damit,
## Zahlen nachzuregeln. Hier laeuft jeder Bestand auf seinen natuerlichen Wert
## zu (siehe [method relax]), und der Spieler stoert diesen Zustand.
class_name TradeMath
extends RefCounted

## Spanne zwischen Kauf- und Verkaufspreis, aufgeteilt auf beide Seiten.
## Ohne sie waere sofortiges Kaufen und Zurueckverkaufen kostenlos, und der
## Markt liesse sich als Sparbuch missbrauchen.
const SPREAD: float = 0.12

## Wie stark der Preis auf Knappheit reagiert. 0.5 heisst: viertel Bestand,
## doppelter Preis.
const SCARCITY_EXPONENT: float = 0.5

## Kleinster Umschlag, mit dem gerechnet wird. Eine Stadt, die eine Ware weder
## erzeugt noch braucht, handelt sie trotzdem - nur in kleiner Menge.
const MIN_REFERENCE: float = 12.0

## Verhaeltnis Bestand zu Umschlag, auf das eine Stadt zulaeuft.
const SURPLUS_RATIO: float = 3.0
const NEUTRAL_RATIO: float = 1.0
const SCARCITY_RATIO: float = 0.25

## Nach so vielen Tagen hat sich ein gestoerter Bestand zu rund zwei Dritteln
## erholt.
const RECOVERY_DAYS: float = 4.0

## Untergrenze fuer das Bestandsverhaeltnis. Ohne sie geht der Preis bei
## leerem Lager gegen unendlich.
const MIN_RATIO: float = 0.05


## Umschlag einer Ware pro Woche. Produktion und Verbrauch gehen beide ein -
## eine Stadt, die viel bewegt, hat auch ein grosses Lager.
static func reference_stock(production: float, demand: float) -> float:
	return MIN_REFERENCE + maxf(production, 0.0) + maxf(demand, 0.0)


## Der Bestand, auf den eine Stadt ohne Zutun des Spielers zulaeuft.
static func target_stock(production: float, demand: float) -> float:
	var reference := reference_stock(production, demand)
	if production > 0.0:
		return reference * SURPLUS_RATIO
	if demand > 0.0:
		return reference * SCARCITY_RATIO
	return reference * NEUTRAL_RATIO


## Laesst einen Bestand ueber [param days] Tage auf [param target] zulaufen.
##
## Exponentiell, nicht linear: Der Schritt haengt nur von der verstrichenen
## Zeit ab, nicht davon, in wie vielen Teilschritten sie verrechnet wurde.
static func relax(stock: float, target: float, days: float) -> float:
	if days <= 0.0:
		return stock
	return lerpf(stock, target, 1.0 - exp(-days / RECOVERY_DAYS))


## Preisfaktor auf den Basispreis. 1.0 bei ausgeglichenem Lager.
static func price_multiplier(stock: float, reference: float, volatility: float) -> float:
	var ratio := maxf(stock, 0.0) / maxf(reference, MIN_REFERENCE)
	var raw := pow(maxf(ratio, MIN_RATIO), -SCARCITY_EXPONENT)
	# Knappheit darf staerker ausschlagen als Ueberfluss: Ein leeres Lager
	# kennt keine Obergrenze, ein volles hoert bei "geschenkt" auf.
	return clampf(raw, 1.0 - volatility, 1.0 + volatility * 2.0)


## Marktpreis einer Ware ohne Handelsspanne.
static func market_price(base_price: int, stock: float, reference: float, volatility: float) -> float:
	return float(base_price) * price_multiplier(stock, reference, volatility)


## Was der Spieler pro Einheit zahlt.
static func unit_buy_price(base_price: int, stock: float, reference: float, volatility: float) -> int:
	return maxi(1, int(ceil(market_price(base_price, stock, reference, volatility) * (1.0 + SPREAD * 0.5))))


## Was der Spieler pro Einheit bekommt.
static func unit_sell_price(base_price: int, stock: float, reference: float, volatility: float) -> int:
	return maxi(1, int(floor(market_price(base_price, stock, reference, volatility) * (1.0 - SPREAD * 0.5))))


## Kosten fuer [param amount] Einheiten, Stueck fuer Stueck gerechnet.
##
## Jede gekaufte Einheit senkt den Bestand und hebt damit den Preis der
## naechsten. Deshalb wird nicht multipliziert, sondern summiert: Wer den Markt
## leerkauft, zahlt fuer die letzten Einheiten deutlich mehr - der Handel
## begrenzt sich selbst, ohne dass eine Obergrenze noetig waere.
static func buy_cost(base_price: int, stock: float, reference: float, volatility: float, amount: int) -> int:
	var total := 0
	var remaining := stock
	for i in maxi(amount, 0):
		total += unit_buy_price(base_price, remaining, reference, volatility)
		remaining = maxf(remaining - 1.0, 0.0)
	return total


## Erloes fuer [param amount] Einheiten, Stueck fuer Stueck gerechnet.
static func sell_revenue(base_price: int, stock: float, reference: float, volatility: float, amount: int) -> int:
	var total := 0
	var remaining := stock
	for i in maxi(amount, 0):
		total += unit_sell_price(base_price, remaining, reference, volatility)
		remaining += 1.0
	return total
