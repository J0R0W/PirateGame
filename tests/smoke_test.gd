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
	_check_ship_model()
	_check_heading_convention()
	await _check_terrain()
	_check_code_conventions()

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
		for good: String in town.production:
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
			if basename != "ship.gd" and code.contains("rotation.y"):
				rotation_offenders.append("%s:%d" % [path, i + 1])

	_assert(color_offenders.is_empty(),
		"Keine Farbliterale ausserhalb der Palette%s" % _offenders(color_offenders))
	_assert(rotation_offenders.is_empty(),
		"Kurse laufen ueber heading(), nicht ueber rotation.y%s" % _offenders(rotation_offenders))


func _gd_files() -> PackedStringArray:
	var found := PackedStringArray()
	for directory: String in CODE_DIRS:
		_collect_gd("res://" + directory, found)
	return found


func _collect_gd(path: String, into: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path + "/" + entry
		if dir.current_is_dir():
			_collect_gd(full, into)
		elif entry.ends_with(".gd"):
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
