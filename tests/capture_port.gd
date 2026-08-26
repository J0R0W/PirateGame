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

	# Ein angeschlagenes Schiff, damit die Werft etwas anzuzeigen hat.
	GameState.damage_hull(38)
	GameState.damage_sails(12)

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

	get_tree().quit(0)


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
	return best if best != null else CargoRegistry.get_cargo(&"sugar")


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
