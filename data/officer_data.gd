## Ein benannter Offizier - Steuermann, Kanonier, Zimmermann, Quartiermeister.
##
## Offiziere sind Charaktere, keine Statuswerte: Sie fuehren im Enter-Gefecht
## eigene Einheiten und koennen sterben. Siehe KONZEPT.md, Abschnitt 5.1.
class_name OfficerData
extends Resource

enum Role { NAVIGATOR, GUNNER, CARPENTER, QUARTERMASTER }

@export var officer_name: String = ""
@export var role: Role = Role.NAVIGATOR
@export var portrait: Texture2D

@export_group("Faehigkeiten")
## Wirkt je nach Rolle: Navigation, Nachladezeit, Reparatur, Crew-Moral.
@export_range(1, 10) var skill: int = 3
## Kampfkraft im Enter-Gefecht.
@export_range(1, 10) var combat: int = 3

@export_group("Bindung")
## Sinkt bei ungerechter Beuteteilung und verlorenen Gefechten.
@export_range(0, 100) var loyalty: int = 50
## Anteil an der Beute in Prozent.
@export var share: int = 5
