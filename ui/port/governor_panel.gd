## Der Gouverneurspalast.
##
## Der dritte Hafenbildschirm nach Markt und Werft - und der erste, in dem es
## nicht um Gold geht, sondern um Politik. Hier steht, was die Krone dieser
## Stadt vom Spieler haelt, hier wird der Kaperbrief vergeben, und hier haengt
## der Steckbrief.
##
## Die Reihenfolge auf dem Bildschirm ist die des Aufstiegs: Verhaeltnis, dann
## Brief, dann Auftrag. Jede Zeile setzt die darueber voraus - ohne Ansehen kein
## Brief, ohne Brief kein Auftrag -, und wer von oben nach unten liest, sieht
## genau das.
##
## Gebaut wie Markt und Werft im Code statt als .tscn (siehe [PortWidgets]):
## Der Inhalt haengt an vier Fragen - sitzt hier ein Gouverneur, wie steht die
## Krone, welchen Brief traegt der Spieler, was schuldet er ihr noch -, und die
## Anordnung aendert sich mit jeder Antwort.
class_name GovernorPanel
extends VBoxContainer

signal acted(message: String)

var town: TownData

var _nation: NationData
var _standing: Label
var _letter_title: Label
var _letter_note: Label
var _letter_button: Button
var _return_button: Button
var _order_title: Label
var _order_note: Label
var _accept_button: Button
var _report_button: Button


func setup(target: TownData) -> void:
	town = target
	_nation = WorldData.get_nation(town.nation_id)
	add_theme_constant_override("separation", 8)

	add_child(PortWidgets.label("Gouverneurspalast", Palette.PARCHMENT, 22))

	# Ohne Gouverneur bleibt der Bildschirm eine einzige Zeile. Er wird
	# trotzdem angeboten und nicht ausgeblendet: Wer in einem Dorf liegt, soll
	# erfahren, dass es Kaperbriefe gibt und wo - ein fehlender Menuepunkt
	# erklaert nichts (Regel A8).
	if not LetterOfMarque.has_seat(town.size_tier):
		add_child(_wrapped(
			"In einem Dorf sitzt kein Gouverneur. Kaperbriefe und Aufträge vergibt "
			+ "man in einer Stadt oder in einer Hauptstadt.",
			Palette.HUD_DIM
		))
		return

	_standing = PortWidgets.label("", Palette.HUD_TEXT, 17)
	add_child(_standing)

	add_child(_spacer())

	_letter_title = PortWidgets.label("", Palette.BRASS, 17)
	add_child(_letter_title)
	_letter_note = _wrapped("", Palette.HUD_DIM)
	add_child(_letter_note)

	_letter_button = _action("Kaperbrief annehmen", _on_issue_pressed)
	_return_button = _action("Kaperbrief zurückgeben", _on_return_pressed)

	add_child(_spacer())

	_order_title = PortWidgets.label("", Palette.BRASS, 17)
	add_child(_order_title)
	_order_note = _wrapped("", Palette.HUD_DIM)
	add_child(_order_note)

	_accept_button = _action("Auftrag annehmen", _on_accept_pressed)
	_report_button = _action("Bericht erstatten", _on_report_pressed)

	refresh()


func refresh() -> void:
	if _standing == null:
		return

	var level := GameState.standing_with(town.nation_id)
	_standing.text = "%s  ·  %s  (%d)" % [
		_nation.display_name if _nation != null else "Unbekannte Krone",
		Standing.title_of(level),
		GameState.reputation_with(town.nation_id),
	]
	PortWidgets.paint(_standing, Standing.color_of(level))

	_refresh_letter(level)
	_refresh_order()


## Der Kaperbrief in vier Lagen: Man traegt den dieser Krone, man traegt einen
## fremden, man koennte einen bekommen, oder man ist unten durch.
##
## Die Texte gehen ueber das Adjektiv der Nation ("ein spanischer Kaperbrief")
## und nicht ueber ihren Namen. Sonst braeuchte jeder Satz einen Genitiv, und
## "Niederlande" hat keinen, der ohne Artikel funktioniert.
func _refresh_letter(level: Standing.Level) -> void:
	var adjective := _nation.adjective if _nation != null else "hiesig"
	var patron := GameState.letter_patron()

	if GameState.letter_nation == town.nation_id:
		_letter_title.text = LetterOfMarque.title_of(_nation)
		PortWidgets.paint(_letter_title, Palette.BRASS)
		# Die Zahl der Prisen steht dabei, damit der Brief nicht nur ein
		# Zustand ist, sondern etwas, das mitlaeuft.
		_letter_note.text = (
			"Du fährst im Auftrag dieses Gouverneurs. %s\n%s\n"
			+ "Ihn zurückzugeben kostet nichts — was die übrigen Kronen sich "
			+ "notiert haben, bleibt aber stehen."
		) % [_prize_tally(), _covered_note()]
		_letter_button.visible = false
		_return_button.visible = true
		return

	_return_button.visible = false

	if not LetterOfMarque.can_issue(level):
		_letter_title.text = "Kein Kaperbrief"
		PortWidgets.paint(_letter_title, Palette.MUTED)
		_letter_note.text = (
			"Der Gouverneur lässt dich nicht vor. Wer %se Schiffe aufbringt, "
			+ "bekommt hier keinen Auftrag."
		) % [adjective]
		_letter_button.visible = false
		return

	_letter_title.text = LetterOfMarque.title_of(_nation)
	PortWidgets.paint(_letter_title, Palette.BRASS)
	var note := (
		"Der Gouverneur stellt dir einen %sen Kaperbrief aus. %s\n"
		+ "Die übrigen drei Kronen erfahren davon und nehmen es dir übel."
	) % [adjective, _covered_note()]
	if patron != null:
		# Der bisherige Patron wird beim Ausstellen wie jede andere fremde Krone
		# behandelt und bucht denselben Verlust. Das steht hier, weil es sonst
		# als Ueberraschung kaeme.
		note += (
			"\nDein %ser Kaperbrief wird damit hinfällig, und dein bisheriger "
			+ "Auftraggeber rechnet es dir an."
		) % [patron.adjective]
	_letter_note.text = note
	_letter_button.visible = true
	_letter_button.disabled = false


## Der Auftrag in vier Lagen: keiner ohne Brief, ein ausgehaengter Steckbrief,
## ein laufender mit Frist, ein erledigter mit offener Rechnung.
##
## Auch die erste Lage bekommt ihre Zeile. Ohne sie waere unter dem Kaperbrief
## einfach nichts, und niemand erfuehre, wozu er gut ist (Regel A8).
func _refresh_order() -> void:
	_accept_button.visible = false
	_report_button.visible = false

	var order := GameState.commission
	if order != null and order.patron_id == town.nation_id:
		if order.done:
			_order_title.text = "Auftrag erledigt"
			PortWidgets.paint(_order_title, Palette.GOOD)
			_order_note.text = (
				"%s fährt nicht mehr. Der Gouverneur zahlt %d Gold und rechnet "
				+ "es dir hoch an."
			) % [order.target.title(), order.reward_gold]
			_report_button.visible = true
			return

		_order_title.text = "Gesucht:  %s" % order.target.title()
		PortWidgets.paint(_order_title, Palette.BRASS)
		_order_note.text = (
			"%s  ·  %d Gold auf seinen Kopf.\n%s\n%s"
		) % [
			_target_flag(order.target), order.reward_gold,
			_deadline_note(order), _waters_note(order),
		]
		return

	if order != null:
		# Ein Auftrag einer anderen Krone. Er steht hier, damit man ihn nicht
		# vergisst, waehrend die Frist laeuft - im falschen Hafen ist er nur
		# nicht einzuloesen.
		var patron := WorldData.get_nation(order.patron_id)
		_order_title.text = "Kein Auftrag"
		PortWidgets.paint(_order_title, Palette.MUTED)
		_order_note.text = (
			"Du fährst bereits einen Auftrag für %s: %s. Erst wenn er erledigt "
			+ "und gemeldet ist, hat dieser Gouverneur wieder etwas für dich."
		) % [
			patron.display_name if patron != null else "eine andere Krone",
			order.target.title(),
		]
		return

	if not GameState.can_accept_commission(town.nation_id):
		_order_title.text = "Kein Auftrag"
		PortWidgets.paint(_order_title, Palette.MUTED)
		_order_note.text = (
			"Aufträge vergibt der Gouverneur nur an die eigenen Kaperfahrer. "
			+ "Wer keinen %sen Kaperbrief trägt, ist keiner."
		) % [_nation.adjective if _nation != null else "hiesig"]
		return

	var offer := GameState.commission_offer()
	if offer == null:
		return
	_order_title.text = "Gesucht:  %s" % offer.target.title()
	PortWidgets.paint(_order_title, Palette.BRASS)
	_order_note.text = (
		"%s  ·  %d Gold auf seinen Kopf.\nDu hast %d Tage, ihn zu stellen — "
		+ "aufbringen oder versenken, der Gouverneur will ihn nur von der See "
		+ "haben. Wer zusagt und nicht liefert, dem rechnet er das an."
	) % [_target_flag(offer.target), offer.reward_gold, Commission.DAYS]
	_accept_button.visible = true
	_accept_button.disabled = false


## Welche Flagge der Brief dieser Krone gerade zur Beute macht.
##
## Derselbe Satz beim Angebot wie beim eigenen Brief, und das ist Absicht: Er
## aendert sich, ohne dass der Spieler etwas tut. Wenn die Kronen ihre
## Buendnisse neu ordnen ([Diplomacy]), deckt derselbe Brief am naechsten Tag
## eine andere Flagge - wer dann in den Palast kommt, soll es hier lesen und
## nicht auf See erraten muessen.
func _covered_note() -> String:
	var enemy := WorldData.get_nation(WorldData.enemy_of(town.nation_id))
	if enemy == null:
		return ""
	# "gegen %s" und nicht "%s liegt im Krieg mit ...": Drei der vier Kronen
	# sind Eigennamen ohne Artikel, die vierte ist ein Plural mit einem - und
	# der Plural braucht ein anderes Verb. Nach "gegen" steht der Akkusativ,
	# und der ist bei allen vieren derselbe wie der Nominativ.
	return (
		"Er deckt Prisen gegen %se Segel — der Krieg dieser Krone geht gegen %s, "
		+ "und gegen sonst niemanden."
	) % [enemy.adjective, enemy.subject_name()]


## Wo der Gesuchte kreuzt - oder wo man das erfaehrt.
##
## Der Palast haengt einen Steckbrief aus; wo der Mann steckt, weiss ein
## Gouverneur nicht. Das weiss der Wirt. Der Hinweis darauf steht hier, weil
## sonst niemand auf den Gedanken kaeme, dafuer eine Schenke zu betreten
## (Regel A8).
func _waters_note(order: Commission) -> String:
	if not order.waters_known:
		return "Wo er kreuzt, weiß der Gouverneur nicht — frag in der Schenke."
	var waters := WorldData.get_town(order.waters_town_id)
	if waters == null:
		return ""
	return "Zuletzt gesehen wurde er vor %s." % waters.town_name


## Unter welcher Flagge der Gesuchte faehrt, und auf was fuer einem Schiff.
##
## Beides gehoert auf den Steckbrief: Die Flagge sagt, was einen die Jagd an
## Ansehen kostet, die Klasse, was sie an Pulver kostet.
func _target_flag(who: Adversary) -> String:
	var nation := WorldData.get_nation(who.nation_id)
	var ship_class: ShipClass = load(who.ship_class_path)
	return "%s%s" % [
		"%se " % nation.adjective.capitalize() if nation != null else "",
		ship_class.display_name if ship_class != null else "Segler",
	]


## Wieviel Zeit noch bleibt - als Satz, nicht als nackte Zahl.
func _deadline_note(order: Commission) -> String:
	var left := order.days_left(GameState.current_day())
	if left <= 0:
		return "Die Frist läuft heute ab."
	if left == 1:
		return "Ein Tag bleibt dir noch."
	return "%d Tage bleiben dir noch." % left


## "Prisen unter diesem Brief" als ganzer Satz - eine nackte Null neben einer
## Beschriftung sieht aus wie ein Fehler.
func _prize_tally() -> String:
	match GameState.letter_prizes:
		0:
			return "Aufgebracht hast du unter ihm noch nichts."
		1:
			return "Eine Prise ist darunter aufgebracht."
		_:
			return "%d Prisen sind darunter aufgebracht." % GameState.letter_prizes


func _on_issue_pressed() -> void:
	if not GameState.issue_letter(town.nation_id):
		acted.emit("Der Gouverneur lässt dich nicht vor.")
		refresh()
		return
	refresh()
	acted.emit("Der Gouverneur stellt dir einen %sen Kaperbrief aus." % [
		_nation.adjective if _nation != null else "hiesig"
	])


func _on_return_pressed() -> void:
	# Die Meldung wird vor der Rueckgabe gebaut: Ein laufender Auftrag geht mit
	# dem Brief unter, und danach ist nicht mehr zu sehen, dass es einen gab.
	var dropped := GameState.commission != null and not GameState.commission.done
	GameState.return_letter()
	refresh()
	if dropped:
		acted.emit("Der Kaperbrief ist zurückgegeben — der offene Auftrag mit ihm.")
	else:
		acted.emit("Der Kaperbrief ist zurückgegeben.")


func _on_accept_pressed() -> void:
	if not GameState.accept_commission(town.nation_id):
		acted.emit("Der Gouverneur hat gerade nichts für dich.")
		refresh()
		return
	refresh()
	acted.emit("Der Auftrag ist angenommen: %s." % GameState.commission.target.title())


func _on_report_pressed() -> void:
	var order := GameState.commission
	if order == null:
		return
	var reward := order.reward_gold
	if not GameState.report_commission(town):
		acted.emit("Hier nimmt niemand deinen Bericht entgegen.")
		refresh()
		return
	refresh()
	acted.emit("Bericht erstattet. Der Gouverneur zahlt %d Gold." % reward)


## Ein Knopf, der links steht statt sich ueber die Breite zu ziehen - wie in
## der Werft.
func _action(caption: String, handler: Callable) -> Button:
	var button := PortWidgets.button(caption, 17)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(handler)
	add_child(button)
	return button


## Fliesstext bricht um, und zwar auf Lesebreite.
##
## SHRINK_BEGIN gehoert dazu: Der Inhaltsbereich des Hafens dehnt sich ueber die
## ganze Fensterbreite, und ein umbrechendes Label darin nimmt sich alles davon.
## Der Absatz lief dann ueber anderthalbtausend Pixel in einer Zeile - technisch
## richtig, aber nicht mehr zu lesen. custom_minimum_size allein reicht nicht,
## das ist eine Untergrenze.
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
