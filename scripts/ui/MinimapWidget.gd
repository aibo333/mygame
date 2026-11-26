class_name MinimapWidget
extends Control

const MAP_WIDTH: float = 256.0
const MAP_HEIGHT: float = 204.0

var world_bounds: Rect2 = Rect2(-46.0, -28.0, 90.0, 65.0)
var cross_road_x: int = 0
var rail_z: float = -3.2
var north_road_z: float = -35.2
var south_road_z: float = 32.0
var house_footprints: Array[Rect2] = []
var player_pos: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var train_pos: Vector3 = SquadConfig.TRAIN_POSITION
var train_half_length: float = 22.0
var boarding_pos: Vector3 = Vector3(0.0, 0.0, 1.4)
var stash_pos: Vector3 = Vector3(10.6, 0.0, 1.4)
var loot_positions: Array[Vector3] = []
var mission_positions: Array[Vector3] = []
var survivor_pos: Vector3 = Vector3.ZERO
var has_survivor: bool = false
var zombie_positions: Array[Vector3] = []
var defense_markers: Array[Dictionary] = []
var has_facility: bool = false
var facility_pos: Vector3 = Vector3.ZERO
var facility_powered: bool = false
var has_blockade: bool = false
var blockade_pos: Vector3 = Vector3.ZERO


func _init() -> void:
	custom_minimum_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_snapshot(data: Dictionary) -> void:
	var b_raw: Variant = data.get("bounds", world_bounds)
	if b_raw is Rect2:
		var b: Rect2 = b_raw as Rect2
		world_bounds = Rect2(b.position.x - 1.5, b.position.y - 1.5, b.size.x + 3.0, b.size.y + 3.0)
	cross_road_x = int(data.get("cross_road_x", 0))
	rail_z = float(data.get("rail_z", -3.2))
	north_road_z = float(data.get("north_road_z", -19.2))
	south_road_z = float(data.get("south_road_z", 19.2))
	house_footprints.clear()
	for fp in (data.get("house_footprints", []) as Array):
		if fp is Rect2:
			house_footprints.append(fp as Rect2)
	player_pos = data.get("player_pos", Vector3.ZERO) as Vector3
	player_yaw = float(data.get("player_yaw", 0.0))
	train_pos = data.get("train_pos", SquadConfig.TRAIN_POSITION) as Vector3
	train_half_length = float(data.get("train_half_length", 22.0))
	boarding_pos = data.get("boarding_pos", Vector3(0.0, 0.0, 1.4)) as Vector3
	stash_pos = data.get("stash_pos", Vector3(10.6, 0.0, 1.4)) as Vector3

	loot_positions.clear()
	for p in (data.get("loot_positions", []) as Array):
		if p is Vector3:
			loot_positions.append(p as Vector3)

	mission_positions.clear()
	for p in (data.get("mission_positions", []) as Array):
		if p is Vector3:
			mission_positions.append(p as Vector3)

	has_survivor = bool(data.get("has_survivor", false))
	survivor_pos = data.get("survivor_pos", Vector3.ZERO) as Vector3

	zombie_positions.clear()
	for p in (data.get("zombie_positions", []) as Array):
		if p is Vector3:
			zombie_positions.append(p as Vector3)

	defense_markers.clear()
	for d in (data.get("defense_markers", []) as Array):
		if d is Dictionary:
			defense_markers.append(d as Dictionary)

	has_facility = bool(data.get("has_facility", false))
	facility_pos = data.get("facility_pos", Vector3.ZERO) as Vector3
	facility_powered = bool(data.get("facility_powered", false))
	has_blockade = bool(data.get("has_blockade", false))
	blockade_pos = data.get("blockade_pos", Vector3.ZERO) as Vector3

	queue_redraw()


func _world_to_map(pos: Vector3) -> Vector2:
	var pad: float = 10.0
	var inner_w: float = size.x - pad * 2.0
	var inner_h: float = size.y - pad * 2.0
	var nx: float = clampf((pos.x - world_bounds.position.x) / maxf(1.0, world_bounds.size.x), 0.0, 1.0)
	var nz: float = clampf((pos.z - world_bounds.position.y) / maxf(1.0, world_bounds.size.y), 0.0, 1.0)
	return Vector2(pad + nx * inner_w, pad + nz * inner_h)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	# Cold obsidian tactical radar canvas
	draw_rect(rect, Color(0.035, 0.05, 0.072, 0.98), true)

	# Precision tactical radar grid
	for gx in range(24, int(size.x), 32):
		draw_line(Vector2(float(gx), 4.0), Vector2(float(gx), size.y - 4.0), Color(0.22, 0.42, 0.56, 0.16), 1.0)
	for gy in range(24, int(size.y), 32):
		draw_line(Vector2(4.0, float(gy)), Vector2(size.x - 4.0, float(gy)), Color(0.22, 0.42, 0.56, 0.16), 1.0)

	# Overmap North & South Avenues + N-S Cross Road
	var nr_a: Vector2 = _world_to_map(Vector3(world_bounds.position.x, 0.0, north_road_z))
	var nr_b: Vector2 = _world_to_map(Vector3(world_bounds.end.x, 0.0, north_road_z))
	draw_line(nr_a, nr_b, Color(0.20, 0.25, 0.32, 0.78), 8.0)

	var sr_a: Vector2 = _world_to_map(Vector3(world_bounds.position.x, 0.0, south_road_z))
	var sr_b: Vector2 = _world_to_map(Vector3(world_bounds.end.x, 0.0, south_road_z))
	draw_line(sr_a, sr_b, Color(0.20, 0.25, 0.32, 0.78), 8.0)

	var ns_wx: float = (float(cross_road_x) + 0.5) * 3.2
	var ns_a: Vector2 = _world_to_map(Vector3(ns_wx, 0.0, world_bounds.position.y))
	var ns_b: Vector2 = _world_to_map(Vector3(ns_wx, 0.0, world_bounds.end.y))
	draw_line(ns_a, ns_b, Color(0.20, 0.25, 0.32, 0.78), 8.0)

	# CDDA Civil-Defense House Footprints
	for fp: Rect2 in house_footprints:
		var tl: Vector2 = _world_to_map(Vector3(fp.position.x, 0.0, fp.position.y))
		var br: Vector2 = _world_to_map(Vector3(fp.end.x, 0.0, fp.end.y))
		var hrect := Rect2(tl, br - tl)
		draw_rect(hrect, Color(0.22, 0.30, 0.38, 0.85), true)
		draw_rect(hrect, Color(0.36, 0.54, 0.68, 0.75), false, 1.0)

	# Through-Running Central Railway Line & Armored Train Tactical Silhouette
	var rail_l: Vector2 = _world_to_map(Vector3(world_bounds.position.x, 0.0, rail_z))
	var rail_r: Vector2 = _world_to_map(Vector3(world_bounds.end.x, 0.0, rail_z))
	draw_line(rail_l, rail_r, Color(0.36, 0.46, 0.56, 0.78), 3.0)

	var tr_l: Vector2 = _world_to_map(train_pos + Vector3(-train_half_length, 0.0, 0.0))
	var tr_r: Vector2 = _world_to_map(train_pos + Vector3(train_half_length, 0.0, 0.0))
	var tr_rect := Rect2(tr_l.x, tr_l.y - 5.0, maxf(24.0, tr_r.x - tr_l.x), 10.0)
	draw_rect(tr_rect, Color(0.95, 0.63, 0.14, 0.88), true)
	draw_rect(tr_rect, TacticalTheme.ACCENT_CYAN, false, 1.0)
	draw_circle(_world_to_map(boarding_pos), 3.5, TacticalTheme.ACCENT_EMERALD)
	draw_circle(_world_to_map(stash_pos), 3.5, TacticalTheme.ACCENT_AMBER)

	# Large Holdout Power Facility & Railway Exit Blockade
	if has_facility:
		var fp2: Vector2 = _world_to_map(facility_pos)
		var fcol: Color = TacticalTheme.ACCENT_CYAN if facility_powered else TacticalTheme.ACCENT_AMBER
		draw_circle(fp2, 8.5, Color(fcol.r, fcol.g, fcol.b, 0.25))
		draw_rect(Rect2(fp2.x - 5.0, fp2.y - 5.0, 10.0, 10.0), fcol, true)
		draw_rect(Rect2(fp2.x - 5.0, fp2.y - 5.0, 10.0, 10.0), Color.WHITE, false, 1.2)
	if has_blockade:
		var bp2: Vector2 = _world_to_map(blockade_pos)
		draw_line(bp2 + Vector2(-4.0, -4.0), bp2 + Vector2(4.0, 4.0), TacticalTheme.ACCENT_CRIMSON, 2.0)
		draw_line(bp2 + Vector2(-4.0, 4.0), bp2 + Vector2(4.0, -4.0), TacticalTheme.ACCENT_CRIMSON, 2.0)

	# Deployed Player Defenses
	for dm: Dictionary in defense_markers:
		var dpos: Vector3 = dm.get("pos", Vector3.ZERO) as Vector3
		var dkind: String = str(dm.get("kind", "sandbag"))
		var mp: Vector2 = _world_to_map(dpos)
		var col: Color = Color(1.0, 0.48, 0.20) if dkind == "landmine" else (TacticalTheme.ACCENT_CYAN if dkind == "turret" else Color(0.62, 0.70, 0.78))
		draw_rect(Rect2(mp.x - 2.5, mp.y - 2.5, 5.0, 5.0), col, true)

	# Unlooted Loot Crates
	for lp: Vector3 in loot_positions:
		draw_circle(_world_to_map(lp), 3.0, TacticalTheme.ACCENT_AMBER)

	# Mission Objectives (Violet-Cyan Tactical Diamonds)
	for mp3: Vector3 in mission_positions:
		var m2: Vector2 = _world_to_map(mp3)
		var dia: PackedVector2Array = PackedVector2Array([
			m2 + Vector2(0.0, -5.5),
			m2 + Vector2(5.5, 0.0),
			m2 + Vector2(0.0, 5.5),
			m2 + Vector2(-5.5, 0.0),
		])
		draw_colored_polygon(dia, TacticalTheme.ACCENT_VIOLET)

	# Trapped Survivor
	if has_survivor:
		var sp: Vector2 = _world_to_map(survivor_pos)
		draw_circle(sp, 4.5, TacticalTheme.ACCENT_EMERALD)
		draw_arc(sp, 7.0, 0.0, TAU, 14, Color(0.24, 0.86, 0.58, 0.7), 1.5)

	# Active Hostiles
	for zp: Vector3 in zombie_positions:
		draw_circle(_world_to_map(zp), 2.8, TacticalTheme.ACCENT_CRIMSON)

	# Player Marker
	var pp: Vector2 = _world_to_map(player_pos)
	var fwd: Vector2 = Vector2(-sin(player_yaw), -cos(player_yaw)).normalized()
	var right: Vector2 = Vector2(-fwd.y, fwd.x)
	var tri: PackedVector2Array = PackedVector2Array([
		pp + fwd * 7.5,
		pp - fwd * 4.5 + right * 4.5,
		pp - fwd * 4.5 - right * 4.5,
	])
	draw_colored_polygon(tri, TacticalTheme.TEXT_PRIMARY)
	draw_circle(pp, 2.0, TacticalTheme.ACCENT_CYAN)

	# Crisp Radar Framing + Corner Brackets
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(size.x * 0.5 - 6.0, 14.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TacticalTheme.ACCENT_CYAN)
	draw_rect(rect, TacticalTheme.BORDER_STEEL, false, 1.0)
	TacticalTheme.draw_corner_brackets(self, rect, TacticalTheme.ACCENT_CYAN, 10.0, 1.5)
