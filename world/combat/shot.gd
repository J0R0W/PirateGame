## Das Ergebnis eines einzelnen Kanonenschusses.
##
## Steht schon fest, bevor die Kugel fliegt - siehe [Gunnery]. Die Darstellung
## liest hier ab, wohin sie die Kugel schicken muss und was am Ende passiert.
class_name Shot
extends RefCounted

var hit: bool = false
## Getroffener Bereich, nur bei [member hit] gueltig.
var zone: int = Gunnery.Zone.HULL
var damage: int = 0

## Streuung um den Zielpunkt in Metern, quer und laengs zur Schussrichtung.
## Bei einem Treffer klein (der Rumpf ist getroffen), bei einem Fehlschuss so
## gross, dass die Fontaene sichtbar neben dem Ziel steht.
var scatter: Vector2 = Vector2.ZERO


func zone_name() -> String:
	match zone:
		Gunnery.Zone.SAILS:
			return "Takelage"
		Gunnery.Zone.CREW:
			return "Mannschaft"
		_:
			return "Rumpf"
