## Die Schenke: Leute und Gerede.
##
## Anheuern stand seit M4 in der Werft, und der Kommentar dort sagte selbst,
## dass es dorthin nicht gehoert - es stand da, weil ein Gefecht Leute kostet
## und es sonst keinen Weg zurueck gegeben haette. Hier steht es richtig und
## bekommt zugleich das, was ihm in der Werft fehlte: einen Grund, warum es
## einmal mehr und einmal weniger kostet.
##
## Der zweite Teil ist das Gerede. Es ist kein Beiwerk: Bis hierher wurde ein
## benannter Gegner einfach in Sichtweite gesetzt, egal wo man fuhr - man
## konnte einen Auftrag nicht *suchen*, nur abwarten. Der Wirt sagt, vor
## welchem Hafen der Gesuchte kreuzt, und macht daraus eine Fahrt mit Ziel.
##
## Nodefrei und statisch (Regel B3): Handgeld und Handelstipp sind Rechnungen,
## keine Szenen.
class_name Tavern
extends RefCounted

## Handgeld je Mann.
##
## Teurer als ein Punkt Rumpf ([constant Shipyard.HULL_COST]): Eine Mannschaft
## ersetzt man nicht nebenbei, und Kartaetschen sollen wehtun.
const CREW_COST: int = 26

## Nachlass je Stadtstufe. In einer Hauptstadt liegen mehr Leute ohne Heuer
## herum als in einem Dorf.
const TIER_DISCOUNT: float = 0.10

## Und soviel guenstiger heuert ein Kapitaen an, der in aller Munde ist.
##
## Bei voller Beruechtigtheit ein gutes Drittel. Das ist die Stelle, an der
## Beruechtigtheit zum ersten Mal etwas *fuer* den Spieler tut: Bis hierher hat
## sie ihm Gegner muerbe gemacht ([method Gunnery.will_strike]) und Jaeger
## geschickt ([Bounty]) - eine Achse, die nur kostet, ist so wenig eine
## Entscheidung wie eine, die nur hilft.
const FAME_DISCOUNT: float = 0.35

## Soweit hoert ein Wirt hinaus, in Metern.
##
## Ein knappes Viertel der Weltkante ([constant WorldData.WORLD_SIZE]). Was am
## anderen Ende der Karibik gezahlt wird, erfaehrt man nicht in einer Schenke -
## und ein Tipp, dem nachzufahren eine Stunde kostet, ist keiner.
const GOSSIP_RANGE: float = 5000.0

## Soviel muss eine Stadt von einer Ware haben, damit der Wirt sie erwaehnt.
##
## Ein Gerucht ueber drei Fass ist keines: Wer hinfaehrt, soll den Laderaum
## voll bekommen.
const GOSSIP_STOCK: int = 10


## Was ein Mann hier kostet, als Faktor auf das Handgeld.
##
## Zwei Gruende, und beide heissen Zulauf: In einer grossen Stadt suchen mehr
## Leute eine Heuer, und zu einem beruechtigten Kapitaen kommen sie von selbst -
## wer Prisen macht, teilt Beute.
static func price_factor(town: TownData, notoriety: int) -> float:
	var tier := 1.0 - TIER_DISCOUNT * float(clampi(town.size_tier, 0, 2))
	var fame := 1.0 - FAME_DISCOUNT * (float(clampi(notoriety, 0, 100)) / 100.0)
	return tier * fame


## Wieviele Leute an Bord fehlen.
static func crew_missing() -> int:
	return maxi(GameState.max_crew() - GameState.crew, 0)


static func hire_cost(town: TownData, count: int) -> int:
	return int(ceil(
		float(maxi(count, 0) * CREW_COST) * price_factor(town, GameState.notoriety)
	))


## Was es kostet, wieder voll zu besetzen.
static func full_hire_cost(town: TownData) -> int:
	return hire_cost(town, crew_missing())


## Heuert an, soweit das Gold reicht. Gibt die Zahl der neuen Leute zurueck.
##
## Wie bei der Reparatur kein Alles-oder-nichts: Drei Mann sind besser als
## keiner, und wer knapp bei Kasse aus einem Gefecht kommt, soll wenigstens
## anfangen koennen.
static func hire(town: TownData) -> int:
	var wanted := crew_missing()
	if wanted <= 0:
		return 0

	var per_head := float(CREW_COST) * price_factor(town, GameState.notoriety)
	var affordable := int(floor(float(GameState.gold) / per_head))
	var count := mini(wanted, affordable)
	if count <= 0:
		return 0

	GameState.add_gold(-hire_cost(town, count))
	GameState.crew = GameState.crew + count
	EventBus.crew_hired.emit(town.id, count)
	return count


# --- Gerede ----------------------------------------------------------------

## Der Handelstipp: welche Ware in welchem Nachbarhafen gut bezahlt wird.
##
## Gibt [code]{"town": TownData, "cargo": CargoType, "profit": int}[/code]
## zurueck, oder ein leeres Woerterbuch, wenn es nichts zu holen gibt.
##
## Gesucht wird der groesste Aufschlag auf das, was *hier* zu haben ist. Ein
## Gerucht ueber einen Hafen, in dem Zucker teuer ist, nuetzt nichts, wenn hier
## kein Zucker liegt - der Tipp muss ein Geschaeft sein, kein Preisvergleich.
##
## Die Stadtliste kommt von aussen, damit die Rechnung ohne [WorldData] zu
## pruefen ist (Regel B3).
static func trade_tip(here: TownData, towns: Array[TownData]) -> Dictionary:
	var best := {}
	var best_profit := 0
	if here == null:
		return best

	for cargo: CargoType in CargoRegistry.all():
		if here.available(cargo.id) < GOSSIP_STOCK:
			continue
		var cost := here.buy_price(cargo)
		for town: TownData in towns:
			if town.id == here.id:
				continue
			if here.position.distance_to(town.position) > GOSSIP_RANGE:
				continue
			var profit := town.sell_price(cargo) - cost
			if profit > best_profit:
				best_profit = profit
				best = {"town": town, "cargo": cargo, "profit": profit}

	return best
