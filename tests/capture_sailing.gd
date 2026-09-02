## Rendert den Segelmodus und legt Aufnahmen ab - Sichtpruefung fuer M1.
##
## Laufen lassen mit:
##   godot --path . res://tests/capture_sailing.tscn
##
## Braucht ein echtes Fenster: Der Ozean-Shader wird nur beim Rendern
## kompiliert, headless bleibt er ungeprueft.
extends Node

const OUT_DIR: String = "user://captures"

var _ship: Ship
var _camera_rig: Node3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("Aufnahmen nach: ", ProjectSettings.globalize_path(OUT_DIR))

	var packed: PackedScene = load("res://modes/sailing/sailing_mode.tscn")
	var mode: Node = packed.instantiate()
	add_child(mode)
	await get_tree().process_frame
	_ship = mode.get_node("PlayerShip")
	_camera_rig = mode.get_node("CameraRig")

	# Wind festnageln, sonst dreht er waehrend der Aufnahme weg.
	_pin_wind(deg_to_rad(90.0))

	# Chunks brauchen ein paar Frames, bis sie stehen.
	await _wait(2.0)
	var terrain: Node3D = mode.get_node("Terrain")
	print("  Chunks geladen: %d" % terrain.loaded_count())
	_report_performance(terrain)

	await _wait(2.5)
	await _shot("01_raumschots")

	Input.action_press("helm_starboard")
	await _wait(2.5)
	Input.action_release("helm_starboard")
	await _wait(0.5)
	await _shot("02_wende")

	# Direkt in den Wind drehen - das HUD muss warnen.
	_ship.set_heading(deg_to_rad(90.0))
	await _wait(2.0)
	await _shot("03_in_irons")

	# Seekarte oeffnen. Vorher jeder Nation ein anderes Verhaeltnis geben:
	# Sonst stuenden in der Legende viermal dieselben Worte in derselben Farbe,
	# und die Aufnahme wuerde nicht zeigen, ob die Stufen ueberhaupt greifen.
	GameState.change_reputation(GameState.Nation.SPAIN, -80)
	GameState.change_reputation(GameState.Nation.ENGLAND, -30)
	GameState.change_reputation(GameState.Nation.FRANCE, 45)
	# Und einen Kaperbrief dazu - er steht nur bei einer Nation und waere sonst
	# auf keiner Aufnahme zu sehen.
	GameState.letter_nation = GameState.Nation.FRANCE
	# Dazu ein laufender Auftrag: Die Zeile ueber der Karibik ist der einzige
	# Ort, an dem eine Frist sichtbar herunterzaehlt. Das Gerede aus der
	# Schenke gleich mit - ohne das fehlt der Aufnahme das Revier, und ob der
	# Ortsname noch in die Zeile passt, sieht man nur im Bild.
	GameState.accept_commission(GameState.Nation.FRANCE)
	GameState.hear_commission_rumour()
	var map: Control = mode.get_node("WorldMap")
	map.toggle()
	await _wait(1.0)
	await _shot("04_seekarte")
	map.toggle()

	# Vor einen Hafen legen - die Anlegeaufforderung muss erscheinen.
	await _approach_town()
	await _shot("05_anlegen")

	# Das Debug-Menue. Es baut sich im Code zusammen, also gibt es keine Szene,
	# in der man die Anordnung sehen koennte - nur dieses Bild.
	var debug: DebugMenu = mode.get_node("DebugMenu")
	debug.toggle()
	await _wait(1.0)
	await _shot("06_debug")

	get_tree().quit(0)


## Setzt das Schiff dicht vor eine Stadt, mit Blick auf sie.
func _approach_town() -> void:
	if WorldData.towns.is_empty():
		return
	var town: TownData = WorldData.towns[0]
	var anchor := WorldData.anchorage_for(town)

	_ship.global_position = Vector3(anchor.x, 0.0, anchor.y)
	_ship.set_heading(SailingMath.angle_of(town.position - anchor))
	# Wie beim Auslaufen aus einem Hafen: versetzt, nicht gefahren.
	_camera_rig.snap()
	print("  Hafen in Sicht: %s (%s)" % [town.town_name, town.tier_name()])
	await _wait(2.5)


## Misst die Bildrate ueber zwei Sekunden Fahrt bei geladenem Gelaende.
func _report_performance(terrain: Node3D) -> void:
	var frames := 0
	var started := Time.get_ticks_msec()
	var worst := 0.0
	while Time.get_ticks_msec() - started < 2000:
		var frame_started := Time.get_ticks_usec()
		await get_tree().process_frame
		worst = maxf(worst, float(Time.get_ticks_usec() - frame_started) / 1000.0)
		frames += 1
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	print("  Bildrate: %.0f fps im Mittel, langsamster Frame %.1f ms, %d Chunks"
		% [float(frames) / elapsed, worst, terrain.loaded_count()])


func _pin_wind(direction: float) -> void:
	WorldData.set_wind(direction, 1.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	var error := image.save_png(path)
	print("  %-16s  kurs %4d°   %5.1f kn   %s   [%s]" % [
		shot_name,
		wrapi(int(rad_to_deg(_ship.heading())), 0, 360),
		_ship.speed,
		_ship.point_of_sail(),
		"ok" if error == OK else "FEHLER %d" % error,
	])
