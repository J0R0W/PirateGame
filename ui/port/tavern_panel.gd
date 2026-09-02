## Die Schenke.
##
## Der vierte Hafenbildschirm, und der einzige, in dem man etwas erfaehrt
## statt etwas zu kaufen. Zwei Dinge stehen hier:
##
##   - **Anheuern.** Es stand bis M6 in der Werft, wo sein eigener Kommentar
##     sagte, dass es dorthin nicht gehoert.
##   - **Das Gerede.** Politik, der Aufenthalt des Gesuchten, eine Warnung vor
##     dem Jaeger, ein Handelstipp und was man ueber einen selbst sagt.
##
## Das Gerede ist nicht Beiwerk. Ein Auftragsziel wurde bis hierher einfach in
## Sichtweite gesetzt, egal wo man fuhr - man konnte einen Auftrag nicht
## *suchen*, nur abwarten. Wer hier erfaehrt, vor welchem Hafen der Gesuchte
## kreuzt, hat ab dann eine Fahrt mit Ziel (siehe [member
## Commission.waters_known]).
##
## Gebaut wie Markt, Werft und Palast im Code statt als .tscn (siehe
## [PortWidgets]): Wieviele Zeilen Gerede es gibt, steht erst zur Laufzeit fest.
class_name TavernPanel
extends VBoxContainer

signal acted(message: String)

var town: TownData

var _crew: Label
var _cost: Label
var _button: Button
## Die Geruechte haengen in einem eigenen Kasten, weil ihre Zahl wechselt: Ohne
## Auftrag und ohne Kopfgeld bleiben zwei Zeilen, mit beidem sind es fuenf.
var _gossip: VBoxContainer


func setup(target: TownData) -> void:
	town = target
	add_theme_constant_override("separation", 8)

	add_child(PortWidgets.label("Zur Schenke", Palette.PARCHMENT, 22))
	add_child(_wrapped(
		"Zwischen Rum und Rauch sitzt, wer zur See fährt — und wer weiß, "
		+ "wer gerade wo fährt.",
		Palette.HUD_DIM
	))

	add_child(_spacer())

	add_child(PortWidgets.label("Mannschaft", Palette.BRASS, 17))
	_crew = PortWidgets.label("", Palette.HUD_TEXT, 17)
	add_child(_crew)
	_cost = PortWidgets.label("", Palette.BRASS, 17)
	add_child(_cost)
	_button = PortWidgets.button("Mannschaft anheuern", 17)
	_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_button.pressed.connect(_on_hire_pressed)
	add_child(_button)

	add_child(_spacer())

	add_child(PortWidgets.label("Was man sich erzählt", Palette.BRASS, 17))
	_gossip = VBoxContainer.new()
	_gossip.add_theme_constant_override("separation", 6)
	add_child(_gossip)

	refresh()


func refresh() -> void:
	if _crew == null:
		return
	_refresh_crew()
	_refresh_gossip()


# --- Mannschaft ------------------------------------------------------------

func _refresh_crew() -> void:
	var missing := Tavern.crew_missing()
	# Gefaerbt nach der Bedienung der Rohre, nicht nach dem Anteil an der
	# Hoechstzahl - dieselbe Regel wie im HUD und in der Werft. Eine Schaluppe
	# faehrt mit vierzig Mann und braucht acht.
	if GameState.handling() < 1.0:
		_crew.text = "%d von %d Mann — unter der Mindestbesatzung von %d" % [
			GameState.crew, GameState.max_crew(), GameState.min_crew()
		]
	else:
		_crew.text = "%d von %d Mann" % [GameState.crew, GameState.max_crew()]
	PortWidgets.paint(_crew, _state_color(GameState.readiness()))

	if missing <= 0:
		_cost.text = "Die Mannschaft ist vollzählig."
		PortWidgets.paint(_cost, Palette.HUD_DIM)
		_button.disabled = true
		return

	var cost := Tavern.full_hire_cost(town)
	_button.disabled = GameState.gold < Tavern.hire_cost(town, 1)
	if GameState.gold >= cost:
		_cost.text = "%d Mann anheuern: %d Gold%s" % [missing, cost, _fame_note()]
		PortWidgets.paint(_cost, Palette.BRASS)
	else:
		# Teilanheuerung ist erlaubt, also wird sie auch angeboten - sonst
		# stuende hier nur ein Preis, den man nicht zahlen kann.
		_cost.text = "%d Mann anheuern: %d Gold — du hast %d. Es kommt, wer bezahlt wird." % [
			missing, cost, GameState.gold
		]
		PortWidgets.paint(_cost, Palette.FAIR)


## Warum das Handgeld hier billiger ist als anderswo.
##
## Nur wenn es wirklich etwas ausmacht: Ein Satz, der bei jeder Kampagne von
## Anfang an dasteht, erklaert nichts (Regel A8). So faellt auf, dass sich
## etwas geaendert hat.
func _fame_note() -> String:
	if GameState.notoriety < 20:
		return ""
	return "  ·  dein Ruf drückt das Handgeld"


func _on_hire_pressed() -> void:
	var count := Tavern.hire(town)
	refresh()
	if count <= 0:
		acted.emit("Für Handgeld reicht das Gold nicht.")
	else:
		acted.emit("%d Mann kommen an Bord." % count)


# --- Gerede ----------------------------------------------------------------

func _refresh_gossip() -> void:
	for child in _gossip.get_children():
		_gossip.remove_child(child)
		child.queue_free()

	_rumour(_politics(), Palette.HUD_DIM)
	_rumour(_wanted(), Palette.BRASS)
	_rumour(_hunter(), Palette.BAD)
	_rumour(_trade(), Palette.HUD_DIM)
	_rumour(_about_you(), Palette.MUTED)


## Haengt eine Zeile ins Gerede, wenn es eine gibt.
func _rumour(text: String, color: Color) -> void:
	if text.is_empty():
		return
	_gossip.add_child(_wrapped("·  %s" % text, color))


## Wer gerade mit wem Krieg fuehrt - und was das fuer den eigenen Brief heisst.
##
## Der zweite Satz ist der wichtigere: Die Lage der Kronen ist Kulisse, solange
## niemand sagt, welche Flagge sie zur Beute macht (Regel A8).
func _politics() -> String:
	var pairs: PackedStringArray = []
	for war: Vector2i in WorldData.wars():
		var first := WorldData.get_nation(war.x)
		var second := WorldData.get_nation(war.y)
		if first == null or second == null:
			continue
		pairs.append("%s und %s" % [first.subject_name(), second.subject_name()])
	if pairs.is_empty():
		return ""

	# "A und B liegen im Krieg, C und D ebenso" - zweimal derselbe Satz
	# hintereinander liest sich wie ein Fehler.
	var text := "%s liegen im Krieg." % pairs[0]
	if pairs.size() > 1:
		text = "%s liegen im Krieg, %s ebenso." % [pairs[0], ", ".join(pairs.slice(1))]
	var patron := GameState.letter_patron()
	if patron == null:
		return text
	var enemy := WorldData.get_nation(WorldData.enemy_of(patron.id))
	if enemy == null:
		return text
	return "%s  Dein %ser Kaperbrief deckt Prisen gegen %se Segel — sonst keine." % [
		text, patron.adjective, enemy.adjective
	]


## Wo der Gesuchte kreuzt.
##
## Das Erzaehlen setzt [member Commission.waters_known] - ab hier steht der Ort
## auch auf der Seekarte. Ein Nebeneffekt beim Zeichnen, ja: Die Schenke zu
## betreten *ist* das Erfahren, und ein eigener Knopf "zuhoeren" waere ein
## Klick ohne Entscheidung.
func _wanted() -> String:
	var order := GameState.commission
	if order == null or order.done or order.target == null:
		return ""
	var waters := GameState.hear_commission_rumour()
	# Nicht ueber Adversary.title(): Dessen Mittelpunkt zwischen Kapitaen und
	# Schiff steht hier neben dem Punkt, mit dem jedes Gerucht anfaengt, und
	# aus einem Satz werden drei Aufzaehlungspunkte.
	var who := "Kapitän %s (%s)" % [order.target.captain_name, order.target.ship_name]
	if waters == null:
		return "%s soll auf See sein — wo, weiß hier niemand." % who
	return "%s kreuzt vor %s, sagt man." % [who, waters.town_name]


## Und wer einen selbst sucht.
##
## Dieselbe Frage wie in [method NavalCombat._bounty_due], nur an Land: Wenn
## eine feindliche Krone einen Jaeger schickt, soll man es erfahren koennen,
## bevor er am Horizont steht.
func _hunter() -> String:
	for nation: NationData in WorldData.nations:
		if not Bounty.due(GameState.notoriety, GameState.standing_with(nation.id)):
			continue
		var ship_class: ShipClass = load(Bounty.class_for(GameState.notoriety))
		# Ueber das Adjektiv und nicht ueber den Nationsnamen: "die Niederlande
		# hat" braeuchte ein anderes Verb als "Spanien hat". Beide Klassen, auf
		# denen ein Jaeger kommt, sind weiblich - "eine spanische Fregatte" passt
		# genauso wie "eine niederlaendische Patrouillenschaluppe".
		return "Auf deinen Kopf ist ein Preis ausgesetzt. Eine %se %s sucht dich." % [
			nation.adjective,
			ship_class.display_name if ship_class != null else "Patrouille",
		]
	return ""


## Wo eine Ware von hier gut bezahlt wird.
func _trade() -> String:
	var tip := Tavern.trade_tip(town, WorldData.towns)
	if tip.is_empty():
		return ""
	var target: TownData = tip["town"]
	var cargo: CargoType = tip["cargo"]
	return "In %s zahlen sie für %s gut — hier liegt genug davon." % [
		target.town_name, cargo.display_name
	]


## Was man ueber einen selbst sagt.
##
## Die Beruechtigtheit hat sonst nur Folgen, die man erleidet oder abliest.
## Hier bekommt sie eine Stimme - und der Satz sagt zugleich, wo es hingeht.
func _about_you() -> String:
	if GameState.notoriety >= Bounty.FEARED_FROM:
		return "Über dich reden sie leise. Die Kronen setzen Fregatten auf dich an."
	if GameState.notoriety >= Bounty.HUNTED_FROM:
		return "Dein Name fällt hier öfter, als dir lieb sein kann."
	if GameState.notoriety >= 15:
		return "Man hat von dir gehört."
	return ""


# --- Kleinkram -------------------------------------------------------------

func _state_color(fraction: float) -> Color:
	if fraction >= 0.9:
		return Palette.GOOD
	elif fraction >= 0.4:
		return Palette.FAIR
	return Palette.BAD


## Fliesstext bricht um, und zwar auf Lesebreite. SHRINK_BEGIN gehoert dazu -
## siehe [method GovernorPanel._wrapped].
func _wrapped(content: String, color: Color) -> Label:
	var node := PortWidgets.label(content, color, 14)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = 560
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return node


func _spacer() -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = 10
	return node
