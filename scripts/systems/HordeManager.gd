class_name HordeManager
extends Node3D

signal wave_stage_changed(stage_index: int, stage_name: String)
signal zombie_killed(archetype: String, total_kills: int, death_pos: Vector3)
signal elite_loot_dropped(archetype: String, death_pos: Vector3, bonus_resources: Dictionary, mod_cores: int)
signal run_timer_updated(remaining_sec: float, total_sec: float, stage_name: String)
signal overtime_triggered()

const POOL_SIZE: int = 36
const TURRET_RANGE: float = 30.0

var total_run_duration: float = 360.0
var time_remaining: float = 360.0
var difficulty_mult: float = 1.0
var current_stage: int = 1
var current_stage_name: String = "階段 1：靜默進站"
var current_day: int = 1
var current_cycle_phase: int = DayNightCycleManager.Phase.DAY
var is_extraction_holdout: bool = false
var is_overtime: bool = false
var is_active: bool = true
var spawning_paused: bool = false
var total_kills: int = 0

var _pool: Array[ZombieUnit] = []
var _spawn_timer: float = 2.0
var _wave_timer: float = 28.0
var _turret_fire_cd: float = 0.0
var _vfx_root: Node3D = null
var _world_bounds: Rect2 = Rect2(-23.5, -12.2, 45.0, 30.2)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(p_vfx_root: Node3D) -> void:
	_vfx_root = p_vfx_root
	if not _pool.is_empty():
		return
	for i in range(POOL_SIZE):
		var z: ZombieUnit = ZombieUnit.new()
		z.name = "ZombiePool_%02d" % i
		add_child(z)
		z.died.connect(_on_zombie_died)
		_pool.append(z)


func start_run(seed_value: int, bounds: Rect2, duration_sec: float = 360.0, p_difficulty_mult: float = 1.0) -> void:
	clear_all_zombies()
	_world_bounds = bounds
	total_run_duration = maxf(60.0, duration_sec)
	time_remaining = total_run_duration
	difficulty_mult = maxf(0.5, p_difficulty_mult)
	current_stage = 1
	current_stage_name = "階段 1：靜默進站"
	is_extraction_holdout = false
	is_overtime = false
	is_active = true
	total_kills = 0
	current_day = 1
	current_cycle_phase = DayNightCycleManager.Phase.DAY
	_spawn_timer = 1.5
	_wave_timer = 26.0
	_turret_fire_cd = 0.0
	_rng.seed = seed_value ^ 0x2F91B3

	# Initial scattered roamers in the southern & eastern urban blocks
	spawn_wave(4, false)
	wave_stage_changed.emit(current_stage, current_stage_name)
	run_timer_updated.emit(time_remaining, total_run_duration, current_stage_name)


func get_day_hp_multiplier() -> float:
	var day_bonus: float = 1.0 + float(maxi(0, current_day - 1)) * 0.28
	var bm_bonus: float = 1.35 if current_cycle_phase == DayNightCycleManager.Phase.BLOOD_MOON else 1.0
	return difficulty_mult * day_bonus * bm_bonus * (1.25 if is_overtime else 1.0)


func get_day_speed_multiplier() -> float:
	var day_spd: float = float(maxi(0, current_day - 1)) * 0.08
	var bm_spd: float = 0.16 if current_cycle_phase == DayNightCycleManager.Phase.BLOOD_MOON else 0.0
	return 1.0 + (difficulty_mult - 1.0) * 0.25 + day_spd + bm_spd + (0.18 if is_overtime else 0.0)


func set_day_night_state(phase: int, day_num: int) -> void:
	var prev_phase: int = current_cycle_phase
	current_cycle_phase = phase
	current_day = maxi(1, day_num)
	if prev_phase == phase:
		return
	if phase == DayNightCycleManager.Phase.NIGHT or phase == DayNightCycleManager.Phase.BLOOD_MOON:
		for z: ZombieUnit in _pool:
			if is_instance_valid(z) and z.is_alive:
				z.set_siege_mode()
		var siege_count: int = 5 + current_day * 2
		if phase == DayNightCycleManager.Phase.BLOOD_MOON:
			siege_count += 4
			spawn_zombie("blood_elite", _pick_multi_directional_spawn_pos())
		spawn_wave(mini(siege_count, maxi(0, POOL_SIZE - get_active_zombie_count())), true)


func spawn_daytime_roamers(civil_houses: Array, count: int = 8) -> int:
	if spawning_paused:
		return 0
	var spawned: int = 0
	# Spawn indoor roamers inside CDDA civil houses first
	for i: int in range(mini(civil_houses.size(), maxi(2, count / 2))):
		var h: Dictionary = civil_houses[i] as Dictionary
		var fp: Rect2 = h.get("footprint", Rect2()) as Rect2
		var sockets: Array = h.get("loot_sockets", []) as Array
		var rpos: Vector3 = Vector3(fp.position.x + fp.size.x * 0.5, 0.0, fp.position.y + fp.size.y * 0.5)
		if not sockets.is_empty():
			var s_entry: Dictionary = sockets[0] as Dictionary
			var sp_raw: Variant = s_entry.get("pos", rpos)
			if sp_raw is Vector3:
				rpos = sp_raw as Vector3
		var rz: ZombieUnit = spawn_zombie("walker" if i % 2 == 0 else "runner", rpos)
		if rz != null:
			rz.setup_roamer(rpos, true)
			spawned += 1

	# Fill remaining count as outdoor street roamers
	while spawned < count and get_active_zombie_count() < POOL_SIZE:
		var spos: Vector3 = _pick_multi_directional_spawn_pos()
		var oz: ZombieUnit = spawn_zombie("walker", spos)
		if oz == null:
			break
		oz.setup_roamer(spos, false)
		spawned += 1
	return spawned


func emit_gunshot_noise(noise_pos: Vector3, noise_radius: float) -> int:
	var alerted: int = 0
	for z: ZombieUnit in _pool:
		if is_instance_valid(z) and z.is_alive:
			if z.hear_noise(noise_pos, noise_radius):
				alerted += 1
	return alerted


func clear_all_zombies() -> void:
	for z: ZombieUnit in _pool:
		if is_instance_valid(z):
			z.deactivate()


func set_extraction_holdout(enabled: bool) -> void:
	is_extraction_holdout = enabled
	if enabled:
		current_stage = 4
		current_stage_name = "最終階段：撤離發車守點"
		wave_stage_changed.emit(current_stage, current_stage_name)
		spawn_wave(int(round(5.0 * difficulty_mult)), true)


func get_active_zombie_count() -> int:
	var cnt: int = 0
	for z: ZombieUnit in _pool:
		if is_instance_valid(z) and z.is_alive:
			cnt += 1
	return cnt


func get_active_zombies() -> Array[ZombieUnit]:
	var list: Array[ZombieUnit] = []
	for z: ZombieUnit in _pool:
		if is_instance_valid(z) and z.is_alive:
			list.append(z)
	return list


func connect_attack_handlers(on_player_hit: Callable, on_train_hit: Callable) -> void:
	for z: ZombieUnit in _pool:
		if not z.attacked_player.is_connected(on_player_hit):
			z.attacked_player.connect(on_player_hit)
		if not z.attacked_train.is_connected(on_train_hit):
			z.attacked_train.connect(on_train_hit)


func spawn_zombie(archetype: String, pos: Vector3) -> ZombieUnit:
	for z: ZombieUnit in _pool:
		if is_instance_valid(z) and not z.is_alive:
			z.activate(archetype, pos, get_day_hp_multiplier(), get_day_speed_multiplier())
			return z
	return null


func spawn_wave(count: int, include_specials: bool = true) -> int:
	if spawning_paused:
		return 0
	var spawned: int = 0
	for _i in range(count):
		var spawn_pos: Vector3 = _pick_multi_directional_spawn_pos()
		var arch: String = _pick_archetype(include_specials)
		if spawn_zombie(arch, spawn_pos) != null:
			spawned += 1
	return spawned


func spawn_local_ambush(center_pos: Vector3, count: int = 4) -> int:
	if spawning_paused:
		return 0
	var spawned: int = 0
	for i in range(count):
		var ang: float = float(i) * (TAU / maxf(1.0, float(count))) + _rng.randf_range(-0.35, 0.35)
		var dist: float = _rng.randf_range(7.5, 11.5)
		var pos: Vector3 = Vector3(
			clampf(center_pos.x + cos(ang) * dist, _world_bounds.position.x + 1.0, _world_bounds.end.x - 1.0),
			0.0,
			clampf(center_pos.z + sin(ang) * dist, _world_bounds.position.y + 3.0, _world_bounds.end.y - 1.0)
		)
		var arch: String = "runner" if (i % 2 == 1) else "walker"
		if spawn_zombie(arch, pos) != null:
			spawned += 1
	return spawned


func update_horde(
	delta: float,
	player_pos: Vector3,
	player_alive: bool,
	train: ArmoredTrainBase,
	consist_stats: Dictionary,
	cam_yaw_rad: float
) -> void:
	if not is_active:
		return

	# 1. Advance Run Timer & Threat Stage
	if time_remaining > 0.0:
		time_remaining = maxf(0.0, time_remaining - delta)
		if time_remaining <= 0.0 and not is_overtime:
			is_overtime = true
			current_stage = 5
			current_stage_name = "⚠️ 逾時滅絕屍潮！"
			wave_stage_changed.emit(current_stage, current_stage_name)
			overtime_triggered.emit()
	_update_threat_stage()
	run_timer_updated.emit(time_remaining, total_run_duration, current_stage_name)

	# 2. Periodic Spawns & Horde Waves
	var is_night_siege: bool = (current_cycle_phase == DayNightCycleManager.Phase.NIGHT or current_cycle_phase == DayNightCycleManager.Phase.BLOOD_MOON)
	if not spawning_paused:
		var desired_cap: int = mini(POOL_SIZE, int(round((7.0 + float(current_stage) * 4.5 + float(current_day - 1) * 3.0) * difficulty_mult)))
		if not is_night_siege and not is_extraction_holdout and not is_overtime:
			desired_cap = mini(POOL_SIZE, 10 + (current_day - 1) * 2)
		if current_cycle_phase == DayNightCycleManager.Phase.BLOOD_MOON or is_extraction_holdout or is_overtime:
			desired_cap = mini(POOL_SIZE, int(round((22.0 + float(current_day - 1) * 3.0) * difficulty_mult)))

		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var interval: float = 4.6 if current_stage == 1 else (3.1 if current_stage == 2 else 2.0)
			if not is_night_siege and not is_extraction_holdout and not is_overtime:
				interval = 7.5
			if current_cycle_phase == DayNightCycleManager.Phase.BLOOD_MOON or is_extraction_holdout or is_overtime:
				interval = 1.15
			_spawn_timer = interval / maxf(0.7, difficulty_mult)
			if get_active_zombie_count() < desired_cap:
				var sz := spawn_zombie(_pick_archetype(is_night_siege or current_stage >= 2 or is_extraction_holdout), _pick_multi_directional_spawn_pos())
				if sz != null and not is_night_siege and not is_extraction_holdout and not is_overtime:
					sz.setup_roamer(sz.global_position, false)

		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_timer = 14.0 if (current_cycle_phase == DayNightCycleManager.Phase.BLOOD_MOON or is_extraction_holdout or is_overtime) else (22.0 if is_night_siege else 36.0)
			if is_night_siege or is_extraction_holdout or is_overtime:
				var wave_cnt: int = int(round((4.0 + float(current_day) * 1.5 + float(current_stage)) * difficulty_mult))
				if get_active_zombie_count() < POOL_SIZE - 2:
					spawn_wave(mini(wave_cnt, POOL_SIZE - get_active_zombie_count()), true)

	# 3. Tick all active zombies (lock onto train's current parked perimeter during night siege!)
	var has_tesla: bool = train != null and train.has_tesla_fence()
	for z: ZombieUnit in _pool:
		if is_instance_valid(z) and z.is_alive:
			var train_target: Vector3 = train.get_nearest_perimeter_world_pos(z.global_position) if train != null else Vector3(0.0, 0.0, -3.2)
			z.tick_zombie(delta, player_pos, player_alive, train_target, has_tesla, cam_yaw_rad)

	# 4. Fire Armored Train Roof Auto-Turrets!
	if train != null:
		_update_train_turrets(delta, train, consist_stats)


func _update_threat_stage() -> void:
	if is_extraction_holdout or is_overtime:
		return
	var elapsed_ratio: float = 1.0 - (time_remaining / maxf(1.0, total_run_duration))
	var next_stage: int = 1
	var next_name: String = "階段 1：靜默進站"
	if elapsed_ratio >= 0.68:
		next_stage = 3
		next_name = "階段 3：紅月夜幕屍潮"
	elif elapsed_ratio >= 0.30:
		next_stage = 2
		next_name = "階段 2：警報升溫"

	if next_stage != current_stage:
		current_stage = next_stage
		current_stage_name = next_name
		wave_stage_changed.emit(current_stage, current_stage_name)
		spawn_wave(int(round(4.0 * difficulty_mult)), true)


func _update_train_turrets(delta: float, train: ArmoredTrainBase, consist_stats: Dictionary) -> void:
	var turret_count: int = int(consist_stats.get("turret_count", 0))
	var total_dps: float = float(consist_stats.get("turret_dps", 0.0))
	if turret_count <= 0 or total_dps <= 0.0:
		return

	_turret_fire_cd = maxf(0.0, _turret_fire_cd - delta)
	if _turret_fire_cd > 0.0:
		return

	var fire_interval: float = 0.34
	var turret_positions: Array[Vector3] = train.get_turret_world_positions()
	if turret_positions.is_empty():
		return
	var per_shot_dmg: float = (total_dps * fire_interval) / float(turret_positions.size())

	var fired_any: bool = false
	for ti in range(turret_positions.size()):
		var tpos: Vector3 = turret_positions[ti]
		var target: ZombieUnit = _find_nearest_zombie(tpos, TURRET_RANGE)
		if target == null:
			continue
		fired_any = true
		var aim_pos: Vector3 = target.global_position + Vector3(0.0, 1.05, 0.0)
		train.aim_turret_at(ti, aim_pos)
		_spawn_turret_tracer(tpos, aim_pos)
		target.apply_damage(per_shot_dmg)

	if fired_any:
		_turret_fire_cd = fire_interval


func damage_zombies_along_ray(origin: Vector3, dir: Vector3, max_dist: float, damage: float) -> Dictionary:
	var flat_dir: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat_dir.length_squared() < 0.0001:
		return {"hit": false}
	flat_dir = flat_dir.normalized()

	var best_z: ZombieUnit = null
	var best_t: float = max_dist
	for z: ZombieUnit in _pool:
		if not (is_instance_valid(z) and z.is_alive):
			continue
		var to_z: Vector3 = Vector3(z.global_position.x - origin.x, 0.0, z.global_position.z - origin.z)
		var proj: float = to_z.dot(flat_dir)
		if proj < 0.0 or proj > best_t:
			continue
		var perp_sq: float = to_z.length_squared() - proj * proj
		var hit_radius: float = 0.88 if (z.archetype == "brute" or z.archetype == "bloater") else 0.68
		if perp_sq <= hit_radius * hit_radius:
			best_t = proj
			best_z = z

	if best_z != null:
		var hit_pos: Vector3 = best_z.global_position + Vector3(0.0, 1.05, 0.0)
		var killed: bool = best_z.apply_damage(damage)
		_spawn_hit_spark(hit_pos, Color(1.0, 0.42, 0.24) if killed else Color(1.0, 0.86, 0.42))
		return {"hit": true, "killed": killed, "pos": hit_pos, "archetype": best_z.archetype}
	return {"hit": false}


func _find_nearest_zombie(from_pos: Vector3, max_range: float) -> ZombieUnit:
	var best: ZombieUnit = null
	var best_d_sq: float = max_range * max_range
	for z: ZombieUnit in _pool:
		if not (is_instance_valid(z) and z.is_alive):
			continue
		var dx: float = z.global_position.x - from_pos.x
		var dz: float = z.global_position.z - from_pos.z
		var d_sq: float = dx * dx + dz * dz
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = z
	return best


func _pick_multi_directional_spawn_pos() -> Vector3:
	var edge: int = _rng.randi_range(0, 3)  # North, South, West, or East edges (multi-directional!)
	var rail_mid_z: float = (_world_bounds.position.y + _world_bounds.end.y) * 0.5
	match edge:
		0:
			return Vector3(_rng.randf_range(_world_bounds.position.x + 2.0, _world_bounds.end.x - 2.0), 0.0, _world_bounds.end.y - 1.2)
		1:
			return Vector3(_rng.randf_range(_world_bounds.position.x + 2.0, _world_bounds.end.x - 2.0), 0.0, _world_bounds.position.y + 1.2)
		2:
			var z_w: float = _rng.randf_range(_world_bounds.position.y + 2.0, _world_bounds.end.y - 2.0)
			if absf(z_w - rail_mid_z) < 5.0:
				z_w = rail_mid_z + (6.5 if z_w >= rail_mid_z else -6.5)
			return Vector3(_world_bounds.position.x + 1.2, 0.0, clampf(z_w, _world_bounds.position.y + 1.5, _world_bounds.end.y - 1.5))
		_:
			var z_e: float = _rng.randf_range(_world_bounds.position.y + 2.0, _world_bounds.end.y - 2.0)
			if absf(z_e - rail_mid_z) < 5.0:
				z_e = rail_mid_z + (6.5 if z_e >= rail_mid_z else -6.5)
			return Vector3(_world_bounds.end.x - 1.2, 0.0, clampf(z_e, _world_bounds.position.y + 1.5, _world_bounds.end.y - 1.5))


func _pick_perimeter_spawn_pos() -> Vector3:
	return _pick_multi_directional_spawn_pos()


func _pick_archetype(include_specials: bool) -> String:
	if not include_specials:
		return "walker"
	var r: float = _rng.randf()
	if current_cycle_phase == DayNightCycleManager.Phase.BLOOD_MOON:
		if r < 0.14:
			return "blood_elite"
		if r < 0.30:
			return "brute"
		if r < 0.44:
			return "bloater"
		if r < 0.72:
			return "runner"
		return "walker"
	if current_stage >= 3 or is_extraction_holdout or is_overtime or current_cycle_phase == DayNightCycleManager.Phase.NIGHT:
		if r < 0.14:
			return "brute"
		if r < 0.26:
			return "bloater"
		if r < 0.56:
			return "runner"
		return "walker"
	else:
		if r < 0.34:
			return "runner"
		return "walker"


func _on_zombie_died(zombie: ZombieUnit, arch: String, death_pos: Vector3) -> void:
	total_kills += 1
	if zombie.explodes_on_death:
		_spawn_hit_spark(death_pos + Vector3(0.0, 0.8, 0.0), Color(0.55, 1.0, 0.25), 2.4)
	if arch == "blood_elite":
		_spawn_hit_spark(death_pos + Vector3(0.0, 0.9, 0.0), Color(1.0, 0.18, 0.32), 2.8)
		elite_loot_dropped.emit(arch, death_pos, {"parts": 2, "fuel": 1}, 1)
	zombie_killed.emit(arch, total_kills, death_pos)


func _spawn_turret_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	if _vfx_root == null or not is_inside_tree():
		return
	var seg: Vector3 = to_pos - from_pos
	var length: float = maxf(0.5, seg.length())
	var beam: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.08, 0.08, length)
	beam.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.72, 0.24, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.64, 0.18)
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat
	_vfx_root.add_child(beam)
	beam.global_position = (from_pos + to_pos) * 0.5
	beam.look_at(to_pos, Vector3.UP)
	var tw: Tween = beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.11)
	tw.tween_callback(beam.queue_free)


func _spawn_hit_spark(pos: Vector3, color: Color, scale_mult: float = 1.0) -> void:
	if _vfx_root == null or not is_inside_tree():
		return
	var sph: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.22 * scale_mult
	sm.height = 0.44 * scale_mult
	sph.mesh = sm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sph.material_override = mat
	_vfx_root.add_child(sph)
	sph.global_position = pos
	var tw: Tween = sph.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sph, "scale", Vector3.ONE * 1.9, 0.22)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(sph.queue_free)
