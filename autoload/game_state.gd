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


func change_reputation(nation: Nation, amount: int) -> void:
	reputation[nation] = clampi(reputation[nation] + amount, -100, 100)
	EventBus.reputation_changed.emit(nation, reputation[nation])


func add_notoriety(amount: int) -> void:
	notoriety += amount


## Setzt eine neue Kampagne auf. Die Welt selbst erzeugt WorldData.
func new_campaign(captain: String, world_seed: int) -> void:
	captain_name = captain
	gold = 500
	notoriety = 0
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
