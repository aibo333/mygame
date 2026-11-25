class_name SquadCharacter
extends CharacterBody3D

signal action_changed(char_id: String, action_name: String)
signal interaction_completed(char_id: String, station_label: String)
signal shot_fired(muzzle_pos: Vector3, shot_dir: Vector3, damage: float)
signal hp_changed(current_hp: float, max_hp: float)
signal vitals_changed(hp: float, max_hp: float, stamina: float, max_stamina: float, hunger: float, max_hunger: float)
signal ammo_changed(ammo_in_mag: int, mag_size: int, is_reloading: bool)
signal player_died()

const TOON_SHADER := preload("res://assets/shaders/anime_toon.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/anime_outline.gdshader")

const ROLL_DURATION: float = 1.05
const ROLL_IFRAME_DURATION: float = 0.70
const ROLL_COOLDOWN: float = 0.25
const AVATAR_SCALE: float = 1.45
const RELOAD_DURATION: float = 1.35

var char_id: String = "reina_ar"
var display_name: String = "白羽 玲奈"
var codename: String = "REINA"
var role_label: String = "單人戰術特勤"
var weapon_label: String = "突擊步槍 (Mixamo 動捕)"
var accent_color: Color = Color(0.34, 0.86, 1.0)
var muzzle_color: Color = Color(0.55, 0.92, 1.0)
var move_speed: float = 6.6
var roll_speed: float = 9.8
var fire_interval: float = 0.14
var pellets: int = 1
var spread_deg: float = 2.5
var bullet_damage: float = 28.0
var max_hp: float = 100.0
var hp: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var max_hunger: float = 100.0
var hunger: float = 100.0
var mag_size: int = 30
var ammo_in_mag: int = 30
var is_reloading: bool = false
var is_dead: bool = false
var god_mode: bool = false
var infinite_ammo: bool = false
var _stim_timer: float = 0.0

var is_active_player: bool = true
var current_action: String = "idle"  # "idle", "walk", "shoot", "interact", "roll"
var showcase_override_action: String = ""

var model_pivot: Node3D = null
var avatar_root: Node3D = null
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var vfx_parent: Node3D = null
var selection_ring: MeshInstance3D = null
var interact_bar_root: Node3D = null
var interact_bar_fill: MeshInstance3D = null
var muzzle_light: OmniLight3D = null

var _loaded_clips: Array[String] = []
var _camera_yaw_rad: float = 0.0
var _facing_yaw: float = 0.0
var _step_dust_timer: float = 0.0
var _roll_timer: float = 0.0
var _roll_cd: float = 0.0
var _roll_dir: Vector3 = Vector3.FORWARD
var _fire_cd: float = 0.0
var _reload_timer: float = 0.0
var _iframe_timer: float = 0.0
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
	move_speed = float(cfg.get("move_speed", 6.6))
	roll_speed = float(cfg.get("roll_speed", 9.8))
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
	_load_hiragara_avatar()
	_setup_mixamo_animations()
	_play_clip("idle")


func _build_collision() -> void:
	if get_node_or_null("CollisionShape3D") != null:
		return
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.95
	col.shape = cap
	col.position = Vector3(0.0, 0.98, 0.0)
	add_child(col)


func _build_selection_ring() -> void:
	selection_ring = MeshInstance3D.new()
	selection_ring.name = "SelectionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.54
	torus.outer_radius = 0.64
	torus.rings = 28
	torus.ring_segments = 8
	selection_ring.mesh = torus
	selection_ring.position = Vector3(0.0, 0.14, 0.0)
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
	interact_bar_root.position = Vector3(0.0, 2.55, 0.0)
	interact_bar_root.rotation_degrees = Vector3(-32.0, 0.0, 0.0)
	interact_bar_root.visible = false
	add_child(interact_bar_root)

	var bg := MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(1.05, 0.12, 0.04)
	bg.mesh = bg_box
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.10, 0.14, 0.92)
	bg.material_override = bg_mat
	interact_bar_root.add_child(bg)

	interact_bar_fill = MeshInstance3D.new()
	var fill_box := BoxMesh.new()
	fill_box.size = Vector3(0.98, 0.075, 0.05)
	interact_bar_fill.mesh = fill_box
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = accent_color
	fill_mat.emission_enabled = true
	fill_mat.emission = accent_color
	fill_mat.emission_energy_multiplier = 1.9
	interact_bar_fill.material_override = fill_mat
	interact_bar_root.add_child(interact_bar_fill)


func _load_hiragara_avatar() -> void:
	model_pivot = Node3D.new()
	model_pivot.name = "ModelPivot"
	_facing_yaw = PI  # Initially face toward +Z (toward camera)
	model_pivot.rotation.y = _facing_yaw
	add_child(model_pivot)

	var loaded := load(SquadConfig.AVATAR_FBX_PATH)
	if loaded is PackedScene:
		avatar_root = (loaded as PackedScene).instantiate() as Node3D
		avatar_root.name = "SummerCutenessAvatar"
		# Retargeted Humanoid faces +Z; rotate PI so local -Z matches Godot forward!
		avatar_root.rotation.y = PI
		avatar_root.scale = Vector3.ONE * AVATAR_SCALE
		model_pivot.add_child(avatar_root)

		skeleton = avatar_root.find_child("GeneralSkeleton", true, false) as Skeleton3D
		if skeleton == null:
			skeleton = _find_skeleton(avatar_root)
		_apply_avatar_materials(avatar_root)
		_attach_tactical_rifle()
	else:
		push_warning("SquadCharacter: Failed to load avatar FBX at %s" % SquadConfig.AVATAR_FBX_PATH)

	# Dynamic muzzle flash light
	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "MuzzleLight"
	muzzle_light.light_color = muzzle_color
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 5.5
	muzzle_light.position = Vector3(0.24, 1.35, -0.95)
	model_pivot.add_child(muzzle_light)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var found := _find_skeleton(c)
		if found != null:
			return found
	return null


func _attach_tactical_rifle() -> void:
	# Mount a sleek dark tactical rifle to her retargeted RightHand bone so Rifle Idle / Run / Fire look grounded!
	if skeleton == null or skeleton.find_bone("RightHand") < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "RightHandRifleMount"
	attach.bone_name = "RightHand"
	skeleton.add_child(attach)

	var rifle := Node3D.new()
	rifle.name = "TacticalRifleProp"
	# Flip 180 deg around local X so barrel (+Z) points forward into LeftHand, stock tucks to shoulder, optic is UP, magazine is DOWN!
	rifle.position = Vector3(0.03, 0.08, 0.03)
	rifle.basis = Basis.from_euler(Vector3(deg_to_rad(82.0), deg_to_rad(-10.0), deg_to_rad(90.0))) * Basis(Vector3.RIGHT, PI)
	attach.add_child(rifle)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.18, 0.21, 0.27)
	body_mat.metallic = 0.55
	body_mat.roughness = 0.42

	var accent_mat := StandardMaterial3D.new()
	accent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	accent_mat.albedo_color = accent_color
	accent_mat.emission_enabled = true
	accent_mat.emission = accent_color
	accent_mat.emission_energy_multiplier = 2.2

	var parts := [
		{"size": Vector3(0.045, 0.075, 0.36), "pos": Vector3(0.0, 0.02, 0.05), "mat": body_mat},   # Receiver
		{"size": Vector3(0.026, 0.026, 0.30), "pos": Vector3(0.0, 0.03, 0.34), "mat": body_mat},   # Barrel
		{"size": Vector3(0.038, 0.065, 0.20), "pos": Vector3(0.0, 0.01, -0.20), "mat": body_mat},  # Stock
		{"size": Vector3(0.032, 0.14, 0.055), "pos": Vector3(0.0, -0.07, 0.12), "mat": body_mat},  # Magazine
		{"size": Vector3(0.032, 0.042, 0.09), "pos": Vector3(0.0, 0.08, 0.03), "mat": body_mat},   # Optic
		{"size": Vector3(0.048, 0.016, 0.14), "pos": Vector3(0.0, 0.035, 0.16), "mat": accent_mat},# Cyan accent
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p["size"]
		mi.mesh = bm
		mi.position = p["pos"]
		mi.material_override = p["mat"]
		rifle.add_child(mi)


func _setup_mixamo_animations() -> void:
	_loaded_clips.clear()
	if avatar_root == null or skeleton == null:
		return

	anim_player = AnimationPlayer.new()
	anim_player.name = "MixamoAnimPlayer"
	avatar_root.add_child(anim_player)
	anim_player.root_node = NodePath("..")

	var lib := AnimationLibrary.new()
	var skel_rel_path: String = str(avatar_root.get_path_to(skeleton))

	for action_name: String in ["idle", "walk", "shoot", "roll"]:
		var fbx_path: String = str(SquadConfig.MIXAMO_ANIMS.get(action_name, ""))
		if fbx_path.is_empty() or not ResourceLoader.exists(fbx_path):
			continue
		var packed := load(fbx_path) as PackedScene
		if packed == null:
			continue
		var temp := packed.instantiate()
		var src_ap := temp.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if src_ap != null and src_ap.get_animation_list().size() > 0:
			var raw_anim: Animation = src_ap.get_animation(src_ap.get_animation_list()[0])
			var clip: Animation = raw_anim.duplicate(true) as Animation
			clip.loop_mode = Animation.LOOP_NONE if action_name == "roll" else Animation.LOOP_LINEAR
			_retarget_track_paths_and_strip_root_motion(clip, skel_rel_path)
			lib.add_animation(action_name, clip)
			_loaded_clips.append(action_name)
		temp.free()

	# Reuse idle clip cleanly for "interact" until a dedicated Mixamo tinkering clip is added
	if lib.has_animation("idle"):
		var interact_clip := lib.get_animation("idle").duplicate(true) as Animation
		interact_clip.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("interact", interact_clip)
		_loaded_clips.append("interact")

	anim_player.add_animation_library("", lib)


func _retarget_track_paths_and_strip_root_motion(anim: Animation, skel_rel_path: String) -> void:
	for ti in range(anim.get_track_count()):
		var raw_path: String = str(anim.track_get_path(ti))
		var colon_idx: int = raw_path.find(":")
		if colon_idx < 0:
			continue
		var sub_bone: String = raw_path.substr(colon_idx + 1)
		anim.track_set_path(ti, NodePath(skel_rel_path + ":" + sub_bone))

		# Compensate SummerCuteness's sloped ankle-to-toe bind angle (-52 deg pitch around local X)
		# so both shoes plant flat on the ground without bending the calves upward!
		if (sub_bone == "LeftFoot" or sub_bone == "RightFoot") and anim.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
			var foot_fix := Quaternion(Vector3.RIGHT, deg_to_rad(-52.0))
			var kcount_r: int = anim.track_get_key_count(ti)
			for ki in range(kcount_r):
				var q: Quaternion = anim.track_get_key_value(ti, ki)
				anim.track_set_key_value(ti, ki, (q * foot_fix).normalized())

		# Strip horizontal X/Z root-motion drift AND rebase vertical Y to Hips local rest (0.0)
		# because SummerCuteness's Bip001 parent bone already sits at standing pelvis height (0.78m)!
		if sub_bone == "Hips" and anim.track_get_type(ti) == Animation.TYPE_POSITION_3D:
			var kcount: int = anim.track_get_key_count(ti)
			if kcount > 0:
				for ki in range(kcount):
					var p: Vector3 = anim.track_get_key_value(ti, ki)
					anim.track_set_key_value(ti, ki, Vector3(0.0, p.y - 0.98, 0.0))


func _apply_avatar_materials(root_node: Node) -> void:
	var tex_dir: String = SquadConfig.AVATAR_DIR
	var tex_map := {
		"MAT_Summer_Cuteness_Body_1_UI": tex_dir + "Summer_Cuteness_Body_1_D.png",
		"MAT_Summer_Cuteness_Body_2_UI": tex_dir + "Summer_Cuteness_Body_2_D.png",
		"MAT_Summer_Body_2_UI": tex_dir + "Summer_Body_Map2_D.png",
		"MAT_Summer_Hair_T_UI": tex_dir + "Summer_Body_Map2_D.png",
		"MAT_Summer_Face_UI": tex_dir + "Summer_Face_D.png",
		"MAT_Summer_Eye_UI": tex_dir + "Summer_Face_D.png",
		"MAT_Summer_Eyebrows_UI": tex_dir + "Summer_Face_D.png",
		"MAT_Summer_Weapon_1_UI": tex_dir + "Summer_Weapon_D.png",
	}

	var outfit_tint := Color(0.84, 0.84, 0.86)
	var face_tint := Color(0.88, 0.88, 0.90)

	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = OUTLINE_SHADER
	outline_mat.set_shader_parameter("outline_color", Color(0.18, 0.14, 0.22, 1.0))
	outline_mat.set_shader_parameter("outline_width", 0.0038)

	_apply_materials_recursive(root_node, tex_map, outfit_tint, face_tint, outline_mat)


func _apply_materials_recursive(node: Node, tex_map: Dictionary, outfit_tint: Color, face_tint: Color, outline_mat: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var nlow := mi.name.to_lower()
		if nlow.contains("hairshadow") or nlow.contains("shy"):
			mi.visible = false
			return
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var orig := mi.get_active_material(s)
				var mname: String = orig.resource_name if orig != null else ""
				var tpath: String = str(tex_map.get(mname, ""))
				if tpath.is_empty() or not ResourceLoader.exists(tpath):
					continue
				var tex := load(tpath) as Texture2D
				var is_face := mname.contains("Face") or mname.contains("Eye")
				var is_hair_t := mname.contains("Hair_T")
				var is_brow := mname.contains("Eyebrows")

				if is_hair_t or is_brow:
					var std := StandardMaterial3D.new()
					std.albedo_texture = tex
					std.albedo_color = face_tint if is_brow else outfit_tint
					std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					std.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED if is_brow else BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
					std.cull_mode = BaseMaterial3D.CULL_DISABLED
					std.roughness = 0.82
					mi.set_surface_override_material(s, std)
				else:
					var toon := ShaderMaterial.new()
					toon.shader = TOON_SHADER
					toon.set_shader_parameter("albedo_texture", tex)
					toon.set_shader_parameter("use_texture", true)
					toon.set_shader_parameter("albedo_color", face_tint if is_face else outfit_tint)
					toon.set_shader_parameter("shadow_tint", Color(0.70, 0.66, 0.78, 1.0))
					toon.set_shader_parameter("cel_threshold", 0.04)
					toon.set_shader_parameter("cel_smoothness", 0.10)
					toon.set_shader_parameter("rim_color", Color(1.0, 0.88, 0.74, 1.0))
					toon.set_shader_parameter("rim_strength", 0.06 if is_face else 0.14)
					toon.set_shader_parameter("specular_strength", 0.04)
					toon.set_shader_parameter("is_face_material", is_face)
					if not is_face:
						toon.next_pass = outline_mat
					mi.set_surface_override_material(s, toon)

	for c in node.get_children():
		_apply_materials_recursive(c, tex_map, outfit_tint, face_tint, outline_mat)


func set_camera_yaw(yaw_rad: float) -> void:
	_camera_yaw_rad = yaw_rad
	if interact_bar_root != null:
		interact_bar_root.rotation = Vector3(deg_to_rad(-32.0), _camera_yaw_rad, 0.0)


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
	if is_dead or _roll_timer > 0.0 or _roll_cd > 0.0:
		return false
	if showcase_override_action.is_empty() and not god_mode and stamina < 18.0:
		return false
	if showcase_override_action.is_empty() and not god_mode:
		stamina = maxf(0.0, stamina - 24.0)
		vitals_changed.emit(hp, max_hp, stamina, max_stamina, hunger, max_hunger)
	var dir := Vector3(direction.x, 0.0, direction.z)
	if dir.length_squared() < 0.001:
		dir = Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))
	_roll_dir = dir.normalized()
	_facing_yaw = atan2(-_roll_dir.x, -_roll_dir.z)
	_roll_timer = ROLL_DURATION
	_iframe_timer = ROLL_IFRAME_DURATION
	_roll_cd = ROLL_COOLDOWN
	_has_click_move = false
	_set_action("roll", true)
	_spawn_dust_puff(global_position + Vector3(0.0, 0.14, 0.0))
	return true


func get_facing_yaw() -> float:
	return _facing_yaw


func is_invulnerable() -> bool:
	return god_mode or _iframe_timer > 0.0


func reset_combat_state() -> void:
	is_dead = false
	hp = max_hp
	stamina = max_stamina
	hunger = max_hunger
	_stim_timer = 0.0
	ammo_in_mag = mag_size
	is_reloading = false
	_reload_timer = 0.0
	_iframe_timer = 0.0
	_interact_progress = 0.0
	hp_changed.emit(hp, max_hp)
	vitals_changed.emit(hp, max_hp, stamina, max_stamina, hunger, max_hunger)
	ammo_changed.emit(ammo_in_mag, mag_size, is_reloading)


func take_damage(amount: float) -> bool:
	if is_dead or amount <= 0.0 or is_invulnerable():
		return false
	hp = maxf(0.0, hp - amount)
	_iframe_timer = 0.22
	_spawn_dust_puff(global_position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.26, 0.22, 0.85), 3)
	hp_changed.emit(hp, max_hp)
	vitals_changed.emit(hp, max_hp, stamina, max_stamina, hunger, max_hunger)
	if hp <= 0.0:
		is_dead = true
		velocity = Vector3.ZERO
		_set_action("idle")
		player_died.emit()
	return true


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0 or hp >= max_hp:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)
	vitals_changed.emit(hp, max_hp, stamina, max_stamina, hunger, max_hunger)


func restore_stamina(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	stamina = minf(max_stamina, stamina + amount)
	vitals_changed.emit(hp, max_hp, stamina, max_stamina, hunger, max_hunger)


func restore_hunger(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	hunger = minf(max_hunger, hunger + amount)
	vitals_changed.emit(hp, max_hp, stamina, max_stamina, hunger, max_hunger)


func apply_stimulant(duration_sec: float = 6.0) -> void:
	if is_dead:
		return
	_stim_timer = maxf(_stim_timer, duration_sec)
	stamina = max_stamina
	vitals_changed.emit(hp, max_hp, stamina, max_stamina, hunger, max_hunger)
	_spawn_dust_puff(global_position + Vector3(0.0, 0.9, 0.0), Color(0.40, 0.96, 1.0, 0.85), 4)


func start_reload() -> bool:
	if is_dead or is_reloading or ammo_in_mag >= mag_size:
		return false
	is_reloading = true
	_reload_timer = RELOAD_DURATION
	ammo_changed.emit(ammo_in_mag, mag_size, true)
	return true


func play_stratagem_step_fx() -> void:
	_set_action("interact")
	var hand_front: Vector3 = global_position + Vector3(-sin(_facing_yaw), 0.92, -cos(_facing_yaw)) * 0.58
	_spawn_tinker_spark(hand_front)


func play_stratagem_complete_fx() -> void:
	_spawn_dust_puff(global_position + Vector3(-sin(_facing_yaw), 0.45, -cos(_facing_yaw)) * 0.6, accent_color, 5)
	_set_action("idle")


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
	_iframe_timer = maxf(0.0, _iframe_timer - delta)

	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			is_reloading = false
			ammo_in_mag = mag_size
			ammo_changed.emit(ammo_in_mag, mag_size, false)

	if is_dead:
		velocity = Vector3.ZERO
		_set_interact_bar_visible(false)
		return

	# Survival vitals tick: gradual hunger drain & stamina regen
	_stim_timer = maxf(0.0, _stim_timer - delta)
	if god_mode:
		hp = max_hp
		stamina = max_stamina
		hunger = max_hunger
	else:
		hunger = maxf(0.0, hunger - delta * 0.36)
		var well_fed_mult: float = 1.0 if hunger >= 20.0 else 0.45
		var regen_rate: float = (18.0 if current_action == "idle" else 10.0) * well_fed_mult
		if _roll_timer <= 0.0:
			stamina = minf(max_stamina, stamina + regen_rate * delta)

	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer = maxf(0.0, _muzzle_flash_timer - delta)
		if muzzle_light != null:
			muzzle_light.light_energy = 4.6 if _muzzle_flash_timer > 0.0 else 0.0

	if _roll_timer > 0.0:
		_roll_timer = maxf(0.0, _roll_timer - delta)
		var speed_curve: float = sin((_roll_timer / ROLL_DURATION) * PI) * 0.65 + 0.35
		velocity = _roll_dir * (roll_speed * speed_curve)
		move_and_slide()
		global_position = SquadConfig.clamp_playable(Vector3(global_position.x, 0.0, global_position.z))
		_apply_facing(delta, 18.0)
		_set_interact_bar_visible(false)
		return

	if not showcase_override_action.is_empty():
		if move_input.length_squared() > 0.05 or want_shoot or want_roll:
			showcase_override_action = ""
		else:
			_run_showcase_override(delta)
			return

	_update_active_player(delta, move_input, aim_world_pos, want_shoot, want_interact, want_roll)


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

	if want_interact:
		_has_click_move = false
		velocity = Vector3.ZERO
		_set_action("interact")
		_tick_interact_fx(delta)
		_apply_facing(delta, 12.0)
		return

	_set_interact_bar_visible(false)
	_interact_progress = 0.0

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
		var spd_mult: float = 1.30 if _stim_timer > 0.0 else (0.86 if hunger <= 5.0 else 1.0)
		velocity = move_vec * (move_speed * spd_mult)
		move_and_slide()
		global_position = SquadConfig.clamp_playable(Vector3(global_position.x, 0.0, global_position.z))
		_facing_yaw = atan2(-move_vec.x, -move_vec.z)
		_set_action("walk")
		_step_dust_timer -= delta
		if _step_dust_timer <= 0.0:
			_step_dust_timer = 0.28
			_spawn_dust_puff(global_position + Vector3(0.0, 0.08, 0.0), Color(0.76, 0.72, 0.66, 0.42), 1)
	else:
		velocity = Vector3.ZERO
		_set_action("idle")

	_apply_facing(delta, 14.0)


func _apply_facing(delta: float, turn_speed: float) -> void:
	if model_pivot != null:
		model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, _facing_yaw, clampf(delta * turn_speed, 0.0, 1.0))


func _set_action(action_name: String, force_restart: bool = false) -> void:
	if current_action == action_name and not force_restart:
		if anim_player != null and action_name != "roll" and not anim_player.is_playing():
			_play_clip(action_name)
		return
	current_action = action_name
	_play_clip(action_name, force_restart)
	action_changed.emit(char_id, action_name)


func _play_clip(action_name: String, force_restart: bool = false) -> void:
	if anim_player == null or not anim_player.has_animation(action_name):
		return
	var blend: float = 0.08 if action_name in ["roll", "shoot"] else 0.16
	anim_player.speed_scale = 2.05 if action_name == "roll" else (1.12 if action_name == "walk" else 1.0)
	if force_restart:
		anim_player.stop()
	anim_player.play(action_name, blend)


func get_available_animations() -> PackedStringArray:
	return PackedStringArray(_loaded_clips)


func _try_fire_weapon(target_world_pos: Vector3) -> void:
	if _fire_cd > 0.0 or is_reloading:
		return
	if showcase_override_action.is_empty():
		if infinite_ammo:
			ammo_in_mag = mag_size
		else:
			if ammo_in_mag <= 0:
				start_reload()
				return
			ammo_in_mag -= 1
			ammo_changed.emit(ammo_in_mag, mag_size, false)
			if ammo_in_mag <= 0:
				start_reload()

	_fire_cd = fire_interval
	_muzzle_flash_timer = 0.07

	var fwd := Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))
	var muzzle_pos: Vector3 = global_position + Vector3(0.0, 1.32, 0.0) + fwd * 0.90
	var base_dir := Vector3(target_world_pos.x - muzzle_pos.x, 0.0, target_world_pos.z - muzzle_pos.z)
	if base_dir.length_squared() < 0.05:
		base_dir = fwd
	else:
		base_dir = base_dir.normalized()

	for _i in range(pellets):
		var spread_rad: float = deg_to_rad(randf_range(-spread_deg, spread_deg))
		var shot_dir: Vector3 = base_dir.rotated(Vector3.UP, spread_rad)
		var end_pos: Vector3 = muzzle_pos + shot_dir * randf_range(14.0, 18.0)
		_spawn_tracer(muzzle_pos, end_pos)
		shot_fired.emit(muzzle_pos, shot_dir, bullet_damage)


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	if vfx_parent == null:
		return
	var seg: Vector3 = to_pos - from_pos
	var length: float = maxf(0.5, seg.length())

	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, length)
	beam.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = muzzle_color
	mat.emission_enabled = true
	mat.emission = muzzle_color
	mat.emission_energy_multiplier = 4.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat
	vfx_parent.add_child(beam)
	beam.global_position = (from_pos + to_pos) * 0.5
	beam.look_at(to_pos, Vector3.UP)

	var tw := beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.095)
	tw.tween_callback(beam.queue_free)


func _tick_interact_fx(delta: float) -> void:
	_set_interact_bar_visible(true)
	_interact_progress += delta * 0.45
	if _interact_progress >= 1.0:
		_interact_progress = 0.0
		var label := _nearest_station_label if not _nearest_station_label.is_empty() else "戰術道具／鎖具"
		interaction_completed.emit(char_id, label)
		_spawn_dust_puff(global_position + Vector3(-sin(_facing_yaw), 0.4, -cos(_facing_yaw)) * 0.6, accent_color)

	if interact_bar_fill != null:
		var pct := clampf(_interact_progress, 0.06, 1.0)
		interact_bar_fill.scale.x = pct
		interact_bar_fill.position.x = -(1.0 - pct) * 0.49

	_interact_spark_timer -= delta
	if _interact_spark_timer <= 0.0:
		_interact_spark_timer = 0.20
		var hand_front := global_position + Vector3(-sin(_facing_yaw), 0.88, -cos(_facing_yaw)) * 0.56
		_spawn_tinker_spark(hand_front)


func _set_interact_bar_visible(vis: bool) -> void:
	if interact_bar_root != null:
		interact_bar_root.visible = vis


func _spawn_tinker_spark(origin: Vector3) -> void:
	if vfx_parent == null:
		return
	var spark := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.07
	sph.height = 0.14
	spark.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.90, 0.48)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.35)
	mat.emission_energy_multiplier = 3.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material_override = mat
	vfx_parent.add_child(spark)
	spark.global_position = origin + Vector3(randf_range(-0.18, 0.18), randf_range(-0.08, 0.18), randf_range(-0.18, 0.18))
	var dest := spark.global_position + Vector3(randf_range(-0.38, 0.38), randf_range(0.28, 0.62), randf_range(-0.38, 0.38))

	var tw := spark.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spark, "global_position", dest, 0.28)
	tw.tween_property(spark, "scale", Vector3.ONE * 0.15, 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(spark.queue_free)


func _spawn_dust_puff(origin: Vector3, tint: Color = Color(0.76, 0.72, 0.66, 0.75), count: int = 4) -> void:
	if vfx_parent == null:
		return
	for _i in range(count):
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
