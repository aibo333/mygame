class_name SectorGenerator
extends Node3D

# CDDA-Inspired 5-Step Procedural Sector Generator (Milestone 1)
# Step 1 & 2: Authentic CDDA 24x24 House Layouts (25.6m x 25.6m = 8x8 Overmap tiles)
# Step 3: Overmap City Grid + Through-Running Central Railway Corridor
# Step 4: OMT Face-Road Rotation (0/90/180/270 deg facing adjacent street) + Yard/Park Fill
# Step 5: Global Ruins & Decay Filter (ter_furn_transforms, rubble, tipped furniture, decals, World-Space Noise shader)

const TILE: float = 3.2
const KIT: String = "res://assets/packs/kenney_retro_urban/"
const GRID_MIN_X: int = -21
const GRID_MAX_X: int = 20
const GRID_MIN_Z: int = -13
const GRID_MAX_Z: int = 16

const RAIL_GZ: int = -1
const NORTH_ROAD_GZ: int = -11
const SOUTH_ROAD_GZ: int = 10

const BLOCK_KEYS: Array[String] = ["NW", "NE", "SW", "SE"]
const BLOCK_TYPES: Array[String] = ["industrial", "commercial", "park_alley", "residential_yard"]
const CROSS_ROAD_CHOICES: Array[int] = [-4, 0, 4]

var current_seed: int = 0
var cross_road_x: int = 0
var rail_z: float = float(RAIL_GZ) * TILE
var north_road_z: float = float(NORTH_ROAD_GZ) * TILE
var south_road_z: float = float(SOUTH_ROAD_GZ) * TILE
var decay_rate: float = 0.35

var block_assignments: Dictionary = {}
var train_dock_pos: Vector3 = Vector3(0.0, 0.0, float(RAIL_GZ) * TILE)
var player_spawn_pos: Vector3 = Vector3(0.0, 0.0, float(RAIL_GZ) * TILE + 4.6)
var world_bounds: Rect2 = Rect2(-66.0, -40.4, 130.0, 90.4)
var loot_spawn_points: Array[Dictionary] = []
var flicker_lamps: Array[OmniLight3D] = []
var civil_houses: Array[Dictionary] = []
var house_windows: Array[Dictionary] = []

var _sector_root: Node3D = null
var _model_cache: Dictionary = {}
var _occupied_tiles: Dictionary = {}
var _obstacle_rects: Array[Rect2] = []
var _loot_candidates: Array[Dictionary] = []
var _road_tiles: Dictionary = {}


func generate_sector(seed_value: int) -> Dictionary:
	_clear_previous_sector()

	current_seed = seed_value
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	cross_road_x = CROSS_ROAD_CHOICES[rng.randi_range(0, CROSS_ROAD_CHOICES.size() - 1)]
	rail_z = float(RAIL_GZ) * TILE
	north_road_z = float(NORTH_ROAD_GZ) * TILE
	south_road_z = float(SOUTH_ROAD_GZ) * TILE
	decay_rate = rng.randf_range(0.24, 0.42)
	train_dock_pos = Vector3(0.0, 0.0, rail_z)
	player_spawn_pos = Vector3(0.0, 0.0, rail_z + 4.6)
	world_bounds = Rect2(
		float(GRID_MIN_X) * TILE + 1.2,
		float(GRID_MIN_Z) * TILE + 1.2,
		float(GRID_MAX_X - GRID_MIN_X) * TILE - 1.2,
		float(GRID_MAX_Z - GRID_MIN_Z) * TILE - 1.2
	)

	_sector_root = Node3D.new()
	_sector_root.name = "GeneratedSector"
	add_child(_sector_root)

	_assign_blocks(rng)
	_build_ground_collider()
	_build_overmap_roads_and_railway(rng)
	_build_all_blocks(rng)
	_build_street_props_lights_and_decals(rng)
	_finalize_loot_spawn_points(rng)

	return {
		"seed": current_seed,
		"cross_road_x": cross_road_x,
		"rail_z": rail_z,
		"north_road_z": north_road_z,
		"south_road_z": south_road_z,
		"decay_rate": decay_rate,
		"blocks": block_assignments.duplicate(),
		"train_dock_pos": train_dock_pos,
		"player_spawn_pos": player_spawn_pos,
		"loot_spawn_points": loot_spawn_points,
		"civil_houses": civil_houses,
		"world_bounds": world_bounds,
	}


func update_house_cutaways(player_pos: Vector3) -> int:
	var active_count: int = 0
	var p2: Vector2 = Vector2(player_pos.x, player_pos.z)
	for h: Dictionary in civil_houses:
		var roof: Node3D = h.get("roof_node", null) as Node3D
		if roof == null or not is_instance_valid(roof):
			continue
		var fp: Rect2 = h.get("footprint", Rect2()) as Rect2
		var inside: bool = fp.grow(0.35).has_point(p2)
		roof.visible = not inside
		if inside:
			active_count += 1
	return active_count


func get_house_footprints() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for h: Dictionary in civil_houses:
		out.append(h.get("footprint", Rect2()) as Rect2)
	return out


func find_nearest_house_window(world_pos: Vector3, max_dist: float = 2.8, only_unboarded: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = max_dist
	for w: Dictionary in house_windows:
		if only_unboarded and bool(w.get("boarded", false)):
			continue
		var wpos: Vector3 = w.get("pos", Vector3.ZERO) as Vector3
		var d: float = Vector2(world_pos.x - wpos.x, world_pos.z - wpos.z).length()
		if d < best_d:
			best_d = d
			best = w
	return best


func animate_lights(time_elapsed: float) -> void:
	for i in range(flicker_lamps.size()):
		var lamp: OmniLight3D = flicker_lamps[i]
		if is_instance_valid(lamp):
			var wave: float = sin(time_elapsed * 11.0 + float(i) * 2.9) * sin(time_elapsed * 3.1 + float(i) * 0.7)
			lamp.light_energy = 1.45 if wave > 0.78 else 2.4


func get_block_summary_text() -> String:
	var parts: Array[String] = []
	for key in BLOCK_KEYS:
		var btype: String = str(block_assignments.get(key, ""))
		parts.append("%s%s" % [key, _block_type_zh(btype)])
	return " / ".join(parts)


func _clear_previous_sector() -> void:
	flicker_lamps.clear()
	civil_houses.clear()
	house_windows.clear()
	loot_spawn_points.clear()
	block_assignments.clear()
	civil_houses.clear()
	_occupied_tiles.clear()
	_obstacle_rects.clear()
	_loot_candidates.clear()
	_road_tiles.clear()

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
	_add_invisible_collider(_sector_root, "MainGroundCollider", Vector3(220.0, 0.4, 220.0), Vector3(0.0, -0.2, 4.0))


func _get_block_rect(block_key: String) -> Rect2i:
	# Each quadrant includes an exact 8-tile-deep block adjacent to its main avenue + railway
	match block_key:
		"NW":
			return Rect2i(GRID_MIN_X, -10, (cross_road_x - 1) - GRID_MIN_X + 1, 8)
		"NE":
			return Rect2i(cross_road_x + 2, -10, GRID_MAX_X - (cross_road_x + 2) + 1, 8)
		"SW":
			return Rect2i(GRID_MIN_X, 2, (cross_road_x - 1) - GRID_MIN_X + 1, 8)
		"SE":
			return Rect2i(cross_road_x + 2, 2, GRID_MAX_X - (cross_road_x + 2) + 1, 8)
		_:
			return Rect2i(0, 0, 0, 0)


func _block_key_for_tile(gx: int, gz: int) -> String:
	if gz <= -3:
		if gx <= cross_road_x - 1:
			return "NW"
		if gx >= cross_road_x + 2:
			return "NE"
	elif gz >= 2:
		if gx <= cross_road_x - 1:
			return "SW"
		if gx >= cross_road_x + 2:
			return "SE"
	return ""


func _is_road_tile(gx: int, gz: int) -> bool:
	return _road_tiles.has(Vector2i(gx, gz))


# Step 3: Overmap City Roads & Through-Running Central Railway Corridor
func _build_overmap_roads_and_railway(rng: RandomNumberGenerator) -> void:
	for gx in range(GRID_MIN_X, GRID_MAX_X + 1):
		for gz in range(GRID_MIN_Z, GRID_MAX_Z + 1):
			var on_ns_road: bool = (gx == cross_road_x or gx == cross_road_x + 1)
			var on_north_ave: bool = (gz == NORTH_ROAD_GZ)
			var on_south_ave: bool = (gz == SOUTH_ROAD_GZ)
			var on_rail_apron: bool = (gz == 1)
			var on_rail_corridor: bool = (gz == -2 or gz == -1 or gz == 0)

			if on_rail_corridor:
				if on_ns_road and gz != RAIL_GZ:
					_spawn_kenney("road-asphalt-center", float(gx), 0.0, float(gz))
					_road_tiles[Vector2i(gx, gz)] = true
				else:
					var rail_asset: String = "road-dirt-straight" if (gx + current_seed) % 3 != 0 else "road-dirt-tile"
					var rail_rot: float = 90.0 if rail_asset == "road-dirt-straight" else 0.0
					_spawn_kenney(rail_asset, float(gx), 0.0, float(gz), rail_rot)
				continue

			if on_ns_road or on_north_ave or on_south_ave or on_rail_apron:
				_road_tiles[Vector2i(gx, gz)] = true
				if (on_north_ave or on_south_ave or on_rail_apron) and on_ns_road:
					_spawn_kenney("road-asphalt-center", float(gx), 0.0, float(gz))
				elif on_north_ave or on_south_ave:
					_spawn_kenney("road-asphalt-center", float(gx), 0.0, float(gz))
				elif on_rail_apron:
					_spawn_kenney("road-asphalt-pavement", float(gx), 0.0, float(gz))
				else:
					var ns_rot: float = 90.0 if gx == cross_road_x else -90.0
					_spawn_kenney("road-asphalt-side", float(gx), 0.0, float(gz), ns_rot)
				continue

			var bkey: String = _block_key_for_tile(gx, gz)
			var btype: String = str(block_assignments.get(bkey, "industrial"))
			var ground_asset: String = "road-asphalt-pavement"
			if btype == "park_alley":
				ground_asset = "grass"
			elif btype == "residential_yard":
				ground_asset = "grass"
			elif rng.randf() < 0.14:
				ground_asset = "road-asphalt-damaged"
			_spawn_kenney(ground_asset, float(gx), 0.0, float(gz), 0.0)


func _build_all_blocks(rng: RandomNumberGenerator) -> void:
	for bkey in BLOCK_KEYS:
		var btype: String = str(block_assignments.get(bkey, "industrial"))
		var rect: Rect2i = _get_block_rect(bkey)
		var is_south: bool = (bkey == "SW" or bkey == "SE")
		var is_west: bool = (bkey == "NW" or bkey == "SW")

		# Step 4: Place full-size 8x8 OMT (24x24 CDDA cells = 25.6m x 25.6m) Houses!
		_build_cdda_houses_in_block(bkey, btype, rect, is_south, is_west, rng)

		match btype:
			"industrial":
				_build_industrial_yard_props(bkey, rect, is_south, is_west, rng)
			"commercial":
				_build_commercial_props(bkey, rect, is_south, is_west, rng)
			"park_alley":
				_build_park_props(bkey, rect, is_south, is_west, rng)
			"residential_yard":
				_build_residential_yard_props(bkey, rect, is_south, is_west, rng)


func _build_cdda_houses_in_block(
	bkey: String,
	btype: String,
	rect: Rect2i,
	is_south: bool,
	is_west: bool,
	rng: RandomNumberGenerator
) -> void:
	var omt_sz: int = CddaHouseBuilder.OMT_TILES  # 8 Kenney tiles = 25.6m
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var gz0: int = 2 if is_south else -10

	# Place 1st house near the N-S cross-road (flanks railway & faces avenue/cross-road)
	var lot1_x: int = (max_x - omt_sz + 1) if is_west else min_x
	var lot2_x: int = (lot1_x - omt_sz - 1) if is_west else (lot1_x + omt_sz + 1)

	var candidate_xs: Array[int] = [lot1_x]
	if btype == "residential_yard" or btype == "commercial":
		candidate_xs.append(lot2_x)

	for idx in range(candidate_xs.size()):
		var gx0: int = candidate_xs[idx]
		if gx0 < min_x or gx0 + omt_sz - 1 > max_x:
			continue
		if _lot_has_collision(gx0, gz0, omt_sz, omt_sz):
			continue

		var bp: Dictionary = CddaHouseBuilder.pick_blueprint(rng)
		var face_info: Dictionary = _compute_face_road_rotation(gx0, gz0, omt_sz, omt_sz)
		var rot_deg: float = float(face_info["rot_deg"])
		var facing_dir: String = str(face_info["dir"])

		var center_gx: float = float(gx0) + float(omt_sz - 1) * 0.5
		var center_gz: float = float(gz0) + float(omt_sz - 1) * 0.5
		var world_origin := Vector3(center_gx * TILE, 0.0, center_gz * TILE)
		var house_id: String = "%s_%d" % [bkey, idx + 1]

		var built: Dictionary = CddaHouseBuilder.build_house(
			_sector_root,
			house_id,
			bp,
			world_origin,
			rot_deg,
			decay_rate,
			rng
		)
		built["block_key"] = bkey
		built["facing_dir"] = facing_dir
		built["rot_y_deg"] = rot_deg
		civil_houses.append(built)

		for tx in range(gx0, gx0 + omt_sz):
			for tz in range(gz0, gz0 + omt_sz):
				_mark_occupied(tx, tz)

		for obs: Rect2 in (built.get("obstacles", []) as Array):
			_obstacle_rects.append(obs)

		for sock: Dictionary in (built.get("loot_sockets", []) as Array):
			_register_loot_candidate(
				bkey,
				btype,
				sock.get("pos", Vector3.ZERO) as Vector3,
				str(sock.get("label", "民宅室內物資")),
				str(sock.get("resource_bias", "supplies")),
				true
			)
		for ws: Dictionary in (built.get("window_sockets", []) as Array):
			house_windows.append(ws)


func _lot_has_collision(gx0: int, gz0: int, w: int, h: int) -> bool:
	for tx in range(gx0, gx0 + w):
		for tz in range(gz0, gz0 + h):
			if tx < GRID_MIN_X or tx > GRID_MAX_X or tz < GRID_MIN_Z or tz > GRID_MAX_Z:
				return true
			if _is_tile_occupied(tx, tz) or _is_road_tile(tx, tz):
				return true
	return false


func _compute_face_road_rotation(gx0: int, gz0: int, w: int, h: int) -> Dictionary:
	var n_score: int = 0
	var s_score: int = 0
	var w_score: int = 0
	var e_score: int = 0
	for tx in range(gx0, gx0 + w):
		if _is_road_tile(tx, gz0 - 1):
			n_score += 1
		if _is_road_tile(tx, gz0 + h):
			s_score += 1
	for tz in range(gz0, gz0 + h):
		if _is_road_tile(gx0 - 1, tz):
			w_score += 1
		if _is_road_tile(gx0 + w, tz):
			e_score += 1

	var best_dir := "N"
	var best_score: int = n_score
	if s_score > best_score:
		best_score = s_score
		best_dir = "S"
	if w_score > best_score:
		best_score = w_score
		best_dir = "W"
	if e_score > best_score:
		best_dir = "E"

	var rot: float = 0.0
	match best_dir:
		"S":
			rot = 180.0
		"W":
			rot = 90.0
		"E":
			rot = -90.0
		_:
			rot = 0.0
	return {"dir": best_dir, "rot_deg": rot}


func _build_industrial_yard_props(bkey: String, rect: Rect2i, is_south: bool, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var yard_x: int = (min_x + 2) if is_west else (max_x - 2)
	var base_z: int = 5 if is_south else -6

	if not _is_tile_occupied(yard_x, base_z):
		_spawn_kenney("truck-green-cargo", float(yard_x), 0.0, float(base_z), 90.0, 1.0, Vector3(1.25, 0.85, 0.85))
		_spawn_kenney("pallet", float(yard_x), 0.0, float(base_z + 1), rng.randf_range(-15.0, 15.0), 0.58)
		_register_loot_candidate(bkey, "industrial", Vector3(float(yard_x) * TILE, 0.0, float(base_z + 1) * TILE), "工業貨車裝卸棧板", "fuel")

	var scaf_x: int = clampi(yard_x + (3 if is_west else -3), min_x + 1, max_x - 1)
	if not _is_tile_occupied(scaf_x, base_z):
		for gy in range(0, 2):
			var col_sz: Vector3 = Vector3(0.85, 1.0, 0.85) if gy == 0 else Vector3.ZERO
			_spawn_kenney("scaffolding-structure", float(scaf_x), float(gy), float(base_z), 0.0, 1.0, col_sz)
			_spawn_kenney("scaffolding-floor", float(scaf_x), float(gy + 1), float(base_z), 0.0)
		_register_loot_candidate(bkey, "industrial", Vector3(float(scaf_x) * TILE, 0.0, float(base_z + 1) * TILE), "鷹架工坊零件箱", "parts")

	var rail_edge_z: float = 2.05 if is_south else -2.05
	_spawn_kenney("wall-fence", float(yard_x), 0.0, rail_edge_z, 0.0, 1.0, Vector3(0.95, 0.6, 0.2))


func _build_commercial_props(bkey: String, rect: Rect2i, is_south: bool, is_west: bool, _rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var van_x: int = (min_x + 2) if is_west else (max_x - 2)
	var base_z: int = 12 if is_south else -6
	if not _is_tile_occupied(van_x, base_z):
		_spawn_kenney("truck-grey", float(van_x), 0.0, float(base_z), 90.0, 1.0, Vector3(1.35, 0.9, 0.85))
		_spawn_kenney("detail-dumpster-closed", float(van_x + 1), 0.0, float(base_z), 0.0, 1.0, Vector3(0.6, 0.6, 0.48))
		_register_loot_candidate(bkey, "commercial", Vector3(float(van_x) * TILE, 0.0, float(base_z + 1) * TILE), "商街貨車補給箱", "supplies")


func _build_park_props(bkey: String, rect: Rect2i, is_south: bool, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var mid_x: int = floori(float(min_x + max_x) * 0.5)
	var z_list: Array[int] = [3, 6, 12, 14]
	if not is_south:
		z_list = [-9, -6, -4]

	for tz in z_list:
		for tx in [min_x + 1, min_x + 4, mid_x, max_x - 4, max_x - 1]:
			if tx < min_x or tx > max_x or _is_tile_occupied(tx, tz) or _is_road_tile(tx, tz):
				continue
			if rng.randf() < 0.55:
				var t_asset: String = "tree-park-large" if (tx + tz) % 2 == 0 else "tree-pine-large"
				_spawn_kenney(t_asset, float(tx) + rng.randf_range(-0.2, 0.2), 0.0, float(tz) + rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, 120.0), 1.1)
			elif rng.randf() < 0.35:
				_spawn_kenney("detail-bench", float(tx), 0.0, float(tz), 0.0)
				_register_loot_candidate(bkey, "park_alley", Vector3(float(tx) * TILE, 0.0, float(tz) * TILE), "公園長椅緊急包", "supplies")

	var edge_x: int = min_x if is_west else max_x
	var fz: int = 3 if is_south else -3
	if not _is_tile_occupied(edge_x, fz):
		_spawn_kenney("wall-broken-type-a", float(edge_x), 0.0, float(fz), 0.0, 1.0, Vector3(0.95, 0.5, 0.2))


func _build_residential_yard_props(bkey: String, rect: Rect2i, is_south: bool, is_west: bool, rng: RandomNumberGenerator) -> void:
	var min_x: int = rect.position.x
	var max_x: int = rect.position.x + rect.size.x - 1
	var yard_z: int = 12 if is_south else -12
	for tx in [min_x + 2, min_x + 6, max_x - 5, max_x - 2]:
		if tx < min_x or tx > max_x or _is_tile_occupied(tx, yard_z) or _is_road_tile(tx, yard_z):
			continue
		if rng.randf() < 0.5:
			_spawn_kenney("tree-small", float(tx), 0.0, float(yard_z), rng.randf_range(0.0, 90.0), 1.0)
		else:
			_spawn_kenney("pallet-small", float(tx), 0.0, float(yard_z), rng.randf_range(-20.0, 20.0), 0.55)
			_register_loot_candidate(bkey, "residential_yard", Vector3(float(tx) * TILE, 0.0, float(yard_z) * TILE), "民宅街邊工具箱", "scrap")

	var rail_edge_z: float = 2.05 if is_south else -2.05
	var fx: int = clampi(min_x + 2 if is_west else max_x - 2, min_x, max_x)
	_spawn_kenney("wall-fence", float(fx), 0.0, rail_edge_z, 0.0, 1.0, Vector3(0.95, 0.6, 0.2))


func _build_street_props_lights_and_decals(rng: RandomNumberGenerator) -> void:
	var west_cp_x: int = clampi(cross_road_x - 7, -16, -4)
	_spawn_kenney("truck-flat", float(west_cp_x), 0.0, float(SOUTH_ROAD_GZ), 84.0, 1.0, Vector3(1.55, 1.0, 0.85))
	_spawn_kenney("detail-barrier-strong-type-a", float(west_cp_x) + 1.2, 0.0, float(SOUTH_ROAD_GZ) + 0.4, 12.0, 1.0, Vector3(0.68, 0.4, 0.3))
	_register_loot_candidate("AVENUE", "avenue", Vector3(float(west_cp_x) * TILE, 0.0, float(SOUTH_ROAD_GZ - 1) * TILE), "南大道哨卡軍備箱", "fuel")

	var east_cp_x: int = clampi(cross_road_x + 7, 4, 15)
	_spawn_kenney("detail-barrier-strong-type-b", float(east_cp_x), 0.0, float(NORTH_ROAD_GZ), -10.0, 1.0, Vector3(0.68, 0.4, 0.3))
	_register_loot_candidate("AVENUE", "avenue", Vector3(float(east_cp_x) * TILE, 0.0, float(NORTH_ROAD_GZ + 1) * TILE), "北大道檢查哨零件箱", "parts")

	var lamp_specs: Array[Dictionary] = [
		{"asset": "detail-light-single", "gx": float(clampi(cross_road_x - 8, -16, -6)), "gz": 1.35, "rot": 180.0},
		{"asset": "detail-light-traffic", "gx": float(cross_road_x) - 0.5, "gz": 1.35, "rot": -90.0},
		{"asset": "detail-light-single", "gx": float(clampi(cross_road_x + 8, 5, 16)), "gz": 1.35, "rot": 180.0},
		{"asset": "detail-light-double", "gx": float(clampi(cross_road_x - 6, -14, -3)), "gz": float(SOUTH_ROAD_GZ) - 0.55, "rot": 0.0},
		{"asset": "detail-light-double", "gx": float(clampi(cross_road_x + 6, 3, 14)), "gz": float(NORTH_ROAD_GZ) + 0.55, "rot": 180.0},
	]
	for i in range(lamp_specs.size()):
		var ls: Dictionary = lamp_specs[i]
		var lx: float = float(ls["gx"])
		var lz: float = float(ls["gz"])
		_spawn_kenney(str(ls["asset"]), lx, 0.0, lz, float(ls["rot"]), 1.2)
		var light := OmniLight3D.new()
		light.name = "UrbanLampGlow_%d" % i
		light.light_color = Color(0.82, 0.90, 1.0)
		light.light_energy = 2.2
		light.omni_range = 12.0
		light.position = Vector3(lx * TILE, 3.8, lz * TILE)
		_sector_root.add_child(light)
		flicker_lamps.append(light)

	var decal_kinds: Array[String] = ["cracks", "scorch", "papers", "blood"]
	for i in range(14):
		var d := Decal.new()
		d.name = "StreetDecal_%d" % i
		var dim: float = rng.randf_range(1.6, 3.4)
		d.size = Vector3(dim, 0.5, dim)
		d.texture_albedo = CddaHouseBuilder._get_decal_texture(decal_kinds[rng.randi_range(0, decal_kinds.size() - 1)])
		d.albedo_mix = 0.78
		d.position = Vector3(
			rng.randf_range(world_bounds.position.x + 4.0, world_bounds.end.x - 4.0),
			0.15,
			rng.randf_range(world_bounds.position.y + 4.0, world_bounds.end.y - 4.0)
		)
		d.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		_sector_root.add_child(d)


func _register_loot_candidate(
	block_key: String,
	block_type: String,
	pos: Vector3,
	label: String,
	resource_bias: String,
	is_indoor: bool = false
) -> void:
	_loot_candidates.append({
		"block_key": block_key,
		"block_type": block_type,
		"pos": Vector3(pos.x, 0.0, pos.z),
		"label": label,
		"resource_bias": resource_bias,
		"is_indoor": is_indoor,
	})


func _finalize_loot_spawn_points(rng: RandomNumberGenerator) -> void:
	var target_count: int = rng.randi_range(8, 10)
	var selected: Array[Dictionary] = []
	var block_counts: Dictionary = {"NW": 0, "NE": 0, "SW": 0, "SE": 0, "AVENUE": 0}

	var ordered: Array[Dictionary] = []
	for c: Dictionary in _loot_candidates:
		if bool(c.get("is_indoor", false)):
			ordered.append(c)
	for c: Dictionary in _loot_candidates:
		if not bool(c.get("is_indoor", false)):
			ordered.append(c)

	for cand in ordered:
		if selected.size() >= target_count:
			break
		var bkey: String = str(cand.get("block_key", "AVENUE"))
		var cur_cnt: int = int(block_counts.get(bkey, 0))
		if cur_cnt >= 2:
			continue
		var raw_pos: Vector3 = cand.get("pos", Vector3.ZERO) as Vector3
		var is_indoor: bool = bool(cand.get("is_indoor", false))
		var valid_pos: Variant = _resolve_valid_loot_pos(raw_pos, selected, is_indoor)
		if valid_pos != null:
			var final_pos: Vector3 = valid_pos as Vector3
			var idx: int = selected.size() + 1
			selected.append({
				"id": "loot_%02d_%s" % [idx, bkey.to_lower()],
				"label": str(cand.get("label", "廢墟物資箱")),
				"block_type": str(cand.get("block_type", "industrial")),
				"pos": final_pos,
				"resource_bias": str(cand.get("resource_bias", "scrap")),
				"is_indoor": is_indoor,
			})
			block_counts[bkey] = cur_cnt + 1

	for bkey in BLOCK_KEYS:
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
			if _is_valid_loot_pos(pos, selected, 4.2, false):
				var idx: int = selected.size() + 1
				var bias: String = _bias_for_block_type(btype, rng)
				selected.append({
					"id": "loot_%02d_%s" % [idx, bkey.to_lower()],
					"label": _fallback_loot_label(btype, bias),
					"block_type": btype,
					"pos": pos,
					"resource_bias": bias,
					"is_indoor": false,
				})
				block_counts[bkey] = int(block_counts.get(bkey, 0)) + 1
				need -= 1

	loot_spawn_points = selected


func _resolve_valid_loot_pos(base_pos: Vector3, existing: Array[Dictionary], is_indoor: bool) -> Variant:
	if _is_valid_loot_pos(base_pos, existing, 3.6 if is_indoor else 4.4, is_indoor):
		return base_pos
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.8),
		Vector3(0.0, 0.0, -0.8),
		Vector3(0.8, 0.0, 0.0),
		Vector3(-0.8, 0.0, 0.0),
		Vector3(1.4, 0.0, 1.2),
		Vector3(-1.4, 0.0, 1.2),
	]
	for off in offsets:
		var test_pos: Vector3 = base_pos + off
		if _is_valid_loot_pos(test_pos, existing, 3.6 if is_indoor else 4.4, is_indoor):
			return test_pos
	return null


func _is_valid_loot_pos(pos: Vector3, existing: Array[Dictionary], min_spacing: float, is_indoor: bool) -> bool:
	var p2: Vector2 = Vector2(pos.x, pos.z)
	var safe_bounds: Rect2 = world_bounds.grow(-1.0)
	if not safe_bounds.has_point(p2):
		return false

	if absf(pos.z - rail_z) <= 4.0:
		return false
	if Vector2(pos.x - player_spawn_pos.x, pos.z - player_spawn_pos.z).length() < 5.5:
		return false

	if not is_indoor:
		var gx: int = int(round(pos.x / TILE))
		var gz: int = int(round(pos.z / TILE))
		if _is_tile_occupied(gx, gz):
			return false
		for r in _obstacle_rects:
			if r.grow(1.0).has_point(p2):
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
			return "民防宅"
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

	if collider_tiles.length_squared() > 0.001:
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
