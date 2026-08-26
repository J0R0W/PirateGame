## Baut das Gelaendemesh eines einzelnen Chunks.
##
## Die Hoehen kommen direkt aus WorldGenerator.height_at() - es gibt keine
## gespeicherte Heightmap, die Funktion ist die Quelle. Farben stecken in den
## Vertices statt in Texturen: Das passt zum Low-Poly-Stil und spart eine
## komplette Texturpipeline.
class_name TerrainChunk
extends RefCounted

# Farben kommen aus Palette - siehe data/palette.gd.

## Ab dieser Hoehe ueber dem Meeresspiegel beginnt der jeweilige Bewuchs.
## Passt zu WorldData.TERRAIN_HEIGHT_SCALE - wird die geaendert, wandern die
## Vegetationsgrenzen mit.
const BEACH_TOP: float = 10.0
const GRASS_TOP: float = 110.0
const SCRUB_TOP: float = 240.0
const ROCK_TOP: float = 360.0

## So tief reicht das Mesh unter den Meeresspiegel. Weiter unten sieht es
## ohnehin niemand, und die Vertices waeren verschenkt.
const SEABED_FLOOR: float = -40.0


## Hoehe eines Gitterpunktes, so wie ihn das Mesh setzt.
static func vertex_y(
	generator: WorldGenerator, x: float, z: float, height_scale: float
) -> float:
	return maxf(generator.elevation_at(x, z, height_scale), SEABED_FLOOR)


## Hoehe der GERENDERTEN Oberflaeche an einem beliebigen Punkt.
##
## [method WorldGenerator.elevation_at] liefert die mathematische Hoehe, das
## Mesh zeigt aber die geraden Flaechen zwischen den Gitterpunkten. Zwischen
## zwei Punkten liegen acht Meter, und an einer steilen Kueste weichen beide
## Werte um mehrere Meter voneinander ab: Haeuser schwebten ueber dem Hang,
## die Fahnenstange steckte darin.
##
## Wer etwas auf das Gelaende stellt, fragt deshalb hier - und nicht die
## Hoehenfunktion.
static func surface_y(
	generator: WorldGenerator, x: float, z: float, resolution: int, height_scale: float
) -> float:
	var step := WorldGenerator.TERRAIN_CHUNK_SIZE / float(resolution)
	# Das Gitter laeuft ueber die ganze Welt durch, nicht je Chunk von vorn.
	var half := generator.world_size * 0.5
	var cell_x := (x + half) / step
	var cell_z := (z + half) / step
	var gx := floorf(cell_x)
	var gz := floorf(cell_z)
	var fx := cell_x - gx
	var fz := cell_z - gz

	var x0 := -half + gx * step
	var z0 := -half + gz * step
	var h00 := vertex_y(generator, x0, z0, height_scale)
	var h10 := vertex_y(generator, x0 + step, z0, height_scale)
	var h01 := vertex_y(generator, x0, z0 + step, height_scale)
	var h11 := vertex_y(generator, x0 + step, z0 + step, height_scale)

	# Jedes Quad besteht aus zwei Dreiecken, die Diagonale laeuft von (1,0)
	# nach (0,1) - siehe die Indexschleife in build(). Welches der beiden
	# Dreiecke getroffen wird, entscheidet fx + fz.
	if fx + fz <= 1.0:
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)


## Erzeugt das Mesh fuer [param coord]. [param resolution] ist die Anzahl der
## Quads je Kante.
static func build(
	generator: WorldGenerator, coord: Vector2i, resolution: int, height_scale: float
) -> ArrayMesh:
	var origin := generator.chunk_origin(coord)
	var size := WorldGenerator.TERRAIN_CHUNK_SIZE
	var step := size / float(resolution)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var line := resolution + 1
	vertices.resize(line * line)
	normals.resize(line * line)
	colors.resize(line * line)

	for iz in line:
		for ix in line:
			var world_x := origin.x + float(ix) * step
			var world_z := origin.y + float(iz) * step
			var y := vertex_y(generator, world_x, world_z, height_scale)

			var index := iz * line + ix
			# Lokale Koordinaten - der Chunk-Node sitzt auf seinem Ursprung.
			vertices[index] = Vector3(float(ix) * step, y, float(iz) * step)
			normals[index] = _normal_at(generator, world_x, world_z, step, height_scale)
			colors[index] = _tint(y)

	for iz in resolution:
		for ix in resolution:
			var a := iz * line + ix
			var b := a + 1
			var c := a + line
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Normale aus finiten Differenzen der Hoehenfunktion.
static func _normal_at(
	generator: WorldGenerator, x: float, z: float, step: float, scale: float
) -> Vector3:
	var left := maxf(generator.elevation_at(x - step, z, scale), SEABED_FLOOR)
	var right := maxf(generator.elevation_at(x + step, z, scale), SEABED_FLOOR)
	var back := maxf(generator.elevation_at(x, z - step, scale), SEABED_FLOOR)
	var front := maxf(generator.elevation_at(x, z + step, scale), SEABED_FLOOR)
	return Vector3(left - right, step * 2.0, back - front).normalized()


## Farbe nach Hoehe. Die Uebergaenge sind weich, sonst entstehen harte Ringe
## rund um jede Insel.
##
## Vertex-Farben muessen linear sein - Palette.for_vertex() erledigt das.
static func _tint(y: float) -> Color:
	return Palette.for_vertex(_ramp(y))


static func _ramp(y: float) -> Color:
	if y < 0.0:
		# Unter Wasser vom Strand ins Dunkle - das ergibt weiche Untiefen
		# statt harter Kanten an der Kueste.
		return Palette.SAND.lerp(Palette.SEABED, smoothstep(0.0, -9.0, y))
	if y <= BEACH_TOP:
		return Palette.SAND
	if y <= GRASS_TOP:
		return Palette.SAND.lerp(Palette.GRASS, smoothstep(BEACH_TOP, GRASS_TOP, y))
	if y <= SCRUB_TOP:
		return Palette.GRASS.lerp(Palette.SCRUB, smoothstep(GRASS_TOP, SCRUB_TOP, y))
	if y <= ROCK_TOP:
		return Palette.SCRUB.lerp(Palette.ROCK, smoothstep(SCRUB_TOP, ROCK_TOP, y))
	return Palette.ROCK.lerp(Palette.PEAK, smoothstep(ROCK_TOP, ROCK_TOP + 160.0, y))
