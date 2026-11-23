class_name BattlefieldManager
extends Node3D

var current_wave: int = 1
var current_regiment: String = "shieldmen"
var gate_hp: float = GameConfig.GATE_MAX_HP
var battle_state: String = "playing" # "playing", "victory", "defeat"

var hero: HeroController = null
var regiment: RegimentManager = null
var hud: BattleHud = null
var vfx_root: Node3D = null
var enemies_root: Node3D = null

var _aim_ring: Node3D = null
var _gate_mesh: MeshInstance3D = null
var _gate_mat: StandardMaterial3D = null
var _gate_flash_timer: float = 0.0
var _torch_lights: Array[OmniLight3D] = []
var _torch_base_energies: Array[float] = []
var _time_elapsed: float = 0.0

var _wave_cfg: Dictionary = {}
var _wave_elapsed: float = 0.0
var _pending_spawns: Array[Dictionary] = []
var _alive_enemies: Array[EnemyUnit] = []


func _ready() -> void:
	_build_environment_and_lights()
	_build_world_geometry()
	_build_aim_crosshair()
	_setup_actors_and_ui()
	start_wave(1)


func _build_environment_and_lights() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.05, 0.12)
	sky_mat.sky_horizon_color = Color(0.1, 0.14, 0.24)
	sky_mat.ground_bottom_color = Color(0.03, 0.04, 0.06)
	sky_mat.ground_horizon_color = Color(0.07, 0.1, 0.16)
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.26, 0.34, 0.5)
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color(0.09, 0.13, 0.22)
	env.fog_density = 0.0075

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Moon directional light with shadows
	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.light_color = Color(0.76, 0.85, 1.0)
	moon.light_energy = 1.2
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	add_child(moon)


func _make_mat(color: Color, roughness: float = 0.85, metallic: float = 0.05) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _add_static_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
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
	return mi


func _add_torch(parent: Node3D, pos: Vector3, energy: float = 4.2, radius: float = 15.0) -> void:
	var flame := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	flame.mesh = sphere
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.65, 0.2)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.55, 0.14)
	fmat.emission_energy_multiplier = 2.8
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = fmat
	flame.position = pos
	parent.add_child(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.26)
	light.light_energy = energy
	light.omni_range = radius
	light.position = pos + Vector3(0.0, 0.25, 0.0)
	parent.add_child(light)
	_torch_lights.append(light)
	_torch_base_energies.append(energy)


func _build_world_geometry() -> void:
	var world := Node3D.new()
	world.name = "WorldGeometry"
	add_child(world)

	var grass_mat := _make_mat(Color(0.14, 0.2, 0.15), 0.95, 0.0)
	var road_mat := _make_mat(Color(0.25, 0.24, 0.23), 0.9, 0.05)
	var stone_mat := _make_mat(Color(0.32, 0.34, 0.38), 0.88, 0.08)
	var stone_dark := _make_mat(Color(0.22, 0.24, 0.28), 0.9, 0.1)
	var wood_mat := _make_mat(Color(0.36, 0.22, 0.12), 0.85, 0.05)
	_gate_mat = _make_mat(Color(0.42, 0.25, 0.13), 0.8, 0.12)

	# Ground plain (StaticBody3D on layer 1)
	_add_static_box(world, "GroundPlain", Vector3(84.0, 1.0, 56.0), Vector3(0.0, -0.5, 0.0), grass_mat)

	# Cobblestone siege road (slightly raised visual strip)
	var road := MeshInstance3D.new()
	var road_box := BoxMesh.new()
	road_box.size = Vector3(54.0, 0.04, 7.6)
	road.mesh = road_box
	road.material_override = road_mat
	road.position = Vector3(2.0, 0.02, 0.0)
	world.add_child(road)

	# Castle wall at x = GameConfig.GATE_X (-22.0) — solid layer 1 for SpringArm3D!
	var gx: float = GameConfig.GATE_X
	# North & South curtain wall segments
	_add_static_box(world, "CastleWallNorth", Vector3(3.2, 9.0, 13.0), Vector3(gx - 0.8, 4.5, -10.5), stone_mat)
	_add_static_box(world, "CastleWallSouth", Vector3(3.2, 9.0, 13.0), Vector3(gx - 0.8, 4.5, 10.5), stone_mat)
	# Overhead gate arch lintel
	_add_static_box(world, "GateArch", Vector3(3.4, 3.2, 8.2), Vector3(gx - 0.8, 7.6, 0.0), stone_dark)

	# Wooden double gate
	_gate_mesh = _add_static_box(world, "CastleGate", Vector3(1.1, 6.0, 7.2), Vector3(gx - 0.2, 3.0, 0.0), _gate_mat)
	# Iron reinforcement bands on gate
	var iron_mat := _make_mat(Color(0.2, 0.22, 0.26), 0.45, 0.72)
	for band_y in [1.4, 3.2, 4.8]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.24, 0.26, 7.1)
		band.mesh = bm
		band.material_override = iron_mat
		band.position = Vector3(gx - 0.2, band_y, 0.0)
		world.add_child(band)

	# Twin watchtowers flanking gate
	for side_z in [-5.6, 5.6]:
		var suffix: String = "North" if side_z < 0.0 else "South"
		_add_static_box(world, "Watchtower" + suffix, Vector3(4.6, 13.5, 4.6), Vector3(gx - 0.4, 6.75, side_z), stone_dark)
		# Tower cap & brazier torch
		_add_static_box(world, "WatchtowerCap" + suffix, Vector3(5.2, 0.9, 5.2), Vector3(gx - 0.4, 13.8, side_z), stone_mat)
		_add_torch(world, Vector3(gx + 0.8, 14.6, side_z), 5.0, 22.0)
		# Gate pillar torch at ground/mid height
		_add_torch(world, Vector3(gx + 1.3, 4.2, side_z * 0.72), 4.0, 14.0)

	# Crenelations (battlements) along top of castle wall
	for i in range(-15, 16, 2):
		if absf(float(i)) < 7.5:
			continue
		_add_static_box(world, "Battlement_%d" % i, Vector3(1.0, 1.3, 1.1), Vector3(gx + 0.4, 9.65, float(i)), stone_mat)

	# Arena north & south boundary barricades (low stone/wood walls on layer 1)
	_add_static_box(world, "NorthBoundary", Vector3(52.0, 2.2, 1.2), Vector3(4.0, 1.1, -GameConfig.ARENA_HALF_Z - 1.2), stone_dark)
	_add_static_box(world, "SouthBoundary", Vector3(52.0, 2.2, 1.2), Vector3(4.0, 1.1, GameConfig.ARENA_HALF_Z + 1.2), stone_dark)

	# Decorative wooden siege stakes & flank rocks
	var stake_positions: Array[Vector3] = [
		Vector3(-12.0, 0.0, -9.5), Vector3(-12.0, 0.0, 9.5),
		Vector3(-2.0, 0.0, -11.5), Vector3(-2.0, 0.0, 11.5),
		Vector3(10.0, 0.0, -10.5), Vector3(10.0, 0.0, 10.5),
	]
	for sp in stake_positions:
		_add_static_box(world, "Barricade", Vector3(1.6, 1.1, 2.4), sp + Vector3(0.0, 0.55, 0.0), wood_mat, Vector3(0.0, 14.0, 0.0))

	# Distant warm campfires near enemy spawn side for atmosphere
	_add_torch(world, Vector3(24.5, 1.0, -10.0), 3.6, 16.0)
	_add_torch(world, Vector3(24.5, 1.0, 10.0), 3.6, 16.0)


func _build_aim_crosshair() -> void:
	_aim_ring = Node3D.new()
	_aim_ring.name = "AimGroundRing"
	add_child(_aim_ring)

	var ring_mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.52
	torus.outer_radius = 0.65
	torus.rings = 20
	ring_mi.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.92, 1.0, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mi.material_override = mat
	_aim_ring.add_child(ring_mi)

	var dot_mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = 0.04
	dot_mi.mesh = cyl
	dot_mi.material_override = mat
	_aim_ring.add_child(dot_mi)


func _setup_actors_and_ui() -> void:
	vfx_root = Node3D.new()
	vfx_root.name = "VfxRoot"
	add_child(vfx_root)

	enemies_root = Node3D.new()
	enemies_root.name = "EnemiesRoot"
	add_child(enemies_root)

	hero = HeroController.new()
	hero.name = "HeroController"
	add_child(hero)
	hero.set_vfx_parent(vfx_root)
	hero.warcry_triggered.connect(_on_hero_warcry)
	hero.log_event.connect(_on_log_event)
	hero.camera_mode_changed.connect(_on_camera_mode_changed)

	regiment = RegimentManager.new()
	regiment.name = "RegimentManager"
	add_child(regiment)
	regiment.setup(hero, vfx_root, current_regiment)
	regiment.log_event.connect(_on_log_event)

	hud = BattleHud.new()
	hud.name = "BattleHud"
	add_child(hud)
	hud.regiment_selected.connect(_on_select_regiment)
	hud.wave_selected.connect(start_wave)
	hud.camera_toggle_requested.connect(_on_toggle_camera_requested)
	hud.restart_requested.connect(func(): start_wave(current_wave))
	hud.next_wave_requested.connect(func(): start_wave(mini(current_wave + 1, 3)))
	hud.order_requested.connect(_on_order_requested)
	hud.formation_requested.connect(func(f: String): regiment.set_formation(f))
	hud.regiment_skill_requested.connect(func(): _trigger_regiment_skill())


func start_wave(wave_number: int) -> void:
	current_wave = clampi(wave_number, 1, 3)
	_wave_cfg = GameConfig.get_wave(current_wave)
	gate_hp = GameConfig.GATE_MAX_HP
	battle_state = "playing"
	_wave_elapsed = 0.0

	# Clear existing enemies
	for e in _alive_enemies:
		if is_instance_valid(e):
			e.queue_free()
	_alive_enemies.clear()
	for child in enemies_root.get_children():
		child.queue_free()

	# Copy wave spawn queue
	_pending_spawns.clear()
	var spawns_arr: Array = _wave_cfg.get("spawns", [])
	for entry in spawns_arr:
		_pending_spawns.append(entry.duplicate(true))

	var hero_spawn := Vector3(GameConfig.GATE_X + 6.5, 0.0, 0.0)
	hero.reset_for_wave(hero_spawn)
	regiment.reset_for_wave(hero_spawn + Vector3(-1.5, 0.0, 0.0))
	hud.hide_result_modal()

	_on_log_event("開始 %s — %s" % [str(_wave_cfg.get("name", "")), str(_wave_cfg.get("description", ""))])


func _unhandled_input(event: InputEvent) -> void:
	if battle_state != "playing":
		return

	if event.is_action_pressed("order_follow"):
		_on_order_requested("follow")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("order_hold"):
		_on_order_requested("hold")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("order_engage"):
		_on_order_requested("engage")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("formation_compact"):
		regiment.set_formation("compact")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("formation_spread"):
		regiment.set_formation("spread")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("regiment_skill"):
		_trigger_regiment_skill()
		get_viewport().set_input_as_handled()


func _on_select_regiment(regiment_type: String) -> void:
	current_regiment = regiment_type
	regiment.set_regiment(regiment_type)


func _on_toggle_camera_requested() -> void:
	if hero != null:
		hero.toggle_camera_mode()


func _on_camera_mode_changed(is_tps: bool) -> void:
	_on_log_event("視角切換：%s" % ("肩後 TPS（點擊畫面鎖定準心）" if is_tps else "3D 戰術俯視"))


func _on_hero_warcry(origin: Vector3, radius: float) -> void:
	if regiment != null:
		regiment.apply_warcry(origin, radius, HeroController.WARCRY_DURATION)


func _on_order_requested(order: String) -> void:
	if regiment == null or hero == null:
		return
	var aim_pt: Vector3 = hero.get_aim_ground_point()
	regiment.set_order(order, aim_pt)


func _trigger_regiment_skill() -> void:
	if regiment == null or hero == null:
		return
	var aim_pt: Vector3 = hero.get_aim_ground_point()
	regiment.trigger_skill(aim_pt)


func _on_log_event(message: String) -> void:
	if hud != null:
		hud.push_log(message)


func _process(delta: float) -> void:
	_time_elapsed += delta
	_animate_torches()
	_update_gate_flash(delta)

	if hero != null and _aim_ring != null:
		var aim_pt: Vector3 = hero.get_aim_ground_point()
		_aim_ring.global_position = Vector3(aim_pt.x, 0.06, aim_pt.z)
		_aim_ring.rotation.y += delta * 1.4

	if battle_state == "playing":
		_wave_elapsed += delta
		_process_wave_spawns()
		_check_battle_outcome()

	if hud != null and hero != null and regiment != null:
		var remaining: int = _count_remaining_enemies()
		hud.update_hud(
			gate_hp,
			GameConfig.GATE_MAX_HP,
			current_wave,
			str(_wave_cfg.get("name", "第 %d 波" % current_wave)),
			remaining,
			hero.get_hud_state(),
			regiment.get_hud_state()
		)


func _animate_torches() -> void:
	for i in range(_torch_lights.size()):
		var l: OmniLight3D = _torch_lights[i]
		if is_instance_valid(l):
			l.light_energy = _torch_base_energies[i] + sin(_time_elapsed * 9.0 + float(i) * 1.7) * 0.45


func _update_gate_flash(delta: float) -> void:
	if _gate_flash_timer > 0.0:
		_gate_flash_timer -= delta
		if _gate_flash_timer <= 0.0 and _gate_mat != null:
			_gate_mat.emission_enabled = false


func _process_wave_spawns() -> void:
	var i: int = _pending_spawns.size() - 1
	while i >= 0:
		var entry: Dictionary = _pending_spawns[i]
		if _wave_elapsed >= float(entry.get("spawn_time", 0.0)):
			_spawn_enemy_group(entry)
			_pending_spawns.remove_at(i)
		i -= 1


func _spawn_enemy_group(entry: Dictionary) -> void:
	var etype: String = str(entry.get("type", "goblin_raider"))
	var count: int = int(entry.get("count", 1))
	var custom_name: String = str(entry.get("custom_name", ""))
	var hp_mult: float = float(entry.get("hp_mult", 1.0))

	for k in range(count):
		var enemy := EnemyUnit.new()
		enemy.name = "%s_%d_%d" % [etype, current_wave, _alive_enemies.size()]
		enemies_root.add_child(enemy)
		enemy.setup(etype, vfx_root, custom_name, hp_mult)

		var spawn_x: float = randf_range(GameConfig.ARENA_MAX_X - 4.0, GameConfig.ARENA_MAX_X - 1.2)
		var spawn_z: float = randf_range(-GameConfig.ARENA_HALF_Z + 2.5, GameConfig.ARENA_HALF_Z - 2.5)
		if etype == "enemy_commander":
			spawn_z = randf_range(-3.0, 3.0)
			_on_log_event("警告！敵方督軍【%s】已率軍現身戰場！" % enemy.display_name)
		enemy.global_position = Vector3(spawn_x, 0.0, spawn_z)

		enemy.died.connect(_on_enemy_died)
		enemy.gate_damaged.connect(_on_gate_damaged)
		_alive_enemies.append(enemy)


func _on_enemy_died(enemy: EnemyUnit) -> void:
	_alive_enemies.erase(enemy)
	if enemy.is_commander:
		_on_log_event("敵方督軍【%s】已被斬落馬下！" % enemy.display_name)


func _on_gate_damaged(amount: float, hit_pos: Vector3) -> void:
	if battle_state != "playing":
		return
	gate_hp = maxf(0.0, gate_hp - amount)
	_gate_flash_timer = 0.18
	if _gate_mat != null:
		_gate_mat.emission_enabled = true
		_gate_mat.emission = Color(1.0, 0.25, 0.12)
		_gate_mat.emission_energy_multiplier = 1.4
	if vfx_root != null:
		VfxFactory.spawn_floating_text(vfx_root, hit_pos + Vector3(0.0, 1.2, 0.0), "城門 -%d" % int(round(amount)), Color(1.0, 0.42, 0.2), 26)
	if gate_hp <= 0.0:
		_trigger_defeat()


func _count_remaining_enemies() -> int:
	var alive_count: int = 0
	for e in _alive_enemies:
		if is_instance_valid(e) and not e.is_dead:
			alive_count += 1
	var pending_count: int = 0
	for p in _pending_spawns:
		pending_count += int(p.get("count", 0))
	return alive_count + pending_count


func _check_battle_outcome() -> void:
	if gate_hp <= 0.0:
		_trigger_defeat()
		return
	if _pending_spawns.is_empty() and _count_remaining_enemies() == 0:
		_trigger_victory()


func _trigger_victory() -> void:
	battle_state = "victory"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var can_next: bool = current_wave < 3
	var title: String = "守城大捷！" if not can_next else "波次防守成功！"
	var body: String = "城門剩餘血量：%d / %d\n武將擊殺：%d ｜ 總輸出：%d" % [
		int(ceil(gate_hp)),
		int(round(GameConfig.GATE_MAX_HP)),
		hero.kills,
		int(round(hero.damage_dealt)),
	]
	hud.show_result_modal(true, title, body, can_next)
	_on_log_event("守城成功！已完成 %s" % str(_wave_cfg.get("name", "")))


func _trigger_defeat() -> void:
	battle_state = "defeat"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var body: String = "城門已被敵軍攻破！\n調整兵團陣型與戰技時機，再次迎戰吧。"
	hud.show_result_modal(false, "城門失守", body, false)
	_on_log_event("城門失守！戰役失敗。")
