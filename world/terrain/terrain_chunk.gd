## Baut das Gelaendemesh eines einzelnen Chunks.
##
## Die Hoehen kommen direkt aus WorldGenerator.height_at() - es gibt keine
## gespeicherte Heightmap, die Funktion ist die Quelle. Farben stecken in den
## Vertices statt in Texturen: Das passt zum Low-Poly-Stil und spart eine
## komplette Texturpipeline.
class_name TerrainChunk
extends RefCounted

const SAND := Color(0.847, 0.792, 0.616)
const GRASS := Color(0.325, 0.451, 0.286)
const SCRUB := Color(0.451, 0.478, 0.298)
const ROCK := Color(0.427, 0.400, 0.353)
const SNOW := Color(0.788, 0.780, 0.757)
## Meeresboden. Ohne eigene Farbe leuchtet heller Sand durch die Wellentaeler
## und sieht aus wie schwimmende Platten vor der Kueste.
const SEABED := Color(0.094, 0.243, 0.302)

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


## Erzeugt das Mesh fuer [param coord]. [param resolution] ist die Anzahl der
## Quads je Kante.
static func build(
	generator: WorldGenerator, coord: Vector2i, resolution: int, height_scale: float
) -> ArrayMesh:
	var origin := generator.chunk_origin(coord)
	var size := WorldGenerator.TERRAIN_CHUNK_SIZE
	var step := size / float(resolution)
	var sea := generator.sea_level

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
			var y := maxf((generator.height_at(world_x, world_z) - sea) * height_scale, SEABED_FLOOR)

			var index := iz * line + ix
			# Lokale Koordinaten - der Chunk-Node sitzt auf seinem Ursprung.
			vertices[index] = Vector3(float(ix) * step, y, float(iz) * step)
			normals[index] = _normal_at(generator, world_x, world_z, step, sea, height_scale)
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
	generator: WorldGenerator, x: float, z: float, step: float, sea: float, scale: float
) -> Vector3:
	var left := maxf((generator.height_at(x - step, z) - sea) * scale, SEABED_FLOOR)
	var right := maxf((generator.height_at(x + step, z) - sea) * scale, SEABED_FLOOR)
	var back := maxf((generator.height_at(x, z - step) - sea) * scale, SEABED_FLOOR)
	var front := maxf((generator.height_at(x, z + step) - sea) * scale, SEABED_FLOOR)
	return Vector3(left - right, step * 2.0, back - front).normalized()


## Farbe nach Hoehe. Die Uebergaenge sind weich, sonst entstehen harte Ringe
## rund um jede Insel.
##
## Wichtig: Vertex-Farben werden in Godot 4 als LINEAR interpretiert, nicht als
## sRGB. Ohne die Umrechnung wirkt das ganze Gelaende ausgewaschen - Inseln
## sahen aus wie Schneefelder.
static func _tint(y: float) -> Color:
	return _ramp(y).srgb_to_linear()


static func _ramp(y: float) -> Color:
	if y < 0.0:
		# Unter Wasser vom Strand ins Dunkle - das ergibt weiche Untiefen
		# statt harter Kanten an der Kueste.
		return SAND.lerp(SEABED, smoothstep(0.0, -22.0, y))
	if y <= BEACH_TOP:
		return SAND
	if y <= GRASS_TOP:
		return SAND.lerp(GRASS, smoothstep(BEACH_TOP, GRASS_TOP, y))
	if y <= SCRUB_TOP:
		return GRASS.lerp(SCRUB, smoothstep(GRASS_TOP, SCRUB_TOP, y))
	if y <= ROCK_TOP:
		return SCRUB.lerp(ROCK, smoothstep(SCRUB_TOP, ROCK_TOP, y))
	return ROCK.lerp(SNOW, smoothstep(ROCK_TOP, ROCK_TOP + 160.0, y))
