## Definition einer Schiffsklasse.
##
## Balancing passiert in .tres-Dateien unter resources/ships/, nicht im Code.
class_name ShipClass
extends Resource

@export var display_name: String = "Schaluppe"
@export var description: String = ""
## Low-Poly-Modell als eigene Szene, damit Masten und Segel Kind-Nodes haben.
@export var model: PackedScene

@export_group("Zaehigkeit")
@export var max_hull: int = 100
@export var max_sails: int = 100

@export_group("Fahrverhalten")
## Knoten bei idealem Wind und voller Besegelung.
@export var base_speed: float = 10.0
## Grad pro Sekunde bei voller Fahrt.
@export var turn_rate: float = 2.0
## Wie traege das Schiff auf Ruder und Segel reagiert - hoeher = traeger.
@export var inertia: float = 3.0

@export_group("Bewaffnung & Laderaum")
@export var cannon_slots: int = 8
@export var cargo_capacity: int = 40

@export_group("Mannschaft")
@export var min_crew: int = 10
@export var max_crew: int = 60

@export_group("Handel")
@export var base_price: int = 2000
