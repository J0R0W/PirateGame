## Startbildschirm - zugleich der Funktionstest fuer das M0-Geruest.
##
## Ersetzt in M1 durch ein richtiges Menue. Im Moment beweist die Szene vor
## allem, dass alle Autoloads geladen sind und miteinander reden.
extends Control

const SAVE_SLOT: int = 1

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_quit_button.pressed.connect(get_tree().quit)

	EventBus.gold_changed.connect(_on_gold_changed)

	_continue_button.disabled = not SaveManager.has_save(SAVE_SLOT)
	_refresh_status()


func _on_new_game_pressed() -> void:
	# Zufaelliger Seed - die gesamte Karibik haengt an dieser einen Zahl.
	var world_seed := randi()
	GameState.new_campaign("Kapitaen", world_seed)
	SceneRouter.to_sailing()


func _on_continue_pressed() -> void:
	if SaveManager.load_slot(SAVE_SLOT):
		SceneRouter.to_sailing()
	else:
		_status_label.text = "Spielstand konnte nicht geladen werden."


func _on_gold_changed(_new_amount: int) -> void:
	_refresh_status()


func _refresh_status() -> void:
	if not WorldData.generated:
		_status_label.text = "Bereit. Noch keine Welt erzeugt."
		return
	_status_label.text = "Seed %d  ·  %d Gold  ·  %d Mann  ·  Wind %d°" % [
		WorldData.world_seed,
		GameState.gold,
		GameState.crew,
		int(rad_to_deg(WorldData.wind_direction)),
	]
