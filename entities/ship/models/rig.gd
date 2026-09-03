## Eine schwenkbare Takelage: Rah und Segel, die zusammen zum Wind stehen.
##
## Bis hierher hingen alle Segel starr in der Mittschiffsebene. Das fiel kaum
## auf, solange ein Schiff eine weisse Flaeche an einem Stock war - bei drei
## Lateinern faellt es sofort auf, weil das Tuch dann sichtbar in die falsche
## Richtung steht.
##
## [b]Der Mast gehoert nicht hierher.[/b] Ein Mast dreht nicht, die Rah dreht
## sich um ihn. Bei der Karavelle steht der Mast deshalb als eigener Knoten
## daneben; bei der Schaluppe, deren Mast senkrecht und rund ist, sitzt das
## Skript der Einfachheit halber am ganzen Mastknoten - eine Drehung um die
## eigene Achse sieht man einem Zylinder nicht an.
class_name Rig
extends Node3D

## Winkel der Segelsehne zur Mittschiffslinie in Ruhe, in Grad.
##
## Rahsegel 90 (quer), Lateiner 0 (laengs). Siehe [method SailingMath.sail_trim] -
## ohne diesen Wert schwenkte eines der beiden Rigg verkehrt herum.
@export var rest_chord_deg: float = 90.0

## Soweit schwenkt die Rah hoechstens aus, in Grad.
@export var max_swing_deg: float = 75.0

## Wie traege die Schoten anholen, in Sekunden.
##
## Nicht sofort: Eine Rah, die einem drehenden Wind ohne Verzoegerung folgt,
## sieht aus, als sei sie angeschraubt. Und beim Halsen soll das Tuch sichtbar
## herueberkommen.
@export var trim_inertia: float = 1.8

var _trim: float = 0.0


## Stellt die Rah zum Wind. Wird von [Ship] je Physikschritt gerufen.
func aim(ship_heading: float, wind_direction: float, delta: float) -> void:
	var target := SailingMath.sail_trim(
		ship_heading,
		wind_direction,
		deg_to_rad(rest_chord_deg),
		deg_to_rad(max_swing_deg))
	_trim = SailingMath.approach(_trim, target, trim_inertia, delta)
	# Der Ausschlag einer Rah ist kein Kurs, sondern eine Drehung im Schiff.
	rotation.y = _trim  # kein Kurs


## Der aktuelle Ausschlag in Grad - fuer Anzeigen und Tests.
func trim_degrees() -> float:
	return rad_to_deg(_trim)
