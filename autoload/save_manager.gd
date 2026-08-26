## Spielstaende als JSON unter user://saves/.
##
## Bewusst Klartext statt Binaerformat: Spielstaende lassen sich beim Debuggen
## im Texteditor oeffnen. Gespeichert wird der Seed plus alle Abweichungen -
## nie die Heightmap selbst.
extends Node

const SAVE_DIR: String = "user://saves"
## Bei Formataenderungen erhoehen und in _migrate() behandeln.
const SAVE_VERSION: int = 1


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
			# JSON kennt nur String-Keys - Enum-Keys werden beim Laden zurueckgewandelt.
			"reputation": _keys_to_strings(GameState.reputation),
			"game_minutes": GameState.game_minutes,
		},
		"world": {
			"seed": WorldData.world_seed,
			"wind_direction": WorldData.wind_direction,
			"wind_strength": WorldData.wind_strength,
			"weather": int(WorldData.weather),
			# TODO(M3): Abweichungen vom generierten Zustand - Stadtbesitzer,
			# Lagerbestaende, Preise.
			"town_overrides": {},
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
	GameState.game_minutes = float(player.get("game_minutes", 0.0))
	for key: String in player.get("reputation", {}):
		GameState.reputation[int(key)] = int(player["reputation"][key])

	return true


func delete_slot(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))


## Hebt aeltere Spielstaende auf das aktuelle Format an.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version == SAVE_VERSION:
		return data
	# TODO: Bei Formataenderungen hier schrittweise migrieren.
	push_warning("SaveManager: Spielstand hat Version %d, erwartet %d" % [version, SAVE_VERSION])
	return data


func _keys_to_strings(source: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in source:
		result[str(key)] = source[key]
	return result
