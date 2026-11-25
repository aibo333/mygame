class_name RuinsBaseWorld
extends Node3D

# Complete Phase 1-5 Integrated World:
# Procedural Urban Sector × Armored Train Customization × Horde Combat × Missions & Extraction × Meta Save/Hub
const TILE: float = 3.2
const KIT: String = "res://assets/packs/kenney_retro_urban/"

var env_root: Node3D = null
var squad_root: Node3D = null
var vfx_root: Node3D = null
var camera_rig: LolCameraController = null
var hud: SquadHud = null

var sector_generator: SectorGenerator = null
var armored_train: ArmoredTrainBase = null
var loot_stash_manager: LootStashManager = null
var train_consist: TrainConsistManager = null
var train_blueprint_ui: TrainBlueprintUi = null
var horde_manager: HordeManager = null
var mission_director: MissionDirector = null
var meta_progression: MetaProgressionManager = null
var run_flow_overlay: RunFlowOverlay = null
var stratagem_ui: StratagemInputUi = null

var current_seed: int = SquadConfig.DEFAULT_SECTOR_SEED
var current_tier: int = 1
var run_active: bool = true
var auto_save_enabled: bool = true

var squad: Array[SquadCharacter] = []
var active_index: int = 0
var sync_all_preview: bool = false

var _aim_cursor: MeshInstance3D = null
var _active_interact_target: Dictionary = {}
var _time_elapsed: float = 0.0
var _hud_compass_timer: float = 0.0


func _ready() -> void:
	# Avoid mutating real user save files during headless automated verification
	auto_save_enabled = not DisplayServer.get_name().to_lower().contains("headless")
	_setup_retro_urban_environment()
	_setup_all_systems()
	_setup_squad_and_camera()
	_setup_hud_and_overlays()
	if auto_save_enabled:
		meta_progression.load_from_file(train_consist)
		current_tier = meta_progression.selected_tier
	_apply_train_consist_to_world()
	generate_new_sector(current_seed, true)


func _setup_retro_urban_environment() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "RetroUrbanEnvironment"
	var env: Environment = Environment.new()

	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.24, 0.34)
	sky_mat.sky_horizon_color = Color(0.66, 0.54, 0.48)
	sky_mat.ground_bottom_color = Color(0.14, 0.14, 0.17)
	sky_mat.ground_horizon_color = Color(0.36, 0.32, 0.32)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.23, 0.28)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.62, 0.74)
	env.ambient_light_energy = 0.85

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.36
	env.glow_bloom = 0.12

	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.40, 0.46)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.2

	we.environment = env
	add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "UrbanSunLight"
	sun.light_color = Color(1.0, 0.87, 0.72)
	sun.light_energy = 1.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.03
	sun.rotation_degrees = Vector3(-44.0, -32.0, 0.0)
	add_child(sun)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "SkyFillLight"
	fill.light_color = Color(0.58, 0.70, 0.92)
	fill.light_energy = 0.55
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	add_child(fill)


func _setup_all_systems() -> void:
	env_root = Node3D.new()
	env_root.name = "KenneyRetroUrbanDistrict"
	add_child(env_root)

	vfx_root = Node3D.new()
	vfx_root.name = "VfxRoot"
	add_child(vfx_root)

	meta_progression = MetaProgressionManager.new()

	sector_generator = SectorGenerator.new()
	sector_generator.name = "SectorGenerator"
	env_root.add_child(sector_generator)

	armored_train = ArmoredTrainBase.new()
	armored_train.name = "ArmoredTrainBase"
	armored_train.position = SquadConfig.TRAIN_POSITION
	env_root.add_child(armored_train)
	armored_train.hull_hp_changed.connect(_on_train_hull_changed)
	armored_train.train_destroyed.connect(_on_train_destroyed)

	train_consist = TrainConsistManager.new()
	train_consist.consist_changed.connect(_on_train_consist_changed)

	loot_stash_manager = LootStashManager.new()
	loot_stash_manager.name = "LootStashManager"
	env_root.add_child(loot_stash_manager)
	loot_stash_manager.backpack_changed.connect(_on_inventory_changed)
	loot_stash_manager.stash_changed.connect(_on_stash_changed)

	horde_manager = HordeManager.new()
	horde_manager.name = "HordeManager"
	env_root.add_child(horde_manager)
	horde_manager.setup(vfx_root)
	horde_manager.connect_attack_handlers(_on_zombie_attacked_player, _on_zombie_attacked_train)
	horde_manager.wave_stage_changed.connect(_on_wave_stage_changed)
	horde_manager.zombie_killed.connect(_on_zombie_killed)
	horde_manager.overtime_triggered.connect(_on_overtime_triggered)

	mission_director = MissionDirector.new()
	mission_director.name = "MissionDirector"
	env_root.add_child(mission_director)
	mission_director.objective_ambush_triggered.connect(_on_objective_ambush)
	mission_director.extraction_succeeded.connect(_on_extraction_succeeded)

	_build_aim_cursor()


func _build_aim_cursor() -> void:
	_aim_cursor = MeshInstance3D.new()
	_aim_cursor.name = "GroundAimCursor"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.31
	torus.rings = 20
	torus.ring_segments = 6
	_aim_cursor.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.90, 0.45, 0.88)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.35)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_cursor.material_override = mat
	_aim_cursor.position = Vector3(0.0, 0.18, 0.0)
	add_child(_aim_cursor)


func _setup_squad_and_camera() -> void:
	squad_root = Node3D.new()
	squad_root.name = "SquadRoot"
	add_child(squad_root)

	for char_id in SquadConfig.get_squad_ids():
		var cfg: Dictionary = SquadConfig.get_character(char_id)
		var girl: SquadCharacter = SquadCharacter.new()
		girl.name = "Girl_" + char_id
		squad_root.add_child(girl)
		girl.setup(cfg, vfx_root)
		var spawn_raw: Variant = cfg.get("spawn_pos", Vector3(0.0, 0.0, -8.8))
		girl.global_position = spawn_raw if spawn_raw is Vector3 else Vector3(0.0, 0.0, -8.8)
		girl.action_changed.connect(_on_character_action_changed)
		girl.interaction_completed.connect(_on_interaction_completed)
		girl.shot_fired.connect(_on_player_shot_fired)
		girl.hp_changed.connect(_on_player_hp_changed)
		girl.ammo_changed.connect(_on_player_ammo_changed)
		girl.player_died.connect(_on_player_died)
		squad.append(girl)

	camera_rig = LolCameraController.new()
	camera_rig.name = "LolCameraController"
	add_child(camera_rig)
	camera_rig.lock_mode_changed.connect(_on_camera_lock_changed)
	camera_rig.projection_mode_changed.connect(_on_camera_projection_changed)

	select_character(0, true)


func _setup_hud_and_overlays() -> void:
	hud = SquadHud.new()
	hud.name = "SquadHud"
	add_child(hud)
	hud.setup(squad)
	hud.character_selected.connect(func(idx: int): select_character(idx, false))
	hud.action_preview_requested.connect(_on_hud_action_preview)
	hud.sync_all_toggled.connect(func(enabled: bool): sync_all_preview = enabled)
	hud.camera_lock_toggled.connect(func(): camera_rig.toggle_camera_lock())
	hud.camera_projection_toggled.connect(func(): camera_rig.toggle_projection_mode())
	hud.camera_recenter_requested.connect(func(): camera_rig.recenter_on_target())
	hud.regenerate_sector_requested.connect(_on_regenerate_sector_requested)
	hud.train_blueprint_requested.connect(_on_toggle_train_blueprint)
	hud.hub_requested.connect(_on_toggle_hub_overlay)
	hud.set_active_character(active_index)
	hud.set_camera_locked(camera_rig.camera_locked)
	hud.set_camera_orthographic(camera_rig.is_orthographic)

	train_blueprint_ui = TrainBlueprintUi.new()
	train_blueprint_ui.name = "TrainBlueprintUi"
	add_child(train_blueprint_ui)
	train_blueprint_ui.setup(train_consist, meta_progression.warehouse)
	train_blueprint_ui.sandbox_resources_requested.connect(_on_sandbox_resources_requested)
	train_blueprint_ui.closed.connect(_on_blueprint_closed)
	train_blueprint_ui.feedback_message.connect(func(msg: String):
		if hud != null:
			hud.push_status(msg)
	)

	run_flow_overlay = RunFlowOverlay.new()
	run_flow_overlay.name = "RunFlowOverlay"
	add_child(run_flow_overlay)
	run_flow_overlay.setup()
	run_flow_overlay.deploy_run_requested.connect(_on_deploy_run_requested)
	run_flow_overlay.open_train_blueprint_requested.connect(func():
		if train_blueprint_ui != null:
			train_blueprint_ui.set_open(true)
	)
	run_flow_overlay.return_to_hub_requested.connect(_on_open_hub_overlay)
	run_flow_overlay.save_profile_requested.connect(_on_manual_save_requested)
	run_flow_overlay.reset_profile_requested.connect(_on_reset_profile_requested)

	stratagem_ui = StratagemInputUi.new()
	stratagem_ui.name = "StratagemInputUi"
	add_child(stratagem_ui)
	stratagem_ui.setup()
	stratagem_ui.step_succeeded.connect(_on_stratagem_step_succeeded)
	stratagem_ui.step_failed.connect(_on_stratagem_step_failed)
	stratagem_ui.sequence_completed.connect(_on_stratagem_completed)
	stratagem_ui.sequence_cancelled.connect(_on_stratagem_cancelled)


func generate_new_sector(seed_value: int, reset_stash: bool = true, tier_num: int = -1) -> Dictionary:
	current_seed = seed_value
	if tier_num > 0:
		current_tier = tier_num
		meta_progression.selected_tier = tier_num

	var tier_cfg: Dictionary = meta_progression.get_tier_config(current_tier)
	var sector_data: Dictionary = sector_generator.generate_sector(seed_value)

	var dock_raw: Variant = sector_data.get("train_dock_pos", SquadConfig.TRAIN_POSITION)
	var dock_pos: Vector3 = dock_raw if dock_raw is Vector3 else SquadConfig.TRAIN_POSITION
	if armored_train != null:
		armored_train.position = dock_pos
		armored_train.reset_hull()

	var bounds_raw: Variant = sector_data.get("world_bounds", SquadConfig.active_playable_bounds)
	var bounds: Rect2 = bounds_raw if bounds_raw is Rect2 else SquadConfig.active_playable_bounds
	SquadConfig.set_playable_bounds(bounds)
	if camera_rig != null:
		camera_rig.set_focus_bounds(Rect2(bounds.position.x - 2.0, dock_pos.z - 3.5, bounds.size.x + 4.0, (bounds.end.y - dock_pos.z) + 5.5))

	if loot_stash_manager != null:
		if reset_stash:
			loot_stash_manager.reset_inventory()
		loot_stash_manager.spawn_loot_points(sector_generator.loot_spawn_points, seed_value)

	var active: SquadCharacter = get_active_character()
	var spawn_raw: Variant = sector_data.get("player_spawn_pos", Vector3(0.0, 0.0, -8.8))
	var spawn_pos: Vector3 = spawn_raw if spawn_raw is Vector3 else Vector3(0.0, 0.0, -8.8)
	if active != null:
		active.global_position = spawn_pos
		active.clear_showcase_override()
		active.reset_combat_state()
		if camera_rig != null:
			camera_rig.set_follow_target(active, true)

	# Start Phase 3 Horde & Phase 4 Mission for this Run
	if horde_manager != null:
		horde_manager.start_run(
			seed_value,
			bounds,
			float(tier_cfg.get("duration_sec", 360.0)),
			float(tier_cfg.get("difficulty_mult", 1.0))
		)

	if mission_director != null:
		var crew_ids: Array[String] = []
		for c: Dictionary in train_consist.crew_roster:
			crew_ids.append(str(c.get("id", "")))
		mission_director.start_mission(seed_value, sector_generator.loot_spawn_points, crew_ids)

	run_active = true
	_active_interact_target = {}
	if stratagem_ui != null:
		stratagem_ui.cancel()
	_sync_hud_state()
	if hud != null:
		hud.set_sector_info(current_seed, "%s ｜ %s" % [str(tier_cfg.get("name", "Tier 1")), sector_generator.get_block_summary_text()])
		hud.push_status("🚂 已進站 %s（Seed #%d）— 完成主線【%s】後返回北方登車區發車撤離！" % [
			str(tier_cfg.get("name", "Tier 1")),
			current_seed,
			mission_director.mission_title if mission_director != null else "",
		])
	return sector_data


func finish_run(victory: bool, fail_reason: String = "") -> Dictionary:
	if not run_active:
		return {}
	run_active = false
	if stratagem_ui != null:
		stratagem_ui.cancel()
	if horde_manager != null:
		horde_manager.is_active = false

	var tier_cfg: Dictionary = meta_progression.get_tier_config(current_tier)
	var reward_mult: float = float(tier_cfg.get("reward_mult", 1.0))
	var secured: Dictionary = {"scrap": 0, "parts": 0, "fuel": 0, "supplies": 0}
	var lost: Dictionary = {"scrap": 0, "parts": 0, "fuel": 0, "supplies": 0}

	var stash_src: Dictionary = loot_stash_manager.train_stash if loot_stash_manager != null else {}
	var bp_src: Dictionary = loot_stash_manager.backpack if loot_stash_manager != null else {}
	var bonus: Dictionary = mission_director.get_mission_reward(reward_mult) if (victory and mission_director != null) else {}

	for k: String in LootStashManager.RESOURCE_ORDER:
		var st_v: int = int(stash_src.get(k, 0))
		var bp_v: int = int(bp_src.get(k, 0))
		if victory:
			secured[k] = st_v + bp_v + int(bonus.get(k, 0))
		else:
			secured[k] = st_v
			lost[k] = bp_v

	var settlement: Dictionary = {
		"victory": victory,
		"fail_reason": fail_reason,
		"kills": horde_manager.total_kills if horde_manager != null else 0,
		"mission_title": mission_director.mission_title if mission_director != null else "",
		"mission_complete": mission_director.is_mission_complete if mission_director != null else false,
		"secured_resources": secured,
		"lost_resources": lost,
		"rescued_crew": mission_director.rescued_survivor.duplicate(true) if (victory and mission_director != null) else {},
	}

	meta_progression.apply_run_settlement(settlement, train_consist)
	if auto_save_enabled:
		meta_progression.save_to_file(train_consist)

	if run_flow_overlay != null:
		run_flow_overlay.show_settlement(settlement)
	return settlement


func _on_deploy_run_requested(tier_num: int, seed_value: int) -> void:
	generate_new_sector(seed_value, true, tier_num)


func _on_regenerate_sector_requested() -> void:
	var next_seed: int = int(Time.get_ticks_usec() % 899999) + 100000
	if next_seed == current_seed:
		next_seed += 17
	generate_new_sector(next_seed, true, current_tier)


func _on_open_hub_overlay() -> void:
	if train_blueprint_ui != null and train_blueprint_ui.is_open():
		train_blueprint_ui.set_open(false)
	if run_flow_overlay != null:
		run_flow_overlay.show_hub(meta_progression, train_consist, current_seed)


func _on_toggle_hub_overlay() -> void:
	if run_flow_overlay == null:
		return
	if run_flow_overlay.is_open():
		run_flow_overlay.close()
	else:
		_on_open_hub_overlay()


func _on_manual_save_requested() -> void:
	var ok: bool = meta_progression.save_to_file(train_consist)
	if hud != null:
		hud.push_status("💾 已儲存進度至 user://mygame_save.json！" if ok else "⚠️ 存檔失敗")


func _on_reset_profile_requested() -> void:
	meta_progression.reset_profile()
	train_consist.reset_to_default()
	current_tier = 1
	if auto_save_enabled:
		meta_progression.save_to_file(train_consist)
	_apply_train_consist_to_world()
	if run_flow_overlay != null and run_flow_overlay.is_open():
		run_flow_overlay.show_hub(meta_progression, train_consist, current_seed)
	if hud != null:
		hud.push_status("🔄 已重置本機存檔與列車初始編成")


func _on_blueprint_closed() -> void:
	if auto_save_enabled and meta_progression != null:
		meta_progression.save_to_file(train_consist)


func _sync_hud_state() -> void:
	if hud == null:
		return
	if armored_train != null:
		hud.update_train_hull(armored_train.hull_hp, armored_train.max_hull_hp)
	if train_consist != null:
		hud.update_train_consist_summary(train_consist.compute_stats())
	if loot_stash_manager != null:
		hud.update_inventory(
			loot_stash_manager.backpack,
			loot_stash_manager.get_backpack_used(),
			loot_stash_manager.backpack_capacity,
			loot_stash_manager.train_stash,
			loot_stash_manager.get_stash_total(),
			loot_stash_manager.get_remaining_loot_count(),
			loot_stash_manager.get_total_loot_count()
		)
	var active: SquadCharacter = get_active_character()
	if active != null:
		hud.update_player_vitals(active.hp, active.max_hp, active.ammo_in_mag, active.mag_size, active.is_reloading)
	if horde_manager != null:
		hud.update_run_timer(horde_manager.time_remaining, horde_manager.current_stage_name, horde_manager.total_kills, horde_manager.get_active_zombie_count())
	if mission_director != null and active != null and armored_train != null:
		hud.update_mission_status(mission_director.get_mission_hud_text(), mission_director.get_compass_hint(active.global_position, armored_train.get_boarding_world_pos()))
	if train_blueprint_ui != null and meta_progression != null:
		train_blueprint_ui.update_stash_reference(meta_progression.warehouse)


func _apply_train_consist_to_world() -> void:
	if train_consist == null:
		return
	var stats: Dictionary = train_consist.compute_stats()
	if armored_train != null:
		armored_train.apply_consist(train_consist)
	if loot_stash_manager != null:
		loot_stash_manager.backpack_capacity = int(stats.get("backpack_capacity", 12))
	_sync_hud_state()


func _on_train_consist_changed() -> void:
	_apply_train_consist_to_world()


func _on_toggle_train_blueprint() -> void:
	if run_flow_overlay != null and run_flow_overlay.is_open():
		run_flow_overlay.close()
	if train_blueprint_ui != null:
		train_blueprint_ui.toggle_open()


func _on_sandbox_resources_requested() -> void:
	if meta_progression == null:
		return
	for k: String in LootStashManager.RESOURCE_ORDER:
		meta_progression.warehouse[k] = int(meta_progression.warehouse.get(k, 0)) + 20
	_sync_hud_state()


func _on_train_hull_changed(current_hp: float, max_hp: float) -> void:
	if hud != null:
		hud.update_train_hull(current_hp, max_hp)


func _on_train_destroyed() -> void:
	if run_active:
		finish_run(false, "裝甲列車車體遭屍潮攻破")


func _on_player_died() -> void:
	if run_active:
		finish_run(false, "玩家角色力竭陣亡")


func _on_extraction_succeeded() -> void:
	if run_active:
		finish_run(true, "")


func _on_player_shot_fired(muzzle_pos: Vector3, shot_dir: Vector3, damage: float) -> void:
	if horde_manager != null and run_active:
		horde_manager.damage_zombies_along_ray(muzzle_pos, shot_dir, 18.5, damage)


func _on_player_hp_changed(_hp: float, _max_hp: float) -> void:
	_sync_hud_state()


func _on_player_ammo_changed(_ammo: int, _mag: int, _rel: bool) -> void:
	_sync_hud_state()


func _on_zombie_attacked_player(damage: float) -> void:
	var active: SquadCharacter = get_active_character()
	if active != null and run_active:
		active.take_damage(damage)


func _on_zombie_attacked_train(damage: float) -> void:
	if armored_train != null and run_active:
		var dr: float = float(train_consist.compute_stats().get("damage_reduction", 0.0)) if train_consist != null else 0.0
		armored_train.apply_hull_damage(damage * (1.0 - dr))


func _on_wave_stage_changed(_stage: int, stage_name: String) -> void:
	if hud != null:
		hud.push_status("⚠️ 威脅升級：%s" % stage_name)


func _on_zombie_killed(_arch: String, _kills: int, _pos: Vector3) -> void:
	_sync_hud_state()


func _on_overtime_triggered() -> void:
	if hud != null:
		hud.push_status("🚨 倒數歸零！街區進入無限滅絕屍潮，立即衝回北方裝甲列車撤離！")


func _on_objective_ambush(pos: Vector3) -> void:
	if horde_manager != null:
		horde_manager.spawn_local_ambush(pos, 4)
	if hud != null:
		hud.push_status("🚨 目標啟動聲響吸引了周圍屍群！小心防禦！")


func _on_inventory_changed(_bp: Dictionary, _used: int, _cap: int) -> void:
	_sync_hud_state()


func _on_stash_changed(_stash: Dictionary, _total: int) -> void:
	_sync_hud_state()


func select_character(idx: int, snap_camera: bool = false) -> void:
	if squad.is_empty():
		return
	active_index = clampi(idx, 0, squad.size() - 1)
	var leader: SquadCharacter = squad[active_index]

	var follower_offsets: Array[Vector3] = [Vector3(-2.3, 0.0, 1.5), Vector3(2.3, 0.0, 1.5)]
	var f_slot: int = 0
	for i in range(squad.size()):
		var g: SquadCharacter = squad[i]
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
		var active: SquadCharacter = get_active_character()
		if active != null:
			active.trigger_preview_action(action_name)
			if hud != null:
				hud.push_status("%s 執行動作：%s" % [active.display_name, _action_zh(action_name)])


func _on_character_action_changed(char_id: String, action_name: String) -> void:
	if hud != null:
		hud.update_character_action(char_id, action_name)


func _on_interaction_completed(char_id: String, station_label: String) -> void:
	var active: SquadCharacter = get_active_character()
	var target: Dictionary = _active_interact_target
	if target.is_empty() and active != null:
		target = _find_nearest_interaction(active.global_position)
	_resolve_interaction_target(target, char_id, station_label, -1.0)


func _on_stratagem_step_succeeded(_step: int, _total: int) -> void:
	var active: SquadCharacter = get_active_character()
	if active != null:
		active.play_stratagem_step_fx()


func _on_stratagem_step_failed(_expected: String, _got: String) -> void:
	if hud != null:
		hud.push_status("❌ 指令按錯！序列重置，冷靜重新輸入！")


func _on_stratagem_completed(target: Dictionary, elapsed_sec: float) -> void:
	var active: SquadCharacter = get_active_character()
	if active != null:
		active.play_stratagem_complete_fx()
	_resolve_interaction_target(target, active.char_id if active != null else "reina_ar", str(target.get("label", "")), elapsed_sec)


func _on_stratagem_cancelled(_target: Dictionary) -> void:
	var active: SquadCharacter = get_active_character()
	if active != null and active.current_action == "interact":
		active.trigger_preview_action("idle")


func _try_begin_stratagem_interaction() -> void:
	if stratagem_ui == null or not run_active:
		return
	var active: SquadCharacter = get_active_character()
	if active == null or active.is_dead:
		return
	var target: Dictionary = _find_nearest_interaction(active.global_position)
	if target.is_empty():
		return

	var kind: String = str(target.get("kind", ""))
	if kind == "loot" and loot_stash_manager != null and loot_stash_manager.get_backpack_free() <= 0:
		if hud != null:
			hud.push_status("⚠️ 隨身背包已滿（%d/%d），請先返回北方【裝甲列車暫存倉】卸貨！" % [
				loot_stash_manager.get_backpack_used(),
				loot_stash_manager.backpack_capacity,
			])
		return
	if kind == "train_stash" and loot_stash_manager != null and loot_stash_manager.get_backpack_used() <= 0:
		if hud != null:
			hud.push_status("📦 隨身背包目前為空，先前往都市街區搜刮物資吧！")
		return
	if kind == "boarding_zone":
		if mission_director != null and mission_director.is_extracting:
			return
		if mission_director != null and mission_director.is_mission_complete:
			var extract_target: Dictionary = target.duplicate(true)
			extract_target["kind"] = "boarding_extract"
			extract_target["label"] = "啟動裝甲列車鍋爐撤離"
			stratagem_ui.start_sequence(extract_target)
			active.play_stratagem_step_fx()
			return
		if train_blueprint_ui != null:
			train_blueprint_ui.set_open(true)
		if hud != null:
			hud.push_status("🚂 已進入裝甲列車藍圖整備室")
		return

	stratagem_ui.start_sequence(target)
	active.play_stratagem_step_fx()


func _resolve_interaction_target(target: Dictionary, char_id: String, station_label: String, elapsed_sec: float) -> void:
	var speed_tag: String = ("（⚡ %.2fs 完成）" % elapsed_sec) if elapsed_sec > 0.0 else ""
	var kind: String = str(target.get("kind", ""))

	if kind == "mission_objective" and mission_director != null:
		var mres: Dictionary = mission_director.complete_objective(str(target.get("id", "")))
		if bool(mres.get("ok", false)):
			if bool(mres.get("all_done", false)):
				hud.push_status("✅ 主線任務【%s】全部達成%s！速回北方裝甲列車登車區啟動發車撤離！" % [mission_director.mission_title, speed_tag])
			else:
				hud.push_status("🎯 完成任務目標【%s】%s（進度 %d/%d）" % [str(mres.get("label", "")), speed_tag, int(mres.get("completed", 0)), int(mres.get("target", 1))])
		_sync_hud_state()
		return

	if kind == "survivor_rescue" and mission_director != null:
		var sres: Dictionary = mission_director.rescue_survivor()
		if bool(sres.get("ok", false)):
			var crew: Dictionary = sres.get("crew", {}) as Dictionary
			hud.push_status("💚 已救出受困倖存者【%s】%s！成功搭車撤離後將永久加入乘員名冊！" % [str(crew.get("name", "倖存者")), speed_tag])
		_sync_hud_state()
		return

	if kind == "loot" and loot_stash_manager != null:
		var loot_id: String = str(target.get("id", ""))
		var res: Dictionary = loot_stash_manager.collect_loot_point(loot_id)
		var reason: String = str(res.get("reason", ""))
		if bool(res.get("ok", false)):
			var gained_dict: Dictionary = res.get("gained", {}) as Dictionary
			var gained_text: String = loot_stash_manager.format_resource_dict(gained_dict)
			if reason == "partial":
				hud.push_status("🎒 搜刮【%s】%s取得 %s（背包已滿，請返回裝甲列車暫存倉卸貨！）" % [str(res.get("label", station_label)), speed_tag, gained_text])
			else:
				hud.push_status("✓ 搜刮完成【%s】%s：取得 %s（背包 %d/%d）" % [
					str(res.get("label", station_label)),
					speed_tag,
					gained_text,
					loot_stash_manager.get_backpack_used(),
					loot_stash_manager.backpack_capacity,
				])
		elif reason == "backpack_full":
			hud.push_status("⚠️ 隨身背包已滿（%d/%d），請先返回北方【裝甲列車暫存倉】卸貨！" % [
				loot_stash_manager.get_backpack_used(),
				loot_stash_manager.backpack_capacity,
			])
		_sync_hud_state()
		return

	if kind == "train_stash" and loot_stash_manager != null:
		var dep: Dictionary = loot_stash_manager.deposit_backpack_to_stash()
		var count: int = int(dep.get("count", 0))
		if count > 0:
			var dep_dict: Dictionary = dep.get("deposited", {}) as Dictionary
			var dep_text: String = loot_stash_manager.format_resource_dict(dep_dict)
			if armored_train != null:
				armored_train.play_stash_deposit_fx()
			hud.push_status("📦 已卸貨至【裝甲列車暫存倉】%s：%s（本局安全入庫 %d 件）" % [speed_tag, dep_text, loot_stash_manager.get_stash_total()])
		else:
			hud.push_status("📦 隨身背包目前為空，先前往都市街區搜刮物資吧！")
		_sync_hud_state()
		return

	if (kind == "boarding_zone" or kind == "boarding_extract") and armored_train != null:
		if mission_director != null and mission_director.is_mission_complete and not mission_director.is_extracting:
			var dep_sec: float = float(train_consist.compute_stats().get("departure_seconds", 45.0))
			mission_director.start_extraction(dep_sec)
			if horde_manager != null:
				horde_manager.set_extraction_holdout(true)
			hud.push_status("🚂 汽笛鳴響%s！鍋爐點火撤離倒數 %.0f 秒 — 守住登車區抵禦最終屍潮！" % [speed_tag, dep_sec])
			return
		if train_blueprint_ui != null:
			train_blueprint_ui.set_open(true)
		hud.push_status("🚂 已進入裝甲列車藍圖整備室")
		return

	var who: String = char_id
	for g in squad:
		if g.char_id == char_id:
			who = g.display_name
			break
	if hud != null:
		hud.push_status("✓ %s 完成了【%s】操作！" % [who, station_label])


func _on_camera_lock_changed(locked: bool) -> void:
	if hud != null:
		hud.set_camera_locked(locked)


func _on_camera_projection_changed(is_ortho: bool) -> void:
	if hud != null:
		hud.set_camera_orthographic(is_ortho)
		hud.push_status("視角切換為：%s" % ("Zomboid 45° 正交等角" if is_ortho else "RO / HD-2D 透視"))


func _is_modal_open() -> bool:
	return (train_blueprint_ui != null and train_blueprint_ui.is_open()) or (run_flow_overlay != null and run_flow_overlay.is_open())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode

		if code == KEY_T:
			if stratagem_ui != null:
				stratagem_ui.cancel()
			_on_toggle_train_blueprint()
			get_viewport().set_input_as_handled()
			return
		if code == KEY_H:
			if stratagem_ui != null:
				stratagem_ui.cancel()
			_on_toggle_hub_overlay()
			get_viewport().set_input_as_handled()
			return
		if code == KEY_ESCAPE:
			if stratagem_ui != null and stratagem_ui.is_active:
				stratagem_ui.cancel()
				get_viewport().set_input_as_handled()
				return
			if train_blueprint_ui != null and train_blueprint_ui.is_open():
				train_blueprint_ui.set_open(false)
				get_viewport().set_input_as_handled()
				return
			if run_flow_overlay != null and run_flow_overlay.is_open():
				run_flow_overlay.close()
				get_viewport().set_input_as_handled()
				return
		if _is_modal_open():
			return

		# Intercept Stratagem inputs BEFORE Godot GUI focus navigation can steal Arrow Keys / Space!
		if stratagem_ui != null and stratagem_ui.is_active:
			if code == KEY_SPACE or code == KEY_SHIFT:
				stratagem_ui.cancel()
				var active_r: SquadCharacter = get_active_character()
				if active_r != null:
					active_r.start_roll(Vector3.ZERO)
				get_viewport().set_input_as_handled()
				return
			if code == KEY_E or code == KEY_F:
				stratagem_ui.cancel()
				get_viewport().set_input_as_handled()
				return
			var dir: String = stratagem_ui.keycode_to_direction(code)
			if not dir.is_empty():
				stratagem_ui.feed_direction(dir)
				get_viewport().set_input_as_handled()
				return

		match code:
			KEY_E, KEY_F:
				_try_begin_stratagem_interaction()
				get_viewport().set_input_as_handled()
			KEY_1:
				select_character(0)
			KEY_2:
				select_character(1)
			KEY_3:
				select_character(2)
			KEY_R:
				var active: SquadCharacter = get_active_character()
				if active != null and active.start_reload() and hud != null:
					hud.push_status("🔫 正在更換彈匣...")
				get_viewport().set_input_as_handled()
			KEY_F5:
				_on_regenerate_sector_requested()
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if _is_modal_open():
			return
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and camera_rig != null:
			if stratagem_ui != null and stratagem_ui.is_active:
				stratagem_ui.cancel()
			var click_pos: Vector3 = camera_rig.raycast_ground(mb.position, 0.0)
			var active: SquadCharacter = get_active_character()
			if active != null:
				active.set_click_move_target(click_pos)
				_spawn_move_ping(click_pos)


func _physics_process(delta: float) -> void:
	_time_elapsed += delta
	if sector_generator != null:
		sector_generator.animate_lights(_time_elapsed)
	if armored_train != null:
		armored_train.animate_train(_time_elapsed)
	if loot_stash_manager != null:
		loot_stash_manager.animate_markers(_time_elapsed)
	if mission_director != null:
		mission_director.animate_markers(_time_elapsed)

	if squad.is_empty() or camera_rig == null:
		return

	var active: SquadCharacter = get_active_character()
	var vp: Viewport = get_viewport()
	var aim_pos: Vector3 = active.global_position + Vector3.RIGHT * 4.0
	if vp != null:
		aim_pos = camera_rig.raycast_ground(vp.get_mouse_position(), 0.0)

	if _aim_cursor != null:
		_aim_cursor.global_position = Vector3(aim_pos.x, 0.18, aim_pos.z)

	var axes: Dictionary = camera_rig.get_screen_axes()
	var cam_right: Vector3 = axes["right"] as Vector3
	var cam_fwd: Vector3 = axes["forward"] as Vector3
	var cam_yaw: float = float(axes["yaw_rad"])

	if armored_train != null:
		armored_train.set_camera_yaw(cam_yaw)

	var stratagem_active: bool = (stratagem_ui != null and stratagem_ui.is_active)
	var ui_blocking: bool = _is_modal_open() or not run_active
	camera_rig.input_suppressed = stratagem_active or _is_modal_open()
	var move_in: Vector3 = Vector3.ZERO
	if not ui_blocking and not stratagem_active:
		if Input.is_action_pressed("move_forward") or Input.is_physical_key_pressed(KEY_W):
			move_in += cam_fwd
		if Input.is_action_pressed("move_back") or Input.is_physical_key_pressed(KEY_S):
			move_in -= cam_fwd
		if Input.is_action_pressed("move_left") or Input.is_physical_key_pressed(KEY_A):
			move_in -= cam_right
		if Input.is_action_pressed("move_right") or Input.is_physical_key_pressed(KEY_D):
			move_in += cam_right

	var mouse_over_ui: bool = ui_blocking or (hud != null and hud.is_mouse_over_controls())
	var want_shoot: bool = (not mouse_over_ui) and (not stratagem_active) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var want_interact: bool = false  # Replaced by Helldivers-style StratagemInputUi on E/F press!
	var want_roll: bool = (not ui_blocking) and (not stratagem_active) and (Input.is_action_just_pressed("dodge") or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SHIFT))

	_active_interact_target = _find_nearest_interaction(active.global_position)
	_update_interaction_hud(active.global_position, _active_interact_target)

	var nearest_label: String = str(_active_interact_target.get("label", ""))
	for i in range(squad.size()):
		var g: SquadCharacter = squad[i]
		g.set_camera_yaw(cam_yaw)
		if i == active_index:
			g.update_character(delta, move_in, aim_pos, want_shoot, want_interact, want_roll, nearest_label)
		else:
			g.update_character(delta, Vector3.ZERO, aim_pos, false, false, false, "")

	# Phase 3 & 4 Live Simulation Tick (paused cleanly when blueprint/hub overlay is open)
	if run_active and not _is_modal_open():
		var stats: Dictionary = train_consist.compute_stats()
		if horde_manager != null:
			horde_manager.update_horde(delta, active.global_position, not active.is_dead, armored_train, stats, cam_yaw)

		# Passive Medbay healing near train platform & Armory/Mechanic hull auto-repair
		var heal_rate: float = float(stats.get("heal_rate", 0.0))
		if heal_rate > 0.0 and active.global_position.z < -7.2:
			active.heal(heal_rate * delta)
		var repair_rate: float = float(stats.get("repair_rate", 0.0))
		if repair_rate > 0.0 and armored_train != null and armored_train.hull_hp < armored_train.max_hull_hp:
			armored_train.repair_hull(repair_rate * delta)

		if mission_director != null and armored_train != null:
			var in_boarding: bool = armored_train.is_player_in_boarding_zone(active.global_position)
			mission_director.update_extraction(delta, in_boarding)

		_hud_compass_timer -= delta
		if _hud_compass_timer <= 0.0:
			_hud_compass_timer = 0.25
			if hud != null:
				hud.update_run_timer(horde_manager.time_remaining, horde_manager.current_stage_name, horde_manager.total_kills, horde_manager.get_active_zombie_count())
				if mission_director != null and armored_train != null:
					hud.update_mission_status(mission_director.get_mission_hud_text(), mission_director.get_compass_hint(active.global_position, armored_train.get_boarding_world_pos()))


func _find_nearest_interaction(pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = 999.0

	if mission_director != null:
		var m_inter: Dictionary = mission_director.find_nearest_interactable(pos, 3.4)
		if not m_inter.is_empty():
			var mpos: Vector3 = m_inter.get("pos", Vector3.ZERO) as Vector3
			best_dist = Vector2(pos.x - mpos.x, pos.z - mpos.z).length()
			best = m_inter

	if armored_train != null:
		for zone in armored_train.get_interactive_zones():
			var zpos: Vector3 = zone.get("pos", Vector3.ZERO) as Vector3
			var radius: float = float(zone.get("radius", 2.6))
			var d: float = Vector2(pos.x - zpos.x, pos.z - zpos.z).length()
			if d <= radius and d < best_dist:
				best_dist = d
				best = zone

	if loot_stash_manager != null:
		var loot_entry: Dictionary = loot_stash_manager.find_nearest_unlooted(pos, 3.2)
		if not loot_entry.is_empty():
			var lpos: Vector3 = loot_entry.get("pos", Vector3.ZERO) as Vector3
			var ld: float = Vector2(pos.x - lpos.x, pos.z - lpos.z).length()
			if ld < best_dist:
				best_dist = ld
				best = {
					"id": str(loot_entry.get("id", "")),
					"kind": "loot",
					"label": str(loot_entry.get("label", "物資補給箱")),
					"pos": lpos,
				}

	return best


func _update_interaction_hud(player_pos: Vector3, target: Dictionary) -> void:
	if hud == null:
		return
	var in_boarding: bool = armored_train != null and armored_train.is_player_in_boarding_zone(player_pos)
	hud.set_boarding_zone_active(in_boarding)

	if stratagem_ui != null and stratagem_ui.is_active:
		hud.set_interact_prompt_text("")
		return

	if target.is_empty():
		hud.set_interact_prompt_text("")
		return

	var kind: String = str(target.get("kind", ""))
	var label: String = str(target.get("label", ""))
	if kind == "mission_objective":
		hud.set_interact_prompt_text("[按 E / F] 開始 6 鍵指令：%s" % label, Color(0.98, 0.56, 1.0))
	elif kind == "survivor_rescue":
		hud.set_interact_prompt_text("[按 E / F] 開始 5 鍵救援指令：%s" % label, Color(0.42, 1.0, 0.68))
	elif kind == "loot" and loot_stash_manager != null:
		if loot_stash_manager.get_backpack_free() <= 0:
			hud.set_interact_prompt_text("⚠️ 背包已滿 (%d/%d)！請返回裝甲列車暫存倉卸貨" % [
				loot_stash_manager.get_backpack_used(),
				loot_stash_manager.backpack_capacity,
			], Color(1.0, 0.56, 0.34))
		else:
			hud.set_interact_prompt_text("[按 E / F] 開始 4 鍵開箱指令：%s（背包 %d/%d）" % [
				label,
				loot_stash_manager.get_backpack_used(),
				loot_stash_manager.backpack_capacity,
			], Color(0.45, 0.94, 1.0))
	elif kind == "train_stash" and loot_stash_manager != null:
		var carried: int = loot_stash_manager.get_backpack_used()
		if carried > 0:
			hud.set_interact_prompt_text("[按 E / F] 開始 3 鍵卸貨指令（存入 %d 件物資）" % carried, Color(1.0, 0.86, 0.38))
		else:
			hud.set_interact_prompt_text("📦 裝甲列車暫存倉（目前背包無可卸貨的物資）", Color(0.84, 0.80, 0.66))
	elif kind == "boarding_zone":
		if mission_director != null and mission_director.is_extracting:
			hud.set_interact_prompt_text("🚂 撤離發車倒數 %.1fs — 請留在登車區！" % mission_director.extraction_remaining, Color(0.42, 1.0, 0.68))
		elif mission_director != null and mission_director.is_mission_complete:
			hud.set_interact_prompt_text("[按 E / F] 🚂 開始 6 鍵點火指令・發車撤離！", Color(0.42, 1.0, 0.68))
		else:
			hud.set_interact_prompt_text("[按 E / F] 開啟【蒸氣列車設計圖】（或按 T）", Color(0.42, 0.98, 0.72))
	else:
		hud.set_interact_hint(label)


func _spawn_move_ping(pos: Vector3) -> void:
	if vfx_root == null:
		return
	var ping: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.34
	ping.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.38, 0.92, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.38, 0.92, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ping.material_override = mat
	vfx_root.add_child(ping)
	ping.global_position = Vector3(pos.x, 0.18, pos.z)

	var tw: Tween = ping.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ping, "scale", Vector3.ONE * 2.2, 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(ping.queue_free)


func _action_zh(action_name: String) -> String:
	match action_name:
		"walk":
			return "走路"
		"shoot":
			return "開槍"
		"interact":
			return "搜刮／操作"
		"roll":
			return "翻滾"
		_:
			return "待機"
