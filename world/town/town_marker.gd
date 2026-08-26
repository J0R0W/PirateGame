## Eine sichtbare Siedlung an der Kueste.
##
## Kein Modell aus einer Datei, sondern aus Kisten zusammengesetzt: Ein Dorf
## besteht aus einer Handvoll Haeuser, eine Hauptstadt aus doppelt so vielen,
## und die Fahne traegt die Farbe der Nation. Damit sieht man von See aus, wem
## der Hafen gehoert - ohne die Karte zu oeffnen.
##
## Die Anordnung haengt am Seed und an der Stadt-Id: Derselbe Hafen sieht in
## derselben Welt immer gleich aus, aber kein Hafen wie der naechste.
class_name TownMarker
extends Node3D

## Streuradius der Haeuser um den Stadtmittelpunkt, in Metern.
const SPREAD: float = 46.0
## Hoehe der Fahnenstange.
const POLE_HEIGHT: float = 16.0
const FLAG_SIZE: float = 3.2

## Haeuser je Stadtstufe: Dorf, Stadt, Hauptstadt.
const HOUSE_COUNT: PackedInt32Array = [6, 11, 17]

## So tief steckt jedes Haus mindestens im Boden.
const FOUNDATION_DEPTH: float = 1.2
## Faellt das Gelaende unter der Grundflaeche staerker ab, wird der Platz
## verworfen. Darueber steht das Haus sichtbar auf Stelzen.
const MAX_FOUNDATION_DROP: float = 3.5
## So viele Bauplaetze werden je Haus probiert.
const PLACEMENT_ATTEMPTS: int = 12

var town: TownData


func setup(source: TownData, nation_color: Color) -> void:
	town = source
	name = "Town%d" % source.id

	var rng := RandomNumberGenerator.new()
	# Der Weltseed geht mit ein, sonst saehe Stadt 3 in jeder Welt gleich aus.
	rng.seed = hash(Vector2i(WorldData.world_seed, source.id))

	var walls := _material(Palette.WALL)
	var roofs := _material(Palette.ROOF)
	var timber := _material(Palette.PIER)
	var flag := _material(nation_color)

	var count := HOUSE_COUNT[clampi(source.size_tier, 0, HOUSE_COUNT.size() - 1)]
	for i in count:
		_add_house(rng, walls, roofs)

	_add_flagpole(timber, flag)


## Ein Haus: Quader mit flach ueberstehendem Dach.
##
## Der Bauplatz wird gesucht, nicht gewuerfelt: Auf einem steilen Hang steht
## ein achsenparalleler Quader auf Stelzen - die talseitige Wand ragt meterweit
## in die Luft. Deshalb wird ein Platz verworfen, an dem das Gelaende unter der
## Grundflaeche zu stark abfaellt, und was uebrig bleibt, wird bis zur
## tiefsten Ecke eingegraben.
func _add_house(rng: RandomNumberGenerator, walls: Material, roofs: Material) -> void:
	var width := rng.randf_range(4.0, 7.5)
	var depth := rng.randf_range(4.0, 7.5)
	var height := rng.randf_range(3.2, 5.4)

	var spot := _find_building_spot(rng, maxf(width, depth))
	var footprint := _footprint(spot, width, depth)
	var low: float = footprint[0]
	var centre: float = footprint[2]

	var bottom := low - FOUNDATION_DEPTH
	var top := centre + height
	var body_rotation := rng.randf_range(0.0, TAU)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, top - bottom, depth)
	body.mesh = box
	body.material_override = walls
	body.position = Vector3(spot.x, (top + bottom) * 0.5, spot.y)
	body.rotation.y = body_rotation  # kein Kurs
	add_child(body)

	var roof := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(width * 1.18, 0.9, depth * 1.18)
	roof.mesh = roof_box
	roof.material_override = roofs
	roof.position = Vector3(spot.x, top + 0.45, spot.y)
	roof.rotation.y = body_rotation  # kein Kurs
	add_child(roof)


## Sucht einen Bauplatz: an Land, und flach genug fuer ein Haus.
##
## Gelingt das nicht, wird der letzte Versuch genommen - ein Haus am Hang ist
## besser als ein Loch in der Stadt.
func _find_building_spot(rng: RandomNumberGenerator, size: float) -> Vector2:
	var spot := Vector2.ZERO
	for attempt in PLACEMENT_ATTEMPTS:
		# Gleichverteilt in der Kreisflaeche, nicht im Radius - sonst draengt
		# sich alles in der Mitte. Spaetere Versuche ruecken naeher heran, wo
		# das Gelaende flacher ist.
		var angle := rng.randf_range(0.0, TAU)
		var shrink := 1.0 - float(attempt) / float(PLACEMENT_ATTEMPTS)
		var distance := sqrt(rng.randf()) * SPREAD * shrink
		spot = town.position + Vector2(cos(angle), sin(angle)) * distance

		if not WorldData.is_land(spot.x, spot.y):
			continue
		var footprint := _footprint(spot, size, size)
		if footprint[1] - footprint[0] <= MAX_FOUNDATION_DROP:
			return spot
	return spot


## Gelaendehoehen unter einer Grundflaeche: [tiefste, hoechste, Mitte].
func _footprint(spot: Vector2, width: float, depth: float) -> PackedFloat32Array:
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	var centre := WorldData.terrain_surface_y(spot.x, spot.y)
	var low := centre
	var high := centre
	for corner: Vector2 in [
		Vector2(-half_width, -half_depth), Vector2(half_width, -half_depth),
		Vector2(-half_width, half_depth), Vector2(half_width, half_depth),
	]:
		var y := WorldData.terrain_surface_y(spot.x + corner.x, spot.y + corner.y)
		low = minf(low, y)
		high = maxf(high, y)
	return PackedFloat32Array([low, high, centre])


## Die Fahnenstange steht im Stadtmittelpunkt und ist das, was man zuerst
## sieht - hoeher als jedes Haus.
func _add_flagpole(timber: Material, flag: Material) -> void:
	var ground := WorldData.terrain_surface_y(town.position.x, town.position.y)

	var pole := MeshInstance3D.new()
	var pole_box := BoxMesh.new()
	pole_box.size = Vector3(0.5, POLE_HEIGHT, 0.5)
	pole.mesh = pole_box
	pole.material_override = timber
	pole.position = Vector3(town.position.x, ground + POLE_HEIGHT * 0.5, town.position.y)
	add_child(pole)

	var banner := MeshInstance3D.new()
	var banner_box := BoxMesh.new()
	banner_box.size = Vector3(FLAG_SIZE, FLAG_SIZE * 0.62, 0.16)
	banner.mesh = banner_box
	banner.material_override = flag
	banner.position = Vector3(
		town.position.x + FLAG_SIZE * 0.5 + 0.25,
		ground + POLE_HEIGHT - FLAG_SIZE * 0.5,
		town.position.y
	)
	add_child(banner)


## Flaechenfarbe ohne Glanz - dieselbe Behandlung wie das Gelaende.
func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.metallic_specular = 0.1
	return material
