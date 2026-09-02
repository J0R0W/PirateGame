## Der Kaperbrief: die Gegenrichtung auf der Ansehensskala.
##
## Bis hierher konnte man Ruf nur verlieren. Jede Prise kostete Ansehen bei der
## bestohlenen Nation, und mehr passierte nicht - die Skala war ein Verfall,
## keine Entscheidung. Ein Kaperbrief dreht das um: Wer im Auftrag einer Krone
## faehrt, dem schreibt sie jede fremde Prise gut.
##
## Der Preis dafuer steht am Anfang, nicht am Ende. Einen Brief anzunehmen
## kostet bei allen uebrigen Kronen Ansehen ([constant RIVAL_COST]) - man
## waehlt eine Seite, und die anderen erfahren davon. Deshalb gibt es auch nur
## einen Brief zur Zeit: Vier Briefe waeren vier Freunde und keine Wahl.
##
## Nodefrei und statisch (Regel B3), wie [Standing]: Ob ein Gouverneur einen
## Brief ausstellt, ist eine Frage an eine Zahl, keine an eine Szene.
class_name LetterOfMarque
extends RefCounted

## Kein Brief in der Tasche. Sonst steht hier die Nations-Id des Patrons.
const NONE: int = -1


## Was eine genommene Prise mit dem Brief macht.
##
## Drei Faelle statt eines Wahrheitswerts: gutgeschrieben, gar nicht betroffen,
## oder der Brief ist eingezogen. Der dritte ist der Grund fuer die
## Aufzaehlung - ein "nein" waere von "hat nichts damit zu tun" nicht zu
## unterscheiden, und der Brief verschwaende lautlos.
enum Verdict { NONE, CREDITED, REVOKED }

## Ab diesem Verhaeltnis stellt ein Gouverneur einen Brief aus.
##
## Nicht erst bei FRIENDLY: Zu Beginn steht der Spieler bei allen vier Kronen
## auf null, und ein Brief, den man sich erst verdienen muss, waere kein
## Einstieg in das System, sondern ein Preis dafuer, es schon zu kennen. Wer
## sich dagegen misstrauisch gemacht hat, kommt beim Gouverneur nicht mehr vor -
## und merkt daran, dass die Stufe zwischen offen und verschlossen etwas tut.
const ISSUE_FROM: Standing.Level = Standing.Level.NEUTRAL

## Was die uebrigen Kronen davon halten, dass man fuer eine von ihnen faehrt.
##
## Bewusst kleiner als der Verlust einer Prise (-8): Ein Brief ist eine
## Absichtserklaerung, kein Ueberfall. Drei Kronen zu je -5 machen ihn trotzdem
## zu einer Entscheidung, die man nicht nebenbei trifft.
const RIVAL_COST: int = -5

## Was der Patron einer Prise gutschreibt, die unter seinem Brief faellt.
##
## Kleiner als die -8, die dieselbe Prise beim Bestohlenen kostet: Kapern
## bleibt unterm Strich ein Ansehensverlust in der Welt. Der Brief verschiebt
## nur, wo der Verlust anfaellt - man arbeitet sich bei einem hoch, waehrend
## man bei den anderen faellt.
const PRIZE_REWARD: int = 5

## Und was es kostet, das Schiff des eigenen Patrons aufzubringen.
##
## Kommt auf den gewoehnlichen Prisenverlust obendrauf. Der Brief ist danach
## eingezogen - eine Krone, die man selbst bestiehlt, laesst einen nicht
## weiterfahren.
const BETRAYAL_COST: int = -12

## Ab dieser Stadtgroesse sitzt ein Gouverneur.
##
## Ein Dorf hat keinen. Das ist der erste Grund im Spiel, eine groessere Stadt
## anzulaufen, der nichts mit Preisen zu tun hat - und macht [member
## TownData.size_tier] zu mehr als einer Zahl auf dem Marktbildschirm.
const SEAT_FROM_TIER: int = 1


## Sitzt in dieser Stadt ein Gouverneur?
static func has_seat(size_tier: int) -> bool:
	return size_tier >= SEAT_FROM_TIER


## Stellt diese Krone bei diesem Verhaeltnis einen Brief aus?
##
## [param level] laeuft von ALLIED nach HOSTILE, gute Verhaeltnisse haben also
## die kleineren Werte - siehe [enum Standing.Level].
static func can_issue(level: Standing.Level) -> bool:
	return level <= ISSUE_FROM


## Deckt der Brief eine Prise gegen diese Nation?
##
## Nur die Krone, mit der der Patron gerade Krieg fuehrt ([Diplomacy]). Bis M6
## war es alles ausser der eigenen Flagge - ein Brief, der jede fremde Prise
## gutschreibt, ist aber keine Entscheidung, sondern ein Freibrief. Jetzt
## waehlt man mit dem Patron zugleich sein Jagdrevier, und ein Friedensschluss
## verschiebt es.
##
## [param enemy_id] kommt von aussen und wird nicht selbst nachgeschlagen: Die
## Regel soll ohne Welt und ohne Uhr pruefbar bleiben (Regel B3). Wer sie mit
## dem laufenden Spiel fragen will, nimmt [method GameState.letter_covers].
static func covers(patron_id: int, victim_id: int, enemy_id: int) -> bool:
	return (
		patron_id != NONE
		and victim_id >= 0
		and victim_id != patron_id
		and victim_id == enemy_id
	)


## Ist das der Ueberfall auf den eigenen Auftraggeber?
static func is_betrayal(patron_id: int, victim_id: int) -> bool:
	return patron_id != NONE and victim_id == patron_id


## Wie der Brief im Hafen und auf der Seekarte heisst.
##
## Ueber das Adjektiv der Nation und nicht ueber ihren Namen: "spanischer
## Kaperbrief" liest sich wie das Segel im HUD ("Spanische Patrouille"), waehrend
## ein Genitiv an "die Niederlande" scheitert.
static func title_of(patron: NationData) -> String:
	if patron == null:
		return "Kein Kaperbrief"
	return "%ser Kaperbrief" % patron.adjective.capitalize()
