## Das Entern - ein Gefecht an Deck, gerechnet statt gefochten.
##
## Tier 0 loest das Entern als Wurf auf, nicht als Taktikgefecht: Das Gitter
## mit benannten Offizieren steht in KONZEPT 3.4 und gehoert zu Tier 1, weil es
## Offiziere braucht, die es noch nicht gibt. Die Liste in KONZEPT 6 sagt das
## ausdruecklich - "Entern (zunaechst als Wuerfelwurf-Aufloesung)".
##
## Warum es trotzdem jetzt schon da sein muss: Ohne Entern fuehrt genau ein Weg
## zur Prise - den Gegner beschiessen, bis er streicht. Mannschaft ist damit im
## Gefecht nur etwas, das man verliert, und nie etwas, das man einsetzt.
## [method Ship.readiness] behauptet seit M4 im eigenen Kommentar, die ersten
## Verluste kosteten "Enterstaerke" - erst hier wird das wahr.
##
## Die Entscheidung, um die es geht: Ein unversehrter Gegner streicht nicht.
## Wer ihn zusammenschiesst, braucht Zeit, Pulver und faengt selbst Schaden.
## Wer laengsseits geht und uebersetzt, hat ihn in einem Zug - und zahlt mit
## Leuten, die danach an Schoten und Rohren fehlen.
class_name Boarding
extends RefCounted


## So dicht muss man liegen, um ueberzusetzen.
##
## Deutlich enger als [constant NavalCombat.PRIZE_RANGE], mit der man eine
## bereits gestrichene Prise ausraeumt: Entern ist ein Manoever, kein Knopf.
## Wer entern will, muss sich in die Breitseite des Gegners legen.
const REACH: float = 45.0

## Wer an Deck verteidigt, steht hinter Schanzkleid und Geschuetzen. Ein
## Angreifer braucht Ueberzahl, nicht Gleichstand - sonst waere Entern immer
## die richtige Antwort und das Schiessen ueberfluessig.
const DEFENCE_BONUS: float = 1.35

## Was Beruechtigtheit an Deck wert ist. Bei 100 kaempft die eigene Mannschaft
## wie ein gutes Drittel mehr Leute: der gefuerchtete Pirat aus KONZEPT 3.4,
## der Gefechte gewinnt, ohne einen Schuss abzugeben.
const FEAR_BONUS: float = 0.35

## Wieviel Mut ein zerschossener Rumpf den Verteidigern nimmt. Bei einem Wrack
## kaempfen sie mit dem Rest ihrer Kraft - deshalb lohnt sich eine Breitseite
## vor dem Uebersetzen, auch wenn sie den Gegner nicht zum Streichen bringt.
const HULL_MORALE: float = 0.4

## Wieviel eine Seite hoechstens an Leuten verliert. Der tatsaechliche Verlust
## haengt daran, wie stark die Gegenseite war - siehe [method resolve].
const LOSS_RATE: float = 0.45

## Streuung der Verluste. Ein Enterkampf ist keine Rechenaufgabe; zwei gleiche
## Ausgangslagen sollen unterschiedlich teuer ausgehen.
const LOSS_SPREAD: float = 0.3

## So lange dauert es, die Enterhaken wieder klarzumachen. Ohne diese Sperre
## waere ein abgeschlagener Sturm nur ein zweiter Tastendruck.
const RECOVERY_SECONDS: float = 25.0


## Der Ausgang eines Enterkampfs.
##
## Bewusst eine innere Klasse und keine eigene Datei: Sie entsteht nur hier und
## wird nur vom Aufrufer gelesen. Ein weiteres [code]class_name[/code] waere
## eine Datei mehr und ein Import mehr, den man vergessen kann.
class Result extends RefCounted:
	## Hat der Angreifer das Deck genommen?
	var won: bool = false
	## Gefallene auf beiden Seiten, in Mann.
	var attacker_losses: int = 0
	var defender_losses: int = 0


## Die Enterstaerke einer angreifenden Mannschaft.
##
## [param fear] ist die Beruechtigtheit des Angreifers, 0.0 bis 1.0 - dieselbe
## Groesse, mit der [method Gunnery.will_strike] rechnet.
static func attack_strength(crew: int, fear: float) -> float:
	return float(maxi(crew, 0)) * (1.0 + FEAR_BONUS * clampf(fear, 0.0, 1.0))


## Die Enterstaerke einer verteidigenden Mannschaft.
##
## Verteidigen ist leichter als uebersetzen, aber ein durchschossener Rumpf
## nimmt den Mut. Beides zusammen entscheidet, ob eine Breitseite vor dem
## Sturm sich lohnt.
static func defence_strength(crew: int, hull_fraction: float) -> float:
	var morale := 1.0 - HULL_MORALE * (1.0 - clampf(hull_fraction, 0.0, 1.0))
	return float(maxi(crew, 0)) * DEFENCE_BONUS * morale


## Der Anteil des Angreifers an der Gesamtstaerke, 0.0 bis 1.0.
##
## Das ist zugleich seine Siegchance und das Mass fuer die Verluste beider
## Seiten - eine Zahl, kein Dutzend Regeln.
static func odds(attack: float, defence: float) -> float:
	var total := attack + defence
	if total <= 0.0:
		return 0.0
	return clampf(attack / total, 0.0, 1.0)


## Kann man von hier aus uebersetzen?
##
## Ein gesunkenes oder bereits gestrichenes Schiff entert man nicht - das eine
## ist weg, das andere raeumt man aus. Und ohne Leute an Bord geht niemand
## hinueber.
static func can_board(distance: float, attacker_crew: int, target_struck: bool,
		target_finished: bool) -> bool:
	return distance <= REACH \
		and attacker_crew > 0 \
		and not target_struck \
		and not target_finished


## Rechnet einen Enterkampf aus.
##
## Die Verluste einer Seite haengen an der Staerke der anderen: Ein aussichts-
## loser Sturm ist ein Gemetzel fuer den Angreifer, ein uebermaechtiger kostet
## fast nichts. Ein Gefecht auf Augenhoehe kostet beide die Haelfte. Damit
## braucht es keine getrennte Regel fuer Sieger und Verlierer - der Ausgang
## faellt mit demselben Wert, mit dem die Verluste fallen.
static func resolve(rng: RandomNumberGenerator, attacker_crew: int, fear: float,
		defender_crew: int, defender_hull_fraction: float) -> Result:
	var attack := attack_strength(attacker_crew, fear)
	var defence := defence_strength(defender_crew, defender_hull_fraction)
	var share := odds(attack, defence)

	var result := Result.new()
	result.won = rng.randf() < share
	result.attacker_losses = _losses(rng, attacker_crew, 1.0 - share)
	result.defender_losses = _losses(rng, defender_crew, share)
	return result


## Verluste einer Seite: [param pressure] ist der Anteil der Gegenseite an der
## Gesamtstaerke. Mindestens ein Mann, solange ueberhaupt jemand da ist - ein
## Enterkampf ohne Gefallene waere keiner.
static func _losses(rng: RandomNumberGenerator, crew: int, pressure: float) -> int:
	if crew <= 0:
		return 0
	var share := clampf(pressure, 0.0, 1.0) * LOSS_RATE
	var spread := 1.0 + rng.randf_range(-LOSS_SPREAD, LOSS_SPREAD)
	return clampi(int(round(float(crew) * share * spread)), 1, crew)
