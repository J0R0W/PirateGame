## Wer mit wem Krieg fuehrt - und was das fuer einen Kaperfahrer heisst.
##
## Bis hierher standen die vier Kronen in keinem Verhaeltnis zueinander. Ein
## Kaperbrief deckte alles ausser der eigenen Flagge, und welche Krone ein
## Auftrag traf, entschied der Wuerfel. An beiden Stellen stand seit M6 ein
## Kommentar, dass hier eigentlich der Krieg entscheiden muesste
## ([method LetterOfMarque.covers], [method Commission.offer]).
##
## Genau das tut er jetzt. Zwischen zwei Kronen gibt es Krieg oder Frieden, und
## zu jeder Zeit liegt **jede Krone mit genau einer anderen im Krieg**. Vier
## Nationen lassen sich auf genau drei Arten so paaren; die politische Lage ist
## immer eine dieser drei.
##
## Das ist bewusst enger als "jeder gegen jeden nach Wuerfel", und zwar an
## beiden Enden:
##   - Ein allgemeiner Friede wuerde Kaperbrief und Auftrag abschalten, also
##     das halbe Spiel - und der Spieler haette nichts in der Hand dagegen.
##   - Ein allgemeiner Krieg waere der Zustand von vorher: Ein Brief, der alles
##     deckt, ist keine Entscheidung, sondern ein Freibrief.
## Die Paarung ist die interessante Mitte. Der Brief deckt genau eine Flagge,
## und welche das ist, sucht man sich mit dem Patron aus.
##
## Gerechnet und nicht gehalten, wie der Steckbrief in [Commission]: Die Lage
## ist eine reine Funktion aus Weltseed und Spieltag. Damit steht sie in keinem
## Spielstand, kann mit keinem auseinanderlaufen und ist ohne Szene pruefbar
## (Regel B3).
class_name Diplomacy
extends RefCounted

## Soviele Spieltage bleibt eine Lage bestehen.
##
## Dreimal die Frist eines Auftrags ([constant Commission.DAYS]): Ein Krieg
## soll die Jagd ueberdauern, die unter ihm begonnen wurde. Bei gleicher
## Groessenordnung waere jeder zweite Auftrag beim Einlaufen nicht mehr
## gedeckt, und der Spieler koennte nichts dagegen tun.
##
## In Echtzeit sind das rund anderthalb Stunden ([constant
## GameState.MINUTES_PER_SECOND]) - selten genug, dass eine Umwaelzung eine
## Nachricht ist, haeufig genug, dass ein langer Lauf sie erlebt.
const ERA_DAYS: int = 24

## Die drei moeglichen Lagen, je als "diese Nation liegt mit jener im Krieg".
##
## Der Index in einer Zeile ist die Nations-Id ([enum GameState.Nation]:
## 0 Spanien, 1 England, 2 Frankreich, 3 Niederlande), der Wert die Id des
## Gegners. Jede Zeile ist ihre eigene Umkehrung - wenn England Spanien als
## Feind hat, hat Spanien England. Der Rauchtest haelt das fest; von Hand
## verdreht man so eine Tabelle schnell.
const PAIRINGS: Array = [
	[1, 0, 3, 2],
	[2, 3, 0, 1],
	[3, 2, 1, 0],
]


## Der wievielte Zeitabschnitt an diesem Spieltag laeuft.
static func era_of(day: int) -> int:
	return maxi(day, 0) / ERA_DAYS


## Der erste Tag des Abschnitts, der an diesem Tag laeuft.
static func era_start(day: int) -> int:
	return era_of(day) * ERA_DAYS


## Wieviele Tage die jetzige Lage noch haelt. Nie null - am letzten Tag ist es
## noch einer.
static func days_left(day: int) -> int:
	return era_start(day) + ERA_DAYS - maxi(day, 0)


## Welche der drei Lagen in diesem Abschnitt gilt.
##
## Schrittweise vom ersten Abschnitt an gerechnet statt frei gewuerfelt: Der
## Schritt ist immer eins oder zwei, nie null. Damit ist die Lage nach einer
## Umwaelzung garantiert eine andere - eine Neuordnung, die alles beim Alten
## laesst, waere eine Meldung ueber nichts.
##
## Die Schleife kostet einen Durchgang je Abschnitt. Ein Jahr Spielzeit sind
## fuenfzehn davon; das faellt neben einer einzigen Wellenhoehe nicht auf.
static func pairing_index(world_seed: int, era: int) -> int:
	var index := absi(hash("%d/pairings" % world_seed)) % PAIRINGS.size()
	for step in range(1, maxi(era, 0) + 1):
		var jump := 1 + absi(hash("%d/%d" % [world_seed, step])) % (PAIRINGS.size() - 1)
		index = (index + jump) % PAIRINGS.size()
	return index


## Mit welcher Krone diese am gegebenen Tag Krieg fuehrt, oder -1.
static func enemy_of(world_seed: int, day: int, nation_id: int) -> int:
	var row: Array = PAIRINGS[pairing_index(world_seed, era_of(day))]
	if nation_id < 0 or nation_id >= row.size():
		return -1
	return int(row[nation_id])


## Liegen diese beiden im Krieg?
static func at_war(world_seed: int, day: int, a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and enemy_of(world_seed, day, a) == b


## Die beiden Kriege einer Lage, als Paare von Nations-Ids.
##
## Fuer die Anzeige: Seekarte und Schenke zaehlen sie auf, statt jede Nation
## einzeln zu fragen und dabei jeden Krieg zweimal zu nennen. Die kleinere Id
## steht vorn, damit die Reihenfolge nicht vom Zufall abhaengt.
static func wars(world_seed: int, day: int) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	var row: Array = PAIRINGS[pairing_index(world_seed, era_of(day))]
	for id in row.size():
		var other := int(row[id])
		if id < other:
			pairs.append(Vector2i(id, other))
	return pairs
