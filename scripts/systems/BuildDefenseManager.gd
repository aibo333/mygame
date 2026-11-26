class_name BuildDefenseManager
extends Node3D

signal structure_built(entry: Dictionary)
signal structure_removed(entry_id: String, kind: String)
signal build_mode_changed(active: bool, selected_kind: String)

const STRUCTURE_ORDER: Array[String] = ["sandbag", "barricade", "landmine", "turret", "searchlight", "window_board"]

const STRUCTURE_CATALOG: Dictionary = {
	"sandbag": {
		"name": "沙袋掩體",
		"icon": "🧱",
		"hp": 220.0,
		"cost": {"scrap": 2},
		"size": Vector3(2.4, 0.95, 0.85),
		"desc": "穩固的防禦沙袋牆，阻擋屍群推進並吸引攻擊（220 HP）",
		"accent": Color(0.78, 0.70, 0.52),
	},
	"barricade": {
		"name": "鐵絲拒馬",
		"icon": "🚧",
		"hp": 320.0,
		"thorns_dps": 18.0,
		"cost": {"scrap": 3, "parts": 1},
		"size": Vector3(2.6, 1.15, 1.05),
		"desc": "重型尖刺拒馬，阻擋並持續對貼近的喪屍造成反傷（320 HP）",
		"accent": Color(0.96, 0.68, 0.24),
	},
	"landmine": {
		"name": "感壓地雷",
		"icon": "💣",
		"hp": 40.0,
		"trigger_radius": 1.85,
		"blast_radius": 4.4,
		"blast_damage": 165.0,
		"cost": {"scrap": 1, "parts": 1, "fuel": 1},
		"size": Vector3(0.7, 0.2, 0.7),
		"desc": "喪屍踏入 1.8m 即引爆，造成 4.4m 範圍 165 點毀滅傷害",
		"accent": Color(1.0, 0.36, 0.28),
	},
	"turret": {
		"name": "固定機槍砲台",
		"icon": "🔫",
		"hp": 180.0,
		"range": 14.5,
		"dps": 26.0,
		"cost": {"scrap": 4, "parts": 3, "fuel": 1},
		"size": Vector3(1.1, 1.45, 1.1),
		"desc": "自動旋轉鎖定 14.5m 內喪屍並持續開火壓制（26 DPS）",
		"accent": Color(0.36, 0.90, 1.0),
	},
	"searchlight": {
		"name": "探照燈柱",
		"icon": "🔦",
		"hp": 140.0,
		"cost": {"scrap": 2, "parts": 2, "fuel": 1},
		"size": Vector3(0.65, 3.2, 0.65),
		"desc": "防線照明塔柱，向指定朝向投射強光光錐照亮夜戰死角（140 HP）",
		"accent": Color(0.98, 0.88, 0.42),
	},
	"window_board": {
		"name": "封窗木板",
		"icon": "🪵",
		"hp": 260.0,
		"cost": {"scrap": 1},
		"size": Vector3(1.15, 1.85, 0.26),
		"desc": "強化建築封窗／封門木板柵欄，可阻擋遊蕩喪屍並可拆遷回收（260 HP）",
		"accent": Color(0.72, 0.56, 0.36),
	},
}

var structures: Array[Dictionary] = []
var is_placing: bool = false
var selected_kind: String = "sandbag"
var placement_yaw_deg: float = 0.0
var ghost_world_pos: Vector3 = Vector3.ZERO
var ghost_valid: bool = false
var infinite_resources: bool = false
var god_mode: bool = false

var _structures_root: Node3D = null
var _ghost_root: Node3D = null
var _ghost_mat: StandardMaterial3D = null
var _vfx_root: Node3D = null
var _next_uid: int = 1


func setup(p_vfx_root: Node3D) -> void:
	_vfx_root = p_vfx_root
	if _structures_root == null:
		_structures_root = Node3D.new()
		_structures_root.name = "DeployedStructuresRoot"
		add_child(_structures_root)
	_build_ghost_preview()


func clear_all_structures() -> void:
	structures.clear()
	if _structures_root != null and is_instance_valid(_structures_root):
		for c in _structures_root.get_children():
			_structures_root.remove_child(c)
			c.free()
	cancel_placement()


func start_placement(kind: String) -> void:
	if not STRUCTURE_CATALOG.has(kind):
		return
	selected_kind = kind
	is_placing = true
	_rebuild_ghost_mesh()
	if _ghost_root != null:
		_ghost_root.visible = true
	build_mode_changed.emit(true, selected_kind)


func cancel_placement() -> void:
	if not is_placing:
		return
	is_placing = false
	if _ghost_root != null:
		_ghost_root.visible = false
	build_mode_changed.emit(false, selected_kind)


func rotate_placement(step_deg: float = 45.0) -> void:
	placement_yaw_deg = fmod(placement_yaw_deg + step_deg, 360.0)
	if _ghost_root != null:
		_ghost_root.rotation_degrees.y = placement_yaw_deg


func get_combined_resources(backpack: Dictionary, train_stash: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in LootStashManager.RESOURCE_ORDER:
		out[k] = int(backpack.get(k, 0)) + int(train_stash.get(k, 0))
	return out


func can_afford_structure(kind: String, backpack: Dictionary, train_stash: Dictionary) -> bool:
	if infinite_resources:
		return true
	var spec: Dictionary = STRUCTURE_CATALOG.get(kind, {}) as Dictionary
	var cost: Dictionary = spec.get("cost", {}) as Dictionary
	var pool: Dictionary = get_combined_resources(backpack, train_stash)
	for k in cost.keys():
		if int(pool.get(k, 0)) < int(cost.get(k, 0)):
			return false
	return true


func format_cost(kind: String) -> String:
	var spec: Dictionary = STRUCTURE_CATALOG.get(kind, {}) as Dictionary
	var cost: Dictionary = spec.get("cost", {}) as Dictionary
	var names: Dictionary = {"scrap": "金屬", "parts": "零件", "fuel": "燃料", "supplies": "補給"}
	var parts: PackedStringArray = PackedStringArray()
	for k: String in LootStashManager.RESOURCE_ORDER:
		var v: int = int(cost.get(k, 0))
		if v > 0:
			parts.append("%s%d" % [str(names[k]), v])
	return " ".join(parts)


func _spend_from_pools(cost: Dictionary, backpack: Dictionary, train_stash: Dictionary) -> void:
	if infinite_resources:
		return
	for k in cost.keys():
		var need: int = int(cost.get(k, 0))
		var from_bp: int = mini(need, int(backpack.get(k, 0)))
		backpack[k] = int(backpack.get(k, 0)) - from_bp
		need -= from_bp
		if need > 0:
			train_stash[k] = maxi(0, int(train_stash.get(k, 0)) - need)


func update_ghost(world_pos: Vector3, bounds: Rect2, backpack: Dictionary, train_stash: Dictionary) -> void:
	if not is_placing or _ghost_root == null:
		return
	ghost_world_pos = Vector3(world_pos.x, 0.0, world_pos.z)
	_ghost_root.global_position = ghost_world_pos
	_ghost_root.rotation_degrees.y = placement_yaw_deg

	var in_bounds: bool = bounds.grow(-0.5).has_point(Vector2(ghost_world_pos.x, ghost_world_pos.z))
	var too_close: bool = false
	for st: Dictionary in structures:
		if not bool(st.get("alive", false)):
			continue
		var spos: Vector3 = st.get("pos", Vector3.ZERO) as Vector3
		if Vector2(spos.x - ghost_world_pos.x, spos.z - ghost_world_pos.z).length() < 1.35:
			too_close = true
			break

	ghost_valid = in_bounds and (not too_close) and can_afford_structure(selected_kind, backpack, train_stash)
	if _ghost_mat != null:
		var col: Color = Color(0.32, 0.96, 0.56, 0.52) if ghost_valid else Color(1.0, 0.32, 0.28, 0.52)
		_ghost_mat.albedo_color = col
		_ghost_mat.emission = Color(col.r, col.g, col.b)


func place_structure_free(kind: String, world_pos: Vector3, yaw_deg: float = 0.0) -> Dictionary:
	if not STRUCTURE_CATALOG.has(kind):
		return {"ok": false, "reason": "unknown_kind", "message": "未知的工事類型"}
	var spec: Dictionary = STRUCTURE_CATALOG[kind] as Dictionary
	var sid: String = "def_%03d" % _next_uid
	_next_uid += 1
	var pos: Vector3 = Vector3(world_pos.x, 0.0, world_pos.z)
	var vis: Dictionary = _spawn_structure_3d(sid, kind, pos, yaw_deg, spec)

	var entry: Dictionary = {
		"id": sid,
		"kind": kind,
		"name": str(spec.get("name", kind)),
		"pos": pos,
		"yaw_deg": yaw_deg,
		"hp": float(spec.get("hp", 100.0)),
		"max_hp": float(spec.get("hp", 100.0)),
		"alive": true,
		"fire_cd": 0.0,
		"node": vis["node"],
		"turret_head": vis.get("turret_head", null),
	}
	structures.append(entry)
	structure_built.emit(entry)
	return {"ok": true, "entry": entry, "message": "已部署預設【%s】" % str(entry["name"])}


func spawn_demo_fortifications(anchor_pos: Vector3, bounds: Rect2) -> int:
	# Place one of every fortification type cleanly along the train perimeter so DEMO players can inspect & test immediately!
	var presets: Array[Dictionary] = [
		{"kind": "sandbag", "offset": Vector3(-4.6, 0.0, 3.4), "yaw": 0.0},
		{"kind": "barricade", "offset": Vector3(4.4, 0.0, 3.4), "yaw": 0.0},
		{"kind": "landmine", "offset": Vector3(0.4, 0.0, 5.2), "yaw": 0.0},
		{"kind": "turret", "offset": Vector3(-2.1, 0.0, 2.4), "yaw": 0.0},
	]
	var placed: int = 0
	for p: Dictionary in presets:
		var kind: String = str(p["kind"])
		var off: Vector3 = p["offset"] as Vector3
		var target: Vector3 = Vector3(
			clampf(anchor_pos.x + off.x, bounds.position.x + 1.2, bounds.end.x - 1.2),
			0.0,
			clampf(anchor_pos.z + off.z, bounds.position.y + 1.2, bounds.end.y - 1.2)
		)
		var res: Dictionary = place_structure_free(kind, target, float(p["yaw"]))
		if bool(res.get("ok", false)):
			placed += 1
	return placed


func get_alive_structure_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for st: Dictionary in structures:
		if bool(st.get("alive", false)):
			var k: String = str(st.get("kind", ""))
			if not kinds.has(k):
				kinds.append(k)
	return kinds


func try_place_structure(kind: String, world_pos: Vector3, yaw_deg: float, bounds: Rect2, backpack: Dictionary, train_stash: Dictionary) -> Dictionary:
	if not STRUCTURE_CATALOG.has(kind):
		return {"ok": false, "reason": "unknown_kind", "message": "未知的工事類型"}
	if not bounds.grow(-0.4).has_point(Vector2(world_pos.x, world_pos.z)):
		return {"ok": false, "reason": "out_of_bounds", "message": "此位置超出可建造區域"}
	if not can_afford_structure(kind, backpack, train_stash):
		return {"ok": false, "reason": "insufficient_resources", "message": "材料不足（需要：%s）" % format_cost(kind)}

	var spec: Dictionary = STRUCTURE_CATALOG[kind] as Dictionary
	_spend_from_pools(spec.get("cost", {}) as Dictionary, backpack, train_stash)

	var sid: String = "def_%03d" % _next_uid
	_next_uid += 1
	var pos: Vector3 = Vector3(world_pos.x, 0.0, world_pos.z)
	var vis: Dictionary = _spawn_structure_3d(sid, kind, pos, yaw_deg, spec)

	var entry: Dictionary = {
		"id": sid,
		"kind": kind,
		"name": str(spec.get("name", kind)),
		"pos": pos,
		"yaw_deg": yaw_deg,
		"hp": float(spec.get("hp", 100.0)),
		"max_hp": float(spec.get("hp", 100.0)),
		"alive": true,
		"fire_cd": 0.0,
		"node": vis["node"],
		"turret_head": vis.get("turret_head", null),
	}
	structures.append(entry)
	structure_built.emit(entry)
	return {"ok": true, "entry": entry, "message": "已建造【%s】！" % str(entry["name"])}


func find_nearest_structure(world_pos: Vector3, max_dist: float = 2.8) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = max_dist
	for st: Dictionary in structures:
		if not bool(st.get("alive", false)):
			continue
		var spos: Vector3 = st.get("pos", Vector3.ZERO) as Vector3
		var d: float = Vector2(world_pos.x - spos.x, world_pos.z - spos.z).length()
		if d < best_d:
			best_d = d
			best = st
	return best


func repair_structure(sid: String, backpack: Dictionary, train_stash: Dictionary) -> Dictionary:
	for st: Dictionary in structures:
		if str(st.get("id", "")) == sid and bool(st.get("alive", false)):
			if float(st["hp"]) >= float(st["max_hp"]):
				return {"ok": false, "message": "此工事耐久度已是滿值"}
			var repair_cost: Dictionary = {"scrap": 1}
			var pool: Dictionary = get_combined_resources(backpack, train_stash)
			if not infinite_resources and int(pool.get("scrap", 0)) < 1:
				return {"ok": false, "message": "需要 1 個廢金屬才能修復工事"}
			_spend_from_pools(repair_cost, backpack, train_stash)
			st["hp"] = st["max_hp"]
			return {"ok": true, "message": "已修復【%s】至 100%% 耐久！" % str(st["name"])}
	return {"ok": false, "message": "找不到該防禦工事"}


func dismantle_structure(sid: String, backpack: Dictionary, train_stash: Dictionary = {}) -> Dictionary:
	for st: Dictionary in structures:
		if str(st.get("id", "")) == sid and bool(st.get("alive", false)):
			var kind: String = str(st["kind"])
			var spec: Dictionary = STRUCTURE_CATALOG.get(kind, {}) as Dictionary
			var cost: Dictionary = spec.get("cost", {}) as Dictionary
			var recovered: Dictionary = {}
			var refund_scrap: int = 0
			for k: String in LootStashManager.RESOURCE_ORDER:
				var c_amt: int = int(cost.get(k, 0))
				if c_amt <= 0:
					continue
				var rec: int = maxi(1 if k == "scrap" else 0, c_amt / 2)
				if rec <= 0 and c_amt >= 1 and k == "parts":
					rec = 1
				if rec > 0:
					recovered[k] = rec
					backpack[k] = int(backpack.get(k, 0)) + rec
					if k == "scrap":
						refund_scrap = rec
			if recovered.is_empty():
				recovered["scrap"] = 1
				backpack["scrap"] = int(backpack.get("scrap", 0)) + 1
				refund_scrap = 1
			var names: Dictionary = {"scrap": "金屬", "parts": "零件", "fuel": "燃料", "supplies": "補給"}
			var rec_parts: PackedStringArray = PackedStringArray()
			for rk: String in LootStashManager.RESOURCE_ORDER:
				var rv: int = int(recovered.get(rk, 0))
				if rv > 0:
					rec_parts.append("%s+%d" % [str(names.get(rk, rk)), rv])
			_destroy_structure_entry(st)
			return {
				"ok": true,
				"refund_scrap": refund_scrap,
				"recovered": recovered,
				"message": "已拆遷回收【%s】：%s" % [str(st["name"]), " ".join(rec_parts)],
			}
	return {"ok": false, "message": "找不到該防禦工事"}


func barricade_house_window(win_entry: Dictionary, bounds: Rect2, backpack: Dictionary, train_stash: Dictionary) -> Dictionary:
	if win_entry.is_empty():
		return {"ok": false, "message": "附近沒有可封固的窗戶"}
	if bool(win_entry.get("boarded", false)):
		return {"ok": false, "message": "此窗戶已經架設封窗木板"}
	var wpos: Vector3 = win_entry.get("pos", Vector3.ZERO) as Vector3
	var yaw: float = float(win_entry.get("yaw_deg", 0.0))
	var res: Dictionary = try_place_structure("window_board", wpos, yaw, bounds, backpack, train_stash)
	if bool(res.get("ok", false)):
		win_entry["boarded"] = true
	return res


func update_defenses(delta: float, horde: HordeManager) -> void:
	if horde == null:
		return
	var zombies: Array[ZombieUnit] = horde.get_active_zombies()
	if zombies.is_empty():
		return

	for st: Dictionary in structures:
		if not bool(st.get("alive", false)):
			continue
		var kind: String = str(st["kind"])
		var spos: Vector3 = st["pos"] as Vector3

		if kind == "landmine":
			var spec: Dictionary = STRUCTURE_CATALOG["landmine"] as Dictionary
			var trig_r: float = float(spec.get("trigger_radius", 1.85))
			var triggered: bool = false
			for z: ZombieUnit in zombies:
				if z.is_alive and Vector2(z.global_position.x - spos.x, z.global_position.z - spos.z).length() <= trig_r:
					triggered = true
					break
			if triggered:
				var blast_r: float = float(spec.get("blast_radius", 4.4))
				var blast_dmg: float = float(spec.get("blast_damage", 165.0))
				for z: ZombieUnit in zombies:
					if z.is_alive and Vector2(z.global_position.x - spos.x, z.global_position.z - spos.z).length() <= blast_r:
						z.apply_damage(blast_dmg)
				_spawn_explosion_vfx(spos + Vector3(0.0, 0.4, 0.0), blast_r)
				_destroy_structure_entry(st)
			continue

		if kind == "turret":
			var spec: Dictionary = STRUCTURE_CATALOG["turret"] as Dictionary
			var rng_m: float = float(spec.get("range", 14.5))
			var dps: float = float(spec.get("dps", 26.0))
			st["fire_cd"] = maxf(0.0, float(st["fire_cd"]) - delta)
			if float(st["fire_cd"]) <= 0.0:
				var best_z: ZombieUnit = null
				var best_d: float = rng_m
				for z: ZombieUnit in zombies:
					if not z.is_alive:
						continue
					var d: float = Vector2(z.global_position.x - spos.x, z.global_position.z - spos.z).length()
					if d < best_d:
						best_d = d
						best_z = z
				if best_z != null:
					st["fire_cd"] = 0.28
					var head: Node3D = st.get("turret_head", null) as Node3D
					if head != null and is_instance_valid(head):
						var to_z: Vector3 = best_z.global_position - spos
						head.rotation.y = atan2(to_z.x, to_z.z)
					_spawn_sentry_tracer(spos + Vector3(0.0, 1.25, 0.0), best_z.global_position + Vector3(0.0, 1.0, 0.0))
					best_z.apply_damage(dps * 0.28)

		# Zombies adjacent to solid defenses chew on them (and take thorns damage from barricades!)
		for z: ZombieUnit in zombies:
			if not z.is_alive:
				continue
			if Vector2(z.global_position.x - spos.x, z.global_position.z - spos.z).length() <= 1.75:
				if not god_mode:
					st["hp"] = float(st["hp"]) - z.attack_damage * delta * 0.75
				if kind == "barricade":
					var thorns: float = float((STRUCTURE_CATALOG["barricade"] as Dictionary).get("thorns_dps", 18.0))
					z.apply_damage(thorns * delta)
				if float(st["hp"]) <= 0.0:
					_destroy_structure_entry(st)
					break


func get_minimap_markers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st: Dictionary in structures:
		if bool(st.get("alive", false)):
			out.append({"pos": st["pos"], "kind": st["kind"]})
	return out


func _destroy_structure_entry(st: Dictionary) -> void:
	st["alive"] = false
	var n: Node3D = st.get("node", null) as Node3D
	if n != null and is_instance_valid(n):
		n.queue_free()
	structure_removed.emit(str(st.get("id", "")), str(st.get("kind", "")))


func _spawn_structure_3d(sid: String, kind: String, pos: Vector3, yaw_deg: float, spec: Dictionary) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.name = "Defense_" + sid
	root.position = pos
	root.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	_structures_root.add_child(root)

	var turret_head: Node3D = null
	var accent: Color = spec.get("accent", Color(0.8, 0.7, 0.5)) as Color

	match kind:
		"sandbag":
			var bag_mat: StandardMaterial3D = _mat(Color(0.68, 0.61, 0.45), 0.05, 0.90)
			for row in range(2):
				for bx in [-0.75, 0.0, 0.75]:
					_box(root, Vector3(0.72, 0.36, 0.68), Vector3(bx + (0.12 if row == 1 else 0.0), 0.20 + float(row) * 0.34, 0.0), bag_mat)
			_add_solid_collider(root, Vector3(2.4, 0.95, 0.85))
		"barricade":
			var wood_mat: StandardMaterial3D = _mat(Color(0.45, 0.31, 0.19), 0.1, 0.85)
			var iron_mat: StandardMaterial3D = _mat(Color(0.32, 0.35, 0.40), 0.75, 0.4)
			var warn_mat: StandardMaterial3D = _mat(accent, 0.2, 0.5)
			_box(root, Vector3(2.5, 0.22, 0.22), Vector3(0.0, 0.65, 0.0), warn_mat)
			for lx in [-0.9, 0.0, 0.9]:
				_box(root, Vector3(0.16, 1.35, 0.16), Vector3(lx, 0.58, 0.0), wood_mat, Vector3(34.0, 0.0, 0.0))
				_box(root, Vector3(0.16, 1.35, 0.16), Vector3(lx, 0.58, 0.0), iron_mat, Vector3(-34.0, 0.0, 0.0))
			_add_solid_collider(root, Vector3(2.6, 1.15, 1.05))
		"landmine":
			var mine_mat: StandardMaterial3D = _mat(Color(0.24, 0.27, 0.24), 0.6, 0.5)
			var led_mat: StandardMaterial3D = _mat(Color(1.0, 0.24, 0.18), 0.1, 0.2, Color(1.0, 0.24, 0.18), 3.6)
			_cyl(root, 0.36, 0.14, Vector3(0.0, 0.08, 0.0), mine_mat)
			_cyl(root, 0.11, 0.18, Vector3(0.0, 0.12, 0.0), led_mat)
		"turret":
			var base_mat: StandardMaterial3D = _mat(Color(0.24, 0.28, 0.34), 0.68, 0.42)
			var barrel_mat: StandardMaterial3D = _mat(Color(0.42, 0.46, 0.52), 0.82, 0.34)
			var optic_mat: StandardMaterial3D = _mat(accent, 0.1, 0.2, accent, 3.0)
			_cyl(root, 0.52, 0.32, Vector3(0.0, 0.16, 0.0), base_mat)
			_cyl(root, 0.16, 0.92, Vector3(0.0, 0.68, 0.0), barrel_mat)
			turret_head = Node3D.new()
			turret_head.name = "SentryHead"
			turret_head.position = Vector3(0.0, 1.22, 0.0)
			root.add_child(turret_head)
			_box(turret_head, Vector3(0.62, 0.44, 0.78), Vector3.ZERO, base_mat)
			_box(turret_head, Vector3(0.22, 0.14, 0.10), Vector3(0.0, 0.24, 0.38), optic_mat)
			_cyl(turret_head, 0.06, 0.95, Vector3(-0.14, 0.0, 0.65), barrel_mat, Vector3(90.0, 0.0, 0.0))
			_cyl(turret_head, 0.06, 0.95, Vector3(0.14, 0.0, 0.65), barrel_mat, Vector3(90.0, 0.0, 0.0))
			_add_solid_collider(root, Vector3(1.1, 1.45, 1.1))
		"searchlight":
			var pole_mat: StandardMaterial3D = _mat(Color(0.24, 0.28, 0.34), 0.72, 0.42)
			var lamp_mat: StandardMaterial3D = _mat(Color(1.0, 0.94, 0.72), 0.1, 0.2, Color(1.0, 0.90, 0.62), 3.4)
			_cyl(root, 0.34, 0.25, Vector3(0.0, 0.125, 0.0), pole_mat)
			_cyl(root, 0.09, 3.1, Vector3(0.0, 1.65, 0.0), pole_mat)
			_box(root, Vector3(0.56, 0.32, 0.38), Vector3(0.0, 3.15, 0.12), pole_mat)
			_box(root, Vector3(0.46, 0.22, 0.08), Vector3(0.0, 3.15, 0.32), lamp_mat)
			var flood := SpotLight3D.new()
			flood.name = "PoleSearchlightCone"
			flood.light_color = Color(1.0, 0.94, 0.78)
			flood.light_energy = 7.2
			flood.spot_range = 24.0
			flood.spot_angle = 42.0
			flood.spot_attenuation = 0.9
			flood.shadow_enabled = false
			flood.position = Vector3(0.0, 3.15, 0.36)
			flood.basis = Basis.looking_at(Vector3(0.0, -0.32, 1.0), Vector3.UP)
			root.add_child(flood)
			_add_solid_collider(root, Vector3(0.65, 3.2, 0.65))
		"window_board":
			var plank_mat: StandardMaterial3D = _mat(Color(0.44, 0.32, 0.21), 0.08, 0.86)
			var nail_mat: StandardMaterial3D = _mat(Color(0.32, 0.36, 0.42), 0.78, 0.36)
			for py in [0.45, 0.92, 1.38, 1.76]:
				_box(root, Vector3(1.14, 0.18, 0.12), Vector3(0.0, py, 0.0), plank_mat, Vector3(0.0, 0.0, -3.5 if int(py * 10) % 2 == 0 else 3.5))
			_box(root, Vector3(0.14, 1.72, 0.16), Vector3(-0.42, 1.05, 0.0), nail_mat)
			_box(root, Vector3(0.14, 1.72, 0.16), Vector3(0.42, 1.05, 0.0), nail_mat)
			_add_solid_collider(root, Vector3(1.15, 1.85, 0.26))

	return {"node": root, "turret_head": turret_head}


func _build_ghost_preview() -> void:
	if _ghost_root != null:
		return
	_ghost_root = Node3D.new()
	_ghost_root.name = "BuildPlacementGhost"
	_ghost_root.visible = false
	add_child(_ghost_root)

	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(0.32, 0.96, 0.56, 0.52)
	_ghost_mat.emission_enabled = true
	_ghost_mat.emission = Color(0.32, 0.96, 0.56)
	_ghost_mat.emission_energy_multiplier = 1.6
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rebuild_ghost_mesh()


func _rebuild_ghost_mesh() -> void:
	if _ghost_root == null:
		return
	for c in _ghost_root.get_children():
		_ghost_root.remove_child(c)
		c.queue_free()
	var spec: Dictionary = STRUCTURE_CATALOG.get(selected_kind, STRUCTURE_CATALOG["sandbag"]) as Dictionary
	var sz: Vector3 = spec.get("size", Vector3(2.0, 1.0, 1.0)) as Vector3
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = Vector3(0.0, sz.y * 0.5 + 0.05, 0.0)
	mi.material_override = _ghost_mat
	_ghost_root.add_child(mi)


func _add_solid_collider(parent: Node3D, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.0, size.y * 0.5, 0.0)
	parent.add_child(body)
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)


func _mat(col: Color, metallic: float, roughness: float, emit: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)


func _spawn_sentry_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	if _vfx_root == null or not is_inside_tree():
		return
	var seg: Vector3 = to_pos - from_pos
	var beam: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.06, 0.06, maxf(0.4, seg.length()))
	beam.mesh = box
	var mat: StandardMaterial3D = _mat(Color(0.38, 0.94, 1.0, 0.95), 0.0, 0.5, Color(0.38, 0.94, 1.0), 4.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat
	_vfx_root.add_child(beam)
	beam.global_position = (from_pos + to_pos) * 0.5
	beam.look_at(to_pos, Vector3.UP)
	var tw: Tween = beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.09)
	tw.tween_callback(beam.queue_free)


func _spawn_explosion_vfx(pos: Vector3, radius: float) -> void:
	if _vfx_root == null or not is_inside_tree():
		return
	var sph: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.65
	sm.height = 1.3
	sph.mesh = sm
	var mat: StandardMaterial3D = _mat(Color(1.0, 0.52, 0.16, 0.88), 0.0, 0.4, Color(1.0, 0.44, 0.12), 4.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sph.material_override = mat
	_vfx_root.add_child(sph)
	sph.global_position = pos
	var tw: Tween = sph.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sph, "scale", Vector3.ONE * (radius * 0.95), 0.30)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.30)
	tw.chain().tween_callback(sph.queue_free)
