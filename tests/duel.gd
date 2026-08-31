## Ein Seegefecht auf Knopfdruck - zum Spielen und zum Messen.
##
## Mit Fenster:
##   godot --path . res://tests/duel.tscn
## Ohne Fenster:
##   godot --headless --path . res://tests/duel.tscn
##
## Beides ist dieselbe Szene, weil es dieselbe Frage ist: Trifft man, wenn man
## richtig liegt? Nur die Antwort sieht anders aus.
##
## [b]Mit Fenster[/b] steht man laengsseits eines Gegners auf offener See, und
## das Gefecht laeuft sofort - kein Auslaufen, kein Warten auf ein zufaelliges
## Segel. Q und E feuern, A und D legen das Ruder, W und S setzen Segel, F3
## oeffnet das Debug-Menue. Dazu:
##   R - neuer Gegner in derselben Ausgangslage
##   G - Gegnerklasse wechseln (Patrouillenschaluppe / Handelsbrigg)
##   H - Ausgangslage wechseln (laengsseits / achteraus / entgegenkommend)
## Jede Breitseite wird auf der Konsole mitgeschrieben, mit der Abweichung von
## querab - daran sieht man, warum eine Salve vorbeiging.
##
## [b]Ohne Fenster[/b] fahren KI gegen KI mehrere Gefechte im Zeitraffer, und
## am Ende stehen die Kennzahlen: Salven, Trefferanteil, Schaden, Dauer. Das
## ist das Messgeraet fuer LEAD_SPREAD, SPREAD_DEG und den Schaden je Kugel -
## Balancewerte werden gefahren, nicht geschaetzt (Regel C4).
extends Node

const MERCHANT: String = "res://resources/ships/merchant_brig.tres"
const PATROL: String = "res://resources/ships/patrol_sloop.tres"
const PLAYER_SHIP: String = "res://resources/ships/sloop.tres"

## Ausgangslagen. Der Kegel von zwanzig Grad ist so eng, dass die Lage zu
## Beginn den ganzen Verlauf bestimmt - deshalb sind alle drei durchspielbar.
enum Setup { ABEAM, ASTERN, HEAD_ON }

const SETUP_NAMES: PackedStringArray = ["laengsseits", "achteraus", "entgegenkommend"]

## Abstand, in dem das Gefecht beginnt. Etwas mehr als die ideale Entfernung:
## Die erste Salve soll man sich noch erarbeiten muessen.
const START_RANGE: float = 240.0

# --- Nur fuer den Messlauf -------------------------------------------------
## So viele Gefechte je Paarung. Mehr Laeufe glaetten den Zufall, kosten aber
## Zeit - fuenf reichen, um eine Aenderung von zwanzig Prozent zu sehen.
const RUNS: int = 5
## Laenger dauert kein Gefecht. Wer bis dahin nicht getroffen hat, trifft nicht.
const DUEL_SECONDS: float = 180.0
## Im Zeitraffer, sonst dauert ein Messlauf eine Viertelstunde. Der Physik-
## schritt wird mitgehoben, damit das Ruder nicht in Spruengen arbeitet.
const TIME_SCALE: float = 15.0
const PHYSICS_HZ: int = 120
## Schreibt den Verlauf des ersten Gefechts Sekunde fuer Sekunde mit: Abstand,
## Abweichung von querab, Segel, Fahrt. Aus, weil es die Kennzahlen zuschuettet -
## an, sobald eine Zahl unerklaerlich aussieht. Genau so ist herausgekommen, dass
## ein Verfolger ueber seinen Platz hinauslaeuft.
const TRACE: bool = false
## Sekunden Spielzeit zwischen zwei Zeilen der Mitschrift.
const TRACE_INTERVAL: float = 5.0
## Schreibt jeden einzelnen Lauf mit statt nur den Mittelwert. An heisst: Man
## sieht, ob eine Paarung durchweg knapp ausgeht oder ob zwei Ausreisser den
## Schnitt machen - das ist beim Einstellen von Schadenswerten der Unterschied
## zwischen Messen und Raten.
const TRACE_RUNS: bool = true

var _mode: Node3D
var _ship: Ship
var _combat: NavalCombat
var _enemy: Ship
var _enemy_class: String = PATROL
var _setup: Setup = Setup.ABEAM
var _spot: Vector2 = Vector2.ZERO

## Mitschrift des laufenden Gefechts.
var _salvos: int = 0
var _hits: int = 0
var _shots: int = 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		await _measure()
	else:
		await _play()


# --- Mit Fenster: das spielbare Duell --------------------------------------

func _play() -> void:
	var packed: PackedScene = load("res://modes/sailing/sailing_mode.tscn")
	_mode = packed.instantiate()
	add_child(_mode)
	await get_tree().process_frame

	_ship = _mode.get_node("PlayerShip")
	_combat = _mode.get_node("Combat")
	# Leere See ringsum: Wer ein Gefecht ausprobiert, will nicht mitten darin
	# ein zweites Segel am Horizont haben.
	_combat.max_ships = 0

	# Wind festnageln. Ein drehender Wind waere im Gefecht zwar richtig, macht
	# aber zwei Versuche unvergleichbar.
	WorldData.set_wind(deg_to_rad(180.0), 1.0)

	_spot = _open_sea()
	_ship.global_position = Vector3(_spot.x, 0.0, _spot.y)
	_ship.set_heading(0.0)
	_mode.get_node("CameraRig").snap()

	EventBus.broadside_landed.connect(_on_broadside)
	EventBus.cannons_fired.connect(_on_fired)

	_summon()
	print_rich("[b]Duell[/b] - R neuer Gegner, G Gegnerklasse, H Ausgangslage")


func _unhandled_input(event: InputEvent) -> void:
	if _combat == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_R:
			_summon()
		KEY_G:
			_enemy_class = PATROL if _enemy_class == MERCHANT else MERCHANT
			_summon()
		KEY_H:
			_setup = ((_setup + 1) % SETUP_NAMES.size()) as Setup
			_summon()


## Stellt einen frischen Gegner in die gewaehlte Ausgangslage.
##
## Auch das eigene Schiff wird dabei geheilt und zurueckgesetzt: Ein Duell zum
## Ausprobieren soll mit demselben Blatt anfangen wie das davor.
func _summon() -> void:
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.queue_free()

	_ship.global_position = Vector3(_spot.x, 0.0, _spot.y)
	_ship.set_heading(0.0)
	_ship.speed = 0.0
	_ship.set_condition(_ship.max_hull, _ship.max_sails, _ship.max_crew)
	_mode.get_node("CameraRig").snap()

	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	_enemy = packed.instantiate()
	_enemy.player_controlled = false
	_combat.add_child(_enemy)
	_enemy.apply_class(load(_enemy_class))
	_enemy.ship_name = "Duellant"
	_enemy.nation_id = 3

	var placement := _placement()
	_enemy.global_position = Vector3(placement.x, 0.0, placement.y)
	_enemy.set_heading(_enemy_heading())
	_combat.adopt(_enemy)
	# Sofort gereizt: Sonst faehrt eine Handelsbrigg erst einmal davon, und man
	# sieht eine halbe Minute lang gar kein Gefecht.
	var captain := _enemy.get_node_or_null("Kapitaen") as ShipAI
	if captain != null:
		captain.provoked = true

	_salvos = 0
	_hits = 0
	_shots = 0
	print("--- %s, %s auf %d m ---" % [
		_enemy.ship_class.display_name, SETUP_NAMES[_setup], int(START_RANGE)
	])


## Wo der Gegner steht. Das eigene Schiff liegt auf Nordkurs im Ursprung.
func _placement() -> Vector2:
	match _setup:
		Setup.ASTERN:
			# Hinter einem her - die Lage, in der kein Rohr anliegt und man
			# erst einmal abdrehen muss.
			return _spot + Vector2(0.0, START_RANGE)
		Setup.HEAD_ON:
			return _spot + Vector2(0.0, -START_RANGE)
		_:
			return _spot + Vector2(START_RANGE, 0.0)


func _enemy_heading() -> float:
	return PI if _setup == Setup.HEAD_ON else 0.0


func _on_broadside(by_player: bool, hits: int, shots: int) -> void:
	if not by_player:
		return
	_salvos += 1
	_hits += hits
	_shots += shots
	print("  Salve %2d:  %d von %d   (%d %% ueber alles)" % [
		_salvos, hits, shots, int(100.0 * float(_hits) / float(maxi(_shots, 1)))
	])


## Schreibt mit, wie schief die Rohre standen. Genau das ist die Auskunft, die
## in M4 fehlte: Ein Fehlschuss sah aus wie Pech, nicht wie ein Fehler.
func _on_fired(shooter: Ship, side: int) -> void:
	if shooter != _ship or _enemy == null or not is_instance_valid(_enemy):
		return
	var bearing := SailingMath.bearing(_ship.plan_position(), _enemy.plan_position())
	var offset := rad_to_deg(Gunnery.aim_offset(_ship.heading(), bearing, side))
	var distance := _ship.plan_position().distance_to(_enemy.plan_position())
	print("  %s: %.0f m, %+.0f Grad von querab%s" % [
		"Backbord" if side == Gunnery.PORT else "Steuerbord",
		distance,
		offset,
		"" if absf(offset) <= _ship.gun_traverse else "  -- am Anschlag, geht vorbei",
	])


# --- Ohne Fenster: der Messlauf --------------------------------------------

func _measure() -> void:
	print("Duell-Kennzahlen - %d Laeufe je Paarung, hoechstens %.0f s" % [RUNS, DUEL_SECONDS])
	print("%-30s %6s %7s %9s %8s %8s %8s" % [
		"Paarung", "Dauer", "Salven", "Treffer", "Schaden", "liegt an", "Flagge"
	])
	# Angreifer ist immer ein Kriegsschiff: Nur die suchen das Gefecht. Eine
	# Schaluppe oder eine Handelsbrigg mit Kapitaen flieht, und eine Verfolgung
	# sagt nur, wer schneller ist.
	await _series("Patrouille gegen Handelsbrigg", PATROL, MERCHANT)
	await _series("Patrouille gegen Patrouille", PATROL, PATROL)
	await _series("Patrouille gegen Schaluppe", PATROL, PLAYER_SHIP)
	get_tree().quit(0)


func _series(label: String, attacker: String, defender: String) -> void:
	var seconds := 0.0
	var salvos := 0
	var hits := 0
	var shots := 0
	var damage := 0
	var struck := 0
	var bearing := 0.0
	for run in RUNS:
		var result := await _duel(attacker, defender, 4711 + run * 97, run == 0)
		if TRACE_RUNS:
			print("    Lauf %d (Seed %d): %.0fs  %d/%d Treffer  %d Schaden  %s" % [
				run, 4711 + run * 97, result["seconds"], result["hits"], result["shots"],
				result["damage"], "Flagge" if result["struck"] else "-",
			])
		seconds += result["seconds"]
		salvos += result["salvos"]
		hits += result["hits"]
		shots += result["shots"]
		damage += result["damage"]
		bearing += result["bearing"]
		struck += 1 if result["struck"] else 0
	print("%-30s %5.0fs %7.1f %5d/%-3d %8.0f %7d%% %5d/%d" % [
		label,
		seconds / float(RUNS),
		float(salvos) / float(RUNS),
		hits,
		shots,
		float(damage) / float(RUNS),
		int(100.0 * bearing / float(RUNS)),
		struck,
		RUNS,
	])


## Traegt ein Gefecht aus. Beide Seiten fahren mit Kapitaen - gemessen wird das
## System, nicht die Hand am Ruder.
func _duel(
	attacker_path: String, defender_path: String, seed_value: int, traced: bool = false
) -> Dictionary:
	GameState.new_campaign("Duellant", seed_value)
	# Wind querab und fest. Nicht aus Nord: Beide Schiffe starten auf Nordkurs
	# und laegen dann in Irons - man saehe ein Gefecht zweier Schiffe, die sich
	# kaum bewegen, und die Kennzahlen sagten nichts ueber das Manoevrieren aus.
	WorldData.set_wind(deg_to_rad(90.0), 1.0)
	var spot := _open_sea()

	var combat := NavalCombat.new()
	# Kein Nachschub: Ein drittes Segel waehrend der Messung verfaelscht alles.
	combat.max_ships = 0
	add_child(combat)

	var mine := _make_ship(attacker_path)
	mine.global_position = Vector3(spot.x, 0.0, spot.y)
	mine.set_heading(0.0)
	combat.setup(mine)
	# Erst jetzt: setup() wuerfelt den Wuerfel neu.
	combat.rng.seed = seed_value

	var theirs := _make_ship(defender_path)
	theirs.ship_name = "Beute"
	# Laengsseits auf wirksamem Abstand - die Lage, in der ein Gefecht wirklich
	# beginnt. Nicht START_RANGE wie im spielbaren Duell: Das Aufschliessen davor
	# dauert bei vier Knoten Vorsprung ueber eine Minute und wuerde die Haelfte
	# der Messzeit auffressen, ohne etwas ueber die Ballistik zu sagen.
	theirs.global_position = Vector3(spot.x + Gunnery.IDEAL_RANGE, 0.0, spot.y)
	theirs.set_heading(0.0)
	combat.adopt(theirs)

	var captain := ShipAI.new()
	captain.setup(mine)
	captain.provoked = true
	mine.add_child(captain)

	var tally := {"salvos": 0, "hits": 0, "shots": 0}
	var counter := func(by_player: bool, hits: int, shots: int) -> void:
		if not by_player:
			return
		tally["salvos"] += 1
		tally["hits"] += hits
		tally["shots"] += shots
	EventBus.broadside_landed.connect(counter)

	var previous_scale := Engine.time_scale
	var previous_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	Engine.time_scale = TIME_SCALE
	var step := TIME_SCALE / float(PHYSICS_HZ)

	# Mitgezaehlt wird, wie oft ueberhaupt ein Rohr anlag. Das ist die Zahl, an
	# der man sieht, ob eine schwache Bilanz an der Ballistik liegt oder daran,
	# dass der Kapitaen seinen Platz nicht haelt.
	var samples := 0
	var bearing_samples := 0
	var next_trace := 0.0
	var elapsed := 0.0
	while elapsed < DUEL_SECONDS and not theirs.struck and not theirs.finished:
		captain.target = theirs
		await get_tree().physics_frame
		elapsed += step
		samples += 1
		var range_to := mine.plan_position().distance_to(theirs.plan_position())
		var bearing := SailingMath.bearing(mine.plan_position(), theirs.plan_position())
		if range_to <= Gunnery.MAX_RANGE and (
			Gunnery.bears(mine.heading(), bearing, Gunnery.PORT, mine.gun_traverse)
			or Gunnery.bears(mine.heading(), bearing, Gunnery.STARBOARD, mine.gun_traverse)
		):
			bearing_samples += 1
		if TRACE and traced and elapsed >= next_trace:
			next_trace += TRACE_INTERVAL
			print("  %5.0fs  %4.0f m  quer %+4.0f Grad  Segel %d  %4.1f kn  Gegner %4.1f kn" % [
				elapsed,
				range_to,
				rad_to_deg(Gunnery.aim_offset(mine.heading(), bearing, captain._circle_side)),
				mine.sail_step,
				mine.speed,
				theirs.speed,
			])

	Engine.time_scale = previous_scale
	Engine.physics_ticks_per_second = previous_hz
	EventBus.broadside_landed.disconnect(counter)

	var result := {
		"struck": theirs.struck,
		"seconds": elapsed,
		"salvos": tally["salvos"],
		"hits": tally["hits"],
		"shots": tally["shots"],
		"damage": (theirs.max_hull - theirs.hull) + (theirs.max_sails - theirs.sails),
		"bearing": float(bearing_samples) / float(maxi(samples, 1)),
	}

	combat.queue_free()
	mine.queue_free()
	theirs.queue_free()
	await get_tree().process_frame
	return result


func _make_ship(class_path: String) -> Ship:
	var packed: PackedScene = load("res://entities/ship/ship.tscn")
	var ship: Ship = packed.instantiate()
	ship.player_controlled = false
	add_child(ship)
	ship.apply_class(load(class_path))
	return ship


## Ein Fleck offene See, weit genug von jeder Kueste fuer ein Gefecht.
func _open_sea() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldData.world_seed
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
