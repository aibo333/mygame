class_name SquadCharacter
extends CharacterBody3D

signal action_changed(char_id: String, action_name: String)
signal interaction_completed(char_id: String, station_label: String)
signal shot_fired(muzzle_pos: Vector3, shot_dir: Vector3, damage: float)
signal hp_changed(current_hp: float, max_hp: float)
signal vitals_changed(hp: float, max_hp: float, stamina: float, max_stamina: float, hunger: float, max_hunger: float)
signal ammo_changed(ammo_in_mag: int, mag_size: int, is_reloading: bool)
signal weapon_switched(slot_index: int, weapon_id: String, weapon_label: String, ammo_in_mag: int, mag_size: int)
signal avatar_switched(avatar_id: String, avatar_label: String)
signal player_died()

const TOON_SHADER := preload("res://assets/shaders/anime_toon.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/anime_outline.gdshader")
const SILHOUETTE_SHADER := preload("res://assets/shaders/character_silhouette.gdshader")

const ROLL_DURATION: float = 0.62
const ROLL_IFRAME_DURATION: float = 0.48
const ROLL_COOLDOWN: float = 0.20
const ROLL_CANCEL_PROGRESS: float = 0.72
const AVATAR_SCALE: float = 1.45
const RELOAD_DURATION: float = 1.35
const SHOOT_MOVE_SPEED_MULT: float = 0.80
const FIRE_AUDIO_POOL_SIZE: int = 6
const FIRE_AUDIO_VOLUME_DB: float = -6.0
const FIRE_DISTANT_VOLUME_DB: float = -18.0
const RELOAD_AUDIO_VOLUME_DB: float = -4.0
const SILENCER_TOGGLE_DURATION: float = 1.40
const HIT_REACT_DURATION: float = 0.28

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
var reload_duration: float = RELOAD_DURATION
var supports_silencer: bool = true
var weapon_loadout: Array[Dictionary] = []
var active_weapon_slot: int = 0
var active_weapon_id: String = "m4a1s"
var active_weapon_short_name: String = "M4A1-S"
var active_avatar_id: String = SquadConfig.DEFAULT_AVATAR_ID
var _active_avatar_cfg: Dictionary = {}
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
var muzzle_point: Marker3D = null
var _weapon_mount_root: Node3D = null
var _weapon_default_local_basis: Basis = Basis.IDENTITY
var _last_aim_world_pos: Vector3 = Vector3.ZERO
var _has_aim_target: bool = false
var _weapon_models: Dictionary = {}
var _weapon_audio_cache: Dictionary = {}

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
var _hit_react_timer: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _interact_spark_timer: float = 0.0
var _interact_progress: float = 0.0
var _click_move_target: Vector3 = Vector3.ZERO
var _has_click_move: bool = false
var _follow_leader: Node3D = null
var _follow_offset: Vector3 = Vector3.ZERO
var _nearest_station_label: String = ""
var _fire_audio_pool: Array[AudioStreamPlayer] = []
var _fire_audio_idx: int = 0
var _distant_audio_pool: Array[AudioStreamPlayer] = []
var _distant_audio_idx: int = 0
var _reload_audio_player: AudioStreamPlayer = null
var _weapon_mech_audio_player: AudioStreamPlayer = null
var _fire_streams: Array[AudioStream] = []
var _fire_distant_streams: Array[AudioStream] = []
var _fire_unsilenced_streams: Array[AudioStream] = []
var _fire_unsilenced_distant_streams: Array[AudioStream] = []
var _reload_clip_out_stream: AudioStream = null
var _reload_clip_in_stream: AudioStream = null
var _reload_clip_hit_stream: AudioStream = null
var _reload_bolt_back_stream: AudioStream = null
var _reload_bolt_forward_stream: AudioStream = null
var _reload_bolt_back_unsilenced_stream: AudioStream = null
var _reload_bolt_forward_unsilenced_stream: AudioStream = null
var _reload_add_ammo_stream: AudioStream = null
var _weapon_draw_stream: AudioStream = null
var _silencer_on_stream: AudioStream = null
var _silencer_off_stream: AudioStream = null
var _silencer_screw_on_start_stream: AudioStream = null
var _silencer_screw_off_end_stream: AudioStream = null
var _silencer_screw_streams: Array[AudioStream] = []
var _reload_sfx_stage: int = 0
var silencer_attached: bool = true
var is_toggling_silencer: bool = false
var _silencer_toggle_timer: float = 0.0
var _silencer_target_state: bool = true
var _silencer_sfx_stage: int = 0


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
	_init_weapon_loadout()
	_init_model_pivot()
	switch_avatar_model(SquadConfig.DEFAULT_AVATAR_ID)
	_setup_loadout_audio()
	_apply_active_weapon_state(false)
	_play_clip("idle")


func _init_weapon_loadout() -> void:
	weapon_loadout.clear()
	for raw_w: Dictionary in SquadConfig.get_default_loadout():
		var entry: Dictionary = raw_w.duplicate(true)
		entry["ammo_in_mag"] = int(entry.get("mag_size", 30))
		weapon_loadout.append(entry)
	active_weapon_slot = 0
	if not weapon_loadout.is_empty():
		var w0: Dictionary = weapon_loadout[0]
		active_weapon_id = str(w0.get("id", "m4a1s"))
		active_weapon_short_name = str(w0.get("short_name", "M4A1-S"))
		weapon_label = str(w0.get("label", weapon_label))
		mag_size = int(w0.get("mag_size", 30))
		ammo_in_mag = mag_size
		fire_interval = float(w0.get("fire_interval", fire_interval))
		bullet_damage = float(w0.get("bullet_damage", bullet_damage))
		pellets = int(w0.get("pellets", pellets))
		spread_deg = float(w0.get("spread_deg", spread_deg))
		reload_duration = float(w0.get("reload_duration", RELOAD_DURATION))
		supports_silencer = bool(w0.get("supports_silencer", true))
		muzzle_color = w0.get("muzzle_color", muzzle_color)


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


var flashlight_light: SpotLight3D = null
var _night_lights_active: bool = false
var _flashlight_override: int = -1  # -1 = auto, 0 = forced off, 1 = forced on


func _init_model_pivot() -> void:
	if model_pivot != null:
		return
	model_pivot = Node3D.new()
	model_pivot.name = "ModelPivot"
	_facing_yaw = PI  # Initially face toward +Z (toward camera)
	model_pivot.rotation.y = _facing_yaw
	add_child(model_pivot)

	# Dynamic muzzle flash light
	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "MuzzleLight"
	muzzle_light.light_color = muzzle_color
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 5.5
	muzzle_light.position = Vector3(0.24, 1.35, -0.95)
	model_pivot.add_child(muzzle_light)

	# Tactical shoulder/weapon SpotLight3D cone pointing along facing direction (-Z)
	flashlight_light = SpotLight3D.new()
	flashlight_light.name = "TacticalFlashlight"
	flashlight_light.light_color = Color(0.86, 0.94, 1.0)
	flashlight_light.light_energy = 5.2
	flashlight_light.spot_range = 24.0
	flashlight_light.spot_angle = 36.0
	flashlight_light.spot_angle_attenuation = 0.85
	flashlight_light.spot_attenuation = 1.15
	flashlight_light.shadow_enabled = false
	flashlight_light.position = Vector3(0.18, 1.38, -0.45)
	flashlight_light.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	flashlight_light.visible = false
	model_pivot.add_child(flashlight_light)


func set_night_flashlight(night_active: bool) -> void:
	_night_lights_active = night_active
	_sync_flashlight_visibility()


func toggle_flashlight() -> bool:
	if is_flashlight_on():
		_flashlight_override = 0
	else:
		_flashlight_override = 1
	_sync_flashlight_visibility()
	return is_flashlight_on()


func reset_flashlight_auto() -> void:
	_flashlight_override = -1
	_sync_flashlight_visibility()


func is_flashlight_on() -> bool:
	if _flashlight_override == 0:
		return false
	if _flashlight_override == 1:
		return true
	return _night_lights_active


func _sync_flashlight_visibility() -> void:
	if flashlight_light != null:
		flashlight_light.visible = is_flashlight_on()


func get_active_avatar_id() -> String:
	return active_avatar_id


func switch_avatar_model(avatar_id: String) -> bool:
	var cfg: Dictionary = SquadConfig.get_avatar_config(avatar_id)
	if cfg.is_empty():
		push_warning("SquadCharacter: Unknown avatar_id '%s'" % avatar_id)
		return false
	var model_path: String = str(cfg.get("model_path", ""))
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		push_warning("SquadCharacter: Missing avatar model at %s" % model_path)
		return false
	var loaded := load(model_path) as PackedScene
	if loaded == null:
		push_warning("SquadCharacter: Failed to load avatar PackedScene at %s" % model_path)
		return false

	if model_pivot == null:
		_init_model_pivot()

	# Preserve current weapon slot ammo before rebuilding weapon mounts
	if active_weapon_slot >= 0 and active_weapon_slot < weapon_loadout.size():
		weapon_loadout[active_weapon_slot]["ammo_in_mag"] = ammo_in_mag

	# Cleanly remove and free previous avatar root (and its old skeleton, weapon mounts, and AnimationPlayer)
	if avatar_root != null and is_instance_valid(avatar_root):
		if avatar_root.get_parent() != null:
			avatar_root.get_parent().remove_child(avatar_root)
		avatar_root.queue_free()
	avatar_root = null
	skeleton = null
	anim_player = null
	_weapon_mount_root = null
	muzzle_point = null
	_weapon_models.clear()
	_loaded_clips.clear()

	_active_avatar_cfg = cfg.duplicate(true)
	active_avatar_id = str(cfg.get("id", avatar_id))

	avatar_root = loaded.instantiate() as Node3D
	avatar_root.name = "Avatar_" + active_avatar_id
	avatar_root.rotation.y = float(cfg.get("facing_yaw_offset", PI))
	avatar_root.scale = Vector3.ONE * float(cfg.get("scale", AVATAR_SCALE))
	model_pivot.add_child(avatar_root)

	skeleton = avatar_root.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		skeleton = _find_skeleton(avatar_root)

	_apply_avatar_materials(avatar_root, _active_avatar_cfg)
	_attach_tactical_rifle()
	_setup_mixamo_animations()
	_apply_active_weapon_state(false)

	current_action = "idle"
	_play_clip("idle", true)
	avatar_switched.emit(active_avatar_id, str(cfg.get("label", active_avatar_id)))
	return true


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var found := _find_skeleton(c)
		if found != null:
			return found
	return null


func _attach_tactical_rifle() -> void:
	# Mount all 3 loadout weapon models to her retargeted RightHand bone and swap visibility per active slot.
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
	_weapon_default_local_basis = Basis.from_euler(Vector3(deg_to_rad(82.0), deg_to_rad(-10.0), deg_to_rad(90.0))) * Basis(Vector3.RIGHT, PI)
	rifle.basis = _weapon_default_local_basis
	attach.add_child(rifle)
	_weapon_mount_root = rifle

	muzzle_point = Marker3D.new()
	muzzle_point.name = "MuzzlePoint"
	muzzle_point.position = Vector3(0.0, 0.055, 0.62)
	rifle.add_child(muzzle_point)

	_weapon_models.clear()
	var mounted_any: bool = false
	for wcfg: Dictionary in weapon_loadout:
		var wid: String = str(wcfg.get("id", ""))
		var mpath: String = str(wcfg.get("model_path", ""))
		if wid.is_empty() or mpath.is_empty() or not ResourceLoader.exists(mpath):
			push_warning("SquadCharacter: Missing weapon model for '%s' at %s" % [wid, mpath])
			continue
		var packed := load(mpath) as PackedScene
		if packed == null:
			continue
		var gun_model := packed.instantiate() as Node3D
		gun_model.name = str(wcfg.get("model_node_name", wid + "Model"))
		gun_model.scale = wcfg.get("model_scale", Vector3.ONE * 0.72) as Vector3
		gun_model.position = wcfg.get("model_pos", Vector3.ZERO) as Vector3
		if bool(wcfg.get("apply_m4a1s_pbr", false)):
			_apply_m4a1s_pbr_material(gun_model)
		gun_model.visible = (wid == active_weapon_id)
		rifle.add_child(gun_model)
		_weapon_models[wid] = gun_model
		mounted_any = true

	if not mounted_any:
		push_warning("SquadCharacter: Falling back to procedural rifle; no weapon models loaded")
		_build_fallback_box_rifle(rifle)


func _apply_m4a1s_pbr_material(root_node: Node) -> void:
	var dir := SquadConfig.WEAPON_M4A1S_DIR
	var mat := StandardMaterial3D.new()
	mat.resource_name = "M4A1S_PBR"

	var albedo_path := dir + "m4a1_silencer_default_color_psd_ee3b9cfe.png"
	if ResourceLoader.exists(albedo_path):
		mat.albedo_texture = load(albedo_path) as Texture2D

	var normal_path := dir + "m4a1_silencer_default_normal_tga_2fc36c61.png"
	if ResourceLoader.exists(normal_path):
		mat.normal_enabled = true
		mat.normal_texture = load(normal_path) as Texture2D

	var orm_path := dir + "m4a1_silencer_default_ao_tga_9a4bb8ca_orm.png"
	if ResourceLoader.exists(orm_path):
		var orm_tex := load(orm_path) as Texture2D
		mat.ao_enabled = true
		mat.ao_texture = orm_tex
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.roughness = 1.0
		mat.roughness_texture = orm_tex
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.metallic = 1.0
		mat.metallic_texture = orm_tex
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	else:
		mat.metallic = 0.65
		mat.roughness = 0.42

	_set_material_recursive(root_node, mat)


func _set_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s, mat)
	for c in node.get_children():
		_set_material_recursive(c, mat)


func _build_fallback_box_rifle(rifle: Node3D) -> void:
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

	var one_shot_clips: Array[String] = ["roll", "hit", "death", "reload"]
	for action_name: String in SquadConfig.MIXAMO_ANIMS.keys():
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
			clip.loop_mode = Animation.LOOP_NONE if action_name in one_shot_clips else Animation.LOOP_LINEAR
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
	var foot_pitch_deg: float = float(_active_avatar_cfg.get("foot_pitch_fix_deg", -52.0))
	var hips_y_offset: float = float(_active_avatar_cfg.get("hips_y_offset", -0.98))
	for ti in range(anim.get_track_count()):
		var raw_path: String = str(anim.track_get_path(ti))
		var colon_idx: int = raw_path.find(":")
		if colon_idx < 0:
			continue
		var sub_bone: String = raw_path.substr(colon_idx + 1)
		anim.track_set_path(ti, NodePath(skel_rel_path + ":" + sub_bone))

		# Compensate sloped ankle-to-toe bind angle around local X
		# so both shoes plant flat on the ground without bending the calves upward!
		if absf(foot_pitch_deg) > 0.01 and (sub_bone == "LeftFoot" or sub_bone == "RightFoot") and anim.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
			var foot_fix := Quaternion(Vector3.RIGHT, deg_to_rad(foot_pitch_deg))
			var kcount_r: int = anim.track_get_key_count(ti)
			for ki in range(kcount_r):
				var q: Quaternion = anim.track_get_key_value(ti, ki)
				anim.track_set_key_value(ti, ki, (q * foot_fix).normalized())

		# Strip horizontal X/Z root-motion drift AND rebase vertical Y to Hips local rest (0.0)
		# because Bip001 parent bone already sits at standing pelvis height (0.78m)!
		if sub_bone == "Hips" and anim.track_get_type(ti) == Animation.TYPE_POSITION_3D:
			var kcount: int = anim.track_get_key_count(ti)
			if kcount > 0:
				for ki in range(kcount):
					var p: Vector3 = anim.track_get_key_value(ti, ki)
					anim.track_set_key_value(ti, ki, Vector3(0.0, p.y + hips_y_offset, 0.0))


func _apply_avatar_materials(root_node: Node, avatar_cfg: Dictionary) -> void:
	var tex_dir: String = str(avatar_cfg.get("texture_dir", SquadConfig.AVATAR_DIR))
	var raw_tex_map: Dictionary = avatar_cfg.get("tex_map", {}) as Dictionary
	var tex_map: Dictionary = {}
	for mkey: String in raw_tex_map.keys():
		var fname: String = str(raw_tex_map[mkey])
		tex_map[mkey] = fname if fname.begins_with("res://") else (tex_dir + fname)

	var hide_substrings: Array = avatar_cfg.get("hide_mesh_substrings", ["hairshadow", "shy"]) as Array
	var outfit_tint := Color(0.84, 0.84, 0.86)
	var face_tint := Color(0.88, 0.88, 0.90)

	var silhouette_mat := ShaderMaterial.new()
	silhouette_mat.shader = SILHOUETTE_SHADER
	silhouette_mat.render_priority = 12
	silhouette_mat.set_shader_parameter("silhouette_color", Color(0.18, 0.78, 0.98, 0.52))
	silhouette_mat.set_shader_parameter("rim_color", Color(0.62, 0.95, 1.0, 0.94))
	silhouette_mat.set_shader_parameter("min_occluder_gap", 0.55)

	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = OUTLINE_SHADER
	outline_mat.set_shader_parameter("outline_color", Color(0.18, 0.14, 0.22, 1.0))
	outline_mat.set_shader_parameter("outline_width", 0.0038)
	outline_mat.next_pass = silhouette_mat

	_apply_materials_recursive(root_node, tex_map, hide_substrings, outfit_tint, face_tint, outline_mat, silhouette_mat)


func _apply_materials_recursive(node: Node, tex_map: Dictionary, hide_substrings: Array, outfit_tint: Color, face_tint: Color, outline_mat: ShaderMaterial, silhouette_mat: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var nlow := mi.name.to_lower()
		for hsub: Variant in hide_substrings:
			var hs: String = str(hsub).to_lower()
			if not hs.is_empty() and nlow.contains(hs):
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
				var is_brow := mname.contains("Eyebrow")

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
					else:
						toon.next_pass = silhouette_mat
					mi.set_surface_override_material(s, toon)

	for c in node.get_children():
		_apply_materials_recursive(c, tex_map, hide_substrings, outfit_tint, face_tint, outline_mat, silhouette_mat)


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
	if model_pivot != null:
		model_pivot.rotation.y = _facing_yaw
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
	for wcfg: Dictionary in weapon_loadout:
		wcfg["ammo_in_mag"] = int(wcfg.get("mag_size", 30))
	ammo_in_mag = mag_size
	is_reloading = false
	_reload_timer = 0.0
	_reload_sfx_stage = 0
	is_toggling_silencer = false
	_silencer_toggle_timer = 0.0
	_silencer_sfx_stage = 0
	if _reload_audio_player != null and _reload_audio_player.playing:
		_reload_audio_player.stop()
	if _weapon_mech_audio_player != null and _weapon_mech_audio_player.playing:
		_weapon_mech_audio_player.stop()
	for fp: AudioStreamPlayer in _fire_audio_pool:
		if fp != null and fp.playing:
			fp.stop()
	for dp: AudioStreamPlayer in _distant_audio_pool:
		if dp != null and dp.playing:
			dp.stop()
	play_draw_sfx()
	_iframe_timer = 0.0
	_hit_react_timer = 0.0
	_roll_timer = 0.0
	_roll_cd = 0.0
	_interact_progress = 0.0
	_set_action("idle", true)
	hp_changed.emit(hp, max_hp)
	vitals_changed.emit(hp, max_hp, stamina, max_stamina, hunger, max_hunger)
	ammo_changed.emit(ammo_in_mag, mag_size, is_reloading)


func switch_weapon_slot(slot_index: int) -> bool:
	if is_dead or slot_index < 0 or slot_index >= weapon_loadout.size():
		return false
	if slot_index == active_weapon_slot:
		return false
	if active_weapon_slot >= 0 and active_weapon_slot < weapon_loadout.size():
		weapon_loadout[active_weapon_slot]["ammo_in_mag"] = ammo_in_mag

	# Cancel any in-progress reload or silencer toggle safely
	is_reloading = false
	_reload_timer = 0.0
	_reload_sfx_stage = 0
	is_toggling_silencer = false
	_silencer_toggle_timer = 0.0
	_silencer_sfx_stage = 0
	if _reload_audio_player != null and _reload_audio_player.playing:
		_reload_audio_player.stop()
	if _weapon_mech_audio_player != null and _weapon_mech_audio_player.playing:
		_weapon_mech_audio_player.stop()
	for fp: AudioStreamPlayer in _fire_audio_pool:
		if fp != null and fp.playing:
			fp.stop()
	for dp: AudioStreamPlayer in _distant_audio_pool:
		if dp != null and dp.playing:
			dp.stop()

	active_weapon_slot = slot_index
	_fire_cd = 0.12
	_apply_active_weapon_state(true)
	return true


func _apply_active_weapon_state(emit_and_draw: bool) -> void:
	if active_weapon_slot < 0 or active_weapon_slot >= weapon_loadout.size():
		return
	var wcfg: Dictionary = weapon_loadout[active_weapon_slot]
	active_weapon_id = str(wcfg.get("id", "m4a1s"))
	active_weapon_short_name = str(wcfg.get("short_name", "M4A1-S"))
	weapon_label = str(wcfg.get("label", weapon_label))
	mag_size = int(wcfg.get("mag_size", 30))
	ammo_in_mag = clampi(int(wcfg.get("ammo_in_mag", mag_size)), 0, mag_size)
	fire_interval = float(wcfg.get("fire_interval", 0.14))
	bullet_damage = float(wcfg.get("bullet_damage", 28.0))
	pellets = int(wcfg.get("pellets", 1))
	spread_deg = float(wcfg.get("spread_deg", 2.5))
	reload_duration = float(wcfg.get("reload_duration", RELOAD_DURATION))
	supports_silencer = bool(wcfg.get("supports_silencer", false))
	muzzle_color = wcfg.get("muzzle_color", Color(0.55, 0.92, 1.0)) as Color

	if muzzle_light != null:
		muzzle_light.light_color = muzzle_color
	if muzzle_point != null:
		muzzle_point.position = wcfg.get("muzzle_pos", Vector3(0.0, 0.055, 0.62)) as Vector3

	for wid: String in _weapon_models.keys():
		var mnode: Node3D = _weapon_models[wid] as Node3D
		if mnode != null:
			mnode.visible = (wid == active_weapon_id)

	_bind_cached_weapon_audio(active_weapon_id)

	if emit_and_draw:
		play_draw_sfx()
		weapon_switched.emit(active_weapon_slot, active_weapon_id, weapon_label, ammo_in_mag, mag_size)
		ammo_changed.emit(ammo_in_mag, mag_size, is_reloading)


func get_weapon_count() -> int:
	return weapon_loadout.size()


func get_active_weapon_slot() -> int:
	return active_weapon_slot


func get_active_weapon_id() -> String:
	return active_weapon_id


func get_weapon_model(weapon_id: String) -> Node3D:
	return _weapon_models.get(weapon_id, null) as Node3D


func get_weapon_loadout_summary() -> Array[Dictionary]:
	if active_weapon_slot >= 0 and active_weapon_slot < weapon_loadout.size():
		weapon_loadout[active_weapon_slot]["ammo_in_mag"] = ammo_in_mag
	var summary: Array[Dictionary] = []
	for i: int in range(weapon_loadout.size()):
		var w: Dictionary = weapon_loadout[i]
		summary.append({
			"slot_index": i,
			"slot": int(w.get("slot", i + 1)),
			"id": str(w.get("id", "")),
			"short_name": str(w.get("short_name", "")),
			"label": str(w.get("label", "")),
			"ammo_in_mag": int(w.get("ammo_in_mag", 0)),
			"mag_size": int(w.get("mag_size", 30)),
			"active": i == active_weapon_slot,
		})
	return summary


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
		_hit_react_timer = 0.0
		_set_action("death", true)
		player_died.emit()
	elif _roll_timer <= 0.0 and anim_player != null and anim_player.has_animation("hit"):
		_hit_react_timer = HIT_REACT_DURATION
		_play_clip("hit", true)
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
	if is_dead or is_reloading or is_toggling_silencer or ammo_in_mag >= mag_size:
		return false
	is_reloading = true
	_reload_timer = reload_duration
	_reload_sfx_stage = 1
	_play_reload_sfx(_reload_clip_out_stream)
	ammo_changed.emit(ammo_in_mag, mag_size, true)
	return true


func toggle_silencer() -> bool:
	if not supports_silencer or is_dead or is_reloading or is_toggling_silencer or _roll_timer > 0.0:
		return false
	is_toggling_silencer = true
	_silencer_target_state = not silencer_attached
	_silencer_toggle_timer = SILENCER_TOGGLE_DURATION
	_silencer_sfx_stage = 1
	if _silencer_target_state:
		_play_mech_sfx(_silencer_screw_on_start_stream)
	else:
		_play_mech_sfx(_silencer_off_stream)
	return true


func play_draw_sfx() -> void:
	_play_mech_sfx(_weapon_draw_stream)


func play_stratagem_step_fx() -> void:
	_set_action("interact")
	var hand_front: Vector3 = global_position + Vector3(-sin(_facing_yaw), 0.92, -cos(_facing_yaw)) * 0.58
	_spawn_tinker_spark(hand_front)


func play_stratagem_complete_fx() -> void:
	_spawn_dust_puff(global_position + Vector3(-sin(_facing_yaw), 0.45, -cos(_facing_yaw)) * 0.6, accent_color, 5)
	_set_action("idle")


func _process(_delta: float) -> void:
	if _has_aim_target:
		_align_weapon_to_aim(_last_aim_world_pos)


func update_character(
	delta: float,
	move_input: Vector3,
	aim_world_pos: Vector3,
	want_shoot: bool,
	want_interact: bool,
	want_roll: bool,
	nearest_station_label: String
) -> void:
	_last_aim_world_pos = aim_world_pos
	_has_aim_target = true
	_nearest_station_label = nearest_station_label
	_roll_cd = maxf(0.0, _roll_cd - delta)
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_iframe_timer = maxf(0.0, _iframe_timer - delta)
	_hit_react_timer = maxf(0.0, _hit_react_timer - delta)

	if is_reloading:
		_reload_timer -= delta
		var reload_ratio: float = (reload_duration - _reload_timer) / maxf(0.1, reload_duration)
		var use_silenced_bolt: bool = supports_silencer and silencer_attached
		if _reload_sfx_stage < 2 and reload_ratio >= 0.31:
			_reload_sfx_stage = 2
			_play_reload_sfx(_reload_clip_in_stream)
		elif _reload_sfx_stage < 3 and reload_ratio >= 0.48:
			_reload_sfx_stage = 3
			_play_reload_sfx(_reload_clip_hit_stream)
		elif _reload_sfx_stage < 4 and reload_ratio >= 0.67:
			_reload_sfx_stage = 4
			var bb: AudioStream = _reload_bolt_back_stream if (use_silenced_bolt or _reload_bolt_back_unsilenced_stream == null) else _reload_bolt_back_unsilenced_stream
			_play_reload_sfx(bb)
		elif _reload_sfx_stage < 5 and reload_ratio >= 0.83:
			_reload_sfx_stage = 5
			var bf: AudioStream = _reload_bolt_forward_stream if (use_silenced_bolt or _reload_bolt_forward_unsilenced_stream == null) else _reload_bolt_forward_unsilenced_stream
			_play_reload_sfx(bf)
		if _reload_timer <= 0.0:
			is_reloading = false
			_reload_sfx_stage = 0
			ammo_in_mag = mag_size
			if active_weapon_slot >= 0 and active_weapon_slot < weapon_loadout.size():
				weapon_loadout[active_weapon_slot]["ammo_in_mag"] = ammo_in_mag
			_play_mech_sfx(_reload_add_ammo_stream)
			ammo_changed.emit(ammo_in_mag, mag_size, false)

	if is_toggling_silencer:
		_silencer_toggle_timer -= delta
		var toggle_elapsed: float = SILENCER_TOGGLE_DURATION - _silencer_toggle_timer
		var screw_times: Array[float] = [0.22, 0.42, 0.62, 0.82, 1.02]
		for si: int in range(screw_times.size()):
			var target_stage: int = si + 2
			if _silencer_sfx_stage < target_stage and toggle_elapsed >= screw_times[si]:
				_silencer_sfx_stage = target_stage
				if si < _silencer_screw_streams.size():
					_play_mech_sfx(_silencer_screw_streams[si])
				break
		if _silencer_sfx_stage < 7 and toggle_elapsed >= 1.22:
			_silencer_sfx_stage = 7
			_play_mech_sfx(_silencer_on_stream if _silencer_target_state else _silencer_screw_off_end_stream)
		if _silencer_toggle_timer <= 0.0:
			is_toggling_silencer = false
			_silencer_sfx_stage = 0
			silencer_attached = _silencer_target_state

	if is_dead:
		velocity = Vector3.ZERO
		_set_interact_bar_visible(false)
		_restore_weapon_default_pose()
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
		var roll_progress: float = 1.0 - (_roll_timer / ROLL_DURATION)
		var has_cancel_input: bool = move_input.length_squared() > 0.04 or want_shoot or want_interact
		if _roll_timer <= 0.0 or (roll_progress >= ROLL_CANCEL_PROGRESS and has_cancel_input):
			_roll_timer = 0.0
			play_draw_sfx()
		else:
			var speed_curve: float
			if roll_progress < 0.45:
				# Snappy front-loaded burst on roll startup instead of starting at 0.35
				speed_curve = lerpf(1.45, 1.0, ease(roll_progress / 0.45, 0.7))
			else:
				# Keep original recovery/tail deceleration curve unchanged
				speed_curve = sin((_roll_timer / ROLL_DURATION) * PI) * 0.65 + 0.35
			if anim_player != null and anim_player.current_animation == "roll":
				var tail_t: float = clampf((roll_progress - 0.25) / 0.25, 0.0, 1.0)
				anim_player.speed_scale = lerpf(3.15, 2.05, tail_t)
			velocity = _roll_dir * (roll_speed * speed_curve)
			move_and_slide()
			global_position = SquadConfig.clamp_playable(Vector3(global_position.x, 0.0, global_position.z))
			_apply_facing(delta, 18.0)
			_restore_weapon_default_pose()
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
			_restore_weapon_default_pose()
			return

	# Always face the mouse cursor (aim_world_pos) whenever alive and not rolling
	var to_aim := Vector3(aim_world_pos.x - global_position.x, 0.0, aim_world_pos.z - global_position.z)
	if to_aim.length_squared() > 0.02:
		_facing_yaw = atan2(-to_aim.x, -to_aim.z)

	if want_shoot:
		_set_interact_bar_visible(false)
		_interact_progress = 0.0

		var shoot_move_vec := Vector3.ZERO
		if move_input.length_squared() > 0.02:
			_has_click_move = false
			shoot_move_vec = move_input.normalized()
		elif _has_click_move:
			var to_dest_s := Vector3(_click_move_target.x - global_position.x, 0.0, _click_move_target.z - global_position.z)
			if to_dest_s.length() > 0.25:
				shoot_move_vec = to_dest_s.normalized()
			else:
				_has_click_move = false

		if shoot_move_vec.length_squared() > 0.01:
			var spd_mult_s: float = 1.30 if _stim_timer > 0.0 else (0.86 if hunger <= 5.0 else 1.0)
			velocity = shoot_move_vec * (move_speed * spd_mult_s * SHOOT_MOVE_SPEED_MULT)
			move_and_slide()
			global_position = SquadConfig.clamp_playable(Vector3(global_position.x, 0.0, global_position.z))
			if is_reloading:
				_set_action("reload", false, "reload_move" if _has_clip("reload_move") else _pick_directional_move_clip(shoot_move_vec))
			else:
				_set_action("shoot", false, _pick_directional_move_clip(shoot_move_vec))
			_step_dust_timer -= delta
			if _step_dust_timer <= 0.0:
				_step_dust_timer = 0.30
				_spawn_dust_puff(global_position + Vector3(0.0, 0.08, 0.0), Color(0.76, 0.72, 0.66, 0.42), 1)
		else:
			velocity = Vector3.ZERO
			if is_reloading:
				_set_action("reload", false, "reload" if _has_clip("reload") else "idle")
			else:
				_set_action("shoot", false, "shoot")

		_apply_facing(delta, 20.0)
		_align_weapon_to_aim(aim_world_pos)
		_try_fire_weapon(aim_world_pos)
		return

	if want_interact:
		_has_click_move = false
		velocity = Vector3.ZERO
		_set_action("interact")
		_tick_interact_fx(delta)
		_apply_facing(delta, 14.0)
		_restore_weapon_default_pose()
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
		if is_reloading:
			_set_action("reload", false, "reload_move" if _has_clip("reload_move") else _pick_directional_move_clip(move_vec))
		else:
			_set_action("walk", false, _pick_directional_move_clip(move_vec))
		_step_dust_timer -= delta
		if _step_dust_timer <= 0.0:
			_step_dust_timer = 0.28
			_spawn_dust_puff(global_position + Vector3(0.0, 0.08, 0.0), Color(0.76, 0.72, 0.66, 0.42), 1)
	else:
		velocity = Vector3.ZERO
		if is_reloading:
			_set_action("reload", false, "reload" if _has_clip("reload") else "idle")
		else:
			_set_action("idle")

	_apply_facing(delta, 18.0)
	_align_weapon_to_aim(aim_world_pos)


func _compute_horizontal_aim_dir(aim_world_pos: Vector3) -> Vector3:
	var to_aim := Vector3(aim_world_pos.x - global_position.x, 0.0, aim_world_pos.z - global_position.z)
	if to_aim.length_squared() > 0.02:
		return to_aim.normalized()
	return Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw)).normalized()


func _should_align_weapon_to_aim() -> bool:
	return (
		not is_dead
		and _roll_timer <= 0.0
		and not is_reloading
		and current_action in ["idle", "walk", "shoot"]
	)


func _restore_weapon_default_pose() -> void:
	if _weapon_mount_root != null:
		_weapon_mount_root.basis = _weapon_default_local_basis
	if muzzle_light != null and muzzle_point != null and muzzle_point.is_inside_tree():
		muzzle_light.global_position = muzzle_point.global_position


func _align_weapon_to_aim(aim_world_pos: Vector3) -> void:
	if _weapon_mount_root == null or not _weapon_mount_root.is_inside_tree():
		return
	if not _should_align_weapon_to_aim():
		_restore_weapon_default_pose()
		return
	var parent_node := _weapon_mount_root.get_parent() as Node3D
	if parent_node == null:
		return
	var aim_dir: Vector3 = _compute_horizontal_aim_dir(aim_world_pos)
	# Local +Z is the weapon barrel axis; Basis.looking_at(-aim_dir, UP) maps -Z -> -aim_dir, so +Z -> +aim_dir with +Y upright.
	var desired_world_rot: Basis = Basis.looking_at(-aim_dir, Vector3.UP)
	var parent_rot: Basis = parent_node.global_transform.basis.orthonormalized()
	_weapon_mount_root.basis = (parent_rot.inverse() * desired_world_rot).orthonormalized()
	if muzzle_light != null and muzzle_point != null and muzzle_point.is_inside_tree():
		muzzle_light.global_position = muzzle_point.global_position


func _apply_facing(delta: float, turn_speed: float) -> void:
	if model_pivot != null:
		model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, _facing_yaw, clampf(delta * turn_speed, 0.0, 1.0))


func _has_clip(clip_name: String) -> bool:
	return anim_player != null and anim_player.has_animation(clip_name)


func _pick_directional_move_clip(move_dir: Vector3) -> String:
	var fwd := Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))
	var right := Vector3(cos(_facing_yaw), 0.0, -sin(_facing_yaw))
	var fwd_dot: float = move_dir.dot(fwd)
	var right_dot: float = move_dir.dot(right)
	if absf(fwd_dot) >= absf(right_dot):
		if fwd_dot >= 0.0:
			return "walk"
		return "run_backwards" if _has_clip("run_backwards") else "walk"
	if right_dot >= 0.0:
		return "strafe_right" if _has_clip("strafe_right") else "walk"
	return "strafe_left" if _has_clip("strafe_left") else "walk"


func _set_action(action_name: String, force_restart: bool = false, clip_override: String = "") -> void:
	var target_clip: String = clip_override if not clip_override.is_empty() else action_name
	var hold_hit: bool = _hit_react_timer > 0.0 and action_name not in ["roll", "death"]
	if current_action == action_name and not force_restart:
		if not hold_hit and anim_player != null and action_name not in ["roll", "death"]:
			if not anim_player.is_playing() or anim_player.current_animation != target_clip:
				_play_clip(target_clip)
		return
	current_action = action_name
	if not hold_hit:
		_play_clip(target_clip, force_restart)
	action_changed.emit(char_id, action_name)


func _play_clip(action_name: String, force_restart: bool = false) -> void:
	if anim_player == null or not anim_player.has_animation(action_name):
		return
	var blend: float = 0.03 if action_name == "roll" else (0.08 if action_name in ["shoot", "hit", "death"] else 0.14)
	if action_name == "roll":
		anim_player.speed_scale = 3.15
	elif action_name in ["walk", "strafe_left", "strafe_right", "run_backwards"]:
		anim_player.speed_scale = 1.12
	elif action_name == "reload":
		anim_player.speed_scale = 1.5
	elif action_name == "hit":
		anim_player.speed_scale = 1.6
	else:
		anim_player.speed_scale = 1.0
	if force_restart:
		anim_player.stop()
	anim_player.play(action_name, blend)


func get_available_animations() -> PackedStringArray:
	return PackedStringArray(_loaded_clips)


func _try_fire_weapon(target_world_pos: Vector3) -> void:
	if _fire_cd > 0.0 or is_reloading or is_toggling_silencer:
		return
	if showcase_override_action.is_empty():
		if infinite_ammo:
			ammo_in_mag = mag_size
		else:
			if ammo_in_mag <= 0:
				start_reload()
				return
			ammo_in_mag -= 1
			if active_weapon_slot >= 0 and active_weapon_slot < weapon_loadout.size():
				weapon_loadout[active_weapon_slot]["ammo_in_mag"] = ammo_in_mag
			ammo_changed.emit(ammo_in_mag, mag_size, false)
			if ammo_in_mag <= 0:
				start_reload()

	_fire_cd = fire_interval
	_muzzle_flash_timer = 0.07
	_play_fire_sfx()

	_align_weapon_to_aim(target_world_pos)
	var base_dir: Vector3 = _compute_horizontal_aim_dir(target_world_pos)
	var muzzle_pos: Vector3 = muzzle_point.global_position if (muzzle_point != null and muzzle_point.is_inside_tree()) else (global_position + Vector3(0.0, 1.32, 0.0) + base_dir * 0.90)
	if muzzle_light != null and muzzle_point != null and muzzle_point.is_inside_tree():
		muzzle_light.global_position = muzzle_pos

	for _i in range(pellets):
		var spread_rad: float = deg_to_rad(randf_range(-spread_deg, spread_deg))
		var shot_dir: Vector3 = base_dir.rotated(Vector3.UP, spread_rad)
		var end_pos: Vector3 = muzzle_pos + shot_dir * randf_range(14.0, 18.0)
		_spawn_tracer(muzzle_pos, end_pos)
		shot_fired.emit(muzzle_pos, shot_dir, bullet_damage)


func _load_stream_list(raw_paths: Variant) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	if raw_paths is Array:
		for raw_path: Variant in raw_paths:
			var stream := _load_audio_stream(str(raw_path))
			if stream != null:
				result.append(stream)
	elif raw_paths is String:
		var single_stream := _load_audio_stream(raw_paths)
		if single_stream != null:
			result.append(single_stream)
	return result


func _setup_loadout_audio() -> void:
	_weapon_audio_cache.clear()
	for wcfg: Dictionary in weapon_loadout:
		var wid: String = str(wcfg.get("id", ""))
		var sfx_cfg: Dictionary = wcfg.get("sfx", {}) as Dictionary
		if wid.is_empty():
			continue
		_weapon_audio_cache[wid] = {
			"fire": _load_stream_list(sfx_cfg.get("fire", [])),
			"fire_distant": _load_stream_list(sfx_cfg.get("fire_distant", [])),
			"fire_unsilenced": _load_stream_list(sfx_cfg.get("fire_unsilenced", [])),
			"fire_unsilenced_distant": _load_stream_list(sfx_cfg.get("fire_unsilenced_distant", [])),
			"clip_out": _load_audio_stream(str(sfx_cfg.get("clip_out", ""))),
			"clip_in": _load_audio_stream(str(sfx_cfg.get("clip_in", ""))),
			"clip_hit": _load_audio_stream(str(sfx_cfg.get("clip_hit", ""))),
			"bolt_back": _load_audio_stream(str(sfx_cfg.get("bolt_back", ""))),
			"bolt_forward": _load_audio_stream(str(sfx_cfg.get("bolt_forward", ""))),
			"bolt_back_unsilenced": _load_audio_stream(str(sfx_cfg.get("bolt_back_unsilenced", ""))),
			"bolt_forward_unsilenced": _load_audio_stream(str(sfx_cfg.get("bolt_forward_unsilenced", ""))),
			"add_ammo": _load_audio_stream(str(sfx_cfg.get("add_ammo", ""))),
			"draw": _load_audio_stream(str(sfx_cfg.get("draw", ""))),
			"silencer_on": _load_audio_stream(str(sfx_cfg.get("silencer_on", ""))),
			"silencer_off": _load_audio_stream(str(sfx_cfg.get("silencer_off", ""))),
			"silencer_screw_on_start": _load_audio_stream(str(sfx_cfg.get("silencer_screw_on_start", ""))),
			"silencer_screw_off_end": _load_audio_stream(str(sfx_cfg.get("silencer_screw_off_end", ""))),
			"silencer_screws": _load_stream_list(sfx_cfg.get("silencer_screws", [])),
		}

	if _fire_audio_pool.is_empty():
		for i: int in range(FIRE_AUDIO_POOL_SIZE):
			var player := AudioStreamPlayer.new()
			player.name = "WeaponFireAudio%d" % i
			player.volume_db = FIRE_AUDIO_VOLUME_DB
			add_child(player)
			_fire_audio_pool.append(player)

	if _distant_audio_pool.is_empty():
		for i: int in range(FIRE_AUDIO_POOL_SIZE):
			var dplayer := AudioStreamPlayer.new()
			dplayer.name = "WeaponDistantAudio%d" % i
			dplayer.volume_db = FIRE_DISTANT_VOLUME_DB
			add_child(dplayer)
			_distant_audio_pool.append(dplayer)

	if _reload_audio_player == null:
		_reload_audio_player = AudioStreamPlayer.new()
		_reload_audio_player.name = "WeaponReloadAudio"
		_reload_audio_player.volume_db = RELOAD_AUDIO_VOLUME_DB
		add_child(_reload_audio_player)

	if _weapon_mech_audio_player == null:
		_weapon_mech_audio_player = AudioStreamPlayer.new()
		_weapon_mech_audio_player.name = "WeaponMechAudio"
		_weapon_mech_audio_player.volume_db = RELOAD_AUDIO_VOLUME_DB
		add_child(_weapon_mech_audio_player)

	_bind_cached_weapon_audio(active_weapon_id)


func _bind_cached_weapon_audio(weapon_id: String) -> void:
	_fire_streams.clear()
	_fire_distant_streams.clear()
	_fire_unsilenced_streams.clear()
	_fire_unsilenced_distant_streams.clear()
	_silencer_screw_streams.clear()

	_reload_clip_out_stream = null
	_reload_clip_in_stream = null
	_reload_clip_hit_stream = null
	_reload_bolt_back_stream = null
	_reload_bolt_forward_stream = null
	_reload_bolt_back_unsilenced_stream = null
	_reload_bolt_forward_unsilenced_stream = null
	_reload_add_ammo_stream = null
	_weapon_draw_stream = null
	_silencer_on_stream = null
	_silencer_off_stream = null
	_silencer_screw_on_start_stream = null
	_silencer_screw_off_end_stream = null

	var bank: Dictionary = _weapon_audio_cache.get(weapon_id, {}) as Dictionary
	if bank.is_empty():
		return
	_fire_streams.assign(bank.get("fire", []))
	_fire_distant_streams.assign(bank.get("fire_distant", []))
	_fire_unsilenced_streams.assign(bank.get("fire_unsilenced", []))
	_fire_unsilenced_distant_streams.assign(bank.get("fire_unsilenced_distant", []))

	_reload_clip_out_stream = bank.get("clip_out", null) as AudioStream
	_reload_clip_in_stream = bank.get("clip_in", null) as AudioStream
	_reload_clip_hit_stream = bank.get("clip_hit", null) as AudioStream
	_reload_bolt_back_stream = bank.get("bolt_back", null) as AudioStream
	_reload_bolt_forward_stream = bank.get("bolt_forward", null) as AudioStream
	_reload_bolt_back_unsilenced_stream = bank.get("bolt_back_unsilenced", null) as AudioStream
	_reload_bolt_forward_unsilenced_stream = bank.get("bolt_forward_unsilenced", null) as AudioStream
	_reload_add_ammo_stream = bank.get("add_ammo", null) as AudioStream
	_weapon_draw_stream = bank.get("draw", null) as AudioStream

	_silencer_on_stream = bank.get("silencer_on", null) as AudioStream
	_silencer_off_stream = bank.get("silencer_off", null) as AudioStream
	_silencer_screw_on_start_stream = bank.get("silencer_screw_on_start", null) as AudioStream
	_silencer_screw_off_end_stream = bank.get("silencer_screw_off_end", null) as AudioStream
	_silencer_screw_streams.assign(bank.get("silencer_screws", []))


func get_bound_fire_stream_paths() -> Dictionary:
	var to_paths := func(arr: Array[AudioStream]) -> Array[String]:
		var out: Array[String] = []
		for s: AudioStream in arr:
			if s != null:
				out.append(s.resource_path)
		return out
	return {
		"fire": to_paths.call(_fire_streams),
		"fire_distant": to_paths.call(_fire_distant_streams),
		"fire_unsilenced": to_paths.call(_fire_unsilenced_streams),
		"fire_unsilenced_distant": to_paths.call(_fire_unsilenced_distant_streams),
	}


func _load_audio_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _play_fire_sfx() -> void:
	var use_silenced: bool = supports_silencer and silencer_attached
	var use_unsilenced_alt: bool = supports_silencer and not silencer_attached and not _fire_unsilenced_streams.is_empty()
	var active_fire: Array[AudioStream] = _fire_unsilenced_streams if use_unsilenced_alt else _fire_streams
	if not active_fire.is_empty() and not _fire_audio_pool.is_empty():
		var player: AudioStreamPlayer = _fire_audio_pool[_fire_audio_idx % _fire_audio_pool.size()]
		_fire_audio_idx = (_fire_audio_idx + 1) % _fire_audio_pool.size()
		player.stream = active_fire[randi() % active_fire.size()]
		player.volume_db = FIRE_AUDIO_VOLUME_DB if use_silenced else (FIRE_AUDIO_VOLUME_DB + 2.0)
		player.pitch_scale = randf_range(0.96, 1.04)
		player.play()

	var use_unsilenced_distant_alt: bool = supports_silencer and not silencer_attached and not _fire_unsilenced_distant_streams.is_empty()
	var active_distant: Array[AudioStream] = _fire_unsilenced_distant_streams if use_unsilenced_distant_alt else _fire_distant_streams
	if not active_distant.is_empty() and not _distant_audio_pool.is_empty():
		var dplayer: AudioStreamPlayer = _distant_audio_pool[_distant_audio_idx % _distant_audio_pool.size()]
		_distant_audio_idx = (_distant_audio_idx + 1) % _distant_audio_pool.size()
		dplayer.stream = active_distant[randi() % active_distant.size()]
		dplayer.volume_db = FIRE_DISTANT_VOLUME_DB if use_silenced else (FIRE_DISTANT_VOLUME_DB + 3.0)
		dplayer.pitch_scale = randf_range(0.96, 1.04)
		dplayer.play()


func _play_reload_sfx(stream: AudioStream) -> void:
	if stream == null or _reload_audio_player == null:
		return
	_reload_audio_player.stream = stream
	_reload_audio_player.pitch_scale = randf_range(0.98, 1.02)
	_reload_audio_player.play()


func _play_mech_sfx(stream: AudioStream) -> void:
	if stream == null or _weapon_mech_audio_player == null:
		return
	_weapon_mech_audio_player.stream = stream
	_weapon_mech_audio_player.pitch_scale = randf_range(0.98, 1.02)
	_weapon_mech_audio_player.play()


func has_weapon_audio() -> bool:
	var base_ok: bool = (
		not _fire_streams.is_empty()
		and not _fire_distant_streams.is_empty()
		and _weapon_draw_stream != null
		and _reload_clip_out_stream != null
		and _reload_clip_in_stream != null
		and _reload_add_ammo_stream != null
		and not _fire_audio_pool.is_empty()
		and _reload_audio_player != null
		and _weapon_mech_audio_player != null
	)
	if supports_silencer:
		return (
			base_ok
			and not _fire_unsilenced_streams.is_empty()
			and _silencer_screw_streams.size() == 5
			and _reload_clip_hit_stream != null
		)
	return base_ok


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
