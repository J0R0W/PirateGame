## Rendert die generierte Welt als Kartenbild.
##
## Einmalig erzeugt und danach gecacht - 512x512 sind eine Viertelmillion
## Auswertungen der Hoehenfunktion. Die Farbstufen folgen einer Seekarte:
## Tiefsee, Flachwasser, Strand, Land, Hochland.
class_name MapImage
extends RefCounted

# Die Karte benutzt dieselben Toene wie das Gelaende - eine Wiese muss auf der
# Seekarte dieselbe Farbe haben wie unter dem Kiel.


static func build(generator: WorldGenerator, resolution: int = 512) -> ImageTexture:
	var image := Image.create(resolution, resolution, false, Image.FORMAT_RGB8)
	var half := generator.world_size * 0.5
	var step := generator.world_size / float(resolution)
	var sea := generator.sea_level
	var deep := generator.deep_water
	var peak := generator.max_height

	for y in resolution:
		var world_z := -half + (float(y) + 0.5) * step
		for x in resolution:
			var world_x := -half + (float(x) + 0.5) * step
			var h := generator.height_at(world_x, world_z)
			image.set_pixel(x, y, _shade(h, sea, deep, peak))

	return ImageTexture.create_from_image(image)


static func _shade(height: float, sea: float, deep: float, peak: float) -> Color:
	if height <= deep:
		# Je tiefer, desto dunkler - gibt der offenen See Struktur.
		var t := clampf(height / maxf(deep, 0.001), 0.0, 1.0)
		return Palette.DEEP_SEA.lerp(Palette.SHALLOW_SEA, t * t)
	if height <= sea:
		var t := clampf((height - deep) / maxf(sea - deep, 0.001), 0.0, 1.0)
		return Palette.SHALLOW_SEA.lerp(Palette.SHOAL, t)

	# Ueber dem Meeresspiegel: Strand, Land, Hochland. Bezugsgroesse ist der
	# hoechste Punkt DIESER Welt - gegen 1.0 normiert waere alles Strand.
	var land := clampf((height - sea) / maxf(peak - sea, 0.001), 0.0, 1.0)
	if land < 0.06:
		return Palette.SAND
	if land < 0.45:
		return Palette.SAND.lerp(Palette.GRASS, (land - 0.06) / 0.39)
	if land < 0.8:
		return Palette.GRASS.lerp(Palette.SCRUB, (land - 0.45) / 0.35)
	return Palette.SCRUB.lerp(Palette.PEAK, (land - 0.8) / 0.2)
