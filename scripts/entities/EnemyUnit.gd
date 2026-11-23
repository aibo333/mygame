class_name EnemyUnit
extends CharacterBody3D

signal died(enemy: EnemyUnit)
signal gate_damaged(amount: float, hit_pos: Vector3)

var enemy_type: String = "goblin_raider"
var display_name: String = "哥布林掠奪者"
var is_commander: bool = false
var is_ranged: bool = false
var is_dead: bool = false
var alive: bool = true

var max_hp: float = 75.0
var hp: float = 75.0
var attack_damage: float = 11.0
var defense: float = 2.0
var attack_range: float = 1.9
var attack_interval: float = 1.0
var move_speed: float = 5.2
var gate_damage: float = 14.0
var unit_scale: float = 1.0

var telegraph_radius: float = 4.5
var telegraph_windup: float = 1.1
var telegraph_damage: float = 75.0

var _vfx_parent: Node3D = null
var _visual_root: Node3D = null
var _weapon_pivot: Node3D = null
var _hp_fill_mesh: MeshInstance3D = null
var _hp_bar_root: Node3D = null
var _name_label: Label3D = null
var _base_color: Color = Color(0.35, 0.56, 0.28)
var _accent_color: Color = Color(0.75, 0.25, 0.2)
var _flash_materials: Array[StandardMaterial3D] = []

var _attack_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _swing_timer: float = 0.0
var _knockback_vel: Vector3 = Vector3.ZERO
var _walk_phase: float = 0.0

# Commander AOE telegraph state
var _telegraph_cd: float = 4.5
var _telegraph_active: bool = false
var _telegraph_timer: float = 0.0
var _telegraph_origin: Vector3 = Vector3.ZERO
var _telegraph_node: Node3D = null
var _telegraph_inner_disc: MeshInstance3D = null


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_ensure_collider()


func _ensure_collider() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45 * unit_scale
	cap.height = 1.65 * unit_scale
	col.shape = cap
	col.position = Vector3(0.0, 0.85 * unit_scale, 0.0)
	add_child(col)


func setup(p_enemy_type: String, vfx_parent: Node3D, custom_name: String = "", hp_mult: float = 1.0) -> void:
	enemy_type = p_enemy_type
	_vfx_parent = vfx_parent

	var cfg: Dictionary = GameConfig.get_enemy(enemy_type)
	display_name = custom_name if not custom_name.is_empty() else str(cfg.get("name", enemy_type))
	is_commander = bool(cfg.get("is_commander", enemy_type == "enemy_commander"))
	is_ranged = bool(cfg.get("is_ranged", enemy_type == "skeleton_archer"))
	max_hp = float(cfg.get("max_hp", 80.0)) * hp_mult
	hp = max_hp
	attack_damage = float(cfg.get("attack", 12.0))
	defense = float(cfg.get("defense", 2.0))
	attack_range = float(cfg.get("attack_range", 2.0))
	attack_interval = float(cfg.get("attack_interval", 1.1))
	move_speed = float(cfg.get("move_speed", 4.5))
	gate_damage = float(cfg.get("gate_damage", 15.0))
	unit_scale = 1.7 if is_commander else float(cfg.get("scale", 1.0))

	telegraph_radius = float(cfg.get("telegraph_radius", 4.5))
	telegraph_windup = float(cfg.get("telegraph_windup", 1.1))
	telegraph_damage = float(cfg.get("telegraph_damage", 75.0))

	_attack_timer = randf_range(0.15, 0.45)
	_walk_phase = randf_range(0.0, TAU)
	_telegraph_cd = 4.0

	_configure_palette()
	_build_visual_mesh()
	_update_collider_scale()
	_update_hp_bar()


func _configure_palette() -> void:
	match enemy_type:
		"goblin_raider":
			_base_color = Color(0.36, 0.56, 0.26)
			_accent_color = Color(0.55, 0.34, 0.2)
		"shield_orc":
			_base_color = Color(0.24, 0.4, 0.25)
			_accent_color = Color(0.45, 0.47, 0.52)
		"skeleton_archer":
			_base_color = Color(0.84, 0.81, 0.74)
			_accent_color = Color(0.35, 0.2, 0.42)
		"berserker":
			_base_color = Color(0.68, 0.22, 0.18)
			_accent_color = Color(0.88, 0.52, 0.2)
		"enemy_commander":
			_base_color = Color(0.16, 0.14, 0.2)
			_accent_color = Color(0.88, 0.22, 0.16)
		_:
			_base_color = Color(0.45, 0.45, 0.45)
			_accent_color = Color(0.8, 0.25, 0.2)


func _update_collider_scale() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.radius = 0.45 * unit_scale
		cap.height = 1.65 * unit_scale
		col.position = Vector3(0.0, 0.85 * unit_scale, 0.0)


func _make_mat(color: Color, roughness: float = 0.72, metallic: float = 0.1, track_flash: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if track_flash:
		_flash_materials.append(mat)
	return mat


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _add_cyl(parent: Node3D, top_r: float, bottom_r: float, height: float, pos: Vector3, mat: StandardMaterial3D, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _build_visual_mesh() -> void:
	if _visual_root != null:
		_visual_root.queue_free()
	_flash_materials.clear()

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.scale = Vector3.ONE * unit_scale
	add_child(_visual_root)

	# Ground shadow disc
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.02, 0.03, 0.05, 0.45)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_cyl(_visual_root, 0.55, 0.55, 0.02, Vector3(0.0, 0.02, 0.0), shadow_mat)

	var body_mat := _make_mat(_base_color, 0.72, 0.15)
	var accent_mat := _make_mat(_accent_color, 0.6, 0.25)
	var steel_mat := _make_mat(Color(0.68, 0.72, 0.78), 0.35, 0.7)
	var dark_mat := _make_mat(Color(0.18, 0.16, 0.15), 0.85, 0.05)

	# Legs
	_add_box(_visual_root, Vector3(0.22, 0.58, 0.24), Vector3(-0.16, 0.30, 0.0), dark_mat)
	_add_box(_visual_root, Vector3(0.22, 0.58, 0.24), Vector3(0.16, 0.30, 0.0), dark_mat)

	# Torso & head tailored per archetype
	match enemy_type:
		"goblin_raider":
			_add_box(_visual_root, Vector3(0.54, 0.62, 0.36), Vector3(0.0, 0.86, 0.04), body_mat, Vector3(10, 0, 0))
			_add_box(_visual_root, Vector3(0.42, 0.38, 0.4), Vector3(0.0, 1.36, 0.08), body_mat)
			# Pointed ears
			_add_cyl(_visual_root, 0.01, 0.08, 0.26, Vector3(-0.26, 1.4, 0.06), body_mat, Vector3(0, 0, 68))
			_add_cyl(_visual_root, 0.01, 0.08, 0.26, Vector3(0.26, 1.4, 0.06), body_mat, Vector3(0, 0, -68))
			# Loincloth / belt
			_add_box(_visual_root, Vector3(0.56, 0.14, 0.38), Vector3(0.0, 0.58, 0.02), accent_mat)
		"shield_orc":
			_add_box(_visual_root, Vector3(0.76, 0.82, 0.48), Vector3(0.0, 0.96, 0.0), body_mat)
			_add_box(_visual_root, Vector3(0.46, 0.44, 0.44), Vector3(0.0, 1.56, 0.0), body_mat)
			# Iron helmet + shoulder pads
			_add_cyl(_visual_root, 0.2, 0.28, 0.24, Vector3(0.0, 1.78, 0.0), steel_mat)
			_add_box(_visual_root, Vector3(0.24, 0.24, 0.44), Vector3(-0.48, 1.24, 0.0), steel_mat)
			_add_box(_visual_root, Vector3(0.24, 0.24, 0.44), Vector3(0.48, 1.24, 0.0), steel_mat)
			# Heavy tower shield on left
			_add_box(_visual_root, Vector3(0.14, 1.15, 0.72), Vector3(-0.56, 0.95, 0.22), accent_mat, Vector3(0, 18, 0))
			_add_box(_visual_root, Vector3(0.16, 0.26, 0.26), Vector3(-0.58, 0.98, 0.22), steel_mat, Vector3(0, 18, 0))
		"skeleton_archer":
			_add_box(_visual_root, Vector3(0.46, 0.72, 0.28), Vector3(0.0, 0.92, 0.0), body_mat)
			_add_box(_visual_root, Vector3(0.36, 0.38, 0.36), Vector3(0.0, 1.48, 0.0), body_mat)
			# Hood / cloak
			_add_box(_visual_root, Vector3(0.52, 0.82, 0.14), Vector3(0.0, 0.96, -0.2), accent_mat, Vector3(-8, 0, 0))
			_add_box(_visual_root, Vector3(0.42, 0.16, 0.42), Vector3(0.0, 1.66, -0.02), accent_mat)
			# Quiver on back
			_add_cyl(_visual_root, 0.09, 0.07, 0.62, Vector3(0.18, 1.05, -0.24), dark_mat, Vector3(0, 0, -18))
		"berserker":
			_add_box(_visual_root, Vector3(0.7, 0.8, 0.44), Vector3(0.0, 0.95, 0.0), body_mat)
			_add_box(_visual_root, Vector3(0.44, 0.42, 0.42), Vector3(0.0, 1.54, 0.0), body_mat)
			# Spiked pauldrons & war paint
			_add_box(_visual_root, Vector3(0.28, 0.24, 0.42), Vector3(-0.46, 1.24, 0.0), accent_mat, Vector3(0, 0, 15))
			_add_box(_visual_root, Vector3(0.28, 0.24, 0.42), Vector3(0.46, 1.24, 0.0), accent_mat, Vector3(0, 0, -15))
			# Left hand axe
			_add_cyl(_visual_root, 0.04, 0.04, 0.9, Vector3(-0.5, 0.95, 0.32), dark_mat, Vector3(58, 0, 0))
			_add_box(_visual_root, Vector3(0.08, 0.32, 0.32), Vector3(-0.5, 1.15, 0.65), steel_mat)
		"enemy_commander":
			var gold_mat := _make_mat(Color(0.86, 0.68, 0.24), 0.32, 0.78)
			_add_box(_visual_root, Vector3(0.86, 0.92, 0.54), Vector3(0.0, 1.02, 0.0), body_mat)
			_add_box(_visual_root, Vector3(0.5, 0.48, 0.48), Vector3(0.0, 1.68, 0.0), body_mat)
			# Gold chest trim & giant pauldrons
			_add_box(_visual_root, Vector3(0.88, 0.2, 0.56), Vector3(0.0, 1.22, 0.0), gold_mat)
			_add_box(_visual_root, Vector3(0.36, 0.34, 0.54), Vector3(-0.58, 1.38, 0.0), gold_mat, Vector3(0, 0, 18))
			_add_box(_visual_root, Vector3(0.36, 0.34, 0.54), Vector3(0.58, 1.38, 0.0), gold_mat, Vector3(0, 0, -18))
			# Giant curved horns on helmet
			_add_cyl(_visual_root, 0.02, 0.1, 0.62, Vector3(-0.34, 2.02, 0.04), gold_mat, Vector3(12, 0, 38))
			_add_cyl(_visual_root, 0.02, 0.1, 0.62, Vector3(0.34, 2.02, 0.04), gold_mat, Vector3(12, 0, -38))
			# Crimson warlord cape
			_add_box(_visual_root, Vector3(0.82, 1.22, 0.1), Vector3(0.0, 0.92, -0.34), accent_mat, Vector3(-12, 0, 0))
		_:
			_add_box(_visual_root, Vector3(0.6, 0.75, 0.4), Vector3(0.0, 0.92, 0.0), body_mat)
			_add_box(_visual_root, Vector3(0.4, 0.4, 0.4), Vector3(0.0, 1.48, 0.0), body_mat)

	# Weapon pivot on right hand
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.46, 1.0, 0.12)
	_visual_root.add_child(_weapon_pivot)

	match enemy_type:
		"goblin_raider":
			_add_box(_weapon_pivot, Vector3(0.08, 0.55, 0.12), Vector3(0.0, 0.18, 0.25), steel_mat, Vector3(55, 0, 0))
		"shield_orc":
			_add_cyl(_weapon_pivot, 0.04, 0.04, 0.85, Vector3(0.04, 0.1, 0.28), dark_mat, Vector3(55, 0, 0))
			_add_box(_weapon_pivot, Vector3(0.24, 0.24, 0.24), Vector3(0.04, 0.32, 0.62), steel_mat)
		"skeleton_archer":
			# Bow held forward
			_weapon_pivot.position = Vector3(-0.36, 1.05, 0.34)
			var bow_mat := _make_mat(Color(0.55, 0.36, 0.18), 0.7, 0.05)
			_add_box(_weapon_pivot, Vector3(0.06, 0.95, 0.08), Vector3(0.0, 0.0, 0.14), bow_mat)
		"berserker":
			_add_cyl(_weapon_pivot, 0.04, 0.04, 0.95, Vector3(0.06, 0.12, 0.28), dark_mat, Vector3(58, 0, 0))
			_add_box(_weapon_pivot, Vector3(0.08, 0.34, 0.34), Vector3(0.06, 0.34, 0.66), steel_mat)
		"enemy_commander":
			var glow_blade := _make_mat(Color(1.0, 0.34, 0.16), 0.25, 0.6)
			glow_blade.emission_enabled = true
			glow_blade.emission = Color(1.0, 0.26, 0.1)
			glow_blade.emission_energy_multiplier = 1.6
			_add_cyl(_weapon_pivot, 0.05, 0.05, 0.65, Vector3(0.14, 0.05, 0.25), dark_mat, Vector3(55, 0, 0))
			_add_box(_weapon_pivot, Vector3(0.14, 1.55, 0.24), Vector3(0.14, 0.56, 0.82), glow_blade, Vector3(55, 0, 0))

	_build_overhead_hud()


func _build_overhead_hud() -> void:
	_hp_bar_root = Node3D.new()
	_hp_bar_root.name = "OverheadHud"
	var y_off: float = 2.25 if not is_commander else 2.55
	_hp_bar_root.position = Vector3(0.0, y_off, 0.0)
	_visual_root.add_child(_hp_bar_root)

	var bar_w: float = 1.25 if is_commander else 0.9
	var bar_h: float = 0.13 if is_commander else 0.09

	var bg_mi := MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(bar_w + 0.06, bar_h + 0.05)
	bg_mi.mesh = bg_quad
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.05, 0.06, 0.08, 0.85)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	bg_mi.material_override = bg_mat
	_hp_bar_root.add_child(bg_mi)

	_hp_fill_mesh = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(bar_w, bar_h)
	_hp_fill_mesh.mesh = fill_quad
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.95, 0.24, 0.2) if is_commander else Color(0.88, 0.28, 0.24)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.no_depth_test = true
	_hp_fill_mesh.material_override = fill_mat
	_hp_fill_mesh.position = Vector3(0.0, 0.0, 0.01)
	_hp_bar_root.add_child(_hp_fill_mesh)

	if is_commander:
		_name_label = Label3D.new()
		_name_label.text = "【督軍】" + display_name
		_name_label.font_size = 34
		_name_label.pixel_size = 0.0085
		_name_label.modulate = Color(1.0, 0.82, 0.35)
		_name_label.outline_size = 6
		_name_label.outline_modulate = Color(0.1, 0.05, 0.05)
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.no_depth_test = true
		_name_label.position = Vector3(0.0, 0.28, 0.0)
		_hp_bar_root.add_child(_name_label)


func _update_hp_bar() -> void:
	if _hp_fill_mesh == null:
		return
	var ratio: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_hp_fill_mesh.scale.x = maxf(ratio, 0.001)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _attack_timer > 0.0:
		_attack_timer -= delta

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_set_hit_flash(false)

	if _swing_timer > 0.0:
		_swing_timer -= delta
		if _weapon_pivot != null:
			var t: float = _swing_timer / 0.25
			_weapon_pivot.rotation_degrees.x = lerpf(0.0, 68.0, sin(t * PI))
	elif _weapon_pivot != null and not _telegraph_active:
		_weapon_pivot.rotation_degrees.x = 0.0

	# Knockback decay
	if _knockback_vel.length_squared() > 0.05:
		global_position += _knockback_vel * delta
		_knockback_vel = _knockback_vel.lerp(Vector3.ZERO, minf(1.0, delta * 9.0))
		_clamp_position()

	# Commander AOE telegraph handling
	if is_commander:
		if _telegraph_active:
			_process_commander_telegraph(delta)
			return
		_telegraph_cd -= delta
		if _telegraph_cd <= 0.0:
			var nearby: Node3D = _find_nearest_combat_target(7.5)
			if nearby != null:
				_start_commander_telegraph(nearby.global_position)
				return

	# Target acquisition: nearby hero/soldiers or castle gate
	var aggro_range: float = 14.5 if is_ranged else 9.5
	var target: Node3D = _find_nearest_combat_target(aggro_range)

	if target != null:
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		var dist: float = to_target.length()
		if dist > 0.01:
			_face_direction(to_target.normalized(), delta)
		if dist <= attack_range:
			if _attack_timer <= 0.0:
				_perform_attack_on(target)
				_attack_timer = attack_interval
		else:
			var dir: Vector3 = to_target.normalized()
			global_position += dir * move_speed * delta
			_animate_walk(delta)
	else:
		# March toward castle gate
		var gate_pos := Vector3(GameConfig.GATE_X + 1.5, 0.0, clampf(global_position.z, -3.2, 3.2))
		var to_gate: Vector3 = gate_pos - global_position
		to_gate.y = 0.0
		var dist_gate: float = to_gate.length()
		if dist_gate > 0.05:
			_face_direction(to_gate.normalized(), delta)

		if global_position.x <= GameConfig.GATE_X + 1.85:
			if _attack_timer <= 0.0:
				_swing_timer = 0.25
				var hit_pos := Vector3(GameConfig.GATE_X + 0.6, 1.5, clampf(global_position.z, -3.0, 3.0))
				gate_damaged.emit(gate_damage, hit_pos)
				if _vfx_parent != null:
					VfxFactory.spawn_ring(_vfx_parent, hit_pos, 1.2, Color(1.0, 0.45, 0.18), 0.25)
				_attack_timer = attack_interval
		else:
			var dir_gate: Vector3 = to_gate.normalized()
			global_position += dir_gate * move_speed * delta
			_animate_walk(delta)

	_clamp_position()


func _clamp_position() -> void:
	var clamped: Vector3 = GameConfig.clamp_to_arena(global_position, 0.7)
	global_position.x = maxf(clamped.x, GameConfig.GATE_X + 1.45)
	global_position.z = clamped.z
	global_position.y = 0.0


func _face_direction(dir: Vector3, delta: float) -> void:
	if _visual_root == null:
		return
	var target_yaw: float = atan2(dir.x, dir.z)
	_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_yaw, minf(1.0, delta * 10.0))


func _animate_walk(delta: float) -> void:
	if _visual_root == null:
		return
	_walk_phase += delta * move_speed * 2.2
	_visual_root.position.y = absf(sin(_walk_phase)) * 0.09


func _find_nearest_combat_target(max_range: float) -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_dist_sq: float = max_range * max_range

	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("soldiers"))
	candidates.append_array(get_tree().get_nodes_in_group("hero"))
	candidates.append_array(get_tree().get_nodes_in_group("player"))

	for node in candidates:
		if not (node is Node3D):
			continue
		if node.get("is_dead") == true:
			continue
		var n3 := node as Node3D
		var d_sq: float = global_position.distance_squared_to(n3.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = n3
	return best


func _perform_attack_on(target: Node3D) -> void:
	_swing_timer = 0.25
	if is_ranged and _vfx_parent != null:
		var from_pos: Vector3 = global_position + Vector3(0.0, 1.45 * unit_scale, 0.0)
		var to_pos: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)
		VfxFactory.spawn_arrow(_vfx_parent, from_pos, to_pos, Color(0.95, 0.36, 0.22), 0.36)
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage)


func _start_commander_telegraph(target_pos: Vector3) -> void:
	_telegraph_active = true
	_telegraph_timer = 0.0
	_telegraph_origin = Vector3(target_pos.x, 0.0, target_pos.z)
	_telegraph_origin = GameConfig.clamp_to_arena(_telegraph_origin, 1.2)
	_telegraph_origin.x = maxf(_telegraph_origin.x, GameConfig.GATE_X + 2.0)

	# Face telegraph center
	var to_t: Vector3 = _telegraph_origin - global_position
	to_t.y = 0.0
	if to_t.length() > 0.1 and _visual_root != null:
		_visual_root.rotation.y = atan2(to_t.x, to_t.z)

	if _weapon_pivot != null:
		_weapon_pivot.rotation_degrees.x = -75.0

	_cleanup_telegraph_node()
	_telegraph_node = Node3D.new()
	_telegraph_node.name = "CommanderTelegraph"
	_telegraph_node.position = _telegraph_origin + Vector3(0.0, 0.07, 0.0)

	# Outer warning disc
	var outer_mi := MeshInstance3D.new()
	var outer_cyl := CylinderMesh.new()
	outer_cyl.top_radius = telegraph_radius
	outer_cyl.bottom_radius = telegraph_radius
	outer_cyl.height = 0.04
	outer_cyl.radial_segments = 28
	outer_mi.mesh = outer_cyl
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.95, 0.14, 0.1, 0.24)
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(1.0, 0.2, 0.12)
	outer_mat.emission_energy_multiplier = 1.4
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mi.material_override = outer_mat
	_telegraph_node.add_child(outer_mi)

	# Expanding inner fill disc
	_telegraph_inner_disc = MeshInstance3D.new()
	var inner_cyl := CylinderMesh.new()
	inner_cyl.top_radius = telegraph_radius
	inner_cyl.bottom_radius = telegraph_radius
	inner_cyl.height = 0.06
	inner_cyl.radial_segments = 28
	_telegraph_inner_disc.mesh = inner_cyl
	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = Color(1.0, 0.18, 0.08, 0.48)
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(1.0, 0.25, 0.1)
	inner_mat.emission_energy_multiplier = 2.0
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_inner_disc.material_override = inner_mat
	_telegraph_inner_disc.scale = Vector3(0.05, 1.0, 0.05)
	_telegraph_node.add_child(_telegraph_inner_disc)

	var parent_node: Node = _vfx_parent if _vfx_parent != null else get_parent()
	if parent_node != null:
		parent_node.add_child(_telegraph_node)

	if _vfx_parent != null:
		VfxFactory.spawn_floating_text(_vfx_parent, global_position + Vector3(0.0, 3.2, 0.0), "督軍重劈蓄力！", Color(1.0, 0.35, 0.22), 26)


func _process_commander_telegraph(delta: float) -> void:
	_telegraph_timer += delta
	var progress: float = clampf(_telegraph_timer / maxf(telegraph_windup, 0.1), 0.0, 1.0)
	if _telegraph_inner_disc != null:
		var s: float = lerpf(0.08, 1.0, progress)
		_telegraph_inner_disc.scale = Vector3(s, 1.0, s)

	if _telegraph_timer >= telegraph_windup:
		_execute_commander_slam()
		_telegraph_active = false
		_telegraph_cd = 6.5
		_cleanup_telegraph_node()


func _execute_commander_slam() -> void:
	_swing_timer = 0.32
	if _vfx_parent != null:
		VfxFactory.spawn_ring(_vfx_parent, _telegraph_origin + Vector3(0.0, 0.12, 0.0), telegraph_radius, Color(1.0, 0.24, 0.12), 0.45)
		VfxFactory.spawn_death_burst(_vfx_parent, _telegraph_origin + Vector3(0.0, 0.4, 0.0), Color(1.0, 0.38, 0.14), 10)

	if not is_inside_tree():
		return
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("soldiers"))
	targets.append_array(get_tree().get_nodes_in_group("hero"))
	targets.append_array(get_tree().get_nodes_in_group("player"))

	var hit_set: Dictionary = {}
	for node in targets:
		if not (node is Node3D):
			continue
		if hit_set.has(node):
			continue
		hit_set[node] = true
		var n3 := node as Node3D
		var flat_dist: float = Vector2(n3.global_position.x - _telegraph_origin.x, n3.global_position.z - _telegraph_origin.z).length()
		if flat_dist <= telegraph_radius and n3.has_method("take_damage"):
			n3.call("take_damage", telegraph_damage)


func _cleanup_telegraph_node() -> void:
	if is_instance_valid(_telegraph_node):
		_telegraph_node.queue_free()
	_telegraph_node = null
	_telegraph_inner_disc = null


func _set_hit_flash(active: bool) -> void:
	for mat in _flash_materials:
		if active:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.85, 0.78)
			mat.emission_energy_multiplier = 0.85
		else:
			mat.emission_enabled = false


func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, is_crit: bool = false) -> bool:
	if is_dead:
		return false

	var mitigated: float = maxf(amount - defense * 0.35, amount * 0.35)
	hp -= mitigated
	_hit_flash_timer = 0.12
	_set_hit_flash(true)

	var kb_mult: float = 0.35 if is_commander else 1.0
	_knockback_vel += Vector3(knockback.x, 0.0, knockback.z) * kb_mult
	_update_hp_bar()

	if _vfx_parent != null:
		var text: String = str(int(round(mitigated))) + ("!" if is_crit else "")
		var col: Color = Color(1.0, 0.86, 0.28) if is_crit else Color(1.0, 0.96, 0.9)
		var fsize: int = 28 if is_crit else 20
		VfxFactory.spawn_floating_text(_vfx_parent, global_position + Vector3(0.0, 2.0 * unit_scale, 0.0), text, col, fsize)

	if hp <= 0.0:
		is_dead = true
		alive = false
		_cleanup_telegraph_node()
		if _vfx_parent != null:
			VfxFactory.spawn_death_burst(_vfx_parent, global_position + Vector3(0.0, 0.9 * unit_scale, 0.0), _base_color, 14 if is_commander else 8)
		died.emit(self)
		queue_free()
		return true

	return false


func _exit_tree() -> void:
	_cleanup_telegraph_node()
