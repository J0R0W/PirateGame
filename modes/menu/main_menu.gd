## Startbildschirm.
##
## Zugleich der Funktionstest fuer das Geruest: Die Szene beweist, dass alle
## Autoloads geladen sind und miteinander reden.
extends Control

const SAVE_SLOT: int = 1
## Steht unter dem Titel. Hier und nicht in der Szene, damit der Stand nicht
## in einer .tscn veraltet, die niemand mehr aufmacht.
const SUBTITLE: String = "Meilenstein M3 — Handel und Haefen"

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel
@onready var _background: ColorRect = %Background
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle


func _ready() -> void:
	_background.color = Palette.fade(Palette.BACKDROP, 1.0)
	_title.add_theme_color_override("font_color", Palette.PARCHMENT)
	_subtitle.add_theme_color_override("font_color", Palette.MUTED)
	_status_label.add_theme_color_override("font_color", Palette.MUTED)
	_subtitle.text = SUBTITLE

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
