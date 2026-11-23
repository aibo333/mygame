class_name HeroController
extends CharacterBody3D

signal camera_mode_changed(is_tps: bool)
signal log_event(message: String)
signal warcry_triggered(origin: Vector3, radius: float)

@export var hero_name: String = "艾莉絲"
@export var max_hp: float = 360.0
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 24.0
@export var base_attack: float = 38.0
@export var move_speed: float = 7.4
@export var mouse_sensitivity: float = 0.0032
@export var custom_model_scene: PackedScene

const MELEE_RANGE: float = 3.8
const MELEE_COOLDOWN: float = 0.34
const COMBO_RESET_TIME: float = 1.15
const DODGE_COST: float = 30.0
const DODGE_DURATION: float = 0.26
const DODGE_IFRAMES: float = 0.28
const DODGE_SPEED: float = 17.5
const SKILL1_MAX_CD: float = 6.0
const SKILL1_DISTANCE: float = 10.5
const SKILL1_DURATION: float = 0.24
const SKILL2_MAX_CD: float = 12.0
const WARCRY_DURATION: float = 6.0
const WARCRY_RADIUS: float = 12.0
const RESPAWN_DURATION: float = 6.0

var hp: float = 360.0
var stamina: float = 100.0
var alive: bool = true
var respawn_timer: float = 0.0

var combo_step: int = 0
var combo_reset_timer: float = 0.0
var attack_cd_timer: float = 0.0
var swing_timer: float = 0.0
var swing_duration: float = 0.24
var swing_combo_index: int = 0

var invuln_timer: float = 0.0
var dodge_timer: float = 0.0
var dodge_dir: Vector3 = Vector3.RIGHT

var skill1_cd: float = 0.0
var skill2_cd: float = 0.0
var warcry_timer: float = 0.0

var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.RIGHT
var dash_speed: float = 42.0
var dash_start_pos: Vector3 = Vector3.ZERO
var dash_hit_ids: Dictionary = {}

var kills: int = 0
var damage_dealt: float = 0.0

var is_tps: bool = true
var tps_yaw: float = -PI * 0.5
var tps_pitch: float = -0.34
var facing_yaw: float = -PI * 0.5
var run_cycle: float = 0.0

var vfx_parent: Node3D = null

var camera_pivot: Node3D = null
var spring_arm: SpringArm3D = null
var tps_camera: Camera3D = null
var tactical_camera: Camera3D = null

var visual_root: Node3D = null
var weapon_pivot: Node3D = null
var cape_mesh: MeshInstance3D = null
var warcry_ring: MeshInstance3D = null
var dodge_shell: MeshInstance3D = null


func _ready() -> void:
	add_to_group("hero")
	collision_layer = 2
	collision_mask = 1

	hp = max_hp
	stamina = max_stamina

	_build_collision()
	_build_visual_rig()
	_build_cameras()
	_apply_camera_mode(false)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.9
	col.shape = capsule
	col.position = Vector3(0.0, 0.95, 0.0)
	add_child(col)


func _make_mat(color: Color, metallic: float = 0.2, roughness: float = 0.55, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


func _build_visual_rig() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.rotation.y = facing_yaw
	add_child(visual_root)

	if custom_model_scene != null:
		var custom_node := custom_model_scene.instantiate()
		visual_root.add_child(custom_node)
	else:
		_build_valkyrie_mesh(visual_root)

	# Ground golden warcry aura ring
	warcry_ring = MeshInstance3D.new()
	warcry_ring.name = "WarcryRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.12
	ring_mesh.outer_radius = 1.32
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	warcry_ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.82, 0.22, 0.85)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.78, 0.18, 1.0)
	ring_mat.emission_energy_multiplier = 2.0
	warcry_ring.material_override = ring_mat
	warcry_ring.position = Vector3(0.0, 0.08, 0.0)
	warcry_ring.scale = Vector3(1.0, 0.16, 1.0)
	warcry_ring.visible = false
	visual_root.add_child(warcry_ring)

	# Translucent cyan dodge invulnerability shell
	dodge_shell = MeshInstance3D.new()
	dodge_shell.name = "DodgeShell"
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 1.05
	shell_mesh.height = 2.1
	shell_mesh.radial_segments = 14
	shell_mesh.rings = 8
	dodge_shell.mesh = shell_mesh
	var shell_mat := StandardMaterial3D.new()
	shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_mat.albedo_color = Color(0.28, 0.78, 1.0, 0.34)
	shell_mat.emission_enabled = true
	shell_mat.emission = Color(0.25, 0.82, 1.0, 1.0)
	shell_mat.emission_energy_multiplier = 1.6
	dodge_shell.material_override = shell_mat
	dodge_shell.position = Vector3(0.0, 1.0, 0.0)
	dodge_shell.visible = false
	visual_root.add_child(dodge_shell)


func _build_valkyrie_mesh(parent_node: Node3D) -> void:
	var steel_mat := _make_mat(Color(0.76, 0.80, 0.86), 0.72, 0.32)
	var dark_steel_mat := _make_mat(Color(0.24, 0.27, 0.34), 0.65, 0.42)
	var gold_mat := _make_mat(Color(0.95, 0.76, 0.24), 0.85, 0.25, Color(0.95, 0.72, 0.18), 0.35)
	var crimson_mat := _make_mat(Color(0.76, 0.12, 0.16), 0.1, 0.72)
	var skin_mat := _make_mat(Color(0.93, 0.80, 0.70), 0.0, 0.75)

	# Legs
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_box := BoxMesh.new()
		leg_box.size = Vector3(0.22, 0.72, 0.24)
		leg.mesh = leg_box
		leg.material_override = dark_steel_mat
		leg.position = Vector3(side * 0.18, 0.36, 0.0)
		parent_node.add_child(leg)

	# Armored torso
	var torso := MeshInstance3D.new()
	var torso_box := BoxMesh.new()
	torso_box.size = Vector3(0.62, 0.76, 0.38)
	torso.mesh = torso_box
	torso.material_override = steel_mat
	torso.position = Vector3(0.0, 1.06, 0.0)
	parent_node.add_child(torso)

	# Gold chest emblem
	var trim := MeshInstance3D.new()
	var trim_box := BoxMesh.new()
	trim_box.size = Vector3(0.46, 0.28, 0.41)
	trim.mesh = trim_box
	trim.material_override = gold_mat
	trim.position = Vector3(0.0, 1.15, 0.0)
	parent_node.add_child(trim)

	# Waist skirt / tassets
	var skirt := MeshInstance3D.new()
	var skirt_cyl := CylinderMesh.new()
	skirt_cyl.top_radius = 0.28
	skirt_cyl.bottom_radius = 0.40
	skirt_cyl.height = 0.32
	skirt_cyl.radial_segments = 8
	skirt.mesh = skirt_cyl
	skirt.material_override = crimson_mat
	skirt.position = Vector3(0.0, 0.64, 0.0)
	parent_node.add_child(skirt)

	# Shoulder pauldrons
	for side in [-1.0, 1.0]:
		var pauldron := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(0.26, 0.24, 0.36)
		pauldron.mesh = p_box
		pauldron.material_override = gold_mat
		pauldron.position = Vector3(side * 0.42, 1.34, 0.0)
		pauldron.rotation.z = -side * 0.22
		parent_node.add_child(pauldron)

	# Head + Golden Winged Helm
	var head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.32, 0.32, 0.32)
	head.mesh = head_box
	head.material_override = skin_mat
	head.position = Vector3(0.0, 1.60, 0.0)
	parent_node.add_child(head)

	var helm := MeshInstance3D.new()
	var helm_cyl := CylinderMesh.new()
	helm_cyl.top_radius = 0.16
	helm_cyl.bottom_radius = 0.21
	helm_cyl.height = 0.24
	helm_cyl.radial_segments = 8
	helm.mesh = helm_cyl
	helm.material_override = gold_mat
	helm.position = Vector3(0.0, 1.72, 0.0)
	parent_node.add_child(helm)

	# Winged helm crests
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wing_box := BoxMesh.new()
		wing_box.size = Vector3(0.06, 0.34, 0.24)
		wing.mesh = wing_box
		wing.material_override = gold_mat
		wing.position = Vector3(side * 0.24, 1.80, 0.06)
		wing.rotation = Vector3(-0.35, side * 0.22, -side * 0.48)
		parent_node.add_child(wing)

	# Crimson cape (back is +Z because forward is -Z)
	cape_mesh = MeshInstance3D.new()
	var cape_box := BoxMesh.new()
	cape_box.size = Vector3(0.62, 1.05, 0.06)
	cape_mesh.mesh = cape_box
	cape_mesh.material_override = crimson_mat
	cape_mesh.position = Vector3(0.0, 0.94, 0.27)
	cape_mesh.rotation.x = 0.20
	parent_node.add_child(cape_mesh)

	# Left-hand kite shield
	var shield_pivot := Node3D.new()
	shield_pivot.position = Vector3(-0.46, 1.04, -0.20)
	shield_pivot.rotation.y = 0.32
	parent_node.add_child(shield_pivot)

	var shield_body := MeshInstance3D.new()
	var shield_box := BoxMesh.new()
	shield_box.size = Vector3(0.10, 0.78, 0.52)
	shield_body.mesh = shield_box
	shield_body.material_override = steel_mat
	shield_pivot.add_child(shield_body)

	var shield_boss := MeshInstance3D.new()
	var boss_box := BoxMesh.new()
	boss_box.size = Vector3(0.14, 0.42, 0.14)
	shield_boss.mesh = boss_box
	shield_boss.material_override = gold_mat
	shield_pivot.add_child(shield_boss)

	# Right-hand sword pivot for crisp swing animations
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.position = Vector3(0.48, 1.06, -0.14)
	parent_node.add_child(weapon_pivot)

	var grip := MeshInstance3D.new()
	var grip_cyl := CylinderMesh.new()
	grip_cyl.top_radius = 0.035
	grip_cyl.bottom_radius = 0.035
	grip_cyl.height = 0.28
	grip_cyl.radial_segments = 6
	grip.mesh = grip_cyl
	grip.material_override = dark_steel_mat
	grip.position = Vector3(0.0, 0.0, -0.14)
	grip.rotation.x = PI * 0.5
	weapon_pivot.add_child(grip)

	var guard := MeshInstance3D.new()
	var guard_box := BoxMesh.new()
	guard_box.size = Vector3(0.32, 0.06, 0.07)
	guard.mesh = guard_box
	guard.material_override = gold_mat
	guard.position = Vector3(0.0, 0.0, -0.28)
	weapon_pivot.add_child(guard)

	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.09, 0.035, 1.28)
	blade.mesh = blade_box
	blade.material_override = _make_mat(Color(0.92, 0.96, 1.0), 0.9, 0.16, Color(0.65, 0.85, 1.0), 0.3)
	blade.position = Vector3(0.0, 0.0, -0.94)
	weapon_pivot.add_child(blade)


func _build_cameras() -> void:
	# Native Godot 4 SpringArm3D TPS rig
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 1.9, 0.0)
	camera_pivot.rotation = Vector3(tps_pitch, tps_yaw, 0.0)
	add_child(camera_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.position = Vector3(0.9, 0.0, 0.0)
	spring_arm.spring_length = 8.5
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.35
	spring_arm.add_excluded_object(get_rid())
	camera_pivot.add_child(spring_arm)

	tps_camera = Camera3D.new()
	tps_camera.name = "TpsCamera"
	tps_camera.fov = 65.0
	tps_camera.near = 0.1
	tps_camera.far = 160.0
	spring_arm.add_child(tps_camera)

	# Separate angled top-down tactical camera
	tactical_camera = Camera3D.new()
	tactical_camera.name = "TacticalCamera"
	tactical_camera.top_level = true
	tactical_camera.fov = 48.0
	tactical_camera.near = 0.2
	tactical_camera.far = 200.0
	add_child(tactical_camera)
	_snap_tactical_camera()


func _snap_tactical_camera() -> void:
	if tactical_camera == null:
		return
	var target_pos: Vector3 = global_position + Vector3(0.0, 18.5, 15.0)
	tactical_camera.global_position = target_pos
	tactical_camera.look_at(global_position + Vector3(0.0, 0.6, -1.0), Vector3.UP)


func _apply_camera_mode(emit_signal_flag: bool) -> void:
	if tps_camera != null:
		tps_camera.current = is_tps
	if tactical_camera != null:
		tactical_camera.current = not is_tps
	if not is_tps:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_snap_tactical_camera()
	if emit_signal_flag:
		camera_mode_changed.emit(is_tps)
		log_event.emit("視角切換：%s" % ("第三人稱肩後視角 (TPS)" if is_tps else "戰術俯視視角"))


func set_vfx_parent(node: Node3D) -> void:
	vfx_parent = node


func is_tps_mode() -> bool:
	return is_tps


func toggle_camera_mode() -> void:
	is_tps = not is_tps
	_apply_camera_mode(true)


func reset_for_wave(spawn_pos: Vector3) -> void:
	global_position = GameConfig.clamp_to_arena(Vector3(spawn_pos.x, 0.0, spawn_pos.z))
	velocity = Vector3.ZERO
	hp = max_hp
	stamina = max_stamina
	alive = true
	respawn_timer = 0.0
	invuln_timer = 0.8
	dodge_timer = 0.0
	dash_timer = 0.0
	combo_step = 0
	combo_reset_timer = 0.0
	attack_cd_timer = 0.0
	skill1_cd = 0.0
	skill2_cd = 0.0
	warcry_timer = 0.0
	facing_yaw = -PI * 0.5
	tps_yaw = -PI * 0.5
	if visual_root != null:
		visual_root.visible = true
		visual_root.rotation.y = facing_yaw
	if camera_pivot != null:
		camera_pivot.rotation = Vector3(tps_pitch, tps_yaw, 0.0)
	_snap_tactical_camera()


func get_aim_ground_point() -> Vector3:
	var active_cam: Camera3D = tps_camera if is_tps else tactical_camera
	if active_cam == null:
		return GameConfig.clamp_to_arena(global_position + _get_facing_forward() * 6.0)

	var vp := get_viewport()
	if vp == null:
		return GameConfig.clamp_to_arena(global_position + _get_facing_forward() * 6.0)

	var screen_pt: Vector2 = vp.get_visible_rect().size * 0.5 if is_tps else vp.get_mouse_position()
	var ray_origin: Vector3 = active_cam.project_ray_origin(screen_pt)
	var ray_dir: Vector3 = active_cam.project_ray_normal(screen_pt)
	var ground_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)
	if hit is Vector3:
		return GameConfig.clamp_to_arena(hit as Vector3)

	var fallback_fwd := -active_cam.global_transform.basis.z
	fallback_fwd.y = 0.0
	if fallback_fwd.length_squared() < 0.001:
		fallback_fwd = Vector3.RIGHT
	return GameConfig.clamp_to_arena(global_position + fallback_fwd.normalized() * 8.0)


func get_hud_state() -> Dictionary:
	return {
		"name": hero_name,
		"hp": hp,
		"max_hp": max_hp,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"alive": alive,
		"respawn_sec": respawn_timer,
		"combo_step": combo_step,
		"skill1_cd": skill1_cd,
		"skill1_max_cd": SKILL1_MAX_CD,
		"skill2_cd": skill2_cd,
		"skill2_max_cd": SKILL2_MAX_CD,
		"warcry_sec": warcry_timer,
		"kills": kills,
		"damage_dealt": damage_dealt,
		"is_tps": is_tps,
		"mouse_captured": Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED,
	}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		toggle_camera_mode()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		if is_tps and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var motion := event as InputEventMouseMotion
			tps_yaw -= motion.relative.x * mouse_sensitivity
			tps_pitch = clampf(tps_pitch - motion.relative.y * mouse_sensitivity, -0.95, -0.12)
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if is_tps and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				get_viewport().set_input_as_handled()
				return
			_try_melee_attack()
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_try_skill_1()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("dodge"):
		_try_dodge()
	elif event.is_action_pressed("skill_1"):
		_try_skill_1()
	elif event.is_action_pressed("skill_2"):
		_try_skill_2()


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_cameras(delta)

	if not alive:
		velocity = Vector3.ZERO
		return

	var move_dir: Vector3 = _get_camera_relative_move_dir()

	if dash_timer > 0.0:
		dash_timer = maxf(dash_timer - delta, 0.0)
		velocity = dash_dir * dash_speed
		_check_dash_hits()
	elif dodge_timer > 0.0:
		dodge_timer = maxf(dodge_timer - delta, 0.0)
		velocity = dodge_dir * DODGE_SPEED
	else:
		var speed_mult: float = 1.20 if warcry_timer > 0.0 else 1.0
		velocity = move_dir * (move_speed * speed_mult)
		if move_dir.length_squared() > 0.01:
			var target_yaw: float = atan2(-move_dir.x, -move_dir.z)
			facing_yaw = lerp_angle(facing_yaw, target_yaw, minf(delta * 14.0, 1.0))

	move_and_slide()
	var clamped: Vector3 = GameConfig.clamp_to_arena(global_position, 0.8)
	global_position.x = clamped.x
	global_position.y = 0.0
	global_position.z = clamped.z

	_update_visuals(delta, move_dir)


func _update_timers(delta: float) -> void:
	if attack_cd_timer > 0.0:
		attack_cd_timer = maxf(attack_cd_timer - delta, 0.0)
	if combo_reset_timer > 0.0:
		combo_reset_timer = maxf(combo_reset_timer - delta, 0.0)
		if combo_reset_timer <= 0.0:
			combo_step = 0
	if invuln_timer > 0.0:
		invuln_timer = maxf(invuln_timer - delta, 0.0)
	if skill1_cd > 0.0:
		skill1_cd = maxf(skill1_cd - delta, 0.0)
	if skill2_cd > 0.0:
		skill2_cd = maxf(skill2_cd - delta, 0.0)
	if warcry_timer > 0.0:
		warcry_timer = maxf(warcry_timer - delta, 0.0)
	if swing_timer > 0.0:
		swing_timer = maxf(swing_timer - delta, 0.0)

	if alive:
		if stamina < max_stamina and dodge_timer <= 0.0:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
	else:
		respawn_timer = maxf(respawn_timer - delta, 0.0)
		if respawn_timer <= 0.0:
			_respawn_hero()


func _update_cameras(delta: float) -> void:
	if camera_pivot != null:
		camera_pivot.rotation = Vector3(tps_pitch, tps_yaw, 0.0)

	if tactical_camera != null:
		var desired_pos: Vector3 = global_position + Vector3(0.0, 18.5, 15.0)
		tactical_camera.global_position = tactical_camera.global_position.lerp(desired_pos, minf(delta * 8.0, 1.0))
		tactical_camera.look_at(global_position + Vector3(0.0, 0.6, -1.0), Vector3.UP)


func _update_visuals(delta: float, move_dir: Vector3) -> void:
	if visual_root != null:
		visual_root.rotation.y = facing_yaw
		var moving: bool = move_dir.length_squared() > 0.01 and dash_timer <= 0.0 and dodge_timer <= 0.0
		if moving:
			run_cycle += delta * 12.0
			visual_root.position.y = absf(sin(run_cycle)) * 0.08
		else:
			visual_root.position.y = lerpf(visual_root.position.y, 0.0, minf(delta * 10.0, 1.0))

	if cape_mesh != null:
		var speed_ratio: float = clampf(velocity.length() / maxf(move_speed, 0.1), 0.0, 1.8)
		cape_mesh.rotation.x = 0.18 + speed_ratio * 0.34 + sin(run_cycle * 1.2) * 0.06

	if warcry_ring != null:
		warcry_ring.visible = warcry_timer > 0.0
		if warcry_ring.visible:
			warcry_ring.rotation.y += delta * 2.2

	if dodge_shell != null:
		dodge_shell.visible = invuln_timer > 0.0

	if weapon_pivot != null:
		if swing_timer > 0.0:
			var t: float = 1.0 - (swing_timer / maxf(swing_duration, 0.01))
			var ease_t: float = 1.0 - pow(1.0 - t, 3.0)
			if swing_combo_index == 2:
				weapon_pivot.rotation = Vector3(-0.22, lerpf(-1.65, 1.85, ease_t), -0.35)
			elif swing_combo_index == 1:
				weapon_pivot.rotation = Vector3(0.08, lerpf(1.25, -1.35, ease_t), 0.18)
			else:
				weapon_pivot.rotation = Vector3(-0.08, lerpf(-1.25, 1.35, ease_t), -0.18)
		else:
			weapon_pivot.rotation = weapon_pivot.rotation.lerp(Vector3(0.15, 0.25, 0.0), minf(delta * 14.0, 1.0))


func _get_camera_relative_move_dir() -> Vector3:
	var input_z: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var input_x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if absf(input_x) < 0.01 and absf(input_z) < 0.01:
		return Vector3.ZERO

	var active_cam: Camera3D = tps_camera if is_tps else tactical_camera
	if active_cam == null:
		return Vector3(input_x, 0.0, -input_z).normalized()

	var cam_forward: Vector3 = -active_cam.global_transform.basis.z
	cam_forward.y = 0.0
	if cam_forward.length_squared() < 0.0001:
		cam_forward = Vector3.FORWARD
	else:
		cam_forward = cam_forward.normalized()

	var cam_right: Vector3 = active_cam.global_transform.basis.x
	cam_right.y = 0.0
	if cam_right.length_squared() < 0.0001:
		cam_right = Vector3.RIGHT
	else:
		cam_right = cam_right.normalized()

	var dir: Vector3 = cam_forward * input_z + cam_right * input_x
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.ZERO


func _get_facing_forward() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw)).normalized()


func _get_aim_direction_xz() -> Vector3:
	if is_tps and tps_camera != null:
		var fwd: Vector3 = -tps_camera.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length_squared() > 0.0001:
			return fwd.normalized()
	else:
		var aim_pt: Vector3 = get_aim_ground_point()
		var to_aim: Vector3 = aim_pt - global_position
		to_aim.y = 0.0
		if to_aim.length_squared() > 0.01:
			return to_aim.normalized()
	return _get_facing_forward()


func _try_melee_attack() -> void:
	if not alive or attack_cd_timer > 0.0 or dash_timer > 0.0:
		return

	var atk_dir: Vector3 = _get_aim_direction_xz()
	facing_yaw = atan2(-atk_dir.x, -atk_dir.z)

	var current_step: int = combo_step
	var is_finisher: bool = (current_step == 2)
	swing_combo_index = current_step
	swing_duration = 0.28 if is_finisher else 0.22
	swing_timer = swing_duration

	attack_cd_timer = MELEE_COOLDOWN * (1.15 if is_finisher else 1.0)
	combo_step = (combo_step + 1) % 3
	combo_reset_timer = COMBO_RESET_TIME

	var warcry_mult: float = 1.25 if warcry_timer > 0.0 else 1.0
	var dmg: float = base_attack * warcry_mult * (1.55 if is_finisher else 1.0)
	var min_dot: float = -0.15 if is_finisher else 0.22
	var kb_strength: float = 9.5 if is_finisher else 4.2

	VfxFactory.spawn_slash(_get_vfx_target(), global_position, facing_yaw, MELEE_RANGE, is_finisher)

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var enemy := node as Node3D
		if not _is_enemy_alive(enemy):
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		var dist: float = to_enemy.length()
		if dist > MELEE_RANGE:
			continue
		var dir_to: Vector3 = to_enemy / maxf(dist, 0.001)
		if dist > 0.9 and atk_dir.dot(dir_to) < min_dot:
			continue
		_apply_damage_to_enemy(enemy, dmg, dir_to * kb_strength, is_finisher)


func _try_dodge() -> void:
	if not alive or dodge_timer > 0.0 or dash_timer > 0.0:
		return
	if stamina < DODGE_COST:
		VfxFactory.spawn_floating_text(_get_vfx_target(), global_position, "耐力不足", Color(1.0, 0.75, 0.35), 36)
		return

	stamina -= DODGE_COST
	invuln_timer = maxf(invuln_timer, DODGE_IFRAMES)
	dodge_timer = DODGE_DURATION

	var move_dir: Vector3 = _get_camera_relative_move_dir()
	dodge_dir = move_dir if move_dir.length_squared() > 0.01 else _get_facing_forward()
	facing_yaw = atan2(-dodge_dir.x, -dodge_dir.z)

	VfxFactory.spawn_ring(_get_vfx_target(), global_position, 1.8, Color(0.32, 0.82, 1.0, 0.85), 0.28)


func _try_skill_1() -> void:
	if not alive or skill1_cd > 0.0 or dash_timer > 0.0:
		return

	skill1_cd = SKILL1_MAX_CD
	dash_dir = _get_aim_direction_xz()
	facing_yaw = atan2(-dash_dir.x, -dash_dir.z)
	dash_start_pos = global_position
	dash_timer = SKILL1_DURATION
	dash_speed = SKILL1_DISTANCE / SKILL1_DURATION
	invuln_timer = maxf(invuln_timer, SKILL1_DURATION + 0.08)
	dash_hit_ids.clear()

	var end_preview: Vector3 = GameConfig.clamp_to_arena(dash_start_pos + dash_dir * SKILL1_DISTANCE, 0.8)
	VfxFactory.spawn_charge_trail(_get_vfx_target(), dash_start_pos, end_preview, Color(1.0, 0.65, 0.18, 0.9))
	VfxFactory.spawn_ring(_get_vfx_target(), global_position, 2.6, Color(1.0, 0.72, 0.22, 0.9), 0.35)
	VfxFactory.spawn_floating_text(_get_vfx_target(), global_position, "破陣衝鋒！", Color(1.0, 0.84, 0.32), 46)
	log_event.emit("%s 發動【破陣衝鋒】！" % hero_name)


func _check_dash_hits() -> void:
	var warcry_mult: float = 1.25 if warcry_timer > 0.0 else 1.0
	var dmg: float = base_attack * 1.85 * warcry_mult
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var eid: int = node.get_instance_id()
		if dash_hit_ids.has(eid):
			continue
		var enemy := node as Node3D
		if not _is_enemy_alive(enemy):
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= 2.7:
			dash_hit_ids[eid] = true
			var kb_dir: Vector3 = (dash_dir + offset.normalized() * 0.4).normalized()
			_apply_damage_to_enemy(enemy, dmg, kb_dir * 11.5, true)


func _try_skill_2() -> void:
	if not alive or skill2_cd > 0.0:
		return

	skill2_cd = SKILL2_MAX_CD
	warcry_timer = WARCRY_DURATION
	warcry_triggered.emit(global_position, WARCRY_RADIUS)

	VfxFactory.spawn_ring(_get_vfx_target(), global_position, WARCRY_RADIUS, Color(1.0, 0.84, 0.22, 0.92), 0.55)
	VfxFactory.spawn_floating_text(_get_vfx_target(), global_position, "戰意咆哮！", Color(1.0, 0.9, 0.3), 50)
	log_event.emit("%s 發動【戰意咆哮】！攻速移速提升、減傷並激勵周邊兵團。" % hero_name)


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return

	if invuln_timer > 0.0:
		VfxFactory.spawn_floating_text(_get_vfx_target(), global_position, "閃避！", Color(0.35, 0.88, 1.0), 42)
		return

	var dmg_mult: float = 0.80 if warcry_timer > 0.0 else 1.0
	var final_dmg: float = maxf(amount * dmg_mult, 1.0)
	hp = maxf(hp - final_dmg, 0.0)
	VfxFactory.spawn_floating_text(_get_vfx_target(), global_position, "-%d" % int(round(final_dmg)), Color(1.0, 0.32, 0.32), 42)

	if hp <= 0.0:
		alive = false
		respawn_timer = RESPAWN_DURATION
		dash_timer = 0.0
		dodge_timer = 0.0
		if visual_root != null:
			visual_root.visible = false
		VfxFactory.spawn_death_burst(_get_vfx_target(), global_position, Color(1.0, 0.32, 0.25, 0.95), 12)
		log_event.emit("%s 暫時重傷倒下，將於 %.0f 秒後在城門重整旗鼓！" % [hero_name, RESPAWN_DURATION])


func _respawn_hero() -> void:
	alive = true
	hp = max_hp
	stamina = max_stamina
	invuln_timer = 1.5
	global_position = Vector3(GameConfig.GATE_X + 3.0, 0.0, 0.0)
	velocity = Vector3.ZERO
	if visual_root != null:
		visual_root.visible = true
	VfxFactory.spawn_ring(_get_vfx_target(), global_position, 3.2, Color(0.4, 0.95, 0.55, 0.9), 0.5)
	VfxFactory.spawn_floating_text(_get_vfx_target(), global_position, "重返戰場！", Color(0.45, 1.0, 0.6), 46)
	log_event.emit("%s 已於城門前重返戰場！" % hero_name)


func _is_enemy_alive(enemy: Node) -> bool:
	var alive_val: Variant = enemy.get("alive")
	if alive_val is bool:
		return alive_val as bool
	var hp_val: Variant = enemy.get("hp")
	if hp_val is float or hp_val is int:
		return float(hp_val) > 0.0
	return true


func _apply_damage_to_enemy(enemy: Node, dmg: float, knockback: Vector3, is_crit: bool) -> void:
	if not enemy.has_method("take_damage"):
		return
	var was_alive: bool = _is_enemy_alive(enemy)
	enemy.call("take_damage", dmg, knockback, is_crit)
	damage_dealt += dmg
	if was_alive and (not is_instance_valid(enemy) or not _is_enemy_alive(enemy)):
		kills += 1


func _get_vfx_target() -> Node3D:
	if vfx_parent != null and is_instance_valid(vfx_parent):
		return vfx_parent
	var parent_node := get_parent()
	if parent_node is Node3D:
		return parent_node as Node3D
	return self
