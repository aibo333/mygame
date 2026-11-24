class_name RuinsBaseWorld
extends Node3D

var camera_rig: LolCameraController = null
var hud: SquadHud = null
var vfx_root: Node3D = null
var squad_root: Node3D = null
var env_root: Node3D = null

var squad: Array[SquadCharacter] = []
var active_index: int = 0
var sync_all_preview: bool = false

var _station_markers: Array[Dictionary] = []
var _furnace_lights: Array[OmniLight3D] = []
var _flicker_lamps: Array[OmniLight3D] = []
var _time_elapsed: float = 0.0
var _aim_cursor: MeshInstance3D = null


func _ready() -> void:
	_build_dusk_environment()
	_build_ground_and_road()
	_build_kabaneri_train_base()
	_build_gfl2_urban_ruins()
	_build_interactive_stations()
	_build_aim_cursor()
	_setup_squad_and_camera()
	_setup_hud()


func _build_dusk_environment() -> void:
	# Girls' Frontline 2 × Kabaneri Cinematic Dusk Atmosphere:
	# Cool steel-blue twilight sky aloft + warm amber sunset horizon + subtle depth fog + ACES bloom!
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.09, 0.13, 0.24)
	sky_mat.sky_horizon_color = Color(0.76, 0.41, 0.26)
	sky_mat.ground_bottom_color = Color(0.08, 0.09, 0.12)
	sky_mat.ground_horizon_color = Color(0.28, 0.20, 0.19)
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.64)
	env.ambient_light_energy = 0.72

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.85
	env.glow_bloom = 0.24
	env.glow_hdr_threshold = 1.05

	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.28, 0.30)
	env.fog_density = 0.0052
	env.fog_aerial_perspective = 0.35

	var world_env := WorldEnvironment.new()
	world_env.name = "DuskWorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Low-angle Warm Sunset Key Sun (casts long dramatic shadows across ruins & train!)
	var sunset := DirectionalLight3D.new()
	sunset.name = "SunsetKeyLight"
	sunset.light_color = Color(1.0, 0.72, 0.48)
	sunset.light_energy = 1.65
	sunset.shadow_enabled = true
	sunset.directional_shadow_max_distance = 75.0
	sunset.rotation_degrees = Vector3(-34.0, 38.0, 0.0)
	add_child(sunset)

	# Cool Twilight Rim/Fill Light from opposite sky hemisphere
	var sky_fill := DirectionalLight3D.new()
	sky_fill.name = "TwilightFillLight"
	sky_fill.light_color = Color(0.55, 0.70, 1.0)
	sky_fill.light_energy = 0.48
	sky_fill.shadow_enabled = false
	sky_fill.rotation_degrees = Vector3(-52.0, -140.0, 0.0)
	add_child(sky_fill)


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _make_ground_mat(tex_path: String, fallback_col: Color, uv_tile: Vector3, roughness: float = 0.90) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fallback_col
	mat.roughness = roughness
	mat.metallic = 0.04
	var tex := _load_tex(tex_path)
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE.lerp(fallback_col, 0.28)
		mat.uv1_scale = uv_tile
	return mat


func _build_ground_and_road() -> void:
	env_root = Node3D.new()
	env_root.name = "EnvironmentRoot"
	add_child(env_root)

	vfx_root = Node3D.new()
	vfx_root.name = "VfxRoot"
	add_child(vfx_root)

	# Main Cracked Urban Asphalt Boulevard
	var asphalt_mat := _make_ground_mat("res://assets/textures/env/asphalt_cracked.png", Color(0.42, 0.44, 0.48), Vector3(14.0, 10.0, 1.0), 0.92)
	_add_static_box(env_root, "MainAsphaltRoad", Vector3(96.0, 0.4, 72.0), Vector3(0.0, -0.2, 0.0), asphalt_mat)

	# Elevated Crushed Gravel Rail Bed along Z = -9.2 (where the Kabaneri Armored Train rests!)
	var ballast_mat := StandardMaterial3D.new()
	ballast_mat.albedo_color = Color(0.24, 0.22, 0.23)
	ballast_mat.roughness = 0.96
	_add_static_box(env_root, "RailBallastBed", Vector3(92.0, 0.14, 6.2), Vector3(0.0, 0.02, SquadConfig.TRAIN_POSITION.z), ballast_mat)

	# Sidewalk Concrete Apron & Curbs framing the ruined avenue
	var conc_mat := _make_ground_mat("res://assets/textures/env/ruined_concrete.png", Color(0.55, 0.56, 0.60), Vector3(12.0, 2.0, 1.0), 0.90)
	_add_static_box(env_root, "NorthSidewalk", Vector3(92.0, 0.22, 6.0), Vector3(0.0, 0.06, -15.5), conc_mat)
	_add_static_box(env_root, "SouthSidewalk", Vector3(92.0, 0.24, 7.5), Vector3(0.0, 0.07, 17.5), conc_mat)

	# Faded Post-Apocalyptic Road Lane Dashes & Plaza Hazard Lines
	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = Color(0.76, 0.66, 0.42, 0.72)
	paint_mat.roughness = 0.85
	for i in range(-5, 6):
		var dash := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.2, 0.02, 0.22)
		dash.mesh = box
		dash.material_override = paint_mat
		dash.position = Vector3(float(i) * 6.5, 0.015, 5.4)
		env_root.add_child(dash)

	# Extended Rail Tracks running east/west off into the ruined horizon
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.26, 0.24, 0.24)
	rail_mat.metallic = 0.75
	rail_mat.roughness = 0.48
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rbox := BoxMesh.new()
		rbox.size = Vector3(92.0, 0.14, 0.16)
		rail.mesh = rbox
		rail.material_override = rail_mat
		rail.position = Vector3(0.0, 0.12, SquadConfig.TRAIN_POSITION.z + side * 1.56)
		env_root.add_child(rail)


func _build_kabaneri_train_base() -> void:
	var train_holder := Node3D.new()
	train_holder.name = "KabaneriArmoredTrainBase"
	train_holder.position = SquadConfig.TRAIN_POSITION
	env_root.add_child(train_holder)

	var train_scene := load("res://assets/models/train/kabaneri_armored_train.glb")
	if train_scene is PackedScene:
		var inst := (train_scene as PackedScene).instantiate()
		inst.name = "TrainModel"
		train_holder.add_child(inst)
	else:
		push_warning("RuinsBaseWorld: Could not load kabaneri_armored_train.glb")

	# Train invisible blocker collider so characters don't clip through the armored hull
	_add_invisible_collider(train_holder, "TrainHullCollider", Vector3(33.5, 5.5, 4.4), Vector3(-0.8, 2.75, 0.0))

	# Pulsing Kabaneri Locomotive Furnace Core Orange Glow Light
	var furnace_light := OmniLight3D.new()
	furnace_light.name = "FurnaceCoreLight"
	furnace_light.light_color = Color(1.0, 0.42, 0.12)
	furnace_light.light_energy = 4.5
	furnace_light.omni_range = 12.0
	furnace_light.position = Vector3(10.3, 2.8, 3.1)
	train_holder.add_child(furnace_light)
	_furnace_lights.append(furnace_light)

	# Warm Amber Interior Light inside the Open Workshop Base Bay
	var bay_light := OmniLight3D.new()
	bay_light.name = "WorkshopBayLight"
	bay_light.light_color = Color(1.0, 0.72, 0.36)
	bay_light.light_energy = 3.8
	bay_light.omni_range = 11.5
	bay_light.position = Vector3(-2.6, 3.6, 2.6)
	train_holder.add_child(bay_light)
	_furnace_lights.append(bay_light)

	# Twin Locomotive High-Intensity Searchlight SpotLights sweeping east across the ruins!
	for side in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		spot.name = "TrainHeadlight_%s" % ("L" if side < 0 else "R")
		spot.light_color = Color(1.0, 0.90, 0.68)
		spot.light_energy = 8.5
		spot.spot_range = 34.0
		spot.spot_angle = 26.0
		spot.spot_attenuation = 1.2
		spot.position = Vector3(14.5, 3.4, side * 1.15)
		spot.rotation_degrees = Vector3(-8.0, -90.0, 0.0)
		train_holder.add_child(spot)

	# Billowing Steam & Glowing Ember Particles from the Twin Armored Smokestacks!
	for sx in [12.3, 10.4]:
		_add_smokestack_particles(train_holder, Vector3(sx, 6.2, 0.0))


func _add_smokestack_particles(parent: Node3D, origin: Vector3) -> void:
	var steam := CPUParticles3D.new()
	steam.name = "SteamPlume"
	steam.position = origin
	steam.amount = 24
	steam.lifetime = 2.8
	steam.preprocess = 1.5
	steam.direction = Vector3(-0.35, 1.0, -0.15).normalized()
	steam.spread = 22.0
	steam.initial_velocity_min = 1.8
	steam.initial_velocity_max = 3.4
	steam.gravity = Vector3(-0.8, 0.5, 0.0)
	steam.scale_amount_min = 0.55
	steam.scale_amount_max = 1.65

	var sph := SphereMesh.new()
	sph.radius = 0.38
	sph.height = 0.76
	sph.radial_segments = 8
	sph.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.68, 0.64, 0.66, 0.34)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sph.material = mat
	steam.mesh = sph
	parent.add_child(steam)


func _spawn_glb_prop(path: String, p_name: String, pos: Vector3, rot_y_deg: float, prop_scale: float = 1.0, collider_size: Vector3 = Vector3.ZERO) -> Node3D:
	var holder := Node3D.new()
	holder.name = p_name
	holder.position = pos
	holder.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	holder.scale = Vector3.ONE * prop_scale
	env_root.add_child(holder)

	var res := load(path)
	if res is PackedScene:
		holder.add_child((res as PackedScene).instantiate())

	if collider_size.length_squared() > 0.01:
		_add_invisible_collider(holder, p_name + "_Col", collider_size, Vector3(0.0, collider_size.y * 0.5, 0.0))
	return holder


func _build_gfl2_urban_ruins() -> void:
	var bldg_a := "res://assets/models/ruins/building_ruin_a.glb"
	var bldg_b := "res://assets/models/ruins/building_ruin_b.glb"
	var overpass := "res://assets/models/ruins/overpass_pillar.glb"
	var car := "res://assets/models/ruins/wrecked_car.glb"
	var cover := "res://assets/models/ruins/tactical_cover.glb"
	var lamp := "res://assets/models/ruins/streetlight_broken.glb"

	# Northern Ruined City Skyline Backdrop (behind the Kabaneri Train!)
	_spawn_glb_prop(bldg_a, "NorthRuin_West", Vector3(-22.0, 0.0, -20.5), 4.0, 1.25)
	_spawn_glb_prop(bldg_b, "NorthRuin_MidW", Vector3(-9.5, 0.0, -21.5), -6.0, 1.30)
	_spawn_glb_prop(bldg_a, "NorthRuin_MidE", Vector3(6.5, 0.0, -21.0), 178.0, 1.20)
	_spawn_glb_prop(bldg_b, "NorthRuin_East", Vector3(21.0, 0.0, -20.5), 10.0, 1.35)

	# Towering Collapsed Highway Viaduct on the East Flank (iconic GFL2 ruin landmark!)
	_spawn_glb_prop(overpass, "HighwayOverpass_East", Vector3(26.5, 0.0, 3.5), -96.0, 1.15, Vector3(3.2, 6.0, 3.0))
	_spawn_glb_prop(bldg_b, "WestFlankRuin", Vector3(-28.5, 0.0, 5.0), 86.0, 1.18, Vector3(7.0, 7.0, 5.5))

	# Foreground/South Low Ruins Silhouette (kept low/wide so LoL camera view is NEVER obstructed!)
	_spawn_glb_prop(wrecked_car, "WreckedCar_West", Vector3(-16.5, 0.0, 9.2), 28.0, 1.05, Vector3(4.2, 1.6, 2.0))
	_spawn_glb_prop(wrecked_car, "WreckedCar_East", Vector3(15.2, 0.0, 1.8), -142.0, 1.0, Vector3(4.2, 1.6, 2.0))
	_spawn_glb_prop(wrecked_car, "WreckedCar_South", Vector3(2.8, 0.0, 13.8), 14.0, 1.0, Vector3(4.2, 1.6, 2.0))

	# Tactical Cover Clusters (Concrete Jersey Barriers + Sandbags + Barrels)
	_spawn_glb_prop(cover, "Cover_WestPlaza", Vector3(-9.5, 0.0, 1.8), 12.0, 1.0, Vector3(4.8, 1.2, 1.2))
	_spawn_glb_prop(cover, "Cover_CenterLeft", Vector3(-4.2, 0.0, 7.6), -8.0, 1.0, Vector3(4.8, 1.2, 1.2))
	_spawn_glb_prop(cover, "Cover_CenterRight", Vector3(7.5, 0.0, 6.8), 162.0, 1.0, Vector3(4.8, 1.2, 1.2))
	_spawn_glb_prop(cover, "Cover_EastRoad", Vector3(13.5, 0.0, 11.2), -24.0, 1.0, Vector3(4.8, 1.2, 1.2))

	# Bent Post-Apocalyptic Streetlights (two still casting warm flickering amber cones!)
	var lamp_positions: Array[Dictionary] = [
		{"pos": Vector3(-13.8, 0.0, -3.2), "rot": 14.0, "lit": true},
		{"pos": Vector3(11.4, 0.0, -3.0), "rot": -162.0, "lit": true},
		{"pos": Vector3(-12.0, 0.0, 14.6), "rot": -75.0, "lit": false},
		{"pos": Vector3(11.5, 0.0, 14.8), "rot": -105.0, "lit": false},
	]
	for i in range(lamp_positions.size()):
		var lp: Dictionary = lamp_positions[i]
		_spawn_glb_prop(lamp, "StreetLamp_%d" % i, lp["pos"], lp["rot"], 1.0)
		if bool(lp["lit"]):
			var l_omni := OmniLight3D.new()
			l_omni.name = "LampGlow_%d" % i
			l_omni.light_color = Color(1.0, 0.76, 0.44)
			l_omni.light_energy = 2.6
			l_omni.omni_range = 10.5
			l_omni.position = (lp["pos"] as Vector3) + Vector3(0.0, 5.4, 0.0)
			env_root.add_child(l_omni)
			_flicker_lamps.append(l_omni)


func _build_interactive_stations() -> void:
	var crate_path := "res://assets/models/ruins/supply_crate.glb"
	for st in SquadConfig.get_interactive_stations():
		var pos: Vector3 = st["pos"]
		if bool(st.get("is_crate", false)):
			_spawn_glb_prop(crate_path, "Station_" + str(st["id"]), pos, randf_range(-25.0, 25.0), 1.05, Vector3(1.3, 0.9, 0.9))

		# Subtle cyan tactical ground ring marking interactive zone ("摸東摸西"點位!)
		var ring := MeshInstance3D.new()
		ring.name = "InteractRing_" + str(st["id"])
		var torus := TorusMesh.new()
		torus.inner_radius = 1.05
		torus.outer_radius = 1.16
		torus.rings = 28
		torus.ring_segments = 8
		ring.mesh = torus
		ring.position = Vector3(pos.x, 0.04, pos.z)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.28, 0.86, 1.0, 0.65)
		mat.emission_enabled = true
		mat.emission = Color(0.28, 0.86, 1.0)
		mat.emission_energy_multiplier = 1.6
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		env_root.add_child(ring)

		var entry := st.duplicate()
		entry["ring"] = ring
		_station_markers.append(entry)


func _build_aim_cursor() -> void:
	_aim_cursor = MeshInstance3D.new()
	_aim_cursor.name = "GroundAimCursor"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.31
	torus.rings = 20
	torus.ring_segments = 6
	_aim_cursor.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.90, 0.45, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.35)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_cursor.material_override = mat
	_aim_cursor.position = Vector3(0.0, 0.05, 0.0)
	add_child(_aim_cursor)


func _setup_squad_and_camera() -> void:
	squad_root = Node3D.new()
	squad_root.name = "SquadRoot"
	add_child(squad_root)

	for char_id in SquadConfig.get_squad_ids():
		var cfg: Dictionary = SquadConfig.get_character(char_id)
		var girl := SquadCharacter.new()
		girl.name = "Girl_" + char_id
		squad_root.add_child(girl)
		girl.setup(cfg, vfx_root)
		girl.global_position = cfg["spawn_pos"]
		girl.action_changed.connect(_on_character_action_changed)
		girl.interaction_completed.connect(_on_interaction_completed)
		squad.append(girl)

	camera_rig = LolCameraController.new()
	camera_rig.name = "LolCameraController"
	add_child(camera_rig)
	camera_rig.lock_mode_changed.connect(_on_camera_lock_changed)

	select_character(0, true)


func _setup_hud() -> void:
	hud = SquadHud.new()
	hud.name = "SquadHud"
	add_child(hud)
	hud.setup(squad)
	hud.character_selected.connect(func(idx: int): select_character(idx, false))
	hud.action_preview_requested.connect(_on_hud_action_preview)
	hud.sync_all_toggled.connect(func(enabled: bool): sync_all_preview = enabled)
	hud.camera_lock_toggled.connect(func(): camera_rig.toggle_camera_lock())
	hud.camera_recenter_requested.connect(func(): camera_rig.recenter_on_target())
	hud.set_active_character(active_index)
	hud.set_camera_locked(camera_rig.camera_locked)


func select_character(idx: int, snap_camera: bool = false) -> void:
	if squad.is_empty():
		return
	active_index = clampi(idx, 0, squad.size() - 1)
	var leader := squad[active_index]

	var follower_offsets: Array[Vector3] = [Vector3(-2.1, 0.0, 1.5), Vector3(2.1, 0.0, 1.5)]
	var f_slot := 0
	for i in range(squad.size()):
		var g := squad[i]
		if i == active_index:
			g.set_active(true)
			g.set_follow_leader(null, Vector3.ZERO)
		else:
			g.set_active(false)
			g.set_follow_leader(leader, follower_offsets[f_slot % follower_offsets.size()])
			f_slot += 1

	if camera_rig != null:
		camera_rig.set_follow_target(leader, snap_camera)
	if hud != null:
		hud.set_active_character(active_index)
		hud.push_status("切換操控：%s（%s）" % [leader.display_name, leader.weapon_label])


func get_active_character() -> SquadCharacter:
	if squad.is_empty():
		return null
	return squad[active_index]


func _on_hud_action_preview(action_name: String) -> void:
	if sync_all_preview:
		for g in squad:
			g.trigger_preview_action(action_name)
		if hud != null:
			hud.push_status("全員同步預覽動作：%s" % _action_zh(action_name))
	else:
		var active := get_active_character()
		if active != null:
			active.trigger_preview_action(action_name)
			if hud != null:
				hud.push_status("%s 執行動作：%s" % [active.display_name, _action_zh(action_name)])


func _on_character_action_changed(char_id: String, action_name: String) -> void:
	if hud != null:
		hud.update_character_action(char_id, action_name)


func _on_interaction_completed(char_id: String, station_label: String) -> void:
	var who := char_id
	for g in squad:
		if g.char_id == char_id:
			who = g.display_name
			break
	if hud != null:
		hud.push_status("✓ %s 完成了【%s】操作！" % [who, station_label])


func _on_camera_lock_changed(locked: bool) -> void:
	if hud != null:
		hud.set_camera_locked(locked)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				select_character(0)
			KEY_2:
				select_character(1)
			KEY_3:
				select_character(2)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and camera_rig != null:
			var click_pos: Vector3 = camera_rig.raycast_ground(mb.position, 0.0)
			var active := get_active_character()
			if active != null:
				active.set_click_move_target(click_pos)
				_spawn_move_ping(click_pos)


func _physics_process(delta: float) -> void:
	_time_elapsed += delta
	_animate_dusk_lights()

	if squad.is_empty() or camera_rig == null:
		return

	var active := get_active_character()
	var vp := get_viewport()
	var aim_pos := active.global_position + Vector3.FORWARD * 4.0
	if vp != null:
		aim_pos = camera_rig.raycast_ground(vp.get_mouse_position(), 0.0)

	if _aim_cursor != null:
		_aim_cursor.global_position = Vector3(aim_pos.x, 0.05, aim_pos.z)

	# WASD movement aligned to LoL fixed camera (W = -Z north, S = +Z south, A = -X west, D = +X east)
	var move_in := Vector3.ZERO
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W):
		move_in.z -= 1.0
	if Input.is_action_pressed("move_back") or Input.is_key_pressed(KEY_S):
		move_in.z += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
		move_in.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
		move_in.x += 1.0

	var mouse_over_ui: bool = hud != null and hud.is_mouse_over_controls()
	var want_shoot: bool = (not mouse_over_ui) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var want_interact: bool = Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_F)
	var want_roll: bool = Input.is_action_just_pressed("dodge") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)

	var nearest_label := _find_nearest_station_label(active.global_position)
	if hud != null:
		hud.set_interact_hint(nearest_label)

	for i in range(squad.size()):
		var g := squad[i]
		if i == active_index:
			g.update_character(delta, move_in, aim_pos, want_shoot, want_interact, want_roll, nearest_label)
		else:
			g.update_character(delta, Vector3.ZERO, aim_pos, false, false, false, "")


func _find_nearest_station_label(pos: Vector3) -> String:
	var best_dist := 3.4
	var best_label := ""
	for st in _station_markers:
		var spos: Vector3 = st["pos"]
		var d: float = Vector2(pos.x - spos.x, pos.z - spos.z).length()
		if d < best_dist:
			best_dist = d
			best_label = str(st["label"])
	return best_label


func _animate_dusk_lights() -> void:
	# Subtle Kabaneri furnace pulse & broken dusk streetlight flicker
	for i in range(_furnace_lights.size()):
		var l := _furnace_lights[i]
		if is_instance_valid(l):
			l.light_energy = (4.3 if i == 0 else 3.7) + sin(_time_elapsed * 4.2 + float(i) * 1.7) * 0.45
	for i in range(_flicker_lamps.size()):
		var f := _flicker_lamps[i]
		if is_instance_valid(f):
			var wave := sin(_time_elapsed * 13.0 + float(i) * 3.1) * sin(_time_elapsed * 3.7)
			f.light_energy = 1.4 if wave > 0.72 else 2.6


func _spawn_move_ping(pos: Vector3) -> void:
	if vfx_root == null:
		return
	var ping := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.34
	ping.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.38, 0.92, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.38, 0.92, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ping.material_override = mat
	vfx_root.add_child(ping)
	ping.global_position = Vector3(pos.x, 0.05, pos.z)

	var tw := ping.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ping, "scale", Vector3.ONE * 2.2, 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(ping.queue_free)


func _add_static_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	body.add_child(mi)


func _add_invisible_collider(parent: Node3D, node_name: String, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)


func _action_zh(action_name: String) -> String:
	match action_name:
		"walk":
			return "走路"
		"shoot":
			return "開槍"
		"interact":
			return "摸東摸西"
		"roll":
			return "翻滾"
		_:
			return "待機"
