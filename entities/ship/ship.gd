## Ein Segelschiff - der Spieler und jedes KI-Schiff benutzen dieselbe Klasse.
##
## Gesteuert wird ausschliesslich Ruder und Segelstellung, nie direkt die
## Geschwindigkeit. Die Fahrt ergibt sich aus dem Winkel zum Wind.
##
## Ein Schiff kennt seinen eigenen Zustand - Rumpf, Takelage, Mannschaft - aber
## weder Gold noch Ladung des Spielers und niemanden ausser sich selbst. Wer
## auf wen schiesst, entscheidet [NavalCombat].
##
## Waehrend einer Szene ist dieses Objekt die Wahrheit ueber das Schiff des
## Spielers; zwischen zwei Szenen ist es GameState. Der Segelmodus liest beim
## Start von dort und schreibt bei jeder Aenderung dorthin zurueck.
class_name Ship
extends CharacterBody3D

signal sail_setting_changed(step: int)
## Aufgelaufen. Die Fahrt im Moment des Aufpralls entscheidet ueber den Schaden -
## das Schiff selbst kennt weder Rumpfzustand noch Gold, das gehoert dem Modus.
signal ran_aground(impact_speed: float)

## Eine Breitseite soll fallen. Ob und worauf, entscheidet [NavalCombat] - das
## Schiff weiss nicht, wer sonst noch auf der See ist.
signal fire_requested(side: int)
signal damaged(zone: int, amount: int)
## Rumpf, Takelage oder Mannschaft haben sich geaendert - aus welchem Grund
## auch immer. Der Segelmodus schreibt daraufhin GameState fort.
signal condition_changed(new_hull: int, new_sails: int, new_crew: int)
## Die Flagge ist gestrichen. Das Schiff faehrt nicht mehr und laesst sich
## als Prise nehmen.
signal struck_colours()
signal sunk()

@export_group("Fahrverhalten")
## Knoten bei idealem Wind und voller Besegelung.
@export var base_speed: float = 12.0
## Grad pro Sekunde bei voller Fahrt.
@export var turn_rate_deg: float = 34.0
## Wie traege die Fahrt auf Segelaenderungen reagiert, in Sekunden.
@export var speed_inertia: float = 4.5
## Wie traege das Ruder anspricht, in Sekunden.
@export var turn_inertia: float = 1.2
## Wieviel Fahrt noetig ist, um ueberhaupt zu wenden. Unterhalb treibt das
## Schiff nur noch.
@export var min_steerage: float = 0.12

@export_group("Gefecht")
## Rohre je Breitseite.
@export var cannons_per_side: int = 3
## Rohre insgesamt. Beide Batterien laden gleichzeitig, also braucht auch jede
## ihre eigene Bedienung - siehe [method Gunnery.readiness].
@export var cannon_slots: int = 6
## Schwenkbereich der Rohre um querab, in Grad nach jeder Seite.
@export var gun_traverse: float = Gunnery.TRAVERSE

@export_group("Steuerung")
## Nimmt dieses Schiff Tastatureingaben entgegen?
@export var player_controlled: bool = true

## Aktuelle Fahrt in Knoten.
var speed: float = 0.0
## Faktor auf die Hoechstfahrt. Nur fuers Debug-Menue - die Schiffsklasse
## bleibt unberuehrt, damit die .tres-Datei die Wahrheit bleibt.
var speed_multiplier: float = 1.0
## Stufe aus SailingMath.SAIL_STEPS.
var sail_step: int = 2
## Aktuelle Ruderlage, -1.0 bis 1.0.
var helm: float = 0.0
## Sitzt das Schiff auf Grund?
var aground: bool = false

# --- Steuerbefehle fuer Schiffe ohne Spieler -------------------------------
#
# Die KI schreibt hier hinein statt Kraefte zu setzen. Dadurch faehrt ein
# KI-Schiff durch genau dieselbe Physik wie der Spieler und kann sich nicht
# gegen den Wind bewegen, nur weil es das gerne wuerde.
var helm_command: float = 0.0
var sail_command: int = 3

# --- Zustand ---------------------------------------------------------------
var ship_class: ShipClass = null
var ship_name: String = "Namenlos"
## Wer es fuehrt - aber nur bei benannten Gegnern (siehe [Adversary]). Leer
## heisst: irgendein Kapitaen, wie bei jedem zufaellig gesetzten Segel.
##
## Steht hier und nicht in einem eigenen Node am Schiff, weil es die einzige
## Auskunft ist, ueber die ein Auftrag sein Ziel wiedererkennt - und die muss
## jeder haben, der das Schiff in der Hand hat.
var captain_name: String = ""
## Nation dieses Schiffs, -1 fuer Piraten und den Spieler.
var nation_id: int = -1
## Kriegsschiffe suchen das Gefecht, Handelsschiffe fliehen davor.
var warship: bool = false

var max_hull: int = 100
var hull: int = 100
var max_sails: int = 100
var sails: int = 100
var max_crew: int = 40
var crew: int = 20
## Soviele Leute haelt das Schiff ueberhaupt in Fahrt. Erst was darueber
## hinausgeht, bedient die Geschuetze.
var min_crew: int = 8

## Flagge gestrichen - das Schiff ergibt sich und wartet auf den Prisenkommando.
var struck: bool = false
## Bereits gesunken oder als Prise genommen? Verhindert doppelte Beute.
var finished: bool = false

## Ladung und Kasse - nur bei KI-Schiffen gefuellt, sie sind die Beute.
## Beim Spieler stehen beide in GameState.
var cargo: Dictionary = {}
var gold: int = 0

## Rumpfmasse fuer das Abtasten der Wellen, in Metern. Groessere Schiffe
## bekommen sie ueber [method apply_class] hochskaliert.
const BASE_HALF_LENGTH: float = 3.6
const BASE_HALF_BEAM: float = 1.3
var half_length: float = BASE_HALF_LENGTH
var half_beam: float = BASE_HALF_BEAM

## Ein 8-Meter-Rumpf folgt der See gedaempft, nicht eins zu eins.
const PITCH_DAMPING: float = 0.55
const ROLL_DAMPING: float = 0.7
## Kraengung bei vollem Ruder.
const HEEL_DEGREES: float = 7.0

## Wie schnell ein gestrichenes Schiff aufstoppt, in Sekunden.
const STRIKE_STOP_INERTIA: float = 3.0

## Restliche Nachladezeit je Seite, Index 0 = Backbord, 1 = Steuerbord.
var _reload: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])

## Gruppe, in der ein Modell seine Segel anmeldet.
##
## Frueher stand hier ein fester Pfad ($Hull/Mast/Sail), weil jede Klasse
## dasselbe Modell benutzte. Eine Karavelle hat drei Segel an drei Masten - der
## Pfad haette nur das erste gefunden und die anderen waeren beim Reffen stehen
## geblieben.
const SAIL_GROUP: StringName = &"sail"

## Alle Segel des gerade eingesetzten Modells.
var _sails: Array[Node3D] = []
## Alles, was zum Wind schwenkt: Rahen samt ihren Segeln.
var _rigs: Array[Rig] = []
## Die Flaggen des Schiffes. In der Regel eine, aber nichts verbietet zwei.
var _flags: Array[Flag] = []
## Die Laternen des Schiffes - und ob sie gerade brennen.
##
## Der Zustand steht hier und nicht nur in den Laternen, weil die Schwelle
## zwei Werte hat (siehe [method Skylight.lanterns_lit]): Ob angezuendet oder
## geloescht wird, haengt davon ab, was gerade ist.
var _lanterns: Array[Lantern] = []
var _lanterns_lit: bool = false
## Unter welcher Flagge zuletzt gefahren wurde - damit die Farbe nicht in jedem
## Bild neu gesetzt wird, sondern nur, wenn sich die Nation wirklich aendert.
var _flying: int = -2


func _ready() -> void:
	_collect_rigging()
	_update_sail_visual()


func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled:
		return
	if event.is_action_pressed("sails_more"):
		_set_sail_step(sail_step + 1)
	elif event.is_action_pressed("sails_less"):
		_set_sail_step(sail_step - 1)
	elif event.is_action_pressed("fire_port"):
		fire(Gunnery.PORT)
	elif event.is_action_pressed("fire_starboard"):
		fire(Gunnery.STARBOARD)


func _physics_process(delta: float) -> void:
	_cool_batteries(delta)

	var helm_input := helm_command
	if player_controlled:
		helm_input = Input.get_axis("helm_port", "helm_starboard")
	elif sail_step != sail_command:
		_set_sail_step(sail_command)

	# Ruder spricht traege an - kein sofortiges Einrasten.
	helm = SailingMath.approach(helm, helm_input, turn_inertia, delta)

	# Fahrt aus Wind, Kurs und Segelstellung.
	var goal := SailingMath.target_speed(
		base_speed * speed_multiplier,
		heading(),
		WorldData.wind_direction,
		WorldData.wind_strength,
		SailingMath.SAIL_STEPS[sail_step] * sail_health() * handling()
	)
	# Wer die Flagge gestrichen hat, faehrt nicht mehr - er dreht bei.
	if struck:
		speed = SailingMath.approach(speed, 0.0, STRIKE_STOP_INERTIA, delta)
	else:
		speed = SailingMath.approach(speed, goal, speed_inertia, delta)

	# Ohne Fahrt greift das Ruder nicht. Deshalb faehrt man sich in Irons fest.
	var steerage := clampf(speed / (base_speed * min_steerage), 0.0, 1.0)
	rotation.y -= helm * deg_to_rad(turn_rate_deg) * steerage * delta

	# Knoten in Meter pro Sekunde: 1 kn ~ 0.514 m/s.
	velocity = -global_basis.z * speed * 0.514
	_check_grounding(delta)
	move_and_slide()

	_apply_swell(delta)


## Rah und Flagge sind reine Anzeige und gehoeren deshalb ins Bild, nicht in
## die Physik.
##
## Das ist kein Schoenheitsfehler, sondern noetig: Ein Schiff mit abgeschalteter
## Physik - in einer Aufnahme, im Hafen, mit gestrichener Flagge - haette sonst
## eine Rah, die irgendwo steht, und eine Flagge, die in keine Richtung weht.
func _process(delta: float) -> void:
	_update_rigging(delta)
	_update_lanterns()


## Haelt das Schiff vor der Kueste an.
##
## Kein Kollisionsmesh: Die Hoehenfunktion beantwortet die Frage direkt und
## billiger, als ein Collider fuer jede Insel es koennte. Geprueft wird die
## Position des naechsten Schrittes, damit das Schiff nicht erst im Land landet.
func _check_grounding(delta: float) -> void:
	var next := global_position + velocity * delta
	if not WorldData.is_land(next.x, next.z):
		aground = false
		return

	if not aground:
		aground = true
		ran_aground.emit(speed)
	speed = 0.0
	velocity = Vector3.ZERO


## Kurs des Schiffs als Navigationswinkel: 0 = Nord, PI/2 = Ost.
##
## Godot dreht andersherum: Bei rotation.y = t zeigt der Bug nach
## (-sin t, -cos t), positive Rotation also nach WESTEN. Die Umrechnung steckt
## hier an einer Stelle, damit Kompass, Karte und Windanzeige denselben Winkel
## benutzen wie die Navigation. Siehe SailingMath fuer die Konvention.
func heading() -> float:
	return wrapf(-rotation.y, -PI, PI)


## Setzt den Kurs als Navigationswinkel.
func set_heading(navigation_angle: float) -> void:
	rotation.y = -navigation_angle


## Position in der Weltebene - fuer alles, was mit Peilungen rechnet.
func plan_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Kurs zum Wind, aufbereitet fuers HUD.
func point_of_sail() -> String:
	return SailingMath.point_of_sail(heading(), WorldData.wind_direction)


func efficiency() -> float:
	return SailingMath.sail_efficiency(heading(), WorldData.wind_direction)


func sail_name() -> String:
	return SailingMath.SAIL_NAMES[sail_step]


func _set_sail_step(step: int) -> void:
	var clamped := clampi(step, 0, SailingMath.SAIL_STEPS.size() - 1)
	if clamped == sail_step:
		return
	sail_step = clamped
	_update_sail_visual()
	sail_setting_changed.emit(sail_step)


## Das Segel zeigt die Stellung direkt an - gerefft ist es schmaler.
func _update_sail_visual() -> void:
	var amount := SailingMath.SAIL_STEPS[sail_step]
	for sail: Node3D in _sails:
		if sail == null:
			continue
		var tween := create_tween()
		tween.tween_property(sail, "scale", Vector3(1.0, maxf(amount, 0.06), 1.0), 0.4) \
			.set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property(sail, "visible", amount > 0.0, 0.0)


## Sammelt Segel, Rahen und Flaggen des gerade eingesetzten Modells ein.
##
## Segel ueber die Gruppe, Rahen und Flaggen ueber ihren Typ: Ein Modell darf
## seine Masten nennen, wie es will, und muss nur sagen, was was ist.
func _collect_rigging() -> void:
	_sails.clear()
	_rigs.clear()
	_flags.clear()
	_lanterns.clear()
	_lanterns_lit = false
	_flying = -2
	var body := get_node_or_null("Hull")
	if body == null:
		return
	for node: Node in body.find_children("*", "Node3D", true, false):
		if node.is_in_group(SAIL_GROUP):
			_sails.append(node as Node3D)
		if node is Rig:
			_rigs.append(node as Rig)
		elif node is Flag:
			_flags.append(node as Flag)
		elif node is Lantern:
			_lanterns.append(node as Lantern)


## Stellt Rahen und Flaggen zum Wind.
##
## Beides haengt am selben Wind, wird aber verschieden gerechnet: Die Rah steht
## zum Wind [i]relativ zum Schiff[/i] und dreht deshalb oertlich; die Flagge
## steht in einer Weltrichtung und weiss vom Kurs ihres Traegers nichts.
func _update_rigging(delta: float) -> void:
	var course := heading()
	for rig: Rig in _rigs:
		rig.aim(course, WorldData.wind_direction, delta)

	if _flags.is_empty():
		return
	if _flying != nation_id:
		_flying = nation_id
		var colour := _flag_colour()
		for flag: Flag in _flags:
			flag.raise(colour)
	for flag: Flag in _flags:
		flag.stream(WorldData.wind_direction, WorldData.wind_strength, delta)


## Laesst die Laternen anzuenden oder loeschen, je nach Sicht.
##
## Jedes Schiff fuer sich, ohne Befehl: Ein Kapitaen macht bei Nacht und im
## Regen Licht, das ist keine Entscheidung des Spielers. Die Entscheidung
## kommt spaeter - wenn der Ausguck die Sicht liest, wird ein Licht zu etwas,
## das einen verraet, und dann gibt es einen Grund, es zu loeschen.
func _update_lanterns() -> void:
	if _lanterns.is_empty():
		return
	var wanted := Skylight.lanterns_lit(WorldData.visibility(), _lanterns_lit)
	if wanted == _lanterns_lit:
		return
	_lanterns_lit = wanted
	for lantern: Lantern in _lanterns:
		lantern.set_lit(wanted)


## Brennen die Laternen?
func lanterns_lit() -> bool:
	return _lanterns_lit


## Unter welcher Farbe dieses Schiff faehrt.
##
## Aus der Nation, wenn es eine hat - sonst schwarz. Ein Schiff ohne Flagge
## gibt es nicht; wer keine Krone hinter sich hat, faehrt eben ohne eine.
func _flag_colour() -> Color:
	var nation: NationData = WorldData.get_nation(nation_id)
	return nation.color if nation != null else Palette.IRON


# --- Zustand ---------------------------------------------------------------

## Uebernimmt Fahrwerte, Zaehigkeit und Bewaffnung aus einer Schiffsklasse.
##
## Die .tres-Datei ist die Wahrheit, nicht die Szene: Sonst stuenden dieselben
## Werte zweimal da und die Werft wuerde ein anderes Schiff reparieren, als man
## steuert.
func apply_class(source: ShipClass) -> void:
	if source == null:
		return
	ship_class = source
	base_speed = source.base_speed
	turn_rate_deg = source.turn_rate_deg
	speed_inertia = source.speed_inertia
	turn_inertia = source.turn_inertia
	warship = source.warship

	max_hull = source.max_hull
	max_sails = source.max_sails
	max_crew = source.max_crew
	min_crew = source.min_crew
	hull = max_hull
	sails = max_sails
	crew = source.max_crew
	# Ein Schiff mit vier Rohren hat zwei je Seite. Ungerade Zahlen fallen
	# zugunsten des Spielers auf - eine halbe Kanone gibt es nicht.
	cannon_slots = source.cannon_slots
	cannons_per_side = maxi(1, int(ceil(float(source.cannon_slots) * 0.5)))
	gun_traverse = source.gun_traverse

	_install_model(source.model)
	_scale_hull(source.hull_scale)
	_measure_hull(source)


## Setzt das Modell einer Klasse ein, sofern sie eines mitbringt.
##
## Ohne eigenes Modell bleibt der Rumpf aus ship.tscn stehen - so faehrt jede
## Klasse, die noch keines hat, weiter wie bisher.
func _install_model(scene: PackedScene) -> void:
	if scene == null:
		return
	var body := scene.instantiate() as Node3D
	if body == null:
		return

	var old := get_node_or_null("Hull")
	if old != null:
		# queue_free() wirkt erst am Bildende. Bis dahin haengen zwei Knoten
		# namens "Hull" im Baum, und Godot taufte den neuen still in "Hull2" um -
		# danach findet get_node("Hull") den alten, leeren Rumpf. Also erst aus
		# dem Baum nehmen, dann freigeben.
		remove_child(old)
		old.queue_free()

	body.name = "Hull"
	add_child(body)
	# Ausdruecklich bauen statt auf _ready zu warten: Ob _ready schon gelaufen
	# ist, haengt davon ab, ob das Schiff im Moment des Einsetzens selbst schon
	# im Baum haengt - und danach richtet sich, ob die Segel gleich zu finden
	# sind.
	if body.has_method("build"):
		body.call("build")
	_collect_rigging()


## Groessere Klassen ohne eigenes Modell benutzen dasselbe in groesser.
##
## Solange eine Klasse kein eigenes Rumpfmodell hat, ist die Groesse das
## einzige Merkmal, an dem man eine Brigg von einer Schaluppe unterscheidet -
## Regel A1 verlangt unterscheidbare Silhouetten auf Entfernung.
func _scale_hull(factor: float) -> void:
	if is_equal_approx(factor, 1.0):
		return
	var body := get_node_or_null("Hull") as Node3D
	if body != null:
		body.scale = Vector3.ONE * factor
	var shape := get_node_or_null("Collision") as Node3D
	if shape != null:
		shape.scale = Vector3.ONE * factor


## Die Rumpfmasse, mit denen Wellengang und Trefferentscheid rechnen.
##
## Ein einzelner Skalierungsfaktor konnte beides nur solange beschreiben, wie
## alle Schiffe dieselbe Form hatten. Eine Karavelle ist laenger als die
## Schaluppe und dabei schlanker - mit hull_scale allein waere sie entweder zu
## kurz oder zu breit, und [method Gunnery.hits_target] wuerde gegen ein
## Rechteck pruefen, das nicht auf dem Bildschirm steht.
func _measure_hull(source: ShipClass) -> void:
	half_length = BASE_HALF_LENGTH * source.hull_scale
	half_beam = BASE_HALF_BEAM * source.hull_scale
	if source.half_length > 0.0:
		half_length = source.half_length
	if source.half_beam > 0.0:
		half_beam = source.half_beam

	# Der Kollisionskoerper bleibt bewusst aussen vor: Er haengt als geteilte
	# Unterressource in ship.tscn, und wer ihn hier umschreibt, aendert ihn fuer
	# jedes andere Schiff gleich mit. Er dient ohnehin nur dazu, dass zwei
	# Rumpfe nicht ineinander stehen - getroffen wird ueber half_length und
	# half_beam, und die stimmen jetzt.


func hull_fraction() -> float:
	return float(hull) / float(maxi(max_hull, 1))


func crew_fraction() -> float:
	return float(crew) / float(maxi(max_crew, 1))


## Wie gut sind die Geschuetze bedient? Die Zahl, die im Gefecht zaehlt.
##
## Nicht [method crew_fraction]: Eine Schaluppe faehrt mit vierzig Mann und
## braucht sechzehn: Die ersten Verluste kosten Enterstaerke, nicht Feuer-
## geschwindigkeit. Genau das soll man merken.
func readiness() -> float:
	return Gunnery.readiness(crew, min_crew, cannon_slots)


## Wie gut das Schiff noch zu fahren ist, 0.3 bis 1.0. Die Formel steht in
## [SailingMath], weil das HUD sie ohne Schiff in der Szene ebenfalls braucht.
func handling() -> float:
	return SailingMath.handling(crew, min_crew)


## Wie gut die Segel noch ziehen, 0.0 bis 1.0. Zerschossene Takelage kostet
## Fahrt - und damit die Moeglichkeit zu fliehen.
func sail_health() -> float:
	return clampf(float(sails) / float(maxi(max_sails, 1)), 0.0, 1.0)


## Uebernimmt einen Zustand von aussen - beim Spieler aus GameState.
func set_condition(new_hull: int, new_sails: int, new_crew: int) -> void:
	hull = clampi(new_hull, 0, max_hull)
	sails = clampi(new_sails, 0, max_sails)
	crew = clampi(new_crew, 0, max_crew)
	condition_changed.emit(hull, sails, crew)


## Nimmt Schaden in einer Zone auf. Der einzige Weg, an dem Zustand zu drehen -
## Auflaufen und Beschuss gehen beide hier durch.
func take_hit(zone: int, amount: int) -> void:
	if amount <= 0 or finished:
		return
	match zone:
		Gunnery.Zone.SAILS:
			sails = maxi(sails - amount, 0)
		Gunnery.Zone.CREW:
			crew = maxi(crew - amount, 0)
		_:
			hull = maxi(hull - amount, 0)
	damaged.emit(zone, amount)
	condition_changed.emit(hull, sails, crew)

	if hull <= 0:
		finished = true
		sunk.emit()


## Name des Flaggenknotens im Masttopp. Wer eine Flagge setzt, benutzt diesen
## Namen - dann kann das Schiff sie selbst einholen.
const FLAG_NODE: String = "Hull/Mast/Flag"


## Streicht die Flagge. Das Schiff dreht bei und wartet auf den Sieger.
##
## Die Flagge kommt dabei wirklich herunter: Sie ist von See aus das Zeichen,
## an dem man einen Gegner erkennt, und ein Schiff, das aufgegeben hat, soll
## man auch ohne Blick ins HUD erkennen.
func strike() -> void:
	if struck or finished:
		return
	struck = true
	sail_command = 0
	_set_sail_step(0)
	var flag := get_node_or_null(FLAG_NODE) as Node3D
	if flag != null:
		flag.visible = false
	struck_colours.emit()


# --- Batterien -------------------------------------------------------------

## Index in [member _reload]: Backbord (-1) auf 0, Steuerbord (+1) auf 1.
static func battery_index(side: int) -> int:
	return 0 if side == Gunnery.PORT else 1


func battery_ready(side: int) -> bool:
	return not struck and not finished and _reload[battery_index(side)] <= 0.0


## Ladezustand von 0.0 (gerade gefeuert) bis 1.0 (bereit) - fuer die Anzeige.
func battery_progress(side: int) -> float:
	var remaining := _reload[battery_index(side)]
	if remaining <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / Gunnery.reload_seconds(readiness()), 0.0, 1.0)


## Feuert eine Breitseite ab, wenn sie geladen ist.
##
## Das Schiff verbraucht nur die Ladung und meldet den Schuss. Wohin er geht,
## entscheidet [NavalCombat] - hier ist niemand bekannt ausser man selbst.
func fire(side: int) -> bool:
	if not battery_ready(side):
		return false
	_reload[battery_index(side)] = Gunnery.reload_seconds(readiness())
	fire_requested.emit(side)
	EventBus.cannons_fired.emit(self, side)
	return true


func _cool_batteries(delta: float) -> void:
	for i in _reload.size():
		if _reload[i] > 0.0:
			_reload[i] = maxf(_reload[i] - delta, 0.0)


# --- Seegang ---------------------------------------------------------------

## Das Schiff reitet auf den Wellen, die der Shader zeichnet.
##
## Statt einer Wackelanimation wird die Wasserhoehe an vier Punkten des Rumpfes
## abgetastet - Bug, Heck, beide Seiten. Daraus ergeben sich Tiefgang, Stampfen
## und Rollen von selbst, und sie passen zur sichtbaren See.
func _apply_swell(delta: float) -> void:
	var t := OceanWaves.time_now()
	var pos := global_position
	var forward := -global_basis.z
	var starboard := global_basis.x

	var bow := pos + forward * half_length
	var stern := pos - forward * half_length
	var port := pos - starboard * half_beam
	var star := pos + starboard * half_beam

	var h_bow := OceanWaves.height_at(bow.x, bow.z, t)
	var h_stern := OceanWaves.height_at(stern.x, stern.z, t)
	var h_port := OceanWaves.height_at(port.x, port.z, t)
	var h_star := OceanWaves.height_at(star.x, star.z, t)

	# Der Rumpf mittelt ueber seine Laenge - er folgt nicht jeder Kraeuselung.
	var water := (h_bow + h_stern + h_port + h_star) * 0.25
	position.y = lerpf(position.y, water, 1.0 - exp(-delta * 6.0))

	# Stampfen aus dem Hoehenunterschied Bug zu Heck, Rollen quer dazu.
	var pitch := atan2(h_bow - h_stern, half_length * 2.0) * PITCH_DAMPING
	var roll := atan2(h_star - h_port, half_beam * 2.0) * ROLL_DAMPING

	# In der Wende kraengt ein Segler nach aussen, nicht nach innen.
	roll += helm * deg_to_rad(HEEL_DEGREES) * clampf(speed / base_speed, 0.0, 1.0)

	rotation.x = lerp_angle(rotation.x, pitch, 1.0 - exp(-delta * 5.0))
	rotation.z = lerp_angle(rotation.z, roll, 1.0 - exp(-delta * 4.0))
