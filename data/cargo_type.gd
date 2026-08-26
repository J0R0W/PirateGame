## Eine handelbare Ware.
##
## Der Basispreis ist nur der Anker - der tatsaechliche Preis entsteht in M3
## aus Angebot und Nachfrage der jeweiligen Stadt.
class_name CargoType
extends Resource

@export var display_name: String = "Zucker"
@export var icon: Texture2D
@export var base_price: int = 100
## Wie stark der Preis um den Basiswert schwanken darf (0.0-1.0).
@export_range(0.0, 1.0) var price_volatility: float = 0.3
## Platzbedarf pro Einheit im Laderaum.
@export var unit_size: int = 1
## Schmuggelware - bringt beim Hehler mehr als auf dem offenen Markt.
@export var contraband: bool = false
