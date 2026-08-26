## Erzeugt Ortsnamen im Klang einer Nation.
##
## Die Silbenlisten stehen in den NationData-Resources unter resources/nations/,
## nicht hier - so laesst sich der Klang einer Nation aendern, ohne Code
## anzufassen. Vergebene Namen werden gemerkt, damit keine Stadt doppelt heisst.
class_name NameGenerator
extends RefCounted

## Roemische Ziffern fuer den Notfall, wenn alle Kombinationen vergeben sind.
const ORDINALS: PackedStringArray = ["II", "III", "IV", "V", "VI", "VII", "VIII"]

var _rng: RandomNumberGenerator
var _used: Dictionary = {}


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func generate(nation: NationData) -> String:
	if nation.name_prefixes.is_empty() or nation.name_suffixes.is_empty():
		return "Namenlos"

	# Genug Versuche, um bei den ueblichen Listengroessen fast immer zu treffen.
	for attempt in 40:
		var candidate := "%s %s" % [
			nation.name_prefixes[_rng.randi() % nation.name_prefixes.size()],
			nation.name_suffixes[_rng.randi() % nation.name_suffixes.size()],
		]
		if not _used.has(candidate):
			_used[candidate] = true
			return candidate

	# Alles vergeben: an einen bestehenden Namen eine Ordnungszahl haengen.
	var base := "%s %s" % [
		nation.name_prefixes[_rng.randi() % nation.name_prefixes.size()],
		nation.name_suffixes[_rng.randi() % nation.name_suffixes.size()],
	]
	for ordinal: String in ORDINALS:
		var candidate := "%s %s" % [base, ordinal]
		if not _used.has(candidate):
			_used[candidate] = true
			return candidate

	_used[base] = true
	return base


func reset() -> void:
	_used.clear()
