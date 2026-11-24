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
	print("=== Retro Urban × SummerCuteness × Mixamo Godot 4 Verification ===")
	_test_assets_and_config()
	_test_main_scene_and_player()
	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _test_assets_and_config() -> void:
	var ids := SquadConfig.get_squad_ids()
	_assert(ids.size() == 1, "Solo player mode active (AI followers removed)")
	_assert(ResourceLoader.exists(SquadConfig.AVATAR_FBX_PATH), "SummerCuteness avatar FBX exists")
	for anim_key: String in ["idle", "walk", "shoot", "roll"]:
		var apath: String = str(SquadConfig.MIXAMO_ANIMS.get(anim_key, ""))
		_assert(ResourceLoader.exists(apath), "Mixamo animation FBX exists: %s" % anim_key)
	for piece: String in ["road-asphalt-center", "wall-a-garage", "wall-b-roof-slant", "truck-green", "scaffolding-structure"]:
		_assert(ResourceLoader.exists(SquadConfig.KENNEY_DIR + piece + ".glb"), "Kenney Retro Urban asset exists: %s" % piece)


func _test_main_scene_and_player() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	_assert(packed != null, "Load res://scenes/Main.tscn")
	if packed == null:
		return

	var main: Node = packed.instantiate()
	_assert(main is RuinsBaseWorld, "Main scene root is RuinsBaseWorld")
	root.add_child(main)

	var world := main as RuinsBaseWorld
	_assert(world.camera_rig != null and world.camera_rig is LolCameraController, "LolCameraController initialized")
	_assert(world.hud != null and world.hud is SquadHud, "SquadHud initialized")
	_assert(world.squad.size() == 1, "Only 1 solo player character spawned")

	var player := world.get_active_character()
	_assert(player != null and player.skeleton != null and player.skeleton.name == "GeneralSkeleton", "Player uses retargeted GeneralSkeleton")
	_assert(player.anim_player != null, "Mixamo AnimationPlayer attached")

	var anims := player.get_available_animations()
	var has_all := (
		anims.has("idle")
		and anims.has("walk")
		and anims.has("shoot")
		and anims.has("interact")
		and anims.has("roll")
	)
	_assert(has_all, "Player has all 5 retargeted clips: %s" % str(anims))

	for act in ["walk", "shoot", "interact", "roll"]:
		player.trigger_preview_action(act)
		_assert(player.current_action == act, "Player transitions cleanly to '%s'" % act)

	var init_lock: bool = world.camera_rig.camera_locked
	world.camera_rig.toggle_camera_lock()
	_assert(world.camera_rig.camera_locked != init_lock, "Camera lock toggles cleanly")

	var init_ortho: bool = world.camera_rig.is_orthographic
	world.camera_rig.toggle_projection_mode()
	_assert(world.camera_rig.is_orthographic != init_ortho, "Zomboid/RO camera projection toggles cleanly")

	world.queue_free()
