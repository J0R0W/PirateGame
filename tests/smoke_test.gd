## Rauchtest fuer das M0-Geruest.
##
## Laufen lassen mit:
##   godot --headless --path . res://tests/smoke_test.tscn
##
## Prueft, dass alle Autoloads existieren und die Grundfunktionen zusammen-
## spielen. Beendet mit Code 0 bei Erfolg, sonst 1.
extends Node

var _failures: int = 0
## Mitgezaehlt, damit die Zahl in README.md nicht von Hand gepflegt werden muss.
var _checks: int = 0


func _ready() -> void:
	print("=== PirateGame Rauchtest ===")

	_check_autoloads()
	_check_input_map()
	_check_new_campaign()
	_check_determinism()
	_check_save_roundtrip()
	_check_sailing_math()
	_check_ocean_waves()
	_check_world_generation()
	_check_cargo_registry()
	_check_trade_math()
	_check_anchorages()
	_check_terraces()
	_check_town_markers()
	_check_market()
	_check_shipyard()
	_check_damage()
	_check_ship_model()
	_check_heading_convention()
	_check_gunnery()
	_check_hit_geometry()
	_check_salvo()
	_check_ship_ai()
	_check_ship_combat()
	_check_prize()
	_check_hiring()
	await _check_debug_knobs()
	await _check_duel()
	await _check_terrain()
	_check_code_conventions()
	_check_everything_loads()

	print("=== %s  (%d Pruefungen) ===" % [
		"BESTANDEN" if _failures == 0 else "%d FEHLER" % _failures, _checks
	])
	get_tree().quit(1 if _failures > 0 else 0)


func _check_autoloads() -> void:
	for name in ["EventBus", "WorldData", "GameState", "SaveManager", "AudioDirector", "SceneRouter"]:
		_assert(get_tree().root.get_node_or_null(NodePath(name)) != null, "Autoload %s geladen" % name)


func _check_input_map() -> void:
	var expected := [
		"helm_port", "helm_starboard", "sails_more", "sails_less",
		"fire_port", "fire_starboard", "interact", "spyglass",
		"toggle_map", "time_faster", "pause", "debug_menu",
	]
	for action: String in expected:
		var known := InputMap.has_action(action)
		var bound := known and not InputMap.action_get_events(action).is_empty()
		_assert(bound, "Eingabe %s belegt" % action)


func _check_new_campaign() -> void:
	GameState.new_campaign("Testkapitaen", 12345)
	_assert(GameState.captain_name == "Testkapitaen", "Kapitaensname gesetzt")
	_assert(GameState.gold == 500, "Startgold 500")
	_assert(GameState.crew == GameState.max_crew(), "Voll besetzt gestartet")
	_assert(WorldData.generated, "Welt als erzeugt markiert")
	_assert(WorldData.world_seed == 12345, "Seed uebernommen")
	_assert(WorldData.wind_strength > 0.0, "Wind hat Staerke")

	GameState.add_gold(250)
	_assert(GameState.gold == 750, "Gold addiert")
	GameState.add_gold(-10000)
	_assert(GameState.gold == 0, "Gold faellt nicht unter null")

	GameState.change_reputation(GameState.Nation.SPAIN, -150)
	_assert(GameState.reputation[GameState.Nation.SPAIN] == -100, "Ruf bei -100 begrenzt")

	GameState.add_notoriety(200)
	_assert(GameState.notoriety == 100, "Beruechtigtheit bei 100 begrenzt")

	GameState.game_minutes = 1440.0 * 3 + 720.0
	_assert(GameState.current_day() == 3, "Tag aus Spielminuten")
	_assert(is_equal_approx(GameState.time_of_day(), 0.5), "Mittag bei halbem Tag")


func _check_determinism() -> void:
	WorldData.generate(999)
	var first_direction := WorldData.wind_direction
	var first_strength := WorldData.wind_strength
	WorldData.generate(999)
	_assert(is_equal_approx(WorldData.wind_direction, first_direction), "Seed erzeugt gleichen Wind")
	_assert(is_equal_approx(WorldData.wind_strength, first_strength), "Seed erzeugt gleiche Staerke")

	WorldData.generate(1000)
	_assert(not is_equal_approx(WorldData.wind_direction, first_direction), "Anderer Seed, andere Welt")

	# Wind laesst sich gezielt setzen und bleibt im Winkelraum.
	WorldData.set_wind(deg_to_rad(90.0), 0.8)
	_assert(is_equal_approx(WorldData.wind_direction, deg_to_rad(90.0)), "Wind gesetzt")
	_assert(is_equal_approx(WorldData.wind_strength, 0.8), "Windstaerke gesetzt")
	WorldData.set_wind(deg_to_rad(270.0))
	_assert(WorldData.wind_direction <= PI and WorldData.wind_direction >= -PI, "Wind bleibt normalisiert")


func _check_save_roundtrip() -> void:
	GameState.new_campaign("Blackbeard", 4242)
	GameState.add_gold(1234)
	GameState.change_reputation(GameState.Nation.ENGLAND, -40)
	GameState.add_notoriety(17)
	GameState.damage_hull(23)
	GameState.add_cargo(&"rum", 7)
	GameState.add_cargo(&"cannons", 2)
	GameState.current_port_id = 0

	# Ein leergekauftes Lager ist die einzige Abweichung, die eine Stadt vom
	# generierten Zustand haben kann - genau die muss der Spielstand halten.
	var plundered: TownData = WorldData.towns[0]
	plundered.stock[&"sugar"] = 3.0
	plundered.discovered = true

	_assert(SaveManager.save_slot(99), "Spielstand geschrieben")
	_assert(SaveManager.has_save(99), "Spielstand gefunden")

	# Zustand verfaelschen, dann laden - die Werte muessen zurueckkommen.
	GameState.new_campaign("Ueberschrieben", 1)
	_assert(SaveManager.load_slot(99), "Spielstand gelesen")
	_assert(GameState.captain_name == "Blackbeard", "Name wiederhergestellt")
	_assert(GameState.gold == 1734, "Gold wiederhergestellt")
	_assert(GameState.notoriety == 17, "Beruechtigtheit wiederhergestellt")
	_assert(GameState.reputation[GameState.Nation.ENGLAND] == -40, "Ruf wiederhergestellt")
	_assert(WorldData.world_seed == 4242, "Weltseed wiederhergestellt")
	_assert(GameState.hull == GameState.max_hull() - 23, "Rumpfzustand wiederhergestellt")
	_assert(GameState.cargo_of(&"rum") == 7, "Ladung wiederhergestellt")
	_assert(GameState.cargo_of(&"cannons") == 2, "Zweite Ladung wiederhergestellt")
	_assert(GameState.ship_class != null, "Schiffsklasse wiederhergestellt")
	_assert(GameState.current_port_id == 0, "Liegeplatz wiederhergestellt")
	_assert(is_equal_approx(WorldData.towns[0].stock_of(&"sugar"), 3.0),
		"Lagerbestand der Stadt wiederhergestellt")
	_assert(WorldData.towns[0].discovered, "Besuchte Stadt bleibt bekannt")

	GameState.current_port_id = -1
	SaveManager.delete_slot(99)
	_assert(not SaveManager.has_save(99), "Spielstand geloescht")


func _check_sailing_math() -> void:
	# Wind kommt aus Norden (0). Kurse werden dagegen gemessen.
	var wind := 0.0
	_assert(is_equal_approx(SailingMath.sail_efficiency(0.0, wind), 0.05), "Direkt gegenan: In Irons")
	_assert(is_equal_approx(SailingMath.sail_efficiency(deg_to_rad(45.0), wind), 0.45), "45 Grad: am Wind")
	_assert(is_equal_approx(SailingMath.sail_efficiency(deg_to_rad(90.0), wind), 1.0), "90 Grad: optimal")
	_assert(is_equal_approx(SailingMath.sail_efficiency(deg_to_rad(180.0), wind), 0.75), "Vor dem Wind: 75 Prozent")

	# Backbord und Steuerbord muessen sich gleich verhalten.
	for angle: float in [20.0, 45.0, 90.0, 140.0]:
		var port := SailingMath.sail_efficiency(deg_to_rad(angle), wind)
		var starboard := SailingMath.sail_efficiency(deg_to_rad(-angle), wind)
		_assert(is_equal_approx(port, starboard), "Symmetrisch bei %d Grad" % int(angle))

	# Der Winkelraum muss umlaufen, nicht an der Naht brechen.
	_assert(is_equal_approx(
		SailingMath.sail_efficiency(deg_to_rad(350.0), 0.0),
		SailingMath.sail_efficiency(deg_to_rad(-10.0), 0.0)
	), "Winkel laeuft ueber 360 Grad um")

	_assert(SailingMath.point_of_sail(0.0, wind) == "In Irons", "Kursname In Irons")
	_assert(SailingMath.point_of_sail(deg_to_rad(90.0), wind) == "Raumschots", "Kursname Raumschots")

	# Eingeholte Segel bedeuten Stillstand, egal wie guenstig der Kurs ist.
	_assert(is_zero_approx(
		SailingMath.target_speed(12.0, deg_to_rad(90.0), wind, 1.0, 0.0)
	), "Ohne Segel keine Fahrt")
	_assert(is_equal_approx(
		SailingMath.target_speed(12.0, deg_to_rad(90.0), wind, 1.0, 1.0), 12.0
	), "Optimaler Kurs erreicht Grundgeschwindigkeit")
	_assert(
		SailingMath.target_speed(12.0, deg_to_rad(45.0), wind, 1.0, 1.0)
		< SailingMath.target_speed(12.0, deg_to_rad(90.0), wind, 1.0, 1.0),
		"Am Wind langsamer als raumschots"
	)

	# Traege Annaeherung: monoton steigend, nie ueber das Ziel hinaus.
	var value := 0.0
	var monotonic := true
	for i in 600:
		var next := SailingMath.approach(value, 10.0, 2.0, 1.0 / 60.0)
		if next < value or next > 10.0:
			monotonic = false
		value = next
	_assert(monotonic, "Annaeherung steigt monoton und schiesst nie ueber")
	_assert(value > 9.9 and value < 10.0, "Nach 10 Sekunden nahezu am Ziel")

	# Zeitkonstante: nach [inertia] Sekunden sind rund 63 Prozent erreicht.
	var tc := 0.0
	for i in 120:
		tc = SailingMath.approach(tc, 10.0, 2.0, 2.0 / 120.0)
	_assert(absf(tc - 6.32) < 0.1, "Zeitkonstante trifft 63 Prozent")

	# Framerate darf das Ergebnis nicht verschieben.
	var at_60 := 0.0
	for i in 120:
		at_60 = SailingMath.approach(at_60, 10.0, 2.0, 1.0 / 60.0)
	var at_30 := 0.0
	for i in 60:
		at_30 = SailingMath.approach(at_30, 10.0, 2.0, 1.0 / 30.0)
	_assert(absf(at_60 - at_30) < 0.01, "Framerate-unabhaengig")
	_assert(is_equal_approx(SailingMath.approach(5.0, 5.0, 2.0, 0.016), 5.0), "Am Ziel bleibt es stehen")

	_assert(SailingMath.SAIL_STEPS.size() == SailingMath.SAIL_NAMES.size(), "Segelstufen und Namen passen zusammen")


func _check_ocean_waves() -> void:
	# Amplituden summieren sich zu 1.22 - die See darf diesen Rahmen nie verlassen.
	var limit: float = 1.22 * OceanWaves.WAVE_HEIGHT
	var lowest := INF
	var highest := -INF
	for i in 400:
		var x := float(i) * 7.3
		var z := float(i) * -3.1
		var t := float(i) * 0.37
		var h: float = OceanWaves.height_at(x, z, t)
		lowest = minf(lowest, h)
		highest = maxf(highest, h)
	_assert(highest <= limit and lowest >= -limit, "Wellenhoehe bleibt im Rahmen")
	_assert(highest > 0.3 and lowest < -0.3, "Die See ist tatsaechlich bewegt")

	# Deterministisch: gleicher Ort und gleiche Zeit ergeben dieselbe Hoehe.
	_assert(is_equal_approx(
		OceanWaves.height_at(120.0, -45.0, 8.5),
		OceanWaves.height_at(120.0, -45.0, 8.5)
	), "Wellenhoehe ist reproduzierbar")

	# Benachbarte Punkte duerfen nicht springen, sonst zittert das Schiff.
	var previous: float = OceanWaves.height_at(0.0, 0.0, 3.0)
	var smooth := true
	for i in range(1, 200):
		var h: float = OceanWaves.height_at(float(i) * 0.25, 0.0, 3.0)
		if absf(h - previous) > 0.1:
			smooth = false
		previous = h
	_assert(smooth, "Wellenfeld ist stetig")


func _check_world_generation() -> void:
	WorldData.generate(4242)

	_assert(WorldData.nations.size() == 4, "Vier Nationen geladen")
	_assert(not WorldData.islands.is_empty(), "Inseln erzeugt")
	_assert(WorldData.towns.size() >= WorldGenerator.MIN_TOWNS, "Genug Haefen erzeugt")
	_assert(WorldData.towns.size() <= WorldGenerator.MAX_TOWNS_RANGE.y, "Nicht mehr Haefen als erlaubt")

	# Der Meeresspiegel wird pro Welt kalibriert - der Landanteil muss treffen.
	var land := 0
	var samples := 0
	var half := WorldData.WORLD_SIZE * 0.5
	for iz in 100:
		for ix in 100:
			var x := -half + (float(ix) + 0.5) * (WorldData.WORLD_SIZE / 100.0)
			var z := -half + (float(iz) + 0.5) * (WorldData.WORLD_SIZE / 100.0)
			samples += 1
			if WorldData.is_land(x, z):
				land += 1
	var share := float(land) / float(samples)
	_assert(absf(share - WorldGenerator.TARGET_LAND_SHARE) < 0.04,
		"Landanteil trifft Vorgabe (%.1f%%)" % (share * 100.0))

	# Kein Land am Weltrand - die Karte muss in offener See enden.
	# Ueber mehrere Seeds geprueft: Die Randverzerrung schiebt die Kueste je
	# nach Richtung nach aussen, das darf sie nie bis an die Kante tun.
	var edge_seeds_ok := 0
	var edge_seeds: Array[int] = [1, 42, 777, 4242, 90210, 555555, 31337, 8888888]
	for edge_seed: int in edge_seeds:
		WorldData.generate(edge_seed)
		var clean := true
		for i in 80:
			var t := -half + float(i) * (WorldData.WORLD_SIZE / 80.0)
			if WorldData.is_land(t, -half + 40.0) or WorldData.is_land(t, half - 40.0) \
					or WorldData.is_land(-half + 40.0, t) or WorldData.is_land(half - 40.0, t):
				clean = false
				break
		if clean:
			edge_seeds_ok += 1
	_assert(edge_seeds_ok == edge_seeds.size(),
		"Kein Land am Weltrand (%d von %d Seeds)" % [edge_seeds_ok, edge_seeds.size()])

	WorldData.generate(4242)

	# Jede Stadt: gueltige Nation, benannt, auf einer besiedelbaren Insel.
	var all_named := true
	var all_placed := true
	var names := {}
	var duplicates := false
	for town: TownData in WorldData.towns:
		if town.town_name.is_empty() or town.town_name == "Namenlos":
			all_named = false
		if names.has(town.town_name):
			duplicates = true
		names[town.town_name] = true
		if WorldData.get_nation(town.nation_id) == null:
			all_placed = false
		if town.island_id < 0 or town.island_id >= WorldData.islands.size():
			all_placed = false
	_assert(all_named, "Alle Staedte benannt")
	_assert(not duplicates, "Keine doppelten Ortsnamen")
	_assert(all_placed, "Alle Staedte haben Nation und Insel")

	# Mindestabstand einhalten - Haefen duerfen nicht uebereinander liegen.
	var too_close := 0
	for i in WorldData.towns.size():
		for j in range(i + 1, WorldData.towns.size()):
			var d: float = WorldData.towns[i].position.distance_to(WorldData.towns[j].position)
			if d < WorldGenerator.MIN_TOWN_DISTANCE * 0.69:
				too_close += 1
	_assert(too_close == 0, "Haefen halten Mindestabstand")

	# Jede Nation bekommt Gebiet und genau eine Hauptstadt.
	for nation: NationData in WorldData.nations:
		var owned := 0
		var capitals := 0
		for town: TownData in WorldData.towns:
			if town.nation_id == nation.id:
				owned += 1
				if town.size_tier == 2:
					capitals += 1
		_assert(owned > 0, "%s besitzt Staedte" % nation.display_name)
		_assert(capitals == 1, "%s hat genau eine Hauptstadt" % nation.display_name)

	# Wirtschaft: Was eine Stadt herstellt, fragt sie nicht nach.
	var overlap := false
	var has_trade := true
	for town: TownData in WorldData.towns:
		if town.production.is_empty() or town.demand.is_empty():
			has_trade = false
		for good: StringName in town.production:
			if town.demand.has(good):
				overlap = true
	_assert(has_trade, "Jede Stadt produziert und braucht etwas")
	_assert(not overlap, "Keine Stadt kauft, was sie selbst herstellt")

	# Derselbe Seed muss dieselbe Karibik ergeben.
	var first_names: Array[String] = []
	for town: TownData in WorldData.towns:
		first_names.append(town.town_name)
	var first_count := WorldData.islands.size()

	WorldData.generate(4242)
	var same := WorldData.towns.size() == first_names.size() \
		and WorldData.islands.size() == first_count
	if same:
		for i in WorldData.towns.size():
			if WorldData.towns[i].town_name != first_names[i]:
				same = false
	_assert(same, "Gleicher Seed erzeugt dieselbe Welt")

	WorldData.generate(9999)
	var different := WorldData.towns.is_empty() or first_names.is_empty() \
		or WorldData.towns[0].town_name != first_names[0]
	_assert(different, "Anderer Seed erzeugt eine andere Welt")

	# height_at muss ueberall einen gueltigen Wert liefern.
	var in_range := true
	for i in 500:
		var x := randf_range(-half, half)
		var z := randf_range(-half, half)
		var h := WorldData.height_at(x, z)
		if h < 0.0 or h > 1.0 or is_nan(h):
			in_range = false
	_assert(in_range, "Hoehenfunktion bleibt in 0 bis 1")


## Laedt jedes Skript und jede Szene des Projekts.
##
## Anlass: Ein Funktionsaufruf in einer const-Deklaration liess compass.gd nicht
## mehr parsen. Das Spiel lief weiter - nur ohne Kompass. Ein Parse-Fehler
## erscheint als Zeile in der Godot-Ausgabe, und die geht zwischen Warnungen
## unter. Hier wird er zu einem roten Test.
## Prueft die Ankerplaetze vor den Staedten.
##
## Hier stand das Schiff nach dem Auslaufen im Berg: Die Richtung "vom
## Inselmittelpunkt weg" zeigt bei langgestreckten Inseln an der Kueste
## entlang, nicht aufs Meer.
func _check_anchorages() -> void:
	for world_seed: int in [42, 1337, 90210]:
		WorldData.generate(world_seed)
		var dry: Array[String] = []
		var far: Array[String] = []
		for town: TownData in WorldData.towns:
			var anchor := WorldData.anchorage_for(town)
			if WorldData.is_land(anchor.x, anchor.y):
				dry.append(town.town_name)
			elif not WorldData.generator.is_navigable(anchor.x, anchor.y):
				dry.append(town.town_name + " (zu flach)")
			if anchor.distance_to(town.position) > 900.0:
				far.append(town.town_name)
		_assert(dry.is_empty(), "Seed %d: jeder Ankerplatz liegt in fahrbarem Wasser%s"
			% [world_seed, _offenders(dry)])
		_assert(far.is_empty(), "Seed %d: jeder Ankerplatz liegt nahe an seiner Stadt%s"
			% [world_seed, _offenders(far)])


## Prueft die eingeebneten Stadtterrassen.
func _check_terraces() -> void:
	WorldData.generate(42)
	var g := WorldData.generator
	var bumpy: Array[String] = []
	var flooded: Array[String] = []

	for town: TownData in WorldData.towns:
		var lowest := INF
		var highest := -INF
		# Vier Punkte im ebenen Kern, nicht nur die Mitte.
		for angle in 4:
			var direction := Vector2.RIGHT.rotated(float(angle) * TAU / 4.0)
			var probe := town.position + direction * (WorldGenerator.TERRACE_CORE * 0.8)
			var y := WorldData.terrain_y(probe.x, probe.y)
			lowest = minf(lowest, y)
			highest = maxf(highest, y)
		if highest - lowest > 1.0:
			bumpy.append("%s (%.1f m)" % [town.town_name, highest - lowest])
		if lowest <= 0.0:
			flooded.append(town.town_name)

	_assert(bumpy.is_empty(), "Jede Stadt steht auf ebenem Grund%s" % _offenders(bumpy))
	_assert(flooded.is_empty(), "Keine Stadt steht im Wasser%s" % _offenders(flooded))

	# Die Terrasse darf die Welt nicht umkrempeln - sie ist ein Uferstreifen,
	# kein Landgewinn.
	var land := 0
	var samples := 4096
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in samples:
		var x := rng.randf_range(-g.world_size * 0.5, g.world_size * 0.5)
		var z := rng.randf_range(-g.world_size * 0.5, g.world_size * 0.5)
		if WorldData.is_land(x, z):
			land += 1
	var share := float(land) / float(samples)
	_assert(share > 0.08 and share < 0.22, "Landanteil bleibt plausibel (%.1f %%)" % (share * 100.0))


## Prueft die sichtbaren Siedlungen.
##
## Hier schwebten die Haeuser ueber dem Hang: Gesetzt wurden sie auf
## elevation_at(), gezeichnet wird aber die gerade Flaeche zwischen den
## Gitterpunkten des Meshes. Zwischen beiden liegen an einer Kueste mehrere
## Meter.
func _check_town_markers() -> void:
	WorldData.generate(42)
	var g := WorldData.generator
	var town: TownData = WorldData.towns[0]

	# Die Platzierungsfunktion muss die GERENDERTE Flaeche treffen, nicht die
	# Hoehenfunktion. Gegengeprueft wird gegen das Mesh selbst.
	var coord := g.chunk_coord_at(town.position.x, town.position.y)
	var mesh := TerrainChunk.build(
		g, coord, WorldGenerator.TERRAIN_RESOLUTION, WorldData.TERRAIN_HEIGHT_SCALE
	)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var origin := g.chunk_origin(coord)

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var worst := 0.0
	var checked := 0
	for i in 60:
		var local_x := rng.randf_range(4.0, WorldGenerator.TERRAIN_CHUNK_SIZE - 4.0)
		var local_z := rng.randf_range(4.0, WorldGenerator.TERRAIN_CHUNK_SIZE - 4.0)
		var from_mesh := _mesh_height(vertices, indices, local_x, local_z)
		if is_nan(from_mesh):
			continue
		checked += 1
		var from_function := WorldData.terrain_surface_y(
			origin.x + local_x, origin.y + local_z
		)
		worst = maxf(worst, absf(from_mesh - from_function))
	_assert(checked > 40, "Genug Punkte im Chunk getroffen (%d)" % checked)
	_assert(worst < 0.01, "Aufsetzhoehe trifft das gezeichnete Mesh (%.4f m Abweichung)" % worst)

	# Und sie muss sich messbar von der reinen Hoehenfunktion unterscheiden -
	# sonst waere die ganze Funktion ueberfluessig.
	var spread := 0.0
	for i in 200:
		var x := town.position.x + rng.randf_range(-400.0, 400.0)
		var z := town.position.y + rng.randf_range(-400.0, 400.0)
		spread = maxf(spread, absf(
			WorldData.terrain_surface_y(x, z) - WorldData.terrain_y(x, z)
		))
	_assert(spread > 0.5,
		"Gezeichnete Flaeche weicht von der Hoehenfunktion ab (%.1f m)" % spread)

	# Die Siedlung selbst: richtige Zahl Haeuser, Fahne in Nationsfarbe,
	# nichts schwebt.
	var nation := WorldData.get_nation(town.nation_id)
	var marker := TownMarker.new()
	add_child(marker)
	marker.setup(town, nation.color)

	var expected := TownMarker.HOUSE_COUNT[clampi(town.size_tier, 0, 2)]
	# Je Haus ein Rumpf und ein Dach, dazu Stange und Fahne.
	_assert(marker.get_child_count() == expected * 2 + 2,
		"Siedlung hat %d Haeuser, Stange und Fahne" % expected)

	var floating: Array[String] = []
	var flagged := false
	for child in marker.get_children():
		var instance := child as MeshInstance3D
		var box := instance.mesh as BoxMesh
		if instance.material_override.albedo_color.is_equal_approx(nation.color):
			flagged = true
		if not instance.material_override.albedo_color.is_equal_approx(Palette.WALL):
			continue
		# Die Unterkante jedes Hauses muss im Boden stecken.
		var bottom := instance.position.y - box.size.y * 0.5
		var ground := WorldData.terrain_surface_y(instance.position.x, instance.position.z)
		if bottom > ground:
			floating.append("%.1f m" % (bottom - ground))
	_assert(flagged, "Die Fahne traegt die Farbe der Nation")
	_assert(floating.is_empty(), "Kein Haus schwebt ueber dem Gelaende%s" % _offenders(floating))

	marker.queue_free()


## Hoehe des Meshes an einem lokalen Punkt, aus den Dreiecken selbst gelesen.
## NAN, wenn der Punkt in keinem Dreieck liegt.
func _mesh_height(
	vertices: PackedVector3Array, indices: PackedInt32Array, x: float, z: float
) -> float:
	var point := Vector2(x, z)
	var triangle := 0
	while triangle < indices.size():
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		triangle += 3

		var pa := Vector2(a.x, a.z)
		var pb := Vector2(b.x, b.z)
		var pc := Vector2(c.x, c.z)
		var area := (pb - pa).cross(pc - pa)
		if absf(area) < 0.0001:
			continue
		var u := (pb - point).cross(pc - point) / area
		var v := (pc - point).cross(pa - point) / area
		var w := 1.0 - u - v
		if u < -0.0001 or v < -0.0001 or w < -0.0001:
			continue
		return a.y * u + b.y * v + c.y * w
	return NAN


## Prueft die Warenliste.
func _check_cargo_registry() -> void:
	var cargo_list := CargoRegistry.all()
	_assert(cargo_list.size() == CargoRegistry.RAW_IDS.size() + CargoRegistry.FINISHED_IDS.size(),
		"Alle Waren geladen (%d)" % cargo_list.size())

	var seen := {}
	var complete := true
	for cargo: CargoType in cargo_list:
		if cargo == null or cargo.display_name.is_empty() or cargo.base_price <= 0:
			complete = false
		elif seen.has(cargo.id):
			complete = false
		else:
			seen[cargo.id] = true
	_assert(complete, "Jede Ware hat Id, Namen und Preis")

	# Die Reihenfolge geht in die Weltgenerierung ein - sie darf sich zwischen
	# zwei Aufrufen nicht aendern, sonst haette derselbe Seed eine andere
	# Wirtschaft.
	_assert(CargoRegistry.ids() == CargoRegistry.ids(), "Warenreihenfolge ist stabil")
	_assert(not CargoRegistry.has(&"kraken"), "Unbekannte Ware wird nicht erfunden")


## Prueft die Preisformel - ohne Stadt, ohne Szene.
func _check_trade_math() -> void:
	var reference := 40.0
	var volatility := 0.4

	_assert(is_equal_approx(TradeMath.price_multiplier(reference, reference, volatility), 1.0),
		"Ausgeglichenes Lager kostet den Basispreis")

	var scarce := TradeMath.price_multiplier(reference * 0.25, reference, volatility)
	var plenty := TradeMath.price_multiplier(reference * 3.0, reference, volatility)
	_assert(scarce > 1.0 and plenty < 1.0, "Knappheit verteuert, Ueberfluss verbilligt")

	# Monotonie ueber den ganzen Bereich, nicht nur an drei Punkten.
	var monotone := true
	var previous := TradeMath.price_multiplier(0.0, reference, volatility)
	for step in 40:
		var current := TradeMath.price_multiplier(float(step) * 5.0, reference, volatility)
		if current > previous + 0.0001:
			monotone = false
		previous = current
	_assert(monotone, "Preis faellt monoton mit dem Bestand")

	_assert(TradeMath.price_multiplier(0.0, reference, volatility) <= 1.0 + volatility * 2.0
		and TradeMath.price_multiplier(9999.0, reference, volatility) >= 1.0 - volatility,
		"Preis bleibt in den Grenzen der Volatilitaet")

	# Mengenrabatt gibt es nicht - im Gegenteil.
	var single := TradeMath.buy_cost(100, reference, reference, volatility, 1)
	var ten := TradeMath.buy_cost(100, reference, reference, volatility, 10)
	_assert(ten > single * 10, "Grosse Kaeufe treiben den Preis")
	_assert(TradeMath.sell_revenue(100, reference, reference, volatility, 10)
		< TradeMath.sell_revenue(100, reference, reference, volatility, 1) * 10,
		"Grosse Verkaeufe druecken den Preis")

	# Der wichtigste Test des ganzen Marktes: Sofort zurueckverkaufen muss
	# Geld kosten. Sonst waere der Markt ein Sparbuch mit Zinsen.
	var cost := TradeMath.buy_cost(100, reference, reference, volatility, 5)
	var back := TradeMath.sell_revenue(100, reference - 5.0, reference, volatility, 5)
	_assert(back < cost, "Kaufen und sofort zurueckverkaufen ist ein Verlust")

	# Erholung: gleiche Spielzeit, gleiches Ergebnis - unabhaengig davon, in
	# wie vielen Schritten sie verrechnet wurde.
	var one_step := TradeMath.relax(10.0, 100.0, 2.0)
	var two_steps := TradeMath.relax(TradeMath.relax(10.0, 100.0, 1.0), 100.0, 1.0)
	_assert(absf(one_step - two_steps) < 0.001, "Erholung haengt nur an der Zeit")
	_assert(TradeMath.relax(10.0, 100.0, 400.0) > 99.0, "Erholung erreicht ihr Ziel")
	_assert(is_equal_approx(TradeMath.relax(50.0, 50.0, 5.0), 50.0),
		"Ein Lager am Ziel bewegt sich nicht")


## Prueft Staedte als Markt und den Handel daran.
func _check_market() -> void:
	GameState.new_campaign("Haendler", 20250825)
	_assert(not WorldData.towns.is_empty(), "Welt hat Staedte zum Handeln")
	if WorldData.towns.is_empty():
		return

	# Jede Stadt handelt jede Ware. Ein fehlender Bestand waere ein leeres
	# Lager und damit Hoechstpreis - hier lag der Fehler, mit dem sich Holz an
	# jedes Dorf zum Doppelten verkaufen liess.
	var complete := true
	for town: TownData in WorldData.towns:
		for cargo_id: StringName in CargoRegistry.ids():
			if not town.stock.has(cargo_id):
				complete = false
	_assert(complete, "Jede Stadt fuehrt jede Ware")

	# Es muss eine Route geben, die sich lohnt: irgendeine Ware, die irgendwo
	# billiger zu kaufen als anderswo zu verkaufen ist.
	var best_margin := 0
	var best_route := ""
	for cargo: CargoType in CargoRegistry.all():
		var cheapest: TownData = null
		var dearest: TownData = null
		for town: TownData in WorldData.towns:
			if cheapest == null or town.buy_price(cargo) < cheapest.buy_price(cargo):
				cheapest = town
			if dearest == null or town.sell_price(cargo) > dearest.sell_price(cargo):
				dearest = town
		var margin := dearest.sell_price(cargo) - cheapest.buy_price(cargo)
		if margin > best_margin:
			best_margin = margin
			best_route = "%s: %s -> %s" % [cargo.display_name, cheapest.town_name, dearest.town_name]
	_assert(best_margin > 0, "Es gibt eine profitable Handelsroute (%s, +%d je Einheit)"
		% [best_route, best_margin])

	# Wer erzeugt, verkauft billiger als der, der braucht.
	var producer_cheaper := true
	for cargo: CargoType in CargoRegistry.all():
		var producer_sum := 0
		var producer_count := 0
		var consumer_sum := 0
		var consumer_count := 0
		for town: TownData in WorldData.towns:
			if town.is_producer(cargo.id):
				producer_sum += town.buy_price(cargo)
				producer_count += 1
			elif town.is_consumer(cargo.id):
				consumer_sum += town.buy_price(cargo)
				consumer_count += 1
		if producer_count > 0 and consumer_count > 0:
			if float(producer_sum) / producer_count >= float(consumer_sum) / consumer_count:
				producer_cheaper = false
	_assert(producer_cheaper, "Erzeuger sind billiger als Abnehmer")

	_check_trade_limits()
	_check_trade_bookkeeping()
	_check_trade_loop()
	_check_docking_reach()


## Die Schleife von M3: guenstig kaufen, woanders teuer verkaufen.
##
## Das ist das Abnahmekriterium des Meilensteins - deshalb wird es gefahren
## und nicht nur behauptet.
func _check_trade_loop() -> void:
	var cargo := CargoRegistry.get_cargo(&"sugar")
	var cheapest: TownData = null
	var dearest: TownData = null
	for town: TownData in WorldData.towns:
		if cheapest == null or town.buy_price(cargo) < cheapest.buy_price(cargo):
			cheapest = town
		if dearest == null or town.sell_price(cargo) > dearest.sell_price(cargo):
			dearest = town

	GameState.gold = 3000
	GameState.cargo.clear()
	var purse := GameState.gold

	var bought := Trade.buy(cheapest, cargo, 20)
	_assert(bought > 0, "Im billigen Hafen laesst sich %s kaufen" % cargo.display_name)
	var sold := Trade.sell(dearest, cargo, bought)
	_assert(sold == bought, "Im teuren Hafen wird die ganze Ladung verkauft")
	_assert(GameState.gold > purse,
		"Die Handelsfahrt traegt sich (%d -> %d Gold, %s nach %s)"
		% [purse, GameState.gold, cheapest.town_name, dearest.town_name])

	# Und dieselbe Fahrt zurueck ist ein Verlustgeschaeft - sonst waere die
	# Richtung der Route egal.
	GameState.gold = 3000
	GameState.cargo.clear()
	purse = GameState.gold
	var wrong_way := Trade.buy(dearest, cargo, 20)
	Trade.sell(cheapest, cargo, wrong_way)
	_assert(GameState.gold < purse, "Die Route rueckwaerts kostet Geld")

	GameState.cargo.clear()


## Reichweite zum Anlegen. Der Segelmodus fragt genau so.
func _check_docking_reach() -> void:
	var town: TownData = WorldData.towns[0]
	var anchor := WorldData.anchorage_for(town)
	_assert(WorldData.dockable_town(anchor) == town,
		"Vom Ankerplatz aus ist der Hafen erreichbar")

	var far := town.position + Vector2(4000.0, 0.0)
	_assert(WorldData.dockable_town(far) == null,
		"Vier Kilometer weiter ist kein Hafen in Reichweite")


func _check_trade_limits() -> void:
	var town: TownData = WorldData.towns[0]
	var cargo := CargoRegistry.get_cargo(&"sugar")

	GameState.gold = 0
	_assert(Trade.max_buyable(town, cargo) == 0, "Ohne Gold kein Kauf")
	_assert(Trade.buy(town, cargo, 10) == 0, "Kauf ohne Gold bleibt folgenlos")

	GameState.gold = 1000000
	GameState.cargo.clear()
	var by_hold := Trade.max_buyable(town, cargo)
	_assert(by_hold <= GameState.cargo_capacity(), "Der Laderaum begrenzt den Kauf")

	town.stock[cargo.id] = 3.0
	_assert(Trade.max_buyable(town, cargo) == 3, "Der Vorrat der Stadt begrenzt den Kauf")

	# Sperrgut belegt doppelt so viel Platz.
	var cannons := CargoRegistry.get_cargo(&"cannons")
	GameState.cargo.clear()
	GameState.add_cargo(cannons.id, 3)
	_assert(GameState.cargo_used() == 3 * cannons.unit_size,
		"Sperrgut belegt mehrfachen Laderaum")
	GameState.cargo.clear()


func _check_trade_bookkeeping() -> void:
	var town: TownData = WorldData.towns[0]
	var cargo := CargoRegistry.get_cargo(&"sugar")
	town.stock[cargo.id] = 200.0

	GameState.gold = 5000
	GameState.cargo.clear()

	var before_gold := GameState.gold
	var before_stock := town.stock_of(cargo.id)
	var quoted := town.buy_cost(cargo, 6)
	var bought := Trade.buy(town, cargo, 6)

	_assert(bought == 6, "Kauf liefert die gewuenschte Menge")
	_assert(GameState.gold == before_gold - quoted, "Der Kauf kostet genau den Anschlagspreis")
	_assert(GameState.cargo_of(cargo.id) == 6, "Die Ware liegt im Laderaum")
	_assert(is_equal_approx(town.stock_of(cargo.id), before_stock - 6.0),
		"Das Lager der Stadt schrumpft um die gekaufte Menge")

	var revenue := town.sell_revenue(cargo, 6)
	var sold := Trade.sell(town, cargo, 6)
	_assert(sold == 6, "Verkauf liefert die gewuenschte Menge")
	_assert(GameState.cargo_of(cargo.id) == 0, "Der Laderaum ist wieder leer")
	_assert(GameState.gold == before_gold - quoted + revenue, "Der Erloes kommt an")
	_assert(GameState.gold < before_gold, "Hin und zurueck kostet die Handelsspanne")
	_assert(is_equal_approx(town.stock_of(cargo.id), before_stock),
		"Das Lager ist danach wieder so voll wie zuvor")

	_assert(Trade.sell(town, cargo, 5) == 0, "Was man nicht hat, verkauft man nicht")

	# Erholung: ein leergekauftes Lager fuellt sich mit der Zeit.
	town.stock[cargo.id] = 0.0
	var target := town.target_stock(cargo.id)
	town.advance_economy(30.0)
	_assert(town.stock_of(cargo.id) > target * 0.9, "Ein leeres Lager erholt sich")


func _check_shipyard() -> void:
	var town: TownData = WorldData.towns[0]

	GameState.hull = GameState.max_hull()
	GameState.sails = GameState.max_sails()
	_assert(Shipyard.full_repair_cost(town) == 0, "Ein heiles Schiff kostet nichts")
	_assert(Shipyard.repair(town) == 0, "Ein heiles Schiff wird nicht repariert")

	GameState.hull = GameState.max_hull() - 30
	GameState.sails = GameState.max_sails() - 10
	var cost := Shipyard.full_repair_cost(town)
	_assert(cost > 0, "Schaden kostet Gold")

	GameState.gold = cost + 100
	var spent := Shipyard.repair(town)
	_assert(spent == cost, "Die Werft nimmt den angeschlagenen Preis")
	_assert(GameState.hull == GameState.max_hull() and GameState.sails == GameState.max_sails(),
		"Nach der Reparatur ist das Schiff heil")
	_assert(GameState.gold == 100, "Die Reparatur wird bezahlt")

	# Teilreparatur: wer zu wenig hat, bekommt, was das Gold hergibt.
	GameState.hull = GameState.max_hull() - 40
	GameState.gold = 100
	var partial := Shipyard.repair(town)
	_assert(partial > 0 and partial <= 100, "Teilreparatur bleibt im Budget")
	_assert(GameState.gold >= 0, "Die Werft macht keine Schulden")
	_assert(GameState.hull > GameState.max_hull() - 40, "Teilreparatur bessert wirklich aus")

	# Eine Hauptstadt hat Trockendocks, ein Dorf einen Zimmermann.
	var village := TownData.new()
	village.size_tier = 0
	var capital := TownData.new()
	capital.size_tier = 2
	_assert(Shipyard.repair_cost(capital, 50, 0) < Shipyard.repair_cost(village, 50, 0),
		"Die Hauptstadt repariert billiger als das Dorf")


## Schaden am Schiff und was er bewirkt.
func _check_damage() -> void:
	GameState.hull = GameState.max_hull()
	GameState.sails = GameState.max_sails()

	GameState.damage_hull(25)
	_assert(GameState.hull == GameState.max_hull() - 25, "Rumpfschaden kommt an")
	GameState.damage_hull(100000)
	_assert(GameState.hull == 0, "Der Rumpf faellt nicht unter null")

	GameState.sails = GameState.max_sails() / 2
	_assert(is_equal_approx(GameState.sail_condition(), 0.5), "Halbe Segel, halber Zustand")

	# Zerschossene Segel muessen Fahrt kosten - sonst waere Schaden nur eine
	# Zahl im HUD.
	var healthy := SailingMath.target_speed(12.0, 0.0, PI, 1.0, 1.0)
	var damaged := SailingMath.target_speed(12.0, 0.0, PI, 1.0, 0.5)
	_assert(damaged < healthy, "Beschaedigte Segel ziehen weniger")

	GameState.hull = GameState.max_hull()
	GameState.sails = GameState.max_sails()


# --- Gefecht ---------------------------------------------------------------

func _check_gunnery() -> void:
	# Querab heisst querab: Steuerbord liegt 90 Grad rechts vom Kurs.
	_assert(is_equal_approx(Gunnery.abeam(0.0, Gunnery.STARBOARD), PI * 0.5),
		"Steuerbord liegt bei Kurs Nord im Osten")
	_assert(is_equal_approx(Gunnery.abeam(0.0, Gunnery.PORT), -PI * 0.5),
		"Backbord liegt bei Kurs Nord im Westen")

	# Der Schwenkbereich: enger Kegel um querab, sonst liegt kein Rohr an.
	_assert(Gunnery.bears(0.0, PI * 0.5, Gunnery.STARBOARD), "Ziel genau querab liegt an")
	_assert(not Gunnery.bears(0.0, 0.0, Gunnery.STARBOARD), "Ziel voraus liegt nicht an")
	_assert(not Gunnery.bears(0.0, PI, Gunnery.STARBOARD), "Ziel achteraus liegt nicht an")
	_assert(not Gunnery.bears(0.0, PI * 0.5, Gunnery.PORT),
		"Die falsche Seite liegt nie an")
	var inside := PI * 0.5 - deg_to_rad(Gunnery.TRAVERSE - 1.0)
	var outside := PI * 0.5 - deg_to_rad(Gunnery.TRAVERSE + 1.0)
	_assert(Gunnery.bears(0.0, inside, Gunnery.STARBOARD), "Knapp im Kegel liegt an")
	_assert(not Gunnery.bears(0.0, outside, Gunnery.STARBOARD),
		"Knapp ausserhalb liegt nicht mehr an")

	# Die Anzeige dazu: 1.0 querab, 0.0 am Anschlag.
	_assert(is_equal_approx(Gunnery.bearing_quality(0.0, PI * 0.5, Gunnery.STARBOARD), 1.0),
		"Genau querab bleibt der volle Spielraum")
	var half := Gunnery.bearing_quality(
		0.0, PI * 0.5 - deg_to_rad(Gunnery.TRAVERSE * 0.5), Gunnery.STARBOARD
	)
	_assert(is_equal_approx(half, 0.5), "Halber Schwenkbereich, halber Spielraum (%.2f)" % half)
	_assert(Gunnery.bearing_quality(0.0, 0.0, Gunnery.STARBOARD) == 0.0,
		"Ausserhalb bleibt kein Spielraum")

	_assert(Gunnery.better_side(0.0, PI * 0.5) == Gunnery.STARBOARD,
		"Ziel im Osten liegt steuerbord")
	_assert(Gunnery.better_side(0.0, -PI * 0.5) == Gunnery.PORT,
		"Ziel im Westen liegt backbord")

	# Richten: im Kegel auf das Ziel, ausserhalb bis zum Anschlag.
	var tracked := Gunnery.aim_direction(0.0, inside, Gunnery.STARBOARD)
	_assert(is_equal_approx(tracked, inside), "Im Kegel zeigen die Rohre auf das Ziel")
	var pinned := Gunnery.aim_direction(0.0, 0.0, Gunnery.STARBOARD)
	_assert(is_equal_approx(pinned, PI * 0.5 - deg_to_rad(Gunnery.TRAVERSE)),
		"Ausserhalb schwenken sie bis zum Anschlag und schiessen daneben")
	_assert(is_equal_approx(
		Gunnery.aim_direction(0.0, PI * 0.5, Gunnery.STARBOARD), PI * 0.5
	), "Ohne Korrektur geht die Salve genau querab")

	# Ein weiterer Schwenkbereich holt ein Ziel wieder herein, das eben noch
	# ausserhalb lag - genau daran dreht ShipClass.gun_traverse.
	_assert(Gunnery.bears(0.0, outside, Gunnery.STARBOARD, Gunnery.TRAVERSE * 2.0),
		"Ein weiterer Schwenkbereich bekommt mehr")

	# Flugzeit: sie steckt im Vorhalten, also muss sie mit der Entfernung wachsen.
	_assert(Gunnery.flight_time(Gunnery.MAX_RANGE) > Gunnery.flight_time(Gunnery.IDEAL_RANGE),
		"Weiter fliegen dauert laenger")
	_assert(Gunnery.flight_time(0.0) > 0.0, "Auch ein Nahschuss braucht Zeit")

	# Mannschaft: erst faehrt das Schiff, dann bedient sie die Rohre.
	_assert(is_equal_approx(Gunnery.readiness(40, 4, 6), 1.0),
		"Vierzig Mann bedienen sechs Rohre vollstaendig")
	_assert(is_equal_approx(Gunnery.readiness(16, 4, 6), 1.0),
		"Vier zum Fahren und zwoelf an den Rohren reichen genau")
	_assert(Gunnery.readiness(10, 4, 6) < 1.0, "Zehn Mann reichen dafuer nicht")
	_assert(is_equal_approx(Gunnery.readiness(4, 4, 6), Gunnery.MIN_READINESS),
		"Wer nur noch fahren kann, feuert im Schneckentempo")
	_assert(is_equal_approx(Gunnery.readiness(0, 4, 6), Gunnery.MIN_READINESS),
		"Und tiefer geht es nicht")
	_assert(Gunnery.readiness(30, 18, 10) < Gunnery.readiness(30, 4, 6),
		"Mehr Rohre und mehr Mindestbesatzung heissen schlechter bedient")

	_assert(Gunnery.reload_seconds(0.5) > Gunnery.reload_seconds(1.0),
		"Halbe Bedienung laedt langsamer")
	_assert(is_equal_approx(Gunnery.reload_seconds(1.0), Gunnery.RELOAD_SECONDS),
		"Volle Bedienung laedt in der Nennzeit")
	_assert(is_equal_approx(Gunnery.reload_seconds(0.1),
		Gunnery.reload_seconds(Gunnery.MIN_READINESS)), "Ladezeit hat eine Untergrenze")

	# Fehler wachsen mit der Entfernung und mit fehlenden Leuten.
	_assert(Gunnery.error_scale(300.0, 1.0) > Gunnery.error_scale(150.0, 1.0),
		"Auf doppelte Entfernung wird doppelt so ungenau gezielt")
	_assert(Gunnery.error_scale(150.0, 0.5) > Gunnery.error_scale(150.0, 1.0),
		"Eine halbe Bedienung zielt schlechter")

	# Trefferzonen: nah in den Rumpf, fern in die Takelage.
	var close := Gunnery.zone_weights(40.0)
	var far := Gunnery.zone_weights(Gunnery.MAX_RANGE)
	_assert(close[Gunnery.Zone.HULL] > close[Gunnery.Zone.SAILS],
		"Nahschuesse gehen in den Rumpf")
	_assert(far[Gunnery.Zone.SAILS] > far[Gunnery.Zone.HULL],
		"Fernschuesse gehen in die Takelage")
	for distance: float in [0.0, 60.0, 200.0, 419.0]:
		var weights := Gunnery.zone_weights(distance)
		var sum := weights[0] + weights[1] + weights[2]
		_assert(is_equal_approx(sum, 1.0), "Trefferzonen summieren sich auf 1 (%.0f m)" % distance)

	# Aufgeben: nur ein angeschlagenes Schiff, und Ruf hilft nach.
	_assert(not Gunnery.will_strike(1.0, 1.0, 1.0), "Ein unversehrtes Schiff ergibt sich nie")
	_assert(Gunnery.will_strike(0.2, 1.0, 0.0), "Ein zerschossener Rumpf gibt auf")
	_assert(Gunnery.will_strike(1.0, 0.2, 0.0), "Eine dezimierte Mannschaft gibt auf")
	var brink := Gunnery.STRIKE_HULL + Gunnery.FEAR_BONUS * 0.5
	_assert(Gunnery.will_strike(brink, 1.0, 1.0) and not Gunnery.will_strike(brink, 1.0, 0.0),
		"Beruechtigtheit laesst frueher aufgeben")


## Der Trefferentscheid: ein Punkt im gedrehten Rechteck des Ziels.
##
## Das ist die Stelle, an der aus der Umstellung ein Spielsystem wird - wer
## sich dem Feind zudreht, macht sich schmal.
func _check_hit_geometry() -> void:
	var here := Vector2.ZERO
	# Ein Rumpf auf Nordkurs: zehn Meter lang, gut drei breit.
	var length := 5.0
	var beam := 1.8

	_assert(Gunnery.hits_target(here, here, 0.0, length, beam), "Mittschiffs ist ein Treffer")
	_assert(Gunnery.hits_target(Vector2(0.0, -4.9), here, 0.0, length, beam),
		"Der Bug gehoert zum Ziel")
	_assert(not Gunnery.hits_target(Vector2(0.0, -5.1), here, 0.0, length, beam),
		"Knapp vor dem Bug ist keiner")
	_assert(Gunnery.hits_target(Vector2(1.7, 0.0), here, 0.0, length, beam),
		"Die Bordwand gehoert dazu")
	_assert(not Gunnery.hits_target(Vector2(1.9, 0.0), here, 0.0, length, beam),
		"Knapp daneben ist daneben")

	# Dasselbe Rechteck, um 90 Grad gedreht: Was eben ein Treffer war, ist jetzt
	# keiner mehr, und umgekehrt.
	_assert(Gunnery.hits_target(Vector2(4.0, 0.0), here, PI * 0.5, length, beam),
		"Quergedreht liegt die Laenge nach Osten")
	_assert(not Gunnery.hits_target(Vector2(0.0, -4.0), here, PI * 0.5, length, beam),
		"Und die Breite nach Norden")

	# Die Aussage in Zahlen: querab ist das Ziel gut dreimal so breit im
	# Anschlag wie mit dem Bug voran.
	var abeam_hits := 0
	var bow_hits := 0
	var samples := 200
	for i in samples:
		# Ein Punkt, der seitlich streut - so wie eine Salve streut.
		var offset := -12.0 + 24.0 * float(i) / float(samples - 1)
		# Schuetze im Westen: seine Streuung laeuft von Nord nach Sued.
		var point := Vector2(0.0, offset)
		if Gunnery.hits_target(point, here, 0.0, length, beam):
			abeam_hits += 1
		if Gunnery.hits_target(point, here, PI * 0.5, length, beam):
			bow_hits += 1
	_assert(abeam_hits > bow_hits * 2,
		"Ein Schiff quer zum Schuetzen ist ein weit groesseres Ziel (%d gegen %d)"
		% [abeam_hits, bow_hits])


## Breitseiten: geprueft wird die Verteilung ueber viele Salven, nicht eine.
##
## Gewuerfelt wird nur noch das Zielen; ob getroffen wird, entscheidet danach
## die Geometrie. Deshalb stehen hier Trefferzahlen und keine Wahrscheinlich-
## keiten.
func _check_salvo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831

	# Ein Gegner, der auf Nordkurs querab steht, 150 Meter im Osten.
	var target := TargetProfile.make(Vector2(Gunnery.IDEAL_RANGE, 0.0), Vector2.ZERO, 0.0, 5.0, 1.8)
	var rounds := 300
	var guns := 5

	var abeam_hits := 0
	var askew_hits := 0
	for i in rounds:
		abeam_hits += Gunnery.hits_in(Gunnery.resolve_salvo(
			rng, guns, Vector2.ZERO, 0.0, Gunnery.STARBOARD, target, 1.0
		))
		# Derselbe Gegner, aber das eigene Schiff steht schraeg: Die Rohre
		# haengen am Anschlag und die Salve geht vorbei.
		askew_hits += Gunnery.hits_in(Gunnery.resolve_salvo(
			rng, guns, Vector2.ZERO, deg_to_rad(50.0), Gunnery.STARBOARD, target, 1.0
		))
	_assert(abeam_hits > askew_hits * 5,
		"Wer richtig liegt, trifft ungleich mehr (%d gegen %d von je %d Kugeln)"
		% [abeam_hits, askew_hits, rounds * guns])
	_assert(abeam_hits > rounds * guns / 2,
		"Eine richtig gelegte Breitseite trifft mehrheitlich (%d von %d)"
		% [abeam_hits, rounds * guns])

	# Naeher heran heisst genauer - der Kern der ganzen Umstellung.
	var near := TargetProfile.make(Vector2(60.0, 0.0), Vector2.ZERO, 0.0, 5.0, 1.8)
	var distant := TargetProfile.make(Vector2(380.0, 0.0), Vector2.ZERO, 0.0, 5.0, 1.8)
	var near_hits := 0
	var distant_hits := 0
	for i in rounds:
		near_hits += Gunnery.hits_in(Gunnery.resolve_salvo(
			rng, guns, Vector2.ZERO, 0.0, Gunnery.STARBOARD, near, 1.0
		))
		distant_hits += Gunnery.hits_in(Gunnery.resolve_salvo(
			rng, guns, Vector2.ZERO, 0.0, Gunnery.STARBOARD, distant, 1.0
		))
	_assert(near_hits > distant_hits * 2,
		"Aus der Naehe trifft es weit oefter (%d gegen %d von je %d Kugeln)"
		% [near_hits, distant_hits, rounds * guns])

	# Und eine dezimierte Mannschaft trifft schlechter, ohne dass es dafuer
	# eine zweite Zahl braeuchte.
	var thin_hits := 0
	for i in rounds:
		thin_hits += Gunnery.hits_in(Gunnery.resolve_salvo(
			rng, guns, Vector2.ZERO, 0.0, Gunnery.STARBOARD, target, Gunnery.MIN_READINESS
		))
	_assert(thin_hits < abeam_hits,
		"Halbe Bedienung trifft schlechter (%d gegen %d)" % [thin_hits, abeam_hits])

	# Ein Ziel, das faehrt, muss vorgehalten werden. Ohne Vorhalten schiesst man
	# ihm hinterher - geprueft, indem die Fahrt quer zur Schussrichtung liegt.
	var running := TargetProfile.make(
		Vector2(Gunnery.IDEAL_RANGE, 0.0), SailingMath.direction(0.0) * 6.0, 0.0, 5.0, 1.8
	)
	var lead := Gunnery.predicted_position(running, Gunnery.IDEAL_RANGE)
	_assert(lead.distance_to(running.position) > 1.0,
		"Auf ein fahrendes Ziel wird vorgehalten (%.1f m)" % lead.distance_to(running.position))
	_assert(is_equal_approx(
		Gunnery.predicted_position(target, Gunnery.IDEAL_RANGE).x, target.position.x
	), "Auf ein stehendes Ziel wird nicht vorgehalten")
	var running_hits := 0
	for i in rounds:
		running_hits += Gunnery.hits_in(Gunnery.resolve_salvo(
			rng, guns, Vector2.ZERO, 0.0, Gunnery.STARBOARD, running, 1.0
		))
	_assert(running_hits > rounds * guns / 4,
		"Ein fahrendes Ziel wird trotzdem getroffen (%d von %d)"
		% [running_hits, rounds * guns])

	# Trefferzonen am fertigen Schuss: nah bricht der Rumpf, fern faellt die
	# Takelage.
	var close_hull := 0
	var close_sails := 0
	var far_hull := 0
	var far_sails := 0
	for i in rounds:
		var near_salvo := Gunnery.resolve_salvo(
			rng, guns, Vector2.ZERO, 0.0, Gunnery.STARBOARD, near, 1.0
		)
		close_hull += Gunnery.damage_in(near_salvo, Gunnery.Zone.HULL)
		close_sails += Gunnery.damage_in(near_salvo, Gunnery.Zone.SAILS)
		var far_salvo := Gunnery.resolve_salvo(
			rng, guns, Vector2.ZERO, 0.0, Gunnery.STARBOARD, distant, 1.0
		)
		far_hull += Gunnery.damage_in(far_salvo, Gunnery.Zone.HULL)
		far_sails += Gunnery.damage_in(far_salvo, Gunnery.Zone.SAILS)
	_assert(close_hull > close_sails,
		"Aus der Naehe bricht der Rumpf (%d gegen %d Schaden)" % [close_hull, close_sails])
	_assert(far_sails > far_hull,
		"Von weit her faellt die Takelage (%d gegen %d Schaden)" % [far_sails, far_hull])

	# Ausser Reichweite fliegt die Salve trotzdem - sonst fehlten die Fontaenen.
	var beyond := TargetProfile.make(Vector2(800.0, 0.0), Vector2.ZERO, 0.0, 5.0, 1.8)
	var empty := Gunnery.resolve_salvo(
		rng, 4, Vector2.ZERO, 0.0, Gunnery.STARBOARD, beyond, 1.0
	)
	_assert(Gunnery.hits_in(empty) == 0, "Ausser Reichweite trifft keine Kugel")
	_assert(empty.size() == 4, "Auch ein Fehlschuss ist ein Schuss - fuer die Fontaene")

	# Jede Kugel hat ihre eigene Muendung und ihren eigenen Aufschlagpunkt. Ohne
	# das saehe eine Breitseite aus wie ein einziger grosser Schuss.
	var spread_salvo := Gunnery.resolve_salvo(
		rng, guns, Vector2.ZERO, 0.0, Gunnery.STARBOARD, target, 1.0
	)
	var muzzles := spread_salvo[0].origin.distance_to(spread_salvo[guns - 1].origin)
	_assert(muzzles > Gunnery.GUN_SPACING * float(guns - 2),
		"Die Rohre stehen ueber die Bordwand verteilt (%.1f m)" % muzzles)
	_assert(is_equal_approx(
		Gunnery.gun_offset(0, guns), -Gunnery.gun_offset(guns - 1, guns)
	), "Die Batterie sitzt mittig um den Rumpfmittelpunkt")
	for shot: Shot in spread_salvo:
		_assert(shot.impact.distance_to(shot.origin) > 1.0,
			"Jede Kugel fliegt wirklich los")

	# Und ein Fehlschuss geht dorthin, wo man ihn sieht: neben das Ziel, nicht
	# in eine beliebige Richtung.
	var wide := Gunnery.resolve_salvo(
		rng, guns, Vector2.ZERO, deg_to_rad(60.0), Gunnery.STARBOARD, target, 1.0
	)
	for shot: Shot in wide:
		_assert(not shot.hit, "Am Anschlag trifft nichts")
		var reach := shot.impact.distance_to(shot.origin)
		_assert(absf(reach - Gunnery.IDEAL_RANGE) < Gunnery.IDEAL_RANGE * 0.35,
			"Aber die Salve liegt auf der richtigen Entfernung (%.0f m)" % reach)


func _check_ship_ai() -> void:
	# Ein Segler faehrt nicht in den Sperrsektor, auch wenn er gerne wuerde.
	var wind := 0.0
	var forced := SailingMath.sailable_heading(0.0, wind)
	_assert(absf(angle_difference(forced, wind)) > deg_to_rad(SailingMath.CLOSE_HAULED_LIMIT),
		"Kurs in den Wind wird auf den Anlieger gelegt")
	_assert(SailingMath.sail_efficiency(forced, wind) > 0.5,
		"Und der Anlieger zieht auch wirklich")
	var free_course := deg_to_rad(120.0)
	_assert(is_equal_approx(SailingMath.sailable_heading(free_course, wind), free_course),
		"Ein fahrbarer Kurs bleibt unveraendert")

	# Grundhaltung: Handelsschiffe fliehen immer, Kriegsschiffe erst angeschlagen.
	_assert(ShipAI.stance(false, 1.0, 300.0) == ShipAI.Stance.FLEE,
		"Ein Handelsschiff flieht auch unversehrt")
	_assert(ShipAI.stance(true, 1.0, 300.0) == ShipAI.Stance.ENGAGE,
		"Ein Kriegsschiff sucht das Gefecht")
	_assert(ShipAI.stance(true, 1.0, 900.0) == ShipAI.Stance.APPROACH,
		"Ausser Schussweite wird erst geschlossen")
	_assert(ShipAI.stance(true, 0.2, 300.0) == ShipAI.Stance.FLEE,
		"Ein angeschlagenes Kriegsschiff bricht ab")

	# Die Bahn ins Gefecht: Der Vorhalt auf die Peilung waechst mit der Naehe,
	# aus der Spirale wird ein Kreis um den Gegner. Gegner im Osten, wir im
	# Ursprung - wir wollen ihn steuerbord haben.
	var far_off := ShipAI.engage_course(Vector2.ZERO, Vector2(900.0, 0.0), Gunnery.STARBOARD)
	_assert(absf(angle_difference(far_off, PI * 0.5)) < deg_to_rad(1.0),
		"Weit draussen wird geradewegs auf den Gegner zugehalten")

	var at_beam := ShipAI.engage_course(
		Vector2.ZERO, Vector2(ShipAI.BEAM_RANGE, 0.0), Gunnery.STARBOARD
	)
	_assert(Gunnery.bears(at_beam, PI * 0.5, Gunnery.STARBOARD),
		"Auf Gefechtsabstand liegt der Gegner querab und die Breitseite an")

	var half_way := ShipAI.engage_course(
		Vector2.ZERO,
		Vector2((ShipAI.APPROACH_RANGE + ShipAI.BEAM_RANGE) * 0.5, 0.0),
		Gunnery.STARBOARD
	)
	var lead_far := absf(angle_difference(far_off, PI * 0.5))
	var lead_half := absf(angle_difference(half_way, PI * 0.5))
	var lead_beam := absf(angle_difference(at_beam, PI * 0.5))
	_assert(lead_far < lead_half and lead_half < lead_beam,
		"Je naeher, desto mehr wird eingedreht (%.0f, %.0f, %.0f Grad)"
		% [rad_to_deg(lead_far), rad_to_deg(lead_half), rad_to_deg(lead_beam)])

	# Zu dicht dran wird abgedreht, statt zu rammen.
	var sheer := ShipAI.desired_heading(
		ShipAI.Stance.ENGAGE, Vector2.ZERO, Vector2(30.0, 0.0), Gunnery.STARBOARD, PI
	)
	_assert(absf(angle_difference(sheer, PI * 0.5)) > PI * 0.5,
		"Zu nah wird abgedreht statt gerammt")

	# Die Seite entscheidet, herum wo eingedreht wird - auf der anderen Seite
	# spiegelt sich die ganze Bahn.
	var mirrored := ShipAI.engage_course(
		Vector2.ZERO, Vector2(ShipAI.BEAM_RANGE, 0.0), Gunnery.PORT
	)
	_assert(Gunnery.bears(mirrored, PI * 0.5, Gunnery.PORT),
		"Backbord wird andersherum eingedreht")

	# Wind aus Nord, Gegner im Norden: Die Flucht nach Sueden laeuft raumschots
	# und wird deshalb nicht auf einen Anlieger gelegt.
	var away := ShipAI.desired_heading(
		ShipAI.Stance.FLEE, Vector2.ZERO, Vector2(0.0, -200.0), Gunnery.PORT, 0.0
	)
	_assert(absf(angle_difference(away, PI)) < deg_to_rad(1.0),
		"Wer flieht, dreht dem Gegner den Ruecken zu")
	# Steht der Gegner in Lee, geht das nicht: Dann bleibt nur der Anlieger.
	var upwind := ShipAI.desired_heading(
		ShipAI.Stance.FLEE, Vector2.ZERO, Vector2(0.0, 200.0), Gunnery.PORT, 0.0
	)
	_assert(absf(angle_difference(upwind, 0.0)) > deg_to_rad(SailingMath.CLOSE_HAULED_LIMIT),
		"Flucht gegen den Wind laeuft ueber den Anlieger")

	_assert(ShipAI.sail_setting(ShipAI.Stance.ENGAGE, 30.0) < 3,
		"Dicht am Gegner wird Fahrt weggenommen")
	_assert(ShipAI.sail_setting(ShipAI.Stance.ENGAGE, 200.0) == 3,
		"Im Gefecht selbst steht alles - wer refft, wird abgehaengt")
	_assert(ShipAI.sail_setting(ShipAI.Stance.FLEE, 400.0) == 3,
		"Auf der Flucht ebenso")

	# Gefeuert wird genau dann, wenn die Rohre den Gegner bekommen - seit sie
	# wirklich dorthin zeigen, gibt es dazwischen nichts mehr abzuwaegen.
	_assert(not ShipAI.should_fire(0.0, 0.0, Gunnery.STARBOARD, 100.0, Gunnery.TRAVERSE),
		"Auf ein Ziel voraus wird nicht gefeuert")
	_assert(ShipAI.should_fire(0.0, PI * 0.5, Gunnery.STARBOARD, 100.0, Gunnery.TRAVERSE),
		"Liegt das Ziel an und ist es in Reichweite, faellt die Breitseite")
	# Und nicht auf jede Entfernung, auf die die Kugel noch traegt: Eine Salve
	# ins Leere kostet neun Sekunden Nachladen.
	_assert(not ShipAI.should_fire(
		0.0, PI * 0.5, Gunnery.STARBOARD, ShipAI.FIRE_RANGE + 10.0, Gunnery.TRAVERSE
	), "Auf zu grosse Entfernung wird das Pulver gespart")
	_assert(ShipAI.FIRE_RANGE < Gunnery.MAX_RANGE,
		"Und diese Grenze liegt innerhalb der Schussweite")


## Das Schiff als Node: Zaehigkeit, Batterien, Schaden.
func _check_ship_combat() -> void:
	var ship := _make_ship("res://resources/ships/patrol_sloop.tres")

	_assert(ship.max_hull == 115, "Zaehigkeit kommt aus der .tres-Datei")
	_assert(ship.cannons_per_side == 5, "Zehn Rohre sind fuenf je Seite")
	_assert(ship.warship, "Die Patrouille ist ein Kriegsschiff")
	_assert(is_equal_approx(ship.sail_health(), 1.0), "Frische Segel ziehen voll")

	_assert(ship.battery_ready(Gunnery.PORT), "Ein frisches Schiff ist geladen")
	_assert(ship.fire(Gunnery.PORT), "Die Breitseite faellt")
	_assert(not ship.battery_ready(Gunnery.PORT), "Danach muss nachgeladen werden")
	_assert(ship.battery_ready(Gunnery.STARBOARD), "Die andere Seite bleibt geladen")
	_assert(not ship.fire(Gunnery.PORT), "Eine leere Batterie feuert nicht")
	_assert(ship.battery_progress(Gunnery.PORT) < 0.1, "Der Ladebalken faengt bei null an")

	# Zerschossene Segel kosten Fahrt - der Grund, warum Fernbeschuss lohnt.
	var full := SailingMath.target_speed(ship.base_speed, PI, 0.0, 1.0, 1.0, ship.sail_health())
	ship.take_hit(Gunnery.Zone.SAILS, 60)
	var shredded := SailingMath.target_speed(ship.base_speed, PI, 0.0, 1.0, 1.0, ship.sail_health())
	_assert(shredded < full * 0.6, "Zerschossene Takelage kostet Fahrt (%.1f statt %.1f kn)"
		% [shredded, full])

	_assert(is_equal_approx(ship.readiness(), 1.0),
		"Voll besetzt sind alle Rohre bedient")
	_assert(is_equal_approx(ship.handling(), 1.0), "Und das Schiff faehrt voll")

	ship.take_hit(Gunnery.Zone.CREW, 40)
	_assert(ship.crew < ship.max_crew, "Kartaetschen kosten Leute")
	_assert(ship.readiness() < 1.0, "Und damit die Bedienung der Rohre")
	_assert(Gunnery.reload_seconds(ship.readiness()) > Gunnery.RELOAD_SECONDS,
		"Und damit Ladezeit")
	# Sechs von achtzehn Mann: Das Schiff kriecht noch, faehrt aber nicht mehr.
	_assert(ship.handling() < 1.0, "Unter der Mindestbesatzung leidet auch die Fahrt")
	_assert(ship.handling() >= Ship.MIN_HANDLING, "Ganz stehen bleibt es aber nicht")

	ship.strike()
	_assert(ship.struck, "Ein Schiff kann die Flagge streichen")
	_assert(not ship.battery_ready(Gunnery.STARBOARD), "Wer gestrichen hat, feuert nicht mehr")

	var doomed := _make_ship("res://resources/ships/merchant_brig.tres")
	var went_down := [false]
	doomed.sunk.connect(func() -> void: went_down[0] = true)
	doomed.take_hit(Gunnery.Zone.HULL, 999)
	_assert(went_down[0], "Ein durchschossener Rumpf sinkt")
	_assert(doomed.finished, "Ein gesunkenes Schiff ist erledigt")
	doomed.take_hit(Gunnery.Zone.HULL, 10)
	_assert(doomed.hull == 0, "Auf ein Wrack wird nicht weitergeschossen")

	ship.queue_free()
	doomed.queue_free()


## Ein Schiff einer Klasse, fertig ausgeruestet. Der Aufrufer haengt es selbst
## in den Baum - apply_class() braucht den Baum fuer die Segelanimation.
func _make_ship(class_path: String) -> Ship:
	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var ship: Ship = packed.instantiate()
	ship.player_controlled = false
	add_child(ship)
	ship.apply_class(load(class_path))
	return ship



## Die Werft ersetzt auch Leute - seit M4 kostet ein Gefecht Mannschaft.
func _check_hiring() -> void:
	GameState.new_campaign("Werber", 31415)
	var town: TownData = WorldData.towns[0]

	_assert(Shipyard.crew_missing() == GameState.max_crew() - GameState.crew,
		"Es fehlt, was zur vollen Besatzung fehlt")
	GameState.crew = GameState.max_crew()
	_assert(Shipyard.full_hire_cost(town) == 0, "Volle Mannschaft kostet nichts")
	_assert(Shipyard.hire(town) == 0, "Und laesst sich nicht aufstocken")

	GameState.crew = GameState.max_crew() - 10
	GameState.gold = 100000
	var before := GameState.gold
	var hired := Shipyard.hire(town)
	_assert(hired == 10, "Mit Gold kommt die ganze Mannschaft (%d Mann)" % hired)
	_assert(GameState.crew == GameState.max_crew(), "Und das Schiff ist wieder voll besetzt")
	_assert(GameState.gold < before, "Handgeld kostet Gold (%d)" % (before - GameState.gold))

	# Teilanheuerung: Wer knapp bei Kasse ist, bekommt, was er bezahlen kann.
	GameState.crew = GameState.max_crew() - 10
	GameState.gold = Shipyard.hire_cost(town, 3)
	var partial := Shipyard.hire(town)
	_assert(partial == 3, "Knappes Gold heuert anteilig an (%d Mann)" % partial)
	_assert(GameState.gold == 0, "Und ist danach ausgegeben")

	GameState.gold = 0
	_assert(Shipyard.hire(town) == 0, "Ohne Gold kommt niemand")

	# Eine grosse Stadt ist billiger als ein Dorf - dieselbe Regel wie beim Rumpf.
	var village := _town_of_tier(0)
	var capital := _town_of_tier(2)
	if village != null and capital != null:
		_assert(Shipyard.hire_cost(capital, 10) < Shipyard.hire_cost(village, 10),
			"In der Hauptstadt heuert man billiger an als im Dorf")

	_assert(GameState.max_crew() > 0, "Die Mannschaftsgroesse kommt aus der Schiffsklasse")
	GameState.crew = GameState.max_crew() + 50
	_assert(GameState.crew == GameState.max_crew(),
		"Mehr Leute als Kojen gibt es nicht")


func _town_of_tier(tier: int) -> TownData:
	for town: TownData in WorldData.towns:
		if town.size_tier == tier:
			return town
	return null

## Was ein besiegter Gegner hergibt - und was ein verlorenes Gefecht kostet.
func _check_prize() -> void:
	GameState.new_campaign("Freibeuter", 777)
	GameState.gold = 100
	GameState.cargo.clear()

	var combat := NavalCombat.new()
	# Keine zufaelligen Segel dazwischen: Ein drittes Schiff waehrend des Duells
	# verschiebt die Zahlen und macht zwei Laeufe unvergleichbar.
	combat.max_ships = 0
	add_child(combat)

	var mine := _make_ship("res://resources/ships/sloop.tres")
	mine.global_position = Vector3.ZERO
	combat.setup(mine)

	var prize := _make_ship("res://resources/ships/merchant_brig.tres")
	prize.ship_name = "Testprise"
	prize.nation_id = 0
	prize.gold = 450
	prize.cargo = {&"sugar": 30, &"rum": 25}
	prize.global_position = Vector3(600.0, 0.0, 0.0)
	combat.adopt(prize)

	_assert(combat.prize_in_reach() == null, "Ein fahrendes Schiff ist keine Prise")
	prize.strike()
	_assert(combat.prize_in_reach() == null, "Ein gestrichenes auf 600 Metern auch nicht")
	prize.global_position = Vector3(60.0, 0.0, 0.0)
	_assert(combat.prize_in_reach() == prize, "Laengsseit schon")

	var capacity := GameState.cargo_capacity()
	var notoriety_before := GameState.notoriety
	combat.take_prize(prize)

	_assert(GameState.gold == 550, "Das Gold der Prise geht an Bord")
	_assert(GameState.cargo_used() == capacity,
		"Der Laderaum wird voll (%d von %d)" % [GameState.cargo_used(), capacity])
	_assert(GameState.cargo_of(&"rum") < 25,
		"Was nicht hineinpasst, bleibt zurueck - ein voller Laderaum kostet Beute")
	_assert(GameState.notoriety > notoriety_before, "Eine Prise macht beruechtigt")
	_assert(GameState.reputation[0] < 0, "Und kostet Ansehen bei der bestohlenen Nation")
	_assert(combat.prize_in_reach() == null, "Eine ausgeraeumte Prise ist keine mehr")

	# Ein verlorenes Gefecht beendet keinen Lauf - es verteuert ihn.
	GameState.gold = 900
	GameState.cargo.clear()
	GameState.add_cargo(&"tools", 10)
	mine.take_hit(Gunnery.Zone.HULL, 9999)

	_assert(GameState.gold < 900, "Wer verliert, wird ausgeraubt (%d Gold uebrig)"
		% GameState.gold)
	_assert(GameState.cargo_of(&"tools") == 5, "Die halbe Ladung geht ueber Bord")
	_assert(mine.hull > 0, "Das eigene Schiff bleibt ueber Wasser")
	_assert(not mine.finished, "Der Lauf geht weiter")

	combat.queue_free()
	mine.queue_free()


# --- Die Stellschrauben des Debug-Menues -----------------------------------
#
# Geprueft wird nicht die Oberflaeche, sondern das, woran sie dreht. Ein Regler,
# der nichts bewegt, sieht kaputt aus - und genau das ist beim Wind der Fall,
# wenn er nicht festgehalten wird.

func _check_debug_knobs() -> void:
	GameState.new_campaign("Regler", 2024)

	# Der Wind laesst sich festhalten.
	WorldData.set_wind(deg_to_rad(90.0), 1.0)
	WorldData.wind_locked = true
	# Zwei Minuten Spielzeit auf einen Schlag: Von Hand aufgerufen, damit die
	# Pruefung nicht zwei Minuten dauert.
	WorldData._process(120.0)
	_assert(is_equal_approx(WorldData.wind_direction, deg_to_rad(90.0)),
		"Festgehaltener Wind dreht nicht weg")

	WorldData.wind_locked = false
	WorldData._process(120.0)
	_assert(not is_equal_approx(WorldData.wind_direction, deg_to_rad(90.0)),
		"Losgelassener Wind dreht wieder")

	await _check_speed_multiplier()
	await _check_spawn_knobs()
	_check_water_grid()


## Der Fahrtfaktor geht wirklich in die Fahrt ein - und laesst die Werte der
## Schiffsklasse dabei unberuehrt.
func _check_speed_multiplier() -> void:
	WorldData.set_wind(0.0, 1.0)
	WorldData.wind_locked = true

	var plain := await _run_ship(1.0)
	var fast := await _run_ship(3.0)
	_assert(fast > plain * 2.0,
		"Der Fahrtfaktor beschleunigt das Schiff (%.1f statt %.1f kn)" % [fast, plain])

	WorldData.wind_locked = false


## Faehrt ein Schiff kurz mit einem Faktor und gibt die erreichte Fahrt zurueck.
func _run_ship(multiplier: float) -> float:
	var ship := _make_ship("res://resources/ships/sloop.tres")
	# Wind aus Nord, Kurs Sued: vor dem Wind, volle Segel.
	ship.global_position = Vector3(0.0, 0.0, 0.0)
	ship.set_heading(PI)
	ship.sail_command = 3
	ship.speed_multiplier = multiplier

	var previous := Engine.time_scale
	Engine.time_scale = 10.0
	for step in 90:
		await get_tree().physics_frame
	Engine.time_scale = previous

	var reached := ship.speed
	_assert(is_equal_approx(ship.ship_class.base_speed, 12.0),
		"Die Schiffsklasse bleibt unberuehrt (%.1f kn Grundfahrt)" % ship.ship_class.base_speed)
	ship.queue_free()
	return reached


## Hoechstzahl und Sofort-Segel.
func _check_spawn_knobs() -> void:
	var combat := NavalCombat.new()
	# Keine zufaelligen Segel dazwischen: Ein drittes Schiff waehrend des Duells
	# verschiebt die Zahlen und macht zwei Laeufe unvergleichbar.
	combat.max_ships = 0
	add_child(combat)

	var mine := _make_ship("res://resources/ships/sloop.tres")
	var spot := _open_sea()
	mine.global_position = Vector3(spot.x, 0.0, spot.y)
	combat.setup(mine)

	combat.max_ships = 0
	combat.spawn_interval = 5.0
	combat._update_spawning(999.0)
	_assert(combat.ships().is_empty(), "Hoechstzahl null laesst die See leer")

	# Der Knopf im Menue setzt trotzdem ein Segel - er soll gerade dann helfen,
	# wenn man sonst warten muesste.
	_assert(combat.spawn_now(), "Der Knopf setzt sofort ein Segel")
	_assert(combat.ships().size() == 1, "Und genau eines")

	combat.max_ships = 3
	combat._update_spawning(999.0)
	_assert(combat.ships().size() > 1, "Mit hoeherer Hoechstzahl kommt mehr")

	combat.queue_free()
	mine.queue_free()
	await get_tree().process_frame


## Das Gitternetz auf dem Wasser - der buchstaebliche Teil des Schachbretts.
func _check_water_grid() -> void:
	var packed: PackedScene = load("res://world/ocean/ocean.tscn")
	var sea: Ocean = packed.instantiate()
	add_child(sea)

	var material := sea.material_override as ShaderMaterial
	_assert(material != null, "Der Ozean hat ein Shadermaterial")
	if material == null:
		return

	_assert(sea.show_grid, "Das Gitternetz ist vorerst an")
	sea.show_grid = false
	_assert(float(material.get_shader_parameter("grid_strength")) == 0.0,
		"Und laesst sich abschalten")
	sea.show_grid = true
	_assert(is_equal_approx(
		float(material.get_shader_parameter("grid_strength")), Ocean.GRID_STRENGTH
	), "Und wieder an")

	sea.queue_free()


# --- Das Abnahmekriterium von M4 -------------------------------------------
#
# "Ein Gefecht gegen ein KI-Schiff ist spannend und Manoevrieren wird belohnt."
# Spannend kann kein Test beurteilen - das entscheidet sich beim Spielen. Der
# zweite Teil laesst sich fahren, und genau das passiert hier (Regel C6):
# zweimal dieselbe Ausgangslage, derselbe Wuerfel, zwei Kapitaene am eigenen
# Ruder. Einer haelt den Gegner querab, der andere faehrt drauflos und feuert,
# sobald geladen ist. Der Unterschied ist das, was ein Spieler lernen soll.

## Sekunden Spielzeit, die ein Gefecht hoechstens dauern darf. Ein Gefecht
## laeuft rund zwei Minuten - kurz genug fuer eine Sitzung, lang genug, dass
## das Ruder darueber entscheidet.
const DUEL_SECONDS: float = 165.0
const DUEL_SEED: int = 4711
## Im Zeitraffer, sonst dauert der Rauchtest so lang wie zwei echte Gefechte.
## Der Physikschritt wird dabei mitgehoben, damit das Ruder nicht in Spruengen
## arbeitet - 15-fache Zeit bei 120 Schritten sind 125 ms je Schritt.
const DUEL_TIME_SCALE: float = 15.0
const DUEL_PHYSICS_HZ: int = 120


func _check_duel() -> void:
	var artful := await _fight(true)
	var reckless := await _fight(false)

	_assert(artful["struck"], "Ein manoevrierter Gegner streicht die Flagge (nach %.0f s)"
		% artful["seconds"])
	_assert(artful["damage"] > 0, "Die eigenen Breitseiten kommen an")
	_assert(artful["taken"] > 0, "Und der Gegner schiesst zurueck")
	_assert(artful["damage"] > reckless["damage"],
		"Manoevrieren richtet mehr aus als Drauflosfahren (%d gegen %d Schaden)"
		% [artful["damage"], reckless["damage"]])
	_assert(not reckless["struck"],
		"Wer nur hinterherfaehrt, zwingt niemanden zur Flagge")


## Traegt ein Gefecht aus und gibt zurueck, was dabei herauskam.
func _fight(maneuvering: bool) -> Dictionary:
	GameState.new_campaign("Duellant", DUEL_SEED)
	# Wind querab und fest. Fest, weil ein drehender Wind in beiden Laeufen zwar
	# derselbe waere, die Zahlen aber nicht mehr erklaerbar. Und querab statt aus
	# Nord, weil beide Schiffe auf Nordkurs starten: Aus Nord laegen sie in Irons
	# und das "Gefecht" waere ein Gefecht zweier Schiffe, die sich kaum bewegen.
	WorldData.set_wind(deg_to_rad(90.0), 1.0)
	var spot := _open_sea()

	var combat := NavalCombat.new()
	# Keine zufaelligen Segel dazwischen: Ein drittes Schiff waehrend des Duells
	# verschiebt die Zahlen und macht zwei Laeufe unvergleichbar.
	combat.max_ships = 0
	add_child(combat)

	var mine := _make_ship("res://resources/ships/patrol_sloop.tres")
	mine.global_position = Vector3(spot.x, 0.0, spot.y)
	mine.set_heading(0.0)
	combat.setup(mine)
	# Erst jetzt: setup() wuerfelt den Wuerfel neu.
	combat.rng.seed = DUEL_SEED

	# Ein Kriegsschiff, kein Handelsschiff: Eine Handelsbrigg flieht, und eine
	# Verfolgung ueber mehrere Minuten sagt nichts darueber aus, ob Manoevrieren
	# etwas bringt - sie sagt nur, wer schneller ist. Gegen einen Gegner, der
	# selbst das Gefecht sucht, entscheidet die Lage.
	var theirs := _make_ship("res://resources/ships/patrol_sloop.tres")
	theirs.ship_name = "Testgegner"
	# Laengsseits steuerbord auf wirksamem Abstand, gleicher Kurs - die Lage,
	# in der ein Gefecht tatsaechlich beginnt. Das Aufschliessen davor ist eine
	# Frage der Geschwindigkeit, nicht des Gefechts.
	theirs.global_position = Vector3(spot.x + Gunnery.IDEAL_RANGE, 0.0, spot.y)
	theirs.set_heading(0.0)
	combat.adopt(theirs)

	var captain: ShipAI = null
	if maneuvering:
		captain = ShipAI.new()
		captain.setup(mine)
		captain.provoked = true
		mine.add_child(captain)

	var previous_scale := Engine.time_scale
	var previous_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = DUEL_PHYSICS_HZ
	Engine.time_scale = DUEL_TIME_SCALE
	var step := DUEL_TIME_SCALE / float(DUEL_PHYSICS_HZ)

	var elapsed := 0.0
	while elapsed < DUEL_SECONDS and not theirs.struck and not theirs.finished:
		if captain != null:
			captain.target = theirs
		else:
			_charge(mine, theirs)
		await get_tree().physics_frame
		elapsed += step

	Engine.time_scale = previous_scale
	Engine.physics_ticks_per_second = previous_hz

	var result := {
		"struck": theirs.struck,
		"seconds": elapsed,
		"damage": (theirs.max_hull - theirs.hull) + (theirs.max_sails - theirs.sails),
		"taken": (mine.max_hull - mine.hull) + (mine.max_sails - mine.sails),
	}

	combat.queue_free()
	mine.queue_free()
	theirs.queue_free()
	await get_tree().process_frame
	return result


## Der Kapitaen, der es noch nicht besser weiss: direkt auf den Gegner zu und
## feuern, sobald geladen ist. Genau so faehrt man das erste Gefecht.
func _charge(mine: Ship, theirs: Ship) -> void:
	var bearing := SailingMath.bearing(mine.plan_position(), theirs.plan_position())
	mine.helm_command = clampf(
		angle_difference(mine.heading(), bearing) * ShipAI.HELM_GAIN, -1.0, 1.0
	)
	mine.sail_command = 3
	mine.fire(Gunnery.PORT)
	mine.fire(Gunnery.STARBOARD)


## Ein Fleck offene See, weit genug von jeder Kueste fuer ein Gefecht.
func _open_sea() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = DUEL_SEED
	var half := WorldData.WORLD_SIZE * 0.45
	for attempt in 500:
		var spot := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if _water_around(spot, 1200.0):
			return spot
	return Vector2.ZERO


func _water_around(center: Vector2, radius: float) -> bool:
	for i in 12:
		var angle := TAU * float(i) / 12.0
		for factor: float in [0.5, 1.0]:
			var probe := center + Vector2(sin(angle), cos(angle)) * radius * factor
			if not WorldData.is_navigable(probe.x, probe.y):
				return false
	return WorldData.is_navigable(center.x, center.y)


func _check_everything_loads() -> void:
	var broken_scripts: Array[String] = []
	for path: String in _gd_files():
		var script: GDScript = load(path)
		# load() liefert auch bei einem Parse-Fehler ein Objekt zurueck - es
		# ist nur nicht kompiliert. can_instantiate() unterscheidet das.
		if script == null or not script.can_instantiate():
			broken_scripts.append(path)
	_assert(broken_scripts.is_empty(),
		"Alle Skripte kompilieren%s" % _offenders(broken_scripts))

	var broken_scenes: Array[String] = []
	var scene_count := 0
	for path: String in _scene_files():
		scene_count += 1
		if load(path) == null:
			broken_scenes.append(path)
	_assert(broken_scenes.is_empty(),
		"Alle Szenen laden (%d)%s" % [scene_count, _offenders(broken_scenes)])

	# Eine Szene laedt auch dann, wenn ihr Skript fehlt - dann sind Nodes
	# stumm. Deshalb wird gegengeprueft, dass die Skripte wirklich dranhaengen.
	var scripted := {
		"res://ui/hud/sailing_hud.tscn": ["Compass"],
		"res://entities/ship/ship.tscn": [],
		"res://ui/map/world_map.tscn": [],
		"res://modes/port/port_mode.tscn": [],
		"res://modes/sailing/sailing_mode.tscn": ["Terrain", "Towns"],
	}
	var missing: Array[String] = []
	for scene_path: String in scripted:
		var packed: PackedScene = load(scene_path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		if root.get_script() == null:
			missing.append(scene_path)
		for child_name: String in scripted[scene_path]:
			var child: Node = root.find_child(child_name, true, false)
			if child == null or child.get_script() == null:
				missing.append("%s/%s" % [scene_path, child_name])
		root.queue_free()
	_assert(missing.is_empty(), "Szenen behalten ihre Skripte%s" % _offenders(missing))


func _scene_files() -> PackedStringArray:
	var found := PackedStringArray()
	for directory: String in CODE_DIRS:
		_collect_by_suffix("res://" + directory, ".tscn", found)
	return found


## Setzt die Projektregeln durch, die durch Fehler gelernt wurden.
##
## Beide Regeln unten stehen hier, weil ihre Verletzung im Spiel nicht auffaellt:
## Eine falsche Farbe sieht nur etwas anders aus, ein direkt gelesenes
## rotation.y liefert einen plausiblen, aber gespiegelten Winkel. Siehe
## docs/RICHTLINIEN.md.
const CODE_DIRS: PackedStringArray = ["autoload", "data", "world", "ui", "entities", "modes"]

func _check_code_conventions() -> void:
	var color_offenders: Array[String] = []
	var rotation_offenders: Array[String] = []

	for path: String in _gd_files():
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var lines := file.get_as_text().split("\n")
		file.close()

		var basename := path.get_file()
		for i in lines.size():
			var line: String = lines[i]
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue

			# Regel: Farben kommen aus der Palette.
			if basename != "palette.gd" and code.contains("Color("):
				# Vollstaendig transparent ist kein Farbton, sondern "unsichtbar".
				if not code.contains("Color(0, 0, 0, 0)"):
					color_offenders.append("%s:%d" % [path, i + 1])

			# Regel: Kurse laufen ueber heading(), nicht ueber rotation.y.
			#
			# Nicht jede Drehung um die Hochachse ist ein Kurs - ein Haus steht
			# schraeg, es faehrt nicht. Solche Stellen tragen "# kein Kurs" und
			# muessen die Ausnahme damit ausdruecklich behaupten.
			if basename != "ship.gd" and code.contains("rotation.y") \
					and not code.contains("# kein Kurs"):
				rotation_offenders.append("%s:%d" % [path, i + 1])

	_assert(color_offenders.is_empty(),
		"Keine Farbliterale ausserhalb der Palette%s" % _offenders(color_offenders))
	_assert(rotation_offenders.is_empty(),
		"Kurse laufen ueber heading(), nicht ueber rotation.y%s" % _offenders(rotation_offenders))

	# Regel: Auch Oberflaechen-Szenen holen ihre Farben aus der Palette.
	# theme_override_colors in einer .tscn ist eine Zahlenkolonne, die niemand
	# mehr mit der Palette abgleicht - genau so lagen dieselben Toene vorher in
	# sechs Dateien. Ausgenommen sind 3D-Materialien und die Umgebung: Die
	# werden im Editor mit Live-Vorschau eingestellt.
	var theme_offenders: Array[String] = []
	for path: String in _scene_files():
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var lines := file.get_as_text().split("\n")
		file.close()
		for i in lines.size():
			if lines[i].begins_with("theme_override_colors/"):
				theme_offenders.append("%s:%d" % [path, i + 1])
	_assert(theme_offenders.is_empty(),
		"Keine Textfarben in Szenendateien%s" % _offenders(theme_offenders))


func _gd_files() -> PackedStringArray:
	var found := PackedStringArray()
	for directory: String in CODE_DIRS:
		_collect_by_suffix("res://" + directory, ".gd", found)
	return found


func _collect_by_suffix(path: String, suffix: String, into: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path + "/" + entry
		if dir.current_is_dir():
			_collect_by_suffix(full, suffix, into)
		elif entry.ends_with(suffix):
			into.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _offenders(list: Array[String]) -> String:
	return "" if list.is_empty() else "  -> " + ", ".join(list.slice(0, 4))


## Prueft Gelaende-Chunks und Grundberuehrung.
func _check_terrain() -> void:
	WorldData.generate(4242)
	var g := WorldData.generator

	# Chunk-Koordinaten muessen umkehrbar sein, sonst landen Meshes woanders.
	var roundtrip_ok := true
	for i in 200:
		var half := WorldData.WORLD_SIZE * 0.5
		var x := randf_range(-half, half)
		var z := randf_range(-half, half)
		var coord := g.chunk_coord_at(x, z)
		var origin := g.chunk_origin(coord)
		if x < origin.x or x >= origin.x + WorldGenerator.TERRAIN_CHUNK_SIZE \
				or z < origin.y or z >= origin.y + WorldGenerator.TERRAIN_CHUNK_SIZE:
			roundtrip_ok = false
	_assert(roundtrip_ok, "Chunk-Koordinaten und Ursprung passen zusammen")

	# Die Belegungskarte darf keinen Landchunk uebersehen - sonst fehlen Inseln.
	var land_chunks := 0
	var missed := 0
	var total := 0
	for cz in g.chunk_grid_size:
		for cx in g.chunk_grid_size:
			var coord := Vector2i(cx, cz)
			total += 1
			var origin := g.chunk_origin(coord)
			var has_land := false
			for sz in 8:
				for sx in 8:
					var px := origin.x + (float(sx) + 0.5) * WorldGenerator.TERRAIN_CHUNK_SIZE / 8.0
					var pz := origin.y + (float(sz) + 0.5) * WorldGenerator.TERRAIN_CHUNK_SIZE / 8.0
					if g.is_land(px, pz):
						has_land = true
			if g.chunk_has_land(coord):
				land_chunks += 1
			elif has_land:
				missed += 1
	_assert(missed == 0, "Belegungskarte uebersieht keinen Landchunk")
	_assert(land_chunks > 0, "Es gibt Chunks mit Land")
	# Ueber offener See darf kein Mesh entstehen, sonst ist das Streaming sinnlos.
	var share := float(land_chunks) / float(total)
	_assert(share < 0.5, "Nur ein Teil der Chunks traegt Land (%.0f%%)" % (share * 100.0))

	# Hoehen in Metern: ueber dem Meeresspiegel positiv, darunter negativ.
	var land_town: TownData = WorldData.towns[0]
	_assert(WorldData.terrain_y(land_town.position.x, land_town.position.y) > 0.0,
		"Stadt liegt ueber dem Meeresspiegel")
	_assert(WorldData.terrain_y(0.0, WorldData.WORLD_SIZE * 0.49) < 0.0,
		"Weltrand liegt unter dem Meeresspiegel")

	# Mesh eines Landchunks: Vertexzahl und Ausdehnung muessen stimmen.
	var sample := Vector2i.ZERO
	for cz in g.chunk_grid_size:
		for cx in g.chunk_grid_size:
			if g.chunk_has_land(Vector2i(cx, cz)):
				sample = Vector2i(cx, cz)
				break
	var resolution := 16
	var mesh := TerrainChunk.build(g, sample, resolution, WorldData.TERRAIN_HEIGHT_SCALE)
	_assert(mesh.get_surface_count() == 1, "Chunk-Mesh hat eine Oberflaeche")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	_assert(vertices.size() == (resolution + 1) * (resolution + 1), "Vertexzahl passt zur Aufloesung")
	var aabb := mesh.get_aabb()
	_assert(absf(aabb.size.x - WorldGenerator.TERRAIN_CHUNK_SIZE) < 1.0,
		"Chunk-Mesh ist so breit wie sein Chunk")
	_assert(aabb.position.y >= TerrainChunk.SEABED_FLOOR - 0.1,
		"Mesh reicht nicht tiefer als der Meeresboden")

	# Gelaendematerial: Rueckseiten-Culling zerlegt steile Kuesten in Fetzen.
	var manager_script: GDScript = load("res://world/terrain/chunk_manager.gd")
	var manager: Node3D = manager_script.new()
	add_child(manager)
	await get_tree().process_frame
	var terrain_material: StandardMaterial3D = manager.get("_material")
	_assert(terrain_material != null, "Gelaendematerial existiert")
	if terrain_material != null:
		_assert(terrain_material.cull_mode == BaseMaterial3D.CULL_DISABLED,
			"Gelaende rendert beide Seiten")
		_assert(terrain_material.vertex_color_use_as_albedo,
			"Gelaende nutzt Vertex-Farben")
	manager.queue_free()

	# Grundberuehrung: Land muss das Schiff aufhalten.
	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var ship: Node3D = packed.instantiate()
	ship.set("player_controlled", false)
	add_child(ship)
	ship.global_position = Vector3(land_town.position.x, 0.0, land_town.position.y)
	ship.set("speed", 10.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert(ship.get("aground"), "Schiff laeuft an Land auf")
	_assert(is_zero_approx(ship.get("speed")), "Aufgelaufenes Schiff steht")
	ship.queue_free()


## Nagelt die Winkelkonvention fest.
##
## Anlass: Godots rotation.y dreht nach Westen, die Navigationskonvention nach
## Osten. Das Segelverhalten blieb korrekt, weil nur Differenzen zaehlen - aber
## Kompass, Seekarte und Startausrichtung waren an der Nord-Sued-Achse
## gespiegelt. Das Schiff schaute aufs offene Meer statt auf die Kueste.
func _check_heading_convention() -> void:
	# Reine Mathematik: Weltrichtung zu Navigationswinkel und zurueck.
	var north := SailingMath.direction(0.0)
	var east := SailingMath.direction(PI * 0.5)
	var south := SailingMath.direction(PI)
	var west := SailingMath.direction(-PI * 0.5)
	_assert(north.is_equal_approx(Vector2(0.0, -1.0)), "Kurs 0 zeigt nach Norden (-Z)")
	_assert(east.is_equal_approx(Vector2(1.0, 0.0)), "Kurs 90 Grad zeigt nach Osten (+X)")
	_assert(south.is_equal_approx(Vector2(0.0, 1.0)), "Kurs 180 Grad zeigt nach Sueden")
	_assert(west.is_equal_approx(Vector2(-1.0, 0.0)), "Kurs -90 Grad zeigt nach Westen")

	for angle: float in [0.0, 0.7, 1.9, -2.6, 3.0]:
		_assert(is_equal_approx(
			wrapf(SailingMath.angle_of(SailingMath.direction(angle)) - angle, -PI, PI), 0.0
		), "Winkel und Richtung sind umkehrbar (%.1f)" % angle)

	# Und jetzt am echten Node: Zeigt der Bug wirklich dorthin?
	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var ship: Node3D = packed.instantiate()
	ship.set("player_controlled", false)
	add_child(ship)
	ship.set_physics_process(false)

	for angle: float in [0.0, PI * 0.5, PI, -PI * 0.5, 1.1]:
		ship.call("set_heading", angle)
		var forward: Vector3 = -ship.global_basis.z
		var expected: Vector2 = SailingMath.direction(angle)
		var matches := absf(forward.x - expected.x) < 0.001 and absf(forward.z - expected.y) < 0.001
		_assert(matches, "Bug zeigt bei Kurs %4.0f Grad in die richtige Richtung" % rad_to_deg(angle))
		_assert(is_equal_approx(wrapf(ship.call("heading") - angle, -PI, PI), 0.0),
			"heading() gibt zurueck, was set_heading() gesetzt hat")

	ship.queue_free()


## Prueft die Geometrie des Schiffsmodells.
##
## Anlass: Der Kluederbaum zeigte nach unten und schwebte neben dem Rumpf.
## Godot speichert die Basis in .tscn ZEILENWEISE - eine spaltenweise gerechnete
## Rotationsmatrix landet transponiert in der Szene, also als inverse Drehung.
## Von der Verfolgerkamera aus faellt so etwas kaum auf.
func _check_ship_model() -> void:
	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var ship: Node3D = packed.instantiate()
	ship.set("player_controlled", false)
	add_child(ship)
	ship.set_physics_process(false)

	var bowsprit: Node3D = ship.get_node_or_null("Hull/Bowsprit")
	_assert(bowsprit != null, "Kluederbaum vorhanden")
	if bowsprit == null:
		ship.queue_free()
		return

	# Die Zylinderachse ist die lokale y-Achse.
	var axis: Vector3 = bowsprit.global_basis.y.normalized()
	_assert(axis.z < -0.5, "Kluederbaum zeigt nach vorne")
	_assert(axis.y > 0.1, "Kluederbaum zeigt nach oben, nicht ins Wasser")

	var elevation := rad_to_deg(asin(clampf(axis.y, -1.0, 1.0)))
	_assert(elevation > 10.0 and elevation < 35.0,
		"Kluederbaum-Neigung plausibel (%.0f Grad)" % elevation)

	# Fuss und Nock aus Achse und Meshlaenge.
	var mesh: CylinderMesh = (bowsprit as MeshInstance3D).mesh
	var half_length: float = mesh.height * 0.5
	var foot: Vector3 = bowsprit.global_position - axis * half_length
	var nock: Vector3 = bowsprit.global_position + axis * half_length

	# Der Fuss muss im Rumpf stecken - genau das war der sichtbare Fehler.
	var hull: MeshInstance3D = ship.get_node("Hull/HullMesh")
	var hull_mesh: BoxMesh = hull.mesh
	var hull_front: float = hull.global_position.z - hull_mesh.size.z * 0.5
	var bow: MeshInstance3D = ship.get_node("Hull/Bow")
	var bow_mesh: BoxMesh = bow.mesh
	var bow_front: float = bow.global_position.z - bow_mesh.size.z * 0.5

	_assert(foot.z > bow_front, "Kluederbaum steckt im Bug, statt davor zu schweben")
	_assert(foot.y < hull.global_position.y + hull_mesh.size.y * 0.5 + 0.4,
		"Kluederbaum-Fuss liegt nicht ueber dem Rumpf")
	_assert(nock.z < bow_front, "Nock ragt vor den Bug hinaus")
	_assert(nock.y > 1.0, "Nock liegt ueber der Wasserlinie")

	# Segel muessen an der Rah haengen und mit der Stellung schrumpfen.
	var sail: Node3D = ship.get_node_or_null("Hull/Mast/Sail")
	_assert(sail != null, "Segel vorhanden")
	if sail != null:
		var spar: Node3D = ship.get_node("Hull/Mast/Spar")
		_assert(absf(sail.global_position.y - spar.global_position.y) < 0.2,
			"Segel haengt an der Rah")

	ship.queue_free()


func _assert(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		print("  FEHL  %s" % label)
		_failures += 1
