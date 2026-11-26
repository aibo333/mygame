extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _ran: bool = false


func _assert(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		push_error("[FAIL] %s" % label)
		print("[FAIL] %s" % label)


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("=== Armored Train Extraction — Phase 1 + Phase 2 Godot 4 Verification ===")
	_test_assets_and_config()
	_test_main_scene_player_and_phase2()
	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _test_assets_and_config() -> void:
	var ids: PackedStringArray = SquadConfig.get_squad_ids()
	_assert(ids.size() == 1, "Solo player mode active (AI followers removed)")
	_assert(ResourceLoader.exists(SquadConfig.AVATAR_FBX_PATH), "SummerCuteness avatar FBX exists")
	var avatar_catalog: Array[Dictionary] = SquadConfig.get_avatar_catalog()
	_assert(avatar_catalog.size() >= 3, "Avatar catalog lists >= 3 unique characters (got %d)" % avatar_catalog.size())
	for acfg: Dictionary in avatar_catalog:
		var aid: String = str(acfg.get("id", ""))
		var mpath: String = str(acfg.get("model_path", ""))
		_assert(ResourceLoader.exists(mpath), "Avatar catalog model exists: %s" % aid)
		var packed_av := load(mpath) as PackedScene
		_assert(packed_av != null, "Avatar catalog model loads as PackedScene: %s" % aid)
	for anim_key: String in ["idle", "walk", "shoot", "roll"]:
		var apath: String = str(SquadConfig.MIXAMO_ANIMS.get(anim_key, ""))
		_assert(ResourceLoader.exists(apath), "Mixamo animation FBX exists: %s" % anim_key)
	for piece: String in ["road-asphalt-center", "wall-a-garage", "wall-b-roof-slant", "truck-green", "scaffolding-structure"]:
		_assert(ResourceLoader.exists(SquadConfig.KENNEY_DIR + piece + ".glb"), "Kenney Retro Urban asset exists: %s" % piece)
	for sfx_key: String in ["clip_out", "clip_in", "clip_hit", "bolt_back", "bolt_forward", "bolt_back_unsilenced", "bolt_forward_unsilenced", "add_ammo", "draw", "silencer_on", "silencer_off", "silencer_screw_on_start", "silencer_screw_off_end"]:
		var spath: String = str(SquadConfig.WEAPON_M4A1_SFX.get(sfx_key, ""))
		_assert(ResourceLoader.exists(spath), "M4A1 SFX exists: %s" % sfx_key)
	for list_key: String in ["fire", "fire_distant", "fire_unsilenced", "fire_unsilenced_distant", "silencer_screws"]:
		var sarr: Array = SquadConfig.WEAPON_M4A1_SFX.get(list_key, []) as Array
		var all_ok: bool = not sarr.is_empty()
		for item_path: Variant in sarr:
			if not ResourceLoader.exists(str(item_path)):
				all_ok = false
				break
		_assert(all_ok, "M4A1 SFX list exists (%d files): %s" % [sarr.size(), list_key])

	_assert(ResourceLoader.exists(SquadConfig.WEAPON_AK47_GLB_PATH), "AK-47 model GLB exists")
	_assert(ResourceLoader.exists(SquadConfig.WEAPON_DEAGLE_GLB_PATH), "Desert Eagle model GLB exists")
	for sfx_key: String in ["clip_out", "clip_in", "bolt_back", "bolt_forward", "add_ammo", "draw"]:
		_assert(ResourceLoader.exists(str(SquadConfig.WEAPON_AK47_SFX.get(sfx_key, ""))), "AK-47 SFX exists: %s" % sfx_key)
		_assert(ResourceLoader.exists(str(SquadConfig.WEAPON_DEAGLE_SFX.get(sfx_key, ""))), "Desert Eagle SFX exists: %s" % sfx_key)
	for list_key: String in ["fire", "fire_distant"]:
		var ak_arr: Array = SquadConfig.WEAPON_AK47_SFX.get(list_key, []) as Array
		var ak_ok: bool = not ak_arr.is_empty()
		for p: Variant in ak_arr:
			if not ResourceLoader.exists(str(p)):
				ak_ok = false
				break
		_assert(ak_ok, "AK-47 SFX list exists (%d files): %s" % [ak_arr.size(), list_key])
		var de_arr: Array = SquadConfig.WEAPON_DEAGLE_SFX.get(list_key, []) as Array
		var de_ok: bool = not de_arr.is_empty()
		for p: Variant in de_arr:
			if not ResourceLoader.exists(str(p)):
				de_ok = false
				break
		_assert(de_ok, "Desert Eagle SFX list exists (%d files): %s" % [de_arr.size(), list_key])


func _test_main_scene_player_and_phase2() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	_assert(packed != null, "Load res://scenes/Main.tscn")
	if packed == null:
		return

	var main: Node = packed.instantiate()
	_assert(main is RuinsBaseWorld, "Main scene root is RuinsBaseWorld")
	root.add_child(main)

	var world: RuinsBaseWorld = main as RuinsBaseWorld
	_assert(world.camera_rig != null and world.camera_rig is LolCameraController, "LolCameraController initialized")
	_assert(world.hud != null and world.hud is SquadHud, "SquadHud initialized")
	_assert(world.squad.size() == 1, "Only 1 solo player character spawned")

	var player: SquadCharacter = world.get_active_character()
	_assert(player != null and player.skeleton != null and player.skeleton.name == "GeneralSkeleton", "Player uses retargeted GeneralSkeleton")
	_assert(player.anim_player != null, "Mixamo AnimationPlayer attached")
	_assert(player.has_weapon_audio(), "Player M4A1 weapon audio loaded and pool initialized")
	var init_silenced: bool = player.silencer_attached
	_assert(player.toggle_silencer() and player.is_toggling_silencer, "Player starts M4A1 silencer toggle sequence")
	for _st: int in range(16):
		player.update_character(0.1, Vector3.ZERO, player.global_position + Vector3(0.0, 0.0, -10.0), false, false, false, "")
	_assert(not player.is_toggling_silencer and player.silencer_attached != init_silenced, "Player completes M4A1 silencer toggle cleanly")
	player.silencer_attached = true

	var anims: PackedStringArray = player.get_available_animations()
	var has_all: bool = (
		anims.has("idle")
		and anims.has("walk")
		and anims.has("shoot")
		and anims.has("interact")
		and anims.has("roll")
		and anims.has("strafe_left")
		and anims.has("strafe_right")
		and anims.has("run_backwards")
		and anims.has("reload")
		and anims.has("reload_move")
		and anims.has("hit")
		and anims.has("death")
	)
	_assert(has_all, "Player has all 12 retargeted Mixamo clips: %s" % str(anims))

	var pre_ms_pos: Vector3 = player.global_position
	var pre_ms_ammo: int = player.ammo_in_mag
	player.update_character(0.1, Vector3(1.0, 0.0, 0.0), pre_ms_pos + Vector3(0.0, 0.0, -10.0), true, false, false, "")
	_assert(
		player.velocity.length() > 1.0
		and player.ammo_in_mag == pre_ms_ammo - 1
		and player.current_action == "shoot"
		and player.anim_player.current_animation == "strafe_right",
		"Player moves, shoots, and plays directional strafe_right clip simultaneously"
	)
	player.start_reload()
	player.update_character(0.05, Vector3(0.0, 0.0, -1.0), pre_ms_pos + Vector3(0.0, 0.0, -10.0), false, false, false, "")
	_assert(player.current_action == "reload" and player.anim_player.current_animation == "reload_move", "Player plays reload_move clip while moving and reloading")
	player.global_position = pre_ms_pos
	player.reset_combat_state()

	for act: String in ["walk", "shoot", "interact", "roll"]:
		player.trigger_preview_action(act)
		_assert(player.current_action == act, "Player transitions cleanly to '%s'" % act)

	var init_lock: bool = world.camera_rig.camera_locked
	world.camera_rig.toggle_camera_lock()
	_assert(world.camera_rig.camera_locked != init_lock, "Camera lock toggles cleanly")

	var init_ortho: bool = world.camera_rig.is_orthographic
	world.camera_rig.toggle_projection_mode()
	_assert(world.camera_rig.is_orthographic != init_ortho, "Zomboid/RO camera projection toggles cleanly")

	# --- Phase 2 Verification: Seed-Driven Procedural Sector ---
	_assert(world.sector_generator != null and world.sector_generator is SectorGenerator, "Phase 2: SectorGenerator initialized")
	var sec_a1: Dictionary = world.generate_new_sector(424242, true)
	var blocks_a1: Dictionary = (sec_a1.get("blocks", {}) as Dictionary).duplicate()
	var loot_a1: Array[Dictionary] = world.sector_generator.loot_spawn_points.duplicate(true)
	var cross_a1: int = int(sec_a1.get("cross_road_x", 0))

	_assert(blocks_a1.size() == 4, "Phase 2: Sector assigns all 4 city block quadrants (NW/NE/SW/SE)")
	var bvals: Array = blocks_a1.values()
	_assert(bvals.has("industrial") and bvals.has("commercial") and bvals.has("park_alley"), "Phase 2: Sector includes industrial, commercial, and park_alley blocks")
	_assert(loot_a1.size() >= 8 and loot_a1.size() <= 10, "Phase 2: Sector spawns 8-10 loot points (got %d)" % loot_a1.size())

	var bounds: Rect2 = world.sector_generator.world_bounds
	var all_inside: bool = true
	for lp: Dictionary in loot_a1:
		var p: Vector3 = lp.get("pos", Vector3.ZERO) as Vector3
		if not bounds.has_point(Vector2(p.x, p.z)):
			all_inside = false
			break
	_assert(all_inside, "Phase 2: All loot spawn points lie inside playable Sector bounds")

	# Deterministic regeneration with same seed
	var sec_a2: Dictionary = world.generate_new_sector(424242, true)
	var same_blocks: bool = (sec_a2.get("blocks", {}) as Dictionary) == blocks_a1
	var same_cross: bool = int(sec_a2.get("cross_road_x", 0)) == cross_a1
	var same_loot_count: bool = world.sector_generator.loot_spawn_points.size() == loot_a1.size()
	_assert(same_blocks and same_cross and same_loot_count, "Phase 2: Same seed reproduces identical Sector layout & loot count")

	# Varied generation with different seeds
	var found_diff: bool = false
	for test_seed: int in [111111, 222222, 777777, 987654]:
		var sec_other: Dictionary = world.generate_new_sector(test_seed, true)
		if (sec_other.get("blocks", {}) as Dictionary) != blocks_a1 or int(sec_other.get("cross_road_x", 0)) != cross_a1:
			found_diff = true
			break
	_assert(found_diff, "Phase 2: Different seeds produce varied Sector block/road layouts")

	# --- Milestone 1 Verification: CDDA 5-Step Civil-Defense Houses & Through-Running Railway ---
	var sec_cdda: Dictionary = world.generate_new_sector(424242, true)
	var houses: Array = sec_cdda.get("civil_houses", []) as Array
	_assert(houses.size() >= 4, "Milestone 1 (CDDA): Generates >= 4 modular civil-defense houses (got %d)" % houses.size())
	var first_house: Dictionary = houses[0] as Dictionary
	var h_fp: Rect2 = first_house.get("footprint", Rect2()) as Rect2
	var h_lot: Rect2 = first_house.get("lot_footprint", Rect2()) as Rect2
	var h_roof: Node3D = first_house.get("roof_node", null) as Node3D
	var h_node: Node3D = first_house.get("node", null) as Node3D
	var h_sockets: Array = first_house.get("loot_sockets", []) as Array
	var h_dir: String = str(first_house.get("facing_dir", ""))
	var h_reach: int = int(first_house.get("reachable_indoor", 0))
	var h_total: int = int(first_house.get("total_indoor_open", 0))
	_assert(h_lot.size.x >= 25.0 and h_fp.size.x >= 12.0 and h_fp.size.y >= 10.0 and ["N", "S", "W", "E"].has(h_dir), "Milestone 1 (CDDA): Spacious 24x24 house footprint & OMT face-road valid (%.1fx%.1fm, %s)" % [h_fp.size.x, h_fp.size.y, h_dir])
	_assert(h_total > 20 and h_reach == h_total, "Milestone 1 (CDDA Walkability): 100%% of indoor rooms reachable from street (%d/%d tiles)" % [h_reach, h_total])
	_assert(h_sockets.size() >= 3, "Milestone 1 (CDDA): House Nested Room Blocks expose >= 3 indoor loot sockets (got %d)" % h_sockets.size())
	_assert(ResourceLoader.exists("res://assets/shaders/character_silhouette.gdshader"), "Milestone 1 (Occlusion Silhouette): Character occlusion silhouette shader exists")

	var has_decal: bool = false
	if h_node != null:
		for child in h_node.get_children():
			if child is Decal:
				has_decal = true
				break
	_assert(has_decal, "Milestone 1 (CDDA Ruins Filter): House floor includes projected Decal weathering")
	_assert(ResourceLoader.exists(CddaHouseBuilder.WEATHERED_SHADER_PATH), "Milestone 1 (CDDA Shader): World-Space Noise weathering shader exists")

	var house_center := Vector3(h_fp.position.x + h_fp.size.x * 0.5, 0.0, h_fp.position.y + h_fp.size.y * 0.5)
	var cut_in: int = world.sector_generator.update_house_cutaways(house_center)
	_assert(cut_in >= 1 and h_roof != null and not h_roof.visible, "Milestone 1 (RoofCutaway): Entering house hides RoofCutaway node")
	var cut_out: int = world.sector_generator.update_house_cutaways(Vector3(0.0, 0.0, world.sector_generator.rail_z + 4.6))
	_assert(cut_out == 0 and h_roof != null and h_roof.visible, "Milestone 1 (RoofCutaway): Exiting house restores RoofCutaway visibility")

	var rz: float = world.sector_generator.rail_z
	_assert(rz > world.sector_generator.world_bounds.position.y + 8.0 and rz < world.sector_generator.world_bounds.end.y - 8.0, "Milestone 1 (Railway): Through-running central railway sits between North and South districts (z=%.1f)" % rz)

	# --- Milestone 2 Verification: Day/Night Cycle, Night Cones & Daytime Rail Driving ---
	var dn: DayNightCycleManager = world.day_night_manager
	_assert(dn != null and dn.current_day == 1 and dn.current_phase == DayNightCycleManager.Phase.DAY, "Milestone 2 (Clock): Starts on Day 1 DAY")
	_assert(dn.is_train_mobile() and not dn.is_night_lights_active(), "Milestone 2 (Clock): Train mobile & night lights off during DAY")

	dn.update_cycle(DayNightCycleManager.DAY_DURATION + 0.1)
	_assert(dn.current_phase == DayNightCycleManager.Phase.DUSK and not dn.is_train_mobile() and dn.is_night_lights_active(), "Milestone 2 (Clock): Transitions DAY -> DUSK and locks train mobility")
	dn.update_cycle(DayNightCycleManager.DUSK_DURATION + 0.1)
	_assert(dn.current_phase == DayNightCycleManager.Phase.NIGHT and dn.is_night_lights_active(), "Milestone 2 (Clock): Transitions DUSK -> NIGHT")
	dn.update_cycle(DayNightCycleManager.NIGHT_DURATION + 0.1)
	_assert(dn.current_phase == DayNightCycleManager.Phase.DAY and dn.current_day == 2, "Milestone 2 (Clock): Transitions NIGHT -> Day 2 DAY")

	dn.schedule_blood_moon(true)
	dn.force_phase(DayNightCycleManager.Phase.DUSK, 2, DayNightCycleManager.DUSK_DURATION - 0.1)
	dn.update_cycle(0.2)
	_assert(dn.current_phase == DayNightCycleManager.Phase.BLOOD_MOON and dn.is_blood_moon(), "Milestone 2 (Blood Moon): Scheduled Blood Moon triggers on dusk-to-night transition")

	# Night lighting + tactical flashlight + locomotive SpotLight3D cone
	var player_m2: SquadCharacter = world.get_active_character()
	var train_m2: ArmoredTrainBase = world.armored_train
	dn.force_phase(DayNightCycleManager.Phase.NIGHT, 2, 0.0)
	world._physics_process(0.05)
	_assert(world._sun_light != null and world._sun_light.light_energy < 0.5, "Milestone 2 (Lighting): Night phase dims directional sun energy (%.2f)" % (world._sun_light.light_energy if world._sun_light else -1.0))
	_assert(player_m2.flashlight_light != null and player_m2.flashlight_light.visible, "Milestone 2 (Flashlight): Player tactical SpotLight3D auto-enables at NIGHT")
	_assert(train_m2._headlamp_spot != null and train_m2._headlamp_spot.visible, "Milestone 2 (Train Light): Locomotive searchlight SpotLight3D auto-enables at NIGHT")
	var fl_after_toggle: bool = player_m2.toggle_flashlight()
	_assert(not fl_after_toggle and not player_m2.flashlight_light.visible, "Milestone 2 (Flashlight): Manual [L] toggle turns flashlight off")
	player_m2.reset_flashlight_auto()

	# Night mobility lock check
	var x_before_night_drive: float = train_m2.position.x
	world._on_train_drive_requested(-1)
	world._physics_process(0.4)
	_assert(train_m2.rail_throttle == 0 and is_equal_approx(train_m2.position.x, x_before_night_drive), "Milestone 2 (Night Lock): Train refuses movement during NIGHT")

	# Clock below minimap + Boiler room [F] helm console gating
	var minimap_node: Control = world.hud._minimap
	var clock_card: Control = world.hud.find_child("WorldClockCard", true, false) as Control
	_assert(clock_card != null and minimap_node != null and clock_card.get_parent() == minimap_node.get_parent(), "Milestone 2 (HUD Clock): Clock card placed in same right-side panel as Minimap")
	_assert(clock_card.get_index() > minimap_node.get_index(), "Milestone 2 (HUD Clock): Clock card sits directly below MinimapWidget")
	_assert(world.train_helm_ui != null and not world.train_helm_ui.is_open(), "Milestone 2 (Helm Gate): TrainHelmUi starts closed")
	player_m2.global_position = Vector3(0.0, 0.0, train_m2.position.z + 6.5)
	_assert(not world._try_open_train_helm() and not world.train_helm_ui.is_open(), "Milestone 2 (Helm Gate): Cannot open TrainHelmUi from outside boiler room")

	# Daytime bidirectional movement + stationary tracks + passenger carry + bounds clamp
	dn.force_phase(DayNightCycleManager.Phase.DAY, 3, 0.0)
	world._physics_process(0.05)
	_assert(not player_m2.flashlight_light.visible and not train_m2._headlamp_spot.visible, "Milestone 2 (Lighting): Returning to DAY turns off night spotlights")
	player_m2.global_position = train_m2.get_helm_world_pos()
	_assert(train_m2.is_point_inside_train(player_m2.global_position) and train_m2.is_player_at_helm_console(player_m2.global_position), "Milestone 2 (Helm Gate): Player positioned at boiler room throttle console")
	var helm_near: Dictionary = world._find_nearest_interaction(player_m2.global_position)
	_assert(str(helm_near.get("kind", "")) == "train_helm", "Milestone 2 (Helm Gate): Nearest interaction at console is train_helm")
	world._try_begin_stratagem_interaction()
	_assert(world.train_helm_ui.is_open(), "Milestone 2 (Helm Gate): Pressing [F] at boiler console opens TrainHelmUi")

	var start_tx: float = train_m2.position.x
	var start_px: float = player_m2.global_position.x
	world.train_helm_ui.drive_requested.emit(-1)
	for _s: int in range(10):
		world._physics_process(0.05)
	var moved_west: float = train_m2.position.x - start_tx
	_assert(moved_west < -1.5, "Milestone 2 (Day Drive): Train drives West (-X) from Helm Console during DAY (dx=%.2f)" % moved_west)
	_assert(is_equal_approx(train_m2._tracks_root.position.x, -train_m2.position.x), "Milestone 2 (Tracks): Railway tracks stay anchored in world space")
	_assert(absf((player_m2.global_position.x - start_px) - moved_west) < 0.35, "Milestone 2 (Passenger): Riding player shifts along X with moving train")

	world.train_helm_ui.drive_requested.emit(1)
	var mid_tx: float = train_m2.position.x
	for _s2: int in range(15):
		world._physics_process(0.05)
	_assert(train_m2.position.x > mid_tx + 2.0, "Milestone 2 (Day Drive): Train drives East (+X) when throttle=+1")
	world.train_helm_ui.drive_requested.emit(0)
	world.train_helm_ui.set_open(false)
	_assert(not world.train_helm_ui.is_open() and train_m2.rail_throttle == 0, "Milestone 2 (Helm Gate): Exiting console closes TrainHelmUi cleanly")

	# Bounds clamp test
	for _s3: int in range(40):
		train_m2.drive_along_rail(0.25, world.sector_generator.world_bounds.position.x, world.sector_generator.world_bounds.end.x, 1)
	var half_l: float = train_m2.get_train_half_length()
	_assert(train_m2.position.x <= world.sector_generator.world_bounds.end.x - half_l + 0.01, "Milestone 2 (Bounds): Train position clamps cleanly inside Sector world_bounds")

	# Restore clean Day 1 docked sector state for Phase 2-5 assertions
	world.generate_new_sector(424242, true)

	# --- Milestone 3 Verification: Dual-Layer Zombie AI & Blood Moon Dual-Track ---
	var hm3: HordeManager = world.horde_manager
	var dn3: DayNightCycleManager = world.day_night_manager
	var roamers: Array[ZombieUnit] = hm3.get_active_zombies()
	var indoor_roamer_found: bool = false
	var any_roamer_found: bool = false
	for roam_z: ZombieUnit in roamers:
		if roam_z.behavior_mode == ZombieUnit.BehaviorMode.ROAMER:
			any_roamer_found = true
			if roam_z.is_indoor_spawn:
				indoor_roamer_found = true
	_assert(any_roamer_found and indoor_roamer_found, "Milestone 3 (Day Roamers): Daytime sector spawns both outdoor & indoor house roamers")

	# Sight/Noise separation test: silenced shot at 14m doesn't alert, loud shot at 14m alerts!
	hm3.clear_all_zombies()
	var test_roamer: ZombieUnit = hm3.spawn_zombie("walker", Vector3(14.0, 0.0, 14.0))
	test_roamer.setup_roamer(Vector3(14.0, 0.0, 14.0), true)
	var alerted_sup: int = hm3.emit_gunshot_noise(Vector3(0.0, 0.0, 14.0), 7.5)
	_assert(alerted_sup == 0 and test_roamer.alert_state == ZombieUnit.AlertState.IDLE_PATROL, "Milestone 3 (Noise Circle): Suppressed gunshot (7.5m) does not alert roamer at 14m")
	var alerted_loud: int = hm3.emit_gunshot_noise(Vector3(0.0, 0.0, 14.0), 22.0)
	_assert(alerted_loud == 1 and test_roamer.alert_state == ZombieUnit.AlertState.INVESTIGATE_NOISE, "Milestone 3 (Noise Circle): Unsuppressed gunshot (22m) alerts indoor roamer to investigate")

	# Night Siege Train Tracking + Multi-Day Scaling
	var day1_hp_mult: float = hm3.get_day_hp_multiplier()
	world.armored_train.set_rail_x(-12.0)
	var siege_target: Vector3 = world.armored_train.get_nearest_perimeter_world_pos(Vector3(-12.0, 0.0, 15.0))
	_assert(absf(siege_target.x - (-12.0)) <= 1.0, "Milestone 3 (Train Siege Anchor): Night siege perimeter locks onto relocated train X (-12.0)")
	dn3.force_phase(DayNightCycleManager.Phase.NIGHT, 3, 0.0)
	world._physics_process(0.05)
	_assert(test_roamer.behavior_mode == ZombieUnit.BehaviorMode.SIEGE, "Milestone 3 (Night Switch): Nightfall flips active roamers into SIEGE mode")
	_assert(hm3.get_day_hp_multiplier() > day1_hp_mult, "Milestone 3 (Day Scaling): Multi-day stay scales zombie HP multiplier (Day3=%.2f > Day1=%.2f)" % [hm3.get_day_hp_multiplier(), day1_hp_mult])

	# Blood Moon Dual-Track (Time + Action + Random Event) + Dusk Warning + Elite Drop
	dn3.reset(424242)
	var bm_start: float = dn3.blood_moon_value
	dn3.update_cycle(10.0)
	_assert(dn3.blood_moon_value > bm_start, "Milestone 3 (Blood Moon Time): Time accumulation raises Blood Moon gauge")
	var bm_after_time: float = dn3.blood_moon_value
	dn3.add_blood_moon_pressure(25.0, "test_loud")
	dn3.trigger_blood_moon_event(-5.0, "Test Cold Front")
	_assert(is_equal_approx(dn3.blood_moon_value, bm_after_time + 20.0), "Milestone 3 (Blood Moon Dual-Track): Action pressure & random anomaly events modify Blood Moon gauge")
	dn3.add_blood_moon_pressure(90.0, "threshold")
	_assert(dn3.blood_moon_value >= 100.0 and dn3.is_blood_moon_warning(), "Milestone 3 (Dusk Warning): Reaching 100%% Blood Moon triggers Dusk pre-warning")
	dn3.force_phase(DayNightCycleManager.Phase.DUSK, 1, DayNightCycleManager.DUSK_DURATION - 0.1)
	dn3.update_cycle(0.2)
	_assert(dn3.current_phase == DayNightCycleManager.Phase.BLOOD_MOON and is_equal_approx(dn3.blood_moon_value, 0.0), "Milestone 3 (Blood Moon Trigger): Dusk with full gauge enters BLOOD_MOON and resets gauge")
	world._sync_hud_state()
	_assert(world.hud._blood_moon_bar != null and is_equal_approx(world.hud._blood_moon_bar.value, 100.0), "Milestone 3 (HUD Gauge): Minimap clock Blood Moon bar displays active Blood Moon")

	var cores_before: int = world.meta_progression.modification_cores
	var parts_before: int = int(world.loot_stash_manager.backpack.get("parts", 0)) + int(world.loot_stash_manager.train_stash.get("parts", 0))
	var elite_z: ZombieUnit = hm3.spawn_zombie("blood_elite", Vector3(6.0, 0.0, 6.0))
	_assert(elite_z != null and elite_z.is_elite, "Milestone 3 (Blood Elite): Spawns blood_elite archetype")
	elite_z.apply_damage(9999.0)
	var parts_after: int = int(world.loot_stash_manager.backpack.get("parts", 0)) + int(world.loot_stash_manager.train_stash.get("parts", 0))
	_assert(world.meta_progression.modification_cores == cores_before + 1 and parts_after >= parts_before + 2, "Milestone 3 (Elite Loot): Killing Blood Moon Elite grants +1 modification core & rare parts")

	# Restore clean Day 1 docked sector state for Phase 2-5 assertions
	world.meta_progression.modification_cores = cores_before
	world.generate_new_sector(424242, true)

	# --- Milestone 4 Verification: Holdout Facility, Cross-Sector Expedition & Expanded Maintenance ---
	var em4: ExpeditionManager = world.expedition_manager
	_assert(em4 != null and em4.sector_index == 1 and not em4.rail_barricade_cleared, "Milestone 4 (Expedition): Starts in Sector #1 with Railway Blockade active")
	_assert(absf(em4.facility_pos.x) <= 16.0, "Milestone 4 (Facility Placement): Sector #1 places Holdout Facility directly beside starting train yard (x=%.1f)" % em4.facility_pos.x)
	world.armored_train.set_rail_x(26.0)
	em4.update_train_coupling(world.armored_train)
	_assert(not em4.facility_powered, "Milestone 4 (Facility Power): Holdout facility is unpowered when train drives far away")
	world.armored_train.set_rail_x(0.0)
	world._physics_process(0.05)
	_assert(em4.facility_powered, "Milestone 4 (Facility Power): Parking locomotive beside facility couples power immediately")

	var stash_parts_0: int = int(world.loot_stash_manager.train_stash.get("parts", 0))
	var cores_0: int = world.meta_progression.modification_cores
	world.dev_cheat_ui.next_day_requested.emit()
	var stash_parts_1: int = int(world.loot_stash_manager.train_stash.get("parts", 0))
	world.dev_cheat_ui.next_day_requested.emit()
	var stash_parts_2: int = int(world.loot_stash_manager.train_stash.get("parts", 0))
	_assert(stash_parts_1 - stash_parts_0 == 3 and stash_parts_2 - stash_parts_1 == 5, "Milestone 4 (Stepped Yield): Cheat DAY+1 triggers powered stepped yield (+3 Day1, +5 Day2)")
	_assert(em4.consecutive_powered_days == 2 and em4._facility_label.text.contains("連續 2 日"), "Milestone 4 (Facility Label): 3D Label updates live to consecutive powered days (2)")
	_assert(world.meta_progression.modification_cores == cores_0 + 1, "Milestone 4 (Stepped Yield): Day 2 powered facility rewards +1 modification core")

	# Expanded fortifications: searchlight SpotLight3D + house window boarding + multi-resource dismantle
	var bm4: BuildDefenseManager = world.build_manager
	world.loot_stash_manager.train_stash["scrap"] = 10
	world.loot_stash_manager.train_stash["parts"] = 10
	world.loot_stash_manager.train_stash["fuel"] = 10
	var sl_res: Dictionary = bm4.try_place_structure("searchlight", Vector3(4.0, 0.0, 6.0), 0.0, world.sector_generator.world_bounds, world.loot_stash_manager.backpack, world.loot_stash_manager.train_stash)
	_assert(bool(sl_res.get("ok", false)) and (sl_res["entry"]["node"] as Node3D).find_child("PoleSearchlightCone", true, false) is SpotLight3D, "Milestone 4 (Searchlight): Searchlight pole spawns working SpotLight3D cone")
	_assert(world.sector_generator.house_windows.size() >= 4, "Milestone 4 (Windows): CDDA houses expose barricadeable window sockets (got %d)" % world.sector_generator.house_windows.size())
	var wb_res: Dictionary = bm4.barricade_house_window(world.sector_generator.house_windows[0], world.sector_generator.world_bounds, world.loot_stash_manager.backpack, world.loot_stash_manager.train_stash)
	_assert(bool(wb_res.get("ok", false)) and bool(world.sector_generator.house_windows[0].get("boarded", false)), "Milestone 4 (Window Board): Boards up CDDA house window socket cleanly")
	var tur4_res: Dictionary = bm4.try_place_structure("turret", Vector3(-4.0, 0.0, 6.0), 0.0, world.sector_generator.world_bounds, world.loot_stash_manager.backpack, world.loot_stash_manager.train_stash)
	var scrap_before_dis: int = int(world.loot_stash_manager.backpack.get("scrap", 0))
	var parts_before_dis: int = int(world.loot_stash_manager.backpack.get("parts", 0))
	var dis_res: Dictionary = bm4.dismantle_structure(str(tur4_res["entry"]["id"]), world.loot_stash_manager.backpack)
	_assert(bool(dis_res.get("ok", false)) and int(world.loot_stash_manager.backpack.get("scrap", 0)) > scrap_before_dis and int(world.loot_stash_manager.backpack.get("parts", 0)) > parts_before_dis, "Milestone 4 (Relocate): Dismantling turret refunds both scrap & parts")

	# Departure threshold & cross-sector transition (preserves train & stash, clears ground structures)
	var dep_blocked: Dictionary = world.depart_to_next_sector()
	_assert(not bool(dep_blocked.get("ok", false)) and str(dep_blocked.get("reason", "")) == "blockade", "Milestone 4 (Departure Gate): Blocks departure before clearing Railway Blockade")
	em4.clear_rail_blockade()
	world.day_night_manager.force_phase(DayNightCycleManager.Phase.DAY, 1, 0.0)
	world.armored_train.apply_hull_damage(120.0)
	var hull_pre_depart: float = world.armored_train.hull_hp
	var stash_scrap_pre: int = int(world.loot_stash_manager.train_stash.get("scrap", 0))
	world.spawn_demo_fortifications_on_start = false
	var dep_ok: Dictionary = world.depart_to_next_sector()
	world.spawn_demo_fortifications_on_start = true
	_assert(bool(dep_ok.get("ok", false)) and em4.sector_index == 2 and not em4.rail_barricade_cleared, "Milestone 4 (Cross-Sector): Departs cleanly to Sector #2 with new blockade")
	_assert(is_equal_approx(world.armored_train.hull_hp, hull_pre_depart) and int(world.loot_stash_manager.train_stash.get("scrap", 0)) == stash_scrap_pre, "Milestone 4 (Cross-Sector): Preserves train hull HP & train stash across Sector transition")
	_assert(bm4.structures.is_empty(), "Milestone 4 (Cross-Sector): Abandons/clears previous Sector ground fortifications")

	# Restore clean Day 1 docked sector state for Phase 2-5 assertions
	world.meta_progression.modification_cores = cores_before
	world.generate_new_sector(424242, true)

	# --- Phase 2 Verification: Armored Train Base Landmark ---
	_assert(world.armored_train != null and world.armored_train is ArmoredTrainBase, "Phase 2: ArmoredTrainBase initialized")
	var train: ArmoredTrainBase = world.armored_train
	_assert(is_equal_approx(train.hull_hp, train.max_hull_hp) and train.max_hull_hp == 1000.0, "Phase 2: Armored Train starts at full Hull HP (1000)")
	var zones: Array[Dictionary] = train.get_interactive_zones()
	_assert(zones.size() == 2, "Phase 2: Armored Train exposes boarding_zone and train_stash zones")
	_assert(train.is_player_in_boarding_zone(train.get_boarding_world_pos()), "Phase 2: Boarding zone proximity check works")
	_assert(train.is_player_in_stash_zone(train.get_stash_world_pos()), "Phase 2: Train Stash zone proximity check works")

	train.apply_hull_damage(250.0)
	_assert(is_equal_approx(train.hull_hp, 750.0), "Phase 2: Armored Train Hull HP decreases on damage")
	train.repair_hull(100.0)
	_assert(is_equal_approx(train.hull_hp, 850.0), "Phase 2: Armored Train Hull HP recovers on repair")
	train.reset_hull()
	_assert(is_equal_approx(train.hull_hp, 1000.0), "Phase 2: Armored Train Hull HP resets cleanly")

	# --- Phase 2 Verification: Loot Collection, Backpack Cap, and Train Stash Deposit ---
	_assert(world.loot_stash_manager != null and world.loot_stash_manager is LootStashManager, "Phase 2: LootStashManager initialized")
	var lsm: LootStashManager = world.loot_stash_manager
	world.generate_new_sector(424242, true)
	var total_loot: int = lsm.get_total_loot_count()
	_assert(total_loot >= 8 and lsm.get_remaining_loot_count() == total_loot, "Phase 2: Loot points spawned and unlooted")
	_assert(lsm.get_backpack_used() == 0 and lsm.get_stash_total() == 0, "Phase 2: Backpack and Train Stash start empty")

	# Collect first loot point
	var first_loot_id: String = str(lsm.loot_nodes[0].get("id", ""))
	var first_res: Dictionary = lsm.collect_loot_point(first_loot_id)
	_assert(bool(first_res.get("ok", false)) and lsm.get_backpack_used() > 0, "Phase 2: Collecting loot adds Resources to Backpack")
	_assert(lsm.get_remaining_loot_count() == total_loot - 1, "Phase 2: Collected loot point is marked looted")

	# Fill backpack to capacity across remaining loot points to test cap & overflow handling
	var hit_cap_or_partial: bool = false
	for entry: Dictionary in lsm.loot_nodes:
		if bool(entry.get("looted", false)):
			continue
		var r: Dictionary = lsm.collect_loot_point(str(entry.get("id", "")))
		if str(r.get("reason", "")) in ["partial", "backpack_full"]:
			hit_cap_or_partial = true
			break
	_assert(lsm.get_backpack_used() <= lsm.backpack_capacity, "Phase 2: Backpack never exceeds capacity (%d/%d)" % [lsm.get_backpack_used(), lsm.backpack_capacity])
	_assert(hit_cap_or_partial or lsm.get_backpack_used() == lsm.backpack_capacity, "Phase 2: Backpack capacity limit triggers partial/full protection")

	# Deposit backpack into Armored Train Stash
	var carried_before: int = lsm.get_backpack_used()
	var dep: Dictionary = lsm.deposit_backpack_to_stash()
	_assert(int(dep.get("count", 0)) == carried_before and lsm.get_backpack_used() == 0 and lsm.get_stash_total() == carried_before, "Phase 2: Depositing moves all Backpack Resources safely into Train Stash")

	# --- Train System Verification (Uncharted Waters-inspired Consist, Refit & Crew) ---
	_assert(world.train_consist != null and world.train_consist is TrainConsistManager, "Train System: TrainConsistManager initialized")
	_assert(world.train_blueprint_ui != null and world.train_blueprint_ui is TrainBlueprintUi, "Train System: TrainBlueprintUi initialized")
	var tc: TrainConsistManager = world.train_consist
	var init_stats: Dictionary = tc.compute_stats()
	_assert(int(init_stats["carriage_count"]) == 3 and int(init_stats["max_carriages"]) == 3, "Train System: Default consist starts at 3/3 carriages")
	_assert(int(init_stats["power_used"]) == 5 and int(init_stats["power_capacity"]) == 6, "Train System: Default power budget is 5/6")
	_assert(int(init_stats["turret_count"]) == 1, "Train System: Default consist includes 1 Turret Car")

	# Inject test resources into stash for upgrade/expansion/refit verification
	var test_stash: Dictionary = {"scrap": 40, "parts": 40, "fuel": 30, "supplies": 30}

	# Cannot expand beyond Lv1 boiler traction limit (3)
	var exp_blocked: Dictionary = tc.expand_carriage(test_stash)
	_assert(not bool(exp_blocked.get("ok", true)) and str(exp_blocked.get("reason", "")) == "traction_limit", "Train System: Traction limit blocks expanding past Boiler Lv.1 cap")

	# Upgrade Locomotive Boiler & Armor & Headlamp
	var up_boiler: Dictionary = tc.upgrade_locomotive("boiler", test_stash)
	_assert(bool(up_boiler.get("ok", false)) and tc.get_max_carriages() == 4, "Train System: Boiler upgrade raises traction limit to 4 carriages")
	var up_armor: Dictionary = tc.upgrade_locomotive("armor", test_stash)
	_assert(bool(up_armor.get("ok", false)) and train.max_hull_hp > 1000.0, "Train System: Armor upgrade raises live 3D Train max_hull_hp")
	var up_lamp: Dictionary = tc.upgrade_locomotive("headlamp", test_stash)
	_assert(bool(up_lamp.get("ok", false)), "Train System: Headlamp upgrade succeeds")

	# Expand carriage -> 4th carriage (flatbed) reflected in live 3D train
	var exp_ok: Dictionary = tc.expand_carriage(test_stash)
	_assert(bool(exp_ok.get("ok", false)) and tc.carriages.size() == 4 and train.carriage_count == 4, "Train System: Carriage expansion couples 4th carriage to 3D train")

	# Refit new flatbed to Medbay, then to Generator (adding +4 power), then to Cargo (increasing backpack_capacity!)
	var refit_med: Dictionary = tc.refit_carriage(3, "medbay", test_stash)
	_assert(bool(refit_med.get("ok", false)) and float(tc.compute_stats()["heal_rate"]) > 0.0, "Train System: Refitting flatbed to Medbay activates heal rate")
	var refit_gen: Dictionary = tc.refit_carriage(3, "generator", test_stash)
	_assert(bool(refit_gen.get("ok", false)) and int(tc.compute_stats()["power_capacity"]) >= 13, "Train System: Refitting to Generator expands train power budget (+4)")
	var refit_cargo: Dictionary = tc.refit_carriage(3, "cargo", test_stash)
	_assert(bool(refit_cargo.get("ok", false)) and lsm.backpack_capacity == 16, "Train System: Adding 2nd Cargo Car live-updates LootStashManager backpack_capacity to 16")

	# Protect mandatory core carriages (cannot refit sole boarding car)
	var refit_core_blocked: Dictionary = tc.refit_carriage(0, "turret", test_stash)
	_assert(not bool(refit_core_blocked.get("ok", true)) and str(refit_core_blocked.get("reason", "")) == "core_required", "Train System: Mandatory sole Boarding Car is protected from removal/refit")

	# Reorder carriages -> Boarding Zone world X shifts dynamically on 3D train
	var boarding_x_before: float = train.get_boarding_world_pos().x
	var move_res: Dictionary = tc.move_carriage(0, 1)
	_assert(bool(move_res.get("ok", false)) and not is_equal_approx(train.get_boarding_world_pos().x, boarding_x_before), "Train System: Reordering carriages updates 3D Boarding Zone world position")

	# Crew assignment & Role Affinity (Quartermaster on Cargo boosts backpack further; Gunner on Turret boosts DPS!)
	var assign_loco: Dictionary = tc.assign_crew_to_locomotive("mech_hana")
	_assert(bool(assign_loco.get("ok", false)), "Train System: Assigning Mechanic to Locomotive succeeds")
	var assign_qm: Dictionary = tc.assign_crew_to_carriage(3, 0, "qm_goro")
	_assert(bool(assign_qm.get("ok", false)) and is_equal_approx(float(assign_qm.get("affinity", 0.0)), 1.5), "Train System: Quartermaster on Cargo Car achieves 150% role affinity")
	_assert(lsm.backpack_capacity == 19, "Train System: Quartermaster trait + Cargo Car raises live backpack_capacity to 19")
	var dps_before: float = float(tc.compute_stats()["turret_dps"])
	var assign_gunner: Dictionary = tc.assign_crew_to_carriage(2, 0, "gunner_kuro")
	_assert(bool(assign_gunner.get("ok", false)) and float(tc.compute_stats()["turret_dps"]) > dps_before, "Train System: Gunner assigned to Turret Car increases Turret DPS")

	# Blueprint UI toggle, granular cabin-cell & roof refit, and JSON serialization round-trip
	var roof_radar: Dictionary = tc.refit_carriage_roof(3, "radar", test_stash)
	_assert(bool(roof_radar.get("ok", false)) and float(tc.compute_stats()["radar_bonus"]) >= 35.0, "Train System: Mounting Roof Radar hardpoint on carriage #4 adds radar bonus")

	var cell_med: Dictionary = tc.refit_carriage_cell(3, 1, "medbay", test_stash)
	_assert(bool(cell_med.get("ok", false)) and float(tc.compute_stats()["heal_rate"]) > 0.0, "Train System: Refitting individual cabin cell #4-2 to Medbay activates heal rate")

	var assign_med: Dictionary = tc.assign_crew_to_cell(3, 1, "medic_saya")
	_assert(bool(assign_med.get("ok", false)) and is_equal_approx(float(assign_med.get("affinity", 0.0)), 1.5), "Train System: Placing Medic directly into cabin cell #4-2 achieves 150% affinity")

	world.train_blueprint_ui.set_open(true)
	_assert(world.train_blueprint_ui.is_open(), "Train System: TrainBlueprintUi cutaway workshop opens cleanly")
	world.train_blueprint_ui.set_open(false)
	_assert(not world.train_blueprint_ui.is_open(), "Train System: TrainBlueprintUi closes cleanly")

	var snapshot: Dictionary = tc.to_dict()
	var restored: TrainConsistManager = TrainConsistManager.new()
	_assert(restored.from_dict(snapshot) and restored.carriages.size() == tc.carriages.size() and int(restored.locomotive["boiler_level"]) == 2, "Train System: JSON consist serialization round-trip preserves state")

	# --- Phase 3 Verification: Combat, Zombies, Horde Escalation & Train Auto-Turrets ---
	_assert(world.horde_manager != null and world.horde_manager is HordeManager, "Phase 3: HordeManager initialized")
	var hm: HordeManager = world.horde_manager
	_assert(hm.get_active_zombie_count() >= 4, "Phase 3: Initial sector zombies spawned from object pool")

	# Player combat vitals: damage, heal, roll i-frames, ammo reload
	player.reset_combat_state()
	_assert(player.hp == player.max_hp and player.ammo_in_mag == player.mag_size, "Phase 3: Player starts at full HP and full magazine")
	_assert(player.take_damage(25.0) and is_equal_approx(player.hp, 75.0), "Phase 3: Player takes damage cleanly")
	player.heal(15.0)
	_assert(is_equal_approx(player.hp, 90.0), "Phase 3: Player heals cleanly")
	player.start_roll(Vector3.RIGHT)
	_assert(player.is_invulnerable() and not player.take_damage(50.0), "Phase 3: Tactical roll grants invulnerability i-frames")
	player.ammo_in_mag = 5
	_assert(player.start_reload() and player.is_reloading, "Phase 3: Manual magazine reload starts cleanly")

	# Raycast hitscan damage kills spawned zombie
	var target_z: ZombieUnit = hm.spawn_zombie("runner", Vector3(2.0, 0.0, 2.0))
	_assert(target_z != null and target_z.is_alive, "Phase 3: Runner zombie spawned from pool")
	var ray_res: Dictionary = hm.damage_zombies_along_ray(Vector3(2.0, 1.2, 6.0), Vector3(0.0, 0.0, -1.0), 12.0, 100.0)
	_assert(bool(ray_res.get("hit", false)) and bool(ray_res.get("killed", false)) and hm.total_kills >= 1, "Phase 3: Player hitscan ray kills zombie and increments kill counter")

	# Armored Train roof auto-turret shoots nearby zombies automatically
	var turret_z: ZombieUnit = hm.spawn_zombie("walker", train.get_boarding_world_pos() + Vector3(0.0, 0.0, 3.0))
	var z_hp_before: float = turret_z.hp
	hm.update_horde(0.4, player.global_position, true, train, tc.compute_stats(), 0.0)
	_assert(not turret_z.is_alive or turret_z.hp < z_hp_before, "Phase 3: Armored Train auto-turret detects and damages nearby zombie")

	# --- Phase 4 Verification: Main Missions, Survivor Rescue & Extraction Holdout ---
	_assert(world.mission_director != null and world.mission_director is MissionDirector, "Phase 4: MissionDirector initialized")
	var md: MissionDirector = world.mission_director
	var m_info: Dictionary = md.start_mission(424242, world.sector_generator.loot_spawn_points, ["gunner_kuro"], "relay_repair")
	_assert(str(m_info.get("mission_type", "")) == "relay_repair" and int(m_info.get("target_count", 0)) == 2, "Phase 4: Relay Repair mission spawns 2 objective nodes")
	_assert(bool(m_info.get("has_survivor", false)), "Phase 4: Trapped Survivor side-event spawns in Sector")

	for obj: Dictionary in md.objective_nodes:
		md.complete_objective(str(obj.get("id", "")))
	_assert(md.is_mission_complete, "Phase 4: Completing all objectives unlocks Extraction")

	var rescue_res: Dictionary = md.rescue_survivor()
	_assert(bool(rescue_res.get("ok", false)) and not md.rescued_survivor.is_empty(), "Phase 4: Rescuing trapped survivor records recruitable NPC Crew")

	_assert(md.start_extraction(10.0) and md.is_extracting, "Phase 4: Extraction holdout countdown starts at Boarding Zone")
	var extracted: bool = md.update_extraction(10.5, true)
	_assert(extracted and not md.is_extracting, "Phase 4: Surviving extraction timer inside Boarding Zone triggers Victory")

	# --- Phase 5 Verification: Meta Hub, Multi-Tier Unlock, Settlement & Persistent JSON Save ---
	_assert(world.meta_progression != null and world.meta_progression is MetaProgressionManager, "Phase 5: MetaProgressionManager initialized")
	_assert(world.run_flow_overlay != null and world.run_flow_overlay is RunFlowOverlay, "Phase 5: RunFlowOverlay initialized")

	var mp: MetaProgressionManager = MetaProgressionManager.new()
	var save_consist: TrainConsistManager = TrainConsistManager.new()
	var crew_before: int = save_consist.crew_roster.size()
	var win_settlement: Dictionary = {
		"victory": true,
		"kills": 14,
		"secured_resources": {"scrap": 10, "parts": 8, "fuel": 5, "supplies": 4},
		"lost_resources": {},
		"rescued_crew": md.rescued_survivor,
	}
	mp.apply_run_settlement(win_settlement, save_consist)
	_assert(mp.completed_runs == 1 and mp.total_kills == 14, "Phase 5: Victory settlement updates career runs and kills")
	_assert(int(mp.warehouse["scrap"]) == 18, "Phase 5: Victory settlement deposits secured loot into permanent Meta Warehouse")
	_assert(save_consist.crew_roster.size() == crew_before + 1, "Phase 5: Rescued survivor permanently joins TrainConsistManager crew roster")
	_assert(mp.is_tier_unlocked(2, save_consist), "Phase 5: Completing first extraction unlocks Sector Tier 2")

	var test_save_path: String = "user://test_mygame_save_verify.json"
	_assert(mp.save_to_file(save_consist, test_save_path), "Phase 5: Meta profile persists cleanly to JSON file")
	var mp_loaded: MetaProgressionManager = MetaProgressionManager.new()
	var consist_loaded: TrainConsistManager = TrainConsistManager.new()
	_assert(mp_loaded.load_from_file(consist_loaded, test_save_path), "Phase 5: Meta profile reloads cleanly from JSON file")
	_assert(mp_loaded.completed_runs == 1 and int(mp_loaded.warehouse["scrap"]) == 18 and consist_loaded.crew_roster.size() == crew_before + 1, "Phase 5: Reloaded save matches warehouse, career stats, and recruited crew")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))

	world.run_flow_overlay.show_hub(world.meta_progression, world.train_consist, world.current_seed)
	_assert(world.run_flow_overlay.is_open(), "Phase 5: RunFlowOverlay Hub opens cleanly")
	world.run_flow_overlay.close()
	_assert(not world.run_flow_overlay.is_open(), "Phase 5: RunFlowOverlay closes cleanly")

	# --- Helldivers-Style Stratagem Interaction Verification ---
	_assert(world.stratagem_ui != null and world.stratagem_ui is StratagemInputUi, "Stratagem: StratagemInputUi initialized")
	var sui: StratagemInputUi = world.stratagem_ui
	_assert(sui.get_length_for_kind("train_stash") == 3 and sui.get_length_for_kind("loot") == 4 and sui.get_length_for_kind("survivor_rescue") == 5 and sui.get_length_for_kind("mission_objective") == 6, "Stratagem: Sequence lengths scale by interaction stakes (3/4/5/6)")

	world.generate_new_sector(424242, true)
	var test_loot_entry: Dictionary = world.loot_stash_manager.loot_nodes[0]
	var test_target: Dictionary = {
		"id": str(test_loot_entry["id"]),
		"kind": "loot",
		"label": str(test_loot_entry["label"]),
		"pos": test_loot_entry["pos"],
	}
	var seq: Array[String] = sui.start_sequence(test_target, 0, ["up", "right", "down", "left"])
	_assert(sui.is_active and seq.size() == 4, "Stratagem: Starts active 4-step directional sequence for loot crate")
	_assert(sui.feed_direction("up") == "step" and sui.current_index == 1, "Stratagem: Correct arrow advances progress")
	_assert(sui.feed_direction("up") == "mistake" and sui.current_index == 0 and sui.mistakes == 1, "Stratagem: Wrong arrow flashes error and resets sequence progress to 0")

	_assert(sui.feed_direction("up") == "step", "Stratagem: Step 1/4 succeeds")
	_assert(sui.feed_direction("right") == "step", "Stratagem: Step 2/4 succeeds")
	_assert(sui.feed_direction("down") == "step", "Stratagem: Step 3/4 succeeds")
	_assert(sui.feed_direction("left") == "complete" and not sui.is_active, "Stratagem: Final arrow completes sequence immediately")
	_assert(world.loot_stash_manager.get_backpack_used() > 0, "Stratagem: Completing loot sequence collects crate Resources into Backpack")

	sui.start_sequence(test_target, 123)
	sui.cancel()
	_assert(not sui.is_active, "Stratagem: Emergency cancel closes active sequence cleanly")

	# --- HUD Overhaul, Survival Vitals, Quickbelt, Field Fortifications [B] & Zomboid Right-Click Menu ---
	_assert(world.build_manager != null and world.build_manager is BuildDefenseManager, "Fortifications: BuildDefenseManager initialized")
	_assert(world.build_menu_ui != null and world.build_menu_ui is BuildMenuUi, "Fortifications: BuildMenuUi initialized")
	_assert(world.context_menu_ui != null and world.context_menu_ui is ContextMenuUi, "Zomboid UI: ContextMenuUi initialized")
	_assert(world.quickbelt_slots.size() == 5, "HUD: Quickbelt initializes 5 consumable/tactical slots")

	# Survival vitals & Quickbelt usage
	player.reset_combat_state()
	player.take_damage(50.0)
	player.hunger = 50.0
	player.stamina = 40.0
	var use_band: Dictionary = world.use_quickbelt_slot(0)
	_assert(bool(use_band.get("ok", false)) and is_equal_approx(player.hp, 90.0), "Quickbelt: Slot 1 Bandage heals +40 HP")
	var use_rat: Dictionary = world.use_quickbelt_slot(1)
	_assert(bool(use_rat.get("ok", false)) and is_equal_approx(player.hunger, 95.0) and is_equal_approx(player.stamina, 70.0), "Quickbelt: Slot 2 Ration restores Hunger and Stamina")
	var use_stim: Dictionary = world.use_quickbelt_slot(2)
	_assert(bool(use_stim.get("ok", false)) and is_equal_approx(player.stamina, 100.0), "Quickbelt: Slot 3 Stimulant maximizes Stamina")

	# Field Fortification placement: Sandbag, Barricade, Landmine, Fixed Sentry Turret
	var bm: BuildDefenseManager = world.build_manager
	var build_bp: Dictionary = {"scrap": 20, "parts": 15, "fuel": 10, "supplies": 5}
	var build_st: Dictionary = {"scrap": 0, "parts": 0, "fuel": 0, "supplies": 0}
	var sb_res: Dictionary = bm.try_place_structure("sandbag", Vector3(-2.0, 0.0, 3.0), 0.0, world.sector_generator.world_bounds, build_bp, build_st)
	var bar_res: Dictionary = bm.try_place_structure("barricade", Vector3(2.0, 0.0, 3.0), 45.0, world.sector_generator.world_bounds, build_bp, build_st)
	var mine_res: Dictionary = bm.try_place_structure("landmine", Vector3(0.0, 0.0, 6.0), 0.0, world.sector_generator.world_bounds, build_bp, build_st)
	var tur_res: Dictionary = bm.try_place_structure("turret", Vector3(-4.0, 0.0, 5.0), 0.0, world.sector_generator.world_bounds, build_bp, build_st)
	_assert(bool(sb_res["ok"]) and bool(bar_res["ok"]) and bool(mine_res["ok"]) and bool(tur_res["ok"]), "Fortifications: Sandbag, Barricade, Landmine, and Fixed Turret place cleanly")

	# Landmine detonates on approaching zombie!
	var mine_z: ZombieUnit = hm.spawn_zombie("walker", Vector3(0.2, 0.0, 6.0))
	bm.update_defenses(0.3, hm)
	_assert(not mine_z.is_alive, "Fortifications: Proximity Landmine detonates and kills nearby zombie")

	# Fixed Sentry Turret shoots nearby zombie!
	var sentry_z: ZombieUnit = hm.spawn_zombie("brute", Vector3(-4.0, 0.0, 10.0))
	var brute_hp0: float = sentry_z.hp
	bm.update_defenses(0.35, hm)
	_assert(sentry_z.hp < brute_hp0, "Fortifications: Fixed Sentry Turret acquires and damages nearby zombie")

	# Project Zomboid Right-Click Context Menu opens with context-specific actions
	var ctx_train: Array[Dictionary] = world.open_context_menu_at(Vector2(400.0, 300.0), train.get_boarding_world_pos())
	_assert(world.context_menu_ui.is_open() and ctx_train.size() >= 3, "Zomboid UI: Right-clicking Armored Train opens context menu with train actions")
	world.context_menu_ui.close()
	_assert(not world.context_menu_ui.is_open(), "Zomboid UI: Context menu closes cleanly")

	# --- Dev Cheat Code Table & Default DEMO Fortifications ---
	_assert(world.dev_cheat_ui != null and world.dev_cheat_ui is DevCheatUi, "Dev Cheat: DevCheatUi initialized")
	world.dev_cheat_ui.set_open(true)
	_assert(world.dev_cheat_ui.is_open(), "Dev Cheat: Cheat Code Table opens cleanly")
	world.dev_cheat_ui.set_open(false)
	_assert(not world.dev_cheat_ui.is_open(), "Dev Cheat: Cheat Code Table closes cleanly")

	# Default DEMO start spawns all 4 fortification types without touching backpack/stash
	world.generate_new_sector(888888, true)
	var default_kinds: Array[String] = bm.get_alive_structure_kinds()
	_assert(default_kinds.has("sandbag") and default_kinds.has("barricade") and default_kinds.has("landmine") and default_kinds.has("turret"), "DEMO Default: Sector start spawns all 4 fortification types (sandbag/barricade/landmine/turret)")
	_assert(world.loot_stash_manager.get_backpack_used() == 0 and world.loot_stash_manager.get_stash_total() == 0, "DEMO Default: Preset fortifications do not consume player backpack or train stash")

	# Cheat 1: God Mode blocks player, train, and fortification damage
	world.set_cheat("god_mode", true)
	player.take_damage(80.0)
	_assert(is_equal_approx(player.hp, player.max_hp), "Dev Cheat (God Mode): Player ignores incoming damage")
	var train_hp_before: float = train.hull_hp
	world._on_zombie_attacked_train(250.0)
	_assert(is_equal_approx(train.hull_hp, train_hp_before), "Dev Cheat (God Mode): Armored Train ignores hull damage")
	world.set_cheat("god_mode", false)

	# Cheat 2: Infinite Resources enables free fortification placement & infinite quickbelt usage
	world.set_cheat("infinite_resources", true)
	var empty_bp: Dictionary = {"scrap": 0, "parts": 0, "fuel": 0, "supplies": 0}
	var empty_st: Dictionary = {"scrap": 0, "parts": 0, "fuel": 0, "supplies": 0}
	var free_turret: Dictionary = bm.try_place_structure("turret", Vector3(6.0, 0.0, 4.0), 0.0, world.sector_generator.world_bounds, empty_bp, empty_st)
	_assert(bool(free_turret.get("ok", false)), "Dev Cheat (Infinite Resources): Places expensive Sentry Turret with 0 resources")
	var ration_before: int = int(world.quickbelt_slots[1]["count"])
	var free_use: Dictionary = world.use_quickbelt_slot(1)
	_assert(bool(free_use.get("ok", false)) and int(world.quickbelt_slots[1]["count"]) == ration_before, "Dev Cheat (Infinite Resources): Quickbelt item use does not consume stock")
	world.set_cheat("infinite_resources", false)

	# Cheat 3: Pause Spawns freezes waves, ambushes, and periodic zombie spawning
	world.set_cheat("pause_spawns", true)
	hm.clear_all_zombies()
	var wave_spawned: int = hm.spawn_wave(6, true)
	var ambush_spawned: int = hm.spawn_local_ambush(Vector3.ZERO, 4)
	hm.update_horde(10.0, player.global_position, true, train, world.train_consist.compute_stats(), 0.0)
	_assert(wave_spawned == 0 and ambush_spawned == 0 and hm.get_active_zombie_count() == 0, "Dev Cheat (Pause Spawns): Freezes periodic, wave, and ambush zombie spawning")
	world.set_cheat("pause_spawns", false)

	# Cheat 4: Day/Night phase switching, Day +1, Blood Moon controls & Elite spawn
	world.dev_cheat_ui.phase_selected.emit(DayNightCycleManager.Phase.NIGHT)
	_assert(world.day_night_manager.current_phase == DayNightCycleManager.Phase.NIGHT and not world.day_night_manager.is_train_mobile(), "Dev Cheat (Day/Night): Switches directly to NIGHT")
	world.dev_cheat_ui.next_day_requested.emit()
	_assert(world.day_night_manager.current_day == 2 and hm.current_day == 2, "Dev Cheat (Day +1): Advances to Day 2 and updates HordeManager")
	world.dev_cheat_ui.blood_moon_delta_requested.emit(100.0)
	_assert(world.day_night_manager.blood_moon_value >= 100.0 and world.day_night_manager.is_blood_moon_warning(), "Dev Cheat (Blood Moon): Sets Blood Moon gauge to 100%% warning")
	world.dev_cheat_ui.blood_moon_delta_requested.emit(-100.0)
	_assert(is_equal_approx(world.day_night_manager.blood_moon_value, 0.0) and not world.day_night_manager.is_blood_moon_warning(), "Dev Cheat (Blood Moon): Resets Blood Moon gauge cleanly")
	world.dev_cheat_ui.phase_selected.emit(DayNightCycleManager.Phase.BLOOD_MOON)
	_assert(world.day_night_manager.is_blood_moon(), "Dev Cheat (Blood Moon): Triggers BLOOD_MOON phase directly")
	var cnt_before_elite: int = hm.get_active_zombie_count()
	world.dev_cheat_ui.spawn_blood_elite_requested.emit()
	_assert(hm.get_active_zombie_count() == cnt_before_elite + 1, "Dev Cheat (Blood Elite): Spawns blood_elite unit on demand")
	world.dev_cheat_ui.phase_selected.emit(DayNightCycleManager.Phase.DAY)

	# --- 4x Expanded Map, Enlarged Enterable Train, Working NPCs & Non-Player Stickman Verification ---
	var map_area: float = world.sector_generator.world_bounds.size.x * world.sector_generator.world_bounds.size.y
	_assert(map_area >= 5400.0, "4x Map: Playable sector area expanded to 4x (%.0f m^2 >= 5400 m^2)" % map_area)
	_assert(ArmoredTrainBase.CAR_PITCH >= 10.0 and ArmoredTrainBase.CAR_WIDTH >= 5.4 and train.get_train_half_length() >= 20.0, "Enlarged Train: Armored Train volume and dimensions scaled up")
	var train_inside_pt: Vector3 = train.position + Vector3(2.0, 0.0, 0.0)
	_assert(train.is_point_inside_train(train_inside_pt) and world.sector_generator.world_bounds.has_point(Vector2(train_inside_pt.x, train_inside_pt.z)), "Enterable Train: Interior coordinates lie inside walkable playable bounds")
	train.set_interior_cutaway(true)
	_assert(train.is_interior_cutaway_active(), "Enterable Train: Roof cutaway activates when entering train interior")
	train.set_interior_cutaway(false)
	_assert(train.get_working_npc_count() >= 4, "Train Crew NPCs: Visible working Stickman NPCs staffed inside train (%d active)" % train.get_working_npc_count())
	train.animate_train(1.5)
	var sample_z: ZombieUnit = hm.spawn_zombie("walker", Vector3(0.0, 0.0, 4.0))
	_assert(sample_z != null and sample_z.is_stickman, "Stickman Non-Players: Zombies render with articulated 3D Stickman rig")
	_assert(not world.mission_director.survivor_node.is_empty() and not (world.mission_director.survivor_node.get("stickman", {}) as Dictionary).is_empty(), "Stickman Non-Players: Trapped Survivor renders with articulated 3D Stickman rig")

	# --- 3-Weapon Loadout System Verification (M4A1-S / AK-47 / Desert Eagle) ---
	player.reset_combat_state()
	_assert(player.get_weapon_count() == 3, "3-Weapon Loadout: Player initializes with 3 weapons")
	_assert(player.get_active_weapon_id() == "m4a1s" and player.get_active_weapon_slot() == 0, "3-Weapon Loadout: Default active weapon is Slot 1 (M4A1-S)")
	var m4_model: Node3D = player.get_weapon_model("m4a1s")
	var ak_model: Node3D = player.get_weapon_model("ak47")
	var de_model: Node3D = player.get_weapon_model("deagle")
	_assert(m4_model != null and ak_model != null and de_model != null, "3-Weapon Loadout: All 3 weapon 3D models mounted on RightHandRifleMount")
	_assert(m4_model.visible and not ak_model.visible and not de_model.visible, "3-Weapon Loadout: Only M4A1-S 3D model is visible on Slot 1")

	# Spend ammo on M4A1-S and start reload to verify switch cancels reload & preserves independent mag ammo
	player.ammo_in_mag = 22
	player.start_reload()
	_assert(player.is_reloading, "3-Weapon Loadout: M4A1-S reload starts before weapon switch")

	# Switch to Slot 2 (AK-47)
	_assert(world.switch_player_weapon(1), "3-Weapon Loadout: Switch to Slot 2 (AK-47) succeeds")
	_assert(
		player.get_active_weapon_id() == "ak47"
		and not player.is_reloading
		and player.mag_size == 30
		and player.ammo_in_mag == 30
		and player.bullet_damage > 30.0
		and not player.toggle_silencer()
		and player.has_weapon_audio(),
		"3-Weapon Loadout: AK-47 updates stats/audio, cancels reload, and disables silencer toggle"
	)
	_assert(not m4_model.visible and ak_model.visible and not de_model.visible, "3-Weapon Loadout: Only AK-47 3D model is visible on Slot 2")
	player.ammo_in_mag = 19

	# Switch to Slot 3 (Desert Eagle)
	_assert(world.switch_player_weapon(2), "3-Weapon Loadout: Switch to Slot 3 (Desert Eagle) succeeds")
	_assert(
		player.get_active_weapon_id() == "deagle"
		and player.mag_size == 7
		and player.ammo_in_mag == 7
		and player.bullet_damage >= 60.0
		and not player.toggle_silencer()
		and player.has_weapon_audio(),
		"3-Weapon Loadout: Desert Eagle updates stats (7-rd mag, high damage), audio, and disables silencer toggle"
	)
	_assert(not m4_model.visible and not ak_model.visible and de_model.visible, "3-Weapon Loadout: Only Desert Eagle 3D model is visible on Slot 3")
	player.ammo_in_mag = 4

	# Switch back to Slot 1 (M4A1-S) and Slot 2 (AK-47) and confirm independent mag ammo persisted
	_assert(world.switch_player_weapon(0) and player.get_active_weapon_id() == "m4a1s" and player.ammo_in_mag == 22, "3-Weapon Loadout: Switching back to Slot 1 preserves M4A1-S ammo (22/30)")
	_assert(world.switch_player_weapon(1) and player.get_active_weapon_id() == "ak47" and player.ammo_in_mag == 19, "3-Weapon Loadout: Switching back to Slot 2 preserves AK-47 ammo (19/30)")
	_assert(world.switch_player_weapon(2) and player.get_active_weapon_id() == "deagle" and player.ammo_in_mag == 4, "3-Weapon Loadout: Switching back to Slot 3 preserves Desert Eagle ammo (4/7)")

	# --- Audio Isolation, Cursor Facing & Weapon Barrel Alignment Verification ---
	world.switch_player_weapon(1)
	var ak_bound: Dictionary = player.get_bound_fire_stream_paths()
	var ak_fire_paths: Array = ak_bound.get("fire", []) as Array
	var ak_dist_paths: Array = ak_bound.get("fire_distant", []) as Array
	var ak_unsil_paths: Array = ak_bound.get("fire_unsilenced", []) as Array
	var ak_unsil_dist_paths: Array = ak_bound.get("fire_unsilenced_distant", []) as Array
	var ak_audio_pure: bool = (
		ak_fire_paths.size() == 4
		and ak_dist_paths.size() == 1
		and ak_unsil_paths.is_empty()
		and ak_unsil_dist_paths.is_empty()
	)
	for p_item: Variant in ak_fire_paths:
		var ps: String = str(p_item)
		if not ps.contains("/ak47/ak47_0") or ps.contains("ak47-1") or ps.contains("m4a1") or ps.contains("deagle"):
			ak_audio_pure = false
	for p_item: Variant in ak_dist_paths:
		if not str(p_item).contains("/ak47/ak47_distant"):
			ak_audio_pure = false
	_assert(ak_audio_pure, "Audio Isolation: AK-47 binds strictly CS2 AK-47 fire/distant streams with zero M4A1/Deagle/legacy leak")

	# Moving without shooting still faces mouse cursor (aim_world_pos) instead of move_input
	player.reset_combat_state()
	var aim_base_pos: Vector3 = player.global_position
	var cursor_target: Vector3 = aim_base_pos + Vector3(0.0, 0.0, -10.0)
	var expected_yaw: float = atan2(-(cursor_target.x - aim_base_pos.x), -(cursor_target.z - aim_base_pos.z))
	player.update_character(0.1, Vector3(1.0, 0.0, 0.0), cursor_target, false, false, false, "")
	var yaw_err: float = absf(angle_difference(player.get_facing_yaw(), expected_yaw))
	_assert(
		yaw_err < 0.05 and player.current_action == "walk" and player.anim_player.current_animation == "strafe_right",
		"Cursor Facing: Walking without shooting faces mouse cursor (yaw_err=%.4f) and plays directional strafe_right clip" % yaw_err
	)

	# Weapon barrel (+Z) and MuzzlePoint align with horizontal aim vector for all 3 weapons
	var test_aim_dirs: Array[Vector3] = [
		Vector3(1.0, 0.0, -0.6).normalized(),
		Vector3(-0.8, 0.0, -0.5).normalized(),
		Vector3(0.4, 0.0, 0.9).normalized(),
	]
	for slot_idx: int in range(3):
		world.switch_player_weapon(slot_idx)
		var wid_check: String = player.get_active_weapon_id()
		var target_dir: Vector3 = test_aim_dirs[slot_idx]
		var aim_pt: Vector3 = player.global_position + target_dir * 12.0
		player.update_character(0.05, Vector3.ZERO, aim_pt, false, false, false, "")
		var barrel_z: Vector3 = player._weapon_mount_root.global_transform.basis.z
		var barrel_horiz: Vector3 = Vector3(barrel_z.x, 0.0, barrel_z.z).normalized()
		var barrel_dot: float = barrel_horiz.dot(target_dir)
		var grip_to_muzzle: Vector3 = player.muzzle_point.global_position - player._weapon_mount_root.global_position
		var muzzle_ahead_dist: float = Vector3(grip_to_muzzle.x, 0.0, grip_to_muzzle.z).dot(target_dir)
		var light_synced: bool = player.muzzle_light.global_position.distance_to(player.muzzle_point.global_position) < 0.01
		_assert(
			barrel_dot > 0.99 and muzzle_ahead_dist > 0.20 and light_synced,
			"Weapon Alignment (%s): barrel +Z dot=%.4f (>0.99), muzzle ahead=%.2fm, muzzle light synced" % [wid_check, barrel_dot, muzzle_ahead_dist]
		)

	# Restore Slot 3 (deagle, 4 ammo) so subsequent avatar switch assertions remain unchanged
	world.switch_player_weapon(2)
	player.ammo_in_mag = 4

	# --- Live Character Model Switching Verification ---
	for acfg: Dictionary in SquadConfig.get_avatar_catalog():
		var aid: String = str(acfg.get("id", ""))
		var switched: bool = world.switch_player_avatar(aid)
		var av_anims: PackedStringArray = player.get_available_animations()
		var av_m4: Node3D = player.get_weapon_model("m4a1s")
		var av_ak: Node3D = player.get_weapon_model("ak47")
		var av_de: Node3D = player.get_weapon_model("deagle")
		_assert(
			switched
			and player.get_active_avatar_id() == aid
			and player.skeleton != null
			and player.skeleton.name == "GeneralSkeleton"
			and av_anims.size() == 12
			and av_m4 != null and av_ak != null and av_de != null
			and player.get_active_weapon_slot() == 2
			and player.get_active_weapon_id() == "deagle"
			and player.ammo_in_mag == 4
			and not av_m4.visible and not av_ak.visible and av_de.visible,
			"Live Avatar Switch '%s': preserves GeneralSkeleton, all 12 Mixamo clips, 3-weapon mounts, and active slot/ammo" % aid
		)
	_assert(not player.switch_avatar_model("nonexistent_avatar_id"), "Live Avatar Switch rejects unknown avatar_id cleanly")
	_assert(world.switch_player_avatar(SquadConfig.DEFAULT_AVATAR_ID), "Live Avatar Switch returns cleanly to default avatar")

	world.queue_free()

	# --- Start Menu & Animation Tuning Sandbox Verification ---
	var menu_packed: PackedScene = load("res://scenes/StartMenu.tscn") as PackedScene
	_assert(menu_packed != null, "Start Menu: Load res://scenes/StartMenu.tscn")
	if menu_packed != null:
		var menu_node: Node = menu_packed.instantiate()
		root.add_child(menu_node)
		var menu: StartMenu = menu_node as StartMenu
		_assert(menu != null and menu.demo_button != null and menu.sandbox_button != null, "Start Menu: DEMO and Anim Sandbox entry buttons initialized")
		menu_node.queue_free()

	var sb_packed: PackedScene = load("res://scenes/AnimSandbox.tscn") as PackedScene
	_assert(sb_packed != null, "Anim Sandbox: Load res://scenes/AnimSandbox.tscn")
	if sb_packed != null:
		var sb_node: Node = sb_packed.instantiate()
		root.add_child(sb_node)
		var sb: AnimSandboxWorld = sb_node as AnimSandboxWorld
		_assert(sb != null and sb.player != null and sb.selected_clip == "roll", "Anim Sandbox: Initializes player and defaults to 'roll' clip")
		sb.set_playback_speed(0.25)
		_assert(is_equal_approx(sb.playback_speed, 0.25), "Anim Sandbox: Playback speed multiplier sets to 0.25x")
		sb.set_breakpoints(0.10, 0.65)
		_assert(is_equal_approx(sb.start_cut_sec, 0.10) and is_equal_approx(sb.end_cut_sec, 0.65), "Anim Sandbox: Start/End animation breakpoints apply cleanly")
		sb.set_mode(AnimSandboxWorld.SandboxMode.COMBO_WALK_ROLL_WALK)
		_assert(sb.mode == AnimSandboxWorld.SandboxMode.COMBO_WALK_ROLL_WALK, "Anim Sandbox: Switches to Walk->Roll->Walk combo loop mode")
		var summary_txt: String = sb.copy_tuning_summary()
		_assert(summary_txt.contains("Clip=roll") and summary_txt.contains("0.25x"), "Anim Sandbox: Tuning summary exports clip, speed, and breakpoint info")
		_assert(sb.switch_avatar("aria_idol") and sb.player.get_active_avatar_id() == "aria_idol" and sb.player.skeleton != null and sb.player.skeleton.name == "GeneralSkeleton", "Anim Sandbox: Switches character model to Aria Idol cleanly")
		_assert(sb.switch_avatar("nangong_yu") and sb.player.get_active_avatar_id() == "nangong_yu" and sb.player.skeleton != null and sb.player.skeleton.name == "GeneralSkeleton", "Anim Sandbox: Switches character model to Nangong Yu cleanly")
		sb_node.queue_free()
