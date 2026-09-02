## Die generierte Welt: Seed, Wind, Wetter, Staedte, Nationen.
##
## Die Heightmap wird NIE gespeichert - sie wird aus dem Seed rekonstruiert.
## Gespeichert werden nur Abweichungen vom generierten Zustand (Stadtbesitzer,
## Lagerbestaende, Preise). Siehe docs/KONZEPT.md, Abschnitt 7.6.
extends Node

enum Weather { CLEAR, CLOUDY, RAIN, STORM }

## Kantenlaenge der Welt in Metern.
const WORLD_SIZE: float = 20480.0
## Kantenlaenge eines Gelaende-Chunks in Metern. Muss zu
## WorldGenerator.TERRAIN_CHUNK_SIZE passen.
const CHUNK_SIZE: float = 256.0
## Wie hoch ragt Land ueber den Meeresspiegel? Hoehenwerte sind 0 bis 1, die
## Landspanne betraegt nur rund 0,25 davon - ohne kraeftige Ueberhoehung waeren
## Inseln flache Platten.
const TERRAIN_HEIGHT_SCALE: float = 1400.0

# --- Weltdefinition ---
var world_seed: int = 0
var rng := RandomNumberGenerator.new()
var generated: bool = false

## Alle Staedte, Index gleich Id.
var towns: Array[TownData] = []
## Alle Landmassen, Index gleich Id.
var islands: Array[IslandData] = []
## Die vier Kolonialmaechte, aus resources/nations/ geladen.
var nations: Array[NationData] = []

## Der Generator bleibt erhalten - height_at() wird spaeter vom Terrain-Meshing
## und von der Kollisionspruefung gebraucht.
var generator: WorldGenerator = null

const NATION_PATHS: PackedStringArray = [
	"res://resources/nations/spain.tres",
	"res://resources/nations/england.tres",
	"res://resources/nations/france.tres",
	"res://resources/nations/netherlands.tres",
]

# --- Wind ---
## Richtung in Radiant, aus der der Wind kommt.
var wind_direction: float = 0.0
## Windstaerke als Faktor 0.0-1.5.
var wind_strength: float = 1.0

var weather: Weather = Weather.CLEAR

## Haelt den Wind fest, wo er steht.
##
## Fuer das Debug-Menue und fuer Sichtpruefungen: Ohne das dreht der Wind
## waehrend einer Aufnahme weg, und ein von Hand gesetzter Wert waere nach
## Sekunden wieder verschwunden.
var wind_locked: bool = false

# --- Wirtschaft ---
## Nach so vielen Spielminuten werden die Lager der Staedte fortgeschrieben.
## Haeufiger waere Rechenzeit ohne sichtbaren Unterschied - ein Bestand
## bewegt sich in zwei Stunden um Bruchteile eines Fasses.
const ECONOMY_STEP_MINUTES: float = 120.0

## Spielminuten beim letzten Wirtschaftsschritt. Die Zeit selbst liegt in
## GameState - es gibt nur eine Uhr, und die Welt liest sie mit.
var _last_economy_minutes: float = 0.0

## Der zuletzt gemeldete politische Zeitabschnitt (siehe [Diplomacy]).
##
## Nur zum Vergleich beim Tageswechsel, nicht als Wahrheit: Welche Kronen
## einander bekriegen, faellt jederzeit aus Seed und Spieltag heraus. Hier
## steht ausschliesslich, was der Spieler davon schon erfahren hat - deshalb
## wird das Feld auch nicht gespeichert.
var _diplomacy_era: int = 0

## Zielwerte, auf die Richtung und Staerke langsam zulaufen.
var _wind_target_direction: float = 0.0
var _wind_target_strength: float = 1.0
var _wind_shift_timer: float = 0.0

## Sekunden zwischen zwei neuen Wind-Zielwerten.
const WIND_SHIFT_INTERVAL: float = 45.0
## Wie schnell der Wind seinem Zielwert folgt.
const WIND_LERP_SPEED: float = 0.15


## Die politische Uhr laeuft am Tageswechsel, nicht am Bild: Ein
## Friedensschluss ist ein Ereignis des Kalenders.
func _ready() -> void:
	EventBus.day_passed.connect(_on_day_passed)


func _process(delta: float) -> void:
	if not generated:
		return
	_update_wind(delta)
	_update_economy()


## Laesst die Lager aller Staedte altern.
##
## Der Schritt haengt nur an der verstrichenen Spielzeit, nicht an der Bildrate
## und nicht daran, ob der Spieler gerade in einem Hafen steht.
func _update_economy() -> void:
	var elapsed := GameState.game_minutes - _last_economy_minutes
	if elapsed < ECONOMY_STEP_MINUTES:
		return
	_last_economy_minutes = GameState.game_minutes

	var days := elapsed / 1440.0
	for town: TownData in towns:
		town.advance_economy(days)


func _update_wind(delta: float) -> void:
	if wind_locked:
		return
	_wind_shift_timer -= delta
	if _wind_shift_timer <= 0.0:
		_wind_shift_timer = WIND_SHIFT_INTERVAL
		# Wind dreht in Schritten, nicht sprunghaft ueber die ganze Rose.
		_wind_target_direction = wrapf(
			_wind_target_direction + rng.randf_range(-PI * 0.4, PI * 0.4), -PI, PI
		)
		_wind_target_strength = rng.randf_range(0.6, 1.3)

	var previous_direction := wind_direction
	wind_direction = wrapf(
		wind_direction + angle_difference(wind_direction, _wind_target_direction)
		* WIND_LERP_SPEED * delta,
		-PI, PI
	)
	wind_strength = lerpf(wind_strength, _wind_target_strength, WIND_LERP_SPEED * delta)

	if absf(angle_difference(previous_direction, wind_direction)) > 0.001:
		EventBus.wind_changed.emit(wind_direction, wind_strength)


## Erzeugt die Welt aus einem Seed.
func generate(new_seed: int) -> void:
	world_seed = new_seed
	rng.seed = new_seed

	wind_direction = rng.randf_range(-PI, PI)
	wind_strength = rng.randf_range(0.7, 1.2)
	_wind_target_direction = wind_direction
	_wind_target_strength = wind_strength
	_wind_shift_timer = WIND_SHIFT_INTERVAL

	_load_nations()
	generator = WorldGenerator.new()
	generator.generate(new_seed, WORLD_SIZE, nations)
	towns = generator.towns
	islands = generator.islands

	generated = true
	reset_economy_clock()
	reset_political_clock()


## Setzt die Wirtschaftsuhr auf den jetzigen Spielzeitpunkt.
## Noetig nach dem Laden eines Spielstands - sonst holt die Wirtschaft die
## Differenz zwischen zwei Spielstaenden in einem Schritt nach.
func reset_economy_clock() -> void:
	_last_economy_minutes = GameState.game_minutes


## Setzt die politische Uhr auf den jetzigen Spieltag.
##
## Noetig nach dem Laden und nach dem Erzeugen einer Welt: Sonst meldet der
## naechste Tageswechsel eine Umwaelzung, die schon vor dem Speichern
## stattgefunden hat.
func reset_political_clock() -> void:
	_diplomacy_era = Diplomacy.era_of(GameState.current_day())


func _on_day_passed(day: int) -> void:
	var era := Diplomacy.era_of(day)
	if era == _diplomacy_era:
		return
	_diplomacy_era = era
	EventBus.treaties_changed.emit(day)


func _load_nations() -> void:
	if not nations.is_empty():
		return
	for path: String in NATION_PATHS:
		var nation: NationData = load(path)
		if nation != null:
			nations.append(nation)
		else:
			push_error("WorldData: Nation nicht ladbar: %s" % path)


func get_town(town_id: int) -> TownData:
	if town_id < 0 or town_id >= towns.size():
		return null
	return towns[town_id]


func get_nation(nation_id: int) -> NationData:
	for nation: NationData in nations:
		if nation.id == nation_id:
			return nation
	return null


# --- Politik ---------------------------------------------------------------
#
# Die Lage selbst steht in [Diplomacy] und ist eine reine Rechnung aus Seed und
# Spieltag. Hier stehen nur die drei Fragen, die das laufende Spiel daran hat -
# damit nicht jeder Aufrufer Seed und Uhr selbst zusammensuchen muss. Dass die
# Welt dafuer die Uhr aus GameState liest, ist dasselbe wie bei der Wirtschaft:
# Es gibt nur eine Uhr.

## Mit welcher Krone diese gerade Krieg fuehrt, oder -1.
func enemy_of(nation_id: int) -> int:
	return Diplomacy.enemy_of(world_seed, GameState.current_day(), nation_id)


## Liegen diese beiden gerade im Krieg?
func at_war(a: int, b: int) -> bool:
	return Diplomacy.at_war(world_seed, GameState.current_day(), a, b)


## Die beiden Kriege, die gerade laufen - fuer Seekarte und Schenke.
func wars() -> Array[Vector2i]:
	return Diplomacy.wars(world_seed, GameState.current_day())


## Ab dieser Entfernung zur Stadt laesst sich anlegen.
##
## Grosszuegig genug, dass man nicht auf den Meter genau manoevrieren muss -
## die Staedte liegen mindestens 1200 Meter auseinander, verwechseln kann man
## sie also nicht.
const DOCK_RADIUS: float = 240.0


## Stadt, in deren Hafen von [param position] aus angelegt werden kann.
func dockable_town(position: Vector2) -> TownData:
	return nearest_town(position, DOCK_RADIUS)


## Naechstgelegene Stadt zu einer Weltposition, oder null.
func nearest_town(position: Vector2, max_distance: float = INF) -> TownData:
	var best: TownData = null
	var best_distance := max_distance * max_distance
	for town: TownData in towns:
		var d := town.position.distance_squared_to(position)
		if d < best_distance:
			best_distance = d
			best = town
	return best


## Gelaendehoehe an einem Weltpunkt. Vor der Generierung offene See.
func height_at(x: float, z: float) -> float:
	if generator == null:
		return 0.0
	return generator.height_at(x, z)


func is_land(x: float, z: float) -> bool:
	return generator != null and generator.is_land(x, z)


## Ist hier tiefes Wasser? Strenger als [method is_land] - eine Untiefe ist
## kein Land, aber auch kein Platz, an dem ein fremdes Segel auftauchen darf.
func is_navigable(x: float, z: float) -> bool:
	return generator != null and generator.is_navigable(x, z)


## Ankerplatz vor einer Stadt - der Punkt, an dem das Schiff beim Auslaufen
## liegt. Vor der Generierung der Stadtort selbst.
func anchorage_for(town: TownData) -> Vector2:
	if generator == null or town == null:
		return Vector2.ZERO
	var island: IslandData = islands[town.island_id]
	return generator.anchorage(town.position, island.center)


## Setzt den Wind fest auf einen Wert - er driftet danach von dort weiter.
## Fuer Tests, Debugging und spaeter fuer Wetterereignisse.
func set_wind(direction: float, strength: float = -1.0) -> void:
	wind_direction = wrapf(direction, -PI, PI)
	_wind_target_direction = wind_direction
	if strength >= 0.0:
		wind_strength = strength
		_wind_target_strength = strength
	_wind_shift_timer = WIND_SHIFT_INTERVAL
	EventBus.wind_changed.emit(wind_direction, wind_strength)


## Welt-Position -> Chunk-Koordinate.
func chunk_coord_at(position: Vector3) -> Vector2i:
	if generator == null:
		return Vector2i.ZERO
	return generator.chunk_coord_at(position.x, position.z)


## Gelaendehoehe in Metern ueber dem Meeresspiegel. Negativ unter Wasser.
func terrain_y(x: float, z: float) -> float:
	if generator == null:
		return -50.0
	return generator.elevation_at(x, z, TERRAIN_HEIGHT_SCALE)


## Hoehe der sichtbaren Gelaendeoberflaeche - der Wert, auf den Gebaeude,
## Baeume und alles andere an Land gesetzt wird.
func terrain_surface_y(x: float, z: float) -> float:
	if generator == null:
		return -50.0
	return TerrainChunk.surface_y(
		generator, x, z, WorldGenerator.TERRAIN_RESOLUTION, TERRAIN_HEIGHT_SCALE
	)


func sea_level() -> float:
	return generator.sea_level if generator != null else 0.5
