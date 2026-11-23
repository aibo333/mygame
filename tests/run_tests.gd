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
	print("=== 戰意守城原型 Godot 4 Headless Verification ===")
	_test_game_config()
	_test_main_scene_and_gameplay()
	print("=== Summary: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true


func _test_game_config() -> void:
	_assert(is_equal_approx(GameConfig.GATE_MAX_HP, 500.0), "GameConfig.GATE_MAX_HP == 500.0")
	_assert(is_equal_approx(GameConfig.GATE_X, -22.0), "GameConfig.GATE_X == -22.0")

	for rid in ["shieldmen", "pikemen", "archers"]:
		var r: Dictionary = GameConfig.get_regiment(rid)
		_assert(r.get("id", "") == rid and int(r.get("count", 0)) >= 8, "GameConfig.get_regiment('%s') valid" % rid)

	for eid in ["goblin_raider", "shield_orc", "skeleton_archer", "berserker", "enemy_commander"]:
		var e: Dictionary = GameConfig.get_enemy(eid)
		_assert(e.get("id", "") == eid and float(e.get("max_hp", 0.0)) > 0.0, "GameConfig.get_enemy('%s') valid" % eid)

	for w in [1, 2, 3]:
		var wcfg: Dictionary = GameConfig.get_wave(w)
		var spawns: Array = wcfg.get("spawns", [])
		_assert(int(wcfg.get("wave_number", 0)) == w and not spawns.is_empty(), "GameConfig.get_wave(%d) valid" % w)


func _test_main_scene_and_gameplay() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	_assert(packed != null, "Load res://scenes/Main.tscn")
	if packed == null:
		return

	var main: Node = packed.instantiate()
	_assert(main is BattlefieldManager, "Main scene root is BattlefieldManager")
	root.add_child(main)

	var bf := main as BattlefieldManager
	_assert(bf.hero != null and bf.hero is HeroController, "BattlefieldManager created HeroController")
	_assert(bf.regiment != null and bf.regiment is RegimentManager, "BattlefieldManager created RegimentManager")
	_assert(bf.hud != null and bf.hud is BattleHud, "BattlefieldManager created BattleHud")

	# Hero HUD state & camera toggle
	var h_state: Dictionary = bf.hero.get_hud_state()
	_assert(float(h_state.get("max_hp", 0.0)) > 0.0 and bool(h_state.get("alive", false)), "HeroController.get_hud_state() valid")
	var initial_tps: bool = bf.hero.is_tps_mode()
	bf.hero.toggle_camera_mode()
	_assert(bf.hero.is_tps_mode() != initial_tps, "HeroController.toggle_camera_mode() toggles mode")
	bf.hero.toggle_camera_mode()

	# Regiment switching, orders, formations, skill
	for rid in ["shieldmen", "pikemen", "archers"]:
		bf.regiment.set_regiment(rid)
		var rs: Dictionary = bf.regiment.get_hud_state()
		_assert(str(rs.get("type", "")) == rid and int(rs.get("alive_count", 0)) >= 8, "RegimentManager switched to '%s' with >=8 soldiers" % rid)

	bf.regiment.set_order("follow")
	_assert(bf.regiment.current_order == "follow", "Regiment order -> follow")
	bf.regiment.set_order("hold", Vector3(-6.0, 0.0, 2.0))
	_assert(bf.regiment.current_order == "hold", "Regiment order -> hold")
	bf.regiment.set_order("engage")
	_assert(bf.regiment.current_order == "engage", "Regiment order -> engage")

	bf.regiment.set_formation("compact")
	_assert(bf.regiment.current_formation == "compact", "Regiment formation -> compact")
	bf.regiment.set_formation("spread")
	_assert(bf.regiment.current_formation == "spread", "Regiment formation -> spread")

	var skill_ok: bool = bf.regiment.trigger_skill(Vector3(4.0, 0.0, 0.0))
	_assert(skill_ok and bf.regiment.skill_cd > 0.0, "RegimentManager.trigger_skill() executes and starts cooldown")

	# EnemyUnit setup, damage, death
	var enemy := EnemyUnit.new()
	bf.enemies_root.add_child(enemy)
	enemy.setup("goblin_raider", bf.vfx_root)
	_assert(enemy.is_in_group("enemies") and enemy.hp > 0.0 and not enemy.is_dead, "EnemyUnit goblin_raider setup valid")

	var died_flag: Array[bool] = [false]
	enemy.died.connect(func(_e: EnemyUnit): died_flag[0] = true)

	var killed_partial: bool = enemy.take_damage(10.0, Vector3(1.0, 0.0, 0.0), false)
	_assert(not killed_partial and enemy.hp < enemy.max_hp and not died_flag[0], "EnemyUnit partial damage reduces HP without killing")

	var killed_lethal: bool = enemy.take_damage(999.0, Vector3(2.0, 0.0, 0.0), true)
	_assert(killed_lethal and enemy.is_dead and died_flag[0], "EnemyUnit lethal damage kills and emits died")

	# Commander setup check
	var boss := EnemyUnit.new()
	bf.enemies_root.add_child(boss)
	boss.setup("enemy_commander", bf.vfx_root, "測試督軍", 1.0)
	_assert(boss.is_commander and boss.unit_scale >= 1.5 and boss.display_name == "測試督軍", "EnemyUnit commander setup valid")
	boss.queue_free()

	bf.queue_free()
