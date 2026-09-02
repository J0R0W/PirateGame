## Eine der vier Kolonialmaechte.
class_name NationData
extends Resource

@export var id: int = 0
@export var display_name: String = "Spanien"
@export var adjective: String = "spanisch"
## Artikel im Nominativ, wo einer hingehoert - leer bei den meisten, "die"
## bei den Niederlanden.
##
## Drei der vier Kronen sind Eigennamen ohne Artikel, die vierte ist ein
## Plural. Ohne dieses Feld steht in jeder politischen Meldung "Niederlande und
## Frankreich liegen im Krieg" - verstaendlich, aber man stolpert beim Lesen.
## Nur der Nominativ: Saetze, die einen anderen Fall braeuchten, werden ueber
## das Adjektiv gebaut ("gegen niederlaendische Segel").
@export var name_article: String = ""
## Faerbt Flaggen, Kartenmarker und Stadtnamen ein.
@export var color: Color = Color.CRIMSON
@export var flag_texture: Texture2D


@export_group("Namensgenerator")
## Silben fuer prozedurale Stadtnamen im Klang dieser Nation.
@export var name_prefixes: PackedStringArray = []
@export var name_suffixes: PackedStringArray = []
## Schiffsnamen dieser Nation. Eigene Liste statt der Stadtsilben: Ein Segel,
## das genauso heisst wie der Hafen dahinter, verwirrt auf der Seekarte.
@export var ship_names: PackedStringArray = []
## Namen fuer benannte Kapitaene dieser Nation - Auftragsziele und
## Kopfgeldjaeger (siehe [Adversary]).
##
## Getrennt von den Schiffsnamen, obwohl beide zusammen einen Steckbrief
## ergeben: Ein Kapitaen, der heisst wie sein Schiff, liest sich wie ein
## Tippfehler. Und getrennt von den Stadtsilben, weil ein Personenname
## anders klingt als ein Ortsname.
@export var captain_names: PackedStringArray = []

@export_group("Verhalten")
## Wie aggressiv Patrouillen dieser Nation den Spieler verfolgen (0.0-1.0).
@export_range(0.0, 1.0) var aggression: float = 0.5
## Wie stark der Ruf auf Taten reagiert.
@export_range(0.0, 2.0) var reputation_sensitivity: float = 1.0


## Der Name so, wie er als Satzsubjekt dasteht: "England", aber "die
## Niederlande".
func subject_name() -> String:
	return display_name if name_article.is_empty() else "%s %s" % [name_article, display_name]
