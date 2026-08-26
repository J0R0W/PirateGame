## Zugriff auf alle Warenarten.
##
## Die Liste steht bewusst als Konstante hier und wird nicht aus dem Ordner
## gelesen: Die Weltgenerierung waehlt Waren per Zufallszahl aus, und eine
## Verzeichnisliste hat je nach Dateisystem eine andere Reihenfolge. Damit
## haette derselbe Seed auf zwei Rechnern verschiedene Wirtschaften.
##
## Rohstoffe wachsen auf den Inseln, Fertigwaren werden in Staedten verarbeitet
## oder kommen aus Europa. Die Trennung erzeugt Handelsrouten: Ein Dorf gibt
## Zucker billig ab und zahlt fuer Werkzeug.
class_name CargoRegistry
extends RefCounted

const RAW_IDS: Array[StringName] = [
	&"wood", &"sugar", &"cotton", &"tobacco", &"cocoa", &"coffee", &"spices",
]
const FINISHED_IDS: Array[StringName] = [
	&"food", &"rum", &"cloth", &"tools", &"cannons",
]

const DIRECTORY: String = "res://resources/cargo/"

## Geladene Waren, id -> CargoType. Wird beim ersten Zugriff gefuellt.
static var _cache: Dictionary = {}
static var _order: Array[StringName] = []


## Alle Waren in fester Reihenfolge: erst Rohstoffe, dann Fertigwaren.
static func all() -> Array[CargoType]:
	_ensure_loaded()
	var result: Array[CargoType] = []
	for id: StringName in _order:
		result.append(_cache[id])
	return result


static func ids() -> Array[StringName]:
	_ensure_loaded()
	return _order.duplicate()


## Ware zu einer Id, oder null. Unbekannte Ids sind ein Fehler im Aufrufer,
## deshalb laut.
static func get_cargo(id: StringName) -> CargoType:
	_ensure_loaded()
	var cargo: CargoType = _cache.get(id, null)
	if cargo == null:
		push_error("CargoRegistry: unbekannte Ware '%s'" % id)
	return cargo


static func has(id: StringName) -> bool:
	_ensure_loaded()
	return _cache.has(id)


## Anzeigename, oder die Id selbst - eine kaputte Id soll die Oberflaeche
## nicht abstuerzen lassen, sondern sichtbar falsch aussehen.
static func display_name(id: StringName) -> String:
	_ensure_loaded()
	var cargo: CargoType = _cache.get(id, null)
	return cargo.display_name if cargo != null else String(id)


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	for id: StringName in RAW_IDS + FINISHED_IDS:
		var cargo: CargoType = load(DIRECTORY + String(id) + ".tres")
		if cargo == null:
			push_error("CargoRegistry: Ware nicht ladbar: %s" % id)
			continue
		if cargo.id != id:
			push_error("CargoRegistry: %s.tres traegt die Id '%s'" % [id, cargo.id])
		_cache[id] = cargo
		_order.append(id)
