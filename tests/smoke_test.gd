## Rauchtest fuer das M0-Geruest.
##
## Laufen lassen mit:
##   godot --headless --path . res://tests/smoke_test.tscn
##
## Prueft, dass alle Autoloads existieren und die Grundfunktionen zusammen-
## spielen. Beendet mit Code 0 bei Erfolg, sonst 1.
extends Node

var _failures: int = 0


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
	await _check_terrain()
	_check_code_conventions()
	_check_everything_loads()

	print("=== %s ===" % ("BESTANDEN" if _failures == 0 else "%d FEHLER" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_autoloads() -> void:
	for name in ["EventBus", "WorldData", "GameState", "SaveManager", "AudioDirector", "SceneRouter"]:
		_assert(get_tree().root.get_node_or_null(NodePath(name)) != null, "Autoload %s geladen" % name)


func _check_input_map() -> void:
	var expected := [
		"helm_port", "helm_starboard", "sails_more", "sails_less",
		"fire_port", "fire_starboard", "interact", "spyglass",
		"toggle_map", "time_faster", "pause",
	]
	for action: String in expected:
		var known := InputMap.has_action(action)
		var bound := known and not InputMap.action_get_events(action).is_empty()
		_assert(bound, "Eingabe %s belegt" % action)


func _check_new_campaign() -> void:
	GameState.new_campaign("Testkapitaen", 12345)
	_assert(GameState.captain_name == "Testkapitaen", "Kapitaensname gesetzt")
	_assert(GameState.gold == 500, "Startgold 500")
	_assert(GameState.crew == 20, "Startcrew 20")
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
	if condition:
		print("  ok    %s" % label)
	else:
		print("  FEHL  %s" % label)
		_failures += 1
