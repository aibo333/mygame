class_name MissionDirector
extends Node3D

signal mission_updated(summary_text: String, progress: int, target: int, ready_to_extract: bool)
signal objective_ambush_triggered(pos: Vector3)
signal survivor_rescued(crew_data: Dictionary)
signal extraction_started(duration_sec: float)
signal extraction_updated(remaining_sec: float, total_sec: float, player_in_zone: bool)
signal extraction_succeeded()

const MISSION_TYPES: Array[String] = ["fuel_recovery", "relay_repair", "cargo_retrieval"]

const RESCUE_CREW_POOL: Array[Dictionary] = [
	{
		"id": "medic_leo",
		"name": "里歐 戰地醫官",
		"short_name": "里歐",
		"role": "medic",
		"trait": "急救輸血（醫務室回血 +30%）",
		"bonus_power": 0,
		"bonus_backpack": 0,
		"bonus_dps": 0.0,
	},
	{
		"id": "scout_yuki",
		"name": "雪 情報員",
		"short_name": "雪",
		"role": "scout",
		"trait": "信標追蹤（雷達偵測 +35%）",
		"bonus_power": 0,
		"bonus_backpack": 0,
		"bonus_dps": 0.0,
	},
	{
		"id": "mech_tetsu",
		"name": "鐵司 鍋爐匠",
		"short_name": "鐵司",
		"role": "mechanic",
		"trait": "高壓蒸汽（動力 +2 / 搶修加快）",
		"bonus_power": 2,
		"bonus_backpack": 0,
		"bonus_dps": 0.0,
	},
	{
		"id": "qm_nora",
		"name": "諾拉 補給長",
		"short_name": "諾拉",
		"role": "quartermaster",
		"trait": "超載貨架（貨運倉背包額外 +4）",
		"bonus_power": 0,
		"bonus_backpack": 4,
		"bonus_dps": 0.0,
	},
]

var mission_type: String = "fuel_recovery"
var mission_title: String = "燃料回收"
var target_count: int = 3
var completed_count: int = 0
var is_mission_complete: bool = false
var is_extracting: bool = false
var extraction_total: float = 45.0
var extraction_remaining: float = 45.0

var objective_nodes: Array[Dictionary] = []
var survivor_node: Dictionary = {}
var rescued_survivor: Dictionary = {}

var _root: Node3D = null


func start_mission(seed_value: int, loot_points: Array[Dictionary], existing_crew_ids: Array[String], forced_type: String = "") -> Dictionary:
	_clear_nodes()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x71E4A9

	if not forced_type.is_empty() and MISSION_TYPES.has(forced_type):
		mission_type = forced_type
	else:
		mission_type = MISSION_TYPES[rng.randi_range(0, MISSION_TYPES.size() - 1)]

	completed_count = 0
	is_mission_complete = false
	is_extracting = false
	extraction_remaining = 0.0
	rescued_survivor = {}

	_root = Node3D.new()
	_root.name = "MissionMarkersRoot"
	add_child(_root)

	match mission_type:
		"fuel_recovery":
			mission_title = "高能燃料回收"
			target_count = 3
		"relay_repair":
			mission_title = "訊號中繼修復"
			target_count = 2
		_:
			mission_title = "機密黑盒奪還"
			target_count = 1

	# Choose objective spots slightly offset from Sector loot points (guaranteed walkable!)
	var candidates: Array[Vector3] = []
	for lp: Dictionary in loot_points:
		var p: Vector3 = lp.get("pos", Vector3.ZERO) as Vector3
		candidates.append(p)
	if candidates.size() < 4:
		candidates = [
			Vector3(-12.0, 0.0, 4.0),
			Vector3(10.0, 0.0, 5.0),
			Vector3(-6.0, 0.0, 12.0),
			Vector3(12.0, 0.0, 11.0),
		]

	# Sort far-to-near so key mission objectives sit deeper inside the Sector
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.z > b.z
	)

	var used_positions: Array[Vector3] = []
	for i in range(target_count):
		var base_p: Vector3 = candidates[i % candidates.size()]
		var obj_pos: Vector3 = SquadConfig.clamp_playable(Vector3(base_p.x + 1.3, 0.0, maxf(base_p.z - 0.8, -10.0)))
		used_positions.append(obj_pos)
		var oid: String = "obj_%02d" % (i + 1)
		var olabel: String = _objective_label(i + 1)
		var vis: Dictionary = _build_objective_prop(oid, obj_pos, Color(0.98, 0.42, 0.92))
		objective_nodes.append({
			"id": oid,
			"label": olabel,
			"pos": obj_pos,
			"done": false,
			"node": vis["node"],
			"beacon": vis["beacon"],
			"ring": vis["ring"],
		})

	# Spawn 1 Trapped Survivor Rescue side-event if any recruitable NPC remains
	var candidate_crew: Dictionary = _pick_recruitable_survivor(existing_crew_ids, rng)
	if not candidate_crew.is_empty():
		var s_base: Vector3 = candidates[mini(target_count, candidates.size() - 1)]
		var s_pos: Vector3 = SquadConfig.clamp_playable(Vector3(s_base.x - 1.4, 0.0, maxf(s_base.z + 0.6, -9.0)))
		var svis: Dictionary = _build_objective_prop("survivor_sos", s_pos, Color(0.32, 0.98, 0.66), true)
		survivor_node = {
			"id": "survivor_sos",
			"label": "受困倖存者：%s" % str(candidate_crew.get("name", "倖存者")),
			"pos": s_pos,
			"rescued": false,
			"crew": candidate_crew,
			"node": svis["node"],
			"beacon": svis["beacon"],
			"ring": svis["ring"],
			"stickman": svis.get("stickman", {}),
		}
	else:
		survivor_node = {}

	mission_updated.emit(get_mission_hud_text(), completed_count, target_count, false)
	return {
		"mission_type": mission_type,
		"mission_title": mission_title,
		"target_count": target_count,
		"has_survivor": not survivor_node.is_empty(),
	}


func get_mission_hud_text() -> String:
	if is_extracting:
		return "🚂 發車撤離守點中（%.1fs）— 請留在登車區！" % extraction_remaining
	if is_mission_complete:
		return "✅ 主線完成【%s】— 返回北方登車區啟動發車！" % mission_title
	return "🎯 主線【%s】：%d / %d" % [mission_title, completed_count, target_count]


func get_mission_reward(tier_reward_mult: float = 1.0) -> Dictionary:
	if not is_mission_complete:
		return {}
	return {
		"scrap": int(round(5.0 * tier_reward_mult)),
		"parts": int(round(4.0 * tier_reward_mult)),
		"fuel": int(round(3.0 * tier_reward_mult)),
		"supplies": int(round(2.0 * tier_reward_mult)),
	}


func find_nearest_interactable(world_pos: Vector3, max_dist: float = 3.4) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = max_dist

	for obj: Dictionary in objective_nodes:
		if bool(obj.get("done", false)):
			continue
		var opos: Vector3 = obj.get("pos", Vector3.ZERO) as Vector3
		var d: float = Vector2(world_pos.x - opos.x, world_pos.z - opos.z).length()
		if d < best_d:
			best_d = d
			best = {
				"id": str(obj.get("id", "")),
				"kind": "mission_objective",
				"label": str(obj.get("label", mission_title)),
				"pos": opos,
			}

	if not survivor_node.is_empty() and not bool(survivor_node.get("rescued", false)):
		var spos: Vector3 = survivor_node.get("pos", Vector3.ZERO) as Vector3
		var sd: float = Vector2(world_pos.x - spos.x, world_pos.z - spos.z).length()
		if sd < best_d:
			best_d = sd
			best = {
				"id": "survivor_sos",
				"kind": "survivor_rescue",
				"label": str(survivor_node.get("label", "受困倖存者")),
				"pos": spos,
			}

	return best


func complete_objective(obj_id: String) -> Dictionary:
	for obj: Dictionary in objective_nodes:
		if str(obj.get("id", "")) == obj_id and not bool(obj.get("done", false)):
			obj["done"] = true
			_dim_objective_visual(obj)
			completed_count += 1
			var opos: Vector3 = obj.get("pos", Vector3.ZERO) as Vector3
			if mission_type == "relay_repair" or mission_type == "cargo_retrieval":
				objective_ambush_triggered.emit(opos)
			if completed_count >= target_count:
				is_mission_complete = true
			mission_updated.emit(get_mission_hud_text(), completed_count, target_count, is_mission_complete)
			return {
				"ok": true,
				"label": str(obj.get("label", "")),
				"completed": completed_count,
				"target": target_count,
				"all_done": is_mission_complete,
			}
	return {"ok": false}


func rescue_survivor() -> Dictionary:
	if survivor_node.is_empty() or bool(survivor_node.get("rescued", false)):
		return {"ok": false}
	survivor_node["rescued"] = true
	_dim_objective_visual(survivor_node)
	rescued_survivor = (survivor_node.get("crew", {}) as Dictionary).duplicate(true)
	survivor_rescued.emit(rescued_survivor)
	return {"ok": true, "crew": rescued_survivor}


func start_extraction(duration_sec: float) -> bool:
	if not is_mission_complete or is_extracting:
		return false
	is_extracting = true
	extraction_total = maxf(5.0, duration_sec)
	extraction_remaining = extraction_total
	extraction_started.emit(extraction_total)
	mission_updated.emit(get_mission_hud_text(), completed_count, target_count, true)
	return true


func update_extraction(delta: float, player_in_boarding_zone: bool) -> bool:
	if not is_extracting:
		return false
	extraction_remaining = maxf(0.0, extraction_remaining - delta)
	extraction_updated.emit(extraction_remaining, extraction_total, player_in_boarding_zone)
	if extraction_remaining <= 0.0:
		if player_in_boarding_zone:
			is_extracting = false
			extraction_succeeded.emit()
			return true
	return false


func get_compass_hint(player_pos: Vector3, boarding_pos: Vector3) -> String:
	var target_pos: Vector3 = boarding_pos
	var target_name: String = "裝甲列車登車區"
	if not is_mission_complete:
		var best_d: float = 9999.0
		for obj: Dictionary in objective_nodes:
			if bool(obj.get("done", false)):
				continue
			var p: Vector3 = obj.get("pos", Vector3.ZERO) as Vector3
			var d: float = Vector2(p.x - player_pos.x, p.z - player_pos.z).length()
			if d < best_d:
				best_d = d
				target_pos = p
				target_name = str(obj.get("label", mission_title))
	var delta_v: Vector2 = Vector2(target_pos.x - player_pos.x, target_pos.z - player_pos.z)
	var dist_m: int = int(round(delta_v.length()))
	var arrow: String = _direction_arrow(delta_v)
	return "%s %s (%dm)" % [arrow, target_name, dist_m]


func animate_markers(time_elapsed: float) -> void:
	for obj: Dictionary in objective_nodes:
		if not bool(obj.get("done", false)):
			var b: MeshInstance3D = obj.get("beacon", null) as MeshInstance3D
			if b != null and is_instance_valid(b):
				b.position.y = 1.6 + sin(time_elapsed * 3.0) * 0.16
				b.rotation.y = fmod(time_elapsed * 1.8, TAU)
	if not survivor_node.is_empty() and not bool(survivor_node.get("rescued", false)):
		var sb: MeshInstance3D = survivor_node.get("beacon", null) as MeshInstance3D
		if sb != null and is_instance_valid(sb):
			sb.position.y = 2.25 + sin(time_elapsed * 3.6) * 0.16
			sb.rotation.y = fmod(time_elapsed * 2.0, TAU)
		var sm: Dictionary = survivor_node.get("stickman", {}) as Dictionary
		if not sm.is_empty():
			var la: Node3D = sm.get("left_arm", null) as Node3D
			var ra: Node3D = sm.get("right_arm", null) as Node3D
			if la != null and is_instance_valid(la):
				la.rotation_degrees.z = -155.0 + sin(time_elapsed * 6.5) * 22.0
			if ra != null and is_instance_valid(ra):
				ra.rotation_degrees.z = 155.0 - sin(time_elapsed * 6.5) * 22.0


func _direction_arrow(v: Vector2) -> String:
	if v.length() < 2.2:
		return "◎"
	var ang: float = rad_to_deg(atan2(v.y, v.x))
	if ang >= -22.5 and ang < 22.5:
		return "→ 東"
	if ang >= 22.5 and ang < 67.5:
		return "↘ 東南"
	if ang >= 67.5 and ang < 112.5:
		return "↓ 南"
	if ang >= 112.5 and ang < 157.5:
		return "↙ 西南"
	if ang >= -67.5 and ang < -22.5:
		return "↗ 東北"
	if ang >= -112.5 and ang < -67.5:
		return "↑ 北"
	if ang >= -157.5 and ang < -112.5:
		return "↖ 西北"
	return "← 西"


func _objective_label(num: int) -> String:
	match mission_type:
		"fuel_recovery":
			return "高能燃料電池 #%d" % num
		"relay_repair":
			return "訊號中繼站 #%d" % num
		_:
			return "機密黑盒保險箱"


func _pick_recruitable_survivor(existing_ids: Array[String], rng: RandomNumberGenerator) -> Dictionary:
	var avail: Array[Dictionary] = []
	for c: Dictionary in RESCUE_CREW_POOL:
		if not existing_ids.has(str(c.get("id", ""))):
			avail.append(c)
	if avail.is_empty():
		return {}
	return avail[rng.randi_range(0, avail.size() - 1)].duplicate(true)


func _build_objective_prop(node_id: String, pos: Vector3, color: Color, is_survivor: bool = false) -> Dictionary:
	var holder: Node3D = Node3D.new()
	holder.name = "Mission_" + node_id
	holder.position = pos
	_root.add_child(holder)

	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.22
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.14, 0.0)
	ring.scale = Vector3(1.0, 0.45, 1.0)
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(color.r, color.g, color.b, 0.88)
	rmat.emission_enabled = true
	rmat.emission = color
	rmat.emission_energy_multiplier = 2.6
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rmat
	holder.add_child(ring)

	var stickman: Dictionary = {}
	if is_survivor:
		stickman = StickmanFactory.create_stickman({
			"name": "SurvivorStickman",
			"body_color": Color(0.18, 0.22, 0.26),
			"head_color": Color(0.96, 0.94, 0.88),
			"accent_color": color,
			"limb_thickness": 0.068,
			"accessory": "backpack",
		})
		var sm_root: Node3D = stickman["root"] as Node3D
		sm_root.scale = Vector3.ONE * 1.08
		holder.add_child(sm_root)
	else:
		var base_mesh: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.36
		cyl.bottom_radius = 0.44
		cyl.height = 1.15
		base_mesh.mesh = cyl
		base_mesh.position = Vector3(0.0, 0.58, 0.0)
		var bmat: StandardMaterial3D = StandardMaterial3D.new()
		bmat.albedo_color = color.darkened(0.28)
		bmat.metallic = 0.4
		bmat.roughness = 0.45
		base_mesh.material_override = bmat
		holder.add_child(base_mesh)

	var beacon: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.52
	sph.radial_segments = 6
	sph.rings = 3
	beacon.mesh = sph
	beacon.position = Vector3(0.0, 2.25 if is_survivor else 1.6, 0.0)
	var emat: StandardMaterial3D = StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.albedo_color = color
	emat.emission_enabled = true
	emat.emission = color
	emat.emission_energy_multiplier = 3.6
	beacon.material_override = emat
	holder.add_child(beacon)

	return {"node": holder, "ring": ring, "beacon": beacon, "stickman": stickman}


func _dim_objective_visual(entry: Dictionary) -> void:
	var r: MeshInstance3D = entry.get("ring", null) as MeshInstance3D
	if r != null and is_instance_valid(r):
		r.visible = false
	var b: MeshInstance3D = entry.get("beacon", null) as MeshInstance3D
	if b != null and is_instance_valid(b):
		b.visible = false


func _clear_nodes() -> void:
	objective_nodes.clear()
	survivor_node.clear()
	if _root != null and is_instance_valid(_root):
		if _root.get_parent() == self:
			remove_child(_root)
		_root.free()
	_root = null
