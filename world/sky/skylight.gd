## Der Himmel ueber der Karibik: Sonnenstand, Dunst und Sicht aus Uhrzeit und
## Wetter gerechnet.
##
## Bis hierher stand die Sonne fest bei Mittag, und der Dunst war eine Zahl in
## der Szene. Regel A11 sagt "nicht immer Mittag - WorldData.Weather gehoert
## ins Bild", und der Anlass, das einzuloesen, war eine Frage nach Laternen:
## Ein Schiff kann bei schlechter Sicht nur dann Licht machen, wenn es so etwas
## wie schlechte Sicht ueberhaupt gibt.
##
## Nodefrei (Regel B3): Alles hier ist eine reine Funktion aus Tageszeit
## (0.0 bis 1.0, siehe [method GameState.time_of_day]) und Wetter. Der
## Segelmodus schreibt die Werte je Bild in Sonne und Umgebung, das Schiff
## fragt nur [method visibility] und [method lanterns_lit].
##
## [b]Ein Spieltag dauert vier Minuten[/b] (GameState.MINUTES_PER_SECOND).
## Daemmerung kommt also alle paar Minuten. Das ist Absicht und kein Fehler -
## Pirates! (2004) laesst die Tage auf See genauso schnell laufen - aber es
## verlangt, dass die Nacht [i]spielbar[/i] bleibt: Sie ist mondhell, nicht
## schwarz, und der Dunst wird dunkel statt dicht.
class_name Skylight
extends RefCounted

## Sonnenaufgang und -untergang als Anteil des Tages: sechs und achtzehn Uhr.
## Die Karibik liegt nah am Aequator, dort schwankt das kaum uebers Jahr.
const SUNRISE: float = 0.25
## Wie weit die Sonnenbahn nach Sueden geneigt ist, in Grad. Auf 15 bis 20
## Grad Nord steht die Mittagssonne knapp suedlich des Zenits.
const TILT_DEG: float = 20.0

## Sonnenlicht bei klarem Himmel und hohem Stand.
const SUN_ENERGY: float = 1.15
## Mondlicht. Gemessen am Ergebnis, nicht an der Physik: So hell, dass man
## Kueste und Segel eines Gegners noch erkennt.
const MOON_ENERGY: float = 0.22
## Umgebungslicht am Tag und bei Nacht.
const DAY_AMBIENT: float = 0.6
const NIGHT_AMBIENT: float = 0.9
## Helligkeit des Himmels, als Faktor auf die Himmelsfarben der Szene.
const DAY_SKY: float = 1.0
const NIGHT_SKY: float = 0.05

## Dunstdichte je Wetter, Reihenfolge wie [enum WorldData.Weather].
## 0.0009 ist der Wert, der seit M2 in der Szene stand; alles darueber ist
## ungemessen und wartet auf die erste Aufnahme.
const FOG_BY_WEATHER: PackedFloat32Array = [0.0009, 0.0014, 0.0032, 0.0050]
## Wie viel vom Tageslicht das Wetter uebrig laesst - und zugleich, wie weit
## man sieht. Dieselbe Zahl fuer beides: Was das Licht nimmt, nimmt die Sicht.
const SIGHT_BY_WEATHER: PackedFloat32Array = [1.0, 0.85, 0.40, 0.25]

## Ab welcher Sicht ein Kapitaen die Laternen anzuenden laesst - und ab
## welcher er sie wieder loescht. Zwei Schwellen statt einer: Bei einer
## einzigen flackerten die Lichter in der Daemmerung minutenlang um den
## Grenzwert herum.
const LIGHT_BELOW: float = 0.45
const DOUSE_ABOVE: float = 0.60


## Hoehe der Sonne ueber dem Horizont, -1 bis 1. Null bei Auf- und Untergang.
static func elevation(time_of_day: float) -> float:
	return sin((time_of_day - SUNRISE) * TAU)


## Ist die Sonne unter?
static func is_night(time_of_day: float) -> bool:
	return elevation(time_of_day) < 0.0


## Wo die Sonne steht, als Einheitsvektor vom Betrachter aus.
##
## Sie geht im Osten (+X) auf, steht mittags knapp suedlich (+Z) des Zenits
## und geht im Westen unter. Norden ist -Z, wie beim Kurs des Schiffes.
static func sun_position(time_of_day: float) -> Vector3:
	var angle := (time_of_day - SUNRISE) * TAU
	var tilt := deg_to_rad(TILT_DEG)
	return Vector3(cos(angle), sin(angle) * cos(tilt), sin(angle) * sin(tilt))


## Richtung, in die das Licht faellt - von der Sonne, nachts vom Mond.
##
## Der Mond steht der Sonne gegenueber. Das ist astronomisch nur bei Vollmond
## richtig und hier immer so, weil es genau eine Lichtquelle geben soll und
## sie nachts von der anderen Seite kommen muss - sonst laege der Schatten
## eines Segels bei Mondschein dort, wo er mittags lag.
static func light_direction(time_of_day: float) -> Vector3:
	var sun := sun_position(time_of_day)
	if sun.y < 0.0:
		sun = -sun
	return -sun


## Staerke des gerichteten Lichts - Sonne oder Mond, je nach Stand.
##
## Beide Kurven enden bei null, bevor die Richtung umschlaegt: Der Wechsel
## von Sonne zu Mond ist dadurch unsichtbar, statt dass alle Schatten in
## einem Bild die Seite wechseln.
static func light_energy(time_of_day: float, weather: int) -> float:
	var up := elevation(time_of_day)
	var sun := smoothstep(0.0, 0.22, up) * SUN_ENERGY
	var moon := smoothstep(0.0, 0.22, -up) * MOON_ENERGY
	return (sun + moon) * _sight_factor(weather)


## Farbe des gerichteten Lichts: warm am Horizont, weiss am Tag, blau nachts.
static func light_colour(time_of_day: float) -> Color:
	var up := elevation(time_of_day)
	if up < 0.0:
		return Palette.MOONLIGHT
	return Palette.SUN_LOW.lerp(Palette.SUN_HIGH, smoothstep(0.0, 0.35, up))


## Umgebungslicht. Nachts hoeher als am Tag, weil es dann fast das einzige
## Licht ist - der Himmel selbst ist auf ein Zwanzigstel gedimmt.
static func ambient_energy(time_of_day: float) -> float:
	return lerpf(NIGHT_AMBIENT, DAY_AMBIENT, _daylight(time_of_day))


## Helligkeit des Himmels.
static func sky_energy(time_of_day: float) -> float:
	return lerpf(NIGHT_SKY, DAY_SKY, _daylight(time_of_day))


## Dunstdichte, nur vom Wetter abhaengig.
static func fog_density(weather: int) -> float:
	return FOG_BY_WEATHER[clampi(weather, 0, FOG_BY_WEATHER.size() - 1)]


## Farbe des Dunstes - er wird nachts dunkel, nicht dicht.
static func fog_colour(time_of_day: float) -> Color:
	return Palette.NIGHT_HAZE.lerp(Palette.HAZE, _daylight(time_of_day))


## Wie weit man sieht, 0.0 bis 1.0. Die Zahl, die Laternen und spaeter der
## Ausguck lesen.
##
## Tageslicht mal Wetter: Ein klarer Mittag ist 1.0, ein Sturm am Mittag 0.25,
## eine klare Nacht 0.0. Das Produkt und nicht das Minimum, damit ein Regen in
## der Daemmerung schlechter ist als beides fuer sich.
static func visibility(time_of_day: float, weather: int) -> float:
	return _daylight(time_of_day) * _sight_factor(weather)


## Sollen die Laternen brennen?
##
## [param lit] ist der jetzige Zustand: Angezuendet wird unter LIGHT_BELOW,
## geloescht erst wieder ueber DOUSE_ABOVE. Dazwischen bleibt, was ist.
static func lanterns_lit(sight: float, lit: bool) -> bool:
	if lit:
		return sight < DOUSE_ABOVE
	return sight < LIGHT_BELOW


## Uhrzeit als Text fuers Debug-Menue und die Aufnahmen.
static func clock(time_of_day: float) -> String:
	# Abgerundet wie im HUD - zwei Uhren, die um eine Minute auseinander
	# liegen, sehen aus wie ein Fehler.
	var minutes := int(floor(wrapf(time_of_day, 0.0, 1.0) * 1440.0))
	return "%02d:%02d" % [(minutes / 60) % 24, minutes % 60]


## Tageslicht 0.0 bis 1.0 mit einer Daemmerung von etwa einer Stunde zu
## beiden Seiten des Horizonts.
static func _daylight(time_of_day: float) -> float:
	return smoothstep(-0.12, 0.25, elevation(time_of_day))


static func _sight_factor(weather: int) -> float:
	return SIGHT_BY_WEATHER[clampi(weather, 0, SIGHT_BY_WEATHER.size() - 1)]
