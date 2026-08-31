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
## Weiter draussen wird nicht gefeuert, obwohl die Kugel noch traegt.
##
## Ein Rohr liegt auch auf vierhundert Metern an, nur trifft es dort kaum: Der
## Vorhaltefehler waechst mit der Entfernung, und eine Salve ins Leere kostet
## neun Sekunden Nachladen. Im ersten Messlauf hat die KI genau das getan -
## 185 Kugeln, 35 Treffer. Mit dieser Grenze schiesst sie seltener und trifft
## dabei mehr.
const FIRE_RANGE: float = Gunnery.IDEAL_RANGE * 1.5
## Weiter draussen wird geradewegs zugehalten, naeher wird abgedreht.
##
## Der Uebergang muss kurz sein. Ein Vorhalt, der schon auf dreihundert Metern
## anfaengt, kostet die Haelfte des Geschwindigkeitsvorsprungs - und ein
## Verfolger, der nur vier Knoten schneller ist, holt dann gar nicht mehr auf.
## Gemessen: Verfolger und Beute liefen drei Minuten in konstantem Abstand
## nebeneinander her, ohne einen Schuss.
const APPROACH_RANGE: float = 170.0
## Und hier steht der Gegner genau querab.
##
## Deutlich naeher als die ideale Entfernung. Der Grund ist die Beute, nicht die
## Ballistik: Querab kann ein Verfolger nicht mehr aufschliessen, er laeuft ja
## quer zu ihr. Wer erst auf 150 Metern eindreht, haelt die Lage nur, solange die
## Beute geradeaus faehrt - dreht sie weg, faengt die Verfolgung von vorn an.
## Hundert Meter sind nah genug, dass die kurze Nachkorrektur reicht.
const BEAM_RANGE: float = 100.0
## Soweit ueber querab hinaus wird gedreht, in rechten Winkeln. Ueber 1.0 heisst:
## Wer zu dicht heran ist, dreht wieder ab, statt zu rammen.
const MAX_LEAD: float = 1.25
## Verstaerkung des Ruders. Hoeher heisst hektischer, nicht schneller - das
## Ruder selbst spricht traege an.
##
## In M4 stand hier 2.4. Das reichte, solange der Feuerbereich 70 Grad breit war
## und ein Rohr auch dann noch anlag, wenn der Platz um vierzig Meter verfehlt
## wurde. Mit einem Kegel von 20 Grad um querab ist ein zu weiches Ruder
## gleichbedeutend mit "trifft nie".
const HELM_GAIN: float = 3.4
## Soweit muss der Gegner aus der Mitte stehen, damit die Seite wechselt.
##
## Weit mehr als in M4 (0.44 rad, 25 Grad). Die Seite bestimmt, in welche
## Richtung eingedreht wird - wechselt sie, kehrt sich die ganze Bahn um. Mit dem
## kleinen Wert flatterte sie in der Verfolgung viermal je Minute, und das Schiff
## fuhr Schlangenlinien, statt aufzuschliessen. Siebzig Grad heisst: Es wechselt,
## wer wirklich auf der anderen Seite steht, und niemand sonst.
const SIDE_HYSTERESIS: float = 1.2

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
	var desired := desired_heading(mood, here, there, _circle_side, WorldData.wind_direction)
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


## Wunschkurs zur Lage.
##
## Der Kern des Gefechts steht in [method engage_course]: Verfolgt wird nicht
## der Gegner, sondern eine Lage neben ihm.
static func desired_heading(
	mood: Stance,
	own_position: Vector2,
	target_position: Vector2,
	side: int,
	wind_direction: float
) -> float:
	var raw := SailingMath.bearing(own_position, target_position)
	if mood == Stance.FLEE:
		raw = wrapf(raw + PI, -PI, PI)
	else:
		raw = engage_course(own_position, target_position, side)
	return SailingMath.sailable_heading(raw, wind_direction)


## Der Kurs, mit dem ein Kapitaen an seinen Gegner herangeht.
##
## Wer geradewegs auf den Gegner zuhaelt, landet in seinem Kielwasser - dort
## liegt kein Rohr an, und beide fahren bis zum Sonnenuntergang geradeaus. Also
## wird ein Vorhalt auf die Peilung gelegt: weit draussen null, sodass wirklich
## aufgeschlossen wird, und auf wirksamer Entfernung volle neunzig Grad, sodass
## der Gegner genau querab steht.
##
## Dazwischen ergibt sich eine Spirale, die von selbst in einen Kreis um den
## Gegner einlaeuft - und ein Kreis auf Idealentfernung ist genau die Bahn, auf
## der die Breitseite dauerhaft anliegt.
##
## M4 hat das ueber einen festen Platz neben dem Gegner geloest ([code]station()
## [/code]). Das war beim engen Schwenkbereich nicht mehr zu halten: Der Platz
## faehrt mit, ein Verfolger mit zwei Knoten Ueberschuss braucht Minuten, um ihn
## einzuholen, und solange steht der Gegner schraeg voraus. Gemessen: zwoelf
## Prozent der Zeit lag ein Rohr an. Der Vorhalt hier braucht keinen Platz und
## keine Fahrt des Gegners - er korrigiert sich selbst, weil ein Gegner, der
## davonlaeuft, die Entfernung vergroessert und damit den Vorhalt verkleinert.
static func engage_course(own_position: Vector2, target_position: Vector2, side: int) -> float:
	var to_enemy := target_position - own_position
	var distance := to_enemy.length()
	if distance < 1.0:
		return SailingMath.angle_of(to_enemy) if distance > 0.0 else 0.0
	var closeness := clampf(
		(APPROACH_RANGE - distance) / (APPROACH_RANGE - BEAM_RANGE), 0.0, MAX_LEAD
	)
	# Soll der Gegner steuerbord liegen, muss der eigene Kurs links von der
	# Peilung liegen - daher das Minuszeichen.
	var lead := -float(side) * PI * 0.5 * closeness
	return wrapf(SailingMath.angle_of(to_enemy) + lead, -PI, PI)


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


## Feuert diese Breitseite?
##
## Seit die Rohre wirklich dorthin zeigen, wo sie hinzeigen, bleiben zwei
## Fragen: Liegt der Gegner im Schwenkbereich, und ist er nahe genug, dass sich
## das Pulver lohnt. In M4 stand hier stattdessen eine Schwelle auf der
## Lagequalitaet - die ist mit dem Wuerfel weggefallen.
static func should_fire(
	shooter_heading: float,
	target_bearing: float,
	side: int,
	distance: float,
	traverse_deg: float = Gunnery.TRAVERSE
) -> bool:
	return distance <= FIRE_RANGE and Gunnery.bears(
		shooter_heading, target_bearing, side, traverse_deg
	)


func _shoot(bearing: float, distance: float) -> void:
	if not (ship.warship or provoked):
		return
	for side: int in [Gunnery.PORT, Gunnery.STARBOARD]:
		if not ship.battery_ready(side):
			continue
		if should_fire(ship.heading(), bearing, side, distance, ship.gun_traverse):
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
