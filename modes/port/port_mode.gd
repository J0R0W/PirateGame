## Der Hafenbildschirm.
##
## Kein 3D: Der Hafen ist eine Liste von Entscheidungen, keine Gegend, durch
## die man laeuft. Das haelt den Modus klein und den Blick auf dem, was zaehlt
## - Preise, Zustand, Gold.
##
## Der Modus kennt weder Segelmodus noch Hauptmenue. Er weiss nur, in welcher
## Stadt er steht (GameState.current_port_id), und geht ueber den SceneRouter
## wieder hinaus.
extends Control

## Die Abteilungen des Hafens. Weitere - Taverne, Gouverneur, Handelshaus -
## kommen als eigene Eintraege dazu.
enum Section { MARKET, SHIPYARD }

## Reihenfolge im Menue. Eine Konstante statt der Aufzaehlung selbst, damit
## sich die Anordnung aendern laesst, ohne die Werte zu verschieben.
const SECTION_ORDER: Array[int] = [Section.MARKET, Section.SHIPYARD]
const SECTION_NAMES: Dictionary = {
	Section.MARKET: "Markt",
	Section.SHIPYARD: "Werft",
}

## So lange bleibt eine Rueckmeldung stehen.
const MESSAGE_SECONDS: float = 6.0

## Bis es mehrere Spielstaende gibt, benutzen Menue und Hafen denselben Platz.
const SAVE_SLOT: int = 1

@onready var _backdrop: ColorRect = %Backdrop
@onready var _town_name: Label = %TownName
@onready var _subtitle: Label = %Subtitle
@onready var _nav: VBoxContainer = %Nav
@onready var _content: VBoxContainer = %Content
@onready var _message: Label = %Message
@onready var _footer: Label = %Footer

var town: TownData
var _section: int = Section.MARKET
var _section_buttons: Dictionary = {}
## Der gerade sichtbare Bildschirm. Oeffentlich, damit die Sichtpruefung
## umschalten und den Inhalt neu zeichnen kann.
var panel: Node = null
var _message_timer: float = 0.0


func _ready() -> void:
	town = WorldData.get_town(GameState.current_port_id)
	if town == null:
		# Ohne Stadt gibt es nichts anzuzeigen. Das ist ein Programmfehler,
		# aber der Spieler soll nicht in einem leeren Bildschirm festsitzen.
		push_error("PortMode: keine Stadt unter Id %d" % GameState.current_port_id)
		SceneRouter.to_sailing()
		return

	_backdrop.color = Palette.fade(Palette.BACKDROP, 1.0)
	_town_name.add_theme_color_override("font_color", Palette.PARCHMENT)
	_subtitle.add_theme_color_override("font_color", Palette.MUTED)
	_footer.add_theme_color_override("font_color", Palette.HUD_TEXT)
	_message.add_theme_color_override("font_color", Palette.HUD_DIM)

	_town_name.text = town.town_name
	var nation := WorldData.get_nation(town.nation_id)
	_subtitle.text = "%s  ·  %s  ·  Tag %d" % [
		town.tier_name(),
		nation.display_name if nation != null else "unbekannt",
		GameState.current_day() + 1,
	]

	_build_navigation()
	show_section(Section.MARKET)
	_refresh_footer()

	EventBus.gold_changed.connect(_on_purse_changed)
	EventBus.cargo_changed.connect(_on_cargo_changed)
	EventBus.ship_condition_changed.connect(_on_condition_changed)


func _process(delta: float) -> void:
	if _message_timer <= 0.0:
		return
	_message_timer -= delta
	_message.modulate.a = clampf(_message_timer, 0.0, 1.0)
	if _message_timer <= 0.0:
		_message.text = ""


func _build_navigation() -> void:
	for section: int in SECTION_ORDER:
		var button := PortWidgets.button(SECTION_NAMES[section], 20)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.x = 150
		button.pressed.connect(show_section.bind(section))
		_nav.add_child(button)
		_section_buttons[section] = button

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	_nav.add_child(spacer)

	# Der Hafen ist der Speicherpunkt des Spiels: Hier steht die Zeit still,
	# und hier weiss der Spielstand genau, wo das Schiff liegt.
	var store := PortWidgets.button("Speichern", 20)
	store.alignment = HORIZONTAL_ALIGNMENT_LEFT
	store.pressed.connect(_save)
	_nav.add_child(store)

	var leave := PortWidgets.button("Ablegen", 20)
	leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
	leave.pressed.connect(_leave)
	_nav.add_child(leave)

	var hint := PortWidgets.label("Esc", Palette.fade(Palette.MUTED, 0.6), 13)
	_nav.add_child(hint)


func show_section(section: int) -> void:
	_section = section
	for known: int in _section_buttons:
		var button: Button = _section_buttons[known]
		button.add_theme_color_override(
			"font_color", Palette.PARCHMENT if known == section else Palette.MUTED
		)

	if panel != null:
		# Erst aus dem Baum nehmen, dann freigeben: queue_free() wirkt erst am
		# Bildende, sonst stuenden Markt und Werft kurz untereinander.
		_content.remove_child(panel)
		panel.queue_free()
		panel = null

	match section:
		Section.MARKET:
			var market := MarketPanel.new()
			market.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(market)
			market.setup(town)
			market.traded.connect(_show_message)
			panel = market
		Section.SHIPYARD:
			var yard := ShipyardPanel.new()
			yard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(yard)
			yard.setup(town)
			yard.repaired.connect(_show_message)
			panel = yard


func _show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	_message_timer = MESSAGE_SECONDS


func _refresh_footer() -> void:
	_footer.text = "%d Gold      Laderaum %d / %d      Rumpf %d      Segel %d" % [
		GameState.gold,
		GameState.cargo_used(), GameState.cargo_capacity(),
		GameState.hull, GameState.sails,
	]


func _on_purse_changed(_amount: int) -> void:
	_refresh_footer()


func _on_cargo_changed(_cargo_id: StringName, _amount: int) -> void:
	_refresh_footer()


func _on_condition_changed(_hull: int, _sails: int) -> void:
	_refresh_footer()
	# Der Marktbildschirm zeigt keinen Zustand, die Werft schon.
	if panel is ShipyardPanel:
		(panel as ShipyardPanel).refresh()


func _save() -> void:
	if SaveManager.save_slot(SAVE_SLOT):
		_show_message("Gespeichert.")
	else:
		_show_message("Der Spielstand liess sich nicht schreiben.")


func _leave() -> void:
	SceneRouter.leave_port()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_leave()
