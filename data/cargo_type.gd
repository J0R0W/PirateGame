## Eine handelbare Ware.
##
## Der Basispreis ist nur der Anker - der tatsaechliche Preis entsteht aus dem
## Lagerbestand der jeweiligen Stadt. Siehe TradeMath.
class_name CargoType
extends Resource

## Stabiler Schluessel. Steht in Spielstaenden und in den Lagerlisten der
## Staedte, deshalb englisch und unveraenderlich - der Anzeigename darf sich
## aendern, dieser nie.
@export var id: StringName = &"wood"
@export var display_name: String = "Holz"
@export var icon: Texture2D
@export var base_price: int = 100
## Wie stark der Preis um den Basiswert schwanken darf (0.0-1.0). Luxus
## schwankt stark, Grundbedarf kaum.
@export_range(0.0, 1.0) var price_volatility: float = 0.3
## Platzbedarf pro Einheit im Laderaum. Sperrgut kostet Fracht, nicht Gold.
@export var unit_size: int = 1
## Schmuggelware - bringt beim Hehler mehr als auf dem offenen Markt.
@export var contraband: bool = false
