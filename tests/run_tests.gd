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
	print("=== 甲鐵廢墟戰線 Godot 4 Headless Verification ===")
	_test_assets_and_config()
	_test_main_scene_and_squad()
	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _test_assets_and_config() -> void:
	var ids := SquadConfig.get_squad_ids()
	_assert(ids.size() == 3, "SquadConfig defines 3 Blue Archive chibi characters")

	for cid in ids:
		var cfg: Dictionary = SquadConfig.get_character(cid)
		var mpath := str(cfg.get("model_path", ""))
		var fpath := str(cfg.get("face_path", ""))
		_assert(ResourceLoader.exists(mpath), "Character GLB exists: %s" % mpath)
		_assert(ResourceLoader.exists(fpath), "Character anime face texture exists: %s" % fpath)

	_assert(ResourceLoader.exists("res://assets/models/train/kabaneri_armored_train.glb"), "Kabaneri armored train GLB exists")
	for prop in ["building_ruin_a", "building_ruin_b", "overpass_pillar", "wrecked_car", "tactical_cover", "supply_crate", "streetlight_broken"]:
		var ppath := "res://assets/models/ruins/%s.glb" % prop
		_assert(ResourceLoader.exists(ppath), "Ruins kit GLB exists: %s" % prop)


func _test_main_scene_and_squad() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	_assert(packed != null, "Load res://scenes/Main.tscn")
	if packed == null:
		return

	var main: Node = packed.instantiate()
	_assert(main is RuinsBaseWorld, "Main scene root is RuinsBaseWorld")
	root.add_child(main)

	var world := main as RuinsBaseWorld
	_assert(world.camera_rig != null and world.camera_rig is LolCameraController, "LolCameraController initialized (TPS removed)")
	_assert(world.hud != null and world.hud is SquadHud, "SquadHud initialized")
	_assert(world.squad.size() == 3, "All 3 chibi squad characters spawned")

	# Verify all 3 characters have rigged AnimationPlayer with idle, walk, shoot, interact, roll
	for g in world.squad:
		var anims := g.get_available_animations()
		var has_all := (
			anims.has("idle")
			and anims.has("walk")
			and anims.has("shoot")
			and anims.has("interact")
			and anims.has("roll")
		)
		_assert(has_all, "%s has all 5 animations (idle/walk/shoot/interact/roll): %s" % [g.char_id, str(anims)])

	# Test switching between the 3 girls
	world.select_character(1)
	_assert(world.active_index == 1 and world.get_active_character().char_id == "chisa_smg", "Switch active girl to Chisa (SMG)")
	world.select_character(2)
	_assert(world.active_index == 2 and world.get_active_character().char_id == "lily_sg", "Switch active girl to Lily (SG)")

	# Test triggering the 4 core actions
	var active := world.get_active_character()
	for act in ["walk", "shoot", "interact", "roll"]:
		active.trigger_preview_action(act)
		_assert(active.current_action == act, "Character transitions cleanly to '%s'" % act)

	# Test LoL camera lock toggle & ground raycast
	var init_lock: bool = world.camera_rig.camera_locked
	world.camera_rig.toggle_camera_lock()
	_assert(world.camera_rig.camera_locked != init_lock, "LoL camera lock toggles cleanly")

	world.queue_free()
