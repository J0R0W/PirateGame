## Globale Signal-Sammelstelle.
##
## Enthaelt bewusst KEINE Logik - nur Signale. Sender und Empfaenger muessen
## einander dadurch nicht kennen, was Modus-Szenen entkoppelt haelt.
##
## Senden:   EventBus.gold_changed.emit(GameState.gold)
## Empfangen: EventBus.gold_changed.connect(_on_gold_changed)
extends Node

# --- Schiffe & Kampf ---
signal ship_spawned(ship: Node)
signal ship_sunk(ship: Node)
signal ship_boarded(ship: Node)
signal cannons_fired(ship: Node, side: int)
## Ein fremdes Segel ist in Sicht gekommen.
signal sail_sighted(ship_name: String, nation_id: int, warship: bool)
## Und ein benanntes: das Ziel eines Auftrags oder ein Kopfgeldjaeger.
##
## Eigenes Signal neben [signal sail_sighted]: Ein Segel am Horizont ist eine
## Beobachtung, ein Steckbrief am Horizont eine Nachricht. Wer beides in eine
## Meldung packt, verliert genau die, auf die es ankommt.
signal named_captain_sighted(captain_name: String, ship_name: String, nation_id: int, hunting: bool)
## Eine Breitseite ist eingeschlagen. [param by_player] trennt Freud und Leid.
signal broadside_landed(by_player: bool, hits: int, shots: int)
## Ein Gegner hat die Flagge gestrichen und wartet auf das Prisenkommando.
signal ship_struck(ship_name: String)
## Prise genommen: Gold und Ladungseinheiten, die an Bord gingen.
##
## Die Nation steht mit dabei, seit ein Kaperbrief entscheidet, ob dieselbe
## Prise ein Auftrag oder eine Raeuberei ist.
signal prize_taken(ship_name: String, nation_id: int, gold: int, units: int)
## Ein Enterkampf ist ausgefochten. [param won] heisst: Das Deck ist genommen.
signal boarding_resolved(ship_name: String, won: bool, own_losses: int, their_losses: int)
## Das eigene Schiff ist gefechtsunfaehig. Der Gegner nimmt sich, was er will.
signal player_struck(lost_gold: int, lost_units: int)

# --- Schiff des Spielers ---
signal cargo_changed(cargo_id: StringName, new_amount: int)
signal ship_condition_changed(hull: int, sails: int)
signal ran_aground(damage: int)

# --- Handel ---
## Eine abgeschlossene Transaktion. Menge negativ heisst: verkauft.
signal trade_completed(town_id: int, cargo_id: StringName, amount: int, gold_delta: int)
signal ship_repaired(town_id: int, cost: int)
signal crew_hired(town_id: int, count: int)

# --- Spielerzustand ---
signal gold_changed(new_amount: int)
signal crew_changed(new_amount: int)
signal reputation_changed(nation_id: int, new_value: int)
signal notoriety_changed(new_value: int)
## Ein Kaperbrief ist angenommen, zurueckgegeben oder eingezogen worden.
## -1 heisst: keiner mehr.
signal letter_changed(nation_id: int)
## Am Auftrag des Gouverneurs hat sich etwas getan. [param change] ist ein
## [enum Commission.Change].
##
## Ein Signal fuer alle vier Faelle statt vier Signale: Palast, Seekarte und HUD
## wollen bei jedem davon dasselbe tun, naemlich neu zeichnen. Nur die
## Meldezeile auf See unterscheidet sie.
signal commission_changed(change: int)

# --- Welt ---
## Die Kronen haben ihre Buendnisse neu geordnet: Aus einem Krieg ist Frieden
## geworden und anderswo umgekehrt (siehe [Diplomacy]).
##
## Nur der Tag geht mit, keine Aufzaehlung der Kriege. Wer die Meldung
## schreibt, rechnet sich die neue Lage ohnehin aus Seed und Tag aus - sie
## zweimal zu uebertragen waere eine zweite Wahrheit ueber dieselbe Sache
## (Regel B4).
signal treaties_changed(day: int)
signal wind_changed(direction: float, strength: float)
signal weather_changed(state: int)
signal day_passed(day: int)

# --- Modi ---
signal port_entered(town_id: int)
signal port_left(town_id: int)
## Der Hafen ist in Reichweite, oder gerade nicht mehr. -1 heisst ausser Reichweite.
signal dock_target_changed(town_id: int)
## Eine Prise liegt laengsseit, oder nicht mehr. Leerer Name heisst: keine.
signal prize_target_changed(ship_name: String)
## Ein Gegner liegt nahe genug zum Entern, oder nicht mehr. Leer heisst: keiner.
signal boarding_target_changed(ship_name: String)
signal mode_changed(mode_path: String)
