## Eine Stadt auf der generierten Karte.
##
## Wird zur Laufzeit vom WorldGenerator erzeugt (M2), nicht von Hand angelegt.
## Deshalb Variablen statt @export - im Editor gibt es nichts einzustellen.
class_name TownData
extends Resource

var id: int = 0
var town_name: String = ""
## Position auf der Weltkarte in Metern.
var position: Vector2 = Vector2.ZERO
var nation_id: int = 0
## Auf welcher Landmasse liegt die Stadt?
var island_id: int = 0

## 0 = Dorf, 1 = Stadt, 2 = Kolonialhauptstadt. Steuert Angebot und Garnison.
var size_tier: int = 0

const TIER_NAMES: PackedStringArray = ["Dorf", "Stadt", "Hauptstadt"]

func tier_name() -> String:
	return TIER_NAMES[clampi(size_tier, 0, TIER_NAMES.size() - 1)]
## Staerke der Hafenbefestigung, 0 = wehrlos.
var fort_strength: int = 0

## CargoType-Name -> Menge pro Woche. Erzeugt profitable Handelsrouten.
var production: Dictionary = {}
var demand: Dictionary = {}
## CargoType-Name -> aktueller Lagerbestand.
var stock: Dictionary = {}

## Wurde die Stadt vom Spieler schon besucht? Steuert die Kartenanzeige.
var discovered: bool = false
