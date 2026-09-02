## Der Auftrag eines Gouverneurs: Bring mir diesen Mann.
##
## Der Kaperbrief hat aus dem Verfall der Ansehensskala eine Entscheidung
## gemacht, aber er zaehlte nur mit: [member GameState.letter_prizes] stand im
## Palast und hing an nichts. Ein Auftrag ist das, woran er haengt - der Brief
## ist die Erlaubnis, der Auftrag der Grund.
##
## Und er ist die erste Schleife im Spiel, die nicht auf See endet: Der
## Gouverneur zahlt, nicht die See. Wer den Benannten aufgebracht hat, muss
## zurueck in einen Hafen seiner Krone und Bericht erstatten. Vorher ist der
## Auftrag getan, aber nicht bezahlt.
##
## Nodefrei und statisch pruefbar wie [Standing] und [LetterOfMarque]
## (Regel B3).
class_name Commission
extends RefCounted


## Was sich am Auftrag geaendert hat. Geht als [signal EventBus.commission_changed]
## hinaus.
##
## Eine Aufzaehlung statt vier Signalen: Es ist derselbe Auftrag, und wer ihn
## anzeigt - Palast, HUD, Seekarte - will bei jeder Aenderung dasselbe tun,
## naemlich neu zeichnen. Nur die Meldezeile auf See unterscheidet.
enum Change { ACCEPTED, FULFILLED, REPORTED, FAILED }

## Der erste Auftrag bringt soviel Gold, ...
const REWARD_BASE: int = 400
## ... und jeder eingeloeste danach soviel mehr.
##
## Der Gouverneur traut einem mit jedem Bericht mehr zu. Das ist die einzige
## Befoerderung, die es vor den Offizieren (Tier 1) gibt.
const REWARD_STEP: int = 250
## Obergrenze, damit ein langer Lauf nicht in Gold ertrinkt.
const REWARD_MAX: int = 2400

## Was der Patron fuer einen eingeloesten Auftrag gutschreibt.
##
## Mehr als die +5 einer gedeckten Prise ([constant
## LetterOfMarque.PRIZE_REWARD]) und *echt* mehr, als dieselbe Prise den
## Bestohlenen kostet ([constant NavalCombat.PRIZE_REPUTATION], -8). Damit ist
## der Auftrag die einzige Tat im Spiel, bei der das Ansehen in der Welt unterm
## Strich steigt.
##
## Bei genau 8 waere es ein Nullsummenspiel gewesen, das erst durch die
## Gutschrift des Kaperbriefs zum Gewinn wird - eine Behauptung, die man beim
## Balancing verliert, weil sie an zwei Zahlen zugleich haengt. Der Rauchtest
## haelt jetzt das Einfache fest: Der Gouverneur zahlt mehr, als der Diebstahl
## kostet.
##
## Das ist der bewusste Gegensatz zum blossen Kapern unter dem Brief: Wer nur
## pluendert, verschiebt seinen Ruf von einer Krone zur anderen und verliert
## dabei. Wer tut, was ihm aufgetragen wurde, steigt wirklich auf - und faehrt
## dafuer gegen ein Kriegsschiff statt gegen einen Frachter.
const REPUTATION_REWARD: int = 10

## Und was es kostet, einen angenommenen Auftrag verstreichen zu lassen.
##
## Ohne das waere die Annahme kein Entschluss, sondern ein Knopf ohne
## Gegenseite: Man nimmt jeden Auftrag mit und sieht weiter. Klein genug, dass
## ein Fehlschlag kein Laufende ist (Design-Pillar "Konsequenz statt
## Bestrafung") - vier Punkte sind eine halbe Prise.
const FAILURE_COST: int = -4

## Soviele Spieltage bleiben, den Benannten zu stellen.
##
## Ein Spieltag sind vier Minuten Echtzeit ([constant
## GameState.MINUTES_PER_SECOND]), acht Tage also gut eine halbe Stunde. Lang
## genug fuer die Suche, kurz genug, dass die Frist ueberhaupt eine ist.
const DAYS: int = 8

## Ab dem wievielten eingeloesten Auftrag der Gouverneur eine Fregatte
## ausschreibt statt einer Patrouillenschaluppe.
##
## Die ersten beiden Ziele sind mit einer Schaluppe zu stellen. Danach nicht
## mehr - und das ist der Punkt, an dem der Schiffskauf (offen aus M5) fehlt.
const FRIGATE_FROM: int = 2

## Soweit um seinen Hafen herum kreuzt der Gesuchte, in Metern.
##
## Deutlich mehr als die Entfernung, in der ein Segel wieder verschwindet
## ([constant NavalCombat.DESPAWN_DISTANCE], 2600 m): Sonst faehrt man ihm
## waehrend der Verfolgung aus seinem eigenen Revier heraus. Und klein genug
## gegen die Weltkante von zwanzig Kilometern, dass es einen Unterschied macht,
## ob man weiss, wohin - genau das ist der Grund fuer die Schenke.
const WATERS_RANGE: float = 3000.0

const PATROL_CLASS: String = "res://resources/ships/patrol_sloop.tres"
const FRIGATE_CLASS: String = "res://resources/ships/frigate.tres"

## Wer den Auftrag vergeben hat. Immer die Krone des eigenen Kaperbriefs.
var patron_id: int = LetterOfMarque.NONE
## Wen er sehen will.
var target: Adversary = null
var reward_gold: int = REWARD_BASE
var reward_reputation: int = REPUTATION_REWARD
## Letzter Spieltag, an dem der Benannte noch gestellt werden kann.
var deadline_day: int = 0
## Erledigt, aber noch nicht gemeldet.
##
## Der Zustand dazwischen ist der Grund fuer die Rueckfahrt: Ab hier laeuft
## keine Frist mehr, aber es gibt auch noch kein Gold.
var done: bool = false

## Vor welchem Hafen der Gesuchte kreuzt. -1 heisst: ueberall.
##
## Wird erst bei der Annahme gesetzt, und zwar nach dem Hafen, in dem man
## zusagt (siehe [method waters_for]). Ohne das laege sein Revier irgendwo in
## einer zwanzig Kilometer breiten Karibik, und die Frist waere nicht zu
## halten: Eine Ueberfahrt von einem Ende zum anderen dauert bei acht Knoten
## laenger als der ganze Auftrag.
var waters_town_id: int = -1

## Hat der Spieler schon erfahren, wo er kreuzt?
##
## Der Steckbrief im Palast sagt, *wer* gesucht wird, nicht *wo* - das weiss
## der Wirt in der Schenke. Erst danach steht der Ort auf der Seekarte. Das ist
## der eigentliche Grund, eine Schenke zu betreten, und der Unterschied
## zwischen einer Fahrt mit Ziel und dem Abwarten, das es vorher war.
var waters_known: bool = false


## Der Steckbrief, den dieser Gouverneur gerade aushaengt.
##
## Wird bei jedem Blick in den Palast neu gerechnet und ist trotzdem jedes Mal
## derselbe: Der Wuerfel haengt an Seed, Krone und der Zahl der bereits
## eingeloesten Auftraege. Damit muss kein Angebot gespeichert werden, und
## keines flackert beim zweiten Hinsehen.
##
## Dass die Zahl der *eingeloesten* Auftraege den Wuerfel dreht und nicht die
## der angenommenen, ist Absicht: Wer einen Auftrag verstreichen laesst,
## bekommt denselben Mann noch einmal ausgeschrieben. Ein Gesuchter bleibt
## gesucht, bis ihn jemand bringt.
## [param enemy] ist die Krone, mit der der Patron gerade Krieg fuehrt
## ([Diplomacy]). Sie wird nicht mehr gewuerfelt: Ein Gouverneur schreibt aus,
## wer ihm gerade schadet, nicht irgendeinen Fremden. Damit haengt der
## Steckbrief zusaetzlich am Zeitabschnitt - wenn die Kronen ihre Buendnisse
## neu ordnen, haengt im Palast ein anderer Mann.
static func offer(
	world_seed: int,
	patron_id_in: int,
	done_count: int,
	enemy: NationData,
	today: int
) -> Commission:
	if enemy == null or enemy.id == patron_id_in:
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d/%d/%d" % [world_seed, patron_id_in, done_count])

	var order := Commission.new()
	order.patron_id = patron_id_in
	order.target = Adversary.make(rng, enemy, class_for(done_count), false)
	order.reward_gold = reward_for(done_count)
	order.deadline_day = today + DAYS
	return order


## Der Hafen, vor dem der Gesuchte vermutet wird.
##
## Der naechstgelegene Ort seiner eigenen Flagge - ein Kaperkapitaen kreuzt vor
## der Kueste, deren Sprache er spricht. Gemessen von dort aus, wo der Auftrag
## angenommen wurde: Was ein Gouverneur vergibt, spielt in seiner Nachbarschaft,
## und die Frist ist danach zu halten.
##
## Gibt -1, wenn diese Krone keinen Hafen hat - dann kreuzt er ueberall, wie
## vor M6.
static func waters_for(towns: Array[TownData], nation_id: int, from: Vector2) -> int:
	var best: TownData = null
	var best_distance := INF
	for town: TownData in towns:
		if town.nation_id != nation_id:
			continue
		var distance := town.position.distance_squared_to(from)
		if distance < best_distance:
			best_distance = distance
			best = town
	return best.id if best != null else -1


## Kreuzt der Gesuchte hier? [param here] ist die Position des Spielers,
## [param waters] die seines Hafens.
static func in_waters(here: Vector2, waters: Vector2) -> bool:
	return here.distance_to(waters) <= WATERS_RANGE


## Auf welchem Schiff der Benannte faehrt.
static func class_for(done_count: int) -> String:
	return FRIGATE_CLASS if done_count >= FRIGATE_FROM else PATROL_CLASS


## Was der Gouverneur zahlt.
static func reward_for(done_count: int) -> int:
	return mini(REWARD_BASE + REWARD_STEP * maxi(done_count, 0), REWARD_MAX)


## Ist die Frist abgelaufen?
##
## Nur solange der Mann noch faehrt. Wer ihn gestellt hat, darf sich mit dem
## Bericht Zeit lassen - die Frist galt der Jagd, nicht der Rueckfahrt.
func expired(today: int) -> bool:
	return not done and today > deadline_day


## Wieviele Tage noch bleiben. Negativ heisst: abgelaufen.
func days_left(today: int) -> int:
	return deadline_day - today


## Ist dieses Schiff der Gesuchte?
func matches(captain: String, nation_id: int) -> bool:
	return target != null and target.is_ship(captain, nation_id)


## Zahlt dieser Hafen den Bericht aus?
##
## Eine Stadt der eigenen Krone, in der ueberhaupt ein Gouverneur sitzt. In dem
## Dorf, vor dem man gerade liegt, sitzt keiner - dieselbe Regel wie beim
## Kaperbrief ([method LetterOfMarque.has_seat]).
func can_report(town_nation_id: int, size_tier: int) -> bool:
	return done and town_nation_id == patron_id and LetterOfMarque.has_seat(size_tier)


func to_dict() -> Dictionary:
	return {
		"patron": patron_id,
		"target": target.to_dict() if target != null else {},
		"gold": reward_gold,
		"reputation": reward_reputation,
		"deadline": deadline_day,
		"done": done,
		"waters": waters_town_id,
		"waters_known": waters_known,
	}


static func from_dict(data: Dictionary) -> Commission:
	var order := Commission.new()
	order.patron_id = int(data.get("patron", LetterOfMarque.NONE))
	order.target = Adversary.from_dict(data.get("target", {}))
	order.reward_gold = int(data.get("gold", REWARD_BASE))
	order.reward_reputation = int(data.get("reputation", REPUTATION_REWARD))
	order.deadline_day = int(data.get("deadline", 0))
	order.done = bool(data.get("done", false))
	# Ein Spielstand aus der Zeit vor den Gewaessern hat beide Felder nicht.
	# Die Vorgabe -1 heisst "ueberall" - der alte Auftrag verhaelt sich dann
	# genau so, wie er es beim Speichern tat.
	order.waters_town_id = int(data.get("waters", -1))
	order.waters_known = bool(data.get("waters_known", false))
	return order
