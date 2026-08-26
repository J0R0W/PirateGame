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
