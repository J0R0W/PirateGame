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

## Zielwerte, auf die Richtung und Staerke langsam zulaufen.
var _wind_target_direction: float = 0.0
var _wind_target_strength: float = 1.0
var _wind_shift_timer: float = 0.0

## Sekunden zwischen zwei neuen Wind-Zielwerten.
const WIND_SHIFT_INTERVAL: float = 45.0
## Wie schnell der Wind seinem Zielwert folgt.
const WIND_LERP_SPEED: float = 0.15


func _process(delta: float) -> void:
	if not generated:
		return
	_update_wind(delta)


func _update_wind(delta: float) -> void:
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
	return (generator.height_at(x, z) - generator.sea_level) * TERRAIN_HEIGHT_SCALE


func sea_level() -> float:
	return generator.sea_level if generator != null else 0.5
