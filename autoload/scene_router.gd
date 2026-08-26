## Wechselt zwischen den Modus-Szenen und blendet dabei ueber.
##
## Modi kennen einander nie direkt - sie kennen nur den Router.
## Siehe docs/KONZEPT.md, Abschnitt 7.2.
extends Node

const FADE_DURATION: float = 0.35

var current_mode_path: String = ""
var _fade_rect: ColorRect
var _switching: bool = false


func _ready() -> void:
	# Eigener CanvasLayer, damit die Blende ueber allem liegt.
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)


## Wechselt zur Szene unter [param scene_path] mit Ueberblendung.
func change_mode(scene_path: String) -> void:
	if _switching or scene_path == current_mode_path:
		return
	_switching = true

	await _fade(1.0)

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneRouter: Szene konnte nicht geladen werden: %s" % scene_path)
		await _fade(0.0)
		_switching = false
		return

	current_mode_path = scene_path
	EventBus.mode_changed.emit(scene_path)

	await _fade(0.0)
	_switching = false


func _fade(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.0)
	tween.parallel().tween_property(_fade_rect, "color:a", target_alpha, FADE_DURATION)
	await tween.finished


# --- Bequeme Einstiegspunkte, damit Aufrufer keine Pfade kennen muessen ---

func to_main_menu() -> void:
	GameState.time_running = false
	change_mode("res://modes/menu/main_menu.tscn")


func to_sailing() -> void:
	GameState.time_running = true
	change_mode("res://modes/sailing/sailing_mode.tscn")


func enter_port(town_id: int) -> void:
	GameState.time_running = false
	EventBus.port_entered.emit(town_id)
	# TODO(M3): change_mode("res://modes/port/port_mode.tscn")
