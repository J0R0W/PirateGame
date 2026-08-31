## Alles, was die Ballistik ueber ein Ziel wissen muss - und nicht mehr.
##
## Ohne diese Klasse braeuchte [method Gunnery.resolve_salvo] zwoelf Parameter,
## von denen fuenf zusammengehoeren. Sie ist bewusst eine reine Datenablage:
## [Gunnery] darf keinen Node kennen, sonst laesst sich das Gefecht nicht mehr
## ohne Szene pruefen (Regel B3).
##
## Die Masse sind die des Rumpfes. Dass ein Schiff quer zum Schuetzen ein
## grosses Ziel ist und mit dem Bug voran ein schmales, faellt damit von selbst
## an - siehe [method Gunnery.hits_target].
class_name TargetProfile
extends RefCounted

## Mittelpunkt des Rumpfes in der Weltebene.
var position: Vector2 = Vector2.ZERO
## Fahrt in Metern je Sekunde, ebenfalls in der Ebene. Aus ihr entsteht das
## Vorhalten.
var velocity: Vector2 = Vector2.ZERO
## Kurs als Navigationswinkel - die Richtung, in die der Rumpf zeigt.
var heading: float = 0.0
var half_length: float = 3.6
var half_beam: float = 1.3


static func make(
	position: Vector2,
	velocity: Vector2,
	heading: float,
	half_length: float,
	half_beam: float
) -> TargetProfile:
	var profile := TargetProfile.new()
	profile.position = position
	profile.velocity = velocity
	profile.heading = heading
	profile.half_length = half_length
	profile.half_beam = half_beam
	return profile
