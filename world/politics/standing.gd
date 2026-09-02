## Was eine Nation vom Spieler haelt - und was daraus folgt.
##
## M6 beginnt hier. Bis dahin wurde Ansehen zwar gefuehrt (GameState.reputation,
## -100 bis +100 je Nation) und von Prisen veraendert, aber nichts las es je
## aus: Jede Patrouille griff jeden an, jeder Hafen stand jedem offen. Auch
## [member NationData.aggression] und [member NationData.reputation_sensitivity]
## standen seit M2 in allen vier .tres-Dateien, ohne dass eine Zeile Code sie
## angefasst haette.
##
## Nodefrei und statisch (Regel B3): Ob ein Hafen zumacht, ist eine Frage an
## eine Zahl, keine an eine Szene - und laesst sich damit ohne Fenster pruefen.
class_name Standing
extends RefCounted


## Wie eine Nation zum Spieler steht. Die Reihenfolge ist die Skala: ALLIED ist
## das beste Verhaeltnis, HOSTILE das schlechteste. Wer vergleicht, darf sich
## darauf verlassen.
enum Level { ALLIED, FRIENDLY, NEUTRAL, SUSPECT, HOSTILE }

## Untergrenzen der Stufen auf der Ansehensskala.
##
## Nicht symmetrisch: Nach unten liegen die Schwellen enger beieinander als nach
## oben. Ein guter Ruf soll erarbeitet werden, ein schlechter schneller kommen -
## eine gekaperte Prise kostet acht Punkte, ein Gefallen bringt selten mehr.
const ALLIED_FROM: int = 60
const FRIENDLY_FROM: int = 20
const NEUTRAL_FROM: int = -15
const SUSPECT_FROM: int = -45

## Ab dieser Stufe macht der Hafen zu.
##
## Nicht schon bei SUSPECT: Wer misstrauisch beaeugt wird, soll trotzdem
## einlaufen koennen - sonst faellt der Spieler nach zwei Prisen aus dem
## halben Spiel heraus, ohne je gemerkt zu haben, dass es eine Skala gibt
## (Design-Pillar "Konsequenz statt Bestrafung").
const PORT_CLOSED_AT: Level = Level.HOSTILE

## Ab dieser Stufe kann eine Patrouille von sich aus angreifen.
const HUNTS_FROM: Level = Level.SUSPECT

## Wie unnachgiebig eine Nation bei SUSPECT ist, bevor ihre Aggression zaehlt.
##
## Bei HOSTILE greift jede an. Bei SUSPECT entscheidet [member
## NationData.aggression]: Spanien (0.7) jagt frueher als die Niederlande (0.4).
## Genau dafuer steht der Wert seit M2 in den Dateien.
const SUSPECT_AGGRESSION: float = 0.5


## Die Stufe zu einem Ansehenswert.
static func level_of(reputation: int) -> Level:
	if reputation >= ALLIED_FROM:
		return Level.ALLIED
	if reputation >= FRIENDLY_FROM:
		return Level.FRIENDLY
	if reputation >= NEUTRAL_FROM:
		return Level.NEUTRAL
	if reputation >= SUSPECT_FROM:
		return Level.SUSPECT
	return Level.HOSTILE


## Wie es im Hafen und auf der Seekarte heisst.
static func title_of(level: Level) -> String:
	match level:
		Level.ALLIED:
			return "Verbündet"
		Level.FRIENDLY:
			return "Wohlgesonnen"
		Level.NEUTRAL:
			return "Gleichgültig"
		Level.SUSPECT:
			return "Misstrauisch"
		_:
			return "Feindlich"


## Die Farbe, in der ein Verhaeltnis angezeigt wird.
##
## Hier und nicht in den Anzeigen: Seekarte und Gouverneurspalast zeigen
## dieselbe Skala, und zwei Farbtabellen fuer dieselben fuenf Stufen laufen
## frueher oder spaeter auseinander (Regel B4).
##
## Farbregel A5: Gruen heisst gut fuer dich. Rot bleibt der Feindschaft
## vorbehalten - sie ist der Zustand, der wirklich etwas kostet.
static func color_of(level: Level) -> Color:
	match level:
		Level.ALLIED, Level.FRIENDLY:
			return Palette.GOOD
		Level.SUSPECT:
			return Palette.FAIR
		Level.HOSTILE:
			return Palette.BAD
		_:
			return Palette.MUTED


## Steht der Hafen offen?
static func port_open(level: Level) -> bool:
	return level < PORT_CLOSED_AT


## Greift eine Patrouille dieser Nation von sich aus an?
##
## [param aggression] ist [member NationData.aggression], 0.0 bis 1.0. Sie
## entscheidet nur im Graubereich: Wer feindlich steht, wird immer gejagt, wer
## gleichgueltig oder besser steht, nie.
static func hunts_player(level: Level, aggression: float) -> bool:
	if level == Level.HOSTILE:
		return true
	if level < HUNTS_FROM:
		return false
	return aggression >= SUSPECT_AGGRESSION


## Reicht das Verhaeltnis, dass blosse Naehe schon als Bedrohung gilt?
##
## Bis M6 wurde jedes Schiff im Umkreis von 300 Metern dauerhaft "provoziert" -
## auch das einer Nation, der man nie etwas getan hat. Eine befreundete
## Patrouille soll vorbeifahren duerfen.
static func wary_of_player(level: Level) -> bool:
	return level >= HUNTS_FROM


## Ansehensaenderung, gewichtet mit der Empfindlichkeit der Nation.
##
## [param sensitivity] ist [member NationData.reputation_sensitivity]. Spanien
## (1.2) nimmt eine Prise schwerer als die Niederlande (0.8) - die handeln mit
## jedem. Gerundet wird vom Betrag weg, damit eine kleine Tat bei einer
## unempfindlichen Nation nicht auf null faellt und wirkungslos bleibt.
static func weighted_change(amount: int, sensitivity: float) -> int:
	if amount == 0:
		return 0
	var scaled := float(amount) * maxf(sensitivity, 0.0)
	return signi(amount) * maxi(int(round(absf(scaled))), 1)
