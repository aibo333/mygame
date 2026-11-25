class_name MinimapWidget
extends Control

const MAP_WIDTH: float = 256.0
const MAP_HEIGHT: float = 204.0

var world_bounds: Rect2 = Rect2(-46.0, -26.5, 90.0, 64.0)
var cross_road_x: int = 0
var player_pos: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var train_pos: Vector3 = SquadConfig.TRAIN_POSITION
var train_half_length: float = 22.0
var boarding_pos: Vector3 = Vector3(0.0, 0.0, -17.0)
var stash_pos: Vector3 = Vector3(10.6, 0.0, -17.0)
var loot_positions: Array[Vector3] = []
var mission_positions: Array[Vector3] = []
var survivor_pos: Vector3 = Vector3.ZERO
var has_survivor: bool = false
var zombie_positions: Array[Vector3] = []
var defense_markers: Array[Dictionary] = []


func _init() -> void:
	custom_minimum_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_snapshot(data: Dictionary) -> void:
	var b_raw: Variant = data.get("bounds", world_bounds)
	if b_raw is Rect2:
		var b: Rect2 = b_raw as Rect2
		var top_z: float = minf(b.position.y - 3.5, train_pos.z - 4.5)
		world_bounds = Rect2(b.position.x - 2.0, top_z, b.size.x + 4.0, (b.end.y - top_z) + 2.0)
	cross_road_x = int(data.get("cross_road_x", 0))
	player_pos = data.get("player_pos", Vector3.ZERO) as Vector3
	player_yaw = float(data.get("player_yaw", 0.0))
	train_pos = data.get("train_pos", SquadConfig.TRAIN_POSITION) as Vector3
	train_half_length = float(data.get("train_half_length", 22.0))
	boarding_pos = data.get("boarding_pos", Vector3(0.0, 0.0, -17.0)) as Vector3
	stash_pos = data.get("stash_pos", Vector3(10.6, 0.0, -17.0)) as Vector3

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
	# Warm tactical radar parchment-slate background
	draw_rect(rect, Color(0.10, 0.13, 0.16, 0.96), true)

	# Faint tactical grid
	for gx in range(24, int(size.x), 32):
		draw_line(Vector2(float(gx), 4.0), Vector2(float(gx), size.y - 4.0), Color(0.32, 0.42, 0.50, 0.16), 1.0)
	for gy in range(24, int(size.y), 32):
		draw_line(Vector2(4.0, float(gy)), Vector2(size.x - 4.0, float(gy)), Color(0.32, 0.42, 0.50, 0.16), 1.0)

	# Main roads overlay (E-W Boulevard at gz=2..3 -> z=8.0, Secondary South Lane at gz=8 -> z=25.6, N-S Cross Road)
	var ew_a: Vector2 = _world_to_map(Vector3(world_bounds.position.x, 0.0, 8.0))
	var ew_b: Vector2 = _world_to_map(Vector3(world_bounds.end.x, 0.0, 8.0))
	draw_line(ew_a, ew_b, Color(0.34, 0.38, 0.42, 0.72), 11.0)

	var sl_a: Vector2 = _world_to_map(Vector3(world_bounds.position.x, 0.0, 25.6))
	var sl_b: Vector2 = _world_to_map(Vector3(world_bounds.end.x, 0.0, 25.6))
	draw_line(sl_a, sl_b, Color(0.30, 0.34, 0.38, 0.56), 6.0)

	var ns_wx: float = (float(cross_road_x) + 0.5) * 3.2
	var ns_a: Vector2 = _world_to_map(Vector3(ns_wx, 0.0, train_pos.z + 5.5))
	var ns_b: Vector2 = _world_to_map(Vector3(ns_wx, 0.0, world_bounds.end.y))
	draw_line(ns_a, ns_b, Color(0.34, 0.38, 0.42, 0.72), 10.0)

	# Northern Railway Line & Enlarged Armored Train silhouette
	var rail_l: Vector2 = _world_to_map(Vector3(world_bounds.position.x, 0.0, train_pos.z))
	var rail_r: Vector2 = _world_to_map(Vector3(world_bounds.end.x, 0.0, train_pos.z))
	draw_line(rail_l, rail_r, Color(0.56, 0.48, 0.36, 0.75), 4.0)

	var tr_l: Vector2 = _world_to_map(train_pos + Vector3(-train_half_length, 0.0, 0.0))
	var tr_r: Vector2 = _world_to_map(train_pos + Vector3(train_half_length, 0.0, 0.0))
	draw_rect(Rect2(tr_l.x, tr_l.y - 6.0, maxf(24.0, tr_r.x - tr_l.x), 12.0), Color(0.84, 0.62, 0.24, 0.96), true)
	draw_circle(_world_to_map(boarding_pos), 4.0, Color(0.36, 0.98, 0.74, 0.95))
	draw_circle(_world_to_map(stash_pos), 4.0, Color(1.0, 0.82, 0.30, 0.95))

	# Deployed Player Defenses (blue-teal squares / orange mines)
	for dm: Dictionary in defense_markers:
		var dpos: Vector3 = dm.get("pos", Vector3.ZERO) as Vector3
		var dkind: String = str(dm.get("kind", "sandbag"))
		var mp: Vector2 = _world_to_map(dpos)
		var col: Color = Color(1.0, 0.56, 0.22) if dkind == "landmine" else (Color(0.38, 0.92, 1.0) if dkind == "turret" else Color(0.76, 0.68, 0.48))
		draw_rect(Rect2(mp.x - 3.0, mp.y - 3.0, 6.0, 6.0), col, true)

	# Unlooted Loot Crates (Warm Gold dots)
	for lp: Vector3 in loot_positions:
		draw_circle(_world_to_map(lp), 3.4, Color(1.0, 0.84, 0.34, 0.92))

	# Mission Objectives (Bright Magenta diamonds)
	for mp3: Vector3 in mission_positions:
		var m2: Vector2 = _world_to_map(mp3)
		var dia: PackedVector2Array = PackedVector2Array([
			m2 + Vector2(0.0, -6.0),
			m2 + Vector2(6.0, 0.0),
			m2 + Vector2(0.0, 6.0),
			m2 + Vector2(-6.0, 0.0),
		])
		draw_colored_polygon(dia, Color(1.0, 0.42, 0.96, 1.0))

	# Trapped Survivor (Emerald pulsing ring)
	if has_survivor:
		var sp: Vector2 = _world_to_map(survivor_pos)
		draw_circle(sp, 5.0, Color(0.32, 1.0, 0.62, 0.95))
		draw_arc(sp, 7.5, 0.0, TAU, 14, Color(0.32, 1.0, 0.62, 0.7), 1.5)

	# Active Zombies (Crimson dots)
	for zp: Vector3 in zombie_positions:
		draw_circle(_world_to_map(zp), 3.0, Color(0.98, 0.28, 0.26, 0.94))

	# Player Marker (Bright white-cyan arrow)
	var pp: Vector2 = _world_to_map(player_pos)
	var fwd: Vector2 = Vector2(-sin(player_yaw), -cos(player_yaw)).normalized()
	var right: Vector2 = Vector2(-fwd.y, fwd.x)
	var tri: PackedVector2Array = PackedVector2Array([
		pp + fwd * 7.5,
		pp - fwd * 4.5 + right * 4.5,
		pp - fwd * 4.5 - right * 4.5,
	])
	draw_colored_polygon(tri, Color(0.96, 0.99, 1.0, 1.0))
	draw_circle(pp, 2.2, Color(0.30, 0.90, 1.0, 1.0))

	# Crisp Compass N label & border
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(size.x * 0.5 - 8.0, 16.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.88, 0.52))
	draw_rect(rect, Color(0.45, 0.76, 0.92, 0.85), false, 2.0)
