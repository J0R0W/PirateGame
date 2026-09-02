## Das Kopfgeld: was eine Krone tut, wenn sie genug von einem hat.
##
## Die Gegenseite zu [Commission] und aus derselben Maschinerie gebaut - ein
## [Adversary], absichtlich gesetzt statt aus dem Zufall gespuelt. Nur zeigt
## der Steckbrief diesmal auf den Spieler.
##
## Damit bekommt die zweite Ansehensachse endlich eine Folge. Beruechtigtheit
## ([member GameState.notoriety]) waechst seit M4 mit jeder Prise und sinkt
## nie, aber sie tat bis hierher nur eines: Gegner strichen frueher die Flagge
## ([method Gunnery.will_strike]). Ein Ruf, der ausschliesslich hilft, ist kein
## Preis - jetzt schickt er einem jemanden hinterher.
##
## Nodefrei und statisch (Regel B3).
class_name Bounty
extends RefCounted

## Ab dieser Beruechtigtheit lohnt sich der Aufwand fuer eine Krone.
##
## Rund zehn Prisen ([constant NavalCombat.PRIZE_NOTORIETY] = 3 je Stueck).
## Frueher waere es eine Strafe fuers Anfangen, spaeter merkte man es nicht
## mehr - bei fuenfzig Punkten hat man laengst ein groesseres Schiff im Blick.
const HUNTED_FROM: int = 35

## Und ab hier schicken sie keine Patrouille mehr, sondern eine Fregatte.
const FEARED_FROM: int = 65

## Der Vorschuss, den ein Kopfgeldjaeger in der Kajuete hat - Grundbetrag ...
const PURSE_BASE: int = 260
## ... und soviel je Punkt Beruechtigtheit obendrauf.
##
## Sein Kopfgeld ist das eigene: Wer teurer ausgeschrieben ist, dem schickt man
## einen teurer bezahlten Jaeger hinterher. Damit ist der Mann, den man am
## wenigsten treffen will, auch die beste Prise auf See - das ist die Abwaegung,
## die aus einer Verfolgung mehr macht als eine Belaestigung.
const PURSE_PER_POINT: int = 14

## Sekunden Ruhe, nachdem einer erledigt ist.
##
## Ohne das steht der naechste in einer halben Minute am Horizont, und ein
## beruechtigter Kapitaen kaeme nie mehr zum Handeln. Vier Minuten sind rund ein
## Spieltag.
const REST_SECONDS: float = 240.0

const PATROL_CLASS: String = "res://resources/ships/patrol_sloop.tres"
const FRIGATE_CLASS: String = "res://resources/ships/frigate.tres"


## Schickt diese Krone einen Jaeger?
##
## Zwei Achsen, wie in KONZEPT 5.3 vorgesehen: Die Beruechtigtheit entscheidet,
## *ob* ueberhaupt jemand ausfaehrt, das Verhaeltnis, *wer* ihn schickt.
##
## Und zwar nur eine feindliche Krone. Bei "misstrauisch" schickt schon eine
## aggressive Nation ihre Patrouillen los ([method Standing.hunts_player]) - das
## ist die Stufe, auf der man beschossen wird. Ein Kopfgeld ist der Schritt
## danach: Nicht mehr "wir greifen dich an, wenn wir dich sehen", sondern "wir
## suchen dich".
static func due(notoriety: int, level: Standing.Level) -> bool:
	return notoriety >= HUNTED_FROM and level == Standing.Level.HOSTILE


## Auf welchem Schiff er kommt.
static func class_for(notoriety: int) -> String:
	return FRIGATE_CLASS if notoriety >= FEARED_FROM else PATROL_CLASS


## Was er an Bord hat.
static func purse(notoriety: int) -> int:
	return PURSE_BASE + PURSE_PER_POINT * clampi(notoriety, 0, 100)


## Wuerfelt den Jaeger aus, den diese Krone schickt.
##
## Anders als beim Auftrag mit einem freien Wuerfel: Ein Steckbrief im Palast
## muss bei jedem Hinsehen derselbe sein, ein Verfolger nicht. Der naechste darf
## ein anderer Mann auf einem anderen Schiff sein - sonst waere es immer
## dieselbe Begegnung.
static func hunter(
	rng: RandomNumberGenerator, nation: NationData, notoriety: int
) -> Adversary:
	return Adversary.make(rng, nation, class_for(notoriety), true)
