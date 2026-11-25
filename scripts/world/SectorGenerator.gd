class_name SectorGenerator
extends Node3D

# Deterministic, seed-driven procedural retro-urban Sector generator
# Built 100% from verified Kenney Retro Urban Kit (.glb) modular 3.2m tiles.

const TILE: float = 3.2
const KIT: String = "res://assets/packs/kenney_retro_urban/"
const GRID_MIN_X: int = -15
const GRID_MAX_X: int = 14
const GRID_MIN_Z: int = -9
const GRID_MAX_Z: int = 12

const BLOCK_KEYS: Array[String] = ["NW", "NE", "SW", "SE"]
const BLOCK_TYPES: Array[String] = ["industrial", "commercial", "park_alley", "residential_yard"]
const CROSS_ROAD_CHOICES: Array[int] = [-4, 0, 4]

var current_seed: int = 0
var cross_road_x: int = 0
var block_assignments: Dictionary = {}
var train_dock_pos: Vector3 = SquadConfig.TRAIN_POSITION
var player_spawn_pos: Vector3 = Vector3(0.0, 0.0, -14.8)
var world_bounds: Rect2 = Rect2(SquadConfig.WORLD_MIN_X, SquadConfig.WORLD_MIN_Z, SquadConfig.WORLD_MAX_X - SquadConfig.WORLD_MIN_X, SquadConfig.WORLD_MAX_Z - SquadConfig.WORLD_MIN_Z)
var loot_spawn_points: Array[Dictionary] = []
var flicker_lamps: Array[OmniLight3D] = []

var _sector_root: Node3D = null
var _model_cache: Dictionary = {}
var _occupied_tiles: Dictionary = {}
var _obstacle_rects: Array[Rect2] = []
var _loot_candidates: Array[Dictionary] = []


func generate_sector(seed_value: int) -> Dictionary:
	_clear_previous_sector()

	current_seed = seed_value
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	cross_road_x = CROSS_ROAD_CHOICES[rng.randi_range(0, CROSS_ROAD_CHOICES.size() - 1)]
	train_dock_pos = SquadConfig.TRAIN_POSITION
	player_spawn_pos = Vector3(0.0, 0.0, -14.8)
	world_bounds = Rect2(SquadConfig.WORLD_MIN_X, SquadConfig.WORLD_MIN_Z, SquadConfig.WORLD_MAX_X - SquadConfig.WORLD_MIN_X, SquadConfig.WORLD_MAX_Z - SquadConfig.WORLD_MIN_Z)

	_sector_root = Node3D.new()
	_sector_root.name = "GeneratedSector"
	add_child(_sector_root)

	_assign_blocks(rng)
	_build_ground_collider()
	_build_roads_and_terrain(rng)
	_build_all_blocks(rng)
	_build_street_props_lights_and_cables(rng)
	_finalize_loot_spawn_points(rng)

	return {
		"seed": current_seed,
		"cross_road_x": cross_road_x,
		"blocks": block_assignments.duplicate(),
		"train_dock_pos": train_dock_pos,
		"player_spawn_pos": player_spawn_pos,
		"loot_spawn_points": loot_spawn_points,
		"world_bounds": world_bounds,
	}


func animate_lights(time_elapsed: float) -> void:
	for i in range(flicker_lamps.size()):
		var lamp: OmniLight3D = flicker_lamps[i]
		if is_instance_valid(lamp):
			var wave: float = sin(time_elapsed * 11.0 + float(i) * 2.9) * sin(time_elapsed * 3.1 + float(i) * 0.7)
			lamp.light_energy = 1.55 if wave > 0.78 else 2.6


func get_block_summary_text() -> String:
	var parts: Array[String] = []
	for key in BLOCK_KEYS:
		var btype: String = str(block_assignments.get(key, ""))
		parts.append("%s%s" % [key, _block_type_zh(btype)])
	return " / ".join(parts)


func _clear_previous_sector() -> void:
	flicker_lamps.clear()
	loot_spawn_points.clear()
	block_assignments.clear()
	_occupied_tiles.clear()
	_obstacle_rects.clear()
	_loot_candidates.clear()

	if _sector_root != null and is_instance_valid(_sector_root):
		if _sector_root.get_parent() == self:
			remove_child(_sector_root)
		_sector_root.free()
	_sector_root = null

	var leftover: Node = get_node_or_null("GeneratedSector")
	if leftover != null:
		remove_child(leftover)
		leftover.free()


func _assign_blocks(rng: RandomNumberGenerator) -> void:
	var pool: Array[String] = BLOCK_TYPES.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	for idx in range(BLOCK_KEYS.size()):
		block_assignments[BLOCK_KEYS[idx]] = pool[idx]


func _build_ground_collider() -> void:
	_add_invisible_collider(_sector_root, "MainGroundCollider", Vector3(170.0, 0.4, 170.0), Vector3(0.0, -0.2, 4.0))


func _get_block_rect(block_key: String) -> Rect2i:
	match block_key:
		"NW":
			return Rect2i(GRID_MIN_X, -3, (cross_road_x - 1) - GRID_MIN_X + 1, 5)
		"NE":
			return Rect2i(cross_road_x + 2, -3, GRID_MAX_X - (cross_road_x + 2) + 1, 5)
		"SW":
			return Rect2i(GRID_MIN_X, 4, (cross_road_x - 1) - GRID_MIN_X + 1, 9)
		"SE":
			return Rect2i(cross_road_x + 2, 4, GRID_MAX_X - (cross_road_x + 2) + 1, 9)
		_:
			return Rect2i(0, 0, 0, 0)


func _block_key_for_tile(gx: int, gz: int) -> String:
	if gz >= -3 and gz <= 1:
		if gx <= cross_road_x - 1:
			return "NW"
		if gx >= cross_road_x + 2:
			return "NE"
	elif gz >= 4 and gz <= 12:
		if gx <= cross_road_x - 1:
			return "SW"
		if gx >= cross_road_x + 2:
			return "SE"
	return ""


func _build_roads_and_terrain(rng: RandomNumberGenerator) -> void:
	for gx in range(GRID_MIN_X, GRID_MAX_X + 1):
		for gz in range(GRID_MIN_Z, GRID_MAX_Z + 1):
			if gz <= -8:
				_spawn_kenney("road-dirt-tile", float(gx), 0.0, float(gz))
				continue
			if gz == -7 or gz == -6:
				var rail_asset: String = "road-dirt-straight" if (gx + current_seed) % 3 != 0 else "road-dirt-tile"
				var rail_rot: float = 90.0 if rail_asset == "road-dirt-straight" else 0.0
				_spawn_kenney(rail_asset, float(gx), 0.0, float(gz), rail_rot)
				continue
			if gz == -5:
				_spawn_kenney("road-asphalt-pavement", float(gx), 0.0, float(gz))
				continue

			var on_ew_road: bool = (gz == 2 or gz == 3)
			var on_south_lane: bool = (gz == 8)
			var on_ns_road: bool = (gx == cross_road_x or gx == cross_road_x + 1) and gz >= -4

			if gz == -4:
				if on_ns_road:
					var ns_rot_plat: float = 90.0 if gx == cross_road_x else -90.0
					_spawn_kenney("road-asphalt-side", float(gx), 0.0, float(gz), ns_rot_plat)
				else:
					_spawn_kenney("road-asphalt-pavement", float(gx), 0.0, float(gz))
				continue

			if (on_ew_road or on_south_lane) and on_ns_road:
				_spawn_kenney("road-asphalt-center", float(gx), 0.0, float(gz))
				continue
			if on_ew_road:
				var ew_rot: float = 180.0 if gz == 2 else 0.0
				_spawn_kenney("road-asphalt-side", float(gx), 0.0, float(gz), ew_rot)
				continue
			if on_south_lane:
				_spawn_kenney("road-asphalt-center", float(gx), 0.0, float(gz))
				continue
			if on_ns_road:
				var ns_rot: float = 90.0 if gx == cross_road_x else -90.0
				_spawn_kenney("road-asphalt-side", float(gx), 0.0, float(gz), ns_rot)
				continue

			var bkey: String = _block_key_for_tile(gx, gz)
			var btype: String = str(block_assignments.get(bkey, "industrial"))
			var rect: Rect2i = _get_block_rect(bkey)
			var ground_asset: String = "road-asphalt-pavement"
			var ground_rot: float = 0.0

			if btype == "park_alley":
				if _is_block_road_border(gx, gz, bkey, rect):
					ground_asset = "road-asphalt-pavement"
				elif _is_park_dirt_border(gx, gz, bkey, rect):
					ground_asset = "road-dirt-side"
					ground_rot = _park_border_rot(gx, gz, bkey, rect)
				else:
					ground_asset = "grass"
			elif btype == "residential_yard":
				var is_outer_corner: bool = (gz >= 9 or gz <= -2) and (gx <= rect.position.x + 1 or gx >= rect.position.x + rect.size.x - 2)
				if is_outer_corner:
					ground_asset = "grass"
				elif rng.randf() < 0.14:
					ground_asset = "road-asphalt-damaged"
				else:
					ground_asset = "road-asphalt-pavement"
			else:
				if rng.randf() < 0.12:
					ground_asset = "road-asphalt-damaged"
				else:
					ground_asset = "road-asphalt-pavement"

			_spawn_kenney(ground_asset, float(gx), 0.0, float(gz), ground_rot)


func _is_block_road_border(gx: int, gz: int, bkey: String, rect: Rect2i) -> bool:
	var is_north: bool = bkey == "NW" or bkey == "NE"
	var is_west: bool = bkey == "NW" or bkey == "SW"
	if is_north and gz == 1:
		return true
	if (not is_north) and gz == 4:
		return true
	if is_west and gx == rect.position.x + rect.size.x - 1:
		return true
	if (not is_west) and gx == rect.position.x:
		return true
	return false


func _is_park_dirt_border(gx: int, gz: int, bkey: String, rect: Rect2i) -> bool:
	var is_north: bool = bkey == "NW" or bkey == "NE"
	var is_west: bool = bkey == "NW" or bkey == "SW"
	if is_north and gz == 0:
		return true
	if (not is_north) and gz == 5:
		return true
	if is_west and gx == rect.position.x + rect.size.x - 2:
		return true
	if (not is_west) and gx == rect.position.x + 1:
		return true
	return false


func _park_border_rot(gx: int, gz: int, bkey: String, rect: Rect2i) -> float:
	var is_north: bool = bkey == "NW" or bkey == "NE"
	var is_west: bool = bkey == "NW" or bkey == "SW"
	if is_west and gx == rect.position.x + rect.size.x - 2:
		return 90.0
	if (not is_west) and gx == rect.position.x + 1:
		return -90.0
	if is_north and gz == 0:
		return 0.0
	return 180.0


func _build_all_blocks(rng: RandomNumberGenerator) -> void:
	for bkey in BLOCK_KEYS:
		var btype: String = str(block_assignments.get(bkey, "industrial"))
		var rect: Rect2i = _get_block_rect(bkey)
		var is_south: bool = (bkey == "SW" or bkey == "SE")
		var is_west: bool = (bkey == "NW" or bkey == "SW")

		match btype:
			"industrial":
				if is_south:
					_build_industrial_south(bkey, rect, is_west, rng)
				else:
					_build_industrial_north(bkey, rect, is_west, rng)
			"commercial":
				if is_south:
					_build_commercial_south(bkey, rect, is_west, rng)
				else:
					_build_commercial_north(bkey, rect, is_west, rng)
			"park_alley":
				_build_park_alley(bkey, rect, is_south, is_west, rng)
			"residential_yard":
				if is_south:
					_build_residential_south(bkey, rect, is_west, rng)
				else:
					_build_residential_north(bkey, rect, is_west, rng)

		# Populate the expanded 4x outer wings & deep-south city blocks so the whole 90x60m map feels rich!
		_build_expanded_outer_district(bkey, btype, rect, is_south, is_west, rng)


func _build_expanded_outer_district(bkey: String, btype: String, rect: Rect2i, is_south: bool, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var outer_x: int = min_x + 2 if is_west else max_x - 2
	var mid_x: int = floori(float(min_x + max_x) * 0.5)

	if not is_south:
		# Outer wing building cluster on the far west/east edge of the enlarged North blocks
		for gx in range(outer_x - 1, outer_x + 2):
			if gx < min_x or gx > max_x or _is_tile_occupied(gx, -2):
				continue
			if btype == "park_alley":
				_spawn_kenney("tree-park-large" if gx == outer_x else "tree-pine-large", float(gx), 0.0, -1.8, rng.randf_range(0.0, 120.0), 1.15)
				if gx == outer_x:
					_spawn_kenney("detail-bench", float(gx), 0.0, 0.3, 0.0)
			else:
				var wall_pref: String = "wall-b" if btype == "industrial" else "wall-a"
				_spawn_kenney(wall_pref + ("-garage" if gx == outer_x else "-window"), float(gx), 0.0, -2.0, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
				_spawn_kenney(wall_pref + "-window", float(gx), 1.0, -2.0, 180.0)
				_spawn_kenney(wall_pref + "-roof-slant", float(gx), 2.0, -2.0, 180.0)
		_register_loot_candidate(bkey, btype, Vector3(float(outer_x) * TILE, 0.0, 0.2 * TILE), "外圍街區補給點", _bias_for_block_type(btype, rng))
	else:
		# Deep South city blocks beyond the secondary avenue (gz = 9..11)
		for row_x in [outer_x, mid_x]:
			for dx in [-1, 0, 1]:
				var gx: int = clampi(row_x + dx, min_x + 1, max_x - 1)
				if _is_tile_occupied(gx, 10):
					continue
				if btype == "park_alley":
					var t_asset: String = "tree-park-large" if dx == 0 else "tree-pine-large"
					_spawn_kenney(t_asset, float(gx), 0.0, 10.2 + rng.randf_range(-0.3, 0.4), rng.randf_range(0.0, 120.0), 1.18)
				else:
					var wp: String = "wall-b" if btype == "industrial" else "wall-a"
					var g_piece: String = wp + ("-garage" if dx == 0 else "-window")
					_spawn_kenney(g_piece, float(gx), 0.0, 10.5, 0.0, 1.0, Vector3(1.0, 1.0, 1.0))
					_spawn_kenney(wp + "-window", float(gx), 1.0, 10.5, 0.0)
					_spawn_kenney(wp + "-roof-slant-detailed" if dx == 0 else wp + "-roof-slant", float(gx), 2.0, 10.5, 0.0)
			if not _is_tile_occupied(row_x, 9):
				_spawn_kenney("pallet", float(row_x) + 0.2, 0.0, 9.2, rng.randf_range(-20.0, 20.0), 0.58)
				if btype != "park_alley" and rng.randf() < 0.65:
					_spawn_kenney("truck-green-cargo" if btype == "industrial" else "truck-grey", float(clampi(row_x + 2, min_x + 1, max_x - 1)), 0.0, 9.3, 90.0, 1.0, Vector3(1.45, 0.9, 0.85))
		_register_loot_candidate(bkey, btype, Vector3(float(outer_x) * TILE, 0.0, 9.1 * TILE), "南郊深處補給箱", _bias_for_block_type(btype, rng))
		_register_loot_candidate(bkey, btype, Vector3(float(mid_x) * TILE, 0.0, 9.0 * TILE), "外環街區物資堆", _bias_for_block_type(btype, rng))


func _build_industrial_north(bkey: String, rect: Rect2i, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var width: int = rect.size.x

	var fac_w: int = clampi(width - 2, 2, 4)
	var fac_start_x: int = min_x + 1 if is_west else max_x - fac_w
	if fac_start_x < min_x:
		fac_start_x = min_x
	var fac_end_x: int = mini(fac_start_x + fac_w - 1, max_x)

	var side_face_rot: float = -90.0 if is_west else 90.0
	var exposed_side_x: int = fac_end_x if is_west else fac_start_x

	for gx in range(fac_start_x, fac_end_x + 1):
		for gz in range(-2, 0):
			var g_piece: String = "wall-b"
			var g_rot: float = 180.0
			if gz == -1:
				if gx == fac_start_x or gx == fac_start_x + 1:
					g_piece = "wall-b-garage"
				else:
					g_piece = "wall-b-door" if rng.randf() < 0.5 else "wall-b-window"
			elif gx == exposed_side_x:
				g_piece = "wall-b-window"
				g_rot = side_face_rot
			_spawn_kenney(g_piece, float(gx), 0.0, float(gz), g_rot, 1.0, Vector3(1.0, 1.0, 1.0))

			var f2_piece: String = "wall-b-window" if (gz == -1 or gx == exposed_side_x) else "wall-b"
			var f2_rot: float = 180.0 if gz == -1 else (side_face_rot if gx == exposed_side_x else 0.0)
			_spawn_kenney(f2_piece, float(gx), 1.0, float(gz), f2_rot)

			var roof_piece: String = "wall-b-roof-slant-detailed" if ((gx + rng.randi_range(0, 1)) % 2 == 0) else "wall-b-roof-slant"
			_spawn_kenney(roof_piece, float(gx), 2.0, float(gz), 180.0)

	var penthouse_x: int = floori(float(fac_start_x + fac_end_x) * 0.5)
	_spawn_kenney("wall-b-window", float(penthouse_x), 2.0, -2.0, 180.0)
	_spawn_kenney("wall-b-roof-detailed", float(penthouse_x), 3.0, -2.0, 180.0)
	_spawn_kenney("detail-barrier-type-a", float(exposed_side_x), 2.0, -1.0, 0.0)
	_spawn_kenney("detail-awning-wide", float(fac_start_x), 0.88, -0.45, 0.0)

	var scaf_x: int = fac_end_x + 1 if is_west else fac_start_x - 1
	if scaf_x >= min_x and scaf_x <= max_x and not _is_tile_occupied(scaf_x, -2):
		for gy in range(0, 3):
			var col_sz: Vector3 = Vector3(0.85, 1.0, 0.85) if gy == 0 else Vector3.ZERO
			_spawn_kenney("scaffolding-structure", float(scaf_x), float(gy), -2.0, 0.0, 1.0, col_sz)
			_spawn_kenney("scaffolding-floor", float(scaf_x), float(gy + 1), -2.0, 0.0)

	var yard_x: int = scaf_x + 1 if is_west else scaf_x - 1
	if yard_x >= min_x and yard_x <= max_x:
		_spawn_kenney("truck-green", float(yard_x), 0.0, -1.5, 0.0, 1.0, Vector3(0.85, 1.0, 1.55))
		_spawn_kenney("wall-fence", float(yard_x), 0.0, -2.25, 0.0, 1.0, Vector3(0.95, 0.6, 0.2))
		_register_loot_candidate(bkey, "industrial", Vector3(float(yard_x) * TILE, 0.0, 0.0), "貨車裝卸區", "fuel")
	else:
		var alt_x: int = min_x if is_west else max_x
		if not _is_tile_occupied(alt_x, -1):
			_spawn_kenney("truck-green-cargo", float(alt_x), 0.0, -1.5, 0.0, 1.0, Vector3(0.85, 0.8, 1.15))

	var shelter_x: int = min_x if is_west else max_x
	if not _is_tile_occupied(shelter_x, -1):
		_spawn_kenney("roof-metal-poles", float(shelter_x), 0.0, -1.0, 0.0)
	_spawn_kenney("detail-bricks-type-a", float(fac_start_x) + 0.35, 0.0, -0.25, 22.0)
	_spawn_kenney("pallet", float(fac_end_x) - 0.15, 0.0, -0.25, rng.randf_range(-18.0, 18.0), 0.55)
	_spawn_kenney("pallet-small", float(fac_end_x) + 0.35, 0.0, -0.2, rng.randf_range(-25.0, 25.0), 0.55)

	if scaf_x >= min_x and scaf_x <= max_x and not _is_tile_occupied(scaf_x, -1):
		_spawn_kenney("detail-dumpster-open", float(scaf_x), 0.0, -1.1, 180.0, 1.0, Vector3(0.62, 0.6, 0.48))

	_register_loot_candidate(bkey, "industrial", Vector3(float(fac_start_x) * TILE, 0.0, 0.15 * TILE), "廠區捲門補給棧板", "scrap")
	_register_loot_candidate(bkey, "industrial", Vector3(float(fac_end_x) * TILE, 0.0, 0.15 * TILE), "工業機件維修箱", "parts")


func _build_industrial_south(bkey: String, rect: Rect2i, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var mid_x: int = floori(float(min_x + max_x) * 0.5)

	var fence_x: int = min_x + 1 if is_west else max_x - 1
	_spawn_kenney("wall-fence", float(fence_x), 0.0, 3.35, 0.0, 1.0, Vector3(0.95, 0.6, 0.2))
	if rect.size.x >= 6:
		var fence2_x: int = fence_x + 1 if is_west else fence_x - 1
		_spawn_kenney("wall-fence", float(fence2_x), 0.0, 3.35, 0.0, 1.0, Vector3(0.95, 0.6, 0.2))

	var shed_x: int = clampi(mid_x - 1, min_x + 1, max_x - 1)
	_spawn_kenney("roof-metal-poles", float(shed_x), 0.0, 4.5, 0.0)
	_spawn_kenney("pallet", float(shed_x) + 0.2, 0.0, 4.4, rng.randf_range(-15.0, 15.0), 0.55)
	_spawn_kenney("pallet-small", float(shed_x) - 0.3, 0.0, 4.6, rng.randf_range(-20.0, 20.0), 0.55)

	for gx in range(clampi(mid_x - 1, min_x + 1, max_x - 1), mini(mid_x + 2, max_x)):
		var low_piece: String = "wall-b-low" if (gx % 2 == 0) else "wall-b-garage"
		_spawn_kenney(low_piece, float(gx), 0.0, 6.0, 0.0, 1.0, Vector3(1.0, 0.85, 1.0))

	var truck_x: int = max_x - 1 if is_west else min_x + 1
	if truck_x == shed_x:
		truck_x = clampi(shed_x + (1 if is_west else -1), min_x, max_x)
	_spawn_kenney("truck-green-cargo", float(truck_x), 0.0, 4.8, 90.0, 1.0, Vector3(1.2, 0.8, 0.85))

	var dump_x: int = clampi(mid_x + (1 if is_west else -1), min_x + 1, max_x - 1)
	if not _is_tile_occupied(dump_x, 5):
		_spawn_kenney("detail-dumpster-open", float(dump_x), 0.0, 5.2, 0.0, 1.0, Vector3(0.62, 0.6, 0.48))
	_spawn_kenney("detail-beam", float(shed_x) + 0.6, 0.0, 3.6, 35.0)
	_spawn_kenney("detail-bricks-type-a", float(fence_x), 0.0, 4.2, 18.0)

	var edge_x: int = min_x if is_west else max_x
	_spawn_kenney("tree-pine-large", float(edge_x) + (0.3 if is_west else -0.3), 0.0, 5.7, rng.randf_range(0.0, 90.0), 1.1)

	_register_loot_candidate(bkey, "industrial", Vector3(float(shed_x) * TILE, 0.0, 3.8 * TILE), "南區棚架零件堆", "parts")
	_register_loot_candidate(bkey, "industrial", Vector3(float(mid_x) * TILE, 0.0, 5.0 * TILE), "貨櫃裝卸廢料場", "scrap")


func _build_commercial_north(bkey: String, rect: Rect2i, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var width: int = rect.size.x

	var tower_x: int = max_x - 1 if is_west else min_x + 1
	if width <= 4:
		tower_x = max_x - 1 if is_west else min_x
	var dir_in: int = -1 if is_west else 1

	_spawn_kenney("wall-a-door", float(tower_x), 0.0, -1.0, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
	_spawn_kenney("wall-a-window", float(tower_x), 1.0, -1.0, 180.0)
	_spawn_kenney("wall-a-painted", float(tower_x), 2.0, -1.0, 180.0)
	_spawn_kenney("wall-a-roof-detailed", float(tower_x), 3.0, -1.0, 0.0)
	_spawn_kenney("balcony-type-a", float(tower_x), 1.0, -0.45, 180.0)

	var ladder_off: float = 0.55 if is_west else -0.55
	var ladder_rot: float = -90.0 if is_west else 90.0
	_spawn_kenney("balcony-ladder-bottom", float(tower_x) + ladder_off, 0.0, -1.0, ladder_rot)

	var wing_len: int = clampi(width - 2, 1, 3)
	for step in range(1, wing_len + 1):
		var wx: int = tower_x + dir_in * step
		if wx < min_x or wx > max_x:
			break
		var ground_asset: String = "wall-a-garage" if step == wing_len else "wall-a-window"
		_spawn_kenney(ground_asset, float(wx), 0.0, -1.0, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
		_spawn_kenney("wall-a-window" if step == 1 else "wall-a-painted", float(wx), 1.0, -1.0, 180.0)
		var roof_asset: String = "wall-a-roof-slant" if step == wing_len else "wall-a-roof"
		_spawn_kenney(roof_asset, float(wx), 2.0, -1.0, 180.0)
		if step == 1:
			_spawn_kenney("detail-awning-wide", float(wx), 0.86, -0.45, 180.0)
		elif step == 2:
			_spawn_kenney("detail-awning-small", float(wx), 0.86, -0.45, 180.0)

	var rear_x: int = tower_x + dir_in
	if rear_x >= min_x and rear_x <= max_x and not _is_tile_occupied(rear_x, -2):
		_spawn_kenney("wall-b-garage", float(rear_x), 0.0, -2.0, 0.0, 1.0, Vector3(1.0, 1.0, 1.0))
		_spawn_kenney("wall-b-roof-detailed", float(rear_x), 1.0, -2.0, 90.0)

	var alley_x: int = tower_x + dir_in * (wing_len + 1)
	if alley_x >= min_x and alley_x <= max_x and not _is_tile_occupied(alley_x, -2):
		_spawn_kenney("truck-grey", float(alley_x), 0.0, -1.6, 0.0, 1.0, Vector3(0.85, 1.0, 1.55))
	elif not _is_tile_occupied(tower_x, -2):
		_spawn_kenney("detail-dumpster-closed", float(tower_x), 0.0, -2.0, 0.0, 1.0, Vector3(0.62, 0.6, 0.48))

	_spawn_kenney("detail-bench", float(tower_x), 0.0, 0.2, 0.0)
	var crate_x: int = clampi(tower_x + dir_in, min_x, max_x)
	_spawn_kenney("pallet-small", float(crate_x) + 0.3, 0.0, -0.15, rng.randf_range(-20.0, 20.0), 0.55)

	_register_loot_candidate(bkey, "commercial", Vector3(float(tower_x) * TILE, 0.0, 0.25 * TILE), "紅磚商街騎樓物資箱", "supplies")
	_register_loot_candidate(bkey, "commercial", Vector3(float(crate_x) * TILE, 0.0, 0.2 * TILE), "商店街後巷零件袋", "parts")


func _build_commercial_south(bkey: String, rect: Rect2i, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var mid_x: int = floori(float(min_x + max_x) * 0.5)

	var bus_x: int = clampi(min_x + 1 if is_west else max_x - 1, min_x, max_x)
	_spawn_kenney("roof-metal-poles", float(bus_x), 0.0, 3.55, 0.0)
	_spawn_kenney("detail-bench", float(bus_x), 0.0, 3.55, 0.0)

	var kiosk_x: int = clampi(mid_x, min_x + 1, max_x - 1)
	_spawn_kenney("wall-a-low-painted", float(kiosk_x), 0.0, 5.4, 0.0, 1.0, Vector3(1.0, 0.7, 1.0))
	_spawn_kenney("detail-awning-small", float(kiosk_x), 0.62, 4.85, 0.0)
	if rect.size.x >= 6:
		var k2_x: int = clampi(kiosk_x + (1 if is_west else -1), min_x + 1, max_x - 1)
		_spawn_kenney("wall-a-low", float(k2_x), 0.0, 5.4, 0.0, 1.0, Vector3(1.0, 0.7, 1.0))

	var van_x: int = clampi(max_x - 1 if is_west else min_x + 1, min_x, max_x)
	if absi(van_x - kiosk_x) >= 1 and not _is_tile_occupied(van_x, 4):
		_spawn_kenney("truck-grey", float(van_x), 0.0, 4.5, 90.0, 1.0, Vector3(1.55, 1.0, 0.85))

	var wall_x: int = clampi(mid_x + (-1 if is_west else 1), min_x, max_x)
	if wall_x != bus_x:
		_spawn_kenney("wall-broken-type-a", float(wall_x), 0.0, 3.4, 0.0, 1.0, Vector3(0.95, 0.5, 0.2))
	_spawn_kenney("pallet", float(kiosk_x) - 0.35, 0.0, 4.1, rng.randf_range(-15.0, 15.0), 0.55)
	_spawn_kenney("pallet-small", float(kiosk_x) + 0.3, 0.0, 4.15, rng.randf_range(-25.0, 25.0), 0.55)

	var dump_x: int = clampi(kiosk_x + (-1 if is_west else 1), min_x, max_x)
	if not _is_tile_occupied(dump_x, 5):
		_spawn_kenney("detail-dumpster-closed", float(dump_x), 0.0, 5.2, 0.0, 1.0, Vector3(0.62, 0.6, 0.48))

	_register_loot_candidate(bkey, "commercial", Vector3(float(bus_x) * TILE, 0.0, 4.2 * TILE), "公車亭遺落補給箱", "supplies")
	_register_loot_candidate(bkey, "commercial", Vector3(float(kiosk_x) * TILE, 0.0, 4.1 * TILE), "街角報亭物資籃", "parts")


func _build_park_alley(bkey: String, rect: Rect2i, is_south: bool, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var mid_x: int = floori(float(min_x + max_x) * 0.5)

	if is_south:
		var w1: int = clampi(min_x + 1, min_x, max_x)
		_spawn_kenney("wall-broken-type-a", float(w1), 0.0, 3.35, 0.0, 1.0, Vector3(0.95, 0.5, 0.2))
		if rect.size.x >= 6:
			_spawn_kenney("wall-broken-type-b", float(w1 + 1), 0.0, 3.35, 0.0, 1.0, Vector3(0.95, 0.5, 0.2))

		_spawn_kenney("roof-metal-poles", float(mid_x), 0.0, 4.4, 0.0)
		_spawn_kenney("detail-bench", float(mid_x), 0.0, 4.4, 0.0)
		var bench2_x: int = clampi(mid_x + (1 if is_west else -1), min_x, max_x)
		_spawn_kenney("detail-bench", float(bench2_x), 0.0, 3.25, 180.0)

		var outer_x: int = min_x if is_west else max_x
		_spawn_kenney("tree-park-large", float(outer_x) + (0.4 if is_west else -0.4), 0.0, 4.8, rng.randf_range(0.0, 120.0), 1.15)
		_spawn_kenney("tree-pine-large", float(clampi(mid_x - 1, min_x, max_x)), 0.0, 5.7, rng.randf_range(0.0, 120.0), 1.15)
		_spawn_kenney("tree-park-pine-large", float(clampi(mid_x + 1, min_x, max_x)), 0.0, 5.8, rng.randf_range(0.0, 120.0), 1.15)
		_spawn_kenney("tree-small", float(clampi(outer_x + (2 if is_west else -2), min_x, max_x)), 0.0, 5.3, rng.randf_range(0.0, 120.0), 1.0)
		_spawn_kenney("tree-shrub", float(bench2_x) + 0.4, 0.0, 4.5, rng.randf_range(0.0, 90.0))
		_spawn_kenney("detail-bricks-type-b", float(mid_x) - 0.5, 0.0, 3.8, 15.0)

		_register_loot_candidate(bkey, "park_alley", Vector3(float(mid_x) * TILE, 0.0, 4.0 * TILE), "公園涼亭緊急包", "supplies")
		_register_loot_candidate(bkey, "park_alley", Vector3(float(bench2_x) * TILE, 0.0, 4.8 * TILE), "樹籬旁遺落背包", "scrap")
	else:
		var kiosk_x: int = min_x + 1 if is_west else max_x - 1
		_spawn_kenney("wall-a-low-painted", float(kiosk_x), 0.0, -2.0, 180.0, 1.0, Vector3(1.0, 0.8, 1.0))
		_spawn_kenney("wall-a-roof-slant", float(kiosk_x), 0.72, -2.0, 180.0)

		var pav_x: int = clampi(mid_x, min_x + 1, max_x - 1)
		if pav_x == kiosk_x:
			pav_x = clampi(kiosk_x + (1 if is_west else -1), min_x, max_x)
		_spawn_kenney("roof-metal-poles", float(pav_x), 0.0, -1.0, 0.0)
		_spawn_kenney("detail-bench", float(pav_x), 0.0, -1.0, 180.0)
		_spawn_kenney("detail-bench", float(mid_x), 0.0, 0.15, 0.0)

		var f_x: int = clampi(pav_x + (1 if is_west else -1), min_x, max_x)
		if f_x != kiosk_x:
			_spawn_kenney("wall-fence", float(f_x), 0.0, -2.25, 0.0, 1.0, Vector3(0.95, 0.6, 0.2))

		var edge_x: int = min_x if is_west else max_x
		_spawn_kenney("tree-park-large", float(edge_x) + (0.3 if is_west else -0.3), 0.0, -0.6, rng.randf_range(0.0, 90.0), 1.15)
		_spawn_kenney("tree-large", float(clampi(edge_x + (1 if is_west else -1), min_x, max_x)), 0.0, -1.8, rng.randf_range(0.0, 90.0), 1.1)
		_spawn_kenney("tree-pine-large", float(f_x), 0.0, -1.7, rng.randf_range(0.0, 90.0), 1.1)
		_spawn_kenney("tree-shrub", float(pav_x) - 0.55, 0.0, -0.35, rng.randf_range(0.0, 90.0))
		_spawn_kenney("planks", float(kiosk_x), 0.0, -0.5, 28.0)

		_register_loot_candidate(bkey, "park_alley", Vector3(float(pav_x) * TILE, 0.0, 0.0), "林蔭小道補給箱", "supplies")
		_register_loot_candidate(bkey, "park_alley", Vector3(float(f_x) * TILE, 0.0, -0.5 * TILE), "紅磚小亭後巷物資", "scrap")


func _build_residential_north(bkey: String, rect: Rect2i, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var width: int = rect.size.x

	var house_w: int = clampi(width - 2, 2, 3)
	var house_start: int = min_x + 1 if is_west else max_x - house_w
	if house_start < min_x:
		house_start = min_x
	var house_end: int = mini(house_start + house_w - 1, max_x)

	for gx in range(house_start, house_end + 1):
		var g_piece: String = "wall-a-door" if gx == house_start else ("wall-a-garage" if gx == house_end else "wall-a-window")
		_spawn_kenney(g_piece, float(gx), 0.0, -1.0, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
		_spawn_kenney("wall-a-window" if gx == house_start else "wall-a", float(gx), 1.0, -1.0, 180.0)
		var r_piece: String = "wall-a-roof-slant-detailed" if gx == house_start else "wall-a-roof-slant"
		_spawn_kenney(r_piece, float(gx), 2.0, -1.0, 180.0)

	_spawn_kenney("balcony-type-a", float(house_start), 1.0, -0.45, 180.0)

	var yard_x: int = house_end + 1 if is_west else house_start - 1
	if yard_x >= min_x and yard_x <= max_x:
		_spawn_kenney("wall-fence", float(yard_x), 0.0, -2.25, 0.0, 1.0, Vector3(0.95, 0.6, 0.2))
		_spawn_kenney("truck-grey-cargo", float(yard_x), 0.0, -1.4, 0.0, 1.0, Vector3(0.85, 0.8, 1.15))
		_spawn_kenney("pallet", float(yard_x), 0.0, -0.2, rng.randf_range(-15.0, 15.0), 0.55)
	else:
		_spawn_kenney("pallet", float(house_end), 0.0, -0.2, rng.randf_range(-15.0, 15.0), 0.55)

	_spawn_kenney("roof-metal-poles", float(house_start), 0.0, -2.0, 0.0)
	_spawn_kenney("planks", float(house_start) + 0.3, 0.0, -2.1, 20.0)
	_spawn_kenney("detail-bench", float(house_end), 0.0, 0.15, 0.0)

	var outer_x: int = min_x if is_west else max_x
	if not _is_tile_occupied(outer_x, -2):
		_spawn_kenney("tree-small", float(outer_x), 0.0, -1.9, rng.randf_range(0.0, 90.0), 1.05)
	_spawn_kenney("tree-shrub", float(house_start) - 0.55, 0.0, -0.2, rng.randf_range(0.0, 90.0))

	_register_loot_candidate(bkey, "residential_yard", Vector3(float(house_start) * TILE, 0.0, 0.15 * TILE), "民居前院儲物箱", "supplies")
	_register_loot_candidate(bkey, "residential_yard", Vector3(float(house_end) * TILE, 0.0, -2.0 * TILE), "後院工具棚料架", "scrap")


func _build_residential_south(bkey: String, rect: Rect2i, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var mid_x: int = floori(float(min_x + max_x) * 0.5)

	var f1: int = clampi(mid_x - 1, min_x, max_x)
	_spawn_kenney("wall-fence", float(f1), 0.0, 3.4, 0.0, 1.0, Vector3(0.95, 0.6, 0.2))
	if f1 + 1 <= max_x:
		_spawn_kenney("wall-broken-type-b", float(f1 + 1), 0.0, 3.4, 0.0, 1.0, Vector3(0.95, 0.5, 0.2))

	var shed_x: int = clampi(mid_x, min_x + 1, max_x - 1)
	_spawn_kenney("wall-a-low", float(shed_x), 0.0, 5.6, 0.0, 1.0, Vector3(1.0, 0.7, 1.0))
	var shelter_x: int = clampi(shed_x + (1 if is_west else -1), min_x, max_x)
	_spawn_kenney("roof-metal-poles", float(shelter_x), 0.0, 4.5, 0.0)

	_spawn_kenney("pallet", float(shelter_x) - 0.2, 0.0, 4.5, rng.randf_range(-18.0, 18.0), 0.55)
	_spawn_kenney("pallet-small", float(shelter_x) + 0.35, 0.0, 4.55, rng.randf_range(-20.0, 20.0), 0.55)
	_spawn_kenney("planks", float(shed_x) - 0.3, 0.0, 4.6, 30.0)
	_spawn_kenney("detail-bricks-type-b", float(f1), 0.0, 4.3, 12.0)
	_spawn_kenney("detail-bench", float(mid_x), 0.0, 3.15, 180.0)

	var box_x: int = clampi(min_x + 1 if is_west else max_x - 1, min_x, max_x)
	if box_x != shed_x and box_x != shelter_x:
		_spawn_kenney("truck-grey-cargo", float(box_x), 0.0, 5.1, 0.0, 1.0, Vector3(0.85, 0.8, 1.15))

	var outer_x: int = min_x if is_west else max_x
	_spawn_kenney("tree-large", float(outer_x) + (0.35 if is_west else -0.35), 0.0, 5.6, rng.randf_range(0.0, 120.0), 1.1)
	_spawn_kenney("tree-small", float(clampi(outer_x + (1 if is_west else -1), min_x, max_x)), 0.0, 4.7, rng.randf_range(0.0, 120.0), 1.0)
	_spawn_kenney("tree-shrub", float(f1) - 0.35, 0.0, 3.9, rng.randf_range(0.0, 90.0))

	_register_loot_candidate(bkey, "residential_yard", Vector3(float(shelter_x) * TILE, 0.0, 4.0 * TILE), "院落棚下木箱", "scrap")
	_register_loot_candidate(bkey, "residential_yard", Vector3(float(shed_x) * TILE, 0.0, 4.4 * TILE), "民宅院落油桶組", "fuel")


func _build_street_props_lights_and_cables(rng: RandomNumberGenerator) -> void:
	var west_cp_x: int = clampi(cross_road_x - 4, -10, -3)
	var truck_on_north_lane: bool = rng.randf() < 0.5
	var truck_z: float = 2.15 if truck_on_north_lane else 3.2
	var barrier_z: float = 3.35 if truck_on_north_lane else 1.75

	_spawn_kenney("truck-flat", float(west_cp_x) - 0.4, 0.0, truck_z, 84.0, 1.0, Vector3(1.55, 1.0, 0.85))
	_spawn_kenney("detail-barrier-strong-type-a", float(west_cp_x) + 0.9, 0.0, barrier_z, 12.0, 1.0, Vector3(0.68, 0.4, 0.3))
	_spawn_kenney("detail-barrier-strong-damaged", float(west_cp_x) + 1.65, 0.0, barrier_z + 0.1, -14.0, 1.0, Vector3(0.68, 0.4, 0.3))
	_spawn_kenney("detail-barrier-type-b", float(west_cp_x) - 0.2, 0.0, 1.45, 20.0)
	_spawn_kenney("detail-beam", float(west_cp_x) - 1.3, 0.0, 3.55, 62.0)

	var open_lane_z: float = 3.0 if truck_on_north_lane else 2.0
	_register_loot_candidate("AVENUE", "avenue", Vector3(float(west_cp_x) * TILE, 0.0, open_lane_z * TILE), "大道哨卡軍備箱", "fuel")

	var east_cp_x: int = clampi(cross_road_x + 5, 2, 10)
	_spawn_kenney("detail-barrier-strong-type-b", float(east_cp_x), 0.0, 3.3, -10.0, 1.0, Vector3(0.68, 0.4, 0.3))
	_spawn_kenney("detail-block", float(east_cp_x) + 0.8, 0.0, 3.25, 8.0, 1.0, Vector3(0.55, 0.5, 0.55))
	_spawn_kenney("planks", float(east_cp_x) + 0.4, 0.0, 1.5, 32.0)
	_register_loot_candidate("AVENUE", "avenue", Vector3(float(east_cp_x) * TILE, 0.0, 2.0 * TILE), "東側路障補給箱", "parts")

	var lamp_specs: Array[Dictionary] = [
		{"asset": "detail-light-single", "gx": float(clampi(cross_road_x - 8, -13, -6)), "gz": 1.45, "rot": 180.0, "lit": true},
		{"asset": "detail-light-single", "gx": float(clampi(cross_road_x - 4, -8, -3)) - 0.3, "gz": 1.45, "rot": 180.0, "lit": true},
		{"asset": "detail-light-traffic", "gx": float(cross_road_x) - 0.45, "gz": 1.45, "rot": -90.0, "lit": true},
		{"asset": "detail-light-single", "gx": float(clampi(cross_road_x + 4, 2, 8)) + 0.3, "gz": 1.45, "rot": 180.0, "lit": true},
		{"asset": "detail-light-single", "gx": float(clampi(cross_road_x + 8, 6, 13)), "gz": 1.45, "rot": 180.0, "lit": true},
		{"asset": "detail-light-double", "gx": float(clampi(cross_road_x - 3, -8, 1)) - 0.3, "gz": 3.68, "rot": 0.0, "lit": true},
		{"asset": "detail-light-single", "gx": float(clampi(cross_road_x + 5, 3, 10)) + 0.2, "gz": 3.68, "rot": 0.0, "lit": rng.randf() < 0.75},
		{"asset": "detail-light-double", "gx": float(cross_road_x) - 0.4, "gz": 7.65, "rot": 0.0, "lit": true},
	]
	for i in range(lamp_specs.size()):
		var ls: Dictionary = lamp_specs[i]
		var asset: String = str(ls.get("asset", "detail-light-single"))
		var lx: float = float(ls.get("gx", 0.0))
		var lz: float = float(ls.get("gz", 0.0))
		var lrot: float = float(ls.get("rot", 0.0))
		var is_lit: bool = bool(ls.get("lit", true))

		_spawn_kenney(asset, lx, 0.0, lz, lrot, 1.22)
		if is_lit:
			var light: OmniLight3D = OmniLight3D.new()
			light.name = "UrbanLampGlow_%d" % i
			light.light_color = Color(1.0, 0.80, 0.50)
			light.light_energy = 2.6
			light.omni_range = 10.5
			light.position = Vector3(lx * TILE, 3.8, lz * TILE)
			_sector_root.add_child(light)
			flicker_lamps.append(light)

	var cable_x: float = float(cross_road_x) + 0.5
	_spawn_kenney("detail-cables-type-a", cable_x, 1.65, -1.0, 0.0, 1.4)
	_spawn_kenney("detail-cables-type-b", cable_x, 1.65, 0.2, 0.0, 1.4)


func _register_loot_candidate(block_key: String, block_type: String, pos: Vector3, label: String, resource_bias: String) -> void:
	_loot_candidates.append({
		"block_key": block_key,
		"block_type": block_type,
		"pos": Vector3(pos.x, 0.0, pos.z),
		"label": label,
		"resource_bias": resource_bias,
	})


func _finalize_loot_spawn_points(rng: RandomNumberGenerator) -> void:
	var target_count: int = rng.randi_range(8, 10)
	var selected: Array[Dictionary] = []
	var block_counts: Dictionary = {"NW": 0, "NE": 0, "SW": 0, "SE": 0, "AVENUE": 0}

	for cand in _loot_candidates:
		if selected.size() >= target_count:
			break
		var bkey: String = str(cand.get("block_key", "AVENUE"))
		var cur_cnt: int = int(block_counts.get(bkey, 0))
		if cur_cnt >= 2:
			continue
		var raw_pos: Vector3 = cand.get("pos", Vector3.ZERO) as Vector3
		var valid_pos: Variant = _resolve_valid_loot_pos(raw_pos, selected)
		if valid_pos != null:
			var final_pos: Vector3 = valid_pos as Vector3
			var idx: int = selected.size() + 1
			selected.append({
				"id": "loot_%02d_%s" % [idx, bkey.to_lower()],
				"label": str(cand.get("label", "廢墟物資箱")),
				"block_type": str(cand.get("block_type", "industrial")),
				"pos": final_pos,
				"resource_bias": str(cand.get("resource_bias", "scrap")),
			})
			block_counts[bkey] = cur_cnt + 1

	var scan_blocks: Array[String] = ["NW", "NE", "SW", "SE"]
	for bkey in scan_blocks:
		if selected.size() >= target_count:
			break
		var need: int = 2 - int(block_counts.get(bkey, 0))
		if need <= 0:
			continue
		var btype: String = str(block_assignments.get(bkey, "industrial"))
		var rect: Rect2i = _get_block_rect(bkey)
		var tiles: Array[Vector2i] = []
		for gx in range(rect.position.x, rect.position.x + rect.size.x):
			for gz in range(rect.position.y, rect.position.y + rect.size.y):
				tiles.append(Vector2i(gx, gz))
		for i in range(tiles.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Vector2i = tiles[i]
			tiles[i] = tiles[j]
			tiles[j] = tmp

		for t in tiles:
			if need <= 0 or selected.size() >= target_count:
				break
			var pos: Vector3 = Vector3(float(t.x) * TILE, 0.0, float(t.y) * TILE)
			if _is_valid_loot_pos(pos, selected, 4.2):
				var idx: int = selected.size() + 1
				var bias: String = _bias_for_block_type(btype, rng)
				selected.append({
					"id": "loot_%02d_%s" % [idx, bkey.to_lower()],
					"label": _fallback_loot_label(btype, bias),
					"block_type": btype,
					"pos": pos,
					"resource_bias": bias,
				})
				block_counts[bkey] = int(block_counts.get(bkey, 0)) + 1
				need -= 1

	if selected.size() < 8:
		var road_tiles: Array[Vector2i] = []
		for gx in range(GRID_MIN_X + 1, GRID_MAX_X):
			road_tiles.append(Vector2i(gx, 2))
			road_tiles.append(Vector2i(gx, 3))
		for gz in range(-2, 11):
			road_tiles.append(Vector2i(cross_road_x, gz))
			road_tiles.append(Vector2i(cross_road_x + 1, gz))
		for i in range(road_tiles.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Vector2i = road_tiles[i]
			road_tiles[i] = road_tiles[j]
			road_tiles[j] = tmp

		for t in road_tiles:
			if selected.size() >= 8:
				break
			var pos: Vector3 = Vector3(float(t.x) * TILE, 0.0, float(t.y) * TILE)
			if _is_valid_loot_pos(pos, selected, 3.6):
				var idx: int = selected.size() + 1
				var bias: String = _bias_for_block_type("avenue", rng)
				selected.append({
					"id": "loot_%02d_avenue" % idx,
					"label": _fallback_loot_label("avenue", bias),
					"block_type": "avenue",
					"pos": pos,
					"resource_bias": bias,
				})

	loot_spawn_points = selected


func _resolve_valid_loot_pos(base_pos: Vector3, existing: Array[Dictionary]) -> Variant:
	if _is_valid_loot_pos(base_pos, existing, 4.4):
		return base_pos
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 1.4),
		Vector3(0.0, 0.0, -1.4),
		Vector3(1.4, 0.0, 0.0),
		Vector3(-1.4, 0.0, 0.0),
		Vector3(1.6, 0.0, 1.4),
		Vector3(-1.6, 0.0, 1.4),
		Vector3(1.6, 0.0, -1.4),
		Vector3(-1.6, 0.0, -1.4),
		Vector3(0.0, 0.0, 2.6),
		Vector3(2.6, 0.0, 0.0),
		Vector3(-2.6, 0.0, 0.0),
	]
	for off in offsets:
		var test_pos: Vector3 = base_pos + off
		if _is_valid_loot_pos(test_pos, existing, 4.4):
			return test_pos
	return null


func _is_valid_loot_pos(pos: Vector3, existing: Array[Dictionary], min_spacing: float) -> bool:
	var p2: Vector2 = Vector2(pos.x, pos.z)
	var safe_bounds: Rect2 = world_bounds.grow(-1.0)
	if not safe_bounds.has_point(p2):
		return false

	if pos.z <= -13.2:
		return false
	if Vector2(pos.x - player_spawn_pos.x, pos.z - player_spawn_pos.z).length() < 6.0:
		return false

	var gx: int = int(round(pos.x / TILE))
	var gz: int = int(round(pos.z / TILE))
	if _is_tile_occupied(gx, gz):
		return false

	for r in _obstacle_rects:
		if r.grow(1.05).has_point(p2):
			return false

	for other in existing:
		var opos: Vector3 = other.get("pos", Vector3.ZERO) as Vector3
		if Vector2(pos.x - opos.x, pos.z - opos.z).length() < min_spacing:
			return false

	return true


func _bias_for_block_type(btype: String, rng: RandomNumberGenerator) -> String:
	var options: Array[String]
	match btype:
		"industrial":
			options = ["scrap", "parts", "fuel"]
		"commercial":
			options = ["supplies", "parts"]
		"park_alley":
			options = ["supplies", "scrap"]
		"residential_yard":
			options = ["scrap", "supplies", "fuel"]
		_:
			options = ["fuel", "parts", "supplies"]
	return options[rng.randi_range(0, options.size() - 1)]


func _fallback_loot_label(btype: String, bias: String) -> String:
	match btype:
		"industrial":
			return "工廠機件箱" if bias == "parts" else ("工業燃料桶" if bias == "fuel" else "廢鐵料架")
		"commercial":
			return "商街補給箱" if bias == "supplies" else "五金零件櫃"
		"park_alley":
			return "公園遺落物資" if bias == "supplies" else "林蔭廢料袋"
		"residential_yard":
			return "院落儲藏箱" if bias == "supplies" else ("院落備用油桶" if bias == "fuel" else "拆解建材堆")
		_:
			return "路障燃料箱" if bias == "fuel" else "街道補給包"


func _block_type_zh(btype: String) -> String:
	match btype:
		"industrial":
			return "工業"
		"commercial":
			return "商業"
		"park_alley":
			return "公園"
		"residential_yard":
			return "院落"
		_:
			return "廢區"


func _mark_occupied(gx: int, gz: int) -> void:
	_occupied_tiles[Vector2i(gx, gz)] = true


func _is_tile_occupied(gx: int, gz: int) -> bool:
	return _occupied_tiles.has(Vector2i(gx, gz))


func _spawn_kenney(
	asset_name: String,
	gx: float,
	gy: float,
	gz: float,
	rot_y_deg: float = 0.0,
	extra_scale: float = 1.0,
	collider_tiles: Vector3 = Vector3.ZERO
) -> Node3D:
	var path: String = KIT + asset_name + ".glb"
	var packed: PackedScene = _model_cache.get(path, null) as PackedScene
	if packed == null and ResourceLoader.exists(path):
		packed = load(path) as PackedScene
		if packed != null:
			_model_cache[path] = packed

	var holder: Node3D = Node3D.new()
	holder.name = "%s_%d_%d" % [asset_name, int(round(gx * 10.0)), int(round(gz * 10.0))]
	holder.position = Vector3(gx * TILE, gy * TILE, gz * TILE)
	holder.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	_sector_root.add_child(holder)

	if packed != null:
		var inst: Node = packed.instantiate()
		if inst is Node3D:
			(inst as Node3D).scale = Vector3.ONE * (TILE * extra_scale)
		holder.add_child(inst)
	else:
		push_warning("SectorGenerator: Missing Kenney GLB %s" % path)

	if collider_tiles.length_squared() > 0.001 and gz > -3.6:
		var csize: Vector3 = collider_tiles * TILE
		_add_invisible_collider(holder, holder.name + "_Col", csize, Vector3(0.0, csize.y * 0.5, 0.0))
		_record_obstacle_footprint(gx, gz, rot_y_deg, collider_tiles)

	return holder


func _record_obstacle_footprint(gx: float, gz: float, rot_y_deg: float, collider_tiles: Vector3) -> void:
	var rad: float = deg_to_rad(rot_y_deg)
	var c: float = absf(cos(rad))
	var s: float = absf(sin(rad))
	var hx_tiles: float = (collider_tiles.x * c + collider_tiles.z * s) * 0.5
	var hz_tiles: float = (collider_tiles.x * s + collider_tiles.z * c) * 0.5

	var world_cx: float = gx * TILE
	var world_cz: float = gz * TILE
	var world_hx: float = hx_tiles * TILE
	var world_hz: float = hz_tiles * TILE
	_obstacle_rects.append(Rect2(world_cx - world_hx, world_cz - world_hz, world_hx * 2.0, world_hz * 2.0))

	var min_tx: int = int(floor(gx - hx_tiles + 0.15))
	var max_tx: int = int(ceil(gx + hx_tiles - 0.15))
	var min_tz: int = int(floor(gz - hz_tiles + 0.15))
	var max_tz: int = int(ceil(gz + hz_tiles - 0.15))
	for tx in range(min_tx, max_tx + 1):
		for tz in range(min_tz, max_tz + 1):
			_mark_occupied(tx, tz)


func _add_invisible_collider(parent: Node3D, node_name: String, size: Vector3, pos: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
