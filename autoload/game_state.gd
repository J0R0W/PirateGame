## Alles, was den Spieler betrifft: Gold, Zeit, Ruf, Crew.
##
## Modus-Szenen lesen und schreiben hier, statt sich gegenseitig zu kennen.
extends Node

enum Nation { SPAIN, ENGLAND, FRANCE, NETHERLANDS }

## Spielminuten pro Realsekunde bei Zeitfaktor 1.
##
## 6.0 heisst: ein Spieltag in vier Minuten Echtzeit. Vorher waren es zwoelf,
## und zwischen zwei Haefen verging kaum ein halber Tag - die Lager der Staedte
## hatten nie Zeit, sich zu erholen, und Handel bestand nur aus dem eigenen
## Preisdruck.
const MINUTES_PER_SECOND: float = 6.0

## Startausruestung einer neuen Kampagne.
const STARTING_SHIP: String = "res://resources/ships/sloop.tres"

# --- Spieler ---
var captain_name: String = "Namenlos"
var gold: int = 500:
	set(value):
		gold = maxi(0, value)
		EventBus.gold_changed.emit(gold)

var crew: int = 20:
	set(value):
		crew = clampi(value, 0, max_crew())
		EventBus.crew_changed.emit(crew)

## Ansehen pro Nation, -100 (Feind) bis +100 (Verbuendeter).
var reputation: Dictionary = {
	Nation.SPAIN: 0,
	Nation.ENGLAND: 0,
	Nation.FRANCE: 0,
	Nation.NETHERLANDS: 0,
}

## Beruechtigtheit, 0-100. Waechst mit jeder Tat und sinkt nie.
var notoriety: int = 0:
	set(value):
		notoriety = clampi(value, 0, 100)
		EventBus.notoriety_changed.emit(notoriety)

## Nation, in deren Auftrag der Spieler kapert, oder [constant
## LetterOfMarque.NONE].
##
## Immer nur eine: Vier Kaperbriefe waeren vier Freunde und keine Wahl. Wer
## einen zweiten annimmt, gibt den ersten damit ab - siehe [method issue_letter].
var letter_nation: int = LetterOfMarque.NONE

## Prisen, die unter dem laufenden Brief aufgebracht wurden.
##
## Faengt bei jedem neuen Brief wieder bei null an und steht im
## Gouverneurspalast: Der Brief ist dadurch nicht nur ein Zustand, sondern
## etwas, das mitlaeuft.
var letter_prizes: int = 0

## Der angenommene Auftrag des Gouverneurs, oder null.
##
## Immer hoechstens einer, und immer der der eigenen Patronskrone: Ein Auftrag
## setzt den Kaperbrief voraus (siehe [method accept_commission]). Das offene
## Angebot wird dagegen nicht gehalten, sondern gerechnet - siehe [method
## commission_offer].
var commission: Commission = null

## Wieviele Auftraege bisher eingeloest wurden.
##
## Zwei Aufgaben: Sie bestimmt, was der naechste Auftrag einbringt und wie
## schwer sein Ziel faehrt - und sie ist der Wuerfel des ausgehaengten
## Steckbriefs. Deshalb zaehlt sie *eingeloeste* und nicht angenommene: Ein
## Gesuchter, den niemand gebracht hat, bleibt gesucht.
var commissions_done: int = 0

# --- Schiff ---
#
# Das Schiff des Spielers lebt hier und nicht in der Segelszene: Laderaum und
# Zustand muessen den Szenenwechsel in den Hafen ueberstehen. Die Szene erzeugt
# nur die sichtbare Huelle und uebernimmt diese Werte.

var ship_class: ShipClass = null

## Rumpfzustand, 0 bis ship_class.max_hull.
var hull: int = 100:
	set(value):
		hull = clampi(value, 0, max_hull())
		EventBus.ship_condition_changed.emit(hull, sails)

## Zustand der Besegelung. Beschaedigte Segel kosten Fahrt.
var sails: int = 100:
	set(value):
		sails = clampi(value, 0, max_sails())
		EventBus.ship_condition_changed.emit(hull, sails)

## Laderaum: Waren-Id -> Menge. Nur Waren mit Menge > 0 stehen drin.
var cargo: Dictionary = {}

## Id der Stadt, in deren Hafen der Spieler liegt. -1 heisst: auf See.
var current_port_id: int = -1

# --- Zeit ---
var game_minutes: float = 0.0
var time_scale: float = 1.0
var _last_day: int = 0

## Laeuft die Spielzeit gerade? Im Hafen und in Menues pausiert sie.
var time_running: bool = false


func _process(delta: float) -> void:
	if not time_running:
		return
	game_minutes += delta * MINUTES_PER_SECOND * time_scale
	var day := current_day()
	if day != _last_day:
		_last_day = day
		# Erst die Frist pruefen, dann den Tag melden: Wer auf day_passed hoert
		# und den Auftrag anzeigt, soll nicht noch einmal den abgelaufenen sehen.
		_check_commission_deadline(day)
		EventBus.day_passed.emit(day)


func current_day() -> int:
	return int(game_minutes / 1440.0)


## Uhrzeit als 0.0-1.0 ueber den Tag - fuer Sonnenstand und Beleuchtung.
func time_of_day() -> float:
	return fmod(game_minutes, 1440.0) / 1440.0


func add_gold(amount: int) -> void:
	gold += amount


# --- Schiff ---------------------------------------------------------------

func max_hull() -> int:
	return ship_class.max_hull if ship_class != null else 100


func max_sails() -> int:
	return ship_class.max_sails if ship_class != null else 100


func max_crew() -> int:
	return ship_class.max_crew if ship_class != null else 40


## Soviele Leute halten das Schiff in Fahrt. Alles darueber bedient die Rohre.
func min_crew() -> int:
	return ship_class.min_crew if ship_class != null else 4


## Wie gut die Geschuetze bedient sind, 0.35 bis 1.0.
##
## Die Zahl, die im Gefecht zaehlt - nicht der Anteil an der Hoechstbesatzung.
## Sie steht hier und nicht nur im [Ship], weil Hafenbildschirme und HUD sie
## brauchen, wenn kein Schiff in der Szene haengt.
func readiness() -> float:
	var slots := ship_class.cannon_slots if ship_class != null else 6
	return Gunnery.readiness(crew, min_crew(), slots)


## Wie gut das Schiff mit dieser Mannschaft noch zu fahren ist, 0.3 bis 1.0.
## Unter 1.0 nur, wenn die Mindestbesatzung unterschritten ist.
func handling() -> float:
	return SailingMath.handling(crew, min_crew())


func cargo_capacity() -> int:
	return ship_class.cargo_capacity if ship_class != null else 40


## Belegter Laderaum. Sperrgut zaehlt mehrfach - siehe CargoType.unit_size.
func cargo_used() -> int:
	var used := 0
	for cargo_id: StringName in cargo:
		var type := CargoRegistry.get_cargo(cargo_id)
		used += int(cargo[cargo_id]) * (type.unit_size if type != null else 1)
	return used


func cargo_free() -> int:
	return maxi(cargo_capacity() - cargo_used(), 0)


func cargo_of(cargo_id: StringName) -> int:
	return int(cargo.get(cargo_id, 0))


func add_cargo(cargo_id: StringName, amount: int) -> void:
	var total := cargo_of(cargo_id) + amount
	if total <= 0:
		cargo.erase(cargo_id)
	else:
		cargo[cargo_id] = total
	EventBus.cargo_changed.emit(cargo_id, maxi(total, 0))


## Schaden am Rumpf. Kommt vorerst nur vom Auflaufen, spaeter vom Gefecht.
func damage_hull(amount: int) -> void:
	if amount <= 0:
		return
	hull = hull - amount


func damage_sails(amount: int) -> void:
	if amount <= 0:
		return
	sails = sails - amount


## Wie gut die Segel noch ziehen, 0.0 bis 1.0.
func sail_condition() -> float:
	var maximum := max_sails()
	return float(sails) / float(maximum) if maximum > 0 else 0.0


## Aendert das Ansehen bei einer Nation.
##
## Gewichtet mit ihrer Empfindlichkeit: Spanien nimmt eine Prise schwerer als
## die Niederlande. Der Wert steht seit M2 in den .tres-Dateien und wurde bis
## M6 von niemandem gelesen.
func change_reputation(nation: Nation, amount: int) -> void:
	var data := WorldData.get_nation(int(nation))
	var weighted := Standing.weighted_change(
		amount, data.reputation_sensitivity if data != null else 1.0
	)
	reputation[nation] = clampi(reputation[nation] + weighted, -100, 100)
	EventBus.reputation_changed.emit(nation, reputation[nation])


## Ansehen bei einer Nation, oder 0 fuer eine unbekannte Id.
##
## Nimmt die Id als int, weil Schiffe und Staedte ihre Nation so tragen
## (ship.nation_id, town.nation_id) - der Aufrufer soll nicht jedes Mal
## umwandeln muessen.
func reputation_with(nation_id: int) -> int:
	return int(reputation.get(nation_id, 0))


## Wie diese Nation zum Spieler steht.
func standing_with(nation_id: int) -> Standing.Level:
	return Standing.level_of(reputation_with(nation_id))


func add_notoriety(amount: int) -> void:
	notoriety += amount


# --- Kaperbrief -----------------------------------------------------------

func has_letter() -> bool:
	return letter_nation != LetterOfMarque.NONE


## Die Krone, in deren Auftrag gefahren wird, oder null.
func letter_patron() -> NationData:
	return WorldData.get_nation(letter_nation) if has_letter() else null


## Wuerde der Gouverneur dieser Nation einen Brief ausstellen?
##
## Zwei Gruende dagegen: Sie traut dem Spieler nicht mehr, oder er faehrt
## bereits fuer sie. Die Anzeige fragt dasselbe, damit der Knopf nicht etwas
## anbietet, das der Griff danach ablehnt.
func can_issue_letter(nation_id: int) -> bool:
	if nation_id < 0 or nation_id == letter_nation:
		return false
	return LetterOfMarque.can_issue(standing_with(nation_id))


## Nimmt einen Kaperbrief an. Gibt false zurueck, wenn die Krone keinen gibt.
##
## Ein bisheriger Patron wird dabei nicht gesondert behandelt: Er ist ab dem
## Moment eine der uebrigen Kronen und bucht denselben Verlust wie sie. Damit
## kostet ein Seitenwechsel von selbst mehr als ein erster Brief, ohne dass es
## dafuer eine eigene Regel braucht.
func issue_letter(nation_id: int) -> bool:
	if not can_issue_letter(nation_id):
		return false
	# Ein laufender Auftrag gehoert dem bisherigen Patron. Wer die Seite
	# wechselt, laesst ihn sitzen - und das rechnet er an wie jedes andere
	# nicht gehaltene Wort.
	_drop_commission(true)
	letter_nation = nation_id
	letter_prizes = 0
	for other: Variant in reputation:
		if int(other) != nation_id:
			change_reputation(int(other), LetterOfMarque.RIVAL_COST)
	EventBus.letter_changed.emit(letter_nation)
	return true


## Gibt den Brief zurueck.
##
## Der Brief selbst kostet nichts: Ihn niederzulegen ist keine Tat, die jemandem
## schadet. Was die uebrigen Kronen sich notiert haben, vergessen sie deswegen
## trotzdem nicht - Ansehen wird nicht zurueckgedreht.
##
## Ein laufender Auftrag geht mit und wird dabei als gescheitert gebucht: Wer
## einen Namen zugesagt hat und stattdessen den Brief abgibt, hat den
## Gouverneur sitzenlassen. Ohne das waere die Rueckgabe der Schlupfweg aus
## jeder Frist.
func return_letter() -> void:
	if not has_letter():
		return
	_drop_commission(true)
	_clear_letter()


## Nimmt den Brief aus der Tasche, ohne sonst etwas zu buchen.
##
## Getrennt von [method return_letter], weil es zwei Wege dorthin gibt: die
## Rueckgabe, die einen offenen Auftrag anrechnet, und den Einzug nach Verrat,
## der schon teuer genug war.
func _clear_letter() -> void:
	letter_nation = LetterOfMarque.NONE
	letter_prizes = 0
	EventBus.letter_changed.emit(letter_nation)


## Deckt der laufende Kaperbrief eine Prise gegen diese Nation?
##
## Die eine Stelle, an der die Regel aus [LetterOfMarque] auf die politische
## Lage trifft: Gedeckt ist nur die Krone, mit der der Patron gerade Krieg
## fuehrt. Anzeige und Buchung fragen dieselbe Funktion - sonst schreibt das
## HUD "wird gutgeschrieben" ueber eine Prise, die niemand gutschreibt.
func letter_covers(victim_id: int) -> bool:
	return LetterOfMarque.covers(
		letter_nation, victim_id, WorldData.enemy_of(letter_nation)
	)


## Verbucht eine genommene Prise beim Auftraggeber.
##
## Die eine Stelle, an der ein Kaperbrief etwas einbringt - und die einzige
## Richtung, in der sich Ansehen ueberhaupt aufbauen laesst. Wer den eigenen
## Patron aufbringt, ist ihn los.
func settle_letter_prize(victim_id: int) -> LetterOfMarque.Verdict:
	if LetterOfMarque.is_betrayal(letter_nation, victim_id):
		change_reputation(letter_nation, LetterOfMarque.BETRAYAL_COST)
		# Ohne zweite Rechnung: Der Verrat ist mit BETRAYAL_COST bezahlt, und
		# denselben Vorgang zweimal zu buchen macht aus einer Konsequenz eine
		# Bestrafung.
		_drop_commission(false)
		_clear_letter()
		return LetterOfMarque.Verdict.REVOKED
	if not letter_covers(victim_id):
		return LetterOfMarque.Verdict.NONE
	letter_prizes += 1
	change_reputation(letter_nation, LetterOfMarque.PRIZE_REWARD)
	return LetterOfMarque.Verdict.CREDITED


# --- Auftraege des Gouverneurs ---------------------------------------------

## Der Steckbrief, den der Gouverneur der eigenen Patronskrone aushaengt.
##
## Gerechnet statt gehalten: Der Wuerfel haengt an Seed, Krone und der Zahl der
## eingeloesten Auftraege ([method Commission.offer]). Damit steht bei jedem
## Blick in den Palast derselbe Mann da, ohne dass ein Angebot gespeichert oder
## bei jedem Betreten neu ausgewuerfelt werden muesste.
func commission_offer() -> Commission:
	if not has_letter():
		return null
	# Ausgeschrieben wird, wer der Krone gerade schadet - also ein Segel des
	# Kriegsgegners. Frueher wuerfelte der Auftrag unter allen drei fremden
	# Kronen; damit war er von der Politik unabhaengig, die es noch nicht gab.
	var enemy := WorldData.get_nation(WorldData.enemy_of(letter_nation))
	return Commission.offer(
		WorldData.world_seed, letter_nation, commissions_done, enemy, current_day()
	)


## Vergibt dieser Gouverneur gerade einen Auftrag?
##
## Nur die eigene Patronskrone, und nur einen. Ein Auftrag ohne Kaperbrief
## waere ein Gefallen unter Fremden - der Brief ist die Erlaubnis, der Auftrag
## der Grund.
func can_accept_commission(nation_id: int) -> bool:
	return commission == null and has_letter() and nation_id == letter_nation


func accept_commission(nation_id: int) -> bool:
	if not can_accept_commission(nation_id):
		return false
	var order := commission_offer()
	if order == null:
		return false
	# Wo er kreuzt, haengt an dem Hafen, in dem zugesagt wird - sonst laege sein
	# Revier irgendwo in einer zwanzig Kilometer breiten Karibik und die Frist
	# waere nicht zu halten (siehe Commission.waters_for). Ausserhalb eines
	# Hafens - im Rauchtest - wird vom Weltmittelpunkt aus gemessen.
	var here := WorldData.get_town(current_port_id)
	order.waters_town_id = Commission.waters_for(
		WorldData.towns,
		order.target.nation_id,
		here.position if here != null else Vector2.ZERO
	)
	commission = order
	EventBus.commission_changed.emit(Commission.Change.ACCEPTED)
	return true


## Der Wirt sagt, vor welchem Hafen der Gesuchte kreuzt.
##
## Gibt die Stadt zurueck, oder null, wenn es nichts zu erzaehlen gibt. Ab hier
## steht der Ort auch auf der Seekarte - das ist der ganze Ertrag eines
## Schenkenbesuchs, und der Grund, warum ein Auftrag jetzt eine Fahrt mit Ziel
## ist statt eines Abwartens.
func hear_commission_rumour() -> TownData:
	if commission == null or commission.done or commission.waters_town_id < 0:
		return null
	commission.waters_known = true
	return WorldData.get_town(commission.waters_town_id)


## Der Gesuchte ist erledigt - aufgebracht oder versenkt.
##
## Beides zaehlt. Der Gouverneur will den Mann von der See haben; ob er dabei
## an Bord kommt oder auf den Grund geht, ist Sache des Kapitaens. Ohne das
## waere eine gut sitzende Breitseite die schlechteste Art, einen Auftrag zu
## erfuellen.
##
## Ueber Name und Flagge statt ueber das Schiffsobjekt: Zwischen Annahme und
## Treffen liegen Haefen und Szenenwechsel, und der Node von vorhin ist dann
## laengst weg (siehe [method Adversary.is_ship]).
func commission_target_defeated(captain: String, nation_id: int) -> bool:
	if commission == null or commission.done:
		return false
	if not commission.matches(captain, nation_id):
		return false
	commission.done = true
	EventBus.commission_changed.emit(Commission.Change.FULFILLED)
	return true


## Zahlt dieser Hafen den Bericht aus?
func can_report_commission(town: TownData) -> bool:
	if commission == null or town == null:
		return false
	return commission.can_report(town.nation_id, town.size_tier)


## Bericht erstattet - der Gouverneur zahlt.
##
## Die eine Stelle, an der ein Auftrag etwas einbringt, und sie liegt an Land.
## Das ist der Unterschied zur Prise: Die See zahlt sofort, der Gouverneur erst,
## wenn man wieder vor ihm steht.
func report_commission(town: TownData) -> bool:
	if not can_report_commission(town):
		return false
	var gold_reward := commission.reward_gold
	var standing_reward := commission.reward_reputation
	var patron := commission.patron_id
	commission = null
	commissions_done += 1
	add_gold(gold_reward)
	change_reputation(patron, standing_reward)
	EventBus.commission_changed.emit(Commission.Change.REPORTED)
	return true


## Ist die Frist verstrichen? Wird beim Tageswechsel gefragt.
func _check_commission_deadline(today: int) -> void:
	if commission != null and commission.expired(today):
		_drop_commission(true)


## Nimmt den laufenden Auftrag aus den Buechern.
##
## [param charge] entscheidet, ob der Patron es anrechnet: Er tut es, wenn ein
## zugesagter Mann nicht gebracht wurde, nicht aber beim Einzug des Briefs nach
## Verrat - der ist schon bezahlt.
##
## Ein bereits erledigter Auftrag kostet ebenfalls nichts mehr. Die Arbeit war
## getan, es verfaellt nur der Lohn - und das ist Strafe genug.
func _drop_commission(charge: bool) -> void:
	if commission == null:
		return
	if charge and not commission.done:
		change_reputation(commission.patron_id, Commission.FAILURE_COST)
	commission = null
	EventBus.commission_changed.emit(Commission.Change.FAILED)


## Setzt eine neue Kampagne auf. Die Welt selbst erzeugt WorldData.
func new_campaign(captain: String, world_seed: int) -> void:
	captain_name = captain
	gold = 500
	notoriety = 0
	letter_nation = LetterOfMarque.NONE
	letter_prizes = 0
	commission = null
	commissions_done = 0
	game_minutes = 0.0
	_last_day = 0
	for nation in reputation:
		reputation[nation] = 0

	ship_class = load(STARTING_SHIP)
	if ship_class == null:
		push_error("GameState: Startschiff nicht ladbar: %s" % STARTING_SHIP)
	hull = max_hull()
	sails = max_sails()
	# Voll besetzt in See stechen. Eine halbe Mannschaft laedt fast doppelt so
	# lang und trifft halb so oft (siehe Gunnery) - damit anzufangen waere eine
	# Strafe fuer nichts. Die Zeile steht hinter der Schiffsklasse, weil deren
	# max_crew die Obergrenze setzt.
	crew = max_crew()
	cargo.clear()
	current_port_id = -1

	WorldData.generate(world_seed)
