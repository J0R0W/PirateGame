## Eine zusammenhaengende Landmasse aus der Weltgenerierung.
##
## Wird zur Laufzeit vom WorldGenerator erzeugt, nicht von Hand angelegt -
## deshalb Variablen statt @export.
class_name IslandData
extends Resource

var id: int = 0
## Flaeche in Quadratkilometern.
var area_km2: float = 0.0
## Schwerpunkt in Weltkoordinaten (Meter).
var center: Vector2 = Vector2.ZERO
## Umschliessendes Rechteck in Weltkoordinaten.
var bounds: Rect2 = Rect2()
## Hoechster Punkt als Hoehenwert 0..1.
var peak: float = 0.0
## Alle Kuestenzellen des Analyse-Rasters.
var coast_cells: PackedVector2Array = PackedVector2Array()
## Kuestenzellen mit tiefem Wasser in Reichweite - die guten Hafenplaetze.
var harbour_cells: PackedVector2Array = PackedVector2Array()
## Ids der Staedte auf dieser Insel.
var town_ids: PackedInt32Array = PackedInt32Array()


## Traegt die Insel Siedlungen? Felsen unter der Mindestgroesse nicht.
func is_settleable() -> bool:
	return area_km2 >= 2.0


## Hafenplaetze, mit Rueckfall auf einfache Kueste. Eine harte
## Tiefwasserbedingung wuerde bei manchen Seeds jeden Platz verwerfen.
func anchorages() -> PackedVector2Array:
	return harbour_cells if not harbour_cells.is_empty() else coast_cells
