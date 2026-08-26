## Eine der vier Kolonialmaechte.
class_name NationData
extends Resource

@export var id: int = 0
@export var display_name: String = "Spanien"
@export var adjective: String = "spanisch"
## Faerbt Flaggen, Kartenmarker und Stadtnamen ein.
@export var color: Color = Color.CRIMSON
@export var flag_texture: Texture2D

@export_group("Namensgenerator")
## Silben fuer prozedurale Stadtnamen im Klang dieser Nation.
@export var name_prefixes: PackedStringArray = []
@export var name_suffixes: PackedStringArray = []

@export_group("Verhalten")
## Wie aggressiv Patrouillen dieser Nation den Spieler verfolgen (0.0-1.0).
@export_range(0.0, 1.0) var aggression: float = 0.5
## Wie stark der Ruf auf Taten reagiert.
@export_range(0.0, 2.0) var reputation_sensitivity: float = 1.0
