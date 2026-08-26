## Zeigt die Siedlungen der Welt an - aber nur die in der Naehe.
##
## Es gibt rund dreissig Staedte auf 20 Kilometern. Alle dauerhaft im Baum zu
## halten kostet nichts an Rechenzeit, aber sie wuerden noch in zehn Kilometern
## Entfernung als Farbflecken auf dem Wasser stehen. Deshalb dasselbe Prinzip
## wie beim Gelaende: sichtbar, was in Reichweite liegt.
class_name TownMarkers
extends Node3D

## Ab hier ist eine Stadt gebaut und sichtbar. Etwas mehr als die Sichtweite
## des Gelaendes, damit ein Hafen nicht erst aus dem Nichts auftaucht.
@export var view_distance: float = 2600.0
## Wieviel weiter eine Stadt sein muss, bevor sie wieder verschwindet. Ohne
## diesen Abstand flackern Staedte genau auf der Grenze.
@export var hysteresis: float = 300.0

## Wessen Position entscheidet, was sichtbar ist?
var target: Node3D

## Stadt-Id -> TownMarker.
var _markers: Dictionary = {}
var _check_timer: float = 0.0

## Sekunden zwischen zwei Sichtpruefungen. Ein Schiff macht hoechstens
## sechs Meter pro Sekunde - jeden Frame zu pruefen waere Verschwendung.
const CHECK_INTERVAL: float = 0.5


func _process(delta: float) -> void:
	if target == null or not WorldData.generated:
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL
	_update_visibility()


func _update_visibility() -> void:
	var here := Vector2(target.global_position.x, target.global_position.z)

	for town: TownData in WorldData.towns:
		var distance := here.distance_to(town.position)
		var known: bool = _markers.has(town.id)

		if not known and distance <= view_distance:
			_spawn(town)
		elif known and distance > view_distance + hysteresis:
			var marker: TownMarker = _markers[town.id]
			_markers.erase(town.id)
			marker.queue_free()


func _spawn(town: TownData) -> void:
	var nation := WorldData.get_nation(town.nation_id)
	var marker := TownMarker.new()
	add_child(marker)
	marker.setup(town, nation.color if nation != null else Palette.WALL)
	_markers[town.id] = marker


## Wieviel Siedlungen gerade stehen - fuer die Sichtpruefung.
func loaded_count() -> int:
	return _markers.size()
