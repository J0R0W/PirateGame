## Statistik ueber mehrere generierte Welten - zum Justieren der Parameter.
##
##   godot --headless --path . res://tests/world_report.tscn
extends Node


func _ready() -> void:
	print("=== Weltgenerierung: Stichprobe ueber 5 Seeds ===")
	print("%6s %8s %7s %8s %7s %8s %7s %9s" % ["Seed", "Land %", "Inseln", "bewohnb", "Kueste", "Haefen", "Staedte", "groesste"])

	var town_counts := PackedInt32Array()
	for world_seed: int in [1, 42, 1337, 90210, 555555]:
		var started := Time.get_ticks_msec()
		WorldData.generate(world_seed)
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0

		var generator := WorldData.generator
		var land_cells := 0
		var total := WorldGenerator.ANALYSIS_SIZE * WorldGenerator.ANALYSIS_SIZE
		for island: IslandData in WorldData.islands:
			land_cells += int(island.area_km2 * 1_000_000.0 / (generator._cell_size * generator._cell_size))

		var settleable := 0
		var largest := 0.0
		var coast := 0
		var harbours := 0
		for island: IslandData in WorldData.islands:
			if island.is_settleable():
				settleable += 1
				coast += island.coast_cells.size()
				harbours += island.harbour_cells.size()
			largest = maxf(largest, island.area_km2)

		town_counts.push_back(WorldData.towns.size())
		print("%6d %7.1f%% %7d %8d %7d %8d %7d %6.0f km²" % [
			world_seed,
			100.0 * float(land_cells) / float(total),
			WorldData.islands.size(),
			settleable,
			coast,
			harbours,
			WorldData.towns.size(),
			largest,
		])
		if elapsed > 2.0:
			print("        (Generierung dauerte %.2f s)" % elapsed)

	print("\n=== Eine Welt im Detail (Seed 42) ===")
	WorldData.generate(42)
	var per_nation := {}
	for town: TownData in WorldData.towns:
		per_nation[town.nation_id] = per_nation.get(town.nation_id, 0) + 1

	for nation: NationData in WorldData.nations:
		var names: Array[String] = []
		for town: TownData in WorldData.towns:
			if town.nation_id == nation.id and names.size() < 6:
				names.append("%s (%s)" % [town.town_name, town.tier_name()])
		print("  %-14s %2d Städte   %s" % [
			nation.display_name, per_nation.get(nation.id, 0), ", ".join(names)
		])

	var sample: TownData = WorldData.towns[0] if not WorldData.towns.is_empty() else null
	if sample != null:
		print("\n  Beispielstadt %s:" % sample.town_name)
		print("    Produktion: %s" % _goods(sample.production))
		print("    Bedarf:     %s" % _goods(sample.demand))
		print("\n  Preise dort (Kauf/Verkauf, * = Eigenerzeugnis):")
		for cargo: CargoType in CargoRegistry.all():
			print("    %-14s %4d / %4d   Lager %5.0f%s" % [
				cargo.display_name,
				sample.buy_price(cargo),
				sample.sell_price(cargo),
				sample.stock_of(cargo.id),
				"  *" if sample.is_producer(cargo.id) else "",
			])

	get_tree().quit(0)


## Waren-Ids in lesbare Namen mit Mengen.
func _goods(source: Dictionary) -> String:
	var parts: Array[String] = []
	for cargo_id: StringName in source:
		parts.append("%s %d" % [CargoRegistry.display_name(cargo_id), int(source[cargo_id])])
	return ", ".join(parts) if not parts.is_empty() else "-"
