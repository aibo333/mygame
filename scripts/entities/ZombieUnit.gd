class_name ZombieUnit
extends CharacterBody3D

signal died(zombie: ZombieUnit, archetype: String, death_pos: Vector3)
signal attacked_player(damage: float)
signal attacked_train(damage: float)

const ARCHETYPES: Dictionary = {
	"walker": {
		"label": "漫遊者",
		"hp": 65.0,
		"speed": 2.75,
		"damage": 10.0,
		"attack_cd": 1.15,
		"scale": 1.0,
		"body_color": Color(0.36, 0.44, 0.34),
		"head_color": Color(0.52, 0.60, 0.46),
		"eye_color": Color(0.95, 0.92, 0.40),
		"prioritize_train": false,
		"explodes": false,
	},
	"runner": {
		"label": "疾行者",
		"hp": 42.0,
		"speed": 5.15,
		"damage": 8.0,
		"attack_cd": 0.78,
		"scale": 0.90,
		"body_color": Color(0.54, 0.24, 0.24),
		"head_color": Color(0.68, 0.42, 0.38),
		"eye_color": Color(1.0, 0.32, 0.22),
		"prioritize_train": false,
		"explodes": false,
	},
	"brute": {
		"label": "重甲撞擊者",
		"hp": 210.0,
		"speed": 2.15,
		"damage": 26.0,
		"attack_cd": 1.45,
		"scale": 1.42,
		"body_color": Color(0.28, 0.30, 0.36),
		"head_color": Color(0.44, 0.46, 0.50),
		"eye_color": Color(1.0, 0.58, 0.16),
		"prioritize_train": true,
		"explodes": false,
	},
	"bloater": {
		"label": "毒霧自爆體",
		"hp": 95.0,
		"speed": 2.35,
		"damage": 14.0,
		"attack_cd": 1.30,
		"scale": 1.22,
		"body_color": Color(0.30, 0.52, 0.24),
		"head_color": Color(0.56, 0.76, 0.36),
		"eye_color": Color(0.60, 1.0, 0.24),
		"prioritize_train": false,
		"explodes": true,
		"elite": false,
	},
	"blood_elite": {
		"label": "血月獵殺者",
		"hp": 260.0,
		"speed": 3.85,
		"damage": 30.0,
		"attack_cd": 1.05,
		"scale": 1.38,
		"body_color": Color(0.36, 0.08, 0.12),
		"head_color": Color(0.58, 0.16, 0.22),
		"eye_color": Color(1.0, 0.16, 0.28),
		"prioritize_train": false,
		"explodes": false,
		"elite": true,
	},
}

enum BehaviorMode {
	ROAMER,
	SIEGE,
}

enum AlertState {
	IDLE_PATROL,
	INVESTIGATE_NOISE,
	CHASE,
}

var archetype: String = "walker"
var max_hp: float = 65.0
var hp: float = 65.0
var move_speed: float = 2.75
var attack_damage: float = 10.0
var attack_interval: float = 1.15
var prioritize_train: bool = false
var explodes_on_death: bool = false
var is_elite: bool = false
var is_alive: bool = false

var behavior_mode: int = BehaviorMode.SIEGE
var alert_state: int = AlertState.CHASE
var is_indoor_spawn: bool = false
var sight_range: float = 11.5
var sight_half_angle_deg: float = 65.0
var patrol_anchor: Vector3 = Vector3.ZERO
var patrol_target: Vector3 = Vector3.ZERO
var investigate_pos: Vector3 = Vector3.ZERO
var investigate_timer: float = 0.0
var _patrol_wait_timer: float = 0.0
var _facing_dir: Vector3 = Vector3(0.0, 0.0, 1.0)

var _visual_root: Node3D = null
var _stickman_rig: Dictionary = {}
var _left_arm: Node3D = null
var _right_arm: Node3D = null
var _left_leg: Node3D = null
var _right_leg: Node3D = null
var _eye_l: MeshInstance3D = null
var _eye_r: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _head_mat: StandardMaterial3D = null
var _hp_bar_root: Node3D = null
var _hp_bar_fill: MeshInstance3D = null
var _attack_cd: float = 0.0
var _hit_flash_timer: float = 0.0
var _wobble_phase: float = 0.0
var _base_body_color: Color = Color(0.36, 0.44, 0.34)
var is_stickman: bool = true


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("zombies")
	_build_visuals()
	deactivate()


func _build_visuals() -> void:
	if _visual_root != null:
		return

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "ZombieCollision"
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.75
	col.shape = cap
	col.position = Vector3(0.0, 0.88, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	_visual_root.name = "ZombieVisual"
	add_child(_visual_root)

	_stickman_rig = StickmanFactory.create_stickman({
		"name": "ZombieStickmanRig",
		"body_color": Color(0.36, 0.44, 0.34),
		"head_color": Color(0.52, 0.60, 0.46),
		"eye_color": Color(1.0, 0.4, 0.2),
		"emit_eyes": true,
		"limb_thickness": 0.068,
		"accessory": "zombie",
	})
	var rig_root: Node3D = _stickman_rig["root"] as Node3D
	_visual_root.add_child(rig_root)

	_body_mat = _stickman_rig["body_mat"] as StandardMaterial3D
	_head_mat = _stickman_rig["head_mat"] as StandardMaterial3D
	_left_arm = _stickman_rig["left_arm"] as Node3D
	_right_arm = _stickman_rig["right_arm"] as Node3D
	_left_leg = _stickman_rig["left_leg"] as Node3D
	_right_leg = _stickman_rig["right_leg"] as Node3D
	_eye_l = _stickman_rig["eye_l"] as MeshInstance3D
	_eye_r = _stickman_rig["eye_r"] as MeshInstance3D

	# Outstretched zombie stickman arms!
	_left_arm.rotation_degrees.x = 84.0
	_right_arm.rotation_degrees.x = 84.0

	# Mini world-space HP bar (shown once damaged)
	_hp_bar_root = Node3D.new()
	_hp_bar_root.name = "ZombieHpBar"
	_hp_bar_root.position = Vector3(0.0, 2.05, 0.0)
	_hp_bar_root.rotation_degrees = Vector3(-34.0, 0.0, 0.0)
	_hp_bar_root.visible = false
	add_child(_hp_bar_root)

	var bg: MeshInstance3D = MeshInstance3D.new()
	var bg_box: BoxMesh = BoxMesh.new()
	bg_box.size = Vector3(0.92, 0.10, 0.04)
	bg.mesh = bg_box
	var bg_mat: StandardMaterial3D = StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.10, 0.9)
	bg.material_override = bg_mat
	_hp_bar_root.add_child(bg)

	_hp_bar_fill = MeshInstance3D.new()
	var fill_box: BoxMesh = BoxMesh.new()
	fill_box.size = Vector3(0.86, 0.065, 0.05)
	_hp_bar_fill.mesh = fill_box
	var fill_mat: StandardMaterial3D = StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.96, 0.28, 0.24)
	fill_mat.emission_enabled = true
	fill_mat.emission = Color(0.96, 0.28, 0.24)
	fill_mat.emission_energy_multiplier = 1.6
	_hp_bar_fill.material_override = fill_mat
	_hp_bar_root.add_child(_hp_bar_fill)


func activate(p_archetype: String, spawn_pos: Vector3, hp_mult: float = 1.0, speed_mult: float = 1.0) -> void:
	if _visual_root == null:
		_build_visuals()
	archetype = p_archetype if ARCHETYPES.has(p_archetype) else "walker"
	var cfg: Dictionary = ARCHETYPES[archetype] as Dictionary
	max_hp = float(cfg.get("hp", 65.0)) * hp_mult
	hp = max_hp
	move_speed = float(cfg.get("speed", 2.75)) * speed_mult
	attack_damage = float(cfg.get("damage", 10.0))
	attack_interval = float(cfg.get("attack_cd", 1.15))
	prioritize_train = bool(cfg.get("prioritize_train", false))
	explodes_on_death = bool(cfg.get("explodes", false))
	is_elite = bool(cfg.get("elite", false))

	behavior_mode = BehaviorMode.SIEGE
	alert_state = AlertState.CHASE
	is_indoor_spawn = false
	patrol_anchor = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	patrol_target = patrol_anchor
	investigate_timer = 0.0
	_patrol_wait_timer = 0.0
	var ang: float = randf() * TAU
	_facing_dir = Vector3(cos(ang), 0.0, sin(ang)).normalized()

	var sc: float = float(cfg.get("scale", 1.0))
	_visual_root.scale = Vector3(sc * (1.25 if archetype == "bloater" else 1.0), sc, sc * (1.25 if archetype == "bloater" else 1.0))
	_base_body_color = cfg.get("body_color", Color(0.36, 0.44, 0.34)) as Color
	_body_mat.albedo_color = _base_body_color
	_body_mat.emission_enabled = is_elite
	if is_elite:
		_body_mat.emission = Color(0.65, 0.08, 0.14)
		_body_mat.emission_energy_multiplier = 0.85
	_head_mat.albedo_color = cfg.get("head_color", Color(0.52, 0.60, 0.46)) as Color

	var eye_col: Color = cfg.get("eye_color", Color(1.0, 0.4, 0.2)) as Color
	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = eye_col
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_col
	eye_mat.emission_energy_multiplier = 2.8
	_eye_l.material_override = eye_mat
	_eye_r.material_override = eye_mat

	_attack_cd = 0.25
	_hit_flash_timer = 0.0
	_wobble_phase = randf() * TAU
	_hp_bar_root.visible = false
	_hp_bar_root.position.y = 1.95 * sc + 0.2
	global_position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	velocity = Vector3.ZERO
	is_alive = true
	visible = true
	set_physics_process(false)


func deactivate() -> void:
	is_alive = false
	visible = false
	velocity = Vector3.ZERO
	if _hp_bar_root != null:
		_hp_bar_root.visible = false
	global_position = Vector3(0.0, -40.0, 0.0)


func apply_damage(amount: float) -> bool:
	if not is_alive or amount <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	_hit_flash_timer = 0.11
	_body_mat.albedo_color = Color(1.0, 0.88, 0.82)
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(1.0, 0.48, 0.34)
	_body_mat.emission_energy_multiplier = 1.8

	_hp_bar_root.visible = hp < max_hp and hp > 0.0
	var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.02, 1.0)
	_hp_bar_fill.scale.x = ratio
	_hp_bar_fill.position.x = -(1.0 - ratio) * 0.43

	if hp <= 0.0:
		var death_pos: Vector3 = global_position
		var dead_type: String = archetype
		deactivate()
		died.emit(self, dead_type, death_pos)
		return true
	return false


func setup_roamer(anchor_pos: Vector3, indoor: bool = false) -> void:
	behavior_mode = BehaviorMode.ROAMER
	alert_state = AlertState.IDLE_PATROL
	is_indoor_spawn = indoor
	patrol_anchor = Vector3(anchor_pos.x, 0.0, anchor_pos.z)
	patrol_target = patrol_anchor
	investigate_timer = 0.0
	_patrol_wait_timer = randf_range(0.4, 1.8)


func set_siege_mode() -> void:
	behavior_mode = BehaviorMode.SIEGE
	alert_state = AlertState.CHASE


func hear_noise(noise_pos: Vector3, noise_radius: float) -> bool:
	if not is_alive or behavior_mode != BehaviorMode.ROAMER:
		return false
	var dist: float = Vector2(noise_pos.x - global_position.x, noise_pos.z - global_position.z).length()
	if dist > noise_radius:
		return false
	investigate_pos = Vector3(noise_pos.x, 0.0, noise_pos.z)
	investigate_timer = 7.0
	if dist <= 6.5:
		alert_state = AlertState.CHASE
	elif alert_state != AlertState.CHASE:
		alert_state = AlertState.INVESTIGATE_NOISE
	return true


func _can_see_player(player_pos: Vector3, player_alive: bool) -> bool:
	if not player_alive:
		return false
	var to_p: Vector3 = Vector3(player_pos.x - global_position.x, 0.0, player_pos.z - global_position.z)
	var dist: float = to_p.length()
	if dist <= 4.2:
		return true
	if dist > sight_range:
		return false
	var dir_to_p: Vector3 = to_p / maxf(0.001, dist)
	var cos_limit: float = cos(deg_to_rad(sight_half_angle_deg))
	return _facing_dir.dot(dir_to_p) >= cos_limit


func tick_zombie(delta: float, player_pos: Vector3, player_alive: bool, train_target_pos: Vector3, tesla_slow_active: bool, cam_yaw_rad: float) -> void:
	if not is_alive:
		return

	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		if _hit_flash_timer <= 0.0:
			_body_mat.albedo_color = _base_body_color
			_body_mat.emission_enabled = is_elite

	if _hp_bar_root != null and _hp_bar_root.visible:
		_hp_bar_root.rotation = Vector3(deg_to_rad(-34.0), cam_yaw_rad, 0.0)

	var dist_player: float = Vector2(player_pos.x - global_position.x, player_pos.z - global_position.z).length()
	var dist_train: float = Vector2(train_target_pos.x - global_position.x, train_target_pos.z - global_position.z).length()

	if behavior_mode == BehaviorMode.ROAMER:
		if _can_see_player(player_pos, player_alive):
			alert_state = AlertState.CHASE
		elif alert_state == AlertState.CHASE and (not player_alive or dist_player > sight_range * 1.9):
			alert_state = AlertState.INVESTIGATE_NOISE
			investigate_pos = Vector3(player_pos.x, 0.0, player_pos.z)
			investigate_timer = 5.0

		if alert_state == AlertState.IDLE_PATROL:
			var to_patrol: Vector3 = Vector3(patrol_target.x - global_position.x, 0.0, patrol_target.z - global_position.z)
			var pdist: float = to_patrol.length()
			if pdist <= 0.45:
				velocity = Vector3.ZERO
				_patrol_wait_timer -= delta
				if _patrol_wait_timer <= 0.0:
					_patrol_wait_timer = randf_range(1.0, 2.8)
					var r_ang: float = randf() * TAU
					var r_rad: float = randf_range(1.2, 2.8 if is_indoor_spawn else 4.5)
					patrol_target = patrol_anchor + Vector3(cos(r_ang) * r_rad, 0.0, sin(r_ang) * r_rad)
			else:
				var pdir: Vector3 = to_patrol / maxf(0.001, pdist)
				_facing_dir = pdir
				velocity = pdir * (move_speed * 0.45)
				move_and_slide()
				global_position.y = 0.0
				var pyaw: float = atan2(-pdir.x, -pdir.z)
				_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, pyaw, clampf(delta * 8.0, 0.0, 1.0))
			_animate_limb_wobble(delta, 0.45)
			return

		if alert_state == AlertState.INVESTIGATE_NOISE:
			investigate_timer -= delta
			var to_inv: Vector3 = Vector3(investigate_pos.x - global_position.x, 0.0, investigate_pos.z - global_position.z)
			var idist: float = to_inv.length()
			if idist <= 1.25 or investigate_timer <= 0.0:
				alert_state = AlertState.IDLE_PATROL
				patrol_anchor = Vector3(global_position.x, 0.0, global_position.z)
				patrol_target = patrol_anchor
				_patrol_wait_timer = 1.2
				velocity = Vector3.ZERO
				return
			var idir: Vector3 = to_inv / maxf(0.001, idist)
			_facing_dir = idir
			velocity = idir * (move_speed * 0.78)
			move_and_slide()
			global_position.y = 0.0
			var iyaw: float = atan2(-idir.x, -idir.z)
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, iyaw, clampf(delta * 9.0, 0.0, 1.0))
			_animate_limb_wobble(delta, 0.78)
			return

	var target_is_train: bool = (behavior_mode == BehaviorMode.SIEGE) and ((not player_alive) or prioritize_train or (dist_train < 5.5 and dist_player > 4.2))
	var target_pos: Vector3 = train_target_pos if target_is_train else player_pos
	var to_target: Vector3 = Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
	var dist: float = to_target.length()

	var attack_reach: float = 2.45 if target_is_train else 1.25
	if dist <= attack_reach:
		velocity = Vector3.ZERO
		if _attack_cd <= 0.0:
			_attack_cd = attack_interval
			if target_is_train:
				attacked_train.emit(attack_damage)
			else:
				attacked_player.emit(attack_damage)
	else:
		var dir: Vector3 = to_target / maxf(0.001, dist)
		_facing_dir = dir
		var speed_factor: float = 0.65 if (tesla_slow_active and dist_train < 8.5) else 1.0
		velocity = dir * (move_speed * speed_factor)
		move_and_slide()
		global_position.y = 0.0
		var yaw: float = atan2(-dir.x, -dir.z)
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, yaw, clampf(delta * 10.0, 0.0, 1.0))

	_animate_limb_wobble(delta, 1.0)


func _animate_limb_wobble(delta: float, speed_scale: float) -> void:
	_wobble_phase += delta * (move_speed * 3.1 * speed_scale)
	var stride: float = sin(_wobble_phase)
	_visual_root.rotation.z = stride * 0.075
	if _left_leg != null and _right_leg != null:
		_left_leg.rotation.x = stride * 0.62
		_right_leg.rotation.x = -stride * 0.62
	if _left_arm != null and _right_arm != null:
		_left_arm.rotation_degrees.x = 82.0 + stride * 14.0
		_right_arm.rotation_degrees.x = 82.0 - stride * 14.0
