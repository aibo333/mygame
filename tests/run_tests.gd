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
	for anim_key: String in ["idle", "walk", "shoot", "roll"]:
		var apath: String = str(SquadConfig.MIXAMO_ANIMS.get(anim_key, ""))
		_assert(ResourceLoader.exists(apath), "Mixamo animation FBX exists: %s" % anim_key)
	for piece: String in ["road-asphalt-center", "wall-a-garage", "wall-b-roof-slant", "truck-green", "scaffolding-structure"]:
		_assert(ResourceLoader.exists(SquadConfig.KENNEY_DIR + piece + ".glb"), "Kenney Retro Urban asset exists: %s" % piece)


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

	var anims: PackedStringArray = player.get_available_animations()
	var has_all: bool = (
		anims.has("idle")
		and anims.has("walk")
		and anims.has("shoot")
		and anims.has("interact")
		and anims.has("roll")
	)
	_assert(has_all, "Player has all 5 retargeted clips: %s" % str(anims))

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

	world.queue_free()
