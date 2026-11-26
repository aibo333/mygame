class_name DayNightCycleManager
extends Node

## Manages the Day / Dusk / Night / BloodMoon cycle, clock formatting,
## train mobility lock rules, and dynamic WorldEnvironment / DirectionalLight3D lighting.

enum Phase {
	DAY,
	DUSK,
	NIGHT,
	BLOOD_MOON,
}

signal phase_changed(new_phase: int, day_num: int)
signal day_changed(day_num: int)
signal blood_moon_value_changed(value: float, threshold: float, warning_active: bool)
signal random_event_triggered(title: String, delta_bm: float)

const DAY_DURATION: float = 180.0
const DUSK_DURATION: float = 25.0
const NIGHT_DURATION: float = 120.0
const BLOOD_MOON_DURATION: float = 135.0
const BLOOD_MOON_THRESHOLD: float = 100.0
const DAY_PASSIVE_BM_RATE: float = 0.14
const NIGHT_PASSIVE_BM_RATE: float = 0.08
const ANOMALY_INTERVAL: float = 75.0

var current_day: int = 1
var current_phase: int = Phase.DAY
var phase_elapsed: float = 0.0
var blood_moon_value: float = 0.0
var next_night_blood_moon: bool = false
var auto_advance: bool = true
var anomaly_events_enabled: bool = true

var _lighting_blend: float = 0.0  # 0.0=DAY, 1.0=DUSK, 2.0=NIGHT, 3.0=BLOOD_MOON
var _anomaly_timer: float = ANOMALY_INTERVAL
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func reset(seed_value: int = 424242) -> void:
	current_day = 1
	current_phase = Phase.DAY
	phase_elapsed = 0.0
	blood_moon_value = 0.0
	next_night_blood_moon = false
	_lighting_blend = 0.0
	_anomaly_timer = ANOMALY_INTERVAL
	_rng.seed = seed_value ^ 0x6C4E19
	blood_moon_value_changed.emit(blood_moon_value, BLOOD_MOON_THRESHOLD, false)


func get_phase_duration(phase: int = -1) -> float:
	var target: int = current_phase if phase < 0 else phase
	match target:
		Phase.DAY:
			return DAY_DURATION
		Phase.DUSK:
			return DUSK_DURATION
		Phase.NIGHT:
			return NIGHT_DURATION
		Phase.BLOOD_MOON:
			return BLOOD_MOON_DURATION
	return DAY_DURATION


func get_phase_progress() -> float:
	var dur: float = maxf(0.001, get_phase_duration(current_phase))
	return clampf(phase_elapsed / dur, 0.0, 1.0)


func get_phase_remaining() -> float:
	return maxf(0.0, get_phase_duration(current_phase) - phase_elapsed)


func is_train_mobile() -> bool:
	return current_phase == Phase.DAY


func is_night_lights_active() -> bool:
	return current_phase == Phase.DUSK or current_phase == Phase.NIGHT or current_phase == Phase.BLOOD_MOON


func is_blood_moon() -> bool:
	return current_phase == Phase.BLOOD_MOON


func get_phase_label() -> String:
	match current_phase:
		Phase.DAY:
			return "DAY"
		Phase.DUSK:
			return "DUSK"
		Phase.NIGHT:
			return "NIGHT"
		Phase.BLOOD_MOON:
			return "BLOOD MOON"
	return "DAY"


func get_clock_text() -> String:
	var rem: int = int(ceilf(get_phase_remaining()))
	var mins: int = rem / 60
	var secs: int = rem % 60
	return "D%d · %s · %02d:%02d" % [current_day, get_phase_label(), mins, secs]


func force_phase(phase: int, day_num: int = -1, elapsed: float = 0.0) -> void:
	var old_day: int = current_day
	if day_num >= 1:
		current_day = day_num
	current_phase = clampi(phase, Phase.DAY, Phase.BLOOD_MOON)
	phase_elapsed = maxf(0.0, elapsed)
	_lighting_blend = float(current_phase)
	if current_day != old_day:
		day_changed.emit(current_day)
	phase_changed.emit(current_phase, current_day)


func schedule_blood_moon(enabled: bool = true) -> void:
	next_night_blood_moon = enabled
	if enabled and blood_moon_value < BLOOD_MOON_THRESHOLD:
		blood_moon_value = BLOOD_MOON_THRESHOLD
	blood_moon_value_changed.emit(blood_moon_value, BLOOD_MOON_THRESHOLD, is_blood_moon_warning())


func is_blood_moon_warning() -> bool:
	return next_night_blood_moon or blood_moon_value >= BLOOD_MOON_THRESHOLD


func get_blood_moon_ratio() -> float:
	return clampf(blood_moon_value / BLOOD_MOON_THRESHOLD, 0.0, 1.0)


func add_blood_moon_pressure(delta_bm: float, _reason: String = "") -> float:
	if current_phase == Phase.BLOOD_MOON:
		return blood_moon_value
	var prev_warn: bool = is_blood_moon_warning()
	blood_moon_value = clampf(blood_moon_value + delta_bm, 0.0, BLOOD_MOON_THRESHOLD)
	if blood_moon_value >= BLOOD_MOON_THRESHOLD:
		next_night_blood_moon = true
	elif delta_bm < 0.0 and blood_moon_value < BLOOD_MOON_THRESHOLD * 0.85:
		next_night_blood_moon = false
	if not is_equal_approx(delta_bm, 0.0) or prev_warn != is_blood_moon_warning():
		blood_moon_value_changed.emit(blood_moon_value, BLOOD_MOON_THRESHOLD, is_blood_moon_warning())
	return blood_moon_value


func trigger_blood_moon_event(delta_bm: float, title: String) -> float:
	add_blood_moon_pressure(delta_bm, title)
	random_event_triggered.emit(title, delta_bm)
	return blood_moon_value


func update_cycle(delta: float) -> void:
	if not auto_advance or delta <= 0.0:
		return
	if current_phase == Phase.DAY:
		add_blood_moon_pressure(DAY_PASSIVE_BM_RATE * delta, "time_day")
	elif current_phase == Phase.NIGHT:
		add_blood_moon_pressure(NIGHT_PASSIVE_BM_RATE * delta, "time_night")

	if anomaly_events_enabled and current_phase != Phase.BLOOD_MOON:
		_anomaly_timer -= delta
		if _anomaly_timer <= 0.0:
			_anomaly_timer = ANOMALY_INTERVAL
			_roll_random_anomaly_event()

	phase_elapsed += delta
	var dur: float = get_phase_duration(current_phase)
	while phase_elapsed >= dur:
		phase_elapsed -= dur
		_advance_to_next_phase()
		dur = get_phase_duration(current_phase)

	var target_blend: float = float(current_phase)
	_lighting_blend = move_toward(_lighting_blend, target_blend, delta * 0.65)


func _roll_random_anomaly_event() -> void:
	var events: Array[Dictionary] = [
		{"delta": 12.0, "title": "紅霧異常潮汐（血月讀數 +12）"},
		{"delta": -9.0, "title": "冷鋒高壓干擾（血月讀數 -9）"},
		{"delta": 8.0, "title": "遠處都市防空警報迴響（血月讀數 +8）"},
		{"delta": -6.0, "title": "地磁靜默窗口（血月讀數 -6）"},
	]
	var picked: Dictionary = events[_rng.randi_range(0, events.size() - 1)]
	trigger_blood_moon_event(float(picked["delta"]), str(picked["title"]))


func _advance_to_next_phase() -> void:
	match current_phase:
		Phase.DAY:
			current_phase = Phase.DUSK
			if blood_moon_value >= BLOOD_MOON_THRESHOLD:
				next_night_blood_moon = true
			phase_changed.emit(current_phase, current_day)
		Phase.DUSK:
			if next_night_blood_moon or blood_moon_value >= BLOOD_MOON_THRESHOLD:
				next_night_blood_moon = false
				blood_moon_value = 0.0
				current_phase = Phase.BLOOD_MOON
				blood_moon_value_changed.emit(blood_moon_value, BLOOD_MOON_THRESHOLD, false)
			else:
				current_phase = Phase.NIGHT
			phase_changed.emit(current_phase, current_day)
		Phase.NIGHT, Phase.BLOOD_MOON:
			current_day += 1
			current_phase = Phase.DAY
			day_changed.emit(current_day)
			phase_changed.emit(current_phase, current_day)


func get_lighting_profile(blend_val: float = -1.0) -> Dictionary:
	var b: float = _lighting_blend if blend_val < 0.0 else blend_val

	# Anchor keyframes matching RuinsBaseWorld's crisp daytime atmosphere + dusk + cold dark night + blood moon
	var day_bg := Color(0.13, 0.16, 0.21)
	var day_sky := Color(0.10, 0.14, 0.21)
	var day_horizon := Color(0.28, 0.35, 0.44)
	var day_ground := Color(0.08, 0.10, 0.13)
	var day_sun := Color(0.90, 0.94, 1.0)
	var day_sun_energy := 1.80
	var day_fill := Color(0.46, 0.64, 0.88)
	var day_fill_energy := 0.62
	var day_ambient := Color(0.48, 0.58, 0.72)
	var day_ambient_energy := 0.85
	var day_fog := Color(0.26, 0.32, 0.40)
	var day_fog_density := 0.0042

	var dusk_bg := Color(0.14, 0.10, 0.13)
	var dusk_sky := Color(0.22, 0.16, 0.22)
	var dusk_horizon := Color(0.55, 0.34, 0.25)
	var dusk_ground := Color(0.10, 0.08, 0.11)
	var dusk_sun := Color(1.0, 0.62, 0.36)
	var dusk_sun_energy := 0.85
	var dusk_fill := Color(0.42, 0.46, 0.68)
	var dusk_fill_energy := 0.28
	var dusk_ambient := Color(0.34, 0.28, 0.36)
	var dusk_ambient_energy := 0.40
	var dusk_fog := Color(0.32, 0.24, 0.28)
	var dusk_fog_density := 0.0085

	var night_bg := Color(0.02, 0.03, 0.06)
	var night_sky := Color(0.03, 0.05, 0.09)
	var night_horizon := Color(0.06, 0.09, 0.15)
	var night_ground := Color(0.02, 0.03, 0.05)
	var night_sun := Color(0.42, 0.56, 0.88)
	var night_sun_energy := 0.20
	var night_fill := Color(0.16, 0.24, 0.44)
	var night_fill_energy := 0.14
	var night_ambient := Color(0.10, 0.13, 0.22)
	var night_ambient_energy := 0.16
	var night_fog := Color(0.04, 0.06, 0.11)
	var night_fog_density := 0.014

	var blood_bg := Color(0.08, 0.015, 0.025)
	var blood_sky := Color(0.15, 0.03, 0.05)
	var blood_horizon := Color(0.28, 0.05, 0.07)
	var blood_ground := Color(0.05, 0.02, 0.03)
	var blood_sun := Color(0.92, 0.22, 0.24)
	var blood_sun_energy := 0.34
	var blood_fill := Color(0.36, 0.10, 0.14)
	var blood_fill_energy := 0.18
	var blood_ambient := Color(0.22, 0.06, 0.08)
	var blood_ambient_energy := 0.22
	var blood_fog := Color(0.14, 0.03, 0.05)
	var blood_fog_density := 0.016

	if b <= 1.0:
		var t: float = clampf(b, 0.0, 1.0)
		return {
			"bg": day_bg.lerp(dusk_bg, t),
			"sky": day_sky.lerp(dusk_sky, t),
			"horizon": day_horizon.lerp(dusk_horizon, t),
			"ground": day_ground.lerp(dusk_ground, t),
			"sun_color": day_sun.lerp(dusk_sun, t),
			"sun_energy": lerpf(day_sun_energy, dusk_sun_energy, t),
			"fill_color": day_fill.lerp(dusk_fill, t),
			"fill_energy": lerpf(day_fill_energy, dusk_fill_energy, t),
			"ambient_color": day_ambient.lerp(dusk_ambient, t),
			"ambient_energy": lerpf(day_ambient_energy, dusk_ambient_energy, t),
			"fog_color": day_fog.lerp(dusk_fog, t),
			"fog_density": lerpf(day_fog_density, dusk_fog_density, t),
		}
	elif b <= 2.0:
		var t: float = clampf(b - 1.0, 0.0, 1.0)
		return {
			"bg": dusk_bg.lerp(night_bg, t),
			"sky": dusk_sky.lerp(night_sky, t),
			"horizon": dusk_horizon.lerp(night_horizon, t),
			"ground": dusk_ground.lerp(night_ground, t),
			"sun_color": dusk_sun.lerp(night_sun, t),
			"sun_energy": lerpf(dusk_sun_energy, night_sun_energy, t),
			"fill_color": dusk_fill.lerp(night_fill, t),
			"fill_energy": lerpf(dusk_fill_energy, night_fill_energy, t),
			"ambient_color": dusk_ambient.lerp(night_ambient, t),
			"ambient_energy": lerpf(dusk_ambient_energy, night_ambient_energy, t),
			"fog_color": dusk_fog.lerp(night_fog, t),
			"fog_density": lerpf(dusk_fog_density, night_fog_density, t),
		}
	else:
		var t: float = clampf(b - 2.0, 0.0, 1.0)
		return {
			"bg": night_bg.lerp(blood_bg, t),
			"sky": night_sky.lerp(blood_sky, t),
			"horizon": night_horizon.lerp(blood_horizon, t),
			"ground": night_ground.lerp(blood_ground, t),
			"sun_color": night_sun.lerp(blood_sun, t),
			"sun_energy": lerpf(night_sun_energy, blood_sun_energy, t),
			"fill_color": night_fill.lerp(blood_fill, t),
			"fill_energy": lerpf(night_fill_energy, blood_fill_energy, t),
			"ambient_color": night_ambient.lerp(blood_ambient, t),
			"ambient_energy": lerpf(night_ambient_energy, blood_ambient_energy, t),
			"fog_color": night_fog.lerp(blood_fog, t),
			"fog_density": lerpf(night_fog_density, blood_fog_density, t),
		}


func apply_environment_lighting(
	we: WorldEnvironment,
	sun: DirectionalLight3D,
	fill: DirectionalLight3D
) -> void:
	var p: Dictionary = get_lighting_profile()
	if we != null and we.environment != null:
		var env: Environment = we.environment
		env.background_color = p["bg"]
		env.ambient_light_color = p["ambient_color"]
		env.ambient_light_energy = float(p["ambient_energy"])
		env.fog_light_color = p["fog_color"]
		env.fog_density = float(p["fog_density"])
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = p["sky"]
			sky_mat.sky_horizon_color = p["horizon"]
			sky_mat.ground_bottom_color = p["ground"]
			sky_mat.ground_horizon_color = p["horizon"]
	if sun != null:
		sun.light_color = p["sun_color"]
		sun.light_energy = float(p["sun_energy"])
	if fill != null:
		fill.light_color = p["fill_color"]
		fill.light_energy = float(p["fill_energy"])
