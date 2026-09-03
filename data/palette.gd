## Die Farbpalette des Spiels - eine Quelle für alles Sichtbare.
##
## Regel: Keine Farbe wird irgendwo im Code direkt hingeschrieben. Wer eine
## braucht, holt sie hier. Vorher lagen dieselben Töne in sechs Dateien, teils
## leicht verschieden - Karte und Gelände zeigten unterschiedliches Grün für
## dieselbe Wiese.
##
## Ausnahme sind die Nationsfarben: Die stehen in resources/nations/*.tres,
## weil sie Spieldaten sind und nicht Gestaltung. Zur Übersicht unten notiert.
##
## Alle Werte sind sRGB. Für Vertex-Farben in Meshes IMMER [method for_vertex]
## benutzen - Godot 4 interpretiert Mesh-Farben als linear.
class_name Palette
extends RefCounted

# --- Die See ---------------------------------------------------------------
## Offene See, tiefstes Blau.
const DEEP_SEA := Color(0.043, 0.114, 0.196)
## Küstennahes Wasser.
const SHALLOW_SEA := Color(0.129, 0.353, 0.463)
## Untiefen und Riffe, der hellste Wasserton.
const SHOAL := Color(0.290, 0.549, 0.596)
## Meeresboden. Ohne eigenen Ton leuchtet Sand durch die Wellentäler.
const SEABED := Color(0.094, 0.243, 0.302)
## Schaumkronen.
const FOAM := Color(0.550, 0.780, 0.840)

# --- Das Land --------------------------------------------------------------
## Strand und Dünen.
const SAND := Color(0.847, 0.792, 0.616)
## Bewachsene Niederungen.
const GRASS := Color(0.325, 0.451, 0.286)
## Trockener Bewuchs an den Hängen.
const SCRUB := Color(0.451, 0.478, 0.298)
## Kahler Fels.
const ROCK := Color(0.427, 0.400, 0.353)
## Gipfel.
const PEAK := Color(0.788, 0.780, 0.757)

# --- Siedlungen ------------------------------------------------------------
## Gekalkte Mauern. Der hellste Ton an Land - eine Stadt soll sich schon von
## See aus vom Bewuchs abheben.
const WALL := Color(0.878, 0.855, 0.792)
## Ziegeldächer. Bewusst gedämpfter als DANGER: Rot bedeutet im Spiel Gefahr,
## und ein Dorf ist keine.
const ROOF := Color(0.541, 0.286, 0.216)
## Stege, Masten und Fahnenstangen an Land.
const PIER := Color(0.361, 0.286, 0.212)

# --- Schiff und Takelage ---------------------------------------------------
const HULL := Color(0.243, 0.153, 0.110)
## Das Freibord über dem Bergholz: Schanzkleid, Aufbauten, Achterdeckswand.
##
## Zuerst war alles über der Wasserlinie `TAR`, und die Karavelle war von der
## Seite ein schwarzer Klumpen mit hellem Deck. Ein Rumpf hat aber drei Bänder,
## nicht zwei: dunkler Boden, ein schwarzes Bergholz, darüber helleres Holz.
## Erst damit trennt sich das Achterdeck sichtbar vom Rumpf (Regel A11 —
## getrennt wird über Helligkeit).
const TOPSIDE := Color(0.392, 0.271, 0.180)
## Geteerte Bergholzer und die Wasserlinie - der dunkelste Ton am Schiff.
##
## Er zeichnet die Sprunglinie des Decks nach. Ohne dieses dunkle Band ist ein
## Rumpf aus der Entfernung eine braune Flaeche ohne Form (Regel A11: der
## Umriss traegt, nicht die Oberflaeche).
const TAR := Color(0.129, 0.098, 0.086)
## Rundhoelzer: Masten, Rahen, Bugspriet. Geoelt, also waermer als das Deck.
const TIMBER := Color(0.561, 0.416, 0.259)
## Decksplanken. Grauer und ausgeblichener als TIMBER - ein Deck liegt jahrelang
## in der Sonne, eine Rah wird geschmiert.
const DECK := Color(0.494, 0.427, 0.337)
const CANVAS := Color(0.914, 0.894, 0.827)
## Der Fuss des Segeltuchs, im Schatten des eigenen Bauchs. Ohne zweiten Ton
## ist ein Segel eine weisse Flaeche ohne Woelbung.
const CANVAS_SHADE := Color(0.741, 0.718, 0.655)
## Das Glas einer Laterne, solange sie kalt ist: rauchig, nicht weiss.
const GLASS := Color(0.62, 0.60, 0.55)
## Laternenlicht - Talg und Tran, also deutlich waermer als die Sonne.
## Der einzige Ton im Spiel, der bei Nacht leuchtet.
const LANTERN := Color(1.0, 0.72, 0.38)

# --- Himmel ----------------------------------------------------------------
## Sonnenlicht hoch am Tag: fast weiss, eine Spur warm.
const SUN_HIGH := Color(1.0, 0.97, 0.92)
## Sonnenlicht dicht am Horizont.
const SUN_LOW := Color(1.0, 0.62, 0.36)
## Mondlicht. Kalt und blau, und nur so hell, dass man noch fahren kann.
const MOONLIGHT := Color(0.58, 0.68, 0.86)
## Dunst am Tag - die Farbe, in der das Land am Horizont verschwindet.
const HAZE := Color(0.588, 0.690, 0.776)
## Derselbe Dunst bei Nacht.
const NIGHT_HAZE := Color(0.075, 0.098, 0.137)

# --- Gefecht ---------------------------------------------------------------
## Pulverdampf und Gischt. Der einzige Ton, der ueber der See heller ist als
## der Himmel - eine Breitseite soll man auch gegen die Sonne sehen.
const SMOKE := Color(0.898, 0.902, 0.886)
## Eisen: Kugeln in der Luft. Dunkel genug, um vor jeder See zu stehen.
const IRON := Color(0.145, 0.153, 0.169)

# --- Anzeigen --------------------------------------------------------------
## Fließtext und Zahlen im HUD.
const HUD_TEXT := Color(0.880, 0.930, 0.960)
## Nebensächliches, Beschriftungen.
const HUD_DIM := Color(0.850, 0.900, 0.930, 0.80)
## Umrandung hinter Text - das HUD trägt keine Kästen, nur Konturen.
const HUD_OUTLINE := Color(0.0, 0.0, 0.0, 0.75)
## Hintergrund von Karte und Menü.
const BACKDROP := Color(0.031, 0.063, 0.094, 0.92)
## Überschriften in Menü, Seekarte und Hafen - Pergament statt Weiß.
const PARCHMENT := Color(0.914, 0.816, 0.561)
## Nebensächliches in Menüs: Hinweise, abgeblendete Zeilen, Trennlinien.
const MUTED := Color(0.506, 0.588, 0.651)

## Zustandsfarben. Getrennt vom Akzent, damit sie ihre Bedeutung behalten.
const GOOD := Color(0.550, 0.780, 0.720)
const FAIR := Color(0.850, 0.760, 0.450)
const BAD := Color(0.850, 0.450, 0.360)

## Der Akzent des Spiels: Wind, Gold, alles Nautische.
const BRASS := Color(0.780, 0.570, 0.190)
## Warnungen, Sperrsektor, Norden auf dem Kompass.
const DANGER := Color(0.660, 0.260, 0.180)

# --- Nationen (Quelle: resources/nations/*.tres) ----------------------------
# Spanien      0.831, 0.627, 0.090   Gold
# England      0.690, 0.227, 0.180   Rot
# Frankreich   0.180, 0.373, 0.639   Blau
# Niederlande  0.851, 0.467, 0.024   Orange


## Wandelt eine Palettenfarbe für die Verwendung als Vertex-Farbe um.
##
## Godot 4 interpretiert Farben in Mesh-Arrays als linear, nicht als sRGB.
## Ohne diese Umrechnung wirkt alles ausgewaschen - die Inseln sahen aus wie
## Schneefelder.
static func for_vertex(color: Color) -> Color:
	return color.srgb_to_linear()


## Farbe mit anderer Deckkraft, ohne die Konstante zu kopieren.
static func fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## Ein reiner Grauwert - für Masken, nicht für Gestaltung.
##
## [ShipTextures] rechnet Planken- und Segeltuchmuster als Graustufen, die
## multiplikativ über die Vertexfarben laufen. Das ist keine Farbwahl und
## gehört deshalb nicht in eine Konstante; ohne diese Funktion stünde dort
## aber ein `Color(...)` außerhalb dieser Datei, und genau das verbietet der
## Rauchtest zu Recht.
static func grey(value: float) -> Color:
	var v := clampf(value, 0.0, 1.0)
	return Color(v, v, v)
