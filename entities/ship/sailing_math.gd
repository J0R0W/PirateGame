## Reine Segelmathematik - keine Nodes, keine Seiteneffekte.
##
## Bewusst als statische Funktionen ausgelagert: So laesst sich das Herzstueck
## des Spiels testen, ohne eine Szene zu starten. Siehe tests/smoke_test.tscn.
##
## Winkelkonvention im ganzen Projekt (Navigationswinkel):
##   0 = Nord, PI/2 = Ost, PI = Sued, -PI/2 = West.
##   Die Weltrichtung dazu ist (sin a, -cos a) in der XZ-Ebene, denn -Z ist Nord.
##   [param wind_direction] ist die Richtung, AUS DER der Wind kommt.
##   Faehrt das Schiff genau in den Wind, ist die Differenz also 0 - "In Irons".
##
## ACHTUNG: Godots rotation.y laeuft entgegengesetzt. Die Umrechnung passiert
## ausschliesslich in Ship.heading() und Ship.set_heading() - nirgends sonst
## direkt auf rotation.y rechnen.
class_name SailingMath
extends RefCounted

## Segelstellungen von eingeholt bis voll. Der Spieler schaltet mit W/S durch.
const SAIL_STEPS: PackedFloat32Array = [0.0, 0.35, 0.7, 1.0]
const SAIL_NAMES: PackedStringArray = ["Eingeholt", "Gerefft", "Halbe Segel", "Volle Segel"]

## Grenzwinkel der Segelbereiche in Grad, gemessen zur Windquelle.
const IRONS_LIMIT: float = 30.0
const CLOSE_HAULED_LIMIT: float = 60.0
const BROAD_REACH_LIMIT: float = 150.0

## Sicherheitsabstand beim Anlegen eines fahrbaren Kurses, in Grad. Genau auf
## der Grenze entscheidet sonst das letzte Bit einer Fliesskommazahl darueber,
## ob das Segel zieht oder killt.
const POINTING_MARGIN: float = 2.0

## Soweit faellt die Fahrt hoechstens, wenn die Mannschaft unter die Mindest-
## besatzung sinkt. Nicht auf null: Ein manoevrierunfaehiges Wrack, das nur
## noch treibt, waere eine Sackgasse statt einer Niederlage.
const MIN_HANDLING: float = 0.3


## Wie gut ein Schiff mit dieser Mannschaft noch zu fahren ist, 0.3 bis 1.0.
##
## Unter der Mindestbesatzung fehlen Haende an Schoten und Rudern. Ein Schiff
## mit zwei von vier Mann kriecht dann noch, faehrt aber nicht mehr. Der Wert
## multipliziert die Segelwirkung, genau wie ein Loch im Tuch - beide Verluste
## sollen sich im selben spuerbaren Ergebnis niederschlagen: Fahrt.
##
## Steht hier und nicht im [Ship], weil Hafenbildschirme und HUD die Zahl auch
## brauchen, wenn kein Schiff in der Szene haengt - und weil zwei Fassungen
## derselben Formel unweigerlich auseinanderlaufen.
static func handling(crew: int, min_crew: int) -> float:
	return clampf(float(crew) / float(maxi(min_crew, 1)), MIN_HANDLING, 1.0)

## Weltrichtung zu einem Navigationswinkel, in der XZ-Ebene.
static func direction(navigation_angle: float) -> Vector2:
	return Vector2(sin(navigation_angle), -cos(navigation_angle))


## Navigationswinkel zu einer Weltrichtung in der XZ-Ebene.
static func angle_of(direction_xz: Vector2) -> float:
	return atan2(direction_xz.x, -direction_xz.y)


## Wie gut steht das Segel zum Wind? 0.0 = Stillstand, 1.0 = optimal.
static func sail_efficiency(ship_heading: float, wind_direction: float) -> float:
	var angle := absf(angle_difference(ship_heading, wind_direction))
	if angle < deg_to_rad(IRONS_LIMIT):
		return 0.05
	elif angle < deg_to_rad(CLOSE_HAULED_LIMIT):
		return 0.45
	elif angle < deg_to_rad(BROAD_REACH_LIMIT):
		return 1.0
	else:
		return 0.75


## Name des aktuellen Segelbereichs - fuer die Anzeige im HUD.
static func point_of_sail(ship_heading: float, wind_direction: float) -> String:
	var angle := absf(angle_difference(ship_heading, wind_direction))
	if angle < deg_to_rad(IRONS_LIMIT):
		return "In Irons"
	elif angle < deg_to_rad(CLOSE_HAULED_LIMIT):
		return "Am Wind"
	elif angle < deg_to_rad(BROAD_REACH_LIMIT):
		return "Raumschots"
	else:
		return "Vor dem Wind"


## Zielgeschwindigkeit in Knoten. Die tatsaechliche Fahrt laeuft dieser
## traege hinterher - siehe Ship._physics_process().
static func target_speed(
	base_speed: float,
	ship_heading: float,
	wind_direction: float,
	wind_strength: float,
	sail_setting: float,
	sail_health: float = 1.0
) -> float:
	return base_speed \
		* sail_efficiency(ship_heading, wind_direction) \
		* wind_strength \
		* sail_setting \
		* sail_health


## Traege Annaeherung an einen Zielwert. [param inertia] in Sekunden:
## hoeher = schwerfaelliger. Framerate-unabhaengig.
static func approach(current: float, target: float, inertia: float, delta: float) -> float:
	if inertia <= 0.0:
		return target
	return lerpf(current, target, 1.0 - exp(-delta / inertia))


## Peilung von einem Punkt zum anderen, als Navigationswinkel.
static func bearing(from: Vector2, to: Vector2) -> float:
	return angle_of(to - from)


## Der naechstgelegene Kurs, den ein Segler tatsaechlich fahren kann.
##
## Wer in den Sperrsektor steuert, bleibt stehen. Ein Kapitaen faehrt deshalb
## nie den kuerzesten Weg zum Ziel, sondern den kuerzesten fahrbaren: knapp am
## Wind, auf der Seite, die dem Wunschkurs naeher liegt. Wer flieht und dabei
## in den Wind gedraengt wird, verliert Fahrt - das ist beabsichtigt und der
## Grund, warum die Luvposition im Gefecht etwas wert ist.
static func sailable_heading(desired: float, wind_direction: float) -> float:
	var offset := angle_difference(wind_direction, desired)
	var limit := deg_to_rad(CLOSE_HAULED_LIMIT + POINTING_MARGIN)
	if absf(offset) >= limit:
		return desired
	return wrapf(wind_direction + (limit if offset >= 0.0 else -limit), -PI, PI)
