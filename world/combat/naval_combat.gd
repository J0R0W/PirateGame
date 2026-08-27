## Alles, was auf See zwischen zwei Schiffen passiert.
##
## Haengt als Knoten im Segelmodus und ist die einzige Stelle, die mehr als ein
## Schiff kennt. Ein [Ship] weiss nur von sich selbst - wer auf wen schiesst,
## wer wen sieht und wer wen ausraubt, wird hier entschieden.
##
## Drei Aufgaben, in dieser Reihenfolge im Code:
##   1. Begegnungen - fremde Segel auftauchen und wieder verschwinden lassen
##   2. Breitseiten - auswuerfeln, fliegen lassen, Schaden zuteilen
##   3. Prisen - was ein besiegter Gegner hergibt
class_name NavalCombat
extends Node3D

const SHIP_SCENE: String = "res://entities/ship/ship.tscn"

# --- Begegnungen -----------------------------------------------------------
## Hoechstens so viele fremde Segel gleichzeitig. Mehr waeren auf offener See
## unglaubwuerdig und im Gefecht unuebersichtlich.
##
## Veraenderlich statt konstant, damit das Debug-Menue daran drehen kann - null
## heisst: leere See, gut zum Ausprobieren von Handelsrouten.
@export var max_ships: int = 2
## Entfernung, in der ein Segel auftaucht. Knapp innerhalb der Sichtweite des
## Gelaendes - es soll am Horizont erscheinen, nicht neben einem.
const SPAWN_DISTANCE: float = 1150.0
## Soweit muss es sich entfernen, um wieder zu verschwinden.
const DESPAWN_DISTANCE: float = 2600.0
## Sekunden zwischen zwei Versuchen, ein Segel zu setzen.
@export var spawn_interval: float = 30.0
## Und soviel Ruhe zu Beginn einer Fahrt.
const FIRST_SPAWN_DELAY: float = 15.0
## So oft wird ein Platz auf offener See gesucht, bevor aufgegeben wird.
const SPAWN_ATTEMPTS: int = 20
## Anteil Kriegsschiffe an allen Begegnungen. Der Rest sind Handelsschiffe -
## Beute muss haeufiger sein als Aerger, sonst lohnt Segeln nicht.
const WARSHIP_SHARE: float = 0.3

# --- Prisen ----------------------------------------------------------------
## Soweit muss man an ein gestrichenes Schiff heran, um es auszuraeumen.
const PRIZE_RANGE: float = 110.0
## Beruechtigtheit je Prise. Sie macht spaetere Gegner muerber - siehe
## [method Gunnery.will_strike].
const PRIZE_NOTORIETY: int = 3
## Ansehensverlust bei der bestohlenen Nation.
## TODO(M6): Bis dahin hat der Ruf noch keine sichtbare Folge.
const PRIZE_REPUTATION: int = -8

## Wieviel der Sieger dem Spieler abnimmt, wenn dessen Schiff aufgibt.
const DEFEAT_GOLD_SHARE: float = 0.34
const DEFEAT_CARGO_SHARE: float = 0.5
## Mit soviel Rumpf humpelt der Spieler danach weiter. Ein Gefecht zu
## verlieren beendet keinen Lauf - es verteuert ihn (Design-Pillar
## "Konsequenz statt Bestrafung").
const DEFEAT_HULL_SHARE: float = 0.25
## Sekunden, in denen der Sieger den Geschlagenen in Ruhe laesst.
##
## Ohne das faengt der Gegner sofort wieder an: Ein Viertel Rumpf ist in
## zwei Breitseiten weg, und der Spieler wird im Kreis ausgeraubt, bis er
## nichts mehr hat. Eine Niederlage soll etwas kosten, nicht alles.
const TRUCE_SECONDS: float = 60.0

## Sekunden, die ein Wrack beim Sinken braucht.
const SINK_SECONDS: float = 6.0
## Und wie tief es dabei geht.
const SINK_DEPTH: float = 14.0

var player: Ship

## Alle fremden Schiffe in der Welt.
var _ships: Array[Ship] = []
## Eigener Wuerfel: Das Gefecht darf den Weltgenerator nicht durcheinander-
## bringen, dessen Zahlenfolge am Seed haengt. Oeffentlich, damit Tests und
## Sichtpruefungen ein Gefecht wiederholbar machen koennen.
var rng := RandomNumberGenerator.new()
var _spawn_timer: float = FIRST_SPAWN_DELAY
## Restliche Waffenruhe nach einer Niederlage, in Sekunden.
var _truce: float = 0.0


func setup(player_ship: Ship) -> void:
	player = player_ship
	rng.randomize()
	player.fire_requested.connect(_on_fire_requested.bind(player))
	player.sunk.connect(_on_player_defeated)


func _physics_process(delta: float) -> void:
	if player == null or not WorldData.generated:
		return
	_truce = maxf(_truce - delta, 0.0)
	_forget_freed_ships()
	_update_targets()
	_update_spawning(delta)


## Alle fremden Schiffe, die noch fahren - fuer Anzeige und Tests.
func ships() -> Array[Ship]:
	return _ships


## Das naechste fremde Schiff, oder null.
##
## Eine Stelle fuer alle, die es wissen wollen: das HUD fuer die Zielanzeige,
## die Kamera fuers Einrahmen, das Feuerleitwesen fuer die Breitseite.
func nearest_enemy(max_distance: float = INF) -> Ship:
	var best: Ship = null
	var best_distance := max_distance
	for ship: Ship in _ships:
		if ship.finished:
			continue
		var distance := _range_to_player(ship)
		if distance < best_distance:
			best_distance = distance
			best = ship
	return best


# --- Begegnungen -----------------------------------------------------------

func _update_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_interval
	_despawn_distant()
	if _ships.size() < max_ships:
		_spawn()


func _despawn_distant() -> void:
	for ship: Ship in _ships.duplicate():
		# Wer schon Schuesse gewechselt hat, verschwindet nicht einfach.
		var captain := _captain_of(ship)
		if captain != null and captain.provoked:
			continue
		if _range_to_player(ship) > DESPAWN_DISTANCE:
			_ships.erase(ship)
			ship.queue_free()


func _spawn() -> void:
	var spot := _open_water_near(player.plan_position())
	if not spot.is_finite():
		return

	var warship := rng.randf() < WARSHIP_SHARE
	var ship_class: ShipClass = load(
		"res://resources/ships/patrol_sloop.tres" if warship
		else "res://resources/ships/merchant_brig.tres"
	)
	if ship_class == null:
		push_error("NavalCombat: Schiffsklasse nicht ladbar")
		return

	var packed: PackedScene = load(SHIP_SCENE)
	var ship: Ship = packed.instantiate()
	ship.player_controlled = false
	add_child(ship)
	ship.apply_class(ship_class)

	# Heimatnation von der naechsten Stadt - ein spanisches Segel faehrt vor
	# einer spanischen Kueste, nicht irgendwo.
	var home := WorldData.nearest_town(spot)
	var nation := WorldData.get_nation(home.nation_id) if home != null else null
	ship.nation_id = home.nation_id if home != null else -1
	ship.ship_name = _pick_ship_name(nation)

	ship.global_position = Vector3(spot.x, 0.0, spot.y)
	# Auf die offene See hinaus, nicht auf die Kueste zu.
	ship.set_heading(SailingMath.bearing(spot, player.plan_position()) + PI)
	_load_prize(ship, home)

	adopt(ship)
	EventBus.ship_spawned.emit(ship)
	EventBus.sail_sighted.emit(ship.ship_name, ship.nation_id, ship.warship)


## Nimmt ein bestehendes Schiff als Gegner in die Welt auf: Kapitaen dazu,
## Signale verdrahten, mitzaehlen.
##
## Getrennt von [method _spawn], weil nicht jeder Gegner aus dem Zufall kommt -
## eine Sichtpruefung stellt sich ihren auf den Meter genau hin, und spaeter
## setzt ein Auftrag ihn absichtlich (M6).
func adopt(ship: Ship) -> void:
	if _ships.has(ship):
		return
	var nation := WorldData.get_nation(ship.nation_id)
	if nation != null:
		_add_flag(ship, nation.color)
	if _captain_of(ship) == null:
		var captain := ShipAI.new()
		captain.setup(ship)
		ship.add_child(captain)

	ship.fire_requested.connect(_on_fire_requested.bind(ship))
	ship.sunk.connect(_on_ship_sunk.bind(ship))
	ship.damaged.connect(_on_ship_damaged.bind(ship))
	_ships.append(ship)


## Setzt sofort ein Segel, ohne auf den Takt zu warten.
##
## Fuers Debug-Menue: Auf ein zufaelliges Treffen zu warten kostet beim
## Ausprobieren eines Gefechts jedes Mal eine halbe Minute.
func spawn_now() -> bool:
	if player == null or not WorldData.generated:
		return false
	var before := _ships.size()
	_spawn()
	return _ships.size() > before


## Sucht einen Platz auf tiefem Wasser rund um den Spieler.
##
## Gibt [constant Vector2.INF] zurueck, wenn keiner zu finden war - in einer
## engen Bucht ist das der Normalfall und kein Fehler.
func _open_water_near(here: Vector2) -> Vector2:
	for attempt in SPAWN_ATTEMPTS:
		var angle := rng.randf_range(-PI, PI)
		var spot := here + SailingMath.direction(angle) * SPAWN_DISTANCE
		if absf(spot.x) > WorldData.WORLD_SIZE * 0.5 or absf(spot.y) > WorldData.WORLD_SIZE * 0.5:
			continue
		if WorldData.is_navigable(spot.x, spot.y):
			return spot
	return Vector2.INF


func _pick_ship_name(nation: NationData) -> String:
	if nation == null or nation.ship_names.is_empty():
		return "Namenlos"
	return nation.ship_names[rng.randi() % nation.ship_names.size()]


## Gibt einem Handelsschiff eine Ladung, die zu seiner Heimat passt.
##
## Was eine Stadt erzeugt, faehrt aus ihrem Hafen heraus. Damit ist die Beute
## nicht beliebig, sondern eine Aussage ueber die Gegend - und ein Hinweis
## darauf, wo sich das Kapern lohnt.
func _load_prize(ship: Ship, home: TownData) -> void:
	var tier := home.size_tier if home != null else 0
	ship.gold = rng.randi_range(90, 260) * (tier + 1)
	if ship.warship:
		# Ein Kriegsschiff faehrt Sold und Vorrat, keine Handelsware.
		ship.gold *= 2
		return

	var goods: Array[StringName] = []
	if home != null and not home.production.is_empty():
		for cargo_id: StringName in home.production:
			goods.append(cargo_id)
	else:
		goods = CargoRegistry.ids()

	var capacity := ship.ship_class.cargo_capacity if ship.ship_class != null else 40
	var remaining := int(float(capacity) * rng.randf_range(0.45, 0.9))
	for cargo_id: StringName in goods:
		if remaining <= 0:
			break
		var type := CargoRegistry.get_cargo(cargo_id)
		if type == null:
			continue
		var units := int(remaining / maxi(goods.size(), 1) / maxi(type.unit_size, 1))
		if units > 0:
			ship.cargo[cargo_id] = units
			remaining -= units * type.unit_size


## Eine Flagge im Masttopp. Von See aus die einzige Auskunft darueber, wem das
## Segel gehoert - dieselbe Sprache wie die Fahnenstangen der Staedte.
func _add_flag(ship: Ship, color: Color) -> void:
	var mast := ship.get_node_or_null("Hull/Mast")
	if mast == null:
		return

	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, 1.3, 0.08)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.95

	var flag := MeshInstance3D.new()
	flag.name = "Flag"
	flag.mesh = mesh
	flag.material_override = material
	flag.position = Vector3(1.3, 7.4, 0.0)
	mast.add_child(flag)


func _forget_freed_ships() -> void:
	var alive: Array[Ship] = []
	for ship: Ship in _ships:
		if is_instance_valid(ship):
			alive.append(ship)
	_ships = alive


## Setzt jedem Kapitaen den Spieler als Ziel, solange er ihn sehen kann.
func _update_targets() -> void:
	for ship: Ship in _ships:
		var captain := _captain_of(ship)
		if captain == null:
			continue
		if _truce > 0.0:
			captain.target = null
			continue
		var distance := _range_to_player(ship)
		captain.target = player if distance <= ShipAI.ALERT_RANGE else null
		if distance <= ShipAI.PROVOKE_RANGE:
			captain.provoked = true


func _captain_of(ship: Ship) -> ShipAI:
	return ship.get_node_or_null("Kapitaen") as ShipAI


func _range_to_player(ship: Ship) -> float:
	return ship.plan_position().distance_to(player.plan_position())


# --- Breitseiten -----------------------------------------------------------

func _on_fire_requested(side: int, shooter: Ship) -> void:
	_muzzle_smoke(shooter, side)

	var target := _opponent_of(shooter)
	if target == null or target.finished:
		return

	var distance := shooter.plan_position().distance_to(target.plan_position())
	var bearing := SailingMath.bearing(shooter.plan_position(), target.plan_position())
	var quality := Gunnery.bearing_quality(shooter.heading(), bearing, side)
	var shots := Gunnery.resolve_salvo(
		rng, shooter.cannons_per_side, distance, quality, shooter.crew_fraction()
	)
	_launch_balls(shooter, side, target, shots)

	# Der Schaden faellt erst, wenn die Kugeln ankommen - sonst sinkt ein
	# Gegner, waehrend die Breitseite noch in der Luft steht.
	#
	# Als Signal und nicht als await: Legt der Spieler an, waehrend eine Salve
	# fliegt, verschwindet diese Szene mitsamt dem Gefecht. Eine Verbindung
	# loest sich dabei von selbst, eine wartende Funktion nicht.
	get_tree().create_timer(CannonBall.flight_time(distance)).timeout.connect(
		_apply.bind(shots, target, shooter), CONNECT_ONE_SHOT
	)


## Auf wen zielt dieser Schuetze? Es gibt in einem Gefecht immer nur den
## Spieler und die Fremden - eine Seeschlacht mit drei Parteien kommt erst
## mit den Nationen (M6).
func _opponent_of(shooter: Ship) -> Ship:
	if shooter != player:
		return player
	return nearest_enemy(Gunnery.MAX_RANGE)


func _apply(shots: Array[Shot], target: Ship, shooter: Ship) -> void:
	if not is_instance_valid(target) or not is_instance_valid(shooter):
		return
	var hits := 0
	for shot: Shot in shots:
		if not shot.hit:
			continue
		hits += 1
		target.take_hit(shot.zone, shot.damage)

	EventBus.broadside_landed.emit(shooter == player, hits, shots.size())
	if target != player:
		_check_strike(target)


## Gibt der Gegner auf? Geprueft nach der ganzen Breitseite, nicht nach jedem
## Treffer - ein Kapitaen entscheidet, wenn der Rauch sich legt.
func _check_strike(ship: Ship) -> void:
	if ship.struck or ship.finished:
		return
	var fear := float(GameState.notoriety) / 100.0
	if not Gunnery.will_strike(ship.hull_fraction(), ship.crew_fraction(), fear):
		return
	ship.strike()
	var captain := _captain_of(ship)
	if captain != null:
		captain.target = null
	EventBus.ship_struck.emit(ship.ship_name)


func _launch_balls(shooter: Ship, side: int, target: Ship, shots: Array[Shot]) -> void:
	var across := shooter.global_basis.x * float(side)
	var forward := -shooter.global_basis.z
	var muzzle := shooter.global_position + across * shooter.half_beam * 1.6 + Vector3.UP * 1.8
	var aim := target.global_position

	var flat := aim - muzzle
	flat.y = 0.0
	if flat.length_squared() < 1.0:
		return
	var to_target := flat.normalized()
	var sideways := Vector3(-to_target.z, 0.0, to_target.x)

	for i in shots.size():
		var shot: Shot = shots[i]
		# Die Rohre stehen ueber die Laenge des Schiffs verteilt, nicht an
		# einem Punkt - sonst sieht eine Breitseite aus wie ein Schuss.
		var offset := forward * (float(i) - float(shots.size() - 1) * 0.5) * 1.6
		var point := aim + sideways * shot.scatter.x + to_target * shot.scatter.y
		point.y = aim.y + 1.4 if shot.hit else 0.4

		var ball := CannonBall.new()
		add_child(ball)
		ball.launch(muzzle + offset, point, not shot.hit)


func _muzzle_smoke(shooter: Ship, side: int) -> void:
	var across := shooter.global_basis.x * float(side)
	var at := shooter.global_position + across * shooter.half_beam * 2.0 + Vector3.UP * 1.8
	CannonBall.puff(self, at, CannonBall.MUZZLE_RADIUS, Palette.SMOKE)


func _on_ship_damaged(_zone: int, _amount: int, ship: Ship) -> void:
	# Wer beschossen wird, nimmt den Spieler ernst - auch ein Handelsschiff.
	var captain := _captain_of(ship)
	if captain != null:
		captain.provoked = true


# --- Prisen ----------------------------------------------------------------

## Das gestrichene Schiff in Reichweite, oder null. Der Segelmodus fragt hier
## nach, um die Aufforderung einzublenden.
func prize_in_reach() -> Ship:
	for ship: Ship in _ships:
		if ship.struck and not ship.finished and _range_to_player(ship) <= PRIZE_RANGE:
			return ship
	return null


## Raeumt ein gestrichenes Schiff aus.
##
## Gold passt immer, Ladung nur soweit der eigene Laderaum reicht. Was nicht
## hineinpasst, bleibt zurueck - ein voller Laderaum ist im Gefecht ein
## echter Nachteil.
func take_prize(ship: Ship) -> void:
	if ship == null or ship.finished:
		return

	GameState.add_gold(ship.gold)
	var units := 0
	for cargo_id: StringName in ship.cargo:
		var type := CargoRegistry.get_cargo(cargo_id)
		var unit_size := maxi(type.unit_size if type != null else 1, 1)
		var room := GameState.cargo_free() / unit_size
		var take := mini(int(ship.cargo[cargo_id]), room)
		if take > 0:
			GameState.add_cargo(cargo_id, take)
			units += take

	GameState.add_notoriety(PRIZE_NOTORIETY + (1 if ship.warship else 0))
	if ship.nation_id >= 0:
		GameState.change_reputation(ship.nation_id, PRIZE_REPUTATION)

	EventBus.prize_taken.emit(ship.ship_name, ship.gold, units)
	ship.gold = 0
	ship.cargo.clear()
	_release(ship)


## Das ausgeraeumte Schiff treibt davon. Es zu behalten kommt mit M5.
func _release(ship: Ship) -> void:
	ship.finished = true
	_ships.erase(ship)
	var tween := ship.create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(ship.queue_free)


func _on_ship_sunk(ship: Ship) -> void:
	EventBus.ship_sunk.emit(ship)
	_ships.erase(ship)

	# Ladung und Kasse gehen mit unter. Wer zu lange auf den Rumpf schiesst,
	# versenkt seine eigene Beute - das ist der Preis fuer den kurzen Weg.
	var captain := _captain_of(ship)
	if captain != null:
		captain.queue_free()

	var tween := ship.create_tween()
	tween.tween_property(ship, "position:y", ship.position.y - SINK_DEPTH, SINK_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ship, "rotation:z", deg_to_rad(40.0), SINK_SECONDS)
	tween.tween_callback(ship.queue_free)


## Das eigene Schiff ist gefechtsunfaehig.
##
## Kein Spielende: Der Gegner nimmt Gold und Ladung, laesst den Rumpf notdurftig
## ueber Wasser und bricht ab. Der Lauf geht weiter, nur aermer.
func _on_player_defeated() -> void:
	var lost_gold := int(float(GameState.gold) * DEFEAT_GOLD_SHARE)
	GameState.add_gold(-lost_gold)

	var lost_units := 0
	for cargo_id: StringName in GameState.cargo.keys():
		var taken := int(float(GameState.cargo_of(cargo_id)) * DEFEAT_CARGO_SHARE)
		if taken > 0:
			GameState.add_cargo(cargo_id, -taken)
			lost_units += taken

	player.finished = false
	player.set_condition(
		maxi(int(float(player.max_hull) * DEFEAT_HULL_SHARE), 1),
		player.sails,
		player.crew
	)

	# Der Sieger bricht ab und laesst das Wrack ziehen.
	_truce = TRUCE_SECONDS
	for ship: Ship in _ships:
		var captain := _captain_of(ship)
		if captain != null:
			captain.target = null
			captain.provoked = false

	EventBus.player_struck.emit(lost_gold, lost_units)
