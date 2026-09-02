## Rendert ein Seegefecht und legt Aufnahmen ab - Sichtpruefung fuer M4.
##
## Laufen lassen mit:
##   godot --path . res://tests/capture_battle.tscn
##
## Braucht ein echtes Fenster. Muendungsrauch, fliegende Kugeln und die
## Wassersaeulen eines Fehlschusses sind Geometrie, die erst beim Rendern
## entsteht - headless gibt es sie nicht. Und die Flagge im Masttopp ist die
## einzige Auskunft darueber, wem das fremde Segel gehoert: Ist sie zu klein
## oder in der falschen Farbe, faellt das nur im Bild auf.
extends Node

const OUT_DIR: String = "user://captures"
## Entfernung fuer die erste Aufnahme: ein fremdes Segel, gerade eben in
## Gefechtsreichweite. Weiter draussen zeigt weder Kamera noch HUD etwas an,
## und die Aufnahme waere ein Bild von leerer See.
const SIGHTING_RANGE: float = 540.0
## Und fuer das Gefecht selbst.
const FIGHTING_RANGE: float = 180.0

var _ship: Ship
var _camera_rig: Node3D
var _combat: NavalCombat
var _enemy: Ship
var _last_salvo: String = "-"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("Aufnahmen nach: ", ProjectSettings.globalize_path(OUT_DIR))

	var packed: PackedScene = load("res://modes/sailing/sailing_mode.tscn")
	var mode: Node = packed.instantiate()
	add_child(mode)
	await get_tree().process_frame
	_ship = mode.get_node("PlayerShip")
	_camera_rig = mode.get_node("CameraRig")
	_combat = mode.get_node("Combat")

	EventBus.broadside_landed.connect(_on_broadside)
	# Wind festnageln, sonst dreht er waehrend der Aufnahme weg.
	WorldData.set_wind(deg_to_rad(180.0), 1.0)

	var spot := _open_sea()
	_ship.global_position = Vector3(spot.x, 0.0, spot.y)
	_ship.set_heading(0.0)
	_camera_rig.snap()
	await _wait(2.0)

	_enemy = _summon(SIGHTING_RANGE)
	print("  Gegner: %s (%s)" % [_enemy.ship_name, _enemy.ship_class.display_name])
	await _wait(2.0)
	await _shot("01_segel_in_sicht")

	# Laengsseits auf Gefechtsabstand: Von hier aus liegt die Breitseite an.
	_enemy.global_position = Vector3(spot.x + FIGHTING_RANGE, 0.0, spot.y)
	_enemy.set_heading(0.0)
	await _wait(1.0)
	await _shot("02_laengsseits")

	_ship.fire(Gunnery.STARBOARD)
	# Die Kugeln brauchen fuer 180 Meter rund eine halbe Sekunde - hier soll
	# der Muendungsrauch stehen und die Salve noch in der Luft sein.
	await _wait(0.28)
	await _shot("03_breitseite")

	# Kurz nach dem Aufschlag: Fontaenen und Rauch stehen nur gut eine Sekunde.
	await _wait(0.45)
	await _shot("04_einschlag")

	# Enterreichweite: Jetzt muss im HUD die Aufforderung zum Entern stehen -
	# und nicht die zum Anlegen oder Aufbringen. Die drei teilen sich eine
	# Zeile und haben sich frueher gegenseitig ueberschrieben.
	# Relativ zum Schiff, nicht zum Startpunkt: Es faehrt waehrend der Aufnahme
	# weiter, und bei 45 Metern Enterreichweite verzeiht das keine Drift.
	_enemy.global_position = _ship.global_position 		+ Vector3(Boarding.REACH * 0.6, 0.0, 0.0)
	await _wait(1.0)
	await _shot("05_enterreichweite")

	# Der Sturm selbst. Die Meldung danach nennt beide Verlustzahlen - wer
	# entert, soll die Rechnung sehen.
	_combat.board(_enemy)
	await _wait(0.8)
	await _shot("06_geentert")

	# Und die Folge: Unter der Mindestbesatzung faellt die Fahrt, und das steht
	# seit M5 auch da. Vorher zeigte nur der Knotenmesser zu wenig an.
	_ship.take_hit(Gunnery.Zone.CREW, _ship.crew - _ship.min_crew + 3)
	await _wait(1.5)
	await _shot("07_unterbesetzt")

	# Zuletzt die gestrichene Flagge als Prise.
	_enemy.take_hit(Gunnery.Zone.HULL, int(float(_enemy.max_hull) * 0.8))
	EventBus.ship_struck.emit(_enemy.ship_name)
	await _wait(2.0)
	await _shot("08_prise")

	# Und ausgeraeumt, mit einem Kaperbrief einer anderen Krone in der Tasche:
	# Der Auftraggeber steht dann in derselben Meldezeile wie die Beute. Der
	# Brief wird hier erst ausgestellt, damit die Aufnahmen davor die gewohnten
	# Verhaeltnisse zeigen.
	GameState.issue_letter(_patron_against(_enemy.nation_id))
	_combat.take_prize(_enemy)
	await _wait(0.8)
	await _shot("09_prise_gutgeschrieben")

	# Zum Schluss ein benannter Gegner. Zwei Dinge sind nur hier zu sehen: die
	# Silhouette der Fregatte, die es vorher nicht gab, und die Zielzeile mit
	# einem Kapitaensnamen darin - die Wiedererkennung, auf der Auftrag und
	# Kopfgeld beruhen.
	# Spanien erst feindlich machen: Ein Kopfgeldjaeger faehrt nur fuer eine
	# Krone aus, die einen sucht. Ohne das stuende in der Zielzeile
	# "Gleichgueltig", waehrend die Meldung darunter "Spanien sucht dich" sagt -
	# ein Bild, das sich selbst widerspricht.
	while GameState.standing_with(GameState.Nation.SPAIN) != Standing.Level.HOSTILE:
		GameState.change_reputation(GameState.Nation.SPAIN, -10)
	GameState.add_notoriety(Bounty.FEARED_FROM)

	# Naeher heran als das uebrige Gefecht: Die Fregatte ist die erste Klasse mit
	# einer eigenen Silhouette, und auf 180 Metern ist davon nichts zu erkennen.
	var hunter := _summon_named(120.0)
	print("  Kopfgeldjaeger: %s (%s)" % [hunter.captain_name, hunter.ship_class.display_name])
	# Ab hier ist er der Gegner, ueber den die Aufnahmezeile berichtet.
	_enemy = hunter
	EventBus.named_captain_sighted.emit(
		hunter.captain_name, hunter.ship_name, hunter.nation_id, true
	)
	await _wait(1.2)
	await _shot("10_kopfgeldjaeger")

	get_tree().quit(0)


## Ein benannter Gegner auf einer Fregatte, querab.
##
## Ueber [Bounty] und nicht von Hand zusammengesetzt: Die Aufnahme soll zeigen,
## was das Spiel wirklich schickt, nicht was die Sichtpruefung sich ausdenkt.
func _summon_named(distance: float) -> Ship:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldData.world_seed
	var who := Bounty.hunter(
		rng, WorldData.get_nation(GameState.Nation.SPAIN), Bounty.FEARED_FROM
	)

	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var enemy: Ship = packed.instantiate()
	enemy.player_controlled = false
	_combat.add_child(enemy)
	enemy.apply_class(load(who.ship_class_path))
	enemy.ship_name = who.ship_name
	enemy.captain_name = who.captain_name
	enemy.nation_id = who.nation_id
	enemy.global_position = _ship.global_position + Vector3(distance, 0.0, 0.0)
	enemy.set_heading(0.0)
	_combat.adopt(enemy)
	# Wie bei jedem gestellten Gegner: Der Kapitaen wuerde losfahren, das Schiff
	# soll aber stehen bleiben, wo es hingestellt wurde.
	#
	# set_physics_process(false) gehoert dazu und queue_free() allein reicht
	# nicht: Freigegeben wird erst am Bildende, und ein feindlicher Kapitaen
	# entscheidet im ersten Takt danach noch einmal. Die Fregatte hat in genau
	# dieser Luecke eine volle Breitseite abgegeben, und die Aufnahme zeigte
	# statt ihrer Silhouette den eigenen Pulverdampf.
	var captain := enemy.get_node_or_null("Kapitaen")
	if captain != null:
		captain.set_physics_process(false)
		captain.queue_free()
	return enemy


## Die Krone, deren Brief eine Prise gegen diese Flagge deckt.
##
## Seit es Kriege gibt ([Diplomacy]), ist das nicht mehr irgendeine fremde:
## Gedeckt ist genau der Kriegsgegner. Mit einer beliebigen Krone haette die
## Aufnahme je nach Seed die Gutschrift gezeigt oder nicht.
func _patron_against(nation_id: int) -> int:
	var patron := WorldData.enemy_of(nation_id)
	return patron if patron >= 0 else GameState.Nation.ENGLAND


## Setzt ein fremdes Segel in eine bestimmte Entfernung querab.
func _summon(distance: float) -> Ship:
	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var enemy: Ship = packed.instantiate()
	enemy.player_controlled = false
	_combat.add_child(enemy)
	enemy.apply_class(load("res://resources/ships/merchant_brig.tres"))
	enemy.ship_name = "Zeelandia"
	enemy.nation_id = 3
	enemy.global_position = _ship.global_position + Vector3(distance, 0.0, 0.0)
	enemy.set_heading(0.0)
	_combat.adopt(enemy)
	# Der Kapitaen wuerde sofort fliehen - fuer eine Aufnahme soll das Schiff
	# stehen bleiben, wo es hingestellt wurde. Erst stilllegen, dann freigeben:
	# queue_free() wirkt erst am Bildende, und ein Takt reicht fuer eine
	# Entscheidung (siehe _summon_named).
	var captain := enemy.get_node_or_null("Kapitaen")
	if captain != null:
		captain.set_physics_process(false)
		captain.queue_free()
	return enemy


func _open_sea() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldData.world_seed
	var half := WorldData.WORLD_SIZE * 0.45
	for attempt in 500:
		var spot := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		var clear := true
		for i in 12:
			var angle := TAU * float(i) / 12.0
			var probe := spot + Vector2(sin(angle), cos(angle)) * 900.0
			if not WorldData.is_navigable(probe.x, probe.y):
				clear = false
				break
		if clear:
			return spot
	return Vector2.ZERO


func _on_broadside(by_player: bool, hits: int, shots: int) -> void:
	_last_salvo = "%s %d/%d" % ["eigene" if by_player else "gegnerische", hits, shots]


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	var error := image.save_png(path)
	# is_instance_valid und nicht "!= null": Eine ausgeraeumte Prise treibt zwei
	# Sekunden lang davon und wird dann freigegeben - die Variable zeigt danach
	# weiter auf sie, und jeder Zugriff bricht die Aufnahme ab. Genau das ist
	# passiert, als hinter der Prise noch eine Aufnahme dazukam.
	var shown: Ship = _enemy if is_instance_valid(_enemy) else null
	if shown == null:
		print("  %-18s  kein Gegner   Salve %-14s [%s]" % [
			shot_name, _last_salvo, "ok" if error == OK else "FEHLER %d" % error,
		])
		return
	print("  %-18s  %5.0f m   Gegner Rumpf %3d Segel %3d   Salve %-14s [%s]" % [
		shot_name,
		_ship.plan_position().distance_to(shown.plan_position()),
		shown.hull, shown.sails, _last_salvo,
		"ok" if error == OK else "FEHLER %d" % error,
	])
