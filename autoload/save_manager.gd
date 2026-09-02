## Spielstaende als JSON unter user://saves/.
##
## Bewusst Klartext statt Binaerformat: Spielstaende lassen sich beim Debuggen
## im Texteditor oeffnen. Gespeichert wird der Seed plus alle Abweichungen -
## nie die Heightmap selbst.
extends Node

const SAVE_DIR: String = "user://saves"
## Bei Formataenderungen erhoehen und in _migrate() behandeln.
## 2: Schiff, Laderaum und die Lagerbestaende der Staedte kamen dazu.
## 3: der Kaperbrief.
## 4: der Auftrag des Gouverneurs.
## 5: das Revier des Gesuchten.
const SAVE_VERSION: int = 5


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_slot(slot: int) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"player": {
			"captain_name": GameState.captain_name,
			"gold": GameState.gold,
			"crew": GameState.crew,
			"notoriety": GameState.notoriety,
			"letter_nation": GameState.letter_nation,
			"letter_prizes": GameState.letter_prizes,
			"commissions_done": GameState.commissions_done,
			# Der angenommene Auftrag als Ganzes, das offene Angebot nicht: Das
			# faellt aus Seed, Krone und commissions_done wieder heraus
			# (GameState.commission_offer) und waere im Spielstand eine zweite
			# Wahrheit ueber dieselbe Sache.
			"commission": GameState.commission.to_dict() if GameState.commission != null else {},
			# JSON kennt nur String-Keys - Enum-Keys werden beim Laden zurueckgewandelt.
			"reputation": _keys_to_strings(GameState.reputation),
			"game_minutes": GameState.game_minutes,
		},
		"ship": {
			"class": GameState.ship_class.resource_path if GameState.ship_class != null else "",
			"hull": GameState.hull,
			"sails": GameState.sails,
			"cargo": _keys_to_strings(GameState.cargo),
			"port": GameState.current_port_id,
		},
		"world": {
			"seed": WorldData.world_seed,
			"wind_direction": WorldData.wind_direction,
			"wind_strength": WorldData.wind_strength,
			"weather": int(WorldData.weather),
			# Nur Abweichungen vom generierten Zustand. Produktion und Bedarf
			# stehen im Seed, die Lager nicht - sie sind das Einzige, was der
			# Spieler an einer Stadt veraendert.
			"town_overrides": _town_overrides(),
		},
	}

	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Slot %d nicht schreibbar (%s)" % [slot, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_slot(slot: int) -> bool:
	if not has_save(slot):
		return false

	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		push_error("SaveManager: Slot %d nicht lesbar" % slot)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: Slot %d ist beschaedigt" % slot)
		return false

	var data: Dictionary = _migrate(parsed)

	# Welt zuerst - der Seed baut die Karte wieder auf, bevor der Spieler
	# darauf platziert wird.
	var world: Dictionary = data.get("world", {})
	WorldData.generate(int(world.get("seed", 0)))
	WorldData.wind_direction = float(world.get("wind_direction", 0.0))
	WorldData.wind_strength = float(world.get("wind_strength", 1.0))
	WorldData.weather = world.get("weather", WorldData.Weather.CLEAR) as WorldData.Weather

	var player: Dictionary = data.get("player", {})
	GameState.captain_name = str(player.get("captain_name", "Namenlos"))
	GameState.gold = int(player.get("gold", 500))
	GameState.crew = int(player.get("crew", 20))
	GameState.notoriety = int(player.get("notoriety", 0))
	GameState.letter_nation = int(player.get("letter_nation", LetterOfMarque.NONE))
	GameState.letter_prizes = int(player.get("letter_prizes", 0))
	GameState.commissions_done = int(player.get("commissions_done", 0))
	var order: Dictionary = player.get("commission", {})
	GameState.commission = Commission.from_dict(order) if not order.is_empty() else null
	GameState.game_minutes = float(player.get("game_minutes", 0.0))
	for key: String in player.get("reputation", {}):
		GameState.reputation[int(key)] = int(player["reputation"][key])

	_load_ship(data.get("ship", {}))
	_apply_town_overrides(world.get("town_overrides", {}))
	# Die Wirtschaft darf die Pause zwischen zwei Sitzungen nicht nachholen,
	# und die Politik keine Umwaelzung melden, die vor dem Speichern lag.
	WorldData.reset_economy_clock()
	WorldData.reset_political_clock()

	return true


## Die Lagerbestaende aller Staedte, als Stadt-Id -> Waren-Id -> Menge.
func _town_overrides() -> Dictionary:
	var result := {}
	for town: TownData in WorldData.towns:
		result[str(town.id)] = {
			"stock": _keys_to_strings(town.stock),
			"discovered": town.discovered,
		}
	return result


func _apply_town_overrides(overrides: Dictionary) -> void:
	for key: String in overrides:
		var town := WorldData.get_town(int(key))
		if town == null:
			continue
		var entry: Dictionary = overrides[key]
		town.discovered = bool(entry.get("discovered", false))
		# Waren-Ids sind StringName; JSON kennt nur Strings. Unbekannte Ids
		# werden verworfen statt uebernommen - sonst schleppt ein alter
		# Spielstand Waren mit, die es nicht mehr gibt.
		for cargo_id: String in entry.get("stock", {}):
			if CargoRegistry.has(StringName(cargo_id)):
				town.stock[StringName(cargo_id)] = float(entry["stock"][cargo_id])


func _load_ship(ship: Dictionary) -> void:
	var class_path := str(ship.get("class", ""))
	if not class_path.is_empty():
		GameState.ship_class = load(class_path)
	if GameState.ship_class == null:
		GameState.ship_class = load(GameState.STARTING_SHIP)

	GameState.hull = int(ship.get("hull", GameState.max_hull()))
	GameState.sails = int(ship.get("sails", GameState.max_sails()))
	GameState.current_port_id = int(ship.get("port", -1))

	GameState.cargo.clear()
	for cargo_id: String in ship.get("cargo", {}):
		if CargoRegistry.has(StringName(cargo_id)):
			GameState.cargo[StringName(cargo_id)] = int(ship["cargo"][cargo_id])


func delete_slot(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))


## Hebt aeltere Spielstaende auf das aktuelle Format an.
##
## Schrittweise und ohne return dazwischen: Mit dem zweiten Format wurde aus
## dem einen Sonderfall eine Kette, und ein Spielstand der Version 1 muss beide
## Schritte durchlaufen, nicht nur den ersten.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version == SAVE_VERSION:
		return data
	if version < 1 or version > SAVE_VERSION:
		push_warning("SaveManager: Spielstand hat Version %d, erwartet %d" % [version, SAVE_VERSION])
		return data

	if version < 2:
		# Version 1 kannte weder Schiff noch Lagerbestaende. Die fehlenden
		# Abschnitte bleiben leer - die Ladefunktion faellt dann auf die
		# Startwerte und die frisch erzeugte Wirtschaft zurueck.
		data["ship"] = {}
	# Version 2 kannte den Kaperbrief nicht, Version 3 den Auftrag nicht,
	# Version 4 sein Revier nicht. Jedes Mal ist nichts zu tun: Ein fehlendes
	# Feld heisst "keiner" beziehungsweise "ueberall", und genau darauf faellt
	# die Ladefunktion zurueck (siehe Commission.from_dict).

	data["version"] = SAVE_VERSION
	return data


func _keys_to_strings(source: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in source:
		result[str(key)] = source[key]
	return result
