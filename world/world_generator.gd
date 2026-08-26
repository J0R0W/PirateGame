## Erzeugt die Karibik aus einem Seed.
##
## Die Pipeline aus docs/KONZEPT.md, Abschnitt 5.2:
##   Seed -> Heightmap -> Inselmaske -> Landmassen -> Stadtplaetze
##        -> Nationen -> Namen -> Wirtschaft
##
## Wichtig: Die Heightmap wird NICHT als Array gespeichert. [method height_at]
## ist die massgebliche, kontinuierliche Quelle und laesst sich jederzeit an
## beliebiger Stelle auswerten - das Terrain-Meshing in M2b sampelt sie direkt.
## Das Analyse-Raster unten dient nur dazu, Inseln und Haefen zu FINDEN.
class_name WorldGenerator
extends RefCounted

## Kantenlaenge des Analyse-Rasters. 512 bei 20 km Welt sind 40 m pro Zelle -
## grob genug fuer Tempo, fein genug, um Inseln und Buchten zu erkennen.
const ANALYSIS_SIZE: int = 512

## Angestrebter Landanteil der Welt. Der Meeresspiegel wird pro Seed daraus
## abgeleitet, statt fest zu stehen - so liefert JEDER Seed eine brauchbare
## Karibik, statt mal einen leeren Ozean und mal einen Kontinent.
const TARGET_LAND_SHARE: float = 0.14
## Abstand zwischen Meeresspiegel und Tiefwasser, in Hoeheneinheiten.
const DEEP_WATER_MARGIN: float = 0.06

## Aus der Hoehenverteilung berechnet, siehe _calibrate_sea_level().
var sea_level: float = 0.5
var deep_water: float = 0.44

## Mindestabstand zwischen zwei Staedten in Metern.
const MIN_TOWN_DISTANCE: float = 1200.0
const MIN_TOWNS: int = 24
## Obergrenze wird pro Welt gewuerfelt - sonst haette jede Karibik exakt
## gleich viele Haefen.
const MAX_TOWNS_RANGE: Vector2i = Vector2i(26, 40)

var max_towns: int = 40

## Kantenlaenge eines Gelaende-Chunks in Metern. Bei 64 m waeren fuer die
## Sichtweite ueber 250 Chunks noetig - mit 256 m sind es unter 50.
const TERRAIN_CHUNK_SIZE: float = 256.0

## Handelsgueter. Werden in M3 zu echten CargoType-Resources.
const RAW_GOODS: PackedStringArray = [
	"Zucker", "Tabak", "Kakao", "Kaffee", "Baumwolle", "Holz", "Gewürze",
]
const FINISHED_GOODS: PackedStringArray = [
	"Rum", "Stoffe", "Werkzeug", "Kanonen", "Lebensmittel",
]

var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
## Verzerrt den Weltrand. Ohne das ist die Karibik eine perfekte Kreisscheibe.
var edge_noise := FastNoiseLite.new()
## Hoechster Punkt der Welt - die Kartenfarben brauchen den tatsaechlichen
## Bereich, sonst besteht jede Insel nur aus Strand.
var max_height: float = 1.0
var world_size: float = 20480.0

var islands: Array[IslandData] = []
var towns: Array[TownData] = []
var nations: Array[NationData] = []

## Zelle -> Insel-Id, -1 bei Wasser.
var _cell_island: PackedInt32Array = PackedInt32Array()
var _cell_size: float = 40.0

## Wie weit unter den Meeresspiegel reicht Gelaende, das gebaut werden muss?
## In Hoehenwert-Einheiten; mit SEABED_GAIN entspricht 0.04 rund 15 Metern Tiefe.
##
## Ohne diese Marge entstanden Meshes nur fuer Chunks mit Land - der
## Meeresboden davor fehlte. Das Gelaende war eine Schale ohne Unterseite, und
## an steilen Kuesten sah man seitlich darunter hindurch ins Leere.
const SUBMERGED_MARGIN: float = 0.04

## Chunk-Belegung: 1, wenn der Chunk sichtbares Gelaende traegt. Ueber offener See braucht
## es kein Gelaendemesh - der Ozean-Shader deckt das ab. Bei 14 Prozent
## Landanteil spart das rund fuenf Sechstel der Arbeit.
var chunk_grid_size: int = 0
var _chunk_has_land: PackedByteArray = PackedByteArray()


func generate(world_seed: int, size: float, nation_list: Array[NationData]) -> void:
	rng.seed = world_seed
	world_size = size
	nations = nation_list
	_cell_size = world_size / float(ANALYSIS_SIZE)
	islands.clear()
	towns.clear()

	max_towns = rng.randi_range(MAX_TOWNS_RANGE.x, MAX_TOWNS_RANGE.y)
	_build_noise(world_seed)
	_calibrate_sea_level()
	_scan_landmasses()
	_place_towns()
	_assign_nations()
	_name_towns()
	_assign_economy()


# --- Stufe 1: Heightmap ---------------------------------------------------

func _build_noise(world_seed: int) -> void:
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Grundwellenlaenge rund 6 km. Bei 2,6 km entstanden nur Felsen von 2 km²,
	# auf denen keine Stadt Platz hat.
	noise.frequency = 1.0 / 6000.0
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 2.1
	noise.fractal_gain = 0.42
	# Domain-Warping bricht die runden Noise-Formen auf - ohne das sehen alle
	# Inseln aus wie Kleckse.
	noise.domain_warp_enabled = true
	noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	noise.domain_warp_amplitude = 420.0
	noise.domain_warp_frequency = 1.0 / 2400.0

	# Eigene Noise fuer den Weltrand, sehr grob - sie verschiebt die Kueste je
	# nach Richtung nach innen oder aussen.
	edge_noise.seed = world_seed + 7777
	edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	edge_noise.frequency = 1.0 / 9000.0
	edge_noise.fractal_octaves = 2


## Gelaendehoehe an einem Weltpunkt, 0.0 bis 1.0. Ueber [constant SEA_LEVEL]
## ist Land.
func height_at(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	return clampf(n * _falloff(x, z), 0.0, 1.0)


func is_land(x: float, z: float) -> bool:
	return height_at(x, z) > sea_level


## Milde Ueberhoehung des Ufers und Breite der Uferzone, normiert auf die
## Hoehenspanne der Welt.
##
## Bei 6 km Noise-Wellenlaenge verlaeuft die Kueste sonst fast waagerecht, und
## Inseln wirken wie flache Platten. Die Ueberhoehung gibt ihnen Kontur.
##
## Bewusst STUECKWEISE LINEAR statt als Potenzkurve: Eine Potenz hat bei t
## gegen 0 eine unendliche Ableitung, macht also am Meeresspiegel jede Kueste
## zur senkrechten Wand. Hier ist die Steigung ueberall endlich.
##
## Und bewusst MILDE. Ein Wert von 5.0 ergab Klippen rund um jede Insel. Die
## zerfaserte Silhouette, die urspruenglich zu dieser Kurve fuehrte, kam gar
## nicht von flachen Kuesten, sondern vom Rueckseiten-Culling im Gelaende-
## material - siehe chunk_manager.gd.
const COAST_GAIN: float = 2.5
const COAST_ZONE: float = 0.06

## Unter Wasser wird nicht aufgesteilt - der Schelf soll flach auslaufen.
const SEABED_GAIN: float = 1.0


## Gelaendehoehe in Metern, relativ zum Meeresspiegel. Negativ unter Wasser.
##
## Die einzige Stelle, an der Hoehenwerte zu Metern werden - Gelaendemesh,
## Kartenanzeige und Spiellogik muessen sich einig sein.
func elevation_at(x: float, z: float, scale: float) -> float:
	var span := maxf(max_height - sea_level, 0.001)
	var t := (height_at(x, z) - sea_level) / span
	if t >= 0.0:
		return _shape_coast(t) * span * scale
	return t * SEABED_GAIN * span * scale


## Hebt die Uferzone an, ohne die Gesamthoehe zu veraendern.
func _shape_coast(t: float) -> float:
	if t < COAST_ZONE:
		return t * COAST_GAIN
	# Der Rest wird so gestaucht, dass der hoechste Punkt gleich bleibt.
	var above := (1.0 - COAST_ZONE * COAST_GAIN) / (1.0 - COAST_ZONE)
	return COAST_ZONE * COAST_GAIN + (t - COAST_ZONE) * above


## Bestimmt den Meeresspiegel so, dass der Landanteil stimmt.
##
## Die Hoehen werden auf einem groben Raster abgetastet, sortiert, und der
## Meeresspiegel auf das passende Perzentil gelegt. Damit ist der Landanteil
## per Konstruktion richtig - unabhaengig davon, wie die Noise gerade streut.
func _calibrate_sea_level() -> void:
	var samples := PackedFloat32Array()
	var step := 4
	for iz in range(0, ANALYSIS_SIZE, step):
		for ix in range(0, ANALYSIS_SIZE, step):
			var world := _cell_to_world(ix, iz)
			samples.push_back(height_at(world.x, world.y))
	samples.sort()

	var index := int(float(samples.size()) * (1.0 - TARGET_LAND_SHARE))
	sea_level = samples[clampi(index, 0, samples.size() - 1)]
	deep_water = sea_level - DEEP_WATER_MARGIN
	max_height = maxf(samples[samples.size() - 1], sea_level + 0.01)


## Radialer Abfall zum Weltrand - so endet die Karte in offener See statt an
## einer abgeschnittenen Landmasse.
func _falloff(x: float, z: float) -> float:
	var half := world_size * 0.5
	var d := Vector2(x, z).length() / half
	# Innen voll wirksam, erst aussen abfallend - ein Abfall ab der Mitte
	# haette die halbe Karte geflutet. Das Wackeln bricht die Kreisform auf.
	var wobble := edge_noise.get_noise_2d(x, z) * 0.20
	return smoothstep(1.04 + wobble, 0.70 + wobble, d)


# --- Stufe 2 und 3: Inselmaske und Landmassen -----------------------------

func _scan_landmasses() -> void:
	var count := ANALYSIS_SIZE * ANALYSIS_SIZE
	var height := PackedFloat32Array()
	height.resize(count)
	_cell_island.resize(count)
	_cell_island.fill(-1)

	for iz in ANALYSIS_SIZE:
		for ix in ANALYSIS_SIZE:
			var world := _cell_to_world(ix, iz)
			height[iz * ANALYSIS_SIZE + ix] = height_at(world.x, world.y)

	# Flood-Fill trennt zusammenhaengende Landmassen voneinander.
	var queue := PackedInt32Array()
	for start in count:
		if height[start] <= sea_level or _cell_island[start] != -1:
			continue

		var island := IslandData.new()
		island.id = islands.size()

		queue.clear()
		queue.push_back(start)
		_cell_island[start] = island.id

		var cells := 0
		var sum := Vector2.ZERO
		var min_cell := Vector2i(ANALYSIS_SIZE, ANALYSIS_SIZE)
		var max_cell := Vector2i(-1, -1)
		var head := 0

		while head < queue.size():
			var index := queue[head]
			head += 1
			var cx := index % ANALYSIS_SIZE
			var cz := index / ANALYSIS_SIZE

			cells += 1
			var world := _cell_to_world(cx, cz)
			sum += world
			min_cell = min_cell.min(Vector2i(cx, cz))
			max_cell = max_cell.max(Vector2i(cx, cz))
			island.peak = maxf(island.peak, height[index])

			var coastal := false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := cx + offset.x
				var nz := cz + offset.y
				if nx < 0 or nz < 0 or nx >= ANALYSIS_SIZE or nz >= ANALYSIS_SIZE:
					coastal = true
					continue
				var neighbour := nz * ANALYSIS_SIZE + nx
				if height[neighbour] <= sea_level:
					coastal = true
				elif _cell_island[neighbour] == -1:
					_cell_island[neighbour] = island.id
					queue.push_back(neighbour)

			if coastal:
				island.coast_cells.push_back(world)
				if _has_deep_water_near(height, cx, cz):
					island.harbour_cells.push_back(world)

		var cell_area := _cell_size * _cell_size
		island.area_km2 = float(cells) * cell_area / 1_000_000.0
		island.center = sum / float(cells)
		var origin := _cell_to_world(min_cell.x, min_cell.y)
		var extent := _cell_to_world(max_cell.x, max_cell.y) - origin
		island.bounds = Rect2(origin, extent)
		islands.append(island)

	_build_chunk_map(height)


## Markiert alle Chunks mit sichtbarem Gelaende - Land, Kueste und der
## Meeresboden davor - plus deren direkte Nachbarn.
func _build_chunk_map(height: PackedFloat32Array) -> void:
	chunk_grid_size = int(ceil(world_size / TERRAIN_CHUNK_SIZE))
	_chunk_has_land.resize(chunk_grid_size * chunk_grid_size)
	_chunk_has_land.fill(0)

	var visible_floor := sea_level - SUBMERGED_MARGIN
	for iz in ANALYSIS_SIZE:
		for ix in ANALYSIS_SIZE:
			if height[iz * ANALYSIS_SIZE + ix] <= visible_floor:
				continue
			var world := _cell_to_world(ix, iz)
			var coord := chunk_coord_at(world.x, world.y)
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var cx := coord.x + dx
					var cz := coord.y + dz
					if cx < 0 or cz < 0 or cx >= chunk_grid_size or cz >= chunk_grid_size:
						continue
					_chunk_has_land[cz * chunk_grid_size + cx] = 1


## Weltposition -> Chunk-Koordinate.
func chunk_coord_at(x: float, z: float) -> Vector2i:
	var half := world_size * 0.5
	return Vector2i(
		floori((x + half) / TERRAIN_CHUNK_SIZE),
		floori((z + half) / TERRAIN_CHUNK_SIZE)
	)


## Ecke eines Chunks in Weltkoordinaten.
func chunk_origin(coord: Vector2i) -> Vector2:
	var half := world_size * 0.5
	return Vector2(
		-half + float(coord.x) * TERRAIN_CHUNK_SIZE,
		-half + float(coord.y) * TERRAIN_CHUNK_SIZE
	)


## Braucht dieser Chunk ein Gelaendemesh? Das gilt auch fuer Flachwasser -
## der Meeresboden gehoert dazu, sonst hat das Gelaende keine Unterseite.
func chunk_has_land(coord: Vector2i) -> bool:
	if coord.x < 0 or coord.y < 0 or coord.x >= chunk_grid_size or coord.y >= chunk_grid_size:
		return false
	return _chunk_has_land[coord.y * chunk_grid_size + coord.x] == 1


## Sucht tiefes Wasser im Umkreis. Direkt neben der Kueste ist das Wasser
## flach - ein Hafen braucht die Fahrrinne nur in der Naehe, nicht am Kai.
const HARBOUR_SEARCH_RADIUS: int = 4

func _has_deep_water_near(height: PackedFloat32Array, cx: int, cz: int) -> bool:
	for dz in range(-HARBOUR_SEARCH_RADIUS, HARBOUR_SEARCH_RADIUS + 1):
		for dx in range(-HARBOUR_SEARCH_RADIUS, HARBOUR_SEARCH_RADIUS + 1):
			var nx := cx + dx
			var nz := cz + dz
			if nx < 0 or nz < 0 or nx >= ANALYSIS_SIZE or nz >= ANALYSIS_SIZE:
				continue
			if height[nz * ANALYSIS_SIZE + nx] < deep_water:
				return true
	return false


func _cell_to_world(ix: int, iz: int) -> Vector2:
	var half := world_size * 0.5
	return Vector2(
		-half + (float(ix) + 0.5) * _cell_size,
		-half + (float(iz) + 0.5) * _cell_size
	)


# --- Stufe 4: Stadtplaetze ------------------------------------------------

## Waehlt Haefen aus den Kuestenkandidaten - moeglichst weit auseinander.
##
## Kein echtes Poisson-Disk-Sampling, sondern die einfache Variante: Kandidaten
## mischen, der Reihe nach nehmen, alles im Mindestabstand verwerfen. Bei
## einigen tausend Kandidaten reicht das und ist deutlich kuerzer.
func _place_towns() -> void:
	var candidates: Array[Vector2] = []
	var candidate_island: Array[int] = []
	for island: IslandData in islands:
		if not island.is_settleable():
			continue
		for cell: Vector2 in island.anchorages():
			candidates.append(cell)
			candidate_island.append(island.id)

	if candidates.is_empty():
		push_warning("WorldGenerator: keine besiedelbare Kueste gefunden")
		return

	# Gemeinsam mischen, damit Position und Insel-Id gepaart bleiben.
	var order := PackedInt32Array()
	order.resize(candidates.size())
	for i in candidates.size():
		order[i] = i
	_shuffle(order)

	var spacing := MIN_TOWN_DISTANCE
	# Bei wenig Kueste den Abstand schrittweise lockern, bis genug Haefen stehen.
	for relaxation in 4:
		for index: int in order:
			if towns.size() >= max_towns:
				break
			var position: Vector2 = candidates[index]
			if not _is_far_enough(position, spacing):
				continue
			var town := TownData.new()
			town.id = towns.size()
			town.position = position
			town.island_id = candidate_island[index]
			towns.append(town)
			islands[town.island_id].town_ids.push_back(town.id)
		if towns.size() >= MIN_TOWNS or towns.size() >= max_towns:
			break
		spacing *= 0.7

	_assign_town_sizes()


func _is_far_enough(position: Vector2, spacing: float) -> bool:
	var squared := spacing * spacing
	for town: TownData in towns:
		if town.position.distance_squared_to(position) < squared:
			return false
	return true


## Groesse haengt an der Insel: Auf einer grossen Landmasse liegen Staedte,
## auf einem Eiland ein Dorf.
func _assign_town_sizes() -> void:
	for town: TownData in towns:
		var island := islands[town.island_id]
		var roll := rng.randf()
		if island.area_km2 > 60.0 and roll > 0.45:
			town.size_tier = 1
		elif island.area_km2 > 20.0 and roll > 0.7:
			town.size_tier = 1
		else:
			town.size_tier = 0
		# Befestigung folgt der Groesse, mit Streuung.
		town.fort_strength = town.size_tier * 2 + rng.randi_range(0, 2)


# --- Stufe 5: Nationen ----------------------------------------------------

## Vier Kerngebiete per K-Means, danach ein Teil zufaellig umverteilt.
##
## Ohne die Umverteilung bekaeme jede Nation einen sauberen Block und die Karte
## waere langweilig. Die verstreuten Staedte erzeugen Grenzreibung - und damit
## Gelegenheiten fuer den Spieler.
const SCATTER_SHARE: float = 0.15
const KMEANS_ITERATIONS: int = 12

func _assign_nations() -> void:
	if towns.is_empty() or nations.is_empty():
		return

	var centers := _seed_centers()

	for iteration in KMEANS_ITERATIONS:
		var sums: Array[Vector2] = []
		var counts := PackedInt32Array()
		sums.resize(centers.size())
		counts.resize(centers.size())
		for i in centers.size():
			sums[i] = Vector2.ZERO

		for town: TownData in towns:
			var best := _nearest_center(town.position, centers)
			town.nation_id = nations[best].id
			sums[best] += town.position
			counts[best] += 1

		for i in centers.size():
			if counts[i] > 0:
				centers[i] = sums[i] / float(counts[i])

	# Streubesitz: ein Teil der Staedte wechselt zu einer anderen Nation.
	var scatter := int(float(towns.size()) * SCATTER_SHARE)
	for i in scatter:
		var town: TownData = towns[rng.randi() % towns.size()]
		town.nation_id = nations[rng.randi() % nations.size()].id

	_guarantee_minimum_holdings()
	_promote_capitals()


## Ungleiche Machtverteilung ist gewollt - eine Nation ohne nennenswerten
## Besitz waere aber nur noch eine Farbe auf der Karte.
const MIN_TOWNS_PER_NATION: int = 3

func _guarantee_minimum_holdings() -> void:
	for nation: NationData in nations:
		var owned := _towns_of(nation.id)
		while owned.size() < MIN_TOWNS_PER_NATION:
			# Vom groessten Besitzer nehmen, damit es nicht reihum kippt.
			var richest := _largest_owner(nation.id)
			if richest == null:
				return
			richest.nation_id = nation.id
			owned = _towns_of(nation.id)


func _towns_of(nation_id: int) -> Array[TownData]:
	var result: Array[TownData] = []
	for town: TownData in towns:
		if town.nation_id == nation_id:
			result.append(town)
	return result


## Eine Stadt der Nation mit dem meisten Besitz, oder null.
func _largest_owner(exclude_nation: int) -> TownData:
	var counts := {}
	for town: TownData in towns:
		counts[town.nation_id] = counts.get(town.nation_id, 0) + 1

	var best_nation := -1
	var best_count := MIN_TOWNS_PER_NATION
	for nation_id: int in counts:
		if nation_id == exclude_nation:
			continue
		if counts[nation_id] > best_count:
			best_count = counts[nation_id]
			best_nation = nation_id

	if best_nation < 0:
		return null
	for town: TownData in towns:
		if town.nation_id == best_nation:
			return town
	return null


## Startzentren moeglichst weit auseinander, damit K-Means nicht in einem
## Winkel der Karte kollabiert (k-means++ in kurz).
func _seed_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	centers.append(towns[rng.randi() % towns.size()].position)

	while centers.size() < nations.size():
		var farthest := towns[0].position
		var best_distance := -1.0
		for town: TownData in towns:
			var nearest := INF
			for center: Vector2 in centers:
				nearest = minf(nearest, town.position.distance_squared_to(center))
			if nearest > best_distance:
				best_distance = nearest
				farthest = town.position
		centers.append(farthest)
	return centers


func _nearest_center(position: Vector2, centers: Array[Vector2]) -> int:
	var best := 0
	var best_distance := INF
	for i in centers.size():
		var d := position.distance_squared_to(centers[i])
		if d < best_distance:
			best_distance = d
			best = i
	return best


## Jede Nation bekommt genau eine Hauptstadt: ihren Hafen auf der groessten Insel.
func _promote_capitals() -> void:
	for nation: NationData in nations:
		var best: TownData = null
		var best_area := -1.0
		for town: TownData in towns:
			if town.nation_id != nation.id:
				continue
			var area := islands[town.island_id].area_km2
			if area > best_area:
				best_area = area
				best = town
		if best != null:
			best.size_tier = 2
			best.fort_strength = maxi(best.fort_strength, 6)


# --- Stufe 6: Namen -------------------------------------------------------

func _name_towns() -> void:
	var generator := NameGenerator.new(rng)
	for town: TownData in towns:
		town.town_name = generator.generate(_nation_by_id(town.nation_id))


func _nation_by_id(nation_id: int) -> NationData:
	for nation: NationData in nations:
		if nation.id == nation_id:
			return nation
	return nations[0]


# --- Stufe 7: Wirtschaft --------------------------------------------------

## Produktion und Bedarf erzeugen das Preisgefaelle, aus dem in M3 die
## Handelsrouten entstehen. Grundregel: Wer etwas herstellt, braucht es nicht.
func _assign_economy() -> void:
	for town: TownData in towns:
		town.production.clear()
		town.demand.clear()

		var produced: Array[String] = []
		var raw_count := 1 if town.size_tier == 0 else 2
		for i in raw_count:
			var good := RAW_GOODS[rng.randi() % RAW_GOODS.size()]
			if good in produced:
				continue
			produced.append(good)
			town.production[good] = rng.randi_range(8, 20) * (town.size_tier + 1)

		# Groessere Staedte verarbeiten zusaetzlich.
		if town.size_tier >= 1:
			var finished := FINISHED_GOODS[rng.randi() % FINISHED_GOODS.size()]
			produced.append(finished)
			town.production[finished] = rng.randi_range(5, 12) * town.size_tier

		var wanted := 2 + town.size_tier
		for i in wanted:
			var pool := FINISHED_GOODS if rng.randf() > 0.4 else RAW_GOODS
			var good := pool[rng.randi() % pool.size()]
			if good in produced or town.demand.has(good):
				continue
			town.demand[good] = rng.randi_range(6, 18) * (town.size_tier + 1)

		# Startbestand: die Haelfte des Wochenbedarfs, damit Preise nicht bei
		# null beginnen.
		for good: String in town.demand:
			town.stock[good] = int(town.demand[good] * 0.5)


func _shuffle(array: PackedInt32Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var swap := array[i]
		array[i] = array[j]
		array[j] = swap
