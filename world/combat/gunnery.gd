## Die Ballistik des Spiels - reine Mathematik, keine Nodes.
##
## Eine Breitseite wird im Moment des Abfeuerns ausgewuerfelt, nicht simuliert:
## Die Kugel fliegt danach nur noch die Bahn zu einem Ergebnis, das bereits
## feststeht. Das ist die Umkehrung dessen, was man erwartet, und es hat zwei
## Gruende. Erstens laesst sich das Herzstueck des Gefechts so pruefen, ohne
## eine Szene zu starten - Regel B3. Zweitens braucht es keine Kollisionskoerper
## fuer Geschosse, die bei zwoelf Kugeln in der Luft und zwei fahrenden Zielen
## ohnehin nur Zufallstreffer liefern wuerden - Regel B6.
##
## Alles, was der Spieler beeinflussen kann, steckt in drei Zahlen: Lage,
## Entfernung, Mannschaft. Nichts davon ist versteckt.
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
## Bis hierher schiesst man auf volle Wirkung. Darueber faellt die Treffer-
## wahrscheinlichkeit, weil beide Schiffe in der Flugzeit weiterfahren.
const IDEAL_RANGE: float = 150.0
## Treffsicherheit auf hoechste Entfernung, als Anteil der Bestleistung.
const LONG_RANGE_ACCURACY: float = 0.18

## Ab hier gilt ein fremdes Schiff als Gegner: Die Kamera rahmt es ein, das HUD
## zeigt seinen Zustand. Etwas mehr als Schussweite, damit beides schon steht,
## wenn das erste Rohr anliegt.
##
## Kamera und Anzeige benutzen bewusst dieselbe Zahl. Sonst meldet das HUD ein
## Ziel, das die Kamera nicht zeigt - im ersten Entwurf stand dort "Zeelandia -
## 700 m", und auf dem Bildschirm war offene See.
const ENGAGEMENT_RANGE: float = 620.0

# --- Lage ------------------------------------------------------------------
## Halber Feuerbereich um querab, in Grad. Ausserhalb liegt kein Rohr an.
##
## Dieser Winkel ist der Grund, warum man im Gefecht manoevriert statt
## hinterherzufahren: Wer dem Gegner ins Heck faellt, kann nicht schiessen.
##
## 70 Grad ist weiter, als Rohre sich schwenken lassen, und weiter als der
## erste Entwurf mit 50. Der war so eng, dass eine Verfolgungskurve nie
## hindurchpasste - Verfolger und Beute fuhren 80 Sekunden nebeneinander her,
## ohne dass ein Rohr anlag. Wichtig ist, dass Bug und Heck leer bleiben, nicht
## der genaue Grad.
const FIRING_ARC: float = 70.0

# --- Mannschaft und Nachladen ---------------------------------------------
## Trefferwahrscheinlichkeit eines Rohres bei idealer Lage, idealer Entfernung
## und voller Mannschaft.
const BASE_ACCURACY: float = 0.60
## Sekunden bis zur naechsten Breitseite derselben Seite, voll besetzt.
const RELOAD_SECONDS: float = 9.0
## Soweit sinkt der Einfluss der Mannschaft hoechstens. Auch ein zerschossenes
## Schiff feuert noch - nur langsamer und schlechter.
const MIN_CREW_FACTOR: float = 0.40

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

# --- Streuung der Darstellung ---------------------------------------------
## Wie weit ein Fehlschuss neben dem Ziel einschlaegt, in Metern.
const MISS_SCATTER: float = 26.0
## Wie weit ein Treffer vom Schiffsmittelpunkt abweicht.
const HIT_SCATTER: float = 4.0


## Peilung der eigenen Breitseite: der Kurs, auf dem das Ziel genau querab liegt.
static func abeam(ship_heading: float, side: int) -> float:
	return wrapf(ship_heading + float(side) * PI * 0.5, -PI, PI)


## Wie gut liegt das Ziel zur Breitseite? 1.0 = genau querab, 0.0 = kein Rohr an.
##
## Das ist die Zahl, die Manoevrieren belohnt. Sie faellt linear und nicht
## weich ab, damit der Spieler den Zusammenhang aus der Anzeige lernen kann.
static func bearing_quality(ship_heading: float, target_bearing: float, side: int) -> float:
	var offset := absf(angle_difference(abeam(ship_heading, side), target_bearing))
	return clampf(1.0 - offset / deg_to_rad(FIRING_ARC), 0.0, 1.0)


## Welche Seite liegt besser? Gibt PORT oder STARBOARD zurueck.
static func better_side(ship_heading: float, target_bearing: float) -> int:
	var to_port := bearing_quality(ship_heading, target_bearing, PORT)
	var to_starboard := bearing_quality(ship_heading, target_bearing, STARBOARD)
	return PORT if to_port >= to_starboard else STARBOARD


static func range_factor(distance: float) -> float:
	if distance <= IDEAL_RANGE:
		return 1.0
	var t := (distance - IDEAL_RANGE) / (MAX_RANGE - IDEAL_RANGE)
	return lerpf(1.0, LONG_RANGE_ACCURACY, clampf(t, 0.0, 1.0))


static func crew_factor(crew_fraction: float) -> float:
	return clampf(crew_fraction, MIN_CREW_FACTOR, 1.0)


## Trefferwahrscheinlichkeit eines einzelnen Rohres.
static func hit_chance(distance: float, quality: float, crew_fraction: float) -> float:
	if distance > MAX_RANGE or quality <= 0.0:
		return 0.0
	return BASE_ACCURACY * quality * range_factor(distance) * crew_factor(crew_fraction)


## Sekunden bis die Seite wieder feuerbereit ist. Fehlende Leute bedienen
## weniger Rohre gleichzeitig - das Nachladen zieht sich.
static func reload_seconds(crew_fraction: float) -> float:
	return RELOAD_SECONDS / crew_factor(crew_fraction)


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


## Wuerfelt eine ganze Breitseite aus.
##
## [param guns] ist die Zahl der Rohre auf dieser Seite. Jedes schiesst einmal,
## unabhaengig von den anderen - deshalb ist eine Breitseite aus zwoelf Rohren
## verlaesslicher als vier Mal drei.
static func resolve_salvo(
	rng: RandomNumberGenerator,
	guns: int,
	distance: float,
	quality: float,
	crew_fraction: float
) -> Array[Shot]:
	var chance := hit_chance(distance, quality, crew_fraction)
	var shots: Array[Shot] = []
	for i in maxi(guns, 0):
		var shot := Shot.new()
		shot.hit = rng.randf() < chance
		if shot.hit:
			shot.zone = pick_zone(rng, distance)
			shot.damage = damage_for(rng, shot.zone)
			shot.scatter = Vector2(
				rng.randf_range(-HIT_SCATTER, HIT_SCATTER),
				rng.randf_range(-HIT_SCATTER, HIT_SCATTER)
			)
		else:
			# Ein Fehlschuss geht meist zu kurz oder zu weit, seltener daneben -
			# deshalb laengs doppelt so weit gestreut wie quer.
			shot.scatter = Vector2(
				rng.randf_range(-MISS_SCATTER, MISS_SCATTER),
				rng.randf_range(-MISS_SCATTER * 2.0, MISS_SCATTER * 2.0)
			)
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
