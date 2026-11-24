class_name SquadCharacter
extends CharacterBody3D

signal action_changed(char_id: String, action_name: String)
signal interaction_completed(char_id: String, station_label: String)

const TOON_SHADER := preload("res://assets/shaders/anime_toon.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/anime_outline.gdshader")

const ROLL_DURATION: float = 0.52
const ROLL_COOLDOWN: float = 0.35

var char_id: String = "reina_ar"
var display_name: String = "白羽 玲奈"
var codename: String = "REINA"
var role_label: String = "突擊步槍隊長"
var weapon_label: String = "戰術突擊步槍 (AR)"
var accent_color: Color = Color(0.34, 0.86, 1.0)
var muzzle_color: Color = Color(0.55, 0.92, 1.0)
var move_speed: float = 6.2
var roll_speed: float = 11.8
var fire_interval: float = 0.14
var pellets: int = 1
var spread_deg: float = 2.5

var is_active_player: bool = false
var current_action: String = "idle"  # "idle", "walk", "shoot", "interact", "roll"
var showcase_override_action: String = ""  # When non-empty, loops preview action from HUD

var model_pivot: Node3D = null
var anim_player: AnimationPlayer = null
var vfx_parent: Node3D = null
var selection_ring: MeshInstance3D = null
var interact_bar_root: Node3D = null
var interact_bar_fill: MeshInstance3D = null
var muzzle_light: OmniLight3D = null

var _anim_map: Dictionary = {}
var _facing_yaw: float = 0.0
var _roll_timer: float = 0.0
var _roll_cd: float = 0.0
var _roll_dir: Vector3 = Vector3.FORWARD
var _fire_cd: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _interact_spark_timer: float = 0.0
var _interact_progress: float = 0.0
var _click_move_target: Vector3 = Vector3.ZERO
var _has_click_move: bool = false
var _follow_leader: Node3D = null
var _follow_offset: Vector3 = Vector3.ZERO
var _nearest_station_label: String = ""


func setup(cfg: Dictionary, p_vfx_parent: Node3D) -> void:
	char_id = str(cfg.get("id", "reina_ar"))
	display_name = str(cfg.get("name", "白羽 玲奈"))
	codename = str(cfg.get("codename", "REINA"))
	role_label = str(cfg.get("role", ""))
	weapon_label = str(cfg.get("weapon_label", ""))
	accent_color = cfg.get("accent_color", Color(0.34, 0.86, 1.0))
	muzzle_color = cfg.get("muzzle_color", Color(1.0, 0.85, 0.45))
	move_speed = float(cfg.get("move_speed", 6.2))
	roll_speed = float(cfg.get("roll_speed", 11.8))
	fire_interval = float(cfg.get("fire_interval", 0.14))
	pellets = int(cfg.get("pellets", 1))
	spread_deg = float(cfg.get("spread_deg", 2.5))
	vfx_parent = p_vfx_parent

	collision_layer = 2
	collision_mask = 1
	add_to_group("squad_characters")

	_build_collision()
	_build_selection_ring()
	_build_interact_bar()
	_load_glb_model(str(cfg.get("model_path", "")), str(cfg.get("face_path", "")))
	_play_anim("idle")


func _build_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.35
	col.shape = cap
	col.position = Vector3(0.0, 0.68, 0.0)
	add_child(col)


func _build_selection_ring() -> void:
	selection_ring = MeshInstance3D.new()
	selection_ring.name = "SelectionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.50
	torus.outer_radius = 0.60
	torus.rings = 28
	torus.ring_segments = 8
	selection_ring.mesh = torus
	selection_ring.position = Vector3(0.0, 0.04, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = accent_color
	mat.emission_enabled = true
	mat.emission = accent_color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_ring.material_override = mat
	add_child(selection_ring)


func _build_interact_bar() -> void:
	interact_bar_root = Node3D.new()
	interact_bar_root.name = "InteractBar"
	interact_bar_root.position = Vector3(0.0, 1.85, 0.0)
	interact_bar_root.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	interact_bar_root.visible = false
	add_child(interact_bar_root)

	var bg := MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.95, 0.10, 0.04)
	bg.mesh = bg_box
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.10, 0.14, 0.9)
	bg.material_override = bg_mat
	interact_bar_root.add_child(bg)

	interact_bar_fill = MeshInstance3D.new()
	var fill_box := BoxMesh.new()
	fill_box.size = Vector3(0.89, 0.06, 0.05)
	interact_bar_fill.mesh = fill_box
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = accent_color
	fill_mat.emission_enabled = true
	fill_mat.emission = accent_color
	fill_mat.emission_energy_multiplier = 1.8
	interact_bar_fill.material_override = fill_mat
	interact_bar_root.add_child(interact_bar_fill)


func _load_glb_model(model_path: String, face_path: String) -> void:
	model_pivot = Node3D.new()
	model_pivot.name = "ModelPivot"
	_facing_yaw = PI
	model_pivot.rotation.y = _facing_yaw
	add_child(model_pivot)

	var loaded := load(model_path)
	if loaded is PackedScene:
		var inst := (loaded as PackedScene).instantiate()
		inst.name = "CharacterRig"
		# Blender exports -Y front as glTF +Z; rotate PI so character faces Godot -Z forward
		if inst is Node3D:
			(inst as Node3D).rotation.y = PI
			(inst as Node3D).scale = Vector3.ONE * 1.15
		model_pivot.add_child(inst)
		anim_player = _find_animation_player(inst)
		_configure_animations()
		_apply_anime_cel_shading(inst, face_path)
	else:
		push_warning("SquadCharacter: Failed to load model at %s" % model_path)

	# Muzzle flash dynamic point light
	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "MuzzleLight"
	muzzle_light.light_color = muzzle_color
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 4.5
	muzzle_light.position = Vector3(0.24, 0.62, -0.78)
	model_pivot.add_child(muzzle_light)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _configure_animations() -> void:
	_anim_map.clear()
	if anim_player == null:
		return
	var anim_list: PackedStringArray = anim_player.get_animation_list()
	for target in ["idle", "walk", "shoot", "interact", "roll"]:
		for raw_name in anim_list:
			var low := raw_name.to_lower()
			if low == target or low.ends_with("/" + target) or low.contains(target):
				_anim_map[target] = raw_name
				var anim: Animation = anim_player.get_animation(raw_name)
				if anim != null:
					anim.loop_mode = Animation.LOOP_NONE if target == "roll" else Animation.LOOP_LINEAR
				break


func _apply_anime_cel_shading(root_node: Node, fallback_face_path: String) -> void:
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = OUTLINE_SHADER
	outline_mat.set_shader_parameter("outline_color", Color(0.11, 0.09, 0.16, 1.0))
	outline_mat.set_shader_parameter("outline_width", 0.0085)

	var fallback_face_tex: Texture2D = null
	if ResourceLoader.exists(fallback_face_path):
		fallback_face_tex = load(fallback_face_path) as Texture2D

	_apply_toon_recursive(root_node, outline_mat, fallback_face_tex)


func _apply_toon_recursive(node: Node, outline_mat: ShaderMaterial, fallback_face_tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var surf_count := mi.mesh.get_surface_count()
			for s in range(surf_count):
				var orig_mat: Material = mi.get_active_material(s)
				if orig_mat is StandardMaterial3D:
					var std := orig_mat as StandardMaterial3D
					var mname := std.resource_name.to_lower()
					var nname := mi.name.to_lower()
					var is_halo: bool = mname.contains("halo") or nname.contains("halo") or mname.contains("sightglow") or mname.contains("gogglelens")
					if is_halo:
						# Keep Halo & glowing optics bright and crisp without black outline
						var glow_mat := std.duplicate() as StandardMaterial3D
						glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						glow_mat.emission_enabled = true
						glow_mat.emission = std.albedo_color
						glow_mat.emission_energy_multiplier = 2.6
						mi.set_surface_override_material(s, glow_mat)
						continue

					var is_face: bool = mname.contains("face") or (std.albedo_texture != null and nname.contains("head"))
					var toon := ShaderMaterial.new()
					toon.shader = TOON_SHADER
					toon.set_shader_parameter("albedo_color", std.albedo_color)
					toon.set_shader_parameter("shadow_tint", Color(0.68, 0.64, 0.82, 1.0))
					toon.set_shader_parameter("rim_color", Color(1.0, 0.80, 0.56, 1.0))
					toon.set_shader_parameter("rim_strength", 0.42 if not is_face else 0.14)
					toon.set_shader_parameter("is_face_material", is_face)

					if is_face:
						var ftex: Texture2D = std.albedo_texture if std.albedo_texture != null else fallback_face_tex
						if ftex != null:
							toon.set_shader_parameter("albedo_texture", ftex)
							toon.set_shader_parameter("use_texture", true)
							toon.set_shader_parameter("albedo_color", Color.WHITE)
					elif std.albedo_texture != null:
						toon.set_shader_parameter("albedo_texture", std.albedo_texture)
						toon.set_shader_parameter("use_texture", true)

					if not is_face:
						toon.next_pass = outline_mat

					mi.set_surface_override_material(s, toon)

	for child in node.get_children():
		_apply_toon_recursive(child, outline_mat, fallback_face_tex)


func set_active(active: bool) -> void:
	is_active_player = active
	if selection_ring != null:
		selection_ring.visible = active
	if not active:
		_has_click_move = false


func set_follow_leader(leader: Node3D, offset: Vector3) -> void:
	_follow_leader = leader
	_follow_offset = offset


func set_click_move_target(world_pos: Vector3) -> void:
	_click_move_target = SquadConfig.clamp_playable(Vector3(world_pos.x, 0.0, world_pos.z))
	_has_click_move = true
	showcase_override_action = ""


func clear_showcase_override() -> void:
	showcase_override_action = ""


func trigger_preview_action(action_name: String) -> void:
	_has_click_move = false
	if action_name == "roll":
		showcase_override_action = ""
		var fwd := Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw)).normalized()
		start_roll(fwd)
	elif action_name == "idle":
		showcase_override_action = ""
		_set_action("idle")
	else:
		showcase_override_action = action_name
		_set_action(action_name)


func start_roll(direction: Vector3) -> bool:
	if _roll_timer > 0.0 or _roll_cd > 0.0:
		return false
	var dir := Vector3(direction.x, 0.0, direction.z)
	if dir.length_squared() < 0.001:
		dir = Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))
	_roll_dir = dir.normalized()
	_facing_yaw = atan2(-_roll_dir.x, -_roll_dir.z)
	_roll_timer = ROLL_DURATION
	_roll_cd = ROLL_COOLDOWN
	_has_click_move = false
	_set_action("roll")
	_spawn_dust_puff(global_position + Vector3(0.0, 0.12, 0.0))
	return true


func update_character(
	delta: float,
	move_input: Vector3,
	aim_world_pos: Vector3,
	want_shoot: bool,
	want_interact: bool,
	want_roll: bool,
	nearest_station_label: String
) -> void:
	_nearest_station_label = nearest_station_label
	_roll_cd = maxf(0.0, _roll_cd - delta)
	_fire_cd = maxf(0.0, _fire_cd - delta)

	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer = maxf(0.0, _muzzle_flash_timer - delta)
		if muzzle_light != null:
			muzzle_light.light_energy = 4.2 if _muzzle_flash_timer > 0.0 else 0.0

	# Active roll physics takes top priority
	if _roll_timer > 0.0:
		_roll_timer = maxf(0.0, _roll_timer - delta)
		var speed_curve: float = sin((_roll_timer / ROLL_DURATION) * PI) * 0.55 + 0.55
		velocity = _roll_dir * (roll_speed * speed_curve)
		move_and_slide()
		global_position = SquadConfig.clamp_playable(Vector3(global_position.x, 0.0, global_position.z))
		_apply_facing(delta, 18.0)
		_set_interact_bar_visible(false)
		return

	# If HUD Preview Override mode is active (great for inspecting all 4 actions!)
	if not showcase_override_action.is_empty():
		if move_input.length_squared() > 0.05 or want_shoot or want_roll:
			showcase_override_action = ""
		else:
			_run_showcase_override(delta)
			return

	if is_active_player:
		_update_active_player(delta, move_input, aim_world_pos, want_shoot, want_interact, want_roll)
	else:
		_update_squad_follower(delta)


func _run_showcase_override(delta: float) -> void:
	velocity = Vector3.ZERO
	_set_action(showcase_override_action)
	if showcase_override_action == "shoot":
		var fwd := Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))
		_try_fire_weapon(global_position + fwd * 14.0)
		_set_interact_bar_visible(false)
	elif showcase_override_action == "interact":
		_tick_interact_fx(delta)
	else:
		_set_interact_bar_visible(false)
	_apply_facing(delta, 10.0)


func _update_active_player(
	delta: float,
	move_input: Vector3,
	aim_world_pos: Vector3,
	want_shoot: bool,
	want_interact: bool,
	want_roll: bool
) -> void:
	if want_roll:
		var rdir := move_input if move_input.length_squared() > 0.04 else (aim_world_pos - global_position)
		if start_roll(rdir):
			return

	# Shooting (faces cursor & fires tracer bursts!)
	if want_shoot:
		_has_click_move = false
		_set_interact_bar_visible(false)
		var to_aim := Vector3(aim_world_pos.x - global_position.x, 0.0, aim_world_pos.z - global_position.z)
		if to_aim.length_squared() > 0.02:
			_facing_yaw = atan2(-to_aim.x, -to_aim.z)
		velocity = Vector3.ZERO
		_set_action("shoot")
		_try_fire_weapon(aim_world_pos)
		_apply_facing(delta, 20.0)
		return

	# Interact ("摸東摸西": lockpick / craft / tinker)
	if want_interact:
		_has_click_move = false
		velocity = Vector3.ZERO
		_set_action("interact")
		_tick_interact_fx(delta)
		_apply_facing(delta, 12.0)
		return

	_set_interact_bar_visible(false)
	_interact_progress = 0.0

	# Movement: WASD overrides click-to-move
	var move_vec := Vector3.ZERO
	if move_input.length_squared() > 0.02:
		_has_click_move = false
		move_vec = move_input.normalized()
	elif _has_click_move:
		var to_dest := Vector3(_click_move_target.x - global_position.x, 0.0, _click_move_target.z - global_position.z)
		if to_dest.length() > 0.25:
			move_vec = to_dest.normalized()
		else:
			_has_click_move = false

	if move_vec.length_squared() > 0.01:
		velocity = move_vec * move_speed
		move_and_slide()
		global_position = SquadConfig.clamp_playable(Vector3(global_position.x, 0.0, global_position.z))
		_facing_yaw = atan2(-move_vec.x, -move_vec.z)
		_set_action("walk")
	else:
		velocity = Vector3.ZERO
		_set_action("idle")

	_apply_facing(delta, 14.0)


func _update_squad_follower(delta: float) -> void:
	_set_interact_bar_visible(false)
	if _follow_leader == null or not is_instance_valid(_follow_leader):
		_set_action("idle")
		return

	var target_pos: Vector3 = SquadConfig.clamp_playable(_follow_leader.global_position + _follow_offset)
	var diff := Vector3(target_pos.x - global_position.x, 0.0, target_pos.z - global_position.z)
	var dist := diff.length()
	if dist > 0.65:
		var dir := diff / dist
		var spd: float = move_speed * (1.12 if dist > 5.0 else 0.92)
		velocity = dir * spd
		move_and_slide()
		global_position = SquadConfig.clamp_playable(Vector3(global_position.x, 0.0, global_position.z))
		_facing_yaw = atan2(-dir.x, -dir.z)
		_set_action("walk")
	else:
		velocity = Vector3.ZERO
		_set_action("idle")
	_apply_facing(delta, 11.0)


func _apply_facing(delta: float, turn_speed: float) -> void:
	if model_pivot != null:
		model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, _facing_yaw, clampf(delta * turn_speed, 0.0, 1.0))


func _set_action(action_name: String) -> void:
	if current_action == action_name:
		if anim_player != null and action_name != "roll" and not anim_player.is_playing():
			_play_anim(action_name)
		return
	current_action = action_name
	_play_anim(action_name)
	action_changed.emit(char_id, action_name)


func _play_anim(action_name: String) -> void:
	if anim_player == null:
		return
	var clip_name: String = str(_anim_map.get(action_name, ""))
	if clip_name.is_empty():
		return
	var blend := 0.06 if action_name in ["roll", "shoot"] else 0.14
	anim_player.play(clip_name, blend)


func get_available_animations() -> PackedStringArray:
	var keys := PackedStringArray()
	for k in _anim_map.keys():
		keys.append(str(k))
	return keys


func _try_fire_weapon(target_world_pos: Vector3) -> void:
	if _fire_cd > 0.0:
		return
	_fire_cd = fire_interval
	_muzzle_flash_timer = 0.065

	var muzzle_pos: Vector3 = global_position + Vector3(0.0, 0.68, 0.0) + Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw)) * 0.72
	var base_dir := Vector3(target_world_pos.x - muzzle_pos.x, 0.0, target_world_pos.z - muzzle_pos.z)
	if base_dir.length_squared() < 0.05:
		base_dir = Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))
	else:
		base_dir = base_dir.normalized()

	for _i in range(pellets):
		var spread_rad: float = deg_to_rad(randf_range(-spread_deg, spread_deg))
		var shot_dir: Vector3 = base_dir.rotated(Vector3.UP, spread_rad)
		var end_pos: Vector3 = muzzle_pos + shot_dir * randf_range(11.0, 16.0)
		_spawn_tracer(muzzle_pos, end_pos)


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	if vfx_parent == null:
		return
	var seg: Vector3 = to_pos - from_pos
	var length: float = maxf(0.5, seg.length())

	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.045, 0.045, length)
	beam.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = muzzle_color
	mat.emission_enabled = true
	mat.emission = muzzle_color
	mat.emission_energy_multiplier = 4.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat
	vfx_parent.add_child(beam)
	beam.global_position = (from_pos + to_pos) * 0.5
	beam.look_at(to_pos, Vector3.UP)

	var tw := beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.09)
	tw.tween_callback(beam.queue_free)


func _tick_interact_fx(delta: float) -> void:
	_set_interact_bar_visible(true)
	_interact_progress += delta * 0.45
	if _interact_progress >= 1.0:
		_interact_progress = 0.0
		var label := _nearest_station_label if not _nearest_station_label.is_empty() else "戰術道具／鎖具"
		interaction_completed.emit(char_id, label)
		_spawn_dust_puff(global_position + Vector3(-sin(_facing_yaw), 0.35, -cos(_facing_yaw)) * 0.55, accent_color)

	if interact_bar_fill != null:
		var pct := clampf(_interact_progress, 0.06, 1.0)
		interact_bar_fill.scale.x = pct
		interact_bar_fill.position.x = -(1.0 - pct) * 0.445

	_interact_spark_timer -= delta
	if _interact_spark_timer <= 0.0:
		_interact_spark_timer = 0.22
		var hand_front := global_position + Vector3(-sin(_facing_yaw), 0.45, -cos(_facing_yaw)) * 0.48
		_spawn_tinker_spark(hand_front)


func _set_interact_bar_visible(vis: bool) -> void:
	if interact_bar_root != null:
		interact_bar_root.visible = vis


func _spawn_tinker_spark(origin: Vector3) -> void:
	if vfx_parent == null:
		return
	var spark := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.065
	sph.height = 0.13
	spark.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.90, 0.48)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.35)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material_override = mat
	vfx_parent.add_child(spark)
	spark.global_position = origin + Vector3(randf_range(-0.18, 0.18), randf_range(-0.08, 0.16), randf_range(-0.18, 0.18))
	var dest := spark.global_position + Vector3(randf_range(-0.35, 0.35), randf_range(0.25, 0.55), randf_range(-0.35, 0.35))

	var tw := spark.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spark, "global_position", dest, 0.28)
	tw.tween_property(spark, "scale", Vector3.ONE * 0.15, 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(spark.queue_free)


func _spawn_dust_puff(origin: Vector3, tint: Color = Color(0.76, 0.72, 0.66, 0.75)) -> void:
	if vfx_parent == null:
		return
	for _i in range(4):
		var puff := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.16
		sph.height = 0.32
		puff.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = tint
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material_override = mat
		vfx_parent.add_child(puff)
		puff.global_position = origin + Vector3(randf_range(-0.25, 0.25), 0.05, randf_range(-0.25, 0.25))
		var dest := puff.global_position + Vector3(randf_range(-0.6, 0.6), randf_range(0.25, 0.65), randf_range(-0.6, 0.6))
		var tw := puff.create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "global_position", dest, 0.34)
		tw.tween_property(puff, "scale", Vector3.ONE * 1.9, 0.34)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.34)
		tw.chain().tween_callback(puff.queue_free)
