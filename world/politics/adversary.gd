## Ein benannter Gegner: ein Kapitaen mit Namen auf einem bestimmten Schiff.
##
## Bis hierher kam jedes fremde Segel aus dem Zufall - eine Handelsbrigg oder
## eine Patrouille, benannt aus einer Liste, ohne Vorgeschichte. Ein Auftrag des
## Gouverneurs und ein Kopfgeldjaeger brauchen das Gegenteil: ein Schiff, das
## schon feststand, bevor es auf See lag, und das man wiedererkennt, wenn es
## auftaucht.
##
## Genau das ist der gemeinsame Kern von [Commission] und [Bounty] - einmal ist
## der Benannte die Beute, einmal der Verfolger. Deshalb steht er hier fuer sich
## und nicht in einem von beiden.
##
## Daten und kein Node (Regel B3): Der Steckbrief im Palast, die Meldung im HUD
## und das Schiff auf See lesen dieselbe Beschreibung, und sie muss das
## Speichern ueberstehen - ein Node ueberlebt nicht einmal den Szenenwechsel in
## den Hafen.
class_name Adversary
extends RefCounted

## Wenn eine Nation keine Kapitaensnamen hinterlegt hat. Sollte nicht
## vorkommen, ist aber besser als ein leerer Steckbrief.
const UNNAMED: String = "Ein namenloser Kapitän"

var captain_name: String = UNNAMED
var ship_name: String = "Namenlos"
## Unter welcher Flagge er faehrt.
var nation_id: int = -1
## Pfad zur Schiffsklasse. Der Pfad und nicht die geladene Ressource: So laesst
## sich ein Gegner speichern, ohne die .tres-Datei mit in den Spielstand zu
## schreiben.
var ship_class_path: String = ""
## Sucht er den Spieler von sich aus?
##
## Ein Kopfgeldjaeger ja - er ist genau dafuer ausgelaufen. Ein Auftragsziel
## nicht: Es faehrt seiner Wege und wehrt sich erst, wenn ihm jemand in die
## Quere kommt. Das ist der einzige Unterschied im Verhalten zwischen den
## beiden, alles andere ist die Frage, wer ihn benannt hat.
var hunts: bool = false


## Wuerfelt einen benannten Kapitaen fuer eine Nation aus.
##
## [param rng] wird von aussen gestellt: Ein Auftrag soll bei jedem Blick in den
## Palast derselbe sein (siehe [method Commission.offer]), ein Kopfgeldjaeger
## darf jedes Mal ein anderer sein.
static func make(
	rng: RandomNumberGenerator,
	nation: NationData,
	class_path: String,
	hunting: bool
) -> Adversary:
	var who := Adversary.new()
	who.nation_id = nation.id if nation != null else -1
	who.ship_class_path = class_path
	who.hunts = hunting
	if nation != null and not nation.captain_names.is_empty():
		who.captain_name = nation.captain_names[rng.randi() % nation.captain_names.size()]
	if nation != null and not nation.ship_names.is_empty():
		who.ship_name = nation.ship_names[rng.randi() % nation.ship_names.size()]
	return who


## Wie er im Palast, im HUD und auf der Seekarte heisst.
##
## Kapitaen und Schiff nebeneinander statt "Kapitaen X auf der Y": Der deutsche
## Artikel vor einem Schiffsnamen geht bei "Le Corsaire" oder "De Zeeleeuw"
## schief, und der Mittelpunkt ist ohnehin die Schreibweise des uebrigen HUD.
func title() -> String:
	return "Kapitän %s   ·   %s" % [captain_name, ship_name]


## Ist dieses Schiff der Benannte?
##
## Ueber Name und Flagge und nicht ueber die Objektidentitaet: Der Gegner wird
## gesetzt, versenkt und spaeter neu gesetzt, und ein Auftrag muss auch dann
## noch gelten, wenn zwischendurch ein Hafen besucht wurde und der alte Node
## laengst weg ist.
func is_ship(other_captain: String, other_nation: int) -> bool:
	return (
		not other_captain.is_empty()
		and other_captain == captain_name
		and other_nation == nation_id
	)


func to_dict() -> Dictionary:
	return {
		"captain": captain_name,
		"ship": ship_name,
		"nation": nation_id,
		"class": ship_class_path,
		"hunts": hunts,
	}


static func from_dict(data: Dictionary) -> Adversary:
	var who := Adversary.new()
	who.captain_name = str(data.get("captain", UNNAMED))
	who.ship_name = str(data.get("ship", "Namenlos"))
	who.nation_id = int(data.get("nation", -1))
	who.ship_class_path = str(data.get("class", ""))
	who.hunts = bool(data.get("hunts", false))
	return who
