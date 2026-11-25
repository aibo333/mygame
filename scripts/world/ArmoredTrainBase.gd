class_name ArmoredTrainBase
extends Node3D

signal hull_hp_changed(current_hp: float, max_hp: float)
signal train_destroyed()

const CAR_PITCH: float = 6.6
const BOARDING_RADIUS: float = 2.6
const STASH_RADIUS: float = 2.6

var max_hull_hp: float = 1000.0
var hull_hp: float = 1000.0
var boarding_local_pos: Vector3 = Vector3(0.0, 0.0, 3.4)
var stash_local_pos: Vector3 = Vector3(6.6, 0.0, 3.4)
var carriage_count: int = 3

var _built: bool = false
var _tracks_root: Node3D = null
var _consist_root: Node3D = null
var _collider_body: StaticBody3D = null
var _collider_shape: BoxShape3D = null
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
var _camera_yaw_rad: float = 0.0


func _ready() -> void:
	setup()


func setup() -> void:
	if _built:
		return
	_built = true
	_build_hull_collider()
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

	_rebuild_railway_tracks(maxf(54.0, total_span + 18.0))

	_consist_root = Node3D.new()
	_consist_root.name = "ConsistRoot"
	add_child(_consist_root)

	# 1. Locomotive at index 0 (west nose)
	var loco_x: float = start_x
	_build_locomotive_car(loco_x, consist.locomotive, stats)

	# 2. Dynamic Carriages
	var found_boarding: bool = false
	var found_stash: bool = false
	for idx in range(consist.carriages.size()):
		var car: Dictionary = consist.carriages[idx]
		var ctype: String = str(car.get("type", "flatbed"))
		var roof_mod: String = str(car.get("roof", "none"))
		var cx: float = start_x + float(idx + 1) * CAR_PITCH
		var is_manned: bool = _has_assigned_crew(car.get("crew_slots", []) as Array)
		_build_carriage_unit(idx, cx, ctype, roof_mod, is_manned)

		if (ctype == "boarding" or _car_has_cell(car, "boarding")) and not found_boarding:
			boarding_local_pos = Vector3(cx, 0.0, 3.4)
			found_boarding = true
		if (ctype == "cargo" or _car_has_cell(car, "cargo")) and not found_stash:
			stash_local_pos = Vector3(cx, 0.0, 3.4)
			found_stash = true

	if not found_boarding:
		boarding_local_pos = Vector3(start_x + CAR_PITCH, 0.0, 3.4)
	if not found_stash:
		stash_local_pos = Vector3(start_x + CAR_PITCH * 2.0, 0.0, 3.4)

	# Update collider width to match dynamic consist length
	if _collider_shape != null and _collider_body != null:
		_collider_shape.size = Vector3(float(total_units) * CAR_PITCH + 1.4, 3.6, 3.4)
		_collider_body.position = Vector3(-0.35, 1.8, 0.0)

	_update_interactive_zone_positions()
	_update_hull_bar_visual()
	hull_hp_changed.emit(hull_hp, max_hull_hp)


func _clear_consist_nodes() -> void:
	_turret_heads.clear()
	_radar_dishes.clear()
	_electric_lights.clear()
	_furnace_light = null
	_headlamp_light = null

	if _consist_root != null and is_instance_valid(_consist_root):
		if _consist_root.get_parent() == self:
			remove_child(_consist_root)
		_consist_root.free()
	_consist_root = null


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
	return Vector2(world_pos.x - target.x, world_pos.z - target.z).length() <= BOARDING_RADIUS


func is_player_in_stash_zone(world_pos: Vector3) -> bool:
	var target: Vector3 = get_stash_world_pos()
	return Vector2(world_pos.x - target.x, world_pos.z - target.z).length() <= STASH_RADIUS


func get_turret_world_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for th: Node3D in _turret_heads:
		if is_instance_valid(th):
			if th.is_inside_tree():
				positions.append(th.global_position + Vector3(0.0, 0.25, 0.0))
			else:
				positions.append(position + th.position + Vector3(0.0, 0.25, 0.0))
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


func animate_train(time_elapsed: float) -> void:
	if _furnace_light != null and is_instance_valid(_furnace_light):
		_furnace_light.light_energy = 3.2 + sin(time_elapsed * 5.2) * 0.45 + sin(time_elapsed * 13.0) * 0.15
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
			el.light_energy = 2.0 + absf(sin(time_elapsed * 7.5 + float(i) * 2.1)) * 1.6


func play_stash_deposit_fx() -> void:
	if not is_inside_tree():
		return
	var pulse: MeshInstance3D = MeshInstance3D.new()
	pulse.name = "StashDepositPulse"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.32
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
	tw.tween_property(pulse, "position:y", 1.85, 0.42)
	tw.tween_property(pulse, "scale", Vector3(1.55, 0.6, 1.55), 0.42)
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

	_add_box(_tracks_root, "BallastBed", Vector3(track_len, 0.14, 3.2), Vector3(0.0, 0.07, 0.0), ballast_mat)
	_add_box(_tracks_root, "RailNorth", Vector3(track_len, 0.14, 0.14), Vector3(0.0, 0.22, -0.88), rail_mat)
	_add_box(_tracks_root, "RailSouth", Vector3(track_len, 0.14, 0.14), Vector3(0.0, 0.22, 0.88), rail_mat)

	var half_ties: int = int(ceil(track_len * 0.5))
	for i in range(-half_ties, half_ties + 1):
		_add_box(_tracks_root, "Tie_%d" % i, Vector3(0.26, 0.10, 2.55), Vector3(float(i), 0.15, 0.0), tie_mat)


func _build_locomotive_car(cx: float, loco_cfg: Dictionary, stats: Dictionary) -> void:
	var boiler_lv: int = int(loco_cfg.get("boiler_level", 1))
	var armor_lv: int = int(loco_cfg.get("armor_level", 1))
	var lamp_lv: int = int(loco_cfg.get("headlamp_level", 1))
	var manned: bool = _has_assigned_crew(loco_cfg.get("crew_slots", []) as Array)

	var loco: Node3D = Node3D.new()
	loco.name = "LocomotiveCar"
	loco.position = Vector3(cx, 0.0, 0.0)
	_consist_root.add_child(loco)

	var armor_dark: StandardMaterial3D = _make_mat(Color(0.18, 0.21, 0.25), 0.62, 0.46)
	var armor_mid: StandardMaterial3D = _make_mat(Color(0.25, 0.29, 0.34), 0.58, 0.48)
	var hazard_mat: StandardMaterial3D = _make_mat(Color(0.92, 0.62, 0.14), 0.22, 0.52)
	var steel_mat: StandardMaterial3D = _make_mat(Color(0.36, 0.39, 0.44), 0.78, 0.36)
	var furnace_mat: StandardMaterial3D = _make_mat(Color(1.0, 0.46, 0.14), 0.1, 0.3, Color(1.0, 0.42, 0.10), 2.8 + float(boiler_lv) * 0.75)
	var headlamp_mat: StandardMaterial3D = _make_mat(Color(1.0, 0.95, 0.78), 0.1, 0.2, Color(1.0, 0.92, 0.70), 3.6 + float(lamp_lv) * 0.8)

	_add_box(loco, "Chassis", Vector3(6.2, 0.55, 2.85), Vector3(0.0, 0.68, 0.0), armor_dark)
	for wx in [-2.2, -0.8, 0.8, 2.1]:
		_add_cyl(loco, "WheelN_%d" % int(wx * 10), 0.42, 0.22, Vector3(wx, 0.50, -1.02), steel_mat, Vector3(90.0, 0.0, 0.0))
		_add_cyl(loco, "WheelS_%d" % int(wx * 10), 0.42, 0.22, Vector3(wx, 0.50, 1.02), steel_mat, Vector3(90.0, 0.0, 0.0))

	_add_box(loco, "BoilerArmor", Vector3(3.8, 2.05, 2.75), Vector3(-0.9, 1.95, 0.0), armor_mid)
	_add_cyl(loco, "BoilerDrum", 1.08, 3.6, Vector3(-1.0, 2.35, 0.0), armor_dark, Vector3(0.0, 0.0, 90.0))
	_add_box(loco, "CabBody", Vector3(2.4, 2.55, 3.0), Vector3(1.8, 2.22, 0.0), armor_dark)
	_add_box(loco, "CabRoof", Vector3(2.75, 0.26, 3.2), Vector3(1.8, 3.60, 0.0), steel_mat)

	# Visual Boiler Upgrade Tiers (Smokestacks & pressure manifolds)
	_add_cyl(loco, "SmokestackMain", 0.34, 1.2 + float(boiler_lv - 1) * 0.22, Vector3(-2.1, 3.68, 0.0), steel_mat)
	_add_cyl(loco, "SmokestackRim", 0.44, 0.20, Vector3(-2.1, 4.25 + float(boiler_lv - 1) * 0.14, 0.0), armor_dark)
	if boiler_lv >= 2:
		_add_cyl(loco, "TwinStack", 0.24, 1.05, Vector3(-0.9, 3.55, 0.0), steel_mat)
	if boiler_lv >= 3:
		_add_box(loco, "BoilerCoreGlowS", Vector3(2.2, 0.24, 0.12), Vector3(-0.9, 2.55, 1.44), furnace_mat)
		_add_box(loco, "BoilerCoreGlowN", Vector3(2.2, 0.24, 0.12), Vector3(-0.9, 2.55, -1.44), furnace_mat)

	# Visual Armor Upgrade Tiers (Heavy side plates & spiked plow)
	_add_box(loco, "HazardStripeS", Vector3(6.0, 0.22, 0.08), Vector3(0.0, 1.28, 1.48), hazard_mat)
	_add_box(loco, "FurnaceVentS", Vector3(1.4, 0.48, 0.10), Vector3(-1.1, 1.85, 1.41), furnace_mat)
	var plow_scale: float = 1.0 + float(armor_lv - 1) * 0.16
	_add_box(loco, "SnowplowCore", Vector3(1.35 * plow_scale, 1.45, 2.85), Vector3(-3.55, 1.05, 0.0), steel_mat, Vector3(0.0, 0.0, 26.0))
	_add_box(loco, "SnowplowBlade", Vector3(0.28, 1.40, 3.16), Vector3(-4.10 - float(armor_lv - 1) * 0.12, 0.86, 0.0), hazard_mat, Vector3(0.0, 0.0, 32.0))
	if armor_lv >= 2:
		_add_box(loco, "SideArmorSkirtS", Vector3(5.6, 0.68, 0.16), Vector3(-0.1, 0.86, 1.52), steel_mat)
		_add_box(loco, "SideArmorSkirtN", Vector3(5.6, 0.68, 0.16), Vector3(-0.1, 0.86, -1.52), steel_mat)
	if armor_lv >= 3:
		_add_box(loco, "CabRoofShield", Vector3(2.5, 0.35, 3.25), Vector3(1.8, 3.85, 0.0), hazard_mat)

	# Headlamp upgrade tiers
	_add_cyl(loco, "HeadlampLens", 0.30 + float(lamp_lv - 1) * 0.05, 0.18, Vector3(-2.95, 2.65, 0.0), headlamp_mat, Vector3(0.0, 0.0, 90.0))
	if lamp_lv >= 2:
		_add_cyl(loco, "SideFloodS", 0.18, 0.16, Vector3(-2.4, 2.85, 1.38), headlamp_mat, Vector3(90.0, 0.0, 0.0))
	if lamp_lv >= 3:
		_add_cyl(loco, "RoofSearchlight", 0.24, 0.30, Vector3(1.8, 4.15, 0.6), headlamp_mat, Vector3(70.0, 0.0, 0.0))

	if manned:
		_add_crew_beacon(loco, Vector3(1.8, 4.1, -0.8), Color(1.0, 0.78, 0.28))

	_furnace_light = OmniLight3D.new()
	_furnace_light.name = "LocomotiveFurnaceGlow"
	_furnace_light.light_color = Color(1.0, 0.50, 0.18)
	_furnace_light.light_energy = 3.2
	_furnace_light.omni_range = 8.5
	_furnace_light.position = Vector3(-1.1, 2.0, 2.2)
	loco.add_child(_furnace_light)

	_headlamp_light = OmniLight3D.new()
	_headlamp_light.name = "LocomotiveHeadlamp"
	_headlamp_light.light_color = Color(1.0, 0.93, 0.74)
	_headlamp_light.light_energy = float(stats.get("headlamp_energy", 3.4))
	_headlamp_light.omni_range = float(stats.get("headlamp_range", 13.0))
	_headlamp_light.position = Vector3(-4.6, 2.4, 0.4)
	loco.add_child(_headlamp_light)


func _build_carriage_unit(idx: int, cx: float, ctype: String, roof_mod: String, is_manned: bool) -> void:
	var car: Node3D = Node3D.new()
	car.name = "Carriage_%02d_%s" % [idx + 1, ctype]
	car.position = Vector3(cx, 0.0, 0.0)
	_consist_root.add_child(car)

	var armor_dark: StandardMaterial3D = _make_mat(Color(0.20, 0.24, 0.29), 0.60, 0.46)
	var steel_mat: StandardMaterial3D = _make_mat(Color(0.38, 0.42, 0.48), 0.76, 0.38)
	var hazard_mat: StandardMaterial3D = _make_mat(Color(0.95, 0.70, 0.18), 0.25, 0.48)

	# Coupler to west car + common chassis & bogie wheels
	_add_box(car, "CouplerWest", Vector3(0.95, 0.42, 1.1), Vector3(-3.3, 0.92, 0.0), steel_mat)
	_add_box(car, "Chassis", Vector3(5.9, 0.50, 2.95), Vector3(0.0, 0.66, 0.0), armor_dark)
	for wx in [-2.1, -1.2, 1.2, 2.1]:
		_add_cyl(car, "WheelN_%d" % int(wx * 10), 0.38, 0.20, Vector3(wx, 0.46, -1.02), steel_mat, Vector3(90.0, 0.0, 0.0))
		_add_cyl(car, "WheelS_%d" % int(wx * 10), 0.38, 0.20, Vector3(wx, 0.46, 1.02), steel_mat, Vector3(90.0, 0.0, 0.0))

	match ctype:
		"boarding":
			var body_mat: StandardMaterial3D = _make_mat(Color(0.24, 0.32, 0.31), 0.45, 0.54)
			var cyan_glow: StandardMaterial3D = _make_mat(Color(0.32, 0.90, 1.0), 0.1, 0.2, Color(0.32, 0.90, 1.0), 3.0)
			_add_box(car, "CarBody", Vector3(5.8, 2.30, 3.0), Vector3(0.0, 2.06, 0.0), body_mat)
			_add_box(car, "CarRoof", Vector3(6.0, 0.24, 3.16), Vector3(0.0, 3.32, 0.0), armor_dark)
			_add_box(car, "BoardingDoor", Vector3(2.0, 1.90, 0.14), Vector3(0.0, 1.85, 1.48), armor_dark)
			_add_box(car, "BoardingLightStrip", Vector3(2.15, 0.14, 0.16), Vector3(0.0, 2.90, 1.54), cyan_glow)
			_add_box(car, "BoardingRamp", Vector3(2.2, 0.16, 1.65), Vector3(0.0, 0.42, 2.15), steel_mat, Vector3(24.0, 0.0, 0.0))
			_add_light(car, "BoardingBayLight", Color(0.45, 0.92, 1.0), 2.4, 7.5, Vector3(0.0, 2.7, 2.6))
		"cargo":
			var cargo_mat: StandardMaterial3D = _make_mat(Color(0.38, 0.25, 0.20), 0.38, 0.62)
			var amber_glow: StandardMaterial3D = _make_mat(Color(1.0, 0.80, 0.28), 0.1, 0.2, Color(1.0, 0.78, 0.24), 3.0)
			_add_box(car, "CargoBody", Vector3(5.8, 2.30, 3.0), Vector3(0.0, 2.06, 0.0), cargo_mat)
			_add_box(car, "CargoRoof", Vector3(6.0, 0.24, 3.14), Vector3(0.0, 3.32, 0.0), armor_dark)
			_add_box(car, "CargoHazardStripe", Vector3(5.85, 0.22, 0.08), Vector3(0.0, 1.25, 1.52), hazard_mat)
			_add_box(car, "StashBayFrame", Vector3(2.2, 1.80, 0.14), Vector3(0.0, 1.82, 1.48), armor_dark)
			_add_box(car, "StashLightStrip", Vector3(2.3, 0.14, 0.16), Vector3(0.0, 2.84, 1.54), amber_glow)
			_add_box(car, "LoadingTailgate", Vector3(2.3, 0.16, 1.35), Vector3(0.0, 0.56, 2.05), steel_mat, Vector3(18.0, 0.0, 0.0))
			_add_box(car, "CargoCrateA", Vector3(0.70, 0.52, 0.60), Vector3(1.7, 0.26, 2.1), hazard_mat, Vector3(0.0, 14.0, 0.0))
			_add_light(car, "CargoStashLight", Color(1.0, 0.80, 0.36), 2.4, 7.5, Vector3(0.0, 2.7, 2.6))
		"turret":
			var gun_mat: StandardMaterial3D = _make_mat(Color(0.23, 0.24, 0.28), 0.65, 0.42)
			_add_box(car, "TurretHull", Vector3(5.8, 2.25, 3.05), Vector3(0.0, 2.04, 0.0), gun_mat)
			_add_box(car, "CarRoof", Vector3(6.0, 0.24, 3.14), Vector3(0.0, 3.28, 0.0), armor_dark)
			_add_box(car, "ArmorPlatesS", Vector3(5.4, 0.90, 0.16), Vector3(0.0, 1.85, 1.56), steel_mat)
		"medbay":
			var med_body: StandardMaterial3D = _make_mat(Color(0.76, 0.80, 0.82), 0.25, 0.50)
			var cross_mat: StandardMaterial3D = _make_mat(Color(0.24, 0.92, 0.52), 0.1, 0.2, Color(0.24, 0.92, 0.52), 2.8)
			_add_box(car, "MedBody", Vector3(5.8, 2.30, 2.95), Vector3(0.0, 2.06, 0.0), med_body)
			_add_box(car, "MedRoof", Vector3(6.0, 0.24, 3.10), Vector3(0.0, 3.32, 0.0), armor_dark)
			_add_box(car, "CrossV", Vector3(0.34, 1.05, 0.10), Vector3(0.0, 2.05, 1.50), cross_mat)
			_add_box(car, "CrossH", Vector3(1.05, 0.34, 0.10), Vector3(0.0, 2.05, 1.50), cross_mat)
			_add_light(car, "MedLight", Color(0.38, 0.96, 0.62), 2.0, 7.0, Vector3(0.0, 2.6, 2.4))
		"armory":
			var arm_body: StandardMaterial3D = _make_mat(Color(0.28, 0.27, 0.24), 0.55, 0.50)
			var weld_glow: StandardMaterial3D = _make_mat(Color(1.0, 0.66, 0.22), 0.1, 0.2, Color(1.0, 0.62, 0.18), 2.8)
			_add_box(car, "ArmoryBody", Vector3(5.8, 2.25, 3.0), Vector3(0.0, 2.04, 0.0), arm_body)
			_add_box(car, "ArmoryRoof", Vector3(6.0, 0.24, 3.10), Vector3(0.0, 3.28, 0.0), armor_dark)
			_add_box(car, "WorkStrip", Vector3(2.8, 0.20, 0.12), Vector3(0.0, 2.2, 1.52), weld_glow)
		"recon":
			var rec_body: StandardMaterial3D = _make_mat(Color(0.22, 0.28, 0.36), 0.50, 0.48)
			_add_box(car, "ReconBody", Vector3(5.6, 2.25, 2.95), Vector3(0.0, 2.04, 0.0), rec_body)
			_add_box(car, "ReconRoof", Vector3(5.8, 0.22, 3.08), Vector3(0.0, 3.28, 0.0), armor_dark)
		"quarters":
			var q_body: StandardMaterial3D = _make_mat(Color(0.30, 0.28, 0.36), 0.38, 0.56)
			var win_glow: StandardMaterial3D = _make_mat(Color(1.0, 0.88, 0.62), 0.1, 0.2, Color(1.0, 0.84, 0.52), 2.4)
			_add_box(car, "QuartersBody", Vector3(5.8, 2.35, 3.0), Vector3(0.0, 2.08, 0.0), q_body)
			_add_box(car, "QuartersRoof", Vector3(6.0, 0.24, 3.16), Vector3(0.0, 3.36, 0.0), armor_dark)
			for wx in [-1.8, -0.6, 0.6, 1.8]:
				_add_box(car, "WindowS_%d" % int(wx * 10), Vector3(0.68, 0.58, 0.10), Vector3(wx, 2.25, 1.51), win_glow)
		"generator":
			var gen_body: StandardMaterial3D = _make_mat(Color(0.22, 0.26, 0.30), 0.65, 0.42)
			_add_box(car, "GenBody", Vector3(5.6, 2.20, 2.95), Vector3(0.0, 2.00, 0.0), gen_body)
			_add_box(car, "GenRoof", Vector3(5.8, 0.22, 3.08), Vector3(0.0, 3.22, 0.0), armor_dark)
		_:
			_add_box(car, "FlatbedDeck", Vector3(5.8, 0.20, 2.95), Vector3(0.0, 1.02, 0.0), steel_mat)
			for bx in [-2.6, 2.6]:
				_add_box(car, "BollardS_%d" % int(bx * 10), Vector3(0.28, 0.55, 0.28), Vector3(bx, 1.35, 1.28), hazard_mat)
				_add_box(car, "BollardN_%d" % int(bx * 10), Vector3(0.28, 0.55, 0.28), Vector3(bx, 1.35, -1.28), hazard_mat)

	# Modular Roof Hardpoint Attachment (independent of interior cabin type!)
	var roof_y: float = 1.15 if ctype == "flatbed" else 3.45
	match roof_mod:
		"turret":
			var red_glow: StandardMaterial3D = _make_mat(Color(1.0, 0.36, 0.26), 0.1, 0.2, Color(1.0, 0.32, 0.22), 3.2)
			_add_cyl(car, "TurretPedestal", 1.02, 0.42, Vector3(0.0, roof_y + 0.15, 0.0), steel_mat)
			var turret_head: Node3D = Node3D.new()
			turret_head.name = "RoofTurretHead"
			turret_head.position = Vector3(0.0, roof_y + 0.55, 0.0)
			car.add_child(turret_head)
			_add_box(turret_head, "TurretHousing", Vector3(1.35, 0.72, 1.45), Vector3(0.0, 0.15, 0.0), armor_dark)
			_add_box(turret_head, "TurretOptic", Vector3(0.32, 0.20, 0.14), Vector3(0.0, 0.35, 0.75), red_glow)
			_add_cyl(turret_head, "BarrelL", 0.09, 1.95, Vector3(-0.26, 0.14, 1.45), steel_mat, Vector3(90.0, 0.0, 0.0))
			_add_cyl(turret_head, "BarrelR", 0.09, 1.95, Vector3(0.26, 0.14, 1.45), steel_mat, Vector3(90.0, 0.0, 0.0))
			_turret_heads.append(turret_head)
		"radar":
			var cyan_glow: StandardMaterial3D = _make_mat(Color(0.38, 0.88, 1.0), 0.1, 0.2, Color(0.38, 0.88, 1.0), 3.2)
			_add_cyl(car, "RadioMast", 0.09, 2.2, Vector3(-1.7, roof_y + 1.05, -0.5), steel_mat)
			_add_box(car, "MastBeacon", Vector3(0.24, 0.24, 0.24), Vector3(-1.7, roof_y + 2.2, -0.5), cyan_glow)
			var radar: Node3D = Node3D.new()
			radar.name = "RadarDish"
			radar.position = Vector3(0.4, roof_y + 0.45, 0.0)
			car.add_child(radar)
			_add_cyl(radar, "RadarPost", 0.16, 0.8, Vector3(0.0, -0.15, 0.0), steel_mat)
			_add_box(radar, "RadarArray", Vector3(1.9, 0.85, 0.18), Vector3(0.0, 0.35, 0.2), steel_mat, Vector3(-18.0, 0.0, 0.0))
			_add_box(radar, "RadarCore", Vector3(0.24, 0.24, 0.35), Vector3(0.0, 0.35, 0.45), cyan_glow)
			_radar_dishes.append(radar)
		"tesla":
			var coil_mat: StandardMaterial3D = _make_mat(Color(0.84, 0.48, 0.22), 0.78, 0.32)
			var arc_glow: StandardMaterial3D = _make_mat(Color(0.36, 0.94, 1.0), 0.1, 0.2, Color(0.32, 0.90, 1.0), 3.8)
			for gx in [-1.4, 1.4]:
				_add_cyl(car, "TeslaCoil_%d" % int(gx * 10), 0.42, 1.35, Vector3(gx, roof_y + 0.65, 0.0), coil_mat)
				_add_cyl(car, "TeslaRing_%d" % int(gx * 10), 0.58, 0.16, Vector3(gx, roof_y + 1.25, 0.0), arc_glow)
			_add_box(car, "ElectricRailS", Vector3(5.6, 0.14, 0.12), Vector3(0.0, 1.45, 1.56), arc_glow)
			var el: OmniLight3D = _add_light(car, "GenArcLight", Color(0.36, 0.92, 1.0), 2.4, 8.0, Vector3(0.0, roof_y + 0.9, 1.4))
			_electric_lights.append(el)
		"shield":
			_add_box(car, "RoofArmorShield", Vector3(5.6, 0.45, 3.25), Vector3(0.0, roof_y + 0.22, 0.0), hazard_mat)
			_add_box(car, "RoofShieldRibs", Vector3(5.2, 0.52, 2.7), Vector3(0.0, roof_y + 0.30, 0.0), steel_mat)

	if is_manned:
		_add_crew_beacon(car, Vector3(2.2, roof_y + 0.45, 0.9), Color(0.45, 0.98, 0.72))


func _add_crew_beacon(parent: Node3D, pos: Vector3, color: Color) -> void:
	var mat: StandardMaterial3D = _make_mat(color, 0.1, 0.2, color, 3.2)
	_add_cyl(parent, "CrewMannedBeacon", 0.16, 0.28, pos, mat)


func _add_light(parent: Node3D, node_name: String, color: Color, energy: float, light_range: float, pos: Vector3) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = pos
	parent.add_child(light)
	return light


func _build_hull_collider() -> void:
	_collider_body = StaticBody3D.new()
	_collider_body.name = "TrainHullCollider"
	_collider_body.collision_layer = 1
	_collider_body.collision_mask = 0
	_collider_body.position = Vector3(-0.35, 1.8, 0.0)
	add_child(_collider_body)

	var col: CollisionShape3D = CollisionShape3D.new()
	_collider_shape = BoxShape3D.new()
	_collider_shape.size = Vector3(26.4, 3.6, 3.4)
	col.shape = _collider_shape
	_collider_body.add_child(col)


func _build_interactive_zones() -> void:
	_boarding_ring = _create_zone_ring("BoardingZoneRing", boarding_local_pos, 1.28, 1.44, Color(0.28, 0.94, 0.72, 0.82))
	_boarding_label = _create_zone_label("BoardingZoneLabel", boarding_local_pos + Vector3(0.0, 2.2, -0.8), "登車區 [藍圖整備]", Color(0.45, 0.98, 0.78))

	_stash_ring = _create_zone_ring("TrainStashRing", stash_local_pos, 1.22, 1.38, Color(1.0, 0.78, 0.26, 0.86))
	_stash_label = _create_zone_label("TrainStashLabel", stash_local_pos + Vector3(0.0, 2.2, -0.8), "列車暫存倉 [卸貨]", Color(1.0, 0.86, 0.38))


func _update_interactive_zone_positions() -> void:
	if _boarding_ring != null:
		_boarding_ring.position = Vector3(boarding_local_pos.x, 0.14, boarding_local_pos.z)
	if _boarding_label != null:
		_boarding_label.position = boarding_local_pos + Vector3(0.0, 2.2, -0.8)
	if _stash_ring != null:
		_stash_ring.position = Vector3(stash_local_pos.x, 0.14, stash_local_pos.z)
	if _stash_label != null:
		_stash_label.position = stash_local_pos + Vector3(0.0, 2.2, -0.8)
	if _hull_bar_root != null:
		_hull_bar_root.position = Vector3(boarding_local_pos.x, 4.9, 0.0)


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
	lbl.font_size = 40
	lbl.pixel_size = 0.011
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
	_hull_bar_root.position = Vector3(0.0, 4.9, 0.0)
	_hull_bar_root.rotation_degrees = Vector3(-28.0, 0.0, 0.0)
	add_child(_hull_bar_root)

	var bg: MeshInstance3D = MeshInstance3D.new()
	bg.name = "HullBarBg"
	var bg_mesh: BoxMesh = BoxMesh.new()
	bg_mesh.size = Vector3(4.2, 0.28, 0.08)
	bg.mesh = bg_mesh
	var bg_mat: StandardMaterial3D = StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.07, 0.09, 0.13, 0.92)
	bg.material_override = bg_mat
	_hull_bar_root.add_child(bg)

	_hull_bar_fill = MeshInstance3D.new()
	_hull_bar_fill.name = "HullBarFill"
	var fill_mesh: BoxMesh = BoxMesh.new()
	fill_mesh.size = Vector3(4.0, 0.18, 0.10)
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
	_hull_bar_fill.position.x = -(1.0 - display_ratio) * 2.0

	if _hull_bar_fill_mat != null:
		var col: Color = Color(0.28, 0.88, 0.50) if ratio > 0.6 else (Color(0.96, 0.72, 0.22) if ratio > 0.3 else Color(0.94, 0.28, 0.24))
		_hull_bar_fill_mat.albedo_color = col
		_hull_bar_fill_mat.emission = col
