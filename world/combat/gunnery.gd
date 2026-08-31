## Die Ballistik des Spiels - reine Mathematik, keine Nodes.
##
## Bis M4 war Treffen ein verdeckter Wuerfelwurf: Aus dem Winkel zum Ziel wurde
## eine Wahrscheinlichkeit, und die Kugeln flogen danach zu einem Ergebnis, das
## laengst feststand. Die Flugbahn war Dekoration.
##
## Jetzt ist die Flugbahn die Wahrheit. Wo die Rohre hinzeigen, fliegen die
## Kugeln, und ob sie treffen, entscheidet die Geometrie: ein Punkt-in-Rechteck-
## Test gegen den Rumpf des Gegners. Der Zufall sitzt nur noch dort, wo er
## hingehoert - im Vorhalten und in der Streuung der einzelnen Rohre.
##
## Zwei Dinge bleiben aus M4, weil sie sich bewaehrt haben. Eine Breitseite wird
## weiterhin im Moment des Abfeuerns fertig gerechnet, nicht Schritt fuer
## Schritt simuliert: Das Herzstueck des Gefechts laesst sich so ohne Szene
## pruefen (Regel B3) und braucht keine Kollisionskoerper (Regel B6). Und die
## Trefferzonen haengen weiter allein an der Entfernung.
class_name Gunnery
extends RefCounted

## Getroffene Bereiche. Was ein Treffer anrichtet, haengt allein hiervon ab.
enum Zone { HULL, SAILS, CREW }

## Seiten als Vorzeichen, damit sich damit rechnen laesst: querab liegt bei
## heading + side * 90 Grad. Backbord ist links, Steuerbord rechts.
const PORT: int = -1
const STARBOARD: int = 1

# --- Entfernung ------------------------------------------------------------
## Weiter als das traegt keine Kugel. Rund vier Schiffslaengen mal zwoelf.
const MAX_RANGE: float = 420.0
## Der Massstab fuer alle Fehler: Auf dieser Entfernung gelten LEAD_SPREAD und
## SPREAD_DEG unveraendert, darueber wachsen beide linear mit. Naehergehen wird
## damit belohnt, ohne dass eine Wahrscheinlichkeit im Spiel waere.
const IDEAL_RANGE: float = 150.0

## Ab hier gilt ein fremdes Schiff als Gegner: Die Kamera rahmt es ein, das HUD
## zeigt seinen Zustand. Etwas mehr als Schussweite, damit beides schon steht,
## wenn das erste Rohr anliegt.
##
## Kamera und Anzeige benutzen bewusst dieselbe Zahl. Sonst meldet das HUD ein
## Ziel, das die Kamera nicht zeigt - im ersten Entwurf stand dort "Zeelandia -
## 700 m", und auf dem Bildschirm war offene See.
const ENGAGEMENT_RANGE: float = 620.0

# --- Flugzeit --------------------------------------------------------------
## Flugzeit fuer die volle Schussweite, in Sekunden.
##
## Sie steht hier und nicht mehr bei [CannonBall], weil das Vorhalten sie
## braucht: Die Ballistik darf die Darstellung nicht kennen, die Darstellung
## aber die Ballistik - sonst zeigen zwei Klassen aufeinander und Godot loest
## keine von beiden mehr auf.
const FLIGHT_SECONDS: float = 1.4


## Wie lange eine Kugel auf diese Entfernung braucht.
##
## Auch der Schaden wartet darauf: Er faellt erst, wenn die Kugel ankommt -
## sonst sinkt ein Gegner, waehrend die Breitseite noch in der Luft steht.
static func flight_time(distance: float) -> float:
	return maxf(FLIGHT_SECONDS * distance / MAX_RANGE, 0.25)


# --- Richten ---------------------------------------------------------------
## Halber Schwenkbereich um querab, in Grad. Vorgabe fuer alle Klassen; die
## einzelne Klasse verschiebt ihn ueber [member ShipClass.gun_traverse].
##
## In M4 waren es 70 Grad, und die entschieden nur darueber, wie stark der
## Wuerfel belastet war. Jetzt entscheiden sie, wohin die Rohre wirklich zeigen,
## und deshalb ist der Kegel mehr als dreimal so eng. Genau das erzwingt das
## Zielen: Wer dem Gegner ins Heck faellt, kann nicht schiessen, und wer schraeg
## steht, sieht seine Salve vorbeigehen.
const TRAVERSE: float = 20.0


## Peilung der eigenen Breitseite: der Kurs, auf dem das Ziel genau querab liegt.
static func abeam(ship_heading: float, side: int) -> float:
	return wrapf(ship_heading + float(side) * PI * 0.5, -PI, PI)


## Wie weit muss diese Breitseite schwenken, um das Ziel zu bekommen?
## Vorzeichenbehaftet, in Radiant - null heisst genau querab.
static func aim_offset(ship_heading: float, target_bearing: float, side: int) -> float:
	return angle_difference(abeam(ship_heading, side), target_bearing)


## Wieviel Luft bleibt bis zum Anschlag? 1.0 = genau querab, 0.0 = am Anschlag
## oder darueber hinaus.
##
## Seit die Mannschaft selbst richtet, ist das keine Trefferwahrscheinlichkeit
## mehr, sondern eine Anzeige: Sie sagt dem Spieler, wieviel Spielraum ihm
## bleibt, bevor die Salve danebengeht.
static func bearing_quality(
	ship_heading: float, target_bearing: float, side: int, traverse_deg: float = TRAVERSE
) -> float:
	var offset := absf(aim_offset(ship_heading, target_bearing, side))
	return clampf(1.0 - offset / deg_to_rad(maxf(traverse_deg, 0.01)), 0.0, 1.0)


## Liegt diese Breitseite an? Nur dann bekommen die Rohre das Ziel ueberhaupt.
static func bears(
	ship_heading: float, target_bearing: float, side: int, traverse_deg: float = TRAVERSE
) -> bool:
	return absf(aim_offset(ship_heading, target_bearing, side)) <= deg_to_rad(traverse_deg)


## Welche Seite liegt besser? Gibt PORT oder STARBOARD zurueck.
static func better_side(ship_heading: float, target_bearing: float) -> int:
	var to_port := absf(aim_offset(ship_heading, target_bearing, PORT))
	var to_starboard := absf(aim_offset(ship_heading, target_bearing, STARBOARD))
	return PORT if to_port <= to_starboard else STARBOARD


## Die Richtung, in die diese Breitseite tatsaechlich feuert.
##
## Alle Rohre einer Seite feuern parallel - es gibt genau eine Richtung je
## Breitseite, die der mittleren Kanone. Liegt das Ziel im Kegel, zeigen sie
## darauf; liegt es ausserhalb, schwenken sie bis zum Anschlag und schiessen
## daneben. Das ist Absicht: Man sieht die Salve vorbeigehen und weiss, wohin
## man drehen muss.
static func aim_direction(
	ship_heading: float, target_bearing: float, side: int, traverse_deg: float = TRAVERSE
) -> float:
	var limit := deg_to_rad(traverse_deg)
	var offset := clampf(aim_offset(ship_heading, target_bearing, side), -limit, limit)
	return wrapf(abeam(ship_heading, side) + offset, -PI, PI)


# --- Mannschaft und Nachladen ---------------------------------------------
## Sekunden bis zur naechsten Breitseite derselben Seite, voll bedient.
const RELOAD_SECONDS: float = 9.0
## Mann je Rohr fuer die volle Ladegeschwindigkeit.
const CREW_PER_GUN: int = 2
## Soweit sinkt die Bedienung hoechstens. Auch ein zerschossenes Schiff feuert
## noch - nur langsamer und schlechter.
const MIN_READINESS: float = 0.35


## Wie gut sind die Rohre bedient? 1.0 = voll, [constant MIN_READINESS] = kaum
## noch jemand da.
##
## Die Mannschaft hat zwei Aufgaben, und die erste geht vor: [param min_crew]
## Leute halten das Schiff ueberhaupt in Fahrt, erst der Rest bedient die
## Geschuetze. Gezaehlt werden dabei alle Rohre, nicht die einer Seite - beide
## Batterien laden bei uns gleichzeitig, also braucht auch jede ihre eigene
## Bedienung.
static func readiness(crew: int, min_crew: int, cannon_slots: int) -> float:
	var available := maxi(crew - min_crew, 0)
	var needed := maxi(cannon_slots, 1) * CREW_PER_GUN
	return clampf(float(available) / float(needed), MIN_READINESS, 1.0)


## Sekunden, bis die Seite wieder feuerbereit ist.
static func reload_seconds(crew_readiness: float) -> float:
	return RELOAD_SECONDS / clampf(crew_readiness, MIN_READINESS, 1.0)


## Gemeinsamer Massstab beider Fehlerquellen: waechst mit der Entfernung und
## mit fehlenden Leuten. Eine dezimierte Mannschaft laedt langsamer und trifft
## schlechter, ohne dass es dafuer eine zweite Zahl braucht.
static func error_scale(distance: float, crew_readiness: float) -> float:
	return (distance / IDEAL_RANGE) / clampf(crew_readiness, MIN_READINESS, 1.0)


# --- Vorhalten -------------------------------------------------------------
## Wie weit die Mannschaft sich beim Vorhalten vertut, in Metern - auf idealer
## Entfernung und bei voller Bedienung.
##
## Ein Gegner auf 300 Metern ist nach der Flugzeit rund zehn Meter weiter. Dass
## vorgehalten wird, versteht sich; dass es dabei danebengeht, ist der Rest des
## Zufalls. Sechs Meter sind bei einem Rumpf von zehn Metern Laenge noch ein
## Treffer, auf doppelter Entfernung sind es zwoelf und damit ein Vorbeischuss.
const LEAD_SPREAD: float = 6.0


## Wo das Ziel steht, wenn die Kugeln ankommen. Die Wahrheit, gegen die der
## Trefferentscheid geprueft wird.
static func predicted_position(target: TargetProfile, distance: float) -> Vector2:
	return target.position + target.velocity * flight_time(distance)


## Und wohin die Mannschaft haelt: derselbe Punkt, um ihren Fehler verschoben.
##
## Der Fehler laeuft entlang des gegnerischen Kurses, nicht in eine beliebige
## Richtung - man haelt zu weit vor oder zu wenig, man haelt nicht seitlich
## daneben.
static func lead_point(
	rng: RandomNumberGenerator,
	target: TargetProfile,
	distance: float,
	crew_readiness: float
) -> Vector2:
	var error := rng.randf_range(-1.0, 1.0) * LEAD_SPREAD * error_scale(
		distance, crew_readiness
	)
	return predicted_position(target, distance) + SailingMath.direction(target.heading) * error


# --- Streuung der einzelnen Rohre -----------------------------------------
## Wie weit ein einzelnes Rohr von der Richtung der Salve abweicht, in Grad.
##
## Klein, aber nicht null: Ohne Streuung traefen immer alle oder keiner, und
## eine Breitseite waere ein einziger grosser Schuss. Auf 150 Metern sind 1.2
## Grad rund drei Meter quer - genug, dass eine Salve auch mal zwei von drei
## trifft, zu wenig, um das Zielen zu entwerten.
const SPREAD_DEG: float = 1.2
## Abstand zweier Rohre auf der Bordwand, in Metern. Bestimmt nur, wie breit
## eine Salve auf dem Weg auseinanderlaeuft - eine Breitseite aus einem Punkt
## saehe aus wie ein einziger Schuss.
const GUN_SPACING: float = 1.6


## Wo das i-te Rohr einer Breitseite steht, laengs zum Mittelpunkt der Batterie.
static func gun_offset(index: int, guns: int) -> float:
	return (float(index) - float(maxi(guns, 1) - 1) * 0.5) * GUN_SPACING


## Die Abweichung eines einzelnen Rohres von der Richtung der Salve.
static func gun_spread(
	rng: RandomNumberGenerator, distance: float, crew_readiness: float
) -> float:
	return deg_to_rad(SPREAD_DEG) * rng.randf_range(-1.0, 1.0) * error_scale(
		distance, crew_readiness
	)


# --- Trefferentscheid ------------------------------------------------------

## Liegt dieser Punkt im Rumpf des Ziels?
##
## Ein Punkt-in-Rechteck-Test im gedrehten Rechteck des Gegners. Damit wird
## seine Lage zu einer eigenen Groesse: Ein Schiff quer zu dir ist zehn Meter
## breit im Anschlag, dasselbe Schiff mit dem Bug zu dir keine vier. Wer sich
## dem Feind zudreht, macht sich schmal - das gab es in M4 ueberhaupt nicht.
##
## Dass die Kugel dabei genau auf Entfernung liegt und nur seitlich streut, ist
## kein Versehen: Genau daran haengt der Satz oben. Mit einem Streuen auch in
## der Tiefe waere ein Schiff mit dem Bug zu dir das leichtere Ziel, weil es in
## Schussrichtung laenger ist - das Gegenteil dessen, was man sieht.
static func hits_target(
	point: Vector2,
	target_position: Vector2,
	target_heading: float,
	half_length: float,
	half_beam: float
) -> bool:
	var forward := SailingMath.direction(target_heading)
	# Querab zum Ziel, 90 Grad nach dessen Steuerbord.
	var across := Vector2(-forward.y, forward.x)
	var relative := point - target_position
	return absf(relative.dot(forward)) <= half_length \
		and absf(relative.dot(across)) <= half_beam


# --- Trefferzonen ----------------------------------------------------------
## Ab hier gilt ein Schuss als Nahschuss, darunter als Fernschuss.
const CLOSE_RANGE: float = 120.0
const LONG_RANGE: float = 320.0
## Anteil der Treffer, die in den Rumpf gehen - nah und fern.
##
## Auf kurze Entfernung liegt die Bahn flach und schlaegt in die Bordwand.
## Von weit her kommt die Kugel von oben durch die Takelage. Daraus folgt die
## einzige taktische Entscheidung, die der Spieler dauernd trifft: Abstand
## halten und die Segel zerlegen, oder rangehen und den Rumpf brechen.
const HULL_SHARE_CLOSE: float = 0.76
const HULL_SHARE_LONG: float = 0.22
## Anteil der Treffer, die die Mannschaft kosten - entfernungsunabhaengig.
const CREW_SHARE: float = 0.12

## Schaden je Treffer, vor der Streuung.
##
## Deutlich niedriger als in M4 (8/10/2). Damals ging die Lage in die Treffer-
## wahrscheinlichkeit ein, und eine Breitseite verfehlte im Schnitt die Haelfte.
## Jetzt trifft eine richtig gelegte Breitseite fast vollstaendig - der Schaden
## je Kugel muss also fallen, sonst ist jedes Gefecht nach zwei Salven vorbei.
## Am Duell im Rauchtest gemessen, nicht geschaetzt (Regel C4).
const HULL_DAMAGE: int = 8
const SAIL_DAMAGE: int = 10
const CREW_DAMAGE: int = 2
## Streuung des Schadens. Zwei gleiche Breitseiten sollen sich nicht gleich
## anfuehlen.
const DAMAGE_SPREAD: float = 0.3

# --- Aufgeben --------------------------------------------------------------
## Unter diesem Rumpfanteil streicht ein Kapitaen die Flagge.
const STRIKE_HULL: float = 0.30
## Oder wenn ihm so wenig Mannschaft bleibt.
const STRIKE_CREW: float = 0.35
## Wieviel frueher ein gefuerchteter Gegner aufgeben laesst. Beruechtigtheit
## ist damit eine Waffe - siehe KONZEPT.md, Abschnitt 3.4.
const FEAR_BONUS: float = 0.20


## Verteilung der Treffer auf Rumpf, Takelage und Mannschaft.
static func zone_weights(distance: float) -> PackedFloat32Array:
	var t := clampf((distance - CLOSE_RANGE) / (LONG_RANGE - CLOSE_RANGE), 0.0, 1.0)
	var hull := lerpf(HULL_SHARE_CLOSE, HULL_SHARE_LONG, t)
	return PackedFloat32Array([hull, 1.0 - hull - CREW_SHARE, CREW_SHARE])


static func pick_zone(rng: RandomNumberGenerator, distance: float) -> int:
	var weights := zone_weights(distance)
	var roll := rng.randf()
	if roll < weights[0]:
		return Zone.HULL
	if roll < weights[0] + weights[1]:
		return Zone.SAILS
	return Zone.CREW


static func base_damage(zone: int) -> int:
	match zone:
		Zone.SAILS:
			return SAIL_DAMAGE
		Zone.CREW:
			return CREW_DAMAGE
		_:
			return HULL_DAMAGE


static func damage_for(rng: RandomNumberGenerator, zone: int) -> int:
	var spread := rng.randf_range(1.0 - DAMAGE_SPREAD, 1.0 + DAMAGE_SPREAD)
	return maxi(1, int(round(float(base_damage(zone)) * spread)))


# --- Die ganze Breitseite --------------------------------------------------

## Rechnet eine Breitseite aus: Richtung, Bahnen, Treffer.
##
## [param muzzle] ist der Mittelpunkt der Batterie in der Weltebene, nicht der
## Schiffsmittelpunkt - die Rohre stehen an der Bordwand.
##
## Der Ablauf ist derselbe, den eine Geschuetzmannschaft haette: Sie schaetzt,
## wo der Gegner sein wird, wenn die Kugeln ankommen; sie schwenkt so weit sie
## kann darauf zu; jedes Rohr geht ein Stueck daneben; und wo die Kugeln
## niedergehen, entscheidet, ob getroffen wurde. Nirgends faellt ein Wuerfel
## darueber, ob es ein Treffer wird - nur darueber, wie schlecht gezielt war.
static func resolve_salvo(
	rng: RandomNumberGenerator,
	guns: int,
	muzzle: Vector2,
	shooter_heading: float,
	side: int,
	target: TargetProfile,
	crew_readiness: float,
	traverse_deg: float = TRAVERSE
) -> Array[Shot]:
	var shots: Array[Shot] = []
	if guns <= 0 or target == null:
		return shots

	var distance := muzzle.distance_to(target.position)
	var truth := predicted_position(target, distance)
	var aimed := lead_point(rng, target, distance, crew_readiness)
	var aim := aim_direction(
		shooter_heading, SailingMath.bearing(muzzle, aimed), side, traverse_deg
	)
	# Gerichtet wird auf die geschaetzte Entfernung, nicht auf die wirkliche.
	var travel := muzzle.distance_to(aimed)
	var along := SailingMath.direction(shooter_heading)

	for i in guns:
		var shot := Shot.new()
		shot.origin = muzzle + along * gun_offset(i, guns)
		var course := aim + gun_spread(rng, distance, crew_readiness)
		shot.impact = shot.origin + SailingMath.direction(course) * travel
		shot.hit = distance <= MAX_RANGE and hits_target(
			shot.impact, truth, target.heading, target.half_length, target.half_beam
		)
		if shot.hit:
			shot.zone = pick_zone(rng, distance)
			shot.damage = damage_for(rng, shot.zone)
		shots.append(shot)
	return shots


static func hits_in(shots: Array[Shot]) -> int:
	var count := 0
	for shot: Shot in shots:
		if shot.hit:
			count += 1
	return count


## Schadenssumme einer Breitseite in einer Zone - fuer Anzeige und Tests.
static func damage_in(shots: Array[Shot], zone: int) -> int:
	var total := 0
	for shot: Shot in shots:
		if shot.hit and shot.zone == zone:
			total += shot.damage
	return total


## Streicht dieser Kapitaen die Flagge?
##
## [param fear] ist die Beruechtigtheit des Angreifers, 0.0 bis 1.0. Wer einen
## Ruf hat, muss weniger schiessen - und ein unversehrtes Schiff ergibt sich
## trotzdem nie.
static func will_strike(hull_fraction: float, crew_fraction: float, fear: float) -> bool:
	var threshold := STRIKE_HULL + FEAR_BONUS * clampf(fear, 0.0, 1.0)
	return hull_fraction <= threshold or crew_fraction <= STRIKE_CREW
