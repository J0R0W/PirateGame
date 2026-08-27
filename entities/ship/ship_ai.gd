## Der Kapitaen eines Schiffs ohne Spieler.
##
## Er setzt Ruder und Segel wie ein Mensch: ueber [member Ship.helm_command] und
## [member Ship.sail_command]. Damit gilt fuer ihn dieselbe Physik - er kann
## nicht gegen den Wind fahren, nur weil ihm das gerade passen wuerde, und er
## verliert Fahrt, wenn ihm die Takelage zerschossen wird.
##
## Die Entscheidungen selbst sind statische Funktionen ohne Nodes, damit sie
## sich pruefen lassen (Regel B3). Der Node hier haelt nur den Zustand und
## reicht die Ergebnisse ans Schiff weiter.
##
## Bewusste Schwaeche: Wer flieht, faehrt stur vom Gegner weg und nimmt dabei
## in Kauf, in den Wind gedraengt zu werden. Ein Spieler, der die Luvposition
## haelt, kann jede Beute stellen. Das ist ein System zum Durchschauen, kein
## Fehler - siehe Design-Pillar "Lesbare Systeme".
class_name ShipAI
extends Node

## Grundhaltung. Mehr Zustaende braucht es nicht: Was ein Kapitaen tut, folgt
## aus Entfernung und Rumpfzustand.
enum Stance { APPROACH, ENGAGE, FLEE }

## Ab hier nimmt ein Kapitaen ein fremdes Segel ueberhaupt wahr.
const ALERT_RANGE: float = 1200.0
## So nah laesst sich niemand mehr freiwillig kommen. Wer darunter faellt oder
## beschossen wird, gilt als gereizt und feuert.
const PROVOKE_RANGE: float = 300.0
## Unter diesem Rumpfanteil bricht auch ein Kriegsschiff ab.
const FLEE_HULL: float = 0.45
## So nah wird nicht weiter geschlossen - darunter droht das Rammen.
const CLOSE_QUARTERS: float = 55.0
## Ab dieser Lagequalitaet feuert die KI. Darunter wartet sie auf die Wende.
const FIRE_QUALITY: float = 0.35
## Verstaerkung des Ruders. Hoeher heisst hektischer, nicht schneller - das
## Ruder selbst spricht traege an.
const HELM_GAIN: float = 2.4
## Soweit gilt der Platz laengsseits als erreicht, in Metern.
const STATION_TOLERANCE: float = 55.0
## Soweit muss der Gegner aus der Mitte stehen, damit die Seite wechselt.
const SIDE_HYSTERESIS: float = 0.44

## Wie weit voraus auf Land geprueft wird, in Metern.
const LOOKAHEAD: float = 260.0
## Um soviel Grad wird bei Land voraus ausgewichen.
const AVOID_TURN: float = 55.0

## Sekunden zwischen zwei Entscheidungen. Ein Kapitaen denkt nicht sechzig Mal
## in der Sekunde nach, und ein Zittern im Ruder saehe schlecht aus.
const DECISION_INTERVAL: float = 0.25

var ship: Ship
var target: Ship

## Schiesst dieser Kapitaen schon? Ein Kriegsschiff von Anfang an, ein
## Handelsschiff erst, wenn es beschossen wird oder der Fremde dicht aufkommt.
## Ohne das ballert jede Brigg auf jeden, der zufaellig vorbeifaehrt.
var provoked: bool = false

## Auf welcher Seite wird der Gegner umkreist? Wechselt erst, wenn die andere
## Breitseite geladen ist - sonst dreht das Schiff bei jedem Schuss um.
var _circle_side: int = Gunnery.STARBOARD
var _timer: float = 0.0


func setup(own_ship: Ship) -> void:
	ship = own_ship
	name = "Kapitaen"


func _physics_process(delta: float) -> void:
	if ship == null or ship.struck or ship.finished:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = DECISION_INTERVAL
	_decide()


func _decide() -> void:
	if target == null or target.finished:
		_sail_on()
		return

	var here := ship.plan_position()
	var there := target.plan_position()
	var distance := here.distance_to(there)
	if distance > ALERT_RANGE:
		_sail_on()
		return

	var bearing := SailingMath.bearing(here, there)
	var mood := stance(ship.warship, ship.hull_fraction(), distance)

	_circle_side = preferred_side(ship, bearing, _circle_side)
	var desired := desired_heading(
		mood, here, there, target.heading(), _circle_side, WorldData.wind_direction
	)
	_steer(_avoid_land(desired))

	ship.sail_command = sail_setting(mood, distance)
	_shoot(bearing, distance)


## Grundhaltung aus Schiffstyp, Zustand und Entfernung.
static func stance(warship: bool, hull_fraction: float, distance: float) -> Stance:
	if not warship or hull_fraction < FLEE_HULL:
		return Stance.FLEE
	if distance <= Gunnery.MAX_RANGE:
		return Stance.ENGAGE
	return Stance.APPROACH


## Der Platz, den ein Kapitaen im Gefecht sucht: laengsseits des Gegners, auf
## der Seite seiner angelegten Breitseite, im wirksamsten Abstand.
##
## Soll der Gegner steuerbord liegen und laufen beide denselben Kurs, muss man
## an seiner Backbordseite fahren - deshalb das Minuszeichen vor [param side].
static func station(target_position: Vector2, target_heading: float, side: int) -> Vector2:
	var across := SailingMath.direction(target_heading - float(side) * PI * 0.5)
	return target_position + across * Gunnery.IDEAL_RANGE


## Wunschkurs zur Lage.
##
## Verfolgt wird nicht der Gegner, sondern ein Platz neben ihm ([method
## station]). Wer auf den Gegner selbst zuhaelt, landet in seinem Kielwasser -
## dort liegt kein Rohr an, und beide fahren bis zum Sonnenuntergang geradeaus.
## Genau das ist beim ersten Probelauf passiert: 80 Sekunden, sieben Punkte
## Schaden.
##
## Ein Platz laesst sich anfahren wie jedes andere Ziel, und wer ihn erreicht
## hat, laeuft von selbst querab mit. Steht man schon dort, wird der Kurs des
## Gegners uebernommen statt auf einen Punkt unter dem eigenen Kiel zu zielen.
static func desired_heading(
	mood: Stance,
	own_position: Vector2,
	target_position: Vector2,
	target_heading: float,
	side: int,
	wind_direction: float
) -> float:
	var raw := SailingMath.bearing(own_position, target_position)
	match mood:
		Stance.FLEE:
			raw = wrapf(raw + PI, -PI, PI)
		_:
			var post := station(target_position, target_heading, side)
			var to_post := post - own_position
			raw = target_heading if to_post.length() < STATION_TOLERANCE \
				else SailingMath.angle_of(to_post)
	return SailingMath.sailable_heading(raw, wind_direction)


## Segelstellung zur Lage.
##
## Nur dicht am Gegner wird Fahrt weggenommen, sonst rammt man ihn. Im uebrigen
## Gefecht steht alles.
##
## Reffen waere verlockend - halbe Fahrt dreht enger und schiesst ueber das Ziel
## nicht hinaus. Es kostet aber ein Drittel der Geschwindigkeit, und damit faellt
## eine Patrouille hinter jede Handelsbrigg zurueck, die noch Segel hat. In zwei
## Probelaeufen hat das gereffte Schiff seinen Gegner nie eingeholt und in 80
## Sekunden nichts ausgerichtet.
static func sail_setting(_mood: Stance, distance: float) -> int:
	return 1 if distance < CLOSE_QUARTERS else 3


## Auf welcher Seite wird der Gegner gehalten?
##
## Die einmal gewaehlte Seite bleibt, solange der Gegner nicht deutlich auf der
## anderen steht. Die Seite nach dem Ladezustand zu waehlen waere verlockend -
## man haette immer ein volles Rohr - hiesse aber, dem Gegner alle neun Sekunden
## durchs Kielwasser zu fahren. Im Probelauf lief das Schiff dabei nur noch im
## Kreis und traf nichts.
##
## Dass die abgewandte Breitseite dabei ungenutzt bleibt, ist kein Versehen: Im
## Gefecht laengsseits schiesst nur die zugewandte Seite.
static func preferred_side(own: Ship, target_bearing: float, current: int) -> int:
	var offset := angle_difference(own.heading(), target_bearing)
	if absf(offset) < SIDE_HYSTERESIS:
		return current
	return Gunnery.STARBOARD if offset > 0.0 else Gunnery.PORT


static func should_fire(quality: float, distance: float) -> bool:
	return quality >= FIRE_QUALITY and distance <= Gunnery.MAX_RANGE


func _shoot(bearing: float, distance: float) -> void:
	if not (ship.warship or provoked):
		return
	for side: int in [Gunnery.PORT, Gunnery.STARBOARD]:
		if not ship.battery_ready(side):
			continue
		var quality := Gunnery.bearing_quality(ship.heading(), bearing, side)
		if should_fire(quality, distance):
			ship.fire(side)


## Faehrt weiter, ohne jemanden im Blick - aber nicht auf die Kueste zu.
func _sail_on() -> void:
	ship.sail_command = 3
	_steer(_avoid_land(ship.heading()))


func _steer(desired: float) -> void:
	var error := angle_difference(ship.heading(), desired)
	ship.helm_command = clampf(error * HELM_GAIN, -1.0, 1.0)


## Weicht Land aus, bevor es zu spaet ist.
##
## Ohne das rennt jedes fliehende Handelsschiff frueher oder spaeter auf die
## naechste Insel - und liegt dann als Geschenk vor dem Spieler. Geprueft wird
## nur der Wunschkurs und zwei Ausweichkurse; feiner braucht es das nicht, weil
## der Kapitaen viermal je Sekunde neu entscheidet.
func _avoid_land(desired: float) -> float:
	if _clear(desired):
		return desired
	var turn := deg_to_rad(AVOID_TURN)
	for candidate: float in [desired + turn, desired - turn, desired + turn * 2.0,
			desired - turn * 2.0]:
		if _clear(candidate):
			return wrapf(candidate, -PI, PI)
	# Nirgends frei: umkehren und es im naechsten Takt neu versuchen.
	return wrapf(desired + PI, -PI, PI)


func _clear(course: float) -> bool:
	var here := ship.plan_position()
	var step := SailingMath.direction(course)
	# Zwei Punkte statt einem: Eine Landzunge liegt sonst genau zwischen den
	# Fuehlern und wird uebersehen.
	for factor: float in [0.5, 1.0]:
		var probe := here + step * LOOKAHEAD * factor
		if WorldData.is_land(probe.x, probe.y):
			return false
	return true
