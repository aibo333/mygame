class_name LootStashManager
extends Node3D

signal backpack_changed(backpack: Dictionary, used: int, capacity: int)
signal stash_changed(train_stash: Dictionary, total_stashed: int)
signal loot_point_collected(loot_id: String, label: String, gained: Dictionary, overflow: Dictionary)
signal stash_deposited(deposited: Dictionary, count: int)

const RESOURCE_ORDER: Array[String] = ["scrap", "parts", "fuel", "supplies"]

const RESOURCE_META: Dictionary = {
	"scrap": {
		"label": "廢金屬",
		"short": "金屬",
		"color": Color(0.76, 0.80, 0.86),
	},
	"parts": {
		"label": "機械零件",
		"short": "零件",
		"color": Color(0.98, 0.76, 0.32),
	},
	"fuel": {
		"label": "高能燃料",
		"short": "燃料",
		"color": Color(1.0, 0.48, 0.28),
	},
	"supplies": {
		"label": "醫療補給",
		"short": "補給",
		"color": Color(0.42, 0.94, 0.62),
	},
}

const LOOT_ROOT_NAME: String = "LootPointsRoot"
const BEACON_BASE_Y: float = 0.76
const BEACON_BOB_AMPLITUDE: float = 0.09
const RING_BASE_Y: float = 0.05
const RING_HEIGHT_SCALE: float = 0.45

var backpack_capacity: int = 12
var backpack: Dictionary = {"scrap": 0, "parts": 0, "fuel": 0, "supplies": 0}
var train_stash: Dictionary = {"scrap": 0, "parts": 0, "fuel": 0, "supplies": 0}
var loot_nodes: Array[Dictionary] = []

var _loot_root: Node3D = null


func reset_inventory() -> void:
	for res_key: String in RESOURCE_ORDER:
		backpack[res_key] = 0
		train_stash[res_key] = 0
	backpack_changed.emit(backpack.duplicate(), 0, backpack_capacity)
	stash_changed.emit(train_stash.duplicate(), 0)


func spawn_loot_points(spawn_points: Array[Dictionary], seed_value: int) -> void:
	_clear_existing_loot_root()
	loot_nodes.clear()

	var root: Node3D = Node3D.new()
	root.name = LOOT_ROOT_NAME
	add_child(root)
	_loot_root = root

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5A3C19

	for idx: int in range(spawn_points.size()):
		var sp: Dictionary = spawn_points[idx]
		var loot_id: String = str(sp.get("id", "loot_%d" % idx))
		var label: String = str(sp.get("label", "物資補給箱"))
		var block_type: String = str(sp.get("block_type", "ruin"))
		var pos_raw: Variant = sp.get("pos", Vector3.ZERO)
		var pos: Vector3 = pos_raw if pos_raw is Vector3 else Vector3.ZERO
		var bias_raw: String = str(sp.get("resource_bias", "scrap"))
		var primary_resource: String = _resolve_resource_key(bias_raw, idx)

		var contents: Dictionary = _generate_loot_contents(primary_resource, rng)
		var visuals: Dictionary = _build_loot_prop(loot_id, pos, primary_resource, idx)
		var loot_node: Node3D = visuals["node"] as Node3D
		var ring: MeshInstance3D = visuals["ring"] as MeshInstance3D
		var beacon: MeshInstance3D = visuals["beacon"] as MeshInstance3D
		root.add_child(loot_node)

		var entry: Dictionary = {
			"id": loot_id,
			"label": label,
			"block_type": block_type,
			"pos": pos,
			"contents": contents,
			"looted": false,
			"node": loot_node,
			"ring": ring,
			"beacon": beacon,
			"primary_resource": primary_resource,
		}
		loot_nodes.append(entry)


func get_backpack_used() -> int:
	var total: int = 0
	for res_key: String in RESOURCE_ORDER:
		total += int(backpack.get(res_key, 0))
	return total


func get_backpack_free() -> int:
	return maxi(0, backpack_capacity - get_backpack_used())


func get_stash_total() -> int:
	var total: int = 0
	for res_key: String in RESOURCE_ORDER:
		total += int(train_stash.get(res_key, 0))
	return total


func get_remaining_loot_count() -> int:
	var count: int = 0
	for entry: Dictionary in loot_nodes:
		if not bool(entry.get("looted", false)):
			count += 1
	return count


func get_total_loot_count() -> int:
	return loot_nodes.size()


func find_nearest_unlooted(world_pos: Vector3, max_dist: float = 3.2) -> Dictionary:
	if max_dist <= 0.0:
		return {}
	var best_entry: Dictionary = {}
	var best_dist_sq: float = max_dist * max_dist
	for entry: Dictionary in loot_nodes:
		if bool(entry.get("looted", false)):
			continue
		var pos_raw: Variant = entry.get("pos", Vector3.ZERO)
		var entry_pos: Vector3 = pos_raw if pos_raw is Vector3 else Vector3.ZERO
		var dx: float = entry_pos.x - world_pos.x
		var dz: float = entry_pos.z - world_pos.z
		var dist_sq: float = dx * dx + dz * dz
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_entry = entry
	return best_entry


func collect_loot_point(loot_id: String) -> Dictionary:
	var target_entry: Dictionary = {}
	var found: bool = false
	for entry: Dictionary in loot_nodes:
		if str(entry.get("id", "")) == loot_id:
			target_entry = entry
			found = true
			break

	if not found or bool(target_entry.get("looted", false)):
		return {
			"ok": false,
			"reason": "not_available",
			"gained": {},
			"overflow": {},
			"fully_looted": true,
		}

	var contents_raw: Variant = target_entry.get("contents", {})
	var contents: Dictionary = contents_raw if contents_raw is Dictionary else {}
	var free_slots: int = get_backpack_free()
	if free_slots <= 0:
		return {
			"ok": false,
			"reason": "backpack_full",
			"gained": {},
			"overflow": contents.duplicate(),
			"fully_looted": false,
		}

	var gained: Dictionary = {}
	var remaining_free: int = free_slots
	for res_key: String in RESOURCE_ORDER:
		if remaining_free <= 0:
			break
		var available: int = int(contents.get(res_key, 0))
		if available <= 0:
			continue
		var take: int = mini(available, remaining_free)
		backpack[res_key] = int(backpack.get(res_key, 0)) + take
		gained[res_key] = take
		var leftover: int = available - take
		if leftover > 0:
			contents[res_key] = leftover
		else:
			contents.erase(res_key)
		remaining_free -= take

	var overflow: Dictionary = {}
	var remaining_total: int = 0
	for res_key: String in RESOURCE_ORDER:
		var rem: int = int(contents.get(res_key, 0))
		if rem > 0:
			overflow[res_key] = rem
			remaining_total += rem

	var has_overflow: bool = remaining_total > 0
	if not has_overflow:
		target_entry["looted"] = true
		_apply_looted_visuals(target_entry)

	var label: String = str(target_entry.get("label", ""))
	backpack_changed.emit(backpack.duplicate(), get_backpack_used(), backpack_capacity)
	loot_point_collected.emit(loot_id, label, gained.duplicate(), overflow.duplicate())

	return {
		"ok": true,
		"reason": "partial" if has_overflow else "collected",
		"label": label,
		"gained": gained,
		"overflow": overflow,
		"fully_looted": bool(target_entry.get("looted", false)),
	}


func deposit_backpack_to_stash() -> Dictionary:
	var deposited: Dictionary = {}
	var count: int = 0
	for res_key: String in RESOURCE_ORDER:
		var amount: int = int(backpack.get(res_key, 0))
		if amount > 0:
			train_stash[res_key] = int(train_stash.get(res_key, 0)) + amount
			deposited[res_key] = amount
			count += amount
			backpack[res_key] = 0

	if count > 0:
		backpack_changed.emit(backpack.duplicate(), 0, backpack_capacity)
		stash_changed.emit(train_stash.duplicate(), get_stash_total())
		stash_deposited.emit(deposited.duplicate(), count)

	return {
		"deposited": deposited,
		"count": count,
	}


func format_resource_dict(res: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for res_key: String in RESOURCE_ORDER:
		var amount: int = int(res.get(res_key, 0))
		if amount > 0:
			var meta_raw: Variant = RESOURCE_META.get(res_key, {})
			var meta: Dictionary = meta_raw if meta_raw is Dictionary else {}
			var label: String = str(meta.get("label", res_key))
			parts.append("%s+%d" % [label, amount])
	return "、".join(parts)


func animate_markers(time_elapsed: float) -> void:
	for entry: Dictionary in loot_nodes:
		if bool(entry.get("looted", false)):
			continue
		var beacon_raw: Variant = entry.get("beacon", null)
		if beacon_raw is MeshInstance3D:
			var beacon: MeshInstance3D = beacon_raw as MeshInstance3D
			if is_instance_valid(beacon):
				var base_y: float = float(beacon.get_meta("base_y", BEACON_BASE_Y))
				var phase: float = float(beacon.get_meta("phase", 0.0))
				beacon.position.y = base_y + sin(time_elapsed * 2.6 + phase) * BEACON_BOB_AMPLITUDE
				beacon.rotation.y = fmod(time_elapsed * 1.45 + phase, TAU)

		var ring_raw: Variant = entry.get("ring", null)
		if ring_raw is MeshInstance3D:
			var ring: MeshInstance3D = ring_raw as MeshInstance3D
			if is_instance_valid(ring):
				var ring_phase: float = float(ring.get_meta("phase", 0.0))
				var pulse: float = 1.0 + sin(time_elapsed * 2.6 + ring_phase) * 0.035
				ring.scale = Vector3(pulse, RING_HEIGHT_SCALE, pulse)


func _clear_existing_loot_root() -> void:
	if _loot_root != null and is_instance_valid(_loot_root):
		if _loot_root.get_parent() == self:
			remove_child(_loot_root)
		_loot_root.free()
	_loot_root = null

	var existing: Node = get_node_or_null(LOOT_ROOT_NAME)
	if existing != null and is_instance_valid(existing):
		remove_child(existing)
		existing.free()


func _resolve_resource_key(candidate: String, fallback_idx: int) -> String:
	if RESOURCE_META.has(candidate):
		return candidate
	return RESOURCE_ORDER[fallback_idx % RESOURCE_ORDER.size()]


func _get_resource_color(res_key: String) -> Color:
	var meta_raw: Variant = RESOURCE_META.get(res_key, {})
	var meta: Dictionary = meta_raw if meta_raw is Dictionary else {}
	var color_raw: Variant = meta.get("color", Color(0.8, 0.8, 0.8))
	return color_raw if color_raw is Color else Color(0.8, 0.8, 0.8)


func _generate_loot_contents(primary_resource: String, rng: RandomNumberGenerator) -> Dictionary:
	var total_units: int = rng.randi_range(2, 4)
	var contents: Dictionary = {}

	var use_two_types: bool = false
	if total_units == 2:
		use_two_types = rng.randf() < 0.35
	else:
		use_two_types = rng.randf() < 0.65

	if not use_two_types:
		contents[primary_resource] = total_units
		return contents

	var others: PackedStringArray = PackedStringArray()
	for res_key: String in RESOURCE_ORDER:
		if res_key != primary_resource:
			others.append(res_key)

	var secondary_resource: String = others[rng.randi_range(0, others.size() - 1)]
	var primary_amount: int = 1
	if total_units == 2:
		primary_amount = 1
	elif total_units == 3:
		primary_amount = 2
	else:
		primary_amount = rng.randi_range(2, 3)

	var secondary_amount: int = total_units - primary_amount
	contents[primary_resource] = primary_amount
	contents[secondary_resource] = secondary_amount
	return contents


func _build_loot_prop(loot_id: String, pos: Vector3, primary_resource: String, idx: int) -> Dictionary:
	var primary_color: Color = _get_resource_color(primary_resource)
	var phase: float = float(idx) * 0.85

	var loot_node: Node3D = Node3D.new()
	loot_node.name = "LootPoint_%s" % loot_id
	loot_node.position = pos

	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "GroundRing"
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.82
	ring_mesh.outer_radius = 0.94
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 12
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, RING_BASE_Y, 0.0)
	ring.scale = Vector3(1.0, RING_HEIGHT_SCALE, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.set_meta("phase", phase)

	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(primary_color.r, primary_color.g, primary_color.b, 0.86)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.roughness = 0.35
	ring_mat.emission_enabled = true
	ring_mat.emission = primary_color
	ring_mat.emission_energy_multiplier = 2.4
	ring.material_override = ring_mat
	loot_node.add_child(ring)

	var crate_root: Node3D = Node3D.new()
	crate_root.name = "CrateRoot"
	crate_root.rotation.y = fmod(float(idx) * 0.73, TAU)
	loot_node.add_child(crate_root)

	var crate_body_mat: StandardMaterial3D = StandardMaterial3D.new()
	crate_body_mat.albedo_color = Color(0.24, 0.27, 0.31)
	crate_body_mat.metallic = 0.38
	crate_body_mat.roughness = 0.62

	var crate_body: MeshInstance3D = MeshInstance3D.new()
	crate_body.name = "CrateBody"
	var body_mesh: BoxMesh = BoxMesh.new()
	body_mesh.size = Vector3(0.76, 0.36, 0.58)
	crate_body.mesh = body_mesh
	crate_body.position = Vector3(0.0, 0.18, 0.0)
	crate_body.material_override = crate_body_mat
	crate_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	crate_root.add_child(crate_body)

	var crate_lid_mat: StandardMaterial3D = StandardMaterial3D.new()
	crate_lid_mat.albedo_color = Color(0.32, 0.36, 0.41)
	crate_lid_mat.metallic = 0.42
	crate_lid_mat.roughness = 0.54

	var crate_lid: MeshInstance3D = MeshInstance3D.new()
	crate_lid.name = "CrateLid"
	var lid_mesh: BoxMesh = BoxMesh.new()
	lid_mesh.size = Vector3(0.82, 0.10, 0.64)
	crate_lid.mesh = lid_mesh
	crate_lid.position = Vector3(0.0, 0.40, 0.0)
	crate_lid.material_override = crate_lid_mat
	crate_lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	crate_root.add_child(crate_lid)

	var crate_band_mat: StandardMaterial3D = StandardMaterial3D.new()
	crate_band_mat.albedo_color = primary_color
	crate_band_mat.metallic = 0.25
	crate_band_mat.roughness = 0.40
	crate_band_mat.emission_enabled = true
	crate_band_mat.emission = primary_color
	crate_band_mat.emission_energy_multiplier = 0.95

	var crate_band: MeshInstance3D = MeshInstance3D.new()
	crate_band.name = "CrateBand"
	var band_mesh: BoxMesh = BoxMesh.new()
	band_mesh.size = Vector3(0.84, 0.09, 0.18)
	crate_band.mesh = band_mesh
	crate_band.position = Vector3(0.0, 0.25, 0.0)
	crate_band.material_override = crate_band_mat
	crate_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crate_root.add_child(crate_band)

	var beacon: MeshInstance3D = MeshInstance3D.new()
	beacon.name = "BeaconCrystal"
	var beacon_mesh: SphereMesh = SphereMesh.new()
	beacon_mesh.radius = 0.15
	beacon_mesh.height = 0.38
	beacon_mesh.radial_segments = 4
	beacon_mesh.rings = 2
	beacon.mesh = beacon_mesh
	beacon.position = Vector3(0.0, BEACON_BASE_Y, 0.0)
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.set_meta("base_y", BEACON_BASE_Y)
	beacon.set_meta("phase", phase)

	var beacon_mat: StandardMaterial3D = StandardMaterial3D.new()
	beacon_mat.albedo_color = primary_color.lightened(0.22)
	beacon_mat.roughness = 0.2
	beacon_mat.metallic = 0.15
	beacon_mat.emission_enabled = true
	beacon_mat.emission = primary_color
	beacon_mat.emission_energy_multiplier = 3.0
	beacon.material_override = beacon_mat
	loot_node.add_child(beacon)

	return {
		"node": loot_node,
		"ring": ring,
		"beacon": beacon,
	}


func _apply_looted_visuals(entry: Dictionary) -> void:
	var ring_raw: Variant = entry.get("ring", null)
	if ring_raw is MeshInstance3D:
		var ring: MeshInstance3D = ring_raw as MeshInstance3D
		if is_instance_valid(ring):
			ring.visible = false

	var beacon_raw: Variant = entry.get("beacon", null)
	if beacon_raw is MeshInstance3D:
		var beacon: MeshInstance3D = beacon_raw as MeshInstance3D
		if is_instance_valid(beacon):
			beacon.visible = false

	var node_raw: Variant = entry.get("node", null)
	if not (node_raw is Node3D):
		return
	var loot_node: Node3D = node_raw as Node3D
	if not is_instance_valid(loot_node):
		return

	var crate_root: Node3D = loot_node.get_node_or_null("CrateRoot") as Node3D
	if crate_root == null or not is_instance_valid(crate_root):
		return

	var spent_body_mat: StandardMaterial3D = StandardMaterial3D.new()
	spent_body_mat.albedo_color = Color(0.13, 0.14, 0.15)
	spent_body_mat.metallic = 0.15
	spent_body_mat.roughness = 0.88

	var crate_body: MeshInstance3D = crate_root.get_node_or_null("CrateBody") as MeshInstance3D
	if crate_body != null and is_instance_valid(crate_body):
		crate_body.material_override = spent_body_mat

	var crate_lid: MeshInstance3D = crate_root.get_node_or_null("CrateLid") as MeshInstance3D
	if crate_lid != null and is_instance_valid(crate_lid):
		crate_lid.material_override = spent_body_mat
		crate_lid.position = Vector3(0.0, 0.46, -0.18)
		crate_lid.rotation_degrees = Vector3(-28.0, 0.0, 0.0)

	var crate_band: MeshInstance3D = crate_root.get_node_or_null("CrateBand") as MeshInstance3D
	if crate_band != null and is_instance_valid(crate_band):
		var spent_band_mat: StandardMaterial3D = StandardMaterial3D.new()
		spent_band_mat.albedo_color = Color(0.19, 0.20, 0.21)
		spent_band_mat.metallic = 0.1
		spent_band_mat.roughness = 0.85
		crate_band.material_override = spent_band_mat
