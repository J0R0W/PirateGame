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
##   4. Entern - der zweite Weg zur Prise, mit Leuten statt mit Pulver
##   5. Benannte Gegner - wer nicht aus dem Zufall kommt, sondern aus der Politik
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
##
## Groesser als das, was ein Kaperbrief dafuer gutschreibt
## ([constant LetterOfMarque.PRIZE_REWARD]): Kapern bleibt unterm Strich ein
## Verlust an Ansehen. Der Brief verschiebt nur, wo er anfaellt.
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

# --- Masse der Darstellung -------------------------------------------------
## Wie weit die Batterie aus der Mittschiffslinie steht, in halben Rumpfbreiten.
const BATTERY_OFFSET: float = 1.6
## Muendungshoehe ueber der Wasserlinie, in Metern.
const MUZZLE_HEIGHT: float = 1.8
## Auf dieser Hoehe schlaegt ein Treffer in die Bordwand.
const HIT_HEIGHT: float = 1.4
## Und so tief steht die Fontaene eines Fehlschusses.
const SPLASH_LEVEL: float = 0.4

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
## Restliche Zeit, bis die Enterhaken wieder klar sind.
var _grapple_recovery: float = 0.0

## Der benannte Gegner auf See, oder null - siehe [Adversary].
##
## Hoechstens einer gleichzeitig, und er zaehlt nicht gegen [member max_ships]:
## Ein Auftragsziel oder ein Kopfgeldjaeger soll nicht ausbleiben, weil gerade
## zwei Frachter in der Naehe sind.
var _named: Ship = null
## Ist der Benannte ein Jaeger? Entscheidet, ob nach ihm Ruhe einkehrt.
var _named_hunts: bool = false
## Ruhe nach einem erledigten Kopfgeldjaeger, in Sekunden.
var _bounty_rest: float = 0.0


func setup(player_ship: Ship) -> void:
	player = player_ship
	rng.randomize()
	player.fire_requested.connect(_on_fire_requested.bind(player))
	player.sunk.connect(_on_player_defeated)


func _physics_process(delta: float) -> void:
	if player == null or not WorldData.generated:
		return
	_truce = maxf(_truce - delta, 0.0)
	_grapple_recovery = maxf(_grapple_recovery - delta, 0.0)
	_bounty_rest = maxf(_bounty_rest - delta, 0.0)
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
	# Der Benannte hat Vorrang: Wer einen Auftrag traegt oder gesucht wird, soll
	# nicht warten, bis der Zufall gerade Platz hat.
	if _place_named():
		return
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

	var ship := _instantiate(ship_class)

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


## Setzt ein Schiff einer Klasse in die Szene, ohne es schon zu bestuecken.
##
## Getrennt vom Zufallssegel, seit es einen zweiten Weg auf die See gibt: Ein
## benannter Gegner bekommt Flagge, Namen und Kasse aus seinem Steckbrief und
## nicht aus der naechsten Kueste.
func _instantiate(ship_class: ShipClass) -> Ship:
	var packed: PackedScene = load(SHIP_SCENE)
	var ship: Ship = packed.instantiate()
	ship.player_controlled = false
	add_child(ship)
	ship.apply_class(ship_class)
	return ship


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
##
## Seit M6 haengt das am Ruf. Vorher griff jede Patrouille jeden an - eine
## frisch angefangene Kampagne wurde vom ersten spanischen Segel beschossen,
## ohne dass Spanien einen Grund gehabt haette. Jetzt jagt nur, wer einen Grund
## hat: ein feindliches Verhaeltnis, oder ein misstrauisches bei einer Nation,
## die schnell zur Sache kommt (NationData.aggression).
##
## Wer beschossen wurde, jagt in jedem Fall - das entscheidet _on_ship_damaged
## ueber [member ShipAI.provoked] und ist unabhaengig vom Ruf.
func _update_targets() -> void:
	for ship: Ship in _ships:
		var captain := _captain_of(ship)
		if captain == null:
			continue
		if _truce > 0.0:
			captain.target = null
			continue

		var distance := _range_to_player(ship)
		var level := GameState.standing_with(ship.nation_id)
		# Blosse Naehe macht nur den misstrauisch, der es ohnehin schon ist.
		# Vorher wurde jedes Schiff im Umkreis von 300 Metern dauerhaft
		# provoziert, auch das einer befreundeten Nation.
		if distance <= ShipAI.PROVOKE_RANGE and Standing.wary_of_player(level):
			captain.provoked = true

		captain.target = player if distance <= ShipAI.ALERT_RANGE else null
		captain.hostile = captain.provoked or hunts_player(ship)


## Jagt dieses Schiff den Spieler von sich aus?
##
## Nur Kriegsschiffe jagen - ein Handelsschiff flieht auch dann, wenn seine
## Nation den Spieler sucht. Oeffentlich, damit die Anzeige dieselbe Frage
## stellen kann wie die KI und nicht ihre eigene Antwort erfindet.
func hunts_player(ship: Ship) -> bool:
	if not ship.warship:
		return false
	var nation := WorldData.get_nation(ship.nation_id)
	return Standing.hunts_player(
		GameState.standing_with(ship.nation_id),
		nation.aggression if nation != null else 0.5
	)


func _captain_of(ship: Ship) -> ShipAI:
	return ship.get_node_or_null("Kapitaen") as ShipAI


func _range_to_player(ship: Ship) -> float:
	return ship.plan_position().distance_to(player.plan_position())


# --- Benannte Gegner -------------------------------------------------------
#
# Der Auftrag des Gouverneurs und der Kopfgeldjaeger sind dieselbe Mechanik von
# zwei Seiten: In beiden Faellen steht fest, wer da kommt, bevor er kommt. Der
# Unterschied ist nur, wer ihn benannt hat - und ob er den Spieler sucht.

## Setzt den benannten Gegner, wenn einer faellig ist.
##
## Gibt true zurueck, wenn dieser Takt damit verbraucht ist: Ein Auftragsziel
## und ein zufaelliges Segel im selben Augenblick waeren zwei neue Schiffe auf
## einen Schlag.
func _place_named() -> bool:
	# Verschwunden, versenkt oder als Prise weg - dann ist der Platz wieder frei.
	if _named != null and (not is_instance_valid(_named) or not _ships.has(_named)):
		_named = null
		_named_hunts = false
	if _named != null or player == null:
		return false

	var who := _named_due()
	if who == null:
		return false
	var ship_class: ShipClass = load(who.ship_class_path)
	if ship_class == null:
		push_error("NavalCombat: Schiffsklasse nicht ladbar: %s" % who.ship_class_path)
		return false
	var spot := _open_water_near(player.plan_position())
	if not spot.is_finite():
		return false

	var ship := _instantiate(ship_class)
	ship.nation_id = who.nation_id
	ship.ship_name = who.ship_name
	ship.captain_name = who.captain_name
	ship.global_position = Vector3(spot.x, 0.0, spot.y)
	# Ein Jaeger dreht sofort bei, ein Auftragsziel faehrt seiner Wege hinaus.
	ship.set_heading(SailingMath.bearing(spot, player.plan_position())
		+ (0.0 if who.hunts else PI))

	if who.hunts:
		# Sein Vorschuss ist das eigene Kopfgeld: Wer teuer ausgeschrieben ist,
		# bekommt einen teuer bezahlten Jaeger - und damit die beste Prise auf
		# See ausgerechnet von dem Mann, den er am wenigsten treffen will.
		ship.gold = Bounty.purse(GameState.notoriety)
	else:
		_load_prize(ship, WorldData.nearest_town(spot))

	adopt(ship)
	_named = ship
	_named_hunts = who.hunts
	# Ein Jaeger faengt gereizt an. Ohne das faehrt er vorbei, bis der Ruf
	# seiner Krone ihn zufaellig doch noch scharf macht - dabei ist er genau
	# deswegen ausgelaufen.
	if who.hunts:
		var captain := _captain_of(ship)
		if captain != null:
			captain.provoked = true

	EventBus.ship_spawned.emit(ship)
	EventBus.named_captain_sighted.emit(
		who.captain_name, who.ship_name, who.nation_id, who.hunts
	)
	return true


## Wer als Naechstes benannt auf See gehoert, oder null.
##
## Der Auftrag geht vor: Wer einen angenommen hat, soll sein Ziel finden, auch
## wenn ihm gleichzeitig jemand nachgestellt wird. Sonst kaeme der Jaeger
## dauernd dazwischen und die Frist liefe ab.
##
## Aber nur in seinem Revier. Bis hierher wurde das Auftragsziel gesetzt, wo
## auch immer der Spieler gerade fuhr - man konnte einen Auftrag nicht suchen,
## nur abwarten. Jetzt kreuzt der Gesuchte vor einem bestimmten Hafen (siehe
## [member Commission.waters_town_id]), und wo der liegt, sagt der Wirt.
## Ausserhalb bleibt der Platz frei, und der Kopfgeldjaeger rueckt nach.
func _named_due() -> Adversary:
	var order := GameState.commission
	if order != null and not order.done and order.target != null and _in_waters(order):
		return order.target
	return _bounty_due()


## Faehrt der Spieler gerade in den Gewaessern des Gesuchten?
##
## Ein Auftrag ohne festgelegtes Revier gilt ueberall - so kommen Spielstaende
## aus der Zeit davor durch, und so fahren Auftraege, die ausserhalb eines
## Hafens angenommen wurden.
func _in_waters(order: Commission) -> bool:
	var waters := WorldData.get_town(order.waters_town_id)
	if waters == null:
		return true
	return Commission.in_waters(player.plan_position(), waters.position)


## Der Kopfgeldjaeger, den gerade eine Krone schickt, oder null.
func _bounty_due() -> Adversary:
	if _bounty_rest > 0.0:
		return null
	for nation: NationData in WorldData.nations:
		if Bounty.due(GameState.notoriety, GameState.standing_with(nation.id)):
			return Bounty.hunter(rng, nation, GameState.notoriety)
	return null


## Verbucht einen erledigten Gegner beim Gouverneur.
##
## Eine Stelle fuer beide Wege: aufgebracht ([method take_prize]) und versenkt
## ([method _on_ship_sunk]). Der Gouverneur wollte den Mann von der See haben,
## und beides bringt ihn dorthin.
func _settle_named(ship: Ship) -> void:
	if ship.captain_name.is_empty():
		return
	GameState.commission_target_defeated(ship.captain_name, ship.nation_id)
	if ship != _named:
		return
	_named = null
	# Nach einem Jaeger ist eine Weile Ruhe - aber nur nach einem Jaeger. Ein
	# Auftragsziel darf den naechsten Verfolger nicht aufhalten.
	if _named_hunts:
		_bounty_rest = Bounty.REST_SECONDS
	_named_hunts = false


# --- Breitseiten -----------------------------------------------------------

func _on_fire_requested(side: int, shooter: Ship) -> void:
	_muzzle_smoke(shooter, side)

	var target := _opponent_of(shooter)
	if target == null or target.finished:
		return

	var muzzle := battery_centre(shooter, side)
	var shots := Gunnery.resolve_salvo(
		rng,
		shooter.cannons_per_side,
		muzzle,
		shooter.heading(),
		side,
		profile_of(target),
		shooter.readiness(),
		shooter.gun_traverse
	)
	_launch_balls(shooter, shots)

	# Der Schaden faellt erst, wenn die Kugeln ankommen - sonst sinkt ein
	# Gegner, waehrend die Breitseite noch in der Luft steht.
	#
	# Als Signal und nicht als await: Legt der Spieler an, waehrend eine Salve
	# fliegt, verschwindet diese Szene mitsamt dem Gefecht. Eine Verbindung
	# loest sich dabei von selbst, eine wartende Funktion nicht.
	var distance := muzzle.distance_to(target.plan_position())
	get_tree().create_timer(Gunnery.flight_time(distance)).timeout.connect(
		_apply.bind(shots, target, shooter), CONNECT_ONE_SHOT
	)


## Der Mittelpunkt einer Batterie in der Weltebene.
##
## Nicht der Schiffsmittelpunkt: Die Rohre stehen an der Bordwand, und auf 60
## Metern ist das ein sichtbarer Unterschied in der Schussrichtung.
static func battery_centre(shooter: Ship, side: int) -> Vector2:
	var across := SailingMath.direction(Gunnery.abeam(shooter.heading(), side))
	return shooter.plan_position() + across * shooter.half_beam * BATTERY_OFFSET


## Alles, was die Ballistik ueber ein Ziel wissen muss.
##
## Die Fahrt kommt aus [member CharacterBody3D.velocity] und nicht aus Kurs mal
## Knoten: Ein aufgelaufenes oder beidrehendes Schiff steht dann auch wirklich
## still, statt dass die Mannschaft auf eine Fahrt vorhaelt, die es nicht mehr
## macht.
static func profile_of(target: Ship) -> TargetProfile:
	return TargetProfile.make(
		target.plan_position(),
		Vector2(target.velocity.x, target.velocity.z),
		target.heading(),
		target.half_length,
		target.half_beam
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


## Schickt die Kugeln los.
##
## Hier wird nichts mehr entschieden: Jede Kugel hat ihre Muendung und ihren
## Aufschlagpunkt aus der Ballistik, und die Darstellung fliegt genau dorthin.
## Das ist der Kern der Umstellung - ein Fehlschuss geht jetzt sichtbar vor
## oder hinter dem Gegner nieder, statt irgendwo daneben zu platschen.
func _launch_balls(shooter: Ship, shots: Array[Shot]) -> void:
	var deck := shooter.global_position.y + MUZZLE_HEIGHT
	for shot: Shot in shots:
		var from := Vector3(shot.origin.x, deck, shot.origin.y)
		# Ein Treffer schlaegt in die Bordwand, ein Fehlschuss ins Wasser.
		var to := Vector3(
			shot.impact.x,
			shooter.global_position.y + HIT_HEIGHT if shot.hit else SPLASH_LEVEL,
			shot.impact.y
		)
		var ball := CannonBall.new()
		add_child(ball)
		ball.launch(from, to, not shot.hit)


func _muzzle_smoke(shooter: Ship, side: int) -> void:
	var at := battery_centre(shooter, side)
	CannonBall.puff(
		self,
		Vector3(at.x, shooter.global_position.y + MUZZLE_HEIGHT, at.y),
		CannonBall.MUZZLE_RADIUS,
		Palette.SMOKE
	)


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
	EventBus.prize_taken.emit(ship.ship_name, ship.nation_id, ship.gold, units)

	# Der Ruf faellt erst nach der Meldung ueber die Beute, nicht davor: Beide
	# schreiben auf dieselbe Zeile im HUD, und stehen bleiben soll die Folge,
	# nicht die Beute. Wer unter einem Kaperbrief den eigenen Auftraggeber
	# aufbringt, ist ihn los - das darf nicht hinter "340 Gold" verschwinden.
	if ship.nation_id >= 0:
		GameState.change_reputation(ship.nation_id, PRIZE_REPUTATION)
		GameState.settle_letter_prize(ship.nation_id)
	_settle_named(ship)

	ship.gold = 0
	ship.cargo.clear()
	_release(ship)


# --- Entern ----------------------------------------------------------------

## Der Gegner, den man von hier aus stuermen koennte, oder null.
##
## Anders als bei einer Prise geht es hier um ein Schiff, das noch kaempft.
## Die Sperre nach einem abgeschlagenen Sturm zaehlt mit: Solange die Haken
## nicht klar sind, liegt zwar jemand laengsseit, aber es geht niemand hinueber.
func boarding_in_reach() -> Ship:
	if _grapple_recovery > 0.0 or player == null or player.struck or player.finished:
		return null
	for ship: Ship in _ships:
		if Boarding.can_board(
			_range_to_player(ship), player.crew, ship.struck, ship.finished
		):
			return ship
	return null


## Wie lange die Enterhaken noch unklar sind, in Sekunden. Fuer die Anzeige.
func grapple_recovery() -> float:
	return _grapple_recovery


## Setzt ueber und ficht das Deckgefecht aus.
##
## Der Sieg bringt keine Beute, sondern die gestrichene Flagge: Ausgeraeumt
## wird danach mit [method take_prize], genau wie bei einem Gegner, den man
## zusammengeschossen hat. Das haelt die beiden Wege getrennt - der eine kostet
## Zeit und Pulver, der andere Leute - und den Ertrag gleich.
func board(ship: Ship) -> Boarding.Result:
	if ship == null or player == null:
		return null
	if not Boarding.can_board(
		_range_to_player(ship), player.crew, ship.struck, ship.finished
	):
		return null

	var outcome := Boarding.resolve(
		rng,
		player.crew,
		float(GameState.notoriety) / 100.0,
		ship.crew,
		ship.hull_fraction()
	)

	# Verluste als Treffer in die Mannschaft: So laufen sie durch dieselben
	# Signale wie Kartaetschen, und GameState wird auf dem gewohnten Weg
	# fortgeschrieben (Ship.condition_changed).
	player.take_hit(Gunnery.Zone.CREW, outcome.attacker_losses)
	ship.take_hit(Gunnery.Zone.CREW, outcome.defender_losses)

	_grapple_recovery = Boarding.RECOVERY_SECONDS
	if outcome.won:
		ship.strike()
		EventBus.ship_boarded.emit(ship)

	EventBus.boarding_resolved.emit(
		ship.ship_name, outcome.won, outcome.attacker_losses, outcome.defender_losses
	)
	return outcome


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
	# Auch ein versenkter Benannter ist erledigt. Sonst waere die beste
	# Breitseite die schlechteste Art, einen Auftrag zu erfuellen.
	_settle_named(ship)

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
