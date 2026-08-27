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

@export_group("Gefecht")
## Bis hierher richtet sich die Kamera nach einem Gegner. Dieselbe Zahl, die
## auch das HUD benutzt - siehe [constant Gunnery.ENGAGEMENT_RANGE].
@export var focus_range: float = Gunnery.ENGAGEMENT_RANGE
## Wie stark sie das tut. 0 = immer stur hinter dem Schiff, 1 = ganz auf den
## Gegner.
@export var focus_weight: float = 0.5
## Und soweit geht sie dabei zurueck, damit beide Schiffe ins Bild passen.
@export var focus_pullback: float = 9.0
## Soweit rueckt der Blickpunkt hoechstens zum Gegner hin, in Metern.
##
## Ein fester Abstand und kein Anteil der Entfernung: Bei einem Gegner in 500
## Metern sind selbst sieben Prozent ein Blickpunkt 35 Meter neben dem eigenen
## Schiff - und die Kamera steht nur 22 Meter dahinter. Das eigene Schiff lag
## damit am Bildrand.
@export var focus_lead: float = 18.0

@export_group("Zoom")
@export var min_distance: float = 9.0
@export var max_distance: float = 55.0
@export var zoom_step: float = 3.0

## Kurs, dem die Kamera gerade folgt - als Navigationswinkel, nicht als
## Godot-Rotation. Siehe docs/RICHTLINIEN.md.
## Zweites Schiff, das im Bild bleiben soll - im Gefecht der Gegner. Setzt der
## Segelmodus, sonst null.
##
## Ohne das ist ein Seegefecht unsichtbar: Wer eine Breitseite abgeben will,
## hat den Gegner querab, und querab liegt bei einer Heckkamera ausserhalb des
## Bildes. In der ersten Aufnahme stand im HUD "Zeelandia - 700 m", und auf dem
## Bildschirm war nur offene See.
var focus: Node3D

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
	_yaw = _desired_yaw()
	global_position = _desired_position()
	look_at(_look_point())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_step)


func _process(delta: float) -> void:
	if target == null:
		return
	_yaw = lerp_angle(_yaw, _desired_yaw(), 1.0 - exp(-delta * turn_speed))
	global_position = global_position.lerp(
		_desired_position(), 1.0 - exp(-delta * follow_speed)
	)
	look_at(_look_point())


func _zoom(amount: float) -> void:
	_distance = clampf(_distance + amount, min_distance, max_distance)


## Kurs des Ziels aus seinem Vorwaertsvektor - funktioniert fuer jeden Node3D,
## ohne dessen Rotation direkt zu lesen.
func _target_heading() -> float:
	var forward := -target.global_basis.z
	return SailingMath.angle_of(Vector2(forward.x, forward.z))


func _desired_position() -> Vector3:
	# Die Kamera steht hinter dem Ziel, also entgegen seiner Fahrtrichtung.
	var reach := _distance + focus_pullback * _focus_amount()
	var astern := -SailingMath.direction(_yaw) * reach
	var lift := Vector3.UP * (height * (reach / distance))
	return target.global_position + Vector3(astern.x, 0.0, astern.y) + lift


## Kurs, hinter den sich die Kamera legt.
##
## Ohne Gegner ist das der eigene Kurs. Mit Gegner dreht sie zu ihm hin - dann
## steht sie ihm gegenueber hinter dem eigenen Schiff, und beide sind im Bild.
func _desired_yaw() -> float:
	var own := _target_heading()
	var amount := _focus_amount()
	if amount <= 0.0:
		return own
	var toward := SailingMath.angle_of(_to_focus())
	return wrapf(own + angle_difference(own, toward) * amount, -PI, PI)


## Punkt, auf den die Kamera blickt - zwischen eigenem Schiff und Gegner, aber
## naeher am eigenen. Das Schiff bleibt die Hauptsache.
func _look_point() -> Vector3:
	var here := target.global_position + Vector3.UP * look_height
	var amount := _focus_amount()
	if amount <= 0.0:
		return here
	var toward := (focus.global_position - target.global_position).normalized()
	return here + toward * focus_lead * amount


## Wieviel Einfluss der Gegner auf die Kameraeinstellung hat, 0.0 bis 1.0.
## Blendet am Rand der Reichweite auf, damit die Kamera nicht springt, sobald
## ein Segel die Grenze passiert.
func _focus_amount() -> float:
	if focus == null or not is_instance_valid(focus) or target == null:
		return 0.0
	var distance_to_focus := _to_focus().length()
	if distance_to_focus > focus_range:
		return 0.0
	return focus_weight * clampf(
		(focus_range - distance_to_focus) / (focus_range * 0.35), 0.0, 1.0
	)


func _to_focus() -> Vector2:
	var offset := focus.global_position - target.global_position
	return Vector2(offset.x, offset.z)
