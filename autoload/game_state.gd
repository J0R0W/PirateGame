## Alles, was den Spieler betrifft: Gold, Zeit, Ruf, Crew.
##
## Modus-Szenen lesen und schreiben hier, statt sich gegenseitig zu kennen.
extends Node

enum Nation { SPAIN, ENGLAND, FRANCE, NETHERLANDS }

## Spielminuten pro Realsekunde bei Zeitfaktor 1.
const MINUTES_PER_SECOND: float = 2.0

# --- Spieler ---
var captain_name: String = "Namenlos"
var gold: int = 500:
	set(value):
		gold = maxi(0, value)
		EventBus.gold_changed.emit(gold)

var crew: int = 20:
	set(value):
		crew = maxi(0, value)
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


func change_reputation(nation: Nation, amount: int) -> void:
	reputation[nation] = clampi(reputation[nation] + amount, -100, 100)
	EventBus.reputation_changed.emit(nation, reputation[nation])


func add_notoriety(amount: int) -> void:
	notoriety += amount


## Setzt eine neue Kampagne auf. Die Welt selbst erzeugt WorldData.
func new_campaign(captain: String, world_seed: int) -> void:
	captain_name = captain
	gold = 500
	crew = 20
	notoriety = 0
	game_minutes = 0.0
	_last_day = 0
	for nation in reputation:
		reputation[nation] = 0
	WorldData.generate(world_seed)
