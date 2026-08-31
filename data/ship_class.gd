## Definition einer Schiffsklasse.
##
## Balancing passiert in .tres-Dateien unter resources/ships/, nicht im Code.
## Die Feldnamen entsprechen denen in ship.gd - der Segelmodus schreibt die
## Werte beim Start ins Schiff, damit es sie nur an einer Stelle gibt.
class_name ShipClass
extends Resource

@export var id: StringName = &"sloop"
@export var display_name: String = "Schaluppe"
@export var description: String = ""
## Low-Poly-Modell als eigene Szene, damit Masten und Segel Kind-Nodes haben.
@export var model: PackedScene

@export_group("Zaehigkeit")
@export var max_hull: int = 100
@export var max_sails: int = 100

@export_group("Fahrverhalten")
## Knoten bei idealem Wind und voller Besegelung.
@export var base_speed: float = 12.0
## Grad pro Sekunde bei voller Fahrt.
@export var turn_rate_deg: float = 34.0
## Wie traege die Fahrt auf Segelaenderungen reagiert, in Sekunden.
@export var speed_inertia: float = 4.5
## Wie traege das Ruder anspricht, in Sekunden.
@export var turn_inertia: float = 1.2

@export_group("Bewaffnung & Laderaum")
## Rohre insgesamt. Die Haelfte davon liegt auf jeder Seite - eine Breitseite
## ist nie die ganze Bewaffnung.
@export var cannon_slots: int = 8
## Schwenkbereich der Rohre um querab, in Grad nach jeder Seite.
##
## Die Mannschaft richtet selbst, aber nur soweit die Lafette laesst. Ausserhalb
## dieses Kegels schwenkt sie bis zum Anschlag und schiesst daneben - das ist
## der Grund, warum im Gefecht das Ruder die Waffe ist.
@export var gun_traverse: float = 20.0
@export var cargo_capacity: int = 40

@export_group("Auftreten")
## Sucht dieses Schiff das Gefecht? Kriegsschiffe greifen an, Handelsschiffe
## fliehen. Steuert die Grundhaltung der KI - siehe [ShipAI].
@export var warship: bool = false
## Groesse des Rumpfes gegenueber der Schaluppe.
##
## Solange alle Klassen dasselbe Modell benutzen, ist die Groesse das einzige
## Merkmal, an dem man sie auf See auseinanderhaelt - Regel A1.
@export var hull_scale: float = 1.0

@export_group("Mannschaft")
@export var min_crew: int = 10
@export var max_crew: int = 60

@export_group("Handel")
@export var base_price: int = 2000
