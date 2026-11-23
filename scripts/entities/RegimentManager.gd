class_name RegimentManager
extends Node3D

signal log_event(message: String)
signal order_changed(order: String)
signal formation_changed(formation: String)
signal regiment_changed(regiment_type: String)


class SoldierUnit:
	extends CharacterBody3D

	var slot_index: int = 0
	var regiment_type: String = "shieldmen"
	var max_hp: float = 150.0
	var hp: float = 150.0
	var attack_damage: float = 18.0
	var defense: float = 8.0
	var attack_range: float = 2.2
	var attack_interval: float = 1.0
	var move_speed: float = 5.5
	var is_ranged: bool = false
	var is_dead: bool = false

	var damage_reduction_bonus: float = 0.0
	var speed_mult: float = 1.0
	var warcry_timer: float = 0.0

	var _vfx_parent: Node3D = null
	var _visual_root: Node3D = null
	var _weapon_pivot: Node3D = null
	var _hp_fill: MeshInstance3D = null
	var _attack_timer: float = 0.0
	var _swing_timer: float = 0.0
	var _walk_phase: float = 0.0
	var _dash_timer: float = 0.0
	var _dash_vel: Vector3 = Vector3.ZERO
	var _primary_color: Color = Color(0.18, 0.42, 0.78)

	func _ready() -> void:
		add_to_group("soldiers")
		collision_layer = 2
		collision_mask = 1
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.36
		cap.height = 1.5
		col.shape = cap
		col.position = Vector3(0.0, 0.75, 0.0)
		add_child(col)

	func configure(p_slot: int, p_type: String, cfg: Dictionary, vfx_parent: Node3D) -> void:
		slot_index = p_slot
		regiment_type = p_type
		_vfx_parent = vfx_parent
		max_hp = float(cfg.get("max_hp", 150.0))
		hp = max_hp
		attack_damage = float(cfg.get("attack", 18.0))
		defense = float(cfg.get("defense", 6.0))
		attack_range = float(cfg.get("attack_range", 2.2))
		attack_interval = float(cfg.get("attack_interval", 1.0))
		move_speed = float(cfg.get("move_speed", 5.5))
		is_ranged = bool(cfg.get("is_ranged", p_type == "archers"))
		_attack_timer = randf_range(0.05, 0.35)
		_walk_phase = randf_range(0.0, TAU)
		_build_mesh()
		_update_hp_bar()

	func _make_mat(color: Color, roughness: float = 0.65, metallic: float = 0.18) -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = metallic
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

	func _build_mesh() -> void:
		if _visual_root != null:
			_visual_root.queue_free()
		_visual_root = Node3D.new()
		_visual_root.name = "VisualRoot"
		add_child(_visual_root)

		match regiment_type:
			"shieldmen":
				_primary_color = Color(0.18, 0.42, 0.78)
			"pikemen":
				_primary_color = Color(0.14, 0.56, 0.54)
			"archers":
				_primary_color = Color(0.24, 0.55, 0.3)
			_:
				_primary_color = Color(0.22, 0.44, 0.75)

		var tunic_mat := _make_mat(_primary_color, 0.65, 0.15)
		var steel_mat := _make_mat(Color(0.76, 0.8, 0.86), 0.32, 0.75)
		var gold_mat := _make_mat(Color(0.86, 0.7, 0.28), 0.35, 0.7)
		var wood_mat := _make_mat(Color(0.48, 0.31, 0.16), 0.8, 0.05)
		var dark_mat := _make_mat(Color(0.18, 0.2, 0.24), 0.82, 0.1)

		# Shadow disc
		var sh_mat := StandardMaterial3D.new()
		sh_mat.albedo_color = Color(0.02, 0.04, 0.08, 0.42)
		sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_add_cyl(_visual_root, 0.46, 0.46, 0.02, Vector3(0.0, 0.02, 0.0), sh_mat)

		# Legs & torso & head
		_add_box(_visual_root, Vector3(0.18, 0.52, 0.2), Vector3(-0.14, 0.26, 0.0), dark_mat)
		_add_box(_visual_root, Vector3(0.18, 0.52, 0.2), Vector3(0.14, 0.26, 0.0), dark_mat)
		_add_box(_visual_root, Vector3(0.54, 0.68, 0.34), Vector3(0.0, 0.84, 0.0), tunic_mat)
		_add_box(_visual_root, Vector3(0.36, 0.36, 0.36), Vector3(0.0, 1.38, 0.0), steel_mat)

		_weapon_pivot = Node3D.new()
		_weapon_pivot.position = Vector3(0.36, 0.92, 0.1)
		_visual_root.add_child(_weapon_pivot)

		match regiment_type:
			"shieldmen":
				# Helmet crest + kite tower shield + gladius
				_add_box(_visual_root, Vector3(0.1, 0.18, 0.4), Vector3(0.0, 1.62, 0.0), gold_mat)
				_add_box(_visual_root, Vector3(0.12, 0.98, 0.64), Vector3(-0.42, 0.88, 0.22), tunic_mat, Vector3(0, 16, 0))
				_add_box(_visual_root, Vector3(0.14, 0.22, 0.22), Vector3(-0.44, 0.9, 0.22), gold_mat, Vector3(0, 16, 0))
				_add_box(_weapon_pivot, Vector3(0.07, 0.72, 0.1), Vector3(0.0, 0.16, 0.25), steel_mat, Vector3(62, 0, 0))
			"pikemen":
				# Conical helm + pauldrons + long 3.0m spear
				_add_cyl(_visual_root, 0.04, 0.24, 0.24, Vector3(0.0, 1.64, 0.0), steel_mat)
				_add_box(_visual_root, Vector3(0.22, 0.18, 0.36), Vector3(-0.36, 1.12, 0.0), gold_mat)
				_add_box(_visual_root, Vector3(0.22, 0.18, 0.36), Vector3(0.36, 1.12, 0.0), gold_mat)
				_add_cyl(_weapon_pivot, 0.032, 0.032, 2.7, Vector3(0.0, 0.05, 0.9), wood_mat, Vector3(82, 0, 0))
				_add_cyl(_weapon_pivot, 0.01, 0.075, 0.45, Vector3(0.0, 0.26, 2.4), steel_mat, Vector3(82, 0, 0))
			"archers":
				# Cloak + quiver + recurve bow
				_add_box(_visual_root, Vector3(0.56, 0.72, 0.1), Vector3(0.0, 0.84, -0.2), tunic_mat, Vector3(-10, 0, 0))
				_add_box(_visual_root, Vector3(0.42, 0.16, 0.42), Vector3(0.0, 1.56, 0.0), tunic_mat)
				_add_cyl(_visual_root, 0.08, 0.06, 0.56, Vector3(0.18, 0.95, -0.24), wood_mat, Vector3(0, 0, -20))
				_weapon_pivot.position = Vector3(-0.32, 0.96, 0.28)
				_add_box(_weapon_pivot, Vector3(0.06, 0.96, 0.08), Vector3(0.0, 0.0, 0.16), wood_mat)

		# Mini overhead HP bar
		var hp_root := Node3D.new()
		hp_root.position = Vector3(0.0, 1.92, 0.0)
		_visual_root.add_child(hp_root)

		var bg := MeshInstance3D.new()
		var bg_q := QuadMesh.new()
		bg_q.size = Vector2(0.76, 0.1)
		bg.mesh = bg_q
		var bg_m := StandardMaterial3D.new()
		bg_m.albedo_color = Color(0.04, 0.05, 0.08, 0.8)
		bg_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bg_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bg_m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bg_m.no_depth_test = true
		bg.material_override = bg_m
		hp_root.add_child(bg)

		_hp_fill = MeshInstance3D.new()
		var fill_q := QuadMesh.new()
		fill_q.size = Vector2(0.7, 0.07)
		_hp_fill.mesh = fill_q
		var fill_m := StandardMaterial3D.new()
		fill_m.albedo_color = Color(0.26, 0.86, 0.52)
		fill_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fill_m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fill_m.no_depth_test = true
		_hp_fill.material_override = fill_m
		_hp_fill.position = Vector3(0.0, 0.0, 0.01)
		hp_root.add_child(_hp_fill)

	func _update_hp_bar() -> void:
		if _hp_fill == null:
			return
		var ratio: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		_hp_fill.scale.x = maxf(ratio, 0.001)

	func start_dash(vel: Vector3, duration: float) -> void:
		_dash_vel = vel
		_dash_timer = duration

	func step_ai(delta: float, slot_pos: Vector3, order: String, enemies: Array[Node]) -> void:
		if is_dead:
			return

		if warcry_timer > 0.0:
			warcry_timer = maxf(0.0, warcry_timer - delta)
		if _attack_timer > 0.0:
			_attack_timer -= delta * (1.35 if warcry_timer > 0.0 else 1.0)
		if _swing_timer > 0.0:
			_swing_timer -= delta
			if _weapon_pivot != null:
				var t: float = _swing_timer / 0.22
				_weapon_pivot.rotation_degrees.x = lerpf(0.0, 56.0, sin(t * PI))
		elif _weapon_pivot != null:
			_weapon_pivot.rotation_degrees.x = 0.0

		if _dash_timer > 0.0:
			_dash_timer -= delta
			global_position += _dash_vel * delta
			_clamp_self()
			return

		var aggro_range: float = attack_range + 2.5
		if order == "engage":
			aggro_range = 42.0
		elif order == "hold":
			aggro_range = attack_range + (2.5 if is_ranged else 2.2)
		else:
			aggro_range = attack_range + (3.0 if is_ranged else 3.2)

		var target: Node3D = _find_nearest_enemy(enemies, aggro_range)
		var eff_speed: float = move_speed * speed_mult * (1.2 if warcry_timer > 0.0 else 1.0)

		var should_move_to_slot: bool = false
		if target != null:
			var dist: float = _flat_dist(global_position, target.global_position)
			var dir_to_enemy: Vector3 = target.global_position - global_position
			dir_to_enemy.y = 0.0
			if dir_to_enemy.length() > 0.05:
				_face_dir(dir_to_enemy.normalized(), delta)

			if dist <= attack_range:
				if _attack_timer <= 0.0:
					_attack_enemy(target)
					_attack_timer = attack_interval
			elif order == "engage" or (order == "follow" and _flat_dist(global_position, slot_pos) < 5.5) or (order == "hold" and _flat_dist(global_position, slot_pos) < 2.2):
				global_position += dir_to_enemy.normalized() * eff_speed * delta
				_animate_walk(delta, eff_speed)
			else:
				should_move_to_slot = true
		else:
			should_move_to_slot = true

		if should_move_to_slot:
			var to_slot: Vector3 = slot_pos - global_position
			to_slot.y = 0.0
			var d_slot: float = to_slot.length()
			if d_slot > 0.22:
				var move_step: float = minf(d_slot, eff_speed * delta)
				var dir_slot: Vector3 = to_slot.normalized()
				global_position += dir_slot * move_step
				_face_dir(dir_slot, delta)
				_animate_walk(delta, eff_speed)
			else:
				# Face eastward toward oncoming enemy waves when idle in formation
				_face_dir(Vector3(1.0, 0.0, 0.0), delta)

		_clamp_self()

	func _flat_dist(a: Vector3, b: Vector3) -> float:
		return Vector2(a.x - b.x, a.z - b.z).length()

	func _find_nearest_enemy(enemies: Array[Node], max_range: float) -> Node3D:
		var best: Node3D = null
		var best_sq: float = max_range * max_range
		for n in enemies:
			if not is_instance_valid(n) or not (n is Node3D):
				continue
			if n.get("is_dead") == true:
				continue
			var n3 := n as Node3D
			var d_sq: float = global_position.distance_squared_to(n3.global_position)
			if d_sq < best_sq:
				best_sq = d_sq
				best = n3
		return best

	func _attack_enemy(enemy: Node3D) -> void:
		_swing_timer = 0.22
		var dmg: float = attack_damage * (1.28 if warcry_timer > 0.0 else 1.0)
		var dir: Vector3 = enemy.global_position - global_position
		dir.y = 0.0
		var kb: Vector3 = dir.normalized() * (1.8 if not is_ranged else 0.5)
		if is_ranged and _vfx_parent != null:
			VfxFactory.spawn_arrow(
				_vfx_parent,
				global_position + Vector3(0.0, 1.35, 0.0),
				enemy.global_position + Vector3(0.0, 1.0, 0.0),
				Color(0.55, 0.95, 0.65),
				0.32
			)
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", dmg, kb, false)

	func _face_dir(dir: Vector3, delta: float) -> void:
		if _visual_root == null:
			return
		var target_yaw: float = atan2(dir.x, dir.z)
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_yaw, minf(1.0, delta * 12.0))

	func _animate_walk(delta: float, spd: float) -> void:
		if _visual_root == null:
			return
		_walk_phase += delta * spd * 2.2
		_visual_root.position.y = absf(sin(_walk_phase)) * 0.07

	func _clamp_self() -> void:
		var c: Vector3 = GameConfig.clamp_to_arena(global_position, 0.8)
		global_position.x = maxf(c.x, GameConfig.GATE_X + 1.5)
		global_position.z = c.z
		global_position.y = 0.0

	func take_damage(amount: float) -> void:
		if is_dead:
			return
		var reduced: float = amount * (1.0 - damage_reduction_bonus)
		var final_dmg: float = maxf(reduced - defense * 0.35, reduced * 0.35)
		hp -= final_dmg
		_update_hp_bar()
		if hp <= 0.0:
			is_dead = true
			if _vfx_parent != null:
				VfxFactory.spawn_death_burst(_vfx_parent, global_position + Vector3(0.0, 0.8, 0.0), _primary_color, 6)
			visible = false
			remove_from_group("soldiers")


var regiment_type: String = "shieldmen"
var current_order: String = "follow"
var current_formation: String = "compact"
var hold_position: Vector3 = Vector3(-13.0, 0.0, 0.0)

var skill_cd: float = 0.0
var skill_max_cd: float = 10.0

var _cfg: Dictionary = {}
var _hero: Node3D = null
var _vfx_parent: Node3D = null
var _soldiers: Array[SoldierUnit] = []

var _hold_banner: Node3D = null
var _slot_rings_root: Node3D = null
var _slot_rings: Array[MeshInstance3D] = []

# Pending archer arrow-rain strikes
var _pending_rains: Array[Dictionary] = []


func _ready() -> void:
	_build_hold_banner()


func setup(hero: Node3D, vfx_parent: Node3D, p_regiment_type: String = "shieldmen") -> void:
	_hero = hero
	_vfx_parent = vfx_parent
	set_regiment(p_regiment_type)


func set_regiment(p_regiment_type: String) -> void:
	regiment_type = p_regiment_type
	_cfg = GameConfig.get_regiment(regiment_type)
	skill_max_cd = float(_cfg.get("skill_cd", 10.0))
	skill_cd = 0.0
	current_order = "follow"
	current_formation = "compact"

	var anchor: Vector3 = _hero.global_position if is_instance_valid(_hero) else Vector3(-15.0, 0.0, 0.0)
	_respawn_soldiers(anchor)
	_update_hold_banner_visibility()
	regiment_changed.emit(regiment_type)
	log_event.emit("切換兵團：%s" % str(_cfg.get("name", regiment_type)))


func reset_for_wave(spawn_pos: Vector3) -> void:
	skill_cd = 0.0
	current_order = "follow"
	hold_position = spawn_pos + Vector3(3.0, 0.0, 0.0)
	_clear_pending_rains()
	_respawn_soldiers(spawn_pos)
	_update_hold_banner_visibility()


func _respawn_soldiers(anchor: Vector3) -> void:
	for s in _soldiers:
		if is_instance_valid(s):
			s.queue_free()
	_soldiers.clear()

	if _cfg.is_empty():
		_cfg = GameConfig.get_regiment(regiment_type)

	var count: int = int(_cfg.get("count", 10))
	for i in range(count):
		var soldier := SoldierUnit.new()
		soldier.name = "Soldier_%d" % i
		add_child(soldier)
		soldier.configure(i, regiment_type, _cfg, _vfx_parent)
		var slot: Vector3 = _compute_slot_position(i, count, anchor)
		soldier.global_position = slot
		_soldiers.append(soldier)

	_apply_formation_modifiers()
	_rebuild_slot_rings(count)


func _build_hold_banner() -> void:
	_hold_banner = Node3D.new()
	_hold_banner.name = "HoldBanner"
	_hold_banner.visible = false
	add_child(_hold_banner)

	var pole := MeshInstance3D.new()
	var pole_cyl := CylinderMesh.new()
	pole_cyl.top_radius = 0.055
	pole_cyl.bottom_radius = 0.065
	pole_cyl.height = 3.2
	pole.mesh = pole_cyl
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.86, 0.72, 0.28)
	pole_mat.metallic = 0.75
	pole_mat.roughness = 0.3
	pole.material_override = pole_mat
	pole.position = Vector3(0.0, 1.6, 0.0)
	_hold_banner.add_child(pole)

	var flag := MeshInstance3D.new()
	var flag_box := BoxMesh.new()
	flag_box.size = Vector3(1.15, 0.68, 0.05)
	flag.mesh = flag_box
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.95, 0.76, 0.22)
	flag_mat.emission_enabled = true
	flag_mat.emission = Color(0.95, 0.72, 0.16)
	flag_mat.emission_energy_multiplier = 0.9
	flag.material_override = flag_mat
	flag.position = Vector3(0.58, 2.72, 0.0)
	_hold_banner.add_child(flag)

	var base_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.92
	base_ring.mesh = torus
	base_ring.material_override = flag_mat
	base_ring.position = Vector3(0.0, 0.06, 0.0)
	_hold_banner.add_child(base_ring)

	_slot_rings_root = Node3D.new()
	_slot_rings_root.name = "SlotRings"
	_slot_rings_root.visible = false
	add_child(_slot_rings_root)


func _rebuild_slot_rings(count: int) -> void:
	if _slot_rings_root == null:
		return
	for r in _slot_rings:
		if is_instance_valid(r):
			r.queue_free()
	_slot_rings.clear()

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.95, 0.8, 0.3, 0.55)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.95, 0.76, 0.24)
	ring_mat.emission_energy_multiplier = 0.85
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(count):
		var mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.34
		torus.outer_radius = 0.44
		torus.rings = 14
		mi.mesh = torus
		mi.material_override = ring_mat
		_slot_rings_root.add_child(mi)
		_slot_rings.append(mi)

	_update_slot_ring_positions()


func _update_hold_banner_visibility() -> void:
	var is_hold: bool = (current_order == "hold")
	if _hold_banner != null:
		_hold_banner.visible = is_hold
		_hold_banner.global_position = hold_position
	if _slot_rings_root != null:
		_slot_rings_root.visible = is_hold
	if is_hold:
		_update_slot_ring_positions()


func _update_slot_ring_positions() -> void:
	var count: int = _slot_rings.size()
	for i in range(count):
		var slot: Vector3 = _compute_slot_position(i, count, hold_position)
		_slot_rings[i].global_position = Vector3(slot.x, 0.05, slot.z)


func set_order(order: String, target_pos: Vector3 = Vector3.ZERO) -> void:
	if order not in ["follow", "hold", "engage"]:
		return
	current_order = order
	if order == "hold":
		var clamped: Vector3 = GameConfig.clamp_to_arena(target_pos, 1.5)
		clamped.x = maxf(clamped.x, GameConfig.GATE_X + 2.2)
		hold_position = Vector3(clamped.x, 0.0, clamped.z)
		if _vfx_parent != null:
			VfxFactory.spawn_ring(_vfx_parent, hold_position + Vector3(0.0, 0.1, 0.0), 2.4, Color(0.95, 0.78, 0.25), 0.35)
		log_event.emit("軍令 [X]：兵團列陣駐守指定防線！")
	elif order == "follow":
		log_event.emit("軍令 [C]：全軍收攏跟隨武將。")
	elif order == "engage":
		log_event.emit("軍令 [V]：全軍自由接敵衝鋒！")

	_update_hold_banner_visibility()
	order_changed.emit(current_order)


func set_formation(formation: String) -> void:
	if formation not in ["compact", "spread"]:
		return
	current_formation = formation
	_apply_formation_modifiers()
	if current_order == "hold":
		_update_slot_ring_positions()
	var label_key: String = "compact_label" if formation == "compact" else "spread_label"
	log_event.emit("切換陣型：%s" % str(_cfg.get(label_key, formation)))
	formation_changed.emit(current_formation)


func _apply_formation_modifiers() -> void:
	for s in _soldiers:
		if not is_instance_valid(s):
			continue
		if current_formation == "compact":
			s.damage_reduction_bonus = 0.25
			s.speed_mult = 0.94
		else:
			s.damage_reduction_bonus = 0.0
			s.speed_mult = 1.14


func _compute_slot_position(idx: int, total: int, anchor: Vector3) -> Vector3:
	var cols: int = 2
	var rows: int = maxi(1, int(ceil(float(total) / float(cols))))
	var col: int = idx / rows
	var row: int = idx % rows

	var spacing_x: float = 1.4 if current_formation == "compact" else 2.25
	var spacing_z: float = 1.35 if current_formation == "compact" else 2.35

	var offset_x: float = (0.5 - float(col)) * spacing_x
	if current_order == "follow":
		# Stay slightly behind/flanking the hero
		offset_x -= 1.8
	var offset_z: float = (float(row) - (float(rows - 1) * 0.5)) * spacing_z

	var pos := Vector3(anchor.x + offset_x, 0.0, anchor.z + offset_z)
	var clamped: Vector3 = GameConfig.clamp_to_arena(pos, 1.0)
	clamped.x = maxf(clamped.x, GameConfig.GATE_X + 1.6)
	return clamped


func trigger_skill(target_pos: Vector3) -> bool:
	if skill_cd > 0.0:
		return false
	var alive: Array[SoldierUnit] = _get_alive_soldiers()
	if alive.is_empty():
		return false

	skill_cd = skill_max_cd
	var clamped_target: Vector3 = GameConfig.clamp_to_arena(target_pos, 1.0)
	clamped_target.y = 0.0

	match regiment_type:
		"shieldmen":
			_execute_shield_charge(alive, clamped_target)
		"pikemen":
			_execute_pike_thrust(alive, clamped_target)
		"archers":
			_execute_arrow_rain(alive, clamped_target)
		_:
			_execute_shield_charge(alive, clamped_target)

	return true


func _execute_shield_charge(alive: Array[SoldierUnit], target_pos: Vector3) -> void:
	log_event.emit("兵團戰技 [F]：鐵衛刀盾兵發動「盾擊衝鋒」！")
	var base_dmg: float = float(_cfg.get("attack", 17.0)) * 2.3
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies") if is_inside_tree() else []

	for s in alive:
		var dir: Vector3 = target_pos - s.global_position
		dir.y = 0.0
		if dir.length() < 0.2:
			dir = Vector3(1.0, 0.0, 0.0)
		else:
			dir = dir.normalized()

		var from_p: Vector3 = s.global_position + Vector3(0.0, 0.8, 0.0)
		var to_p: Vector3 = from_p + dir * 4.5
		s.start_dash(dir * 13.0, 0.34)
		if _vfx_parent != null:
			VfxFactory.spawn_charge_trail(_vfx_parent, from_p, to_p, Color(0.32, 0.68, 1.0))

	if _vfx_parent != null:
		VfxFactory.spawn_ring(_vfx_parent, target_pos + Vector3(0.0, 0.15, 0.0), 4.2, Color(0.35, 0.72, 1.0), 0.4)

	var hit_enemies: Dictionary = {}
	for s in alive:
		for e in enemies:
			if not is_instance_valid(e) or not (e is Node3D) or hit_enemies.has(e):
				continue
			var e3 := e as Node3D
			if e3.global_position.distance_to(s.global_position) <= 5.5 or e3.global_position.distance_to(target_pos) <= 4.2:
				hit_enemies[e] = true
				var kb_dir: Vector3 = (e3.global_position - s.global_position)
				kb_dir.y = 0.0
				kb_dir = kb_dir.normalized() if kb_dir.length() > 0.05 else Vector3(1.0, 0.0, 0.0)
				if e3.has_method("take_damage"):
					e3.call("take_damage", base_dmg, kb_dir * 9.5, true)


func _execute_pike_thrust(alive: Array[SoldierUnit], target_pos: Vector3) -> void:
	log_event.emit("兵團戰技 [F]：拒馬長槍兵發動「疾風突刺」！")
	var base_dmg: float = float(_cfg.get("attack", 24.0)) * 2.5
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies") if is_inside_tree() else []

	for s in alive:
		var dir: Vector3 = target_pos - s.global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.1 else Vector3(1.0, 0.0, 0.0)
		s.start_dash(dir * 9.0, 0.22)
		if _vfx_parent != null:
			VfxFactory.spawn_charge_trail(
				_vfx_parent,
				s.global_position + Vector3(0.0, 0.9, 0.0),
				s.global_position + dir * 4.8 + Vector3(0.0, 0.9, 0.0),
				Color(0.25, 0.95, 0.85)
			)

	if _vfx_parent != null:
		VfxFactory.spawn_ring(_vfx_parent, target_pos + Vector3(0.0, 0.15, 0.0), 4.4, Color(0.25, 0.95, 0.85), 0.35)

	var hit_enemies: Dictionary = {}
	for s in alive:
		for e in enemies:
			if not is_instance_valid(e) or not (e is Node3D) or hit_enemies.has(e):
				continue
			var e3 := e as Node3D
			if e3.global_position.distance_to(s.global_position) <= 5.2 or e3.global_position.distance_to(target_pos) <= 4.4:
				hit_enemies[e] = true
				var kb_dir: Vector3 = (e3.global_position - s.global_position)
				kb_dir.y = 0.0
				kb_dir = kb_dir.normalized() if kb_dir.length() > 0.05 else Vector3(1.0, 0.0, 0.0)
				if e3.has_method("take_damage"):
					e3.call("take_damage", base_dmg, kb_dir * 6.0, true)


func _execute_arrow_rain(alive: Array[SoldierUnit], target_pos: Vector3) -> void:
	log_event.emit("兵團戰技 [F]：蒼穹長弓兵鎖定區域施放「指定箭雨」！")
	var rain_radius: float = 4.8

	# Glowing 3D target disc
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rain_radius
	cyl.bottom_radius = rain_radius
	cyl.height = 0.05
	cyl.radial_segments = 28
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.95, 0.56, 0.32)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.98, 0.62)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = mat
	disc.position = target_pos + Vector3(0.0, 0.07, 0.0)

	var parent_node: Node = _vfx_parent if _vfx_parent != null else self
	parent_node.add_child(disc)

	# Fire volley visuals immediately toward sky/target
	if _vfx_parent != null:
		for s in alive:
			for _k in range(2):
				var angle: float = randf_range(0.0, TAU)
				var rad: float = sqrt(randf()) * (rain_radius - 0.3)
				var landing := target_pos + Vector3(cos(angle) * rad, 0.2, sin(angle) * rad)
				VfxFactory.spawn_arrow(
					_vfx_parent,
					s.global_position + Vector3(0.0, 1.5, 0.0),
					landing,
					Color(0.42, 1.0, 0.62),
					0.55
				)

	var damage: float = float(_cfg.get("attack", 22.0)) * 2.8
	_pending_rains.append({
		"timer": 0.55,
		"pos": target_pos,
		"radius": rain_radius,
		"damage": damage,
		"disc": disc,
	})


func _clear_pending_rains() -> void:
	for r in _pending_rains:
		var disc = r.get("disc")
		if is_instance_valid(disc):
			disc.queue_free()
	_pending_rains.clear()


func apply_warcry(origin: Vector3, radius: float, duration: float) -> void:
	var buffed: int = 0
	for s in _soldiers:
		if not is_instance_valid(s) or s.is_dead:
			continue
		if s.global_position.distance_to(origin) <= radius + 4.0:
			s.warcry_timer = maxf(s.warcry_timer, duration)
			buffed += 1
	if buffed > 0:
		if _vfx_parent != null:
			VfxFactory.spawn_floating_text(_vfx_parent, origin + Vector3(0.0, 2.8, 0.0), "戰吼鼓舞 (%d名士兵)！" % buffed, Color(1.0, 0.86, 0.3), 24)
		log_event.emit("武將戰吼鼓舞了 %d 名兵團士兵！" % buffed)


func _physics_process(delta: float) -> void:
	if skill_cd > 0.0:
		skill_cd = maxf(0.0, skill_cd - delta)

	_process_pending_rains(delta)

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies") if is_inside_tree() else []
	var anchor: Vector3 = hold_position
	if current_order == "follow" and is_instance_valid(_hero):
		anchor = _hero.global_position

	var total: int = _soldiers.size()
	for i in range(total):
		var s: SoldierUnit = _soldiers[i]
		if not is_instance_valid(s) or s.is_dead:
			continue
		var slot_pos: Vector3 = _compute_slot_position(i, total, anchor)
		s.step_ai(delta, slot_pos, current_order, enemies)


func _process_pending_rains(delta: float) -> void:
	var i: int = _pending_rains.size() - 1
	while i >= 0:
		var r: Dictionary = _pending_rains[i]
		r["timer"] = float(r["timer"]) - delta
		if float(r["timer"]) <= 0.0:
			var pos: Vector3 = r["pos"]
			var radius: float = float(r["radius"])
			var dmg: float = float(r["damage"])
			var disc = r.get("disc")
			if is_instance_valid(disc):
				disc.queue_free()

			if _vfx_parent != null:
				VfxFactory.spawn_ring(_vfx_parent, pos + Vector3(0.0, 0.15, 0.0), radius, Color(0.4, 1.0, 0.6), 0.45)

			if is_inside_tree():
				var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
				for e in enemies:
					if not is_instance_valid(e) or not (e is Node3D):
						continue
					var e3 := e as Node3D
					var flat_d: float = Vector2(e3.global_position.x - pos.x, e3.global_position.z - pos.z).length()
					if flat_d <= radius and e3.has_method("take_damage"):
						e3.call("take_damage", dmg, Vector3(0.0, 0.0, 0.0), true)

			_pending_rains.remove_at(i)
		i -= 1


func _get_alive_soldiers() -> Array[SoldierUnit]:
	var alive: Array[SoldierUnit] = []
	for s in _soldiers:
		if is_instance_valid(s) and not s.is_dead:
			alive.append(s)
	return alive


func get_hud_state() -> Dictionary:
	var ratios: Array[float] = []
	var alive_count: int = 0
	for s in _soldiers:
		if is_instance_valid(s) and not s.is_dead:
			alive_count += 1
			ratios.append(clampf(s.hp / maxf(s.max_hp, 1.0), 0.0, 1.0))
		else:
			ratios.append(0.0)

	return {
		"type": regiment_type,
		"name": str(_cfg.get("name", regiment_type)),
		"description": str(_cfg.get("description", "")),
		"order": current_order,
		"formation": current_formation,
		"alive_count": alive_count,
		"max_count": _soldiers.size(),
		"skill_name": str(_cfg.get("skill_name", "兵團戰技")),
		"skill_cd": skill_cd,
		"skill_max_cd": skill_max_cd,
		"compact_label": str(_cfg.get("compact_label", "密集陣")),
		"spread_label": str(_cfg.get("spread_label", "散兵陣")),
		"soldier_hp_ratios": ratios,
	}
