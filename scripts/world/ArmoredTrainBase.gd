class_name ArmoredTrainBase
extends Node3D

signal hull_hp_changed(current_hp: float, max_hp: float)
signal train_destroyed()

# Enlarged, walkable Armored Train fortress dimensions (~1.6x length, ~1.87x width, ~1.35x height = ~4x volume)
const CAR_PITCH: float = 10.6
const CAR_LEN: float = 9.6
const CAR_WIDTH: float = 5.6
const CAR_HEIGHT: float = 4.35
const DOOR_HALF_W: float = 1.55
const GANGWAY_HALF_Z: float = 1.15
const BOARDING_RADIUS: float = 3.8
const STASH_RADIUS: float = 3.8

var max_hull_hp: float = 1000.0
var hull_hp: float = 1000.0
var boarding_local_pos: Vector3 = Vector3(0.0, 0.0, 4.6)
var stash_local_pos: Vector3 = Vector3(10.6, 0.0, 4.6)
var carriage_count: int = 3

var _built: bool = false
var _tracks_root: Node3D = null
var _consist_root: Node3D = null
var _hull_bar_root: Node3D = null
var _hull_bar_fill: MeshInstance3D = null
var _hull_bar_fill_mat: StandardMaterial3D = null
var _boarding_ring: MeshInstance3D = null
var _stash_ring: MeshInstance3D = null
var _boarding_label: Label3D = null
var _stash_label: Label3D = null
var _furnace_light: OmniLight3D = null
var _headlamp_light: OmniLight3D = null
var _turret_heads: Array[Node3D] = []
var _radar_dishes: Array[Node3D] = []
var _electric_lights: Array[OmniLight3D] = []
var _cutaway_nodes: Array[Node3D] = []
var _working_npcs: Array[Dictionary] = []
var _interior_cutaway_active: bool = false
var _consist_min_x: float = -18.0
var _consist_max_x: float = 18.0
var _camera_yaw_rad: float = 0.0


func _ready() -> void:
	setup()


func setup() -> void:
	if _built:
		return
	_built = true
	_build_interactive_zones()
	_build_hull_durability_bar()
	var default_consist: TrainConsistManager = TrainConsistManager.new()
	apply_consist(default_consist)


func apply_consist(consist: TrainConsistManager) -> void:
	if not _built:
		setup()
	if consist == null:
		return

	var prev_ratio: float = get_hull_ratio()
	var stats: Dictionary = consist.compute_stats()
	max_hull_hp = float(stats.get("max_hull_hp", 1000.0))
	hull_hp = clampf(max_hull_hp * prev_ratio, 1.0 if hull_hp > 0.0 else 0.0, max_hull_hp)
	carriage_count = consist.carriages.size()

	_clear_consist_nodes()

	var total_units: int = 1 + consist.carriages.size()
	var total_span: float = float(total_units - 1) * CAR_PITCH
	var start_x: float = -total_span * 0.5
	_consist_min_x = start_x - 1.2
	_consist_max_x = start_x + total_span + CAR_LEN * 0.5

	_rebuild_railway_tracks(maxf(88.0, total_span + 30.0))

	_consist_root = Node3D.new()
	_consist_root.name = "ConsistRoot"
	add_child(_consist_root)

	# 1. Enlarged Enterable Locomotive at index 0 (west nose + walkable cab)
	var loco_x: float = start_x
	_build_locomotive_car(loco_x, consist.locomotive, stats, consist)

	# 2. Enlarged Enterable Dynamic Carriages
	var found_boarding: bool = false
	var found_stash: bool = false
	for idx in range(consist.carriages.size()):
		var car: Dictionary = consist.carriages[idx]
		var ctype: String = str(car.get("type", "flatbed"))
		var roof_mod: String = str(car.get("roof", "none"))
		var cx: float = start_x + float(idx + 1) * CAR_PITCH
		var is_last: bool = (idx == consist.carriages.size() - 1)
		_build_carriage_unit(idx, cx, car, ctype, roof_mod, is_last, consist)

		if (ctype == "boarding" or _car_has_cell(car, "boarding")) and not found_boarding:
			boarding_local_pos = Vector3(cx, 0.0, 4.6)
			found_boarding = true
		if (ctype == "cargo" or _car_has_cell(car, "cargo")) and not found_stash:
			stash_local_pos = Vector3(cx, 0.0, 4.6)
			found_stash = true

	if not found_boarding:
		boarding_local_pos = Vector3(start_x + CAR_PITCH, 0.0, 4.6)
	if not found_stash:
		stash_local_pos = Vector3(start_x + CAR_PITCH * 2.0, 0.0, 4.6)

	_apply_cutaway_visibility()
	_update_interactive_zone_positions()
	_update_hull_bar_visual()
	hull_hp_changed.emit(hull_hp, max_hull_hp)


func _clear_consist_nodes() -> void:
	_turret_heads.clear()
	_radar_dishes.clear()
	_electric_lights.clear()
	_cutaway_nodes.clear()
	_working_npcs.clear()
	_furnace_light = null
	_headlamp_light = null

	if _consist_root != null and is_instance_valid(_consist_root):
		if _consist_root.get_parent() == self:
			remove_child(_consist_root)
		_consist_root.free()
	_consist_root = null


func get_train_half_length() -> float:
	return float(1 + carriage_count) * CAR_PITCH * 0.5 + 2.4


func get_working_npc_count() -> int:
	return _working_npcs.size()


func is_interior_cutaway_active() -> bool:
	return _interior_cutaway_active


func get_interior_world_bounds() -> Rect2:
	var origin: Vector3 = global_position if is_inside_tree() else position
	return Rect2(origin.x + _consist_min_x, origin.z - (CAR_WIDTH * 0.5 - 0.25), _consist_max_x - _consist_min_x, CAR_WIDTH - 0.5)


func is_point_inside_train(world_pos: Vector3) -> bool:
	return get_interior_world_bounds().has_point(Vector2(world_pos.x, world_pos.z))


func is_point_near_or_inside_train(world_pos: Vector3) -> bool:
	var b: Rect2 = get_interior_world_bounds()
	# Expand slightly south so stepping onto the entry doorway ramp lifts the roof smoothly
	var trigger_rect: Rect2 = Rect2(b.position.x - 1.2, b.position.y - 0.8, b.size.x + 2.4, b.size.y + 2.2)
	return trigger_rect.has_point(Vector2(world_pos.x, world_pos.z))


func set_interior_cutaway(active: bool) -> void:
	if _interior_cutaway_active == active:
		return
	_interior_cutaway_active = active
	_apply_cutaway_visibility()


func _apply_cutaway_visibility() -> void:
	for n: Node3D in _cutaway_nodes:
		if is_instance_valid(n):
			n.visible = not _interior_cutaway_active


func _has_assigned_crew(slots: Array) -> bool:
	for s in slots:
		if not str(s).is_empty():
			return true
	return false


func _car_has_cell(car: Dictionary, module_name: String) -> bool:
	var cells: Array = car.get("cells", []) as Array
	for cell_raw in cells:
		if str((cell_raw as Dictionary).get("module", "")) == module_name:
			return true
	return false


func apply_hull_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var prev_hp: float = hull_hp
	hull_hp = clampf(hull_hp - amount, 0.0, max_hull_hp)
	_update_hull_bar_visual()
	hull_hp_changed.emit(hull_hp, max_hull_hp)
	if prev_hp > 0.0 and hull_hp <= 0.0:
		train_destroyed.emit()


func repair_hull(amount: float) -> void:
	if amount <= 0.0:
		return
	hull_hp = clampf(hull_hp + amount, 0.0, max_hull_hp)
	_update_hull_bar_visual()
	hull_hp_changed.emit(hull_hp, max_hull_hp)


func reset_hull() -> void:
	hull_hp = max_hull_hp
	_update_hull_bar_visual()
	hull_hp_changed.emit(hull_hp, max_hull_hp)


func get_hull_ratio() -> float:
	return clampf(hull_hp / maxf(1.0, max_hull_hp), 0.0, 1.0)


func get_boarding_world_pos() -> Vector3:
	if is_inside_tree():
		return to_global(boarding_local_pos)
	return position + boarding_local_pos


func get_stash_world_pos() -> Vector3:
	if is_inside_tree():
		return to_global(stash_local_pos)
	return position + stash_local_pos


func get_boarding_radius() -> float:
	return BOARDING_RADIUS


func get_stash_radius() -> float:
	return STASH_RADIUS


func is_player_in_boarding_zone(world_pos: Vector3) -> bool:
	var target: Vector3 = get_boarding_world_pos()
	return Vector2(world_pos.x - target.x, world_pos.z - target.z).length() <= BOARDING_RADIUS or is_point_inside_train(world_pos)


func is_player_in_stash_zone(world_pos: Vector3) -> bool:
	var target: Vector3 = get_stash_world_pos()
	return Vector2(world_pos.x - target.x, world_pos.z - target.z).length() <= STASH_RADIUS


func get_turret_world_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for th: Node3D in _turret_heads:
		if is_instance_valid(th):
			if th.is_inside_tree():
				positions.append(th.global_position + Vector3(0.0, 0.35, 0.0))
			else:
				positions.append(position + th.position + Vector3(0.0, 0.35, 0.0))
	return positions


func aim_turret_at(turret_index: int, target_world_pos: Vector3) -> void:
	if turret_index < 0 or turret_index >= _turret_heads.size():
		return
	var th: Node3D = _turret_heads[turret_index]
	if is_instance_valid(th) and th.is_inside_tree():
		var to_t: Vector3 = target_world_pos - th.global_position
		if Vector2(to_t.x, to_t.z).length_squared() > 0.01:
			th.rotation.y = atan2(to_t.x, to_t.z)


func has_tesla_fence() -> bool:
	return not _electric_lights.is_empty()


func get_interactive_zones() -> Array[Dictionary]:
	return [
		{
			"id": "train_stash",
			"kind": "train_stash",
			"label": "裝甲列車暫存倉",
			"pos": get_stash_world_pos(),
			"radius": STASH_RADIUS,
		},
		{
			"id": "boarding_zone",
			"kind": "boarding_zone",
			"label": "裝甲列車登車區（藍圖整備）",
			"pos": get_boarding_world_pos(),
			"radius": BOARDING_RADIUS,
		},
	]


func set_camera_yaw(yaw_rad: float) -> void:
	_camera_yaw_rad = yaw_rad
	if _hull_bar_root != null and is_instance_valid(_hull_bar_root):
		_hull_bar_root.rotation = Vector3(deg_to_rad(-28.0), _camera_yaw_rad, 0.0)
	if _boarding_label != null and is_instance_valid(_boarding_label):
		_boarding_label.rotation = Vector3(deg_to_rad(-24.0), _camera_yaw_rad, 0.0)
	if _stash_label != null and is_instance_valid(_stash_label):
		_stash_label.rotation = Vector3(deg_to_rad(-24.0), _camera_yaw_rad, 0.0)
	for npc: Dictionary in _working_npcs:
		var lbl: Label3D = npc.get("label", null) as Label3D
		if lbl != null and is_instance_valid(lbl):
			lbl.rotation = Vector3(deg_to_rad(-24.0), _camera_yaw_rad, 0.0)


func animate_train(time_elapsed: float) -> void:
	if _furnace_light != null and is_instance_valid(_furnace_light):
		_furnace_light.light_energy = 3.8 + sin(time_elapsed * 5.2) * 0.55 + sin(time_elapsed * 13.0) * 0.2
	if _boarding_ring != null and is_instance_valid(_boarding_ring):
		var b_pulse: float = 1.0 + sin(time_elapsed * 2.4) * 0.03
		_boarding_ring.scale = Vector3(b_pulse, 0.45, b_pulse)
	if _stash_ring != null and is_instance_valid(_stash_ring):
		var s_pulse: float = 1.0 + sin(time_elapsed * 2.4 + 1.4) * 0.03
		_stash_ring.scale = Vector3(s_pulse, 0.45, s_pulse)

	for i in range(_turret_heads.size()):
		var th: Node3D = _turret_heads[i]
		if is_instance_valid(th):
			th.rotation.y = sin(time_elapsed * 0.85 + float(i) * 1.7) * 0.75

	for i in range(_radar_dishes.size()):
		var rd: Node3D = _radar_dishes[i]
		if is_instance_valid(rd):
			rd.rotation.y = fmod(time_elapsed * 1.6 + float(i), TAU)

	for i in range(_electric_lights.size()):
		var el: OmniLight3D = _electric_lights[i]
		if is_instance_valid(el):
			el.light_energy = 2.4 + absf(sin(time_elapsed * 7.5 + float(i) * 2.1)) * 1.8

	# Animate all working Stickman NPCs inside the train!
	for i in range(_working_npcs.size()):
		var npc: Dictionary = _working_npcs[i]
		var rig_root: Node3D = npc.get("root", null) as Node3D
		if rig_root == null or not is_instance_valid(rig_root):
			continue
		var phase: float = time_elapsed + float(i) * 1.37
		var style: String = str(npc.get("style", "console"))
		var base_pos: Vector3 = npc.get("base_pos", Vector3.ZERO) as Vector3
		var base_yaw: float = float(npc.get("base_yaw", 0.0))
		var torso: Node3D = npc.get("torso", null) as Node3D
		var head: Node3D = npc.get("head", null) as Node3D
		var la: Node3D = npc.get("left_arm", null) as Node3D
		var ra: Node3D = npc.get("right_arm", null) as Node3D
		var ll: Node3D = npc.get("left_leg", null) as Node3D
		var rl: Node3D = npc.get("right_leg", null) as Node3D

		match style:
			"hammer":
				# Wrenching / stoking boiler / welding armor!
				if ra != null:
					ra.rotation_degrees.x = 65.0 + sin(phase * 7.5) * 42.0
				if la != null:
					la.rotation_degrees.x = 42.0 + sin(phase * 3.8) * 12.0
				if torso != null:
					torso.rotation_degrees.x = -8.0 + sin(phase * 7.5) * 6.0
				if head != null:
					head.rotation_degrees.x = 10.0 + sin(phase * 3.5) * 5.0
			"patrol":
				# Inspecting crates / walking between interior workstations!
				var walk_t: float = sin(phase * 0.95)
				var walk_v: float = cos(phase * 0.95)
				rig_root.position.x = base_pos.x + walk_t * 1.25
				rig_root.rotation.y = -PI * 0.5 if walk_v >= 0.0 else PI * 0.5
				var step: float = sin(phase * 6.2)
				if ll != null and rl != null:
					ll.rotation.x = step * 0.48
					rl.rotation.x = -step * 0.48
				if la != null and ra != null:
					la.rotation_degrees.x = 58.0
					ra.rotation.x = -step * 0.32
			_:
				# Console operation / radar tracking / medical desk typing!
				rig_root.rotation.y = base_yaw + sin(phase * 1.1) * 0.14
				if la != null:
					la.rotation_degrees.x = 68.0 + sin(phase * 9.0) * 16.0
				if ra != null:
					ra.rotation_degrees.x = 68.0 + cos(phase * 8.4) * 16.0
				if head != null:
					head.rotation_degrees.y = sin(phase * 1.9) * 18.0


func play_stash_deposit_fx() -> void:
	if not is_inside_tree():
		return
	var pulse: MeshInstance3D = MeshInstance3D.new()
	pulse.name = "StashDepositPulse"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.45
	torus.outer_radius = 1.65
	torus.rings = 24
	torus.ring_segments = 8
	pulse.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.84, 0.30, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.22)
	mat.emission_energy_multiplier = 3.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse.material_override = mat
	pulse.position = stash_local_pos + Vector3(0.0, 0.22, 0.0)
	add_child(pulse)

	var tw: Tween = pulse.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pulse, "position:y", 2.2, 0.42)
	tw.tween_property(pulse, "scale", Vector3(1.65, 0.6, 1.65), 0.42)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tw.chain().tween_callback(pulse.queue_free)


func _make_mat(color: Color, metallic: float = 0.45, roughness: float = 0.55, emission: Color = Color.BLACK, emit_energy: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emit_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emit_energy
	return mat


func _add_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _add_cyl(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _add_wall_collider(parent: Node3D, node_name: String, size: Vector3, pos: Vector3) -> void:
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


func _rebuild_railway_tracks(track_len: float) -> void:
	if _tracks_root != null and is_instance_valid(_tracks_root):
		if _tracks_root.get_parent() == self:
			remove_child(_tracks_root)
		_tracks_root.free()
	_tracks_root = Node3D.new()
	_tracks_root.name = "RailwayTracks"
	add_child(_tracks_root)

	var tie_mat: StandardMaterial3D = _make_mat(Color(0.24, 0.19, 0.15), 0.05, 0.90)
	var rail_mat: StandardMaterial3D = _make_mat(Color(0.46, 0.49, 0.54), 0.82, 0.34)
	var ballast_mat: StandardMaterial3D = _make_mat(Color(0.20, 0.19, 0.18), 0.0, 0.95)

	_add_box(_tracks_root, "BallastBed", Vector3(track_len, 0.08, 6.2), Vector3(0.0, 0.04, 0.0), ballast_mat)
	_add_box(_tracks_root, "RailNorth", Vector3(track_len, 0.12, 0.22), Vector3(0.0, 0.08, -2.15), rail_mat)
	_add_box(_tracks_root, "RailSouth", Vector3(track_len, 0.12, 0.22), Vector3(0.0, 0.08, 2.15), rail_mat)

	var half_ties: int = int(ceil(track_len * 0.5))
	for i in range(-half_ties, half_ties + 1, 2):
		_add_box(_tracks_root, "Tie_%d" % i, Vector3(0.38, 0.06, 5.4), Vector3(float(i), 0.06, 0.0), tie_mat)


func _build_locomotive_car(cx: float, loco_cfg: Dictionary, stats: Dictionary, consist: TrainConsistManager) -> void:
	var boiler_lv: int = int(loco_cfg.get("boiler_level", 1))
	var armor_lv: int = int(loco_cfg.get("armor_level", 1))
	var lamp_lv: int = int(loco_cfg.get("headlamp_level", 1))

	var loco: Node3D = Node3D.new()
	loco.name = "LocomotiveCar"
	loco.position = Vector3(cx, 0.0, 0.0)
	_consist_root.add_child(loco)

	var armor_dark: StandardMaterial3D = _make_mat(Color(0.18, 0.21, 0.25), 0.62, 0.46)
	var armor_mid: StandardMaterial3D = _make_mat(Color(0.25, 0.29, 0.34), 0.58, 0.48)
	var floor_mat: StandardMaterial3D = _make_mat(Color(0.28, 0.24, 0.20), 0.35, 0.72)
	var brass_mat: StandardMaterial3D = _make_mat(Color(0.76, 0.58, 0.26), 0.75, 0.35)
	var hazard_mat: StandardMaterial3D = _make_mat(Color(0.92, 0.62, 0.14), 0.22, 0.52)
	var steel_mat: StandardMaterial3D = _make_mat(Color(0.36, 0.39, 0.44), 0.78, 0.36)
	var furnace_mat: StandardMaterial3D = _make_mat(Color(1.0, 0.46, 0.14), 0.1, 0.3, Color(1.0, 0.42, 0.10), 3.2 + float(boiler_lv) * 0.75)
	var headlamp_mat: StandardMaterial3D = _make_mat(Color(1.0, 0.95, 0.78), 0.1, 0.2, Color(1.0, 0.92, 0.70), 3.8 + float(lamp_lv) * 0.8)

	# Heavy undercarriage wheels outside the walls
	for wx in [-3.8, -1.6, 1.0, 3.4]:
		_add_cyl(loco, "WheelN_%d" % int(wx * 10), 0.68, 0.28, Vector3(wx, 0.68, -2.75), steel_mat, Vector3(90.0, 0.0, 0.0))
		_add_cyl(loco, "WheelS_%d" % int(wx * 10), 0.68, 0.28, Vector3(wx, 0.68, 2.75), steel_mat, Vector3(90.0, 0.0, 0.0))

	# Front Steam Boiler & Massive Snowplow (solid front half x = -4.8..-0.6)
	_add_box(loco, "BoilerBase", Vector3(4.6, 2.8, 5.2), Vector3(-2.6, 1.45, 0.0), armor_mid)
	_add_cyl(loco, "BoilerDrum", 1.85, 4.5, Vector3(-2.6, 3.05, 0.0), armor_dark, Vector3(0.0, 0.0, 90.0))
	_add_wall_collider(loco, "BoilerSolidCol", Vector3(5.6, 4.4, 5.6), Vector3(-2.8, 2.2, 0.0))

	# Smokestacks & Boiler Upgrade Tiers
	_add_cyl(loco, "SmokestackMain", 0.52, 1.8 + float(boiler_lv - 1) * 0.3, Vector3(-3.8, 5.2, 0.0), steel_mat)
	_add_cyl(loco, "SmokestackRim", 0.66, 0.28, Vector3(-3.8, 6.1 + float(boiler_lv - 1) * 0.18, 0.0), brass_mat)
	if boiler_lv >= 2:
		_add_cyl(loco, "TwinStack", 0.36, 1.55, Vector3(-1.9, 5.05, 0.0), steel_mat)
	if boiler_lv >= 3:
		_add_box(loco, "BoilerCoreGlowS", Vector3(3.2, 0.34, 0.16), Vector3(-2.5, 3.1, 2.66), furnace_mat)

	var plow_scale: float = 1.0 + float(armor_lv - 1) * 0.16
	_add_box(loco, "SnowplowCore", Vector3(2.2 * plow_scale, 2.1, 5.3), Vector3(-5.6, 1.25, 0.0), steel_mat, Vector3(0.0, 0.0, 26.0))
	_add_box(loco, "SnowplowBlade", Vector3(0.40, 2.0, 5.75), Vector3(-6.45 - float(armor_lv - 1) * 0.16, 0.98, 0.0), hazard_mat, Vector3(0.0, 0.0, 32.0))
	_add_cyl(loco, "HeadlampLens", 0.45 + float(lamp_lv - 1) * 0.06, 0.24, Vector3(-4.95, 3.55, 0.0), headlamp_mat, Vector3(0.0, 0.0, 90.0))

	# Walkable Enlarged Locomotive Cab (x = -0.3 .. +4.8, z = -2.8 .. +2.8)
	_add_box(loco, "CabFloor", Vector3(5.2, 0.10, CAR_WIDTH - 0.15), Vector3(2.25, 0.05, 0.0), floor_mat)
	# North solid wall
	_add_box(loco, "CabNorthWall", Vector3(5.2, CAR_HEIGHT, 0.24), Vector3(2.25, CAR_HEIGHT * 0.5, -2.72), armor_dark)
	_add_wall_collider(loco, "CabNorthCol", Vector3(5.2, CAR_HEIGHT, 0.30), Vector3(2.25, CAR_HEIGHT * 0.5, -2.72))
	# East bulkhead with open center gangway into Carriage #1!
	_add_box(loco, "CabEastN", Vector3(0.24, CAR_HEIGHT, 1.65), Vector3(4.78, CAR_HEIGHT * 0.5, -1.98), armor_dark)
	_add_box(loco, "CabEastS", Vector3(0.24, CAR_HEIGHT, 1.65), Vector3(4.78, CAR_HEIGHT * 0.5, 1.98), armor_dark)
	_add_wall_collider(loco, "CabEastNCol", Vector3(0.30, CAR_HEIGHT, 1.65), Vector3(4.78, CAR_HEIGHT * 0.5, -1.98))
	_add_wall_collider(loco, "CabEastSCol", Vector3(0.30, CAR_HEIGHT, 1.65), Vector3(4.78, CAR_HEIGHT * 0.5, 1.98))
	# South wall with open doorway at x = 2.25 (width 2.8m)
	_add_box(loco, "CabSouthL", Vector3(1.25, 1.5, 0.24), Vector3(0.25, 0.75, 2.72), armor_dark)
	_add_box(loco, "CabSouthR", Vector3(1.25, 1.5, 0.24), Vector3(4.25, 0.75, 2.72), armor_dark)
	_add_wall_collider(loco, "CabSouthLCol", Vector3(1.25, CAR_HEIGHT, 0.30), Vector3(0.25, CAR_HEIGHT * 0.5, 2.72))
	_add_wall_collider(loco, "CabSouthRCol", Vector3(1.25, CAR_HEIGHT, 0.30), Vector3(4.25, CAR_HEIGHT * 0.5, 2.72))
	_add_box(loco, "CabEntryRamp", Vector3(2.7, 0.08, 1.15), Vector3(2.25, 0.04, 3.25), steel_mat)

	# Interior Locomotive Workstations (Visible when roof lifts!)
	_add_box(loco, "FireboxFrame", Vector3(0.55, 2.1, 2.2), Vector3(-0.08, 1.05, -0.4), armor_mid)
	_add_box(loco, "FireboxGlow", Vector3(0.24, 1.05, 1.4), Vector3(0.18, 0.95, -0.4), furnace_mat)
	_add_box(loco, "ThrottleConsole", Vector3(1.6, 1.15, 0.85), Vector3(2.1, 0.58, -1.85), brass_mat)
	_add_box(loco, "CoalBunker", Vector3(1.2, 0.85, 1.1), Vector3(3.6, 0.42, -1.95), armor_dark)
	_add_light(loco, "CabInteriorWarmLight", Color(1.0, 0.72, 0.36), 3.4, 9.5, Vector3(2.2, 3.4, 0.0))

	# Cutaway Roof & South Upper Trim
	var cab_cutaway: Node3D = Node3D.new()
	cab_cutaway.name = "CabRoofCutaway"
	loco.add_child(cab_cutaway)
	_add_box(cab_cutaway, "CabRoof", Vector3(5.5, 0.30, CAR_WIDTH + 0.35), Vector3(2.25, CAR_HEIGHT + 0.15, 0.0), steel_mat)
	_add_box(cab_cutaway, "CabSouthUpperL", Vector3(1.25, CAR_HEIGHT - 1.5, 0.24), Vector3(0.25, 1.5 + (CAR_HEIGHT - 1.5) * 0.5, 2.72), armor_dark)
	_add_box(cab_cutaway, "CabSouthUpperR", Vector3(1.25, CAR_HEIGHT - 1.5, 0.24), Vector3(4.25, 1.5 + (CAR_HEIGHT - 1.5) * 0.5, 2.72), armor_dark)
	_add_box(cab_cutaway, "CabDoorHeader", Vector3(2.8, 1.25, 0.28), Vector3(2.25, CAR_HEIGHT - 0.62, 2.72), hazard_mat)
	_cutaway_nodes.append(cab_cutaway)

	# Working Stickman Engineer inside Locomotive Cab!
	var loco_crew_name: String = "鍋爐輪機師"
	var loco_slots: Array = loco_cfg.get("crew_slots", []) as Array
	for cid in loco_slots:
		if not str(cid).is_empty():
			var cd: Dictionary = consist.get_crew_by_id(str(cid))
			if not cd.is_empty():
				loco_crew_name = str(cd.get("short_name", loco_crew_name))
				break
	_spawn_working_npc(loco, Vector3(1.25, 0.10, -0.55), PI * 0.5, "mechanic", loco_crew_name, "加煤調壓", "hammer")

	_furnace_light = OmniLight3D.new()
	_furnace_light.name = "LocomotiveFurnaceGlow"
	_furnace_light.light_color = Color(1.0, 0.50, 0.18)
	_furnace_light.light_energy = 3.6
	_furnace_light.omni_range = 10.5
	_furnace_light.position = Vector3(-1.4, 2.2, 3.0)
	loco.add_child(_furnace_light)

	_headlamp_light = OmniLight3D.new()
	_headlamp_light.name = "LocomotiveHeadlamp"
	_headlamp_light.light_color = Color(1.0, 0.93, 0.74)
	_headlamp_light.light_energy = float(stats.get("headlamp_energy", 3.4))
	_headlamp_light.omni_range = float(stats.get("headlamp_range", 18.0))
	_headlamp_light.position = Vector3(-7.0, 3.0, 0.4)
	loco.add_child(_headlamp_light)


func _build_carriage_unit(idx: int, cx: float, car_data: Dictionary, ctype: String, roof_mod: String, is_last: bool, consist: TrainConsistManager) -> void:
	var car: Node3D = Node3D.new()
	car.name = "Carriage_%02d_%s" % [idx + 1, ctype]
	car.position = Vector3(cx, 0.0, 0.0)
	_consist_root.add_child(car)

	var armor_dark: StandardMaterial3D = _make_mat(Color(0.20, 0.24, 0.29), 0.60, 0.46)
	var steel_mat: StandardMaterial3D = _make_mat(Color(0.38, 0.42, 0.48), 0.76, 0.38)
	var hazard_mat: StandardMaterial3D = _make_mat(Color(0.95, 0.70, 0.18), 0.25, 0.48)
	var wood_floor: StandardMaterial3D = _make_mat(Color(0.34, 0.27, 0.20), 0.15, 0.80)
	var body_mat: StandardMaterial3D = _carriage_wall_material(ctype)

	# Walkable steel gangway bridge connecting to West unit
	_add_box(car, "GangwayFloorWest", Vector3(1.25, 0.10, 2.35), Vector3(-CAR_PITCH * 0.5, 0.05, 0.0), steel_mat)
	# Spacious flush interior floor deck (y = 0.05)
	_add_box(car, "InteriorFloor", Vector3(CAR_LEN, 0.10, CAR_WIDTH - 0.14), Vector3(0.0, 0.05, 0.0), wood_floor)
	# Heavy external bogie wheels
	for wx in [-3.4, -2.0, 2.0, 3.4]:
		_add_cyl(car, "WheelN_%d" % int(wx * 10), 0.62, 0.26, Vector3(wx, 0.62, -2.78), steel_mat, Vector3(90.0, 0.0, 0.0))
		_add_cyl(car, "WheelS_%d" % int(wx * 10), 0.62, 0.26, Vector3(wx, 0.62, 2.78), steel_mat, Vector3(90.0, 0.0, 0.0))

	# Segmented Hollow Perimeter Walls + Colliders (Enterable from South Door AND West/East Gangways!)
	var half_l: float = CAR_LEN * 0.5
	var half_w: float = CAR_WIDTH * 0.5
	var side_seg_len: float = (CAR_LEN - DOOR_HALF_W * 2.0) * 0.5
	var side_seg_x: float = DOOR_HALF_W + side_seg_len * 0.5
	var end_seg_w: float = (CAR_WIDTH - GANGWAY_HALF_Z * 2.0) * 0.5
	var end_seg_z: float = GANGWAY_HALF_Z + end_seg_w * 0.5

	# North full wall
	_add_box(car, "NorthWall", Vector3(CAR_LEN, CAR_HEIGHT, 0.24), Vector3(0.0, CAR_HEIGHT * 0.5, -half_w + 0.12), body_mat)
	_add_wall_collider(car, "NorthWallCol", Vector3(CAR_LEN, CAR_HEIGHT, 0.30), Vector3(0.0, CAR_HEIGHT * 0.5, -half_w + 0.12))

	# South lower wall skirt (always visible, leaves wide 3.1m open doorway!)
	_add_box(car, "SouthLowerL", Vector3(side_seg_len, 1.35, 0.24), Vector3(-side_seg_x, 0.68, half_w - 0.12), body_mat)
	_add_box(car, "SouthLowerR", Vector3(side_seg_len, 1.35, 0.24), Vector3(side_seg_x, 0.68, half_w - 0.12), body_mat)
	_add_wall_collider(car, "SouthWallLCol", Vector3(side_seg_len, CAR_HEIGHT, 0.30), Vector3(-side_seg_x, CAR_HEIGHT * 0.5, half_w - 0.12))
	_add_wall_collider(car, "SouthWallRCol", Vector3(side_seg_len, CAR_HEIGHT, 0.30), Vector3(side_seg_x, CAR_HEIGHT * 0.5, half_w - 0.12))

	# South open entry threshold ramp
	var trim_col: Color = _carriage_accent_color(ctype)
	var strip_mat: StandardMaterial3D = _make_mat(trim_col, 0.1, 0.2, trim_col, 2.8)
	_add_box(car, "EntryRamp", Vector3(DOOR_HALF_W * 2.0, 0.08, 1.35), Vector3(0.0, 0.04, half_w + 0.62), steel_mat)
	_add_box(car, "EntryThresholdGlow", Vector3(DOOR_HALF_W * 2.0, 0.06, 0.14), Vector3(0.0, 0.10, half_w - 0.04), strip_mat)

	# West end bulkhead (always open central gangway!)
	_add_box(car, "WestEndN", Vector3(0.24, CAR_HEIGHT, end_seg_w), Vector3(-half_l + 0.12, CAR_HEIGHT * 0.5, -end_seg_z), body_mat)
	_add_box(car, "WestEndS", Vector3(0.24, CAR_HEIGHT, end_seg_w), Vector3(-half_l + 0.12, CAR_HEIGHT * 0.5, end_seg_z), body_mat)
	_add_wall_collider(car, "WestEndNCol", Vector3(0.30, CAR_HEIGHT, end_seg_w), Vector3(-half_l + 0.12, CAR_HEIGHT * 0.5, -end_seg_z))
	_add_wall_collider(car, "WestEndSCol", Vector3(0.30, CAR_HEIGHT, end_seg_w), Vector3(-half_l + 0.12, CAR_HEIGHT * 0.5, end_seg_z))

	# East end bulkhead (solid closed wall on the last carriage; open gangway otherwise)
	if is_last:
		_add_box(car, "EastRearWall", Vector3(0.26, CAR_HEIGHT, CAR_WIDTH), Vector3(half_l - 0.12, CAR_HEIGHT * 0.5, 0.0), armor_dark)
		_add_wall_collider(car, "EastRearCol", Vector3(0.32, CAR_HEIGHT, CAR_WIDTH), Vector3(half_l - 0.12, CAR_HEIGHT * 0.5, 0.0))
	else:
		_add_box(car, "EastEndN", Vector3(0.24, CAR_HEIGHT, end_seg_w), Vector3(half_l - 0.12, CAR_HEIGHT * 0.5, -end_seg_z), body_mat)
		_add_box(car, "EastEndS", Vector3(0.24, CAR_HEIGHT, end_seg_w), Vector3(half_l - 0.12, CAR_HEIGHT * 0.5, end_seg_z), body_mat)
		_add_wall_collider(car, "EastEndNCol", Vector3(0.30, CAR_HEIGHT, end_seg_w), Vector3(half_l - 0.12, CAR_HEIGHT * 0.5, -end_seg_z))
		_add_wall_collider(car, "EastEndSCol", Vector3(0.30, CAR_HEIGHT, end_seg_w), Vector3(half_l - 0.12, CAR_HEIGHT * 0.5, end_seg_z))

	# Warm interior lighting so walking inside feels bright & cozy
	_add_light(car, "InteriorCeilingLight", Color(1.0, 0.88, 0.68), 2.8, 10.5, Vector3(0.0, 3.6, 0.0))

	# Interior Furnishings + Animated Working Stickman NPCs!
	_populate_carriage_interior_and_npcs(car, idx, car_data, ctype, consist)

	# Cutaway Roof + South Upper Facade (hides automatically when player approaches/enters!)
	var cutaway_group: Node3D = Node3D.new()
	cutaway_group.name = "RoofCutaway"
	car.add_child(cutaway_group)
	_add_box(cutaway_group, "CarRoofSlab", Vector3(CAR_LEN + 0.35, 0.28, CAR_WIDTH + 0.30), Vector3(0.0, CAR_HEIGHT + 0.14, 0.0), armor_dark)
	_add_box(cutaway_group, "SouthUpperL", Vector3(side_seg_len, CAR_HEIGHT - 1.35, 0.24), Vector3(-side_seg_x, 1.35 + (CAR_HEIGHT - 1.35) * 0.5, half_w - 0.12), body_mat)
	_add_box(cutaway_group, "SouthUpperR", Vector3(side_seg_len, CAR_HEIGHT - 1.35, 0.24), Vector3(side_seg_x, 1.35 + (CAR_HEIGHT - 1.35) * 0.5, half_w - 0.12), body_mat)
	_add_box(cutaway_group, "SouthDoorHeader", Vector3(DOOR_HALF_W * 2.0 + 0.2, 1.15, 0.28), Vector3(0.0, CAR_HEIGHT - 0.58, half_w - 0.12), armor_dark)
	_add_box(cutaway_group, "SouthLightStrip", Vector3(DOOR_HALF_W * 2.0 + 0.2, 0.16, 0.32), Vector3(0.0, CAR_HEIGHT - 1.15, half_w - 0.06), strip_mat)
	_add_box(cutaway_group, "HazardStripeS", Vector3(side_seg_len - 0.2, 0.24, 0.10), Vector3(-side_seg_x, 1.55, half_w + 0.02), hazard_mat)
	_add_box(cutaway_group, "HazardStripeSR", Vector3(side_seg_len - 0.2, 0.24, 0.10), Vector3(side_seg_x, 1.55, half_w + 0.02), hazard_mat)
	_cutaway_nodes.append(cutaway_group)

	# Modular Roof Hardpoint Attachment (mounted cleanly above roofline)
	var roof_y: float = CAR_HEIGHT + 0.30
	match roof_mod:
		"turret":
			var red_glow: StandardMaterial3D = _make_mat(Color(1.0, 0.36, 0.26), 0.1, 0.2, Color(1.0, 0.32, 0.22), 3.4)
			var turret_mount: Node3D = Node3D.new()
			turret_mount.name = "RoofTurretMount"
			car.add_child(turret_mount)
			_add_cyl(turret_mount, "TurretPedestal", 1.35, 0.50, Vector3(0.0, roof_y + 0.22, -1.6), steel_mat)
			var turret_head: Node3D = Node3D.new()
			turret_head.name = "RoofTurretHead"
			turret_head.position = Vector3(0.0, roof_y + 0.72, -1.6)
			turret_mount.add_child(turret_head)
			_add_box(turret_head, "TurretHousing", Vector3(1.8, 0.92, 1.95), Vector3(0.0, 0.18, 0.0), armor_dark)
			_add_box(turret_head, "TurretOptic", Vector3(0.42, 0.24, 0.18), Vector3(0.0, 0.45, 0.98), red_glow)
			_add_cyl(turret_head, "BarrelL", 0.12, 2.55, Vector3(-0.35, 0.18, 1.88), steel_mat, Vector3(90.0, 0.0, 0.0))
			_add_cyl(turret_head, "BarrelR", 0.12, 2.55, Vector3(0.35, 0.18, 1.88), steel_mat, Vector3(90.0, 0.0, 0.0))
			_turret_heads.append(turret_head)
		"radar":
			var cyan_glow: StandardMaterial3D = _make_mat(Color(0.38, 0.88, 1.0), 0.1, 0.2, Color(0.38, 0.88, 1.0), 3.2)
			_add_cyl(cutaway_group, "RadioMast", 0.12, 2.6, Vector3(-2.4, roof_y + 1.25, -0.6), steel_mat)
			_add_box(cutaway_group, "MastBeacon", Vector3(0.30, 0.30, 0.30), Vector3(-2.4, roof_y + 2.6, -0.6), cyan_glow)
			var radar: Node3D = Node3D.new()
			radar.name = "RadarDish"
			radar.position = Vector3(0.6, roof_y + 0.55, 0.0)
			cutaway_group.add_child(radar)
			_add_cyl(radar, "RadarPost", 0.20, 1.0, Vector3(0.0, -0.15, 0.0), steel_mat)
			_add_box(radar, "RadarArray", Vector3(2.4, 1.05, 0.22), Vector3(0.0, 0.45, 0.22), steel_mat, Vector3(-18.0, 0.0, 0.0))
			_add_box(radar, "RadarCore", Vector3(0.32, 0.32, 0.42), Vector3(0.0, 0.45, 0.55), cyan_glow)
			_radar_dishes.append(radar)
		"tesla":
			var coil_mat: StandardMaterial3D = _make_mat(Color(0.84, 0.48, 0.22), 0.78, 0.32)
			var arc_glow: StandardMaterial3D = _make_mat(Color(0.36, 0.94, 1.0), 0.1, 0.2, Color(0.32, 0.90, 1.0), 3.8)
			for gx in [-2.2, 2.2]:
				_add_cyl(cutaway_group, "TeslaCoil_%d" % int(gx * 10), 0.52, 1.6, Vector3(gx, roof_y + 0.8, 0.0), coil_mat)
				_add_cyl(cutaway_group, "TeslaRing_%d" % int(gx * 10), 0.72, 0.20, Vector3(gx, roof_y + 1.5, 0.0), arc_glow)
			var el: OmniLight3D = _add_light(car, "GenArcLight", Color(0.36, 0.92, 1.0), 2.8, 10.0, Vector3(0.0, roof_y + 1.1, 2.0))
			_electric_lights.append(el)
		"shield":
			_add_box(cutaway_group, "RoofArmorShield", Vector3(CAR_LEN - 0.4, 0.55, CAR_WIDTH + 0.2), Vector3(0.0, roof_y + 0.28, 0.0), hazard_mat)


func _populate_carriage_interior_and_npcs(car: Node3D, _idx: int, car_data: Dictionary, ctype: String, consist: TrainConsistManager) -> void:
	var desk_mat: StandardMaterial3D = _make_mat(Color(0.36, 0.30, 0.24), 0.25, 0.65)
	var steel_mat: StandardMaterial3D = _make_mat(Color(0.42, 0.46, 0.52), 0.72, 0.38)
	var crate_mat: StandardMaterial3D = _make_mat(Color(0.76, 0.56, 0.24), 0.15, 0.75)
	var screen_cyan: StandardMaterial3D = _make_mat(Color(0.34, 0.92, 1.0), 0.1, 0.2, Color(0.34, 0.92, 1.0), 2.6)
	var screen_green: StandardMaterial3D = _make_mat(Color(0.30, 0.96, 0.58), 0.1, 0.2, Color(0.30, 0.96, 0.58), 2.6)
	var screen_amber: StandardMaterial3D = _make_mat(Color(1.0, 0.72, 0.24), 0.1, 0.2, Color(1.0, 0.72, 0.24), 2.6)

	# Collect assigned crew names from cells (if any)
	var assigned_crew: Array[Dictionary] = []
	for cell_raw in (car_data.get("cells", []) as Array):
		var cid: String = str((cell_raw as Dictionary).get("crew_id", ""))
		if not cid.is_empty():
			var cd: Dictionary = consist.get_crew_by_id(cid)
			if not cd.is_empty():
				assigned_crew.append(cd)

	match ctype:
		"boarding":
			# Command Briefing Table + Bunk Bed + Tactical Console
			_add_box(car, "BriefingTable", Vector3(2.4, 0.92, 1.15), Vector3(-2.4, 0.46, -1.75), desk_mat)
			_add_box(car, "HoloMap", Vector3(1.5, 0.08, 0.80), Vector3(-2.4, 0.96, -1.75), screen_cyan)
			_add_box(car, "BunkFrame", Vector3(2.2, 0.72, 1.05), Vector3(2.5, 0.36, -1.85), steel_mat)
			_add_box(car, "BunkMattress", Vector3(2.0, 0.20, 0.92), Vector3(2.5, 0.78, -1.85), _make_mat(Color(0.84, 0.78, 0.66), 0.0, 0.9))
			var n1: String = str(assigned_crew[0].get("short_name", "調度員")) if assigned_crew.size() >= 1 else "調度員"
			_spawn_working_npc(car, Vector3(-2.4, 0.10, -0.75), 0.0, "scout", n1, "戰術簡報", "console")
		"cargo":
			# Storage Racks + Stacked Supply Crates + Inventory Desk
			_add_box(car, "CargoCrateBig1", Vector3(1.3, 1.15, 1.1), Vector3(-3.0, 0.58, -1.85), crate_mat)
			_add_box(car, "CargoCrateBig2", Vector3(1.1, 0.95, 1.0), Vector3(-1.6, 0.48, -1.9), crate_mat)
			_add_box(car, "CargoCrateTop", Vector3(0.95, 0.75, 0.85), Vector3(-2.8, 1.52, -1.85), _make_mat(Color(0.58, 0.40, 0.22), 0.1, 0.8))
			_add_box(car, "InventoryTerminal", Vector3(1.6, 1.05, 0.85), Vector3(2.6, 0.52, -1.9), steel_mat)
			_add_box(car, "InventoryScreen", Vector3(1.1, 0.45, 0.10), Vector3(2.6, 1.25, -2.25), screen_amber)
			var qm_name: String = str(assigned_crew[0].get("short_name", "倉管員")) if assigned_crew.size() >= 1 else "倉管員"
			_spawn_working_npc(car, Vector3(0.4, 0.10, -1.1), 0.0, "quartermaster", qm_name, "清點物資", "patrol")
		"turret":
			# Fire Control Console + Ammo Drum Rack + Repair Bench
			_add_box(car, "FireControlDesk", Vector3(2.6, 1.05, 1.0), Vector3(-2.1, 0.52, -1.85), steel_mat)
			_add_box(car, "RadarMonitor", Vector3(1.6, 0.55, 0.12), Vector3(-2.1, 1.32, -2.28), screen_cyan)
			_add_cyl(car, "AmmoDrum1", 0.48, 1.1, Vector3(2.4, 0.55, -1.85), crate_mat)
			_add_cyl(car, "AmmoDrum2", 0.48, 1.1, Vector3(3.4, 0.55, -1.85), crate_mat)
			var g_name: String = str(assigned_crew[0].get("short_name", "砲塔射手")) if assigned_crew.size() >= 1 else "砲塔射手"
			_spawn_working_npc(car, Vector3(-2.1, 0.10, -0.9), 0.0, "gunner", g_name, "砲塔射控", "console")
			_spawn_working_npc(car, Vector3(2.5, 0.10, -0.9), 0.0, "mechanic", "彈藥裝填手", "裝填彈鼓", "hammer")
		"medbay":
			# Medical Bed + Vitals Monitor + Cabinet
			_add_box(car, "MedBed", Vector3(2.4, 0.82, 1.15), Vector3(-2.2, 0.41, -1.8), _make_mat(Color(0.90, 0.94, 0.96), 0.1, 0.6))
			_add_box(car, "MedConsole", Vector3(1.5, 1.05, 0.85), Vector3(2.2, 0.52, -1.85), steel_mat)
			_add_box(car, "VitalsScreen", Vector3(1.1, 0.50, 0.10), Vector3(2.2, 1.30, -2.2), screen_green)
			var m_name: String = str(assigned_crew[0].get("short_name", "軍醫")) if assigned_crew.size() >= 1 else "軍醫"
			_spawn_working_npc(car, Vector3(2.2, 0.10, -0.9), 0.0, "medic", m_name, "配置藥劑", "console")
		"armory":
			_add_box(car, "WorkBench", Vector3(2.8, 0.96, 1.0), Vector3(-2.0, 0.48, -1.85), steel_mat)
			_add_box(car, "ToolGlow", Vector3(1.2, 0.18, 0.4), Vector3(-2.0, 1.05, -1.85), screen_amber)
			var a_name: String = str(assigned_crew[0].get("short_name", "武器技師")) if assigned_crew.size() >= 1 else "武器技師"
			_spawn_working_npc(car, Vector3(-2.0, 0.10, -0.9), 0.0, "mechanic", a_name, "焊接修整", "hammer")
		_:
			# Generic workstation + working crew stickman
			_add_box(car, "UtilityDesk", Vector3(2.2, 0.95, 0.95), Vector3(-2.0, 0.48, -1.85), desk_mat)
			_add_box(car, "UtilityScreen", Vector3(1.2, 0.42, 0.10), Vector3(-2.0, 1.2, -2.25), screen_cyan)
			var u_name: String = str(assigned_crew[0].get("short_name", "值勤乘員")) if assigned_crew.size() >= 1 else "值勤乘員"
			_spawn_working_npc(car, Vector3(-2.0, 0.10, -0.9), 0.0, "mechanic", u_name, "系統巡檢", "console")


func _spawn_working_npc(parent: Node3D, local_pos: Vector3, facing_yaw: float, role: String, npc_name: String, task_label: String, work_style: String) -> void:
	var role_col: Color = _role_color(role)
	var acc: String = "wrench" if work_style == "hammer" else ("clipboard" if work_style == "patrol" else "hardhat")
	var rig: Dictionary = StickmanFactory.create_stickman({
		"name": "TrainCrew_" + npc_name,
		"body_color": Color(0.14, 0.16, 0.20),
		"head_color": Color(0.96, 0.95, 0.90),
		"accent_color": role_col,
		"limb_thickness": 0.068,
		"accessory": acc,
	})
	var root: Node3D = rig["root"] as Node3D
	root.position = local_pos
	root.rotation.y = facing_yaw
	root.scale = Vector3.ONE * 1.05
	parent.add_child(root)

	var lbl: Label3D = Label3D.new()
	lbl.name = "CrewRoleLabel"
	lbl.text = "%s\n[%s]" % [npc_name, task_label]
	lbl.font_size = 30
	lbl.pixel_size = 0.0085
	lbl.modulate = role_col.lightened(0.25)
	lbl.outline_modulate = Color(0.05, 0.06, 0.09, 0.95)
	lbl.outline_size = 8
	lbl.position = Vector3(0.0, 2.22, 0.0)
	lbl.rotation = Vector3(deg_to_rad(-24.0), _camera_yaw_rad, 0.0)
	root.add_child(lbl)

	_working_npcs.append({
		"name": npc_name,
		"role": role,
		"task": task_label,
		"style": work_style,
		"root": root,
		"base_pos": local_pos,
		"base_yaw": facing_yaw,
		"torso": rig["torso"],
		"head": rig["head"],
		"left_arm": rig["left_arm"],
		"right_arm": rig["right_arm"],
		"left_leg": rig["left_leg"],
		"right_leg": rig["right_leg"],
		"label": lbl,
	})


func _role_color(role: String) -> Color:
	match role:
		"mechanic":
			return Color(1.0, 0.72, 0.24)
		"gunner":
			return Color(0.98, 0.38, 0.32)
		"medic":
			return Color(0.32, 0.96, 0.62)
		"quartermaster":
			return Color(0.96, 0.82, 0.34)
		_:
			return Color(0.38, 0.88, 1.0)


func _carriage_wall_material(ctype: String) -> StandardMaterial3D:
	match ctype:
		"boarding":
			return _make_mat(Color(0.24, 0.34, 0.34), 0.45, 0.54)
		"cargo":
			return _make_mat(Color(0.40, 0.26, 0.20), 0.38, 0.62)
		"turret":
			return _make_mat(Color(0.24, 0.26, 0.31), 0.65, 0.42)
		"medbay":
			return _make_mat(Color(0.76, 0.82, 0.84), 0.25, 0.50)
		"armory":
			return _make_mat(Color(0.30, 0.28, 0.24), 0.55, 0.50)
		"recon":
			return _make_mat(Color(0.22, 0.29, 0.38), 0.50, 0.48)
		"quarters":
			return _make_mat(Color(0.32, 0.28, 0.38), 0.38, 0.56)
		_:
			return _make_mat(Color(0.26, 0.29, 0.33), 0.52, 0.50)


func _carriage_accent_color(ctype: String) -> Color:
	match ctype:
		"boarding":
			return Color(0.32, 0.92, 1.0)
		"cargo":
			return Color(1.0, 0.80, 0.28)
		"turret":
			return Color(1.0, 0.38, 0.30)
		"medbay":
			return Color(0.28, 0.96, 0.58)
		_:
			return Color(0.95, 0.72, 0.28)


func _add_light(parent: Node3D, node_name: String, color: Color, energy: float, light_range: float, pos: Vector3) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = pos
	parent.add_child(light)
	return light


func _build_interactive_zones() -> void:
	_boarding_ring = _create_zone_ring("BoardingZoneRing", boarding_local_pos, 1.55, 1.75, Color(0.28, 0.94, 0.72, 0.82))
	_boarding_label = _create_zone_label("BoardingZoneLabel", boarding_local_pos + Vector3(0.0, 2.6, -1.0), "登車入口 [可直接步入車廂]", Color(0.45, 0.98, 0.78))

	_stash_ring = _create_zone_ring("TrainStashRing", stash_local_pos, 1.48, 1.68, Color(1.0, 0.78, 0.26, 0.86))
	_stash_label = _create_zone_label("TrainStashLabel", stash_local_pos + Vector3(0.0, 2.6, -1.0), "貨運車廂入口 [暫存倉]", Color(1.0, 0.86, 0.38))


func _update_interactive_zone_positions() -> void:
	if _boarding_ring != null:
		_boarding_ring.position = Vector3(boarding_local_pos.x, 0.14, boarding_local_pos.z)
	if _boarding_label != null:
		_boarding_label.position = boarding_local_pos + Vector3(0.0, 2.6, -1.0)
	if _stash_ring != null:
		_stash_ring.position = Vector3(stash_local_pos.x, 0.14, stash_local_pos.z)
	if _stash_label != null:
		_stash_label.position = stash_local_pos + Vector3(0.0, 2.6, -1.0)
	if _hull_bar_root != null:
		_hull_bar_root.position = Vector3(boarding_local_pos.x, 6.2, 0.0)


func _create_zone_ring(node_name: String, pos: Vector3, inner_r: float, outer_r: float, color: Color) -> MeshInstance3D:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = node_name
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.rings = 32
	torus.ring_segments = 10
	ring.mesh = torus
	ring.position = Vector3(pos.x, 0.14, pos.z)
	ring.scale = Vector3(1.0, 0.45, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	add_child(ring)
	return ring


func _create_zone_label(node_name: String, pos: Vector3, text: String, color: Color) -> Label3D:
	var lbl: Label3D = Label3D.new()
	lbl.name = node_name
	lbl.text = text
	lbl.font_size = 42
	lbl.pixel_size = 0.012
	lbl.modulate = color
	lbl.outline_modulate = Color(0.05, 0.06, 0.09, 0.95)
	lbl.outline_size = 10
	lbl.position = pos
	lbl.rotation_degrees = Vector3(-24.0, 0.0, 0.0)
	add_child(lbl)
	return lbl


func _build_hull_durability_bar() -> void:
	_hull_bar_root = Node3D.new()
	_hull_bar_root.name = "TrainHullBar3D"
	_hull_bar_root.position = Vector3(0.0, 6.2, 0.0)
	_hull_bar_root.rotation_degrees = Vector3(-28.0, 0.0, 0.0)
	add_child(_hull_bar_root)

	var bg: MeshInstance3D = MeshInstance3D.new()
	bg.name = "HullBarBg"
	var bg_mesh: BoxMesh = BoxMesh.new()
	bg_mesh.size = Vector3(5.4, 0.34, 0.10)
	bg.mesh = bg_mesh
	var bg_mat: StandardMaterial3D = StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.07, 0.09, 0.13, 0.92)
	bg.material_override = bg_mat
	_hull_bar_root.add_child(bg)

	_hull_bar_fill = MeshInstance3D.new()
	_hull_bar_fill.name = "HullBarFill"
	var fill_mesh: BoxMesh = BoxMesh.new()
	fill_mesh.size = Vector3(5.2, 0.22, 0.12)
	_hull_bar_fill.mesh = fill_mesh
	_hull_bar_fill_mat = StandardMaterial3D.new()
	_hull_bar_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hull_bar_fill_mat.albedo_color = Color(0.28, 0.88, 0.50)
	_hull_bar_fill_mat.emission_enabled = true
	_hull_bar_fill_mat.emission = Color(0.28, 0.88, 0.50)
	_hull_bar_fill_mat.emission_energy_multiplier = 1.6
	_hull_bar_fill.material_override = _hull_bar_fill_mat
	_hull_bar_root.add_child(_hull_bar_fill)


func _update_hull_bar_visual() -> void:
	if _hull_bar_fill == null or not is_instance_valid(_hull_bar_fill):
		return
	var ratio: float = get_hull_ratio()
	var display_ratio: float = maxf(0.02, ratio) if hull_hp > 0.0 else 0.001
	_hull_bar_fill.visible = hull_hp > 0.0
	_hull_bar_fill.scale.x = display_ratio
	_hull_bar_fill.position.x = -(1.0 - display_ratio) * 2.6

	if _hull_bar_fill_mat != null:
		var col: Color = Color(0.28, 0.88, 0.50) if ratio > 0.6 else (Color(0.96, 0.72, 0.22) if ratio > 0.3 else Color(0.94, 0.28, 0.24))
		_hull_bar_fill_mat.albedo_color = col
		_hull_bar_fill_mat.emission = col
