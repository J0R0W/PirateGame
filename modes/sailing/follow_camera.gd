## Verfolgerkamera hinter dem Schiff.
##
## Folgt Position und Kurs bewusst traege: Die Kamera zieht in der Wende nach
## aussen und holt erst danach auf. Das laesst das Schiff schwer wirken.
extends Node3D

@export var target: Node3D

@export_group("Ausrichtung")
## Abstand hinter dem Schiff in Metern.
@export var distance: float = 22.0
@export var height: float = 9.0
## Blickpunkt oberhalb des Schiffs, damit der Horizont sichtbar bleibt.
@export var look_height: float = 3.0

@export_group("Traegheit")
## Wie schnell die Kamera der Position folgt.
@export var follow_speed: float = 4.0
## Wie schnell sie dem Kurs folgt - niedriger als follow_speed, sonst klebt sie.
@export var turn_speed: float = 1.8

@export_group("Zoom")
@export var min_distance: float = 9.0
@export var max_distance: float = 55.0
@export var zoom_step: float = 3.0

## Kurs, dem die Kamera gerade folgt - als Navigationswinkel, nicht als
## Godot-Rotation. Siehe docs/RICHTLINIEN.md.
var _yaw: float = 0.0
var _distance: float = 22.0


func _ready() -> void:
	_distance = distance
	snap()


## Setzt die Kamera ohne Uebergang hinter das Ziel.
##
## Noetig, wenn das Schiff versetzt wird statt zu fahren - beim Auslaufen aus
## einem Hafen zum Beispiel. Ohne das flog die Kamera aus dem Weltmittelpunkt
## quer ueber die Karibik hinterher und stand dabei sekundenlang irgendwo im
## Nirgendwo.
func snap() -> void:
	if target == null:
		return
	_yaw = _target_heading()
	global_position = _desired_position()
	look_at(target.global_position + Vector3.UP * look_height)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_step)


func _process(delta: float) -> void:
	if target == null:
		return
	_yaw = lerp_angle(_yaw, _target_heading(), 1.0 - exp(-delta * turn_speed))
	global_position = global_position.lerp(
		_desired_position(), 1.0 - exp(-delta * follow_speed)
	)
	look_at(target.global_position + Vector3.UP * look_height)


func _zoom(amount: float) -> void:
	_distance = clampf(_distance + amount, min_distance, max_distance)


## Kurs des Ziels aus seinem Vorwaertsvektor - funktioniert fuer jeden Node3D,
## ohne dessen Rotation direkt zu lesen.
func _target_heading() -> float:
	var forward := -target.global_basis.z
	return SailingMath.angle_of(Vector2(forward.x, forward.z))


func _desired_position() -> Vector3:
	# Die Kamera steht hinter dem Ziel, also entgegen seiner Fahrtrichtung.
	var astern := -SailingMath.direction(_yaw) * _distance
	var lift := Vector3.UP * (height * (_distance / distance))
	return target.global_position + Vector3(astern.x, 0.0, astern.y) + lift
