## Die Werft: Schaden gegen Gold.
##
## Reparieren ist die laufende Ausgabe im Spiel. Sie ist absichtlich teuer
## genug, dass unvorsichtiges Segeln einen Handelsgewinn auffressen kann -
## sonst waere das Auflaufen auf eine Untiefe nur eine Verzoegerung.
##
## Am Kai wird auch angeheuert. Das gehoert eigentlich in die Taverne (M6),
## steht aber schon hier, weil ein Gefecht seit M4 Leute kostet und es sonst
## keinen Weg zurueck gaebe: Wer zweimal kaempft, faehrt danach dauerhaft mit
## halber Mannschaft, laedt langsamer und trifft schlechter. Eine Sackgasse
## ohne Ausweg ist kein System, sondern ein Fehler.
class_name Shipyard
extends RefCounted

## Gold je Punkt Schaden.
const HULL_COST: int = 14
const SAILS_COST: int = 7
## Handgeld je Mann. Teurer als ein Punkt Rumpf: Eine Mannschaft ersetzt man
## nicht nebenbei, und Kartaetschen sollen wehtun.
const CREW_COST: int = 26

## Rabatt je Stadtstufe. Eine Hauptstadt hat Trockendocks, ein Dorf einen
## Zimmermann.
const TIER_DISCOUNT: float = 0.12


static func price_factor(town: TownData) -> float:
	return 1.0 - TIER_DISCOUNT * float(clampi(town.size_tier, 0, 2))


## Was die vollstaendige Instandsetzung kostet.
static func full_repair_cost(town: TownData) -> int:
	var hull_missing := GameState.max_hull() - GameState.hull
	var sails_missing := GameState.max_sails() - GameState.sails
	return repair_cost(town, hull_missing, sails_missing)


static func repair_cost(town: TownData, hull_points: int, sails_points: int) -> int:
	var raw := maxi(hull_points, 0) * HULL_COST + maxi(sails_points, 0) * SAILS_COST
	return int(ceil(float(raw) * price_factor(town)))


## Repariert, soweit das Gold reicht. Gibt die bezahlte Summe zurueck.
##
## Teilreparatur statt Alles-oder-nichts: Wer mit 40 Gold und einem Leck in
## einen Hafen kriecht, soll die 40 Gold verbauen koennen.
static func repair(town: TownData) -> int:
	var full := full_repair_cost(town)
	if full <= 0:
		return 0

	if GameState.gold >= full:
		GameState.hull = GameState.max_hull()
		GameState.sails = GameState.max_sails()
		GameState.add_gold(-full)
		EventBus.ship_repaired.emit(town.id, full)
		return full

	# Anteilig: Der Rumpf zuerst, er haelt das Schiff schwimmend.
	var budget := GameState.gold
	var factor := price_factor(town)
	var hull_points := mini(
		GameState.max_hull() - GameState.hull,
		int(floor(float(budget) / (float(HULL_COST) * factor)))
	)
	var spent := repair_cost(town, hull_points, 0)
	var sails_points := mini(
		GameState.max_sails() - GameState.sails,
		int(floor(float(budget - spent) / (float(SAILS_COST) * factor)))
	)
	spent = repair_cost(town, hull_points, sails_points)
	if spent <= 0:
		return 0

	GameState.hull = GameState.hull + hull_points
	GameState.sails = GameState.sails + sails_points
	GameState.add_gold(-spent)
	EventBus.ship_repaired.emit(town.id, spent)
	return spent


# --- Mannschaft ------------------------------------------------------------

## Wieviel Leute an Bord fehlen.
static func crew_missing() -> int:
	return maxi(GameState.max_crew() - GameState.crew, 0)


static func hire_cost(town: TownData, count: int) -> int:
	return int(ceil(float(maxi(count, 0) * CREW_COST) * price_factor(town)))


## Was es kostet, wieder voll zu besetzen.
static func full_hire_cost(town: TownData) -> int:
	return hire_cost(town, crew_missing())


## Heuert an, soweit das Gold reicht. Gibt die Zahl der neuen Leute zurueck.
##
## Wie bei der Reparatur: kein Alles-oder-nichts. Drei Mann sind besser als
## keiner, und wer knapp bei Kasse aus einem Gefecht kommt, soll wenigstens
## anfangen koennen.
static func hire(town: TownData) -> int:
	var wanted := crew_missing()
	if wanted <= 0:
		return 0

	var factor := price_factor(town)
	var affordable := int(floor(float(GameState.gold) / (float(CREW_COST) * factor)))
	var count := mini(wanted, affordable)
	if count <= 0:
		return 0

	GameState.add_gold(-hire_cost(town, count))
	GameState.crew = GameState.crew + count
	EventBus.crew_hired.emit(town.id, count)
	return count
