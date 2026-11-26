class_name ExpeditionManager
extends Node3D

## Manages Milestone 4 long-term holdout incentives & cross-sector expedition flow:
## - Fixed Large Holdout Facility requiring Armored Train proximity power coupling (stepped multi-day yields)
## - Railway Exit Blockade & Departure Fuel threshold before leaving the current Sector

signal facility_power_changed(powered: bool, level_days: int)
signal facility_yield_granted(day_num: int, resources: Dictionary, mod_cores: int)
signal blockade_cleared(pos: Vector3)

const FACILITY_POWER_RANGE: float = 7.5
const DEPARTURE_FUEL_COST: int = 2

var sector_index: int = 1
var consecutive_powered_days: int = 0
var facility_powered: bool = false
var facility_activated: bool = true
var facility_pos: Vector3 = Vector3(-16.0, 0.0, -8.8)

var rail_barricade_cleared: bool = false
var blockade_pos: Vector3 = Vector3(56.0, 0.0, -3.2)

var _root: Node3D = null
var _facility_node: Node3D = null
var _facility_beacon_mat: StandardMaterial3D = null
var _facility_light: OmniLight3D = null
var _facility_label: Label3D = null
var _tether_beam: MeshInstance3D = null
var _blockade_node: Node3D = null


func reset_for_sector(p_sector_index: int, bounds: Rect2, rail_z: float, seed_value: int, keep_sector_index: bool = false) -> void:
	if not keep_sector_index:
		sector_index = maxi(1, p_sector_index)
	consecutive_powered_days = 0
	facility_powered = false
	facility_activated = true
	rail_barricade_cleared = false

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4A91D3

	# On Sector #1 place the facility in the open sunlit rail apron plaza (x=-14.5, z=rail_z+6.4)
	# so it sits right in clear view on the starting screen and never hides behind HUD panels or the train.
	if sector_index == 1:
		facility_pos = Vector3(-14.5, 0.0, rail_z + 6.4)
	else:
		var side_sign: float = -1.0 if (rng.randi() % 2 == 0) else 1.0
		var fac_x: float = clampf(rng.randf_range(-28.0, -15.0) if side_sign < 0.0 else rng.randf_range(15.0, 28.0), bounds.position.x + 12.0, bounds.end.x - 12.0)
		facility_pos = Vector3(fac_x, 0.0, rail_z + 6.4)

	# Place the Railway Blockade near the eastern departure edge of the central tracks
	blockade_pos = Vector3(bounds.end.x - 8.5, 0.0, rail_z)

	_rebuild_visuals()


func _rebuild_visuals() -> void:
	if _root != null and is_instance_valid(_root):
		if _root.get_parent() == self:
			remove_child(_root)
		_root.free()
	_root = Node3D.new()
	_root.name = "ExpeditionPropsRoot"
	add_child(_root)

	_build_facility_prop()
	_build_blockade_prop()


func _build_facility_prop() -> void:
	_facility_node = Node3D.new()
	_facility_node.name = "HoldoutPowerFacility"
	_facility_node.position = facility_pos
	_root.add_child(_facility_node)

	var steel_mat := _mat(Color(0.24, 0.28, 0.34), 0.72, 0.42)
	var dark_mat := _mat(Color(0.14, 0.17, 0.22), 0.55, 0.55)
	_facility_beacon_mat = _mat(Color(0.95, 0.62, 0.14), 0.15, 0.35, Color(0.95, 0.58, 0.12), 2.4)

	_add_box(_facility_node, Vector3(3.4, 0.35, 2.8), Vector3(0.0, 0.18, 0.0), dark_mat)
	_add_box(_facility_node, Vector3(2.2, 2.6, 1.8), Vector3(-0.4, 1.45, 0.0), steel_mat)
	_add_box(_facility_node, Vector3(0.85, 3.8, 0.85), Vector3(0.9, 1.9, 0.0), dark_mat)
	_add_box(_facility_node, Vector3(0.55, 0.36, 0.55), Vector3(0.9, 3.95, 0.0), _facility_beacon_mat)

	# Ground coupling ring toward the railway (north side of apron facility)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.45
	tm.outer_radius = 1.65
	ring.mesh = tm
	ring.scale = Vector3(1.0, 0.35, 1.0)
	ring.position = Vector3(0.0, 0.06, -1.9)
	ring.material_override = _facility_beacon_mat
	_facility_node.add_child(ring)

	_facility_light = OmniLight3D.new()
	_facility_light.light_color = Color(0.28, 0.88, 1.0)
	_facility_light.light_energy = 1.6
	_facility_light.omni_range = 12.0
	_facility_light.position = Vector3(0.9, 4.1, 0.0)
	_facility_node.add_child(_facility_light)

	_facility_label = Label3D.new()
	_facility_label.name = "FacilityStatusLabel"
	_facility_label.text = "🔌 大型重工精煉站（駛近 12.5m 接電）"
	_facility_label.font_size = 26
	_facility_label.pixel_size = 0.012
	_facility_label.modulate = Color(1.0, 0.78, 0.28)
	_facility_label.outline_size = 8
	_facility_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_facility_label.position = Vector3(0.0, 4.85, 0.0)
	_facility_node.add_child(_facility_label)

	_tether_beam = MeshInstance3D.new()
	_tether_beam.name = "PowerCouplingTether"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.14, 0.14, 1.0)
	_tether_beam.mesh = beam_mesh
	_tether_beam.material_override = _mat(Color(0.28, 0.92, 1.0), 0.1, 0.2, Color(0.28, 0.92, 1.0), 3.4)
	_tether_beam.visible = false
	_root.add_child(_tether_beam)


func _build_blockade_prop() -> void:
	if rail_barricade_cleared:
		_blockade_node = null
		return
	_blockade_node = Node3D.new()
	_blockade_node.name = "RailwayExitBlockade"
	_blockade_node.position = blockade_pos
	_root.add_child(_blockade_node)

	var rust_mat := _mat(Color(0.32, 0.24, 0.20), 0.62, 0.62)
	var warn_mat := _mat(Color(0.96, 0.36, 0.20), 0.2, 0.45, Color(0.96, 0.32, 0.18), 1.8)
	_add_box(_blockade_node, Vector3(2.4, 1.85, 4.8), Vector3(0.0, 0.92, 0.0), rust_mat)
	_add_box(_blockade_node, Vector3(0.32, 0.45, 5.2), Vector3(-1.15, 1.15, 0.0), warn_mat)
	_add_box(_blockade_node, Vector3(1.6, 2.3, 1.5), Vector3(0.35, 1.15, -1.2), rust_mat, Vector3(0.0, 22.0, -14.0))

	var b_lbl := Label3D.new()
	b_lbl.text = "🚧 鐵軌路障 [E 清除]"
	b_lbl.font_size = 24
	b_lbl.pixel_size = 0.012
	b_lbl.modulate = Color(1.0, 0.48, 0.32)
	b_lbl.outline_size = 8
	b_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b_lbl.position = Vector3(0.0, 3.0, 0.0)
	_blockade_node.add_child(b_lbl)


func update_train_coupling(train: ArmoredTrainBase) -> bool:
	if train == null:
		return false
	var nearest_hull: Vector3 = train.get_nearest_perimeter_world_pos(facility_pos)
	var dist: float = Vector2(nearest_hull.x - facility_pos.x, nearest_hull.z - facility_pos.z).length()
	var now_powered: bool = facility_activated and (dist <= FACILITY_POWER_RANGE)
	if now_powered != facility_powered:
		facility_powered = now_powered
		_sync_facility_visuals()
		facility_power_changed.emit(facility_powered, consecutive_powered_days)
	if _tether_beam != null and is_instance_valid(_tether_beam):
		_tether_beam.visible = facility_powered
		if facility_powered:
			var a := facility_pos + Vector3(0.0, 1.4, -1.2)
			var b := Vector3(nearest_hull.x, 1.4, train.position.z + 2.4)
			_tether_beam.global_position = (a + b) * 0.5
			var seg_len: float = maxf(0.4, a.distance_to(b))
			_tether_beam.scale = Vector3(1.0, 1.0, seg_len)
			if seg_len > 0.01:
				_tether_beam.look_at(b, Vector3.UP)
	return facility_powered


func _sync_facility_visuals() -> void:
	if _facility_beacon_mat != null:
		var col: Color = Color(0.26, 0.92, 1.0) if facility_powered else Color(0.95, 0.62, 0.14)
		_facility_beacon_mat.albedo_color = col
		_facility_beacon_mat.emission = col
		_facility_beacon_mat.emission_energy_multiplier = 3.2 if facility_powered else 1.8
	if _facility_light != null and is_instance_valid(_facility_light):
		_facility_light.light_energy = 3.4 if facility_powered else 1.6
	if _facility_label != null and is_instance_valid(_facility_label):
		if facility_powered:
			_facility_label.text = "⚡ 大型重工精煉站｜已供電（連續 %d 日）" % consecutive_powered_days
			_facility_label.modulate = Color(0.32, 0.96, 1.0)
		else:
			_facility_label.text = "🔌 大型重工精煉站（將列車駛近 7.5m 接電）"
			_facility_label.modulate = Color(1.0, 0.78, 0.28)


func on_day_passed(new_day: int) -> Dictionary:
	if not facility_powered:
		return {"granted": false}
	consecutive_powered_days += 1
	_sync_facility_visuals()
	var yield_res: Dictionary
	var mod_cores: int = 0
	if consecutive_powered_days == 1:
		yield_res = {"parts": 3, "fuel": 2}
	elif consecutive_powered_days == 2:
		yield_res = {"parts": 5, "fuel": 3, "scrap": 4}
		mod_cores = 1
	else:
		yield_res = {"parts": 8, "fuel": 4, "scrap": 6}
		mod_cores = 2
	facility_yield_granted.emit(new_day, yield_res, mod_cores)
	return {
		"granted": true,
		"powered_days": consecutive_powered_days,
		"resources": yield_res,
		"mod_cores": mod_cores,
	}


func clear_rail_blockade() -> bool:
	if rail_barricade_cleared:
		return false
	rail_barricade_cleared = true
	if _blockade_node != null and is_instance_valid(_blockade_node):
		_blockade_node.queue_free()
		_blockade_node = null
	blockade_cleared.emit(blockade_pos)
	return true


func check_departure_requirements(
	is_day_mobile: bool,
	backpack: Dictionary,
	train_stash: Dictionary,
	infinite_resources: bool
) -> Dictionary:
	if not is_day_mobile:
		return {"ok": false, "reason": "night_locked", "message": "⛔ 僅能於白天駕駛裝甲列車駛離目前街區"}
	if not rail_barricade_cleared:
		return {"ok": false, "reason": "blockade", "message": "🚧 東側鐵軌路障尚未清除，請先前往鐵軌末端清除路障"}
	var total_fuel: int = int(backpack.get("fuel", 0)) + int(train_stash.get("fuel", 0))
	if not infinite_resources and total_fuel < DEPARTURE_FUEL_COST:
		return {
			"ok": false,
			"reason": "fuel",
			"message": "⛽ 離站燃料不足（需要高能燃料 %d，目前 %d）" % [DEPARTURE_FUEL_COST, total_fuel],
		}
	return {"ok": true, "reason": "ready", "message": "✅ 離站條件達成！可啟動跨圖遠征"}


func consume_departure_fuel(backpack: Dictionary, train_stash: Dictionary, infinite_resources: bool) -> void:
	if infinite_resources:
		return
	var need: int = DEPARTURE_FUEL_COST
	var from_bp: int = mini(need, int(backpack.get("fuel", 0)))
	backpack["fuel"] = int(backpack.get("fuel", 0)) - from_bp
	need -= from_bp
	if need > 0:
		train_stash["fuel"] = maxi(0, int(train_stash.get("fuel", 0)) - need)


func get_interactive_zones() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	zones.append({
		"id": "holdout_facility",
		"kind": "holdout_facility",
		"label": "大型重工精煉站（接電供能）",
		"pos": facility_pos + Vector3(0.0, 0.0, -1.8),
		"radius": 3.4,
	})
	if not rail_barricade_cleared:
		zones.append({
			"id": "rail_blockade",
			"kind": "rail_blockade",
			"label": "東側鐵軌路障",
			"pos": blockade_pos,
			"radius": 4.2,
		})
	return zones


func _mat(col: Color, metallic: float, roughness: float, emit: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m


func _add_box(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
