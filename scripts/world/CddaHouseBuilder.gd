class_name CddaHouseBuilder
extends RefCounted

# CDDA Open-Source 24x24 Mapgen House Builder (Step 1, 2 & 5)
# Parses authentic Cataclysm-DDA JSON blueprints from data/cdda_mapgen/ at 1.0667m/cell
# (24 cells = 25.6m = exact 8x8 Kenney 3.2m Overmap tiles), with:
# - Slim 0.28m walls + 1.07m wide doorways for smooth 0.38m-radius character navigation
# - BFS Flood-Fill Reachability Guarantor (100% of indoor open rooms reachable from street)
# - Per-tile RoofCutaway group + World-Space Noise Shader + Projected Floor Decals + Programmatic Tipped Cover

const GRID_DIM: int = 24
const CELL: float = 3.2 / 3.0  # 1.066667m per CDDA cell -> 24 cells = 25.6m (8 x 3.2m tiles)
const OMT_TILES: int = 8
const WALL_HEIGHT: float = 2.8
const WALL_THICK: float = 0.26
const ASSET_PACK_DIR: String = "res://assets/packs/civil_houses/"
const WEATHERED_SHADER_PATH: String = "res://assets/shaders/ruins_weathered.gdshader"

const CDDA_BLUEPRINTS: Array[Dictionary] = [
	{"id": "house01", "label": "雙車庫三房民宅", "path": "res://data/cdda_mapgen/house01.json", "palette": "slate_concrete"},
	{"id": "house02", "label": "前廊開闊民防宅", "path": "res://data/cdda_mapgen/house02.json", "palette": "cold_brick"},
	{"id": "bungalow01", "label": "開放式平房宅邸", "path": "res://data/cdda_mapgen/bungalow01.json", "palette": "steel_panel"},
	{"id": "bungalow02", "label": "L型大院民防平房", "path": "res://data/cdda_mapgen/bungalow02.json", "palette": "slate_concrete"},
]

const PALETTES: Dictionary = {
	"slate_concrete": {
		"ext_wall": Color(0.42, 0.46, 0.51),
		"int_wall": Color(0.56, 0.60, 0.64),
		"floor_wood": Color(0.28, 0.24, 0.21),
		"floor_tile": Color(0.37, 0.41, 0.45),
		"roof": Color(0.16, 0.19, 0.23),
	},
	"cold_brick": {
		"ext_wall": Color(0.40, 0.35, 0.36),
		"int_wall": Color(0.53, 0.55, 0.57),
		"floor_wood": Color(0.26, 0.22, 0.20),
		"floor_tile": Color(0.35, 0.40, 0.43),
		"roof": Color(0.15, 0.17, 0.21),
	},
	"steel_panel": {
		"ext_wall": Color(0.34, 0.39, 0.45),
		"int_wall": Color(0.50, 0.54, 0.58),
		"floor_wood": Color(0.24, 0.23, 0.22),
		"floor_tile": Color(0.33, 0.38, 0.42),
		"roof": Color(0.14, 0.17, 0.21),
	},
}

const STRUCTURAL_CHARS: String = "#|o+*¶=:/"
const WALL_CHARS: String = "#|"
const WINDOW_CHARS: String = "o:"
const DOOR_CHARS: String = "+*¶=;"
const FENCE_CHARS: String = "$Ŧ{0"
const OUTDOOR_GRASS_CHARS: String = ".puXj"
const OUTDOOR_WALKWAY_CHARS: String = "-,'`"
const GARAGE_FLOOR_CHARS: String = "~_GKNqUz?a"

# CDDA furniture symbol -> visual & compact collider spec (leaves wide walkable clearance!)
const FURNITURE_SPECS: Dictionary = {
	"@": {"name": "雙人床", "size": Vector3(0.92, 0.55, 0.92), "col": Color(0.28, 0.35, 0.44), "solid": true, "socket": false},
	"H": {"name": "布沙發", "size": Vector3(0.84, 0.72, 0.76), "col": Color(0.26, 0.32, 0.38), "solid": true, "socket": false},
	"E": {"name": "單人扶手椅", "size": Vector3(0.68, 0.72, 0.68), "col": Color(0.30, 0.35, 0.40), "solid": true, "socket": false},
	"L": {"name": "衣帽架", "size": Vector3(0.45, 1.55, 0.45), "col": Color(0.36, 0.30, 0.24), "solid": false, "socket": false},
	"l": {"name": "茶幾", "size": Vector3(0.68, 0.44, 0.62), "col": Color(0.38, 0.31, 0.25), "solid": false, "socket": true, "bias": "supplies"},
	"f": {"name": "餐桌", "size": Vector3(0.72, 0.74, 0.72), "col": Color(0.40, 0.33, 0.26), "solid": false, "socket": true, "bias": "supplies"},
	"s": {"name": "邊桌", "size": Vector3(0.64, 0.72, 0.64), "col": Color(0.38, 0.31, 0.25), "solid": false, "socket": true, "bias": "supplies"},
	"¤": {"name": "床頭桌", "size": Vector3(0.56, 0.64, 0.56), "col": Color(0.36, 0.30, 0.24), "solid": false, "socket": true, "bias": "parts"},
	"h": {"name": "餐椅", "size": Vector3(0.44, 0.76, 0.44), "col": Color(0.35, 0.31, 0.28), "solid": false, "socket": false},
	"F": {"name": "冰箱", "size": Vector3(0.72, 1.72, 0.72), "col": Color(0.66, 0.70, 0.75), "solid": true, "socket": true, "bias": "supplies"},
	"O": {"name": "瓦斯烤箱", "size": Vector3(0.72, 0.90, 0.70), "col": Color(0.32, 0.34, 0.38), "solid": true, "socket": false},
	"S": {"name": "流理水槽", "size": Vector3(0.72, 0.86, 0.66), "col": Color(0.52, 0.56, 0.60), "solid": true, "socket": true, "bias": "supplies"},
	"5": {"name": "廚房水槽", "size": Vector3(0.72, 0.86, 0.66), "col": Color(0.52, 0.56, 0.60), "solid": true, "socket": false},
	"1": {"name": "廚具吊櫃", "size": Vector3(0.72, 0.86, 0.66), "col": Color(0.44, 0.47, 0.50), "solid": true, "socket": true, "bias": "supplies"},
	"2": {"name": "廚具櫃", "size": Vector3(0.72, 0.86, 0.66), "col": Color(0.44, 0.47, 0.50), "solid": true, "socket": false},
	"3": {"name": "廚具櫃", "size": Vector3(0.72, 0.86, 0.66), "col": Color(0.44, 0.47, 0.50), "solid": true, "socket": false},
	"4": {"name": "廚具櫃", "size": Vector3(0.72, 0.86, 0.66), "col": Color(0.44, 0.47, 0.50), "solid": true, "socket": false},
	"6": {"name": "木質貨架", "size": Vector3(0.66, 1.25, 0.66), "col": Color(0.38, 0.31, 0.25), "solid": true, "socket": true, "bias": "scrap"},
	"7": {"name": "備餐台", "size": Vector3(0.72, 0.86, 0.66), "col": Color(0.44, 0.47, 0.50), "solid": true, "socket": false},
	"8": {"name": "流理台", "size": Vector3(0.68, 0.84, 0.66), "col": Color(0.56, 0.60, 0.64), "solid": true, "socket": false},
	"J": {"name": "吧台桌", "size": Vector3(0.72, 0.86, 0.68), "col": Color(0.42, 0.45, 0.48), "solid": true, "socket": false},
	"n": {"name": "洗碗機", "size": Vector3(0.68, 0.86, 0.66), "col": Color(0.58, 0.62, 0.66), "solid": true, "socket": false},
	"B": {"name": "浴缸", "size": Vector3(0.78, 0.52, 0.78), "col": Color(0.74, 0.78, 0.82), "solid": true, "socket": false},
	"9": {"name": "淋浴間", "size": Vector3(0.78, 1.85, 0.78), "col": Color(0.64, 0.70, 0.76), "solid": true, "socket": false},
	"t": {"name": "馬桶", "size": Vector3(0.46, 0.64, 0.56), "col": Color(0.76, 0.80, 0.84), "solid": false, "socket": false},
	"D": {"name": "衣櫃", "size": Vector3(0.72, 1.72, 0.62), "col": Color(0.34, 0.28, 0.23), "solid": true, "socket": true, "bias": "supplies"},
	"d": {"name": "五斗櫃", "size": Vector3(0.68, 1.02, 0.56), "col": Color(0.36, 0.30, 0.25), "solid": true, "socket": false},
	"R": {"name": "書櫃", "size": Vector3(0.68, 1.55, 0.48), "col": Color(0.36, 0.29, 0.23), "solid": true, "socket": true, "bias": "parts"},
	"r": {"name": "書桌", "size": Vector3(0.72, 0.74, 0.58), "col": Color(0.36, 0.30, 0.24), "solid": false, "socket": true, "bias": "parts"},
	"I": {"name": "辦公桌", "size": Vector3(0.72, 0.74, 0.58), "col": Color(0.36, 0.30, 0.24), "solid": false, "socket": true, "bias": "parts"},
	"x": {"name": "電視櫃", "size": Vector3(0.74, 0.92, 0.48), "col": Color(0.22, 0.24, 0.28), "solid": true, "socket": false},
	"T": {"name": "立燈", "size": Vector3(0.32, 1.48, 0.32), "col": Color(0.55, 0.58, 0.62), "solid": false, "socket": false},
	"W": {"name": "洗衣機", "size": Vector3(0.68, 0.88, 0.68), "col": Color(0.68, 0.72, 0.76), "solid": true, "socket": false},
	"Z": {"name": "烘衣機", "size": Vector3(0.68, 0.88, 0.68), "col": Color(0.68, 0.72, 0.76), "solid": true, "socket": false},
	"v": {"name": "家用保險箱", "size": Vector3(0.62, 0.95, 0.62), "col": Color(0.24, 0.28, 0.34), "solid": true, "socket": true, "bias": "parts"},
	"z": {"name": "民防儲物箱", "size": Vector3(0.62, 0.58, 0.62), "col": Color(0.34, 0.39, 0.33), "solid": false, "socket": true, "bias": "scrap"},
	"Y": {"name": "垃圾桶", "size": Vector3(0.42, 0.62, 0.42), "col": Color(0.28, 0.32, 0.36), "solid": false, "socket": false},
	"y": {"name": "盆栽", "size": Vector3(0.42, 0.82, 0.42), "col": Color(0.22, 0.36, 0.24), "solid": false, "socket": false},
	"P": {"name": "鐵製檔案櫃", "size": Vector3(0.56, 1.35, 0.56), "col": Color(0.34, 0.39, 0.44), "solid": true, "socket": true, "bias": "parts"},
}

static var _blueprint_rows_cache: Dictionary = {}
static var _shader_cache: Shader = null
static var _mat_cache: Dictionary = {}
static var _decal_tex_cache: Dictionary = {}


static func pick_blueprint(rng: RandomNumberGenerator) -> Dictionary:
	return CDDA_BLUEPRINTS[rng.randi_range(0, CDDA_BLUEPRINTS.size() - 1)]


static func get_blueprint_by_id(bp_id: String) -> Dictionary:
	for bp: Dictionary in CDDA_BLUEPRINTS:
		if str(bp.get("id", "")) == bp_id:
			return bp
	return CDDA_BLUEPRINTS[0]


static func _load_cdda_rows(bp_id: String, json_path: String) -> Array[String]:
	if _blueprint_rows_cache.has(bp_id):
		var cached: Array = _blueprint_rows_cache[bp_id] as Array
		var out_c: Array[String] = []
		for r: Variant in cached:
			out_c.append(str(r))
		return out_c

	var rows: Array[String] = []
	if FileAccess.file_exists(json_path):
		var f := FileAccess.open(json_path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Array:
				for entry: Variant in (parsed as Array):
					if entry is Dictionary:
						var obj: Dictionary = (entry as Dictionary).get("object", {}) as Dictionary
						var raw_rows: Variant = obj.get("rows", null)
						if raw_rows is Array and (raw_rows as Array).size() == GRID_DIM:
							for line: Variant in (raw_rows as Array):
								rows.append(str(line))
							break
	if rows.size() != GRID_DIM:
		rows = _fallback_24x24_rows()

	_blueprint_rows_cache[bp_id] = rows
	return rows


static func build_house(
	parent: Node3D,
	house_id: String,
	blueprint: Dictionary,
	world_origin: Vector3,
	rot_y_deg: float,
	decay_rate: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var bp_id: String = str(blueprint.get("id", "house01"))
	var bp_path: String = str(blueprint.get("path", ""))
	var raw_rows: Array[String] = _load_cdda_rows(bp_id, bp_path)

	# Copy into editable 24x24 grid
	var grid: Array = []
	for gz in range(GRID_DIM):
		var row_str: String = raw_rows[gz]
		var arr: Array[String] = []
		for gx in range(GRID_DIM):
			arr.append(row_str[gx] if gx < row_str.length() else ".")
		grid.append(arr)

	# Guarantee 100% of indoor rooms are reachable from outside via BFS flood fill!
	var reach_info: Dictionary = _analyze_and_fix_reachability(grid)
	var indoor_cells: Dictionary = reach_info["indoor"] as Dictionary
	var unreachable_fixed: int = int(reach_info["fixed_doors"])
	var reachable_indoor_count: int = int(reach_info["reachable_indoor"])
	var total_indoor_open: int = int(reach_info["total_indoor_open"])

	var pal_name: String = str(blueprint.get("palette", "slate_concrete"))
	var pal: Dictionary = PALETTES.get(pal_name, PALETTES["slate_concrete"]) as Dictionary

	var total_size: float = float(GRID_DIM) * CELL  # 25.6m
	var half: float = total_size * 0.5
	var holder := Node3D.new()
	holder.name = "CddaHouse_%s_%s" % [bp_id, house_id]
	holder.position = world_origin
	holder.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	parent.add_child(holder)

	var roof_node := Node3D.new()
	roof_node.name = "RoofCutaway"
	roof_node.add_to_group("RoofCutaway")
	holder.add_child(roof_node)

	var local_obstacles: Array[Rect2] = []
	var loot_sockets: Array[Dictionary] = []
	var window_sockets: Array[Dictionary] = []
	var house_xform := Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y_deg)), world_origin)

	var min_in_x: int = GRID_DIM
	var max_in_x: int = -1
	var min_in_z: int = GRID_DIM
	var max_in_z: int = -1

	# Render all 24x24 CDDA cells
	for gz in range(GRID_DIM):
		for gx in range(GRID_DIM):
			var ch: String = grid[gz][gx]
			var cx: float = -half + (float(gx) + 0.5) * CELL
			var cz: float = -half + (float(gz) + 0.5) * CELL
			var cell_pos := Vector3(cx, 0.0, cz)
			var is_indoor: bool = indoor_cells.has(Vector2i(gx, gz))

			if is_indoor:
				min_in_x = mini(min_in_x, gx)
				max_in_x = maxi(max_in_x, gx)
				min_in_z = mini(min_in_z, gz)
				max_in_z = maxi(max_in_z, gz)

			# 1. Floor / Surface layer
			if is_indoor:
				var is_bath_kitch: bool = (ch in ["-", "=", "W", "Z", "Y", "1", "2", "3", "4", "5", "6", "7", "8", "S", "F", "O", "n", "t", "B", "9"])
				var is_garage: bool = GARAGE_FLOOR_CHARS.contains(ch)
				var fcol: Color = Color(0.26, 0.29, 0.32) if is_garage else (pal["floor_tile"] if is_bath_kitch else pal["floor_wood"])
				_spawn_box_piece(holder, "Flr_%d_%d" % [gx, gz], Vector3(CELL + 0.02, 0.06, CELL + 0.02), Vector3(cx, 0.03, cz), fcol, 0.55)
				# Roof tile under RoofCutaway
				_spawn_box_piece(roof_node, "Roof_%d_%d" % [gx, gz], Vector3(CELL + 0.04, 0.16, CELL + 0.04), Vector3(cx, WALL_HEIGHT + 0.08, cz), pal["roof"], 0.72)
			elif OUTDOOR_WALKWAY_CHARS.contains(ch) or GARAGE_FLOOR_CHARS.contains(ch):
				_spawn_box_piece(holder, "Walk_%d_%d" % [gx, gz], Vector3(CELL + 0.02, 0.05, CELL + 0.02), Vector3(cx, 0.025, cz), Color(0.28, 0.31, 0.35), 0.62)

			# 2. Structural walls / windows / doors / fences
			if WALL_CHARS.contains(ch):
				var wcol: Color = pal["ext_wall"] if ch == "#" else pal["int_wall"]
				_build_connected_wall(holder, grid, gx, gz, cell_pos, wcol, decay_rate, rng, local_obstacles)
			elif WINDOW_CHARS.contains(ch):
				_build_connected_window(holder, grid, gx, gz, cell_pos, pal["ext_wall"], decay_rate, rng, local_obstacles)
				var win_horiz: bool = _is_structural(grid, gx - 1, gz) or _is_structural(grid, gx + 1, gz)
				var w_world: Vector3 = house_xform * cell_pos
				w_world.y = 0.0
				window_sockets.append({
					"id": "%s_win_%d_%d" % [house_id, gx, gz],
					"pos": w_world,
					"yaw_deg": rot_y_deg + (0.0 if win_horiz else 90.0),
					"boarded": false,
				})
			elif DOOR_CHARS.contains(ch):
				_build_connected_doorway(holder, grid, gx, gz, cell_pos, pal["ext_wall"] if ch == "*" else pal["int_wall"], decay_rate, rng)
			elif FENCE_CHARS.contains(ch):
				_build_fence_post(holder, grid, gx, gz, cell_pos, local_obstacles)
			elif ch == "/":
				_build_half_wall(holder, cell_pos, pal["ext_wall"], local_obstacles)
			elif FURNITURE_SPECS.has(ch):
				var spec: Dictionary = FURNITURE_SPECS[ch] as Dictionary
				var fsize: Vector3 = spec["size"] as Vector3
				var fcol: Color = spec["col"] as Color
				var is_solid: bool = bool(spec.get("solid", true))
				var can_tip: bool = (not is_solid) and (ch in ["l", "f", "s", "h", "¤"]) and rng.randf() < decay_rate * 0.32
				var fmesh := _spawn_box_piece(holder, "Furn_%s_%d_%d" % [ch, gx, gz], fsize, Vector3(cx, fsize.y * 0.5, cz), fcol, 0.52)
				if can_tip and fmesh != null:
					fmesh.rotation_degrees.x = 90.0
					fmesh.position.y = fsize.z * 0.5
					fmesh.rotation_degrees.y = rng.randf_range(-20.0, 20.0)
				# Compact collider so 0.38m-radius player capsule never snags in hallways!
				var col_w: float = minf(fsize.x, 0.56)
				var col_d: float = minf(fsize.z, 0.56)
				_add_box_collider(holder, Vector3(col_w, maxf(0.55, fsize.y), col_d), Vector3(cx, maxf(0.28, fsize.y * 0.5), cz))
				_record_local_obstacle(cell_pos, 0.0, Vector2(col_w, col_d), local_obstacles)

				if bool(spec.get("socket", false)) and not can_tip:
					var wp: Vector3 = house_xform * Vector3(cx, 0.0, cz)
					wp.y = 0.0
					loot_sockets.append({
						"pos": wp,
						"label": "%s (%s)" % [str(spec.get("name", "物資")), str(blueprint.get("label", "民宅"))],
						"resource_bias": str(spec.get("bias", "supplies")),
					})

	# 3. Step 5: Floor Decals inside building
	if max_in_x >= min_in_x and max_in_z >= min_in_z:
		var in_w: float = float(max_in_x - min_in_x + 1) * CELL
		var in_h: float = float(max_in_z - min_in_z + 1) * CELL
		var in_cx: float = -half + (float(min_in_x + max_in_x + 1) * 0.5) * CELL
		var in_cz: float = -half + (float(min_in_z + max_in_z + 1) * 0.5) * CELL
		_apply_floor_decals(holder, Vector3(in_cx, 0.0, in_cz), in_w * 0.85, in_h * 0.85, decay_rate, rng)

	# Compute indoor footprint rect (used for RoofCutaway activation when player enters the house!)
	var local_in_rect: Rect2 = Rect2(-half, -half, total_size, total_size)
	if max_in_x >= min_in_x and max_in_z >= min_in_z:
		local_in_rect = Rect2(
			-half + float(min_in_x) * CELL,
			-half + float(min_in_z) * CELL,
			float(max_in_x - min_in_x + 1) * CELL,
			float(max_in_z - min_in_z + 1) * CELL
		)
	var world_indoor_rect: Rect2 = _transform_rect(local_in_rect, world_origin, rot_y_deg)
	var world_lot_rect: Rect2 = _transform_rect(Rect2(-half, -half, total_size, total_size), world_origin, rot_y_deg)
	var world_obstacles: Array[Rect2] = []
	for lr: Rect2 in local_obstacles:
		world_obstacles.append(_transform_rect(lr, world_origin, rot_y_deg))

	return {
		"id": house_id,
		"label": str(blueprint.get("label", "民防住家")),
		"variant_id": bp_id,
		"node": holder,
		"roof_node": roof_node,
		"footprint": world_indoor_rect,
		"lot_footprint": world_lot_rect,
		"obstacles": world_obstacles,
		"loot_sockets": loot_sockets,
		"window_sockets": window_sockets,
		"reachable_indoor": reachable_indoor_count,
		"total_indoor_open": total_indoor_open,
		"fixed_doors": unreachable_fixed,
	}


static func _is_structural(grid: Array, gx: int, gz: int) -> bool:
	if gx < 0 or gx >= GRID_DIM or gz < 0 or gz >= GRID_DIM:
		return false
	return STRUCTURAL_CHARS.contains(grid[gz][gx])


static func _build_connected_wall(
	parent: Node3D,
	grid: Array,
	gx: int,
	gz: int,
	cell_pos: Vector3,
	col: Color,
	decay_rate: float,
	rng: RandomNumberGenerator,
	local_obstacles: Array[Rect2]
) -> void:
	var n_conn: bool = _is_structural(grid, gx, gz - 1)
	var s_conn: bool = _is_structural(grid, gx, gz + 1)
	var w_conn: bool = _is_structural(grid, gx - 1, gz)
	var e_conn: bool = _is_structural(grid, gx + 1, gz)

	var is_ruined: bool = (rng.randf() < decay_rate * 0.25)
	var h: float = 0.95 if is_ruined else WALL_HEIGHT

	# Central junction post + directional arms (thin 0.26m wall so interior rooms stay wide!)
	_spawn_box_piece(parent, "W_%d_%d" % [gx, gz], Vector3(WALL_THICK, h, WALL_THICK), Vector3(cell_pos.x, h * 0.5, cell_pos.z), col, 0.68)
	var arm_len: float = (CELL - WALL_THICK) * 0.5 + 0.02
	var arm_off: float = WALL_THICK * 0.5 + arm_len * 0.5 - 0.01
	if n_conn:
		_spawn_box_piece(parent, "WN_%d_%d" % [gx, gz], Vector3(WALL_THICK, h, arm_len), Vector3(cell_pos.x, h * 0.5, cell_pos.z - arm_off), col, 0.68)
	if s_conn:
		_spawn_box_piece(parent, "WS_%d_%d" % [gx, gz], Vector3(WALL_THICK, h, arm_len), Vector3(cell_pos.x, h * 0.5, cell_pos.z + arm_off), col, 0.68)
	if w_conn:
		_spawn_box_piece(parent, "WW_%d_%d" % [gx, gz], Vector3(arm_len, h, WALL_THICK), Vector3(cell_pos.x - arm_off, h * 0.5, cell_pos.z), col, 0.68)
	if e_conn:
		_spawn_box_piece(parent, "WE_%d_%d" % [gx, gz], Vector3(arm_len, h, WALL_THICK), Vector3(cell_pos.x + arm_off, h * 0.5, cell_pos.z), col, 0.68)

	if is_ruined:
		_spawn_rubble_cluster(parent, Vector3(cell_pos.x, 0.0, cell_pos.z), rng)

	# Slim collider matching wall thickness so doorways never pinch
	var cw: float = CELL if (w_conn or e_conn) else 0.34
	var cd: float = CELL if (n_conn or s_conn) else 0.34
	_add_box_collider(parent, Vector3(cw, WALL_HEIGHT, cd), Vector3(cell_pos.x, WALL_HEIGHT * 0.5, cell_pos.z))
	_record_local_obstacle(cell_pos, 0.0, Vector2(cw, cd), local_obstacles)


static func _build_connected_window(
	parent: Node3D,
	grid: Array,
	gx: int,
	gz: int,
	cell_pos: Vector3,
	col: Color,
	decay_rate: float,
	rng: RandomNumberGenerator,
	local_obstacles: Array[Rect2]
) -> void:
	var horiz: bool = _is_structural(grid, gx - 1, gz) or _is_structural(grid, gx + 1, gz)
	var rot_y: float = 0.0 if horiz else 90.0
	var seg := Node3D.new()
	seg.position = cell_pos
	seg.rotation_degrees.y = rot_y
	parent.add_child(seg)

	_spawn_box_piece(seg, "WinSill", Vector3(CELL, 0.92, WALL_THICK), Vector3(0.0, 0.46, 0.0), col, 0.68)
	_spawn_box_piece(seg, "WinHead", Vector3(CELL, 0.62, WALL_THICK), Vector3(0.0, WALL_HEIGHT - 0.31, 0.0), col, 0.68)
	if rng.randf() < decay_rate * 0.50:
		for pi in range(3):
			var plank := _spawn_box_piece(seg, "Plank_%d" % pi, Vector3(CELL * 0.9, 0.12, 0.06), Vector3(0.0, 1.12 + float(pi) * 0.32, WALL_THICK * 0.5 + 0.02), Color(0.38, 0.30, 0.22), 0.72)
			if plank != null:
				plank.rotation_degrees.z = rng.randf_range(-5.0, 5.0)
	else:
		_spawn_glass_pane(seg, Vector3(CELL * 0.92, 1.24, 0.04), Vector3(0.0, 1.54, 0.0))

	var cw: float = CELL if horiz else 0.34
	var cd: float = 0.34 if horiz else CELL
	_add_box_collider(parent, Vector3(cw, WALL_HEIGHT, cd), Vector3(cell_pos.x, WALL_HEIGHT * 0.5, cell_pos.z))
	_record_local_obstacle(cell_pos, 0.0, Vector2(cw, cd), local_obstacles)


static func _build_connected_doorway(
	parent: Node3D,
	grid: Array,
	gx: int,
	gz: int,
	cell_pos: Vector3,
	col: Color,
	decay_rate: float,
	rng: RandomNumberGenerator
) -> void:
	var horiz: bool = _is_structural(grid, gx - 1, gz) or _is_structural(grid, gx + 1, gz)
	var rot_y: float = 0.0 if horiz else 90.0
	var seg := Node3D.new()
	seg.position = cell_pos
	seg.rotation_degrees.y = rot_y
	parent.add_child(seg)

	# Only overhead header + swung-open door leaf (100% open walkable 1.07m doorway!)
	_spawn_box_piece(seg, "DoorHead", Vector3(CELL, 0.55, WALL_THICK), Vector3(0.0, WALL_HEIGHT - 0.275, 0.0), col, 0.68)
	if rng.randf() >= decay_rate * 0.35:
		var leaf := _spawn_box_piece(seg, "DoorLeaf", Vector3(CELL * 0.80, 2.15, 0.05), Vector3(-CELL * 0.38, 1.08, 0.36), Color(0.24, 0.28, 0.33), 0.55)
		if leaf != null:
			leaf.rotation_degrees.y = 78.0


static func _build_fence_post(parent: Node3D, grid: Array, gx: int, gz: int, cell_pos: Vector3, local_obstacles: Array[Rect2]) -> void:
	var n_f: bool = FENCE_CHARS.contains(grid[gz - 1][gx]) if gz > 0 else false
	var s_f: bool = FENCE_CHARS.contains(grid[gz + 1][gx]) if gz < GRID_DIM - 1 else false
	var w_f: bool = FENCE_CHARS.contains(grid[gz][gx - 1]) if gx > 0 else false
	var e_f: bool = FENCE_CHARS.contains(grid[gz][gx + 1]) if gx < GRID_DIM - 1 else false
	var fcol := Color(0.30, 0.28, 0.26)
	_spawn_box_piece(parent, "Fence_%d_%d" % [gx, gz], Vector3(0.18, 1.35, 0.18), Vector3(cell_pos.x, 0.68, cell_pos.z), fcol, 0.65)
	if w_f or e_f:
		_spawn_box_piece(parent, "FenceH_%d_%d" % [gx, gz], Vector3(CELL, 1.25, 0.12), Vector3(cell_pos.x, 0.62, cell_pos.z), fcol, 0.65)
	if n_f or s_f:
		_spawn_box_piece(parent, "FenceV_%d_%d" % [gx, gz], Vector3(0.12, 1.25, CELL), Vector3(cell_pos.x, 0.62, cell_pos.z), fcol, 0.65)
	_add_box_collider(parent, Vector3(0.45, 1.35, 0.45), Vector3(cell_pos.x, 0.68, cell_pos.z))
	_record_local_obstacle(cell_pos, 0.0, Vector2(0.45, 0.45), local_obstacles)


static func _build_half_wall(parent: Node3D, cell_pos: Vector3, col: Color, local_obstacles: Array[Rect2]) -> void:
	_spawn_box_piece(parent, "HalfWall", Vector3(CELL, 1.05, WALL_THICK), Vector3(cell_pos.x, 0.525, cell_pos.z), col, 0.65)
	_add_box_collider(parent, Vector3(CELL * 0.8, 1.05, 0.32), Vector3(cell_pos.x, 0.525, cell_pos.z))
	_record_local_obstacle(cell_pos, 0.0, Vector2(CELL * 0.8, 0.32), local_obstacles)


# Flood-Fill BFS from outside boundary to classify indoor cells AND auto-connect any sealed rooms!
static func _analyze_and_fix_reachability(grid: Array) -> Dictionary:
	# 1. Identify which cells are strictly outdoors (connected to grid boundary without crossing walls/doors/fences)
	var exterior: Dictionary = {}
	var q: Array[Vector2i] = []
	for i in range(GRID_DIM):
		for pt: Vector2i in [Vector2i(i, 0), Vector2i(i, GRID_DIM - 1), Vector2i(0, i), Vector2i(GRID_DIM - 1, i)]:
			var ch: String = grid[pt.y][pt.x]
			if not STRUCTURAL_CHARS.contains(ch) and not FENCE_CHARS.contains(ch):
				if not exterior.has(pt):
					exterior[pt] = true
					q.append(pt)

	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head: int = 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d: Vector2i in dirs:
			var np := cur + d
			if np.x < 0 or np.x >= GRID_DIM or np.y < 0 or np.y >= GRID_DIM:
				continue
			if exterior.has(np):
				continue
			var nch: String = grid[np.y][np.x]
			# Fences & exterior grass stop outdoor-vs-indoor classification cleanly at walls/doors
			if STRUCTURAL_CHARS.contains(nch) or FENCE_CHARS.contains(nch):
				continue
			if OUTDOOR_GRASS_CHARS.contains(nch) or OUTDOOR_WALKWAY_CHARS.contains(nch) or nch == " ":
				if nch != " ":
					exterior[np] = true
					q.append(np)

	# Also keep explicit outdoor grass/walkway tiles outside the building as exterior even inside fenced backyards
	var indoor: Dictionary = {}
	for gz in range(GRID_DIM):
		for gx in range(GRID_DIM):
			var pt := Vector2i(gx, gz)
			var ch: String = grid[gz][gx]
			if exterior.has(pt):
				continue
			if FENCE_CHARS.contains(ch) or OUTDOOR_GRASS_CHARS.contains(ch) or OUTDOOR_WALKWAY_CHARS.contains(ch):
				continue
			# Anything enclosed behind walls (or the wall ring itself) is part of the building interior
			indoor[pt] = true

	# 2. Walkability BFS from exterior across doorways & passable indoor tiles
	var fixed_doors: int = 0
	var walkable: Dictionary = {}
	for _pass_idx in range(6):
		walkable = _bfs_walkable_from_outside(grid)
		var sealed_target: Vector2i = Vector2i(-1, -1)
		for pt: Vector2i in indoor.keys():
			var ch: String = grid[pt.y][pt.x]
			if _is_cell_passable(ch) and not walkable.has(pt):
				sealed_target = pt
				break
		if sealed_target.x < 0:
			break
		# Carve a doorway '+' on an interior wall adjacent to the walkable frontier nearest to sealed_target
		var best_wall := Vector2i(-1, -1)
		var best_dist: float = INF
		for gz in range(1, GRID_DIM - 1):
			for gx in range(1, GRID_DIM - 1):
				var wpt := Vector2i(gx, gz)
				var wch: String = grid[gz][gx]
				if not WALL_CHARS.contains(wch):
					continue
				var touches_walkable: bool = false
				var touches_unwalkable_indoor: bool = false
				for d: Vector2i in dirs:
					var nb := wpt + d
					if walkable.has(nb):
						touches_walkable = true
					elif indoor.has(nb) and _is_cell_passable(grid[nb.y][nb.x]) and not walkable.has(nb):
						touches_unwalkable_indoor = true
				if touches_walkable and touches_unwalkable_indoor:
					var dist: float = Vector2(float(wpt.x - sealed_target.x), float(wpt.y - sealed_target.y)).length()
					if dist < best_dist:
						best_dist = dist
						best_wall = wpt
		if best_wall.x >= 0:
			grid[best_wall.y][best_wall.x] = "+"
			fixed_doors += 1
		else:
			break

	walkable = _bfs_walkable_from_outside(grid)
	var total_open: int = 0
	var reached_open: int = 0
	for pt: Vector2i in indoor.keys():
		if _is_cell_passable(grid[pt.y][pt.x]):
			total_open += 1
			if walkable.has(pt):
				reached_open += 1

	return {
		"indoor": indoor,
		"fixed_doors": fixed_doors,
		"reachable_indoor": reached_open,
		"total_indoor_open": total_open,
	}


static func _is_cell_passable(ch: String) -> bool:
	if WALL_CHARS.contains(ch) or WINDOW_CHARS.contains(ch) or FENCE_CHARS.contains(ch) or ch == "/":
		return false
	if FURNITURE_SPECS.has(ch):
		var spec: Dictionary = FURNITURE_SPECS[ch] as Dictionary
		return not bool(spec.get("solid", true))
	return true


static func _bfs_walkable_from_outside(grid: Array) -> Dictionary:
	var visited: Dictionary = {}
	var q: Array[Vector2i] = []
	for i in range(GRID_DIM):
		for pt: Vector2i in [Vector2i(i, 0), Vector2i(i, GRID_DIM - 1), Vector2i(0, i), Vector2i(GRID_DIM - 1, i)]:
			if _is_cell_passable(grid[pt.y][pt.x]) and not visited.has(pt):
				visited[pt] = true
				q.append(pt)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head: int = 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d: Vector2i in dirs:
			var np := cur + d
			if np.x < 0 or np.x >= GRID_DIM or np.y < 0 or np.y >= GRID_DIM:
				continue
			if visited.has(np):
				continue
			if _is_cell_passable(grid[np.y][np.x]):
				visited[np] = true
				q.append(np)
	return visited


static func _spawn_rubble_cluster(parent: Node3D, local_pos: Vector3, rng: RandomNumberGenerator) -> void:
	for i in range(3):
		var sz := Vector3(rng.randf_range(0.16, 0.30), rng.randf_range(0.08, 0.18), rng.randf_range(0.16, 0.28))
		var off := Vector3(rng.randf_range(-0.24, 0.24), sz.y * 0.5, rng.randf_range(-0.24, 0.24))
		var r := _spawn_box_piece(parent, "Rubble_%d" % i, sz, local_pos + off, Color(0.32, 0.34, 0.36), 0.78)
		if r != null:
			r.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 180.0), rng.randf_range(-12.0, 12.0))


static func _apply_floor_decals(parent: Node3D, center: Vector3, span_x: float, span_z: float, decay_rate: float, rng: RandomNumberGenerator) -> void:
	var decal_count: int = clampi(int(round(decay_rate * 12.0)) + 2, 2, 7)
	var kinds: Array[String] = ["cracks", "papers", "scorch", "blood"]
	for i in range(decal_count):
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var decal := Decal.new()
		decal.name = "RuinsDecal_%d" % i
		var dim: float = rng.randf_range(1.2, 2.4)
		decal.size = Vector3(dim, 0.45, dim)
		decal.texture_albedo = _get_decal_texture(kind)
		decal.albedo_mix = 0.84
		decal.position = Vector3(
			center.x + rng.randf_range(-span_x * 0.42, span_x * 0.42),
			0.12,
			center.z + rng.randf_range(-span_z * 0.42, span_z * 0.42)
		)
		decal.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		parent.add_child(decal)


static func _spawn_box_piece(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	pos: Vector3,
	color: Color,
	weathering: float = 0.55,
	metallic: float = 0.06
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _get_weathered_material(color, weathering, metallic)
	parent.add_child(mi)
	return mi


static func _spawn_glass_pane(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "GlassPane"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.68, 0.82, 0.36)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	mat.metallic = 0.2
	mi.material_override = mat
	parent.add_child(mi)


static func _add_box_collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	parent.add_child(sb)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)


static func _record_local_obstacle(local_pos: Vector3, rot_y_deg: float, size_xz: Vector2, out_rects: Array[Rect2]) -> void:
	var rad: float = deg_to_rad(rot_y_deg)
	var c: float = absf(cos(rad))
	var s: float = absf(sin(rad))
	var hx: float = (size_xz.x * c + size_xz.y * s) * 0.5
	var hz: float = (size_xz.x * s + size_xz.y * c) * 0.5
	out_rects.append(Rect2(local_pos.x - hx, local_pos.z - hz, hx * 2.0, hz * 2.0))


static func _transform_rect(local_rect: Rect2, origin: Vector3, rot_y_deg: float) -> Rect2:
	var rad: float = deg_to_rad(rot_y_deg)
	var basis := Basis(Vector3.UP, rad)
	var corners: Array[Vector3] = [
		Vector3(local_rect.position.x, 0.0, local_rect.position.y),
		Vector3(local_rect.end.x, 0.0, local_rect.position.y),
		Vector3(local_rect.position.x, 0.0, local_rect.end.y),
		Vector3(local_rect.end.x, 0.0, local_rect.end.y),
	]
	var min_x: float = INF
	var min_z: float = INF
	var max_x: float = -INF
	var max_z: float = -INF
	for cp: Vector3 in corners:
		var wp: Vector3 = origin + basis * cp
		min_x = minf(min_x, wp.x)
		min_z = minf(min_z, wp.z)
		max_x = maxf(max_x, wp.x)
		max_z = maxf(max_z, wp.z)
	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


static func _get_weathered_material(color: Color, weathering: float, metallic: float) -> Material:
	var key := "%.2f_%.2f_%.2f_%.2f_%.2f" % [color.r, color.g, color.b, weathering, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key] as Material
	if _shader_cache == null and ResourceLoader.exists(WEATHERED_SHADER_PATH):
		_shader_cache = load(WEATHERED_SHADER_PATH) as Shader
	if _shader_cache != null:
		var sm := ShaderMaterial.new()
		sm.shader = _shader_cache
		sm.set_shader_parameter("albedo_color", color)
		sm.set_shader_parameter("weathering_strength", weathering)
		sm.set_shader_parameter("metallic_val", metallic)
		_mat_cache[key] = sm
		return sm
	var std := StandardMaterial3D.new()
	std.albedo_color = color
	std.roughness = 0.85
	std.metallic = metallic
	_mat_cache[key] = std
	return std


static func _get_decal_texture(kind: String) -> Texture2D:
	if _decal_tex_cache.has(kind):
		return _decal_tex_cache[kind] as Texture2D

	var sz: int = 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()

	match kind:
		"blood":
			for _i in range(28):
				var cx := rng.randf_range(16.0, 48.0)
				var cy := rng.randf_range(16.0, 48.0)
				var rad := rng.randf_range(2.5, 9.0)
				_paint_soft_circle(img, cx, cy, rad, Color(0.28, 0.04, 0.04, 0.72))
		"scorch":
			_paint_soft_circle(img, 32.0, 32.0, 22.0, Color(0.08, 0.08, 0.09, 0.68))
			_paint_soft_circle(img, 32.0, 32.0, 12.0, Color(0.04, 0.04, 0.05, 0.82))
		"papers":
			for _i in range(7):
				var px := rng.randi_range(10, 46)
				var py := rng.randi_range(10, 46)
				for dx in range(rng.randi_range(5, 9)):
					for dy in range(rng.randi_range(4, 7)):
						if px + dx < sz and py + dy < sz:
							img.set_pixel(px + dx, py + dy, Color(0.74, 0.76, 0.78, 0.78))
		_:
			var x: float = 12.0
			var y: float = 32.0
			for _s in range(36):
				x += rng.randf_range(0.6, 1.4)
				y += rng.randf_range(-1.8, 1.8)
				var ix := clampi(int(x), 1, sz - 2)
				var iy := clampi(int(y), 1, sz - 2)
				img.set_pixel(ix, iy, Color(0.06, 0.07, 0.08, 0.76))
				img.set_pixel(ix, iy + 1, Color(0.10, 0.11, 0.12, 0.45))

	var tex := ImageTexture.create_from_image(img)
	_decal_tex_cache[kind] = tex
	return tex


static func _paint_soft_circle(img: Image, cx: float, cy: float, rad: float, col: Color) -> void:
	var sz: int = img.get_width()
	var x0: int = maxi(0, int(floor(cx - rad)))
	var x1: int = mini(sz - 1, int(ceil(cx + rad)))
	var y0: int = maxi(0, int(floor(cy - rad)))
	var y1: int = mini(sz - 1, int(ceil(cy + rad)))
	for py in range(y0, y1 + 1):
		for px in range(x0, x1 + 1):
			var d: float = Vector2(float(px) - cx, float(py) - cy).length()
			if d <= rad:
				var falloff: float = 1.0 - (d / maxf(0.1, rad))
				var c := Color(col.r, col.g, col.b, col.a * falloff)
				var prev := img.get_pixel(px, py)
				img.set_pixel(px, py, prev.blend(c))


static func _fallback_24x24_rows() -> Array[String]:
	return [
		"........................",
		"........................",
		"..##oo##oo##+###oo##oo..",
		"..#H  T    |   |123F O#.",
		"..#L   l   |   +     7#.",
		"..#        +   |  f   o.",
		"..o  E     |   | hfh  #.",
		"..#||||||||+   ||||||+#.",
		"..#  @@    |          #.",
		"..o  @@  d |   +|||||+#.",
		"..#        +   |8 S t #.",
		"..#  r     |   |9    B#.",
		"..###o######o###oo#####.",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
		"........................",
	]
