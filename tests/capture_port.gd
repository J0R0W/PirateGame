## Rendert den Hafenbildschirm und legt Aufnahmen ab.
##
## Laufen lassen mit:
##   godot --path . res://tests/capture_port.tscn
##
## Der Hafen ist reine Oberflaeche - Spaltenbreiten, Umbrueche und Farben
## sieht man erst im Bild. Headless bleibt hier alles ungeprueft.
extends Node

const OUT_DIR: String = "user://captures"
const SEED: int = 42


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("Aufnahmen nach: ", ProjectSettings.globalize_path(OUT_DIR))

	GameState.new_campaign("Kapitaen", SEED)

	# Eine Stadt mit eigener Produktion aussuchen - dort ist die Preisspanne
	# im Bild zu sehen, in einem beliebigen Dorf steht ueberall dasselbe.
	var town := _pick_town()
	GameState.current_port_id = town.id
	print("  Hafen: %s (%s, %s)" % [
		town.town_name, town.tier_name(), _nation_name(town)
	])

	# Ein angeschlagenes Schiff, damit die Werft etwas anzuzeigen hat - und
	# eine geschrumpfte Mannschaft fuer die Schenke.
	GameState.damage_hull(38)
	GameState.damage_sails(12)
	GameState.crew = GameState.max_crew() - 14

	var packed: PackedScene = load("res://modes/port/port_mode.tscn")
	var port: Control = packed.instantiate()
	add_child(port)
	await _wait(0.6)
	await _shot("10_hafen_markt")

	# Handeln und danach aufnehmen: Preise, Laderaum und Meldung aendern sich.
	var market: MarketPanel = port.panel as MarketPanel
	var cargo := _cheapest_cargo(port.town)
	print("  Kauft: %s zu %d Gold" % [cargo.display_name, port.town.buy_price(cargo)])
	var bought := Trade.buy(port.town, cargo, 12)
	market.refresh()
	market.traded.emit("%d %s gekauft." % [bought, cargo.display_name])
	await _wait(0.4)
	await _shot("11_hafen_nach_kauf")

	port.show_section(port.Section.SHIPYARD)
	await _wait(0.4)
	await _shot("12_hafen_werft")

	# Der Gouverneurspalast zweimal: mit dem Angebot und mit dem Brief in der
	# Tasche. Die beiden Lagen sehen voellig verschieden aus - ein Bild von
	# einer davon sagt nichts darueber, ob die andere passt.
	port.show_section(port.Section.GOVERNOR)
	await _wait(0.4)
	await _shot("13_hafen_gouverneur")

	var palace: GovernorPanel = port.panel as GovernorPanel
	GameState.issue_letter(port.town.nation_id)
	GameState.letter_prizes = 4
	palace.refresh()
	await _wait(0.4)
	await _shot("14_hafen_kaperbrief")

	# Der Palast hat vier Lagen, und jede aendert Ueberschrift, Absatz und Knopf
	# zugleich - eine Aufnahme von einer sagt nichts ueber die anderen. Ohne
	# Brief (13), mit Brief und ausgehaengtem Steckbrief (14), mit angenommenem
	# Auftrag und laufender Frist (15), mit bekanntem Revier (17), erledigt und
	# auf den Bericht wartend (18).
	GameState.accept_commission(port.town.nation_id)
	palace.refresh()
	await _wait(0.4)
	await _shot("15_hafen_auftrag")

	# Die Schenke, und zwar mit allem, was sie zu erzaehlen hat: Politik, das
	# Revier des Gesuchten, ein Kopfgeld und ein Handelstipp. Jede dieser
	# Zeilen kommt aus einer eigenen Bedingung, und ob sie zusammen noch
	# lesbar untereinander stehen, sieht man nur im Bild.
	GameState.add_notoriety(Bounty.HUNTED_FROM + 10)
	# Genug Gold fuers Handgeld: Sonst zeigt die Aufnahme nur die Zeile fuer
	# einen leeren Beutel, und der Nachlass auf den Ruf steht nirgends.
	GameState.add_gold(900)
	var pursuer := _hostile_nation(port.town.nation_id)
	print("  Verfolger: %s" % pursuer)
	port.show_section(port.Section.TAVERN)
	await _wait(0.4)
	await _shot("16_hafen_schenke")

	# Und zurueck in den Palast: Nach dem Besuch in der Schenke steht dort das
	# Revier, das vorher noch unbekannt war.
	port.show_section(port.Section.GOVERNOR)
	palace = port.panel as GovernorPanel
	await _wait(0.4)
	await _shot("17_hafen_revier")

	var wanted: Adversary = GameState.commission.target
	print("  Gesucht: %s" % wanted.title())
	GameState.commission_target_defeated(wanted.captain_name, wanted.nation_id)
	palace.refresh()
	await _wait(0.4)
	await _shot("18_hafen_bericht")

	get_tree().quit(0)


## Macht eine fremde Krone feindlich und gibt ihren Namen zurueck.
##
## Fuer die Warnung in der Schenke: Ein Kopfgeld setzt nur aus, wer feindlich
## steht - ohne das bliebe die Zeile leer und die Aufnahme zeigte nicht, wie
## sie neben den uebrigen Geruechten wirkt.
func _hostile_nation(except_id: int) -> String:
	for nation: NationData in WorldData.nations:
		if nation.id == except_id:
			continue
		while GameState.standing_with(nation.id) != Standing.Level.HOSTILE:
			GameState.change_reputation(nation.id, -10)
		return nation.display_name
	return "niemand"


## Die groesste Stadt der Welt - sie hat die meisten Waren im Angebot.
func _pick_town() -> TownData:
	var best: TownData = WorldData.towns[0]
	for town: TownData in WorldData.towns:
		if town.size_tier > best.size_tier:
			best = town
	return best


## Die Ware mit dem groessten Abschlag auf den Basispreis.
func _cheapest_cargo(town: TownData) -> CargoType:
	var best: CargoType = null
	var best_ratio := 999.0
	for cargo: CargoType in CargoRegistry.all():
		if town.available(cargo.id) < 12:
			continue
		var ratio := float(town.buy_price(cargo)) / float(cargo.base_price)
		if ratio < best_ratio:
			best_ratio = ratio
			best = cargo
	return best if best != null else CargoRegistry.get_cargo(&"tobacco")


func _nation_name(town: TownData) -> String:
	var nation := WorldData.get_nation(town.nation_id)
	return nation.display_name if nation != null else "unbekannt"


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	var error := image.save_png(path)
	print("  %-20s  %d Gold, Laderaum %d/%d, Rumpf %d   [%s]" % [
		shot_name,
		GameState.gold,
		GameState.cargo_used(), GameState.cargo_capacity(), GameState.hull,
		"ok" if error == OK else "FEHLER %d" % error,
	])
