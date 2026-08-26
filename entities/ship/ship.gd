## Ein Segelschiff. Im Prototyp der Spieler, spaeter auch KI-Schiffe.
##
## Gesteuert wird ausschliesslich Ruder und Segelstellung - nie direkt die
## Geschwindigkeit. Die Fahrt ergibt sich aus dem Winkel zum Wind.
class_name Ship
extends CharacterBody3D

signal sail_setting_changed(step: int)

@export_group("Fahrverhalten")
## Knoten bei idealem Wind und voller Besegelung.
@export var base_speed: float = 12.0
## Grad pro Sekunde bei voller Fahrt.
@export var turn_rate_deg: float = 34.0
## Wie traege die Fahrt auf Segelaenderungen reagiert, in Sekunden.
@export var speed_inertia: float = 4.5
## Wie traege das Ruder anspricht, in Sekunden.
@export var turn_inertia: float = 1.2
## Wieviel Fahrt noetig ist, um ueberhaupt zu wenden. Unterhalb treibt das
## Schiff nur noch.
@export var min_steerage: float = 0.12

@export_group("Steuerung")
## Nimmt dieses Schiff Tastatureingaben entgegen?
@export var player_controlled: bool = true

## Aktuelle Fahrt in Knoten.
var speed: float = 0.0
## Stufe aus SailingMath.SAIL_STEPS.
var sail_step: int = 2
## Aktuelle Ruderlage, -1.0 bis 1.0.
var helm: float = 0.0

## Rumpfmasse fuer das Abtasten der Wellen, in Metern.
const HALF_LENGTH: float = 3.6
const HALF_BEAM: float = 1.3
## Ein 8-Meter-Rumpf folgt der See gedaempft, nicht eins zu eins.
const PITCH_DAMPING: float = 0.55
const ROLL_DAMPING: float = 0.7
## Krängung bei vollem Ruder.
const HEEL_DEGREES: float = 7.0

@onready var _sail: Node3D = $Hull/Mast/Sail


func _ready() -> void:
	_update_sail_visual()


func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled:
		return
	if event.is_action_pressed("sails_more"):
		_set_sail_step(sail_step + 1)
	elif event.is_action_pressed("sails_less"):
		_set_sail_step(sail_step - 1)


func _physics_process(delta: float) -> void:
	var helm_input := 0.0
	if player_controlled:
		helm_input = Input.get_axis("helm_port", "helm_starboard")

	# Ruder spricht traege an - kein sofortiges Einrasten.
	helm = SailingMath.approach(helm, helm_input, turn_inertia, delta)

	# Fahrt aus Wind, Kurs und Segelstellung.
	var goal := SailingMath.target_speed(
		base_speed,
		heading(),
		WorldData.wind_direction,
		WorldData.wind_strength,
		SailingMath.SAIL_STEPS[sail_step]
	)
	speed = SailingMath.approach(speed, goal, speed_inertia, delta)

	# Ohne Fahrt greift das Ruder nicht. Deshalb faehrt man sich in Irons fest.
	var steerage := clampf(speed / (base_speed * min_steerage), 0.0, 1.0)
	rotation.y -= helm * deg_to_rad(turn_rate_deg) * steerage * delta

	# Knoten in Meter pro Sekunde: 1 kn ~ 0.514 m/s.
	velocity = -global_basis.z * speed * 0.514
	move_and_slide()

	_apply_swell(delta)


## Kurs des Schiffs im Projekt-Winkelraum: 0 = Norden (-Z), positiv nach Osten.
func heading() -> float:
	return wrapf(rotation.y, -PI, PI)


## Kurs zum Wind, aufbereitet fuers HUD.
func point_of_sail() -> String:
	return SailingMath.point_of_sail(heading(), WorldData.wind_direction)


func efficiency() -> float:
	return SailingMath.sail_efficiency(heading(), WorldData.wind_direction)


func sail_name() -> String:
	return SailingMath.SAIL_NAMES[sail_step]


func _set_sail_step(step: int) -> void:
	var clamped := clampi(step, 0, SailingMath.SAIL_STEPS.size() - 1)
	if clamped == sail_step:
		return
	sail_step = clamped
	_update_sail_visual()
	sail_setting_changed.emit(sail_step)


## Das Segel zeigt die Stellung direkt an - gerefft ist es schmaler.
func _update_sail_visual() -> void:
	if _sail == null:
		return
	var amount := SailingMath.SAIL_STEPS[sail_step]
	var tween := create_tween()
	tween.tween_property(_sail, "scale", Vector3(1.0, maxf(amount, 0.06), 1.0), 0.4) \
		.set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(_sail, "visible", amount > 0.0, 0.0)


## Das Schiff reitet auf den Wellen, die der Shader zeichnet.
##
## Statt einer Wackelanimation wird die Wasserhoehe an vier Punkten des Rumpfes
## abgetastet - Bug, Heck, beide Seiten. Daraus ergeben sich Tiefgang, Stampfen
## und Rollen von selbst, und sie passen zur sichtbaren See.
func _apply_swell(delta: float) -> void:
	var t := OceanWaves.time_now()
	var pos := global_position
	var forward := -global_basis.z
	var starboard := global_basis.x

	var bow := pos + forward * HALF_LENGTH
	var stern := pos - forward * HALF_LENGTH
	var port := pos - starboard * HALF_BEAM
	var star := pos + starboard * HALF_BEAM

	var h_bow := OceanWaves.height_at(bow.x, bow.z, t)
	var h_stern := OceanWaves.height_at(stern.x, stern.z, t)
	var h_port := OceanWaves.height_at(port.x, port.z, t)
	var h_star := OceanWaves.height_at(star.x, star.z, t)

	# Der Rumpf mittelt ueber seine Laenge - er folgt nicht jeder Kraeuselung.
	var water := (h_bow + h_stern + h_port + h_star) * 0.25
	position.y = lerpf(position.y, water, 1.0 - exp(-delta * 6.0))

	# Stampfen aus dem Hoehenunterschied Bug zu Heck, Rollen quer dazu.
	var pitch := atan2(h_bow - h_stern, HALF_LENGTH * 2.0) * PITCH_DAMPING
	var roll := atan2(h_star - h_port, HALF_BEAM * 2.0) * ROLL_DAMPING

	# In der Wende krängt ein Segler nach aussen, nicht nach innen.
	roll += helm * deg_to_rad(HEEL_DEGREES) * clampf(speed / base_speed, 0.0, 1.0)

	rotation.x = lerp_angle(rotation.x, pitch, 1.0 - exp(-delta * 5.0))
	rotation.z = lerp_angle(rotation.z, roll, 1.0 - exp(-delta * 4.0))
