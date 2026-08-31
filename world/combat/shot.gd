## Das Ergebnis eines einzelnen Kanonenschusses.
##
## Steht fest, sobald die Breitseite faellt - siehe [Gunnery]. Neu gegenueber
## M4 ist, dass hier keine Streuung um das Ziel mehr steht, sondern die Bahn
## selbst: Wo das Rohr stand und wo die Kugel niedergeht. Ob das ein Treffer
## ist, hat die Geometrie entschieden und nicht ein Wurf.
class_name Shot
extends RefCounted

var hit: bool = false
## Getroffener Bereich, nur bei [member hit] gueltig.
var zone: int = Gunnery.Zone.HULL
var damage: int = 0

## Muendung dieses Rohres in der Weltebene. Die Rohre stehen ueber die Laenge
## des Schiffs verteilt, deshalb hat jede Kugel ihren eigenen Startpunkt.
var origin: Vector2 = Vector2.ZERO
## Wo die Kugel niedergeht - im Rumpf des Gegners oder im Wasser daneben.
## Die Darstellung fliegt genau hierhin, damit ein Fehlschuss sichtbar
## vorbeigeht und nicht irgendwo platscht.
var impact: Vector2 = Vector2.ZERO


func zone_name() -> String:
	match zone:
		Gunnery.Zone.SAILS:
			return "Takelage"
		Gunnery.Zone.CREW:
			return "Mannschaft"
		_:
			return "Rumpf"
