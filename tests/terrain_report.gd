## Kennzahlen eines Kuestenchunks - zum Pruefen der Gelaendegeometrie.
##
##   godot --headless --path . res://tests/terrain_report.tscn
##
## Zeigt Vertexbereich, groesste Hoehenspruenge, Kantenpassung zum Nachbarn und
## die Chunk-Belegung ringsum. Damit laesst sich beurteilen, ob ein sichtbarer
## Fehler von der Geometrie kommt oder von der Darstellung.
extends Node

func _ready() -> void:
	WorldData.generate(1)
	var g := WorldData.generator
	var scale := WorldData.TERRAIN_HEIGHT_SCALE

	# Einen Kuestenchunk suchen: hat Land UND Wasser.
	var coast := Vector2i(-1, -1)
	for cz in g.chunk_grid_size:
		for cx in g.chunk_grid_size:
			var c := Vector2i(cx, cz)
			if not g.chunk_has_land(c):
				continue
			var o := g.chunk_origin(c)
			var land := 0
			var water := 0
			for i in 8:
				for j in 8:
					var px: float = o.x + (float(j) + 0.5) * 32.0
					var pz: float = o.y + (float(i) + 0.5) * 32.0
					if g.is_land(px, pz): land += 1
					else: water += 1
			if land > 8 and water > 8:
				coast = c
				break
		if coast.x >= 0: break

	print("Kuestenchunk ", coast, " Ursprung ", g.chunk_origin(coast))

	var mesh := TerrainChunk.build(g, coast, 32, scale)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	var lo := INF
	var hi := -INF
	var nan_count := 0
	for v in verts:
		if is_nan(v.y) or is_inf(v.y): nan_count += 1
		else:
			lo = minf(lo, v.y); hi = maxf(hi, v.y)
	print("  Vertices %d, y von %.1f bis %.1f, NaN/Inf: %d" % [verts.size(), lo, hi, nan_count])
	print("  AABB ", mesh.get_aabb())

	# Steilster Uebergang zwischen benachbarten Vertices
	var line := 33
	var steepest := 0.0
	for iz in line:
		for ix in line - 1:
			var d: float = absf(verts[iz*line+ix+1].y - verts[iz*line+ix].y)
			steepest = maxf(steepest, d)
	print("  Groesster Hoehensprung zwischen Nachbarvertices: %.1f m auf 8 m" % steepest)

	# Passen die Kanten zum Nachbarchunk?
	var right := coast + Vector2i(1, 0)
	if g.chunk_has_land(right):
		var mesh_r := TerrainChunk.build(g, right, 32, scale)
		var vr: PackedVector3Array = mesh_r.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var worst := 0.0
		for iz in line:
			var a: float = verts[iz*line + (line-1)].y
			var b: float = vr[iz*line + 0].y
			worst = maxf(worst, absf(a - b))
		print("  Kantenabweichung zum Nachbarchunk: %.4f m" % worst)
	else:
		print("  Nachbarchunk rechts traegt KEIN Land -> wird nicht gebaut")

	# Und was ist mit den Chunks rundherum?
	print("\n  Belegung um den Kuestenchunk:")
	for dz in range(-2, 3):
		var row := "    "
		for dx in range(-2, 3):
			var c := coast + Vector2i(dx, dz)
			row += ("#" if g.chunk_has_land(c) else ".") + " "
		print(row)

	# Wieviel Wasserflaeche hat ein Landchunk typischerweise?
	var o2 := g.chunk_origin(coast)
	var below := 0
	var total := 0
	for i in 16:
		for j in 16:
			var px: float = o2.x + (float(j) + 0.5) * 16.0
			var pz: float = o2.y + (float(i) + 0.5) * 16.0
			total += 1
			if g.elevation_at(px, pz, scale) < -40.0: below += 1
	print("\n  Anteil unter SEABED_FLOOR (-40 m) in diesem Chunk: %.0f%%" % (100.0*below/total))
	get_tree().quit(0)
