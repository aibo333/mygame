class_name AnimSandboxWorld
extends Node3D

const START_MENU_PATH: String = "res://scenes/StartMenu.tscn"
const FPS_REF: float = 30.0

enum SandboxMode {
	SINGLE_CLIP,
	COMBO_WALK_ROLL_WALK,
	LIVE_CONTROL,
}

var mode: SandboxMode = SandboxMode.SINGLE_CLIP
var player: SquadCharacter = null
var vfx_root: Node3D = null
var camera_pivot: Node3D = null
var camera: Camera3D = null

# Orbit camera state
var _cam_yaw: float = 0.45
var _cam_pitch: float = -0.32
var _cam_dist: float = 4.2
var _orbit_dragging: bool = false

# Animation playback & breakpoint state
var selected_clip: String = "roll"
var is_playing: bool = true
var is_looping: bool = true
var playback_speed: float = 1.0
var clip_length: float = 1.0
var playhead_sec: float = 0.0
var start_cut_sec: float = 0.0
var end_cut_sec: float = 1.0
var blend_in_sec: float = 0.04
var blend_out_sec: float = 0.14
var combo_walk_sec: float = 0.85

# Combo state machine: 0 = WALK_PRE, 1 = ACTION_CLIP, 2 = WALK_POST
var _combo_stage: int = 0
var _combo_timer: float = 0.0

# UI references
var _hud_layer: CanvasLayer = null
var _debug_label: Label = null
var _status_label: Label = null
var _mode_buttons: Dictionary = {}
var _weapon_buttons: Array[Button] = []
var _avatar_option: OptionButton = null
var _avatar_ids: Array[String] = []
var _clip_option: OptionButton = null
var _play_btn: Button = null
var _loop_btn: Button = null
var _speed_slider: HSlider = null
var _speed_val_label: Label = null
var _timeline_slider: HSlider = null
var _timeline_label: Label = null
var _start_cut_slider: HSlider = null
var _start_cut_label: Label = null
var _end_cut_slider: HSlider = null
var _end_cut_label: Label = null
var _blend_in_slider: HSlider = null
var _blend_in_label: Label = null
var _blend_out_slider: HSlider = null
var _blend_out_label: Label = null
var _range_highlight: ColorRect = null
var _range_track: Control = null
var _suppress_ui_callbacks: bool = false


func _ready() -> void:
	Engine.time_scale = 1.0
	_build_studio_environment()
	_spawn_player()
	_build_orbit_camera()
	_build_ui()
	select_clip("roll")
	set_mode(SandboxMode.SINGLE_CLIP)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _build_studio_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.11, 0.15, 0.22)
	sky_mat.sky_horizon_color = Color(0.20, 0.24, 0.30)
	sky_mat.ground_bottom_color = Color(0.08, 0.09, 0.12)
	sky_mat.ground_horizon_color = Color(0.14, 0.16, 0.20)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-24.0, -140.0, 0.0)
	fill_light.light_energy = 0.55
	fill_light.light_color = Color(0.78, 0.88, 1.0)
	add_child(fill_light)

	# Studio floor + collision
	var floor_body := StaticBody3D.new()
	floor_body.name = "StudioFloor"
	floor_body.collision_layer = 1
	add_child(floor_body)

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(60.0, 1.0, 60.0)
	col.shape = box_shape
	col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(col)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mesh.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.16, 0.18, 0.22)
	fmat.roughness = 0.85
	floor_mesh.material_override = fmat
	floor_body.add_child(floor_mesh)

	# Subtle studio reference grid lines
	var grid_mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-12, 13):
		var c := Color(0.28, 0.62, 0.78, 0.45) if i == 0 else Color(0.26, 0.30, 0.36, 0.35)
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(float(i), 0.008, -12.0))
		im.surface_add_vertex(Vector3(float(i), 0.008, 12.0))
		im.surface_add_vertex(Vector3(-12.0, 0.008, float(i)))
		im.surface_add_vertex(Vector3(12.0, 0.008, float(i)))
	im.surface_end()
	grid_mi.mesh = im
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.vertex_color_use_as_albedo = true
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_mi.material_override = gmat
	add_child(grid_mi)

	vfx_root = Node3D.new()
	vfx_root.name = "VfxRoot"
	add_child(vfx_root)


func _spawn_player() -> void:
	SquadConfig.set_playable_bounds(Rect2(-24.0, -24.0, 48.0, 48.0))
	player = SquadCharacter.new()
	player.name = "SandboxCharacter"
	add_child(player)
	player.setup(SquadConfig.get_character("reina_ar"), vfx_root)
	player.global_position = Vector3.ZERO
	player.god_mode = true
	player.infinite_ammo = false
	if player.selection_ring != null:
		player.selection_ring.visible = false


func _build_orbit_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "OrbitPivot"
	camera_pivot.position = Vector3(0.0, 1.15, 0.0)
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.name = "StudioCamera"
	camera.fov = 46.0
	camera_pivot.add_child(camera)
	_update_camera_transform()


func _update_camera_transform() -> void:
	if camera_pivot == null or camera == null:
		return
	var focus_pos: Vector3 = (player.global_position if player != null else Vector3.ZERO) + Vector3(0.0, 1.05, 0.0)
	camera_pivot.position = focus_pos
	camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, _cam_dist)
	camera.look_at(focus_pos, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbit_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_cam_dist = clampf(_cam_dist - 0.35, 1.8, 10.0)
			_update_camera_transform()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_cam_dist = clampf(_cam_dist + 0.35, 1.8, 10.0)
			_update_camera_transform()
	elif event is InputEventMouseMotion and _orbit_dragging:
		var mm := event as InputEventMouseMotion
		_cam_yaw -= mm.relative.x * 0.008
		_cam_pitch = clampf(_cam_pitch - mm.relative.y * 0.008, -1.25, 0.15)
		_update_camera_transform()
	elif event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_1:
			_switch_weapon(0)
		elif ke.keycode == KEY_2:
			_switch_weapon(1)
		elif ke.keycode == KEY_3:
			_switch_weapon(2)
		elif ke.keycode == KEY_ESCAPE:
			return_to_start_menu()
		elif mode == SandboxMode.LIVE_CONTROL:
			if ke.keycode == KEY_R and player != null:
				player.start_reload()
			elif ke.keycode == KEY_V and player != null:
				player.toggle_silencer()
		else:
			if ke.keycode == KEY_SPACE:
				toggle_play_pause()
			elif ke.keycode == KEY_BRACKETLEFT:
				set_start_cut_to_current()
			elif ke.keycode == KEY_BRACKETRIGHT:
				set_end_cut_to_current()
			elif ke.keycode == KEY_LEFT:
				step_frames(-1)
			elif ke.keycode == KEY_RIGHT:
				step_frames(1)


func _process(delta: float) -> void:
	if player == null:
		return

	if mode == SandboxMode.LIVE_CONTROL:
		Engine.time_scale = playback_speed
		_tick_live_control(delta)
	else:
		Engine.time_scale = 1.0
		player.global_position = Vector3.ZERO
		player.velocity = Vector3.ZERO
		if mode == SandboxMode.SINGLE_CLIP:
			_tick_single_clip(delta)
		elif mode == SandboxMode.COMBO_WALK_ROLL_WALK:
			_tick_combo_loop(delta)

	_update_camera_transform()
	_refresh_debug_panel()
	_refresh_timeline_ui()


func _tick_single_clip(delta: float) -> void:
	var ap := player.anim_player
	if ap == null or not ap.has_animation(selected_clip):
		return
	var safe_end: float = maxf(start_cut_sec + 0.01, end_cut_sec)
	if is_playing:
		playhead_sec += delta * playback_speed
		if playhead_sec >= safe_end:
			if is_looping:
				playhead_sec = start_cut_sec + fmod(playhead_sec - start_cut_sec, safe_end - start_cut_sec)
			else:
				playhead_sec = safe_end
				is_playing = false
				_sync_play_button()

	playhead_sec = clampf(playhead_sec, 0.0, clip_length)
	if ap.current_animation != selected_clip:
		ap.play(selected_clip, 0.0)
	ap.speed_scale = 0.0
	ap.seek(playhead_sec, true)


func _tick_combo_loop(delta: float) -> void:
	var ap := player.anim_player
	if ap == null:
		return
	if not is_playing:
		ap.speed_scale = 0.0
		return

	var dt: float = delta * playback_speed
	_combo_timer += dt

	if _combo_stage == 0:
		# Stage 0: Walk approach
		if ap.current_animation != "walk" or not ap.is_playing():
			ap.speed_scale = playback_speed * 1.12
			ap.play("walk", blend_out_sec)
		else:
			ap.speed_scale = playback_speed * 1.12
		if _combo_timer >= combo_walk_sec:
			_combo_stage = 1
			_combo_timer = 0.0
			playhead_sec = start_cut_sec
			ap.speed_scale = playback_speed
			ap.play(selected_clip, blend_in_sec)
			ap.seek(start_cut_sec, true)
	elif _combo_stage == 1:
		# Stage 1: Selected clip truncated strictly to [start_cut_sec .. end_cut_sec]
		var safe_end: float = maxf(start_cut_sec + 0.02, end_cut_sec)
		playhead_sec = start_cut_sec + _combo_timer
		ap.speed_scale = playback_speed
		if playhead_sec >= safe_end:
			_combo_stage = 2
			_combo_timer = 0.0
			ap.speed_scale = playback_speed * 1.12
			ap.play("walk", blend_out_sec)
	else:
		# Stage 2: Walk recovery
		ap.speed_scale = playback_speed * 1.12
		if _combo_timer >= combo_walk_sec:
			if is_looping:
				_combo_stage = 0
				_combo_timer = 0.0
			else:
				is_playing = false
				ap.speed_scale = 0.0
				_sync_play_button()


func _tick_live_control(delta: float) -> void:
	var move_in := Vector3.ZERO
	var fwd := Vector3(-sin(_cam_yaw), 0.0, -cos(_cam_yaw))
	var right := Vector3(cos(_cam_yaw), 0.0, -sin(_cam_yaw))
	if Input.is_physical_key_pressed(KEY_W):
		move_in += fwd
	if Input.is_physical_key_pressed(KEY_S):
		move_in -= fwd
	if Input.is_physical_key_pressed(KEY_D):
		move_in += right
	if Input.is_physical_key_pressed(KEY_A):
		move_in -= right
	if move_in.length_squared() > 0.001:
		move_in = move_in.normalized()

	var aim_pos: Vector3 = player.global_position + fwd * 10.0
	if camera != null:
		var mpos := get_viewport().get_mouse_position()
		var ray_orig := camera.project_ray_origin(mpos)
		var ray_dir := camera.project_ray_normal(mpos)
		if absf(ray_dir.y) > 0.001:
			var t := -ray_orig.y / ray_dir.y
			if t > 0.0:
				aim_pos = ray_orig + ray_dir * t

	var want_shoot: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _is_mouse_over_ui()
	var want_roll: bool = Input.is_action_just_pressed("dodge") or Input.is_physical_key_pressed(KEY_SPACE)
	player.set_camera_yaw(_cam_yaw)
	player.update_character(delta, move_in, aim_pos, want_shoot, false, want_roll, "")


func _is_mouse_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null


func set_mode(new_mode: SandboxMode) -> void:
	mode = new_mode
	Engine.time_scale = playback_speed if mode == SandboxMode.LIVE_CONTROL else 1.0
	if player != null:
		player.global_position = Vector3.ZERO
		player.reset_combat_state()
	if mode == SandboxMode.COMBO_WALK_ROLL_WALK:
		_combo_stage = 0
		_combo_timer = 0.0
		is_playing = true
	elif mode == SandboxMode.SINGLE_CLIP:
		playhead_sec = clampf(playhead_sec, start_cut_sec, end_cut_sec)
	_sync_mode_buttons()
	_sync_play_button()


func select_clip(clip_name: String) -> void:
	if player == null or player.anim_player == null or not player.anim_player.has_animation(clip_name):
		return
	selected_clip = clip_name
	var anim: Animation = player.anim_player.get_animation(clip_name)
	clip_length = maxf(0.05, anim.length)
	start_cut_sec = 0.0
	end_cut_sec = clip_length
	playhead_sec = 0.0
	_combo_stage = 0
	_combo_timer = 0.0
	_sync_clip_sliders()
	if mode == SandboxMode.SINGLE_CLIP:
		player.anim_player.play(selected_clip, 0.0)
		player.anim_player.speed_scale = 0.0
		player.anim_player.seek(0.0, true)


func set_playback_speed(spd: float) -> void:
	playback_speed = clampf(spd, 0.05, 3.0)
	_suppress_ui_callbacks = true
	if _speed_slider != null:
		_speed_slider.value = playback_speed
	if _speed_val_label != null:
		_speed_val_label.text = "%.2fx" % playback_speed
	_suppress_ui_callbacks = false


func set_breakpoints(start_s: float, end_s: float) -> void:
	start_cut_sec = clampf(start_s, 0.0, maxf(0.0, clip_length - 0.02))
	end_cut_sec = clampf(end_s, start_cut_sec + 0.02, clip_length)
	playhead_sec = clampf(playhead_sec, start_cut_sec, end_cut_sec)
	_sync_clip_sliders()


func set_start_cut_to_current() -> void:
	set_breakpoints(playhead_sec, maxf(end_cut_sec, playhead_sec + 0.05))
	_set_status("已設起點斷點：%.3fs (F%d)" % [start_cut_sec, int(round(start_cut_sec * FPS_REF))])


func set_end_cut_to_current() -> void:
	set_breakpoints(minf(start_cut_sec, maxf(0.0, playhead_sec - 0.05)), playhead_sec)
	_set_status("已設終點斷點：%.3fs (F%d)" % [end_cut_sec, int(round(end_cut_sec * FPS_REF))])


func reset_breakpoints() -> void:
	set_breakpoints(0.0, clip_length)
	_set_status("已重設斷點為完整動作 (0.00s ~ %.2fs)" % clip_length)


func toggle_play_pause() -> void:
	is_playing = not is_playing
	_sync_play_button()


func step_frames(delta_frames: int) -> void:
	is_playing = false
	_sync_play_button()
	playhead_sec = clampf(playhead_sec + float(delta_frames) / FPS_REF, 0.0, clip_length)
	if player != null and player.anim_player != null and player.anim_player.has_animation(selected_clip):
		player.anim_player.play(selected_clip, 0.0)
		player.anim_player.speed_scale = 0.0
		player.anim_player.seek(playhead_sec, true)


func _switch_weapon(slot_idx: int) -> void:
	if player == null:
		return
	player.switch_weapon_slot(slot_idx)
	_sync_weapon_buttons()


func switch_avatar(avatar_id: String) -> bool:
	if player == null:
		return false
	var prev_playhead: float = playhead_sec
	var prev_start: float = start_cut_sec
	var prev_end: float = end_cut_sec
	var ok: bool = player.switch_avatar_model(avatar_id)
	if not ok:
		return false
	_sync_avatar_option()
	_sync_weapon_buttons()
	if mode == SandboxMode.SINGLE_CLIP:
		if player.anim_player != null and player.anim_player.has_animation(selected_clip):
			playhead_sec = clampf(prev_playhead, 0.0, clip_length)
			start_cut_sec = clampf(prev_start, 0.0, clip_length)
			end_cut_sec = clampf(prev_end, start_cut_sec + 0.02, clip_length)
			player.anim_player.play(selected_clip, 0.0)
			player.anim_player.speed_scale = 0.0
			player.anim_player.seek(playhead_sec, true)
	elif mode == SandboxMode.COMBO_WALK_ROLL_WALK:
		_combo_stage = 0
		_combo_timer = 0.0
	var acfg: Dictionary = SquadConfig.get_avatar_config(avatar_id)
	_set_status("已切換角色模型：%s" % str(acfg.get("label", avatar_id)))
	return true


func _sync_avatar_option() -> void:
	if _avatar_option == null or player == null:
		return
	var cur_id: String = player.get_active_avatar_id()
	var idx: int = _avatar_ids.find(cur_id)
	if idx >= 0:
		_suppress_ui_callbacks = true
		_avatar_option.select(idx)
		_suppress_ui_callbacks = false


func copy_tuning_summary() -> String:
	var cut_len: float = maxf(0.01, end_cut_sec - start_cut_sec)
	var summary := (
		"Clip=%s | Speed=%.2fx | Start=%.3fs (F%d, %.1f%%) | End=%.3fs (F%d, %.1f%%) | CutLen=%.3fs | BlendIn=%.2fs | BlendOut=%.2fs"
		% [
			selected_clip,
			playback_speed,
			start_cut_sec, int(round(start_cut_sec * FPS_REF)), (start_cut_sec / clip_length) * 100.0,
			end_cut_sec, int(round(end_cut_sec * FPS_REF)), (end_cut_sec / clip_length) * 100.0,
			cut_len,
			blend_in_sec,
			blend_out_sec,
		]
	)
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(summary)
	_set_status("已複製參數到剪貼簿：" + summary)
	return summary


func return_to_start_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(START_MENU_PATH)


func _set_status(msg: String) -> void:
	if _status_label != null:
		_status_label.text = msg


func _build_ui() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "SandboxUi"
	add_child(_hud_layer)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.theme = TacticalTheme.build_theme(14)
	_hud_layer.add_child(root_ctrl)

	_build_debug_panel(root_ctrl)
	_build_timeline_bar(root_ctrl)


func _make_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	return TacticalTheme.make_accent_card_style(bg, border, 3, 12, 10)


func _build_debug_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "DebugPanel"
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(360.0, 560.0)
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(TacticalTheme.BG_PANEL, TacticalTheme.ACCENT_CYAN)
	)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	# Header + Return button
	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var title := Label.new()
	title.text = "SANDBOX // ANIMATION DEBUGGER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	hdr.add_child(title)

	var back_btn := Button.new()
	back_btn.text = "◀ MENU"
	back_btn.pressed.connect(return_to_start_menu)
	hdr.add_child(back_btn)

	# Mode buttons
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	vb.add_child(mode_row)
	for entry in [
		{"m": SandboxMode.SINGLE_CLIP, "t": "單段精調"},
		{"m": SandboxMode.COMBO_WALK_ROLL_WALK, "t": "走→滾→走"},
		{"m": SandboxMode.LIVE_CONTROL, "t": "自由實測"},
	]:
		var btn := Button.new()
		btn.text = str(entry["t"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m_val: SandboxMode = entry["m"]
		btn.pressed.connect(func() -> void: set_mode(m_val))
		mode_row.add_child(btn)
		_mode_buttons[m_val] = btn

	# Character model selector
	var avatar_row := HBoxContainer.new()
	vb.add_child(avatar_row)
	var avatar_lbl := Label.new()
	avatar_lbl.text = "角色模型："
	avatar_row.add_child(avatar_lbl)
	_avatar_option = OptionButton.new()
	_avatar_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avatar_ids.clear()
	var catalog: Array[Dictionary] = SquadConfig.get_avatar_catalog()
	var active_aid: String = player.get_active_avatar_id() if player != null else SquadConfig.DEFAULT_AVATAR_ID
	for i in range(catalog.size()):
		var acfg: Dictionary = catalog[i]
		var aid: String = str(acfg.get("id", ""))
		_avatar_ids.append(aid)
		_avatar_option.add_item(str(acfg.get("label", aid)), i)
		if aid == active_aid:
			_avatar_option.select(i)
	_avatar_option.item_selected.connect(func(idx: int) -> void:
		if not _suppress_ui_callbacks and idx >= 0 and idx < _avatar_ids.size():
			switch_avatar(_avatar_ids[idx])
	)
	avatar_row.add_child(_avatar_option)

	# Clip selector
	var clip_row := HBoxContainer.new()
	vb.add_child(clip_row)
	var clip_lbl := Label.new()
	clip_lbl.text = "動作片段："
	clip_row.add_child(clip_lbl)
	_clip_option = OptionButton.new()
	_clip_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clips: PackedStringArray = player.get_available_animations() if player != null else PackedStringArray()
	for i in range(clips.size()):
		_clip_option.add_item(clips[i], i)
		if clips[i] == "roll":
			_clip_option.select(i)
	_clip_option.item_selected.connect(func(idx: int) -> void:
		select_clip(_clip_option.get_item_text(idx))
	)
	clip_row.add_child(_clip_option)

	# Weapon selector
	var wep_row := HBoxContainer.new()
	wep_row.add_theme_constant_override("separation", 6)
	vb.add_child(wep_row)
	for wi in range(3):
		var wb := Button.new()
		wb.text = ["[1] M4A1-S", "[2] AK-47", "[3] DE"][wi]
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot := wi
		wb.pressed.connect(func() -> void: _switch_weapon(slot))
		wep_row.add_child(wb)
		_weapon_buttons.append(wb)
	_sync_weapon_buttons()

	vb.add_child(HSeparator.new())

	# Blend sliders for Walk->Roll->Walk transitions
	var bi_row := HBoxContainer.new()
	vb.add_child(bi_row)
	var bi_t := Label.new()
	bi_t.text = "進動作融合 (Blend In)"
	bi_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bi_row.add_child(bi_t)
	_blend_in_label = Label.new()
	_blend_in_label.text = "%.2fs" % blend_in_sec
	bi_row.add_child(_blend_in_label)

	_blend_in_slider = HSlider.new()
	_blend_in_slider.min_value = 0.0
	_blend_in_slider.max_value = 0.35
	_blend_in_slider.step = 0.01
	_blend_in_slider.value = blend_in_sec
	_blend_in_slider.value_changed.connect(func(v: float) -> void:
		blend_in_sec = v
		_blend_in_label.text = "%.2fs" % v
	)
	vb.add_child(_blend_in_slider)

	var bo_row := HBoxContainer.new()
	vb.add_child(bo_row)
	var bo_t := Label.new()
	bo_t.text = "接回走路融合 (Blend Out)"
	bo_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bo_row.add_child(bo_t)
	_blend_out_label = Label.new()
	_blend_out_label.text = "%.2fs" % blend_out_sec
	bo_row.add_child(_blend_out_label)

	_blend_out_slider = HSlider.new()
	_blend_out_slider.min_value = 0.0
	_blend_out_slider.max_value = 0.35
	_blend_out_slider.step = 0.01
	_blend_out_slider.value = blend_out_sec
	_blend_out_slider.value_changed.connect(func(v: float) -> void:
		blend_out_sec = v
		_blend_out_label.text = "%.2fs" % v
	)
	vb.add_child(_blend_out_slider)

	vb.add_child(HSeparator.new())

	# Live telemetry readout
	_debug_label = Label.new()
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.add_theme_color_override("font_color", Color(0.86, 0.93, 0.98))
	vb.add_child(_debug_label)

	# Copy parameters button
	var copy_btn := Button.new()
	copy_btn.text = "COPY // 複製目前斷點與倍速參數"
	copy_btn.pressed.connect(copy_tuning_summary)
	vb.add_child(copy_btn)

	_status_label = Label.new()
	_status_label.text = "RMB ORBIT  |  WHEEL ZOOM  |  [ / ] SET BREAKPOINTS"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	vb.add_child(_status_label)


func _build_timeline_bar(parent: Control) -> void:
	var bar := PanelContainer.new()
	bar.name = "TimelineBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 16.0
	bar.offset_right = -16.0
	bar.offset_top = -182.0
	bar.offset_bottom = -14.0
	bar.add_theme_stylebox_override(
		"panel",
		_make_panel_style(TacticalTheme.BG_PANEL, TacticalTheme.ACCENT_CYAN)
	)
	parent.add_child(bar)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	bar.add_child(vb)

	# Row 1: Transport + Speed Multiplier presets + fine speed slider
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vb.add_child(row1)

	_play_btn = Button.new()
	_play_btn.text = "PAUSE"
	_play_btn.custom_minimum_size = Vector2(84.0, 30.0)
	_play_btn.pressed.connect(toggle_play_pause)
	row1.add_child(_play_btn)

	var prev_btn := Button.new()
	prev_btn.text = "◀ -1F"
	prev_btn.pressed.connect(func() -> void: step_frames(-1))
	row1.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "+1F ▶"
	next_btn.pressed.connect(func() -> void: step_frames(1))
	row1.add_child(next_btn)

	_loop_btn = Button.new()
	_loop_btn.text = "LOOP: ON"
	_loop_btn.pressed.connect(func() -> void:
		is_looping = not is_looping
		_loop_btn.text = "LOOP: ON" if is_looping else "LOOP: OFF"
	)
	row1.add_child(_loop_btn)

	var sp_lbl := Label.new()
	sp_lbl.text = "  倍速："
	row1.add_child(sp_lbl)

	for spd in [0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0]:
		var sbtn := Button.new()
		sbtn.text = str(spd) + "x"
		var sv: float = spd
		sbtn.pressed.connect(func() -> void: set_playback_speed(sv))
		row1.add_child(sbtn)

	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.05
	_speed_slider.max_value = 3.0
	_speed_slider.step = 0.05
	_speed_slider.value = playback_speed
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_slider.value_changed.connect(func(v: float) -> void:
		if not _suppress_ui_callbacks:
			set_playback_speed(v)
	)
	row1.add_child(_speed_slider)

	_speed_val_label = Label.new()
	_speed_val_label.text = "1.00x"
	_speed_val_label.custom_minimum_size = Vector2(52.0, 0.0)
	row1.add_child(_speed_val_label)

	# Row 2: Active Cut Range Visual Track + Main Timeline Scrubber
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	vb.add_child(row2)

	var scrub_wrap := VBoxContainer.new()
	scrub_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrub_wrap.add_theme_constant_override("separation", 2)
	row2.add_child(scrub_wrap)

	_range_track = Control.new()
	_range_track.custom_minimum_size = Vector2(0.0, 8.0)
	scrub_wrap.add_child(_range_track)

	var track_bg := ColorRect.new()
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	track_bg.color = Color(0.18, 0.22, 0.28, 1.0)
	_range_track.add_child(track_bg)

	_range_highlight = ColorRect.new()
	_range_highlight.color = Color(0.28, 0.86, 0.98, 0.85)
	_range_track.add_child(_range_highlight)

	_timeline_slider = HSlider.new()
	_timeline_slider.min_value = 0.0
	_timeline_slider.max_value = 1.0
	_timeline_slider.step = 0.005
	_timeline_slider.value_changed.connect(func(v: float) -> void:
		if _suppress_ui_callbacks:
			return
		is_playing = false
		_sync_play_button()
		playhead_sec = clampf(v, 0.0, clip_length)
		if player != null and player.anim_player != null and player.anim_player.has_animation(selected_clip):
			player.anim_player.play(selected_clip, 0.0)
			player.anim_player.speed_scale = 0.0
			player.anim_player.seek(playhead_sec, true)
	)
	scrub_wrap.add_child(_timeline_slider)

	_timeline_label = Label.new()
	_timeline_label.text = "0.000s / 1.000s (F0)"
	_timeline_label.custom_minimum_size = Vector2(185.0, 0.0)
	row2.add_child(_timeline_label)

	# Row 3: Breakpoint Selection Controls (Start Cut & End Cut)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	vb.add_child(row3)

	var set_s_btn := Button.new()
	set_s_btn.text = "[ 設為起點"
	set_s_btn.pressed.connect(set_start_cut_to_current)
	row3.add_child(set_s_btn)

	_start_cut_label = Label.new()
	_start_cut_label.text = "起點: 0.00s"
	_start_cut_label.custom_minimum_size = Vector2(96.0, 0.0)
	row3.add_child(_start_cut_label)

	_start_cut_slider = HSlider.new()
	_start_cut_slider.min_value = 0.0
	_start_cut_slider.max_value = 1.0
	_start_cut_slider.step = 0.005
	_start_cut_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_cut_slider.value_changed.connect(func(v: float) -> void:
		if not _suppress_ui_callbacks:
			set_breakpoints(v, end_cut_sec)
	)
	row3.add_child(_start_cut_slider)

	var set_e_btn := Button.new()
	set_e_btn.text = "] 設為終點"
	set_e_btn.pressed.connect(set_end_cut_to_current)
	row3.add_child(set_e_btn)

	_end_cut_label = Label.new()
	_end_cut_label.text = "終點: 1.00s"
	_end_cut_label.custom_minimum_size = Vector2(96.0, 0.0)
	row3.add_child(_end_cut_label)

	_end_cut_slider = HSlider.new()
	_end_cut_slider.min_value = 0.0
	_end_cut_slider.max_value = 1.0
	_end_cut_slider.step = 0.005
	_end_cut_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_cut_slider.value_changed.connect(func(v: float) -> void:
		if not _suppress_ui_callbacks:
			set_breakpoints(start_cut_sec, v)
	)
	row3.add_child(_end_cut_slider)

	var reset_btn := Button.new()
	reset_btn.text = "↺ 重設斷點"
	reset_btn.pressed.connect(reset_breakpoints)
	row3.add_child(reset_btn)


func _sync_clip_sliders() -> void:
	_suppress_ui_callbacks = true
	if _timeline_slider != null:
		_timeline_slider.max_value = clip_length
		_timeline_slider.value = playhead_sec
	if _start_cut_slider != null:
		_start_cut_slider.max_value = clip_length
		_start_cut_slider.value = start_cut_sec
	if _end_cut_slider != null:
		_end_cut_slider.max_value = clip_length
		_end_cut_slider.value = end_cut_sec
	if _start_cut_label != null:
		_start_cut_label.text = "起點: %.2fs" % start_cut_sec
	if _end_cut_label != null:
		_end_cut_label.text = "終點: %.2fs" % end_cut_sec
	_suppress_ui_callbacks = false


func _sync_play_button() -> void:
	if _play_btn != null:
		_play_btn.text = "PAUSE" if is_playing else "PLAY"


func _sync_mode_buttons() -> void:
	for m_key in _mode_buttons.keys():
		var b: Button = _mode_buttons[m_key]
		TacticalTheme.style_state_button(b, m_key == mode, TacticalTheme.ACCENT_CYAN)


func _sync_weapon_buttons() -> void:
	var active_slot: int = player.get_active_weapon_slot() if player != null else 0
	for i in range(_weapon_buttons.size()):
		TacticalTheme.style_state_button(_weapon_buttons[i], i == active_slot, TacticalTheme.ACCENT_AMBER)


func _refresh_timeline_ui() -> void:
	_suppress_ui_callbacks = true
	if _timeline_slider != null:
		_timeline_slider.value = playhead_sec
	if _timeline_label != null:
		var frame_idx: int = int(round(playhead_sec * FPS_REF))
		var total_frames: int = int(round(clip_length * FPS_REF))
		_timeline_label.text = "%.3fs / %.3fs (F%d/%d)" % [playhead_sec, clip_length, frame_idx, total_frames]
	if _range_track != null and _range_highlight != null and clip_length > 0.001:
		var w: float = _range_track.size.x
		var sx: float = (start_cut_sec / clip_length) * w
		var ex: float = (end_cut_sec / clip_length) * w
		_range_highlight.position = Vector2(sx, 0.0)
		_range_highlight.size = Vector2(maxf(2.0, ex - sx), _range_track.size.y)
	_suppress_ui_callbacks = false


func _refresh_debug_panel() -> void:
	if _debug_label == null or player == null:
		return
	var mode_str := "單段精調"
	if mode == SandboxMode.COMBO_WALK_ROLL_WALK:
		var stage_names: PackedStringArray = PackedStringArray(["WALK_PRE", selected_clip.to_upper(), "WALK_POST"])
		var st_name: String = stage_names[clampi(_combo_stage, 0, 2)]
		mode_str = "走→滾→走 (%s)" % st_name
	elif mode == SandboxMode.LIVE_CONTROL:
		mode_str = "自由實測 (WASD/Space/LMB/R/V)"

	var ap := player.anim_player
	var cur_anim: String = ap.current_animation if ap != null else "none"
	var cut_dur: float = maxf(0.0, end_cut_sec - start_cut_sec)
	var pct: float = (playhead_sec / clip_length) * 100.0 if clip_length > 0.0 else 0.0

	var acfg_dbg: Dictionary = SquadConfig.get_avatar_config(player.get_active_avatar_id())
	var avatar_name_dbg: String = str(acfg_dbg.get("label", player.get_active_avatar_id()))

	_debug_label.text = (
		"模式：%s\n"
		+ "角色：%s\n"
		+ "武器：%s  (彈匣 %d/%d)\n"
		+ "播放片段：%s  |  狀態：%s\n"
		+ "時間軸：%.3fs / %.3fs (%.1f%%)\n"
		+ "斷點區間：%.3fs ~ %.3fs（有效 %.3fs）\n"
		+ "倍速：%.2fx  |  Blend: %.2fs / %.2fs\n"
		+ "速度：%.2f m/s  |  無敵幀：%s"
	) % [
		mode_str,
		avatar_name_dbg,
		player.weapon_label, player.ammo_in_mag, player.mag_size,
		cur_anim, player.current_action,
		playhead_sec, clip_length, pct,
		start_cut_sec, end_cut_sec, cut_dur,
		playback_speed, blend_in_sec, blend_out_sec,
		player.velocity.length(),
		"ON" if player.is_invulnerable() else "OFF",
	]
