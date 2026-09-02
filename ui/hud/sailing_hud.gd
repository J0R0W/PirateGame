## Anzeigen fuer den Segelmodus.
##
## Zeigt nur, was der Spieler zum Navigieren und Handeln braucht: Kurs zum
## Wind, Fahrt, Segelstellung, Wind, Zustand, Gold und Laderaum.
##
## Die Farben stehen hier und nicht in der Szene: In der .tscn waeren es
## Zahlenkolonnen, die niemand mit der Palette abgleicht. Die Szene bestimmt
## die Anordnung, dieses Skript die Farbe.
extends Control

## So lange bleibt eine Meldung stehen.
const NOTICE_SECONDS: float = 3.5

## Ab hier wird ein fremdes Segel als Ziel angezeigt.
##
## Dieselbe Reichweite, ab der die Kamera es einrahmt: Was hier steht, ist auch
## zu sehen. Vorher waren es 900 Meter, und das HUD meldete Gegner, die
## ausserhalb des Bildes lagen.
const TARGET_RANGE: float = Gunnery.ENGAGEMENT_RANGE

var ship: Ship
## Das Gefecht - dieselbe Szene, nicht ein anderer Modus. Das HUD fragt hier
## nach, wer in Reichweite ist, statt fuer jede Zahl ein Signal zu bekommen.
var combat: NavalCombat

@onready var _compass: Control = %Compass
@onready var _point_of_sail: Label = %PointOfSail
@onready var _speed: Label = %Speed
@onready var _sail: Label = %Sail
@onready var _wind: Label = %Wind
@onready var _condition: Label = %Condition
@onready var _clock: Label = %Clock
@onready var _purse: Label = %Purse
@onready var _hold: Label = %Hold
@onready var _dock_prompt: Label = %DockPrompt
@onready var _notice: Label = %Notice
@onready var _target_name: Label = %TargetName
@onready var _target_class: Label = %TargetClass
@onready var _target_condition: Label = %TargetCondition
@onready var _port_battery: Label = %PortBattery
@onready var _starboard_battery: Label = %StarboardBattery

var _notice_timer: float = 0.0

## Die drei Aufforderungen, die sich die Leertaste teilen. Siehe _refresh_prompt.
var _prize_prompt: String = ""
var _boarding_prompt: String = ""
var _dock_prompt_text: String = ""
## Steht der Hafen in Reichweite dem Spieler offen?
var _dock_closed: bool = false


func _ready() -> void:
	_paint(_clock, Palette.HUD_DIM)
	_paint(_purse, Palette.BRASS)
	_paint(_hold, Palette.HUD_DIM)
	_paint($Hint as Label, Palette.fade(Palette.HUD_DIM, 0.55))
	_paint(_speed, Palette.HUD_TEXT)
	_paint(_sail, Palette.HUD_DIM)
	_paint(_wind, Palette.BRASS)
	_paint(_point_of_sail, Palette.GOOD)
	_paint(_condition, Palette.GOOD)
	_paint(_dock_prompt, Palette.PARCHMENT)
	_paint(_notice, Palette.BAD)
	_paint(_target_name, Palette.PARCHMENT)
	_paint(_target_class, Palette.HUD_DIM)
	_paint(_target_condition, Palette.HUD_TEXT)
	_paint(_port_battery, Palette.HUD_TEXT)
	_paint(_starboard_battery, Palette.HUD_TEXT)

	EventBus.dock_target_changed.connect(_on_dock_target_changed)
	EventBus.prize_target_changed.connect(_on_prize_target_changed)
	EventBus.ran_aground.connect(_on_ran_aground)
	EventBus.sail_sighted.connect(_on_sail_sighted)
	EventBus.ship_struck.connect(_on_ship_struck)
	EventBus.prize_taken.connect(_on_prize_taken)
	EventBus.boarding_target_changed.connect(_on_boarding_target_changed)
	EventBus.boarding_resolved.connect(_on_boarding_resolved)
	EventBus.player_struck.connect(_on_player_struck)
	EventBus.letter_changed.connect(_on_letter_changed)
	EventBus.named_captain_sighted.connect(_on_named_captain_sighted)
	EventBus.commission_changed.connect(_on_commission_changed)
	EventBus.treaties_changed.connect(_on_treaties_changed)


func setup(target: Ship, battle: NavalCombat = null) -> void:
	ship = target
	combat = battle
	_compass.ship = target


func _process(delta: float) -> void:
	if ship == null:
		return

	if ship.aground:
		_point_of_sail.text = "Auf Grund"
		_paint(_point_of_sail, Palette.BAD)
	else:
		_point_of_sail.text = ship.point_of_sail()
		_paint(_point_of_sail, _state_color(ship.efficiency()))

	_speed.text = "%.1f kn" % ship.speed
	_sail.text = ship.sail_name()
	_wind.text = "%d°  ·  %.0f %%" % [
		wrapi(int(rad_to_deg(WorldData.wind_direction)), 0, 360),
		WorldData.wind_strength * 100.0,
	]

	# Die Mannschaft steht mit dabei, seit sie im Gefecht etwas bedeutet: Wer
	# Leute verliert, laedt langsamer und trifft schlechter (siehe Gunnery).
	#
	# Gefaerbt wird nach der Bedienung, nicht nach dem Anteil an der Hoechstzahl.
	# Eine Schaluppe faehrt mit vierzig Mann und braucht sechzehn - die Haelfte
	# der Mannschaft zu verlieren sieht nach der Haelfte aus, kostet aber noch
	# keinen einzigen Ladevorgang.
	var worst := minf(
		minf(
			float(GameState.hull) / float(maxi(GameState.max_hull(), 1)),
			GameState.sail_condition()
		),
		GameState.readiness()
	)

	# Unter der Mindestbesatzung kostet es Fahrt (Ship.handling). Das ist die
	# einzige Verschlechterung im Spiel, die man sonst nirgends abliest: Der
	# Knotenmesser zeigt zu wenig, und das Schiff sieht unbeschaedigt aus.
	# Deshalb steht der Grund an der Mannschaft und die Folge an der Fahrt.
	var undermanned := GameState.handling() < 1.0
	if undermanned:
		# Die Mindestbesatzung steht nur dann dabei, wenn sie unterschritten ist -
		# sonst waere sie eine Zahl, die sich nie aendert und nichts erklaert.
		_condition.text = "Rumpf %d  ·  Segel %d  ·  %d von %d Mann  ·  unterbesetzt" % [
			GameState.hull, GameState.sails, GameState.crew, GameState.min_crew()
		]
	else:
		_condition.text = "Rumpf %d  ·  Segel %d  ·  %d Mann" % [
			GameState.hull, GameState.sails, GameState.crew
		]
	_paint(_condition, _state_color(worst))
	_paint(_speed, Palette.BAD if undermanned else Palette.HUD_TEXT)

	_purse.text = "%d Gold" % GameState.gold
	_hold.text = "Laderaum %d / %d" % [GameState.cargo_used(), GameState.cargo_capacity()]

	var minutes := int(GameState.game_minutes) % 1440
	_clock.text = "Tag %d  ·  %02d:%02d" % [
		GameState.current_day() + 1, minutes / 60, minutes % 60
	]

	_update_target()
	_update_notice(delta)


## Zustandsfarbe fuer einen Anteil von 0 bis 1. Dieselben Schwellen fuer
## Segelwirkung und Schiffszustand - der Spieler soll eine Farbe lernen, nicht
## zwei Skalen.
func _state_color(fraction: float) -> Color:
	if fraction >= 0.9:
		return Palette.GOOD
	elif fraction >= 0.4:
		return Palette.FAIR
	return Palette.BAD


# --- Gefecht ---------------------------------------------------------------

## Zeigt den naechsten Gegner und den Zustand der eigenen Batterien.
##
## Die Batterieanzeige ist der Kern von Regel A8: Sie leuchtet genau dann auf,
## wenn eine Breitseite auch treffen wuerde. Wer darauf achtet, lernt den
## Feuerbereich, ohne dass ihn jemand erklaert.
func _update_target() -> void:
	var enemy := _nearest_enemy()
	if enemy == null:
		_target_name.text = ""
		_target_class.text = ""
		_target_condition.text = ""
		_paint_battery(_port_battery, "Q   Backbord",
			ship.battery_progress(Gunnery.PORT), false)
		_paint_battery(_starboard_battery, "Steuerbord   E",
			ship.battery_progress(Gunnery.STARBOARD), false)
		return

	var distance := ship.plan_position().distance_to(enemy.plan_position())
	var nation := WorldData.get_nation(enemy.nation_id)
	var class_name_text := enemy.ship_class.display_name if enemy.ship_class != null else "Segler"

	# Das Verhaeltnis zur Nation steht dabei, seit es entscheidet, ob dieses
	# Segel angreift oder vorbeifaehrt. Ohne die Angabe sieht ein Ueberfall
	# nach Willkuer aus - dabei ist er die Folge der eigenen letzten Prise.
	#
	# Ein benannter Kapitaen steht mit Namen da. Das ist die Wiedererkennung,
	# auf der Auftrag und Kopfgeld beruhen: Ohne sie waere die Fregatte am
	# Horizont nur eine weitere Patrouille (Regel A8).
	_target_name.text = enemy.ship_name if enemy.captain_name.is_empty() else (
		"Kapitän %s   ·   %s" % [enemy.captain_name, enemy.ship_name]
	)
	_target_class.text = "%s%s   ·   %d m   ·   %s" % [
		"%se " % nation.adjective.capitalize() if nation != null else "",
		class_name_text,
		int(distance),
		Standing.title_of(GameState.standing_with(enemy.nation_id)),
	]
	if enemy.struck:
		_target_condition.text = "Flagge gestrichen"
		_paint(_target_condition, Palette.GOOD)
	else:
		_target_condition.text = "Rumpf %d %%   ·   Segel %d %%" % [
			int(round(enemy.hull_fraction() * 100.0)),
			int(round(enemy.sail_health() * 100.0)),
		]
		_paint(_target_condition, _state_color(enemy.hull_fraction()))

	var bearing := SailingMath.bearing(ship.plan_position(), enemy.plan_position())
	for side: int in [Gunnery.PORT, Gunnery.STARBOARD]:
		var bears := distance <= Gunnery.MAX_RANGE and Gunnery.bears(
			ship.heading(), bearing, side, ship.gun_traverse
		)
		var label := _port_battery if side == Gunnery.PORT else _starboard_battery
		var caption := "Q   Backbord" if side == Gunnery.PORT else "Steuerbord   E"
		_paint_battery(label, caption, ship.battery_progress(side), bears)


## Die Beschriftung einer Batterie.
##
## "Liegt an" ist seit der Umstellung auf gerichtete Rohre woertlich zu nehmen:
## Es steht genau dann da, wenn die Kugeln den Gegner auch bekommen. Vorher war
## es eine Schwelle auf einer Wahrscheinlichkeit, und ein Spieler konnte
## danebenschiessen, obwohl das HUD gruen leuchtete.
##
## Farbregel A5: Gruen heisst gut fuer dich. Nachladen wird abgeblendet, nicht
## rot - rot bedeutet in diesem Spiel Schaden.
func _paint_battery(label: Label, caption: String, progress: float, bears: bool) -> void:
	if progress < 1.0:
		label.text = "%s   lädt %d %%" % [caption, int(progress * 100.0)]
		_paint(label, Palette.fade(Palette.HUD_DIM, 0.45))
	elif bears:
		label.text = "%s   liegt an" % caption
		_paint(label, Palette.GOOD)
	else:
		label.text = "%s   bereit" % caption
		_paint(label, Palette.HUD_TEXT)


func _nearest_enemy() -> Ship:
	return combat.nearest_enemy(TARGET_RANGE) if combat != null else null


func _on_sail_sighted(ship_name: String, nation_id: int, warship: bool) -> void:
	var nation := WorldData.get_nation(nation_id)
	var flag := "%ses " % nation.adjective.capitalize() if nation != null else ""
	show_notice("Segel in Sicht:  %s%s" % [
		flag, "Kriegsschiff" if warship else "Handelsschiff"
	], Palette.PARCHMENT)


## Ein Steckbrief ist am Horizont aufgetaucht.
##
## Eigene Meldung neben "Segel in Sicht", und in einer anderen Farbe: Ein
## Jaeger ist eine Warnung (BAD), ein Gesuchter eine Gelegenheit (BRASS, wie
## jede andere Sache des Kaperbriefs). Wer beides in dieselbe Zeile schriebe,
## verloere genau den Unterschied, auf den es ankommt.
func _on_named_captain_sighted(
	captain_name: String, ship_name: String, nation_id: int, hunting: bool
) -> void:
	var nation := WorldData.get_nation(nation_id)
	var crown := nation.display_name if nation != null else "Eine fremde Krone"
	if hunting:
		show_notice("Kopfgeldjäger:  Kapitän %s   ·   %s   ·   %s sucht dich" % [
			captain_name, ship_name, crown
		], Palette.BAD)
	else:
		show_notice("Der Gesuchte:  Kapitän %s   ·   %s   ·   %s" % [
			captain_name, ship_name, crown
		], Palette.BRASS)


## Was ein Auftrag auf See macht.
##
## Nur zwei der vier Faelle kommen hier vor: Angenommen und gemeldet wird im
## Palast, und dort laeuft dieses Signal in eine andere Szene. Erledigt und
## abgelaufen passieren dagegen genau hier - das eine mitten im Gefecht, das
## andere beim stillen Tageswechsel, wo es sonst niemandem auffiele.
func _on_commission_changed(change: int) -> void:
	match change:
		Commission.Change.FULFILLED:
			show_notice(
				"Auftrag erledigt — melde dich beim Gouverneur.", Palette.GOOD
			)
		Commission.Change.FAILED:
			show_notice("Der Auftrag ist verfallen.", Palette.BAD)


func _on_ship_struck(ship_name: String) -> void:
	show_notice("%s streicht die Flagge!" % ship_name, Palette.GOOD)


## Was eine Prise eingebracht hat - und wem sie gutgeschrieben wird.
##
## Der Kaperbrief steht in derselben Zeile und nicht in einer eigenen Meldung:
## Es ist dieselbe Tat, und die Meldezeile hat nur Platz fuer eine davon.
func _on_prize_taken(ship_name: String, nation_id: int, gold: int, units: int) -> void:
	var text := "Prise %s:  %d Gold, %d Einheiten" % [ship_name, gold, units]
	if GameState.letter_covers(nation_id):
		var patron := GameState.letter_patron()
		if patron != null:
			text += "   ·   %s schreibt sie gut" % patron.display_name
	show_notice(text, Palette.BRASS)


## Die Kronen haben ihre Buendnisse neu geordnet.
##
## Das Ereignis, das der Spieler am wenigsten kommen sieht - es passiert im
## Kalender, nicht auf See. Deshalb steht es ueberhaupt im HUD: Ohne die
## Meldung faende man erst beim naechsten Aufbringen heraus, dass der Brief
## eine andere Flagge deckt als gestern.
##
## Wer einen Brief traegt, liest, was es fuer ihn heisst; wer keinen hat, die
## neue Lage. Beides in einer Zeile waere zu lang und das Wichtige ganz hinten.
func _on_treaties_changed(_day: int) -> void:
	var patron := GameState.letter_patron()
	if patron != null:
		var enemy := WorldData.get_nation(WorldData.enemy_of(patron.id))
		if enemy != null:
			show_notice(
				"Neue Bündnisse:  Dein %ser Kaperbrief deckt jetzt %se Prisen."
				% [patron.adjective, enemy.adjective], Palette.BRASS
			)
			return

	var parts: PackedStringArray = []
	for war: Vector2i in WorldData.wars():
		var first := WorldData.get_nation(war.x)
		var second := WorldData.get_nation(war.y)
		if first != null and second != null:
			parts.append("%s gegen %s" % [first.subject_name(), second.subject_name()])
	if parts.is_empty():
		return
	show_notice(
		"Neue Bündnisse:  %s" % "   ·   ".join(parts), Palette.PARCHMENT
	)


## Der Kaperbrief hat sich geaendert.
##
## Auf See gibt es dafuer nur einen Grund: Wer den eigenen Auftraggeber
## aufbringt, verliert ihn auf der Stelle. Angenommen und zurueckgegeben wird
## im Gouverneurspalast, und dort laeuft dieses Signal in eine andere Szene.
func _on_letter_changed(nation_id: int) -> void:
	if nation_id != LetterOfMarque.NONE:
		return
	show_notice("Der Kaperbrief ist eingezogen.", Palette.BAD)


func _on_player_struck(lost_gold: int, lost_units: int) -> void:
	show_notice("Gefecht verloren:  %d Gold und %d Einheiten geplündert"
		% [lost_gold, lost_units], Palette.BAD)


## Prise, Entern und Hafen teilen sich eine Zeile und liegen auf derselben
## Taste. Deshalb merkt sich das HUD alle drei und baut die Zeile an einer
## Stelle zusammen - sonst loescht das Signal des einen die Aufforderung des
## anderen, und die Leertaste tut etwas, das nirgends steht.
##
## Die Reihenfolge ist dieselbe wie in SailingMode._unhandled_input. Wer sie
## hier aendert, aendert sie dort mit.
func _refresh_prompt() -> void:
	if not _prize_prompt.is_empty():
		_dock_prompt.text = _prize_prompt
		_paint(_dock_prompt, Palette.PARCHMENT)
	elif not _boarding_prompt.is_empty():
		_dock_prompt.text = _boarding_prompt
		_paint(_dock_prompt, Palette.PARCHMENT)
	else:
		_dock_prompt.text = _dock_prompt_text
		# Ein verschlossener Hafen ist keine Aufforderung, sondern eine Absage -
		# er wird abgeblendet statt in der Farbe einer Taste zu leuchten.
		_paint(_dock_prompt, Palette.MUTED if _dock_closed else Palette.PARCHMENT)


func _on_prize_target_changed(ship_name: String) -> void:
	_prize_prompt = "" if ship_name.is_empty() 		else "Leertaste   ·   %s aufbringen" % ship_name
	_refresh_prompt()


func _on_boarding_target_changed(ship_name: String) -> void:
	_boarding_prompt = "" if ship_name.is_empty() 		else "Leertaste   ·   %s entern" % ship_name
	_refresh_prompt()


## Was ein Sturm gekostet hat. Beide Zahlen stehen da, auch die eigene: Wer
## entert, soll die Rechnung sehen und beim naechsten Mal abwaegen koennen.
func _on_boarding_resolved(
	ship_name: String, won: bool, own_losses: int, their_losses: int
) -> void:
	if won:
		show_notice("%s geentert!   %d eigene Gefallene, %d gegnerische"
			% [ship_name, own_losses, their_losses], Palette.GOOD)
	else:
		show_notice("Sturm auf %s abgeschlagen:   %d eigene Gefallene, %d gegnerische"
			% [ship_name, own_losses, their_losses], Palette.BAD)


# --- Hafen -----------------------------------------------------------------

func _on_dock_target_changed(town_id: int) -> void:
	var town := WorldData.get_town(town_id)
	_dock_closed = town != null and not Standing.port_open(
		GameState.standing_with(town.nation_id)
	)
	if town == null:
		_dock_prompt_text = ""
	elif _dock_closed:
		# Es steht da, bevor die Taste gedrueckt wird: Wer vor einem
		# verschlossenen Hafen liegt, soll das sehen und nicht ausprobieren.
		_dock_prompt_text = "%s ist dir verschlossen" % town.town_name
	else:
		_dock_prompt_text = "Leertaste   ·   In %s anlegen" % town.town_name
	_refresh_prompt()


func _on_ran_aground(damage: int) -> void:
	show_notice("Aufgelaufen!   %d Rumpfschaden" % damage)


## Blendet eine Meldung ein, die von selbst wieder verschwindet.
func show_notice(text: String, color: Color = Palette.BAD) -> void:
	_notice.text = text
	_paint(_notice, color)
	_notice.modulate.a = 1.0
	_notice_timer = NOTICE_SECONDS


func _update_notice(delta: float) -> void:
	if _notice_timer <= 0.0:
		return
	_notice_timer -= delta
	# Die letzte Sekunde ausblenden, statt die Meldung wegzuschalten.
	_notice.modulate.a = clampf(_notice_timer, 0.0, 1.0)
	if _notice_timer <= 0.0:
		_notice.text = ""


func _paint(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.HUD_OUTLINE)
