class_name VfxFactory
extends RefCounted


class _VfxUpdater:
	extends Node3D

	var elapsed: float = 0.0
	var duration: float = 0.4
	var on_step: Callable

	func _process(delta: float) -> void:
		elapsed += delta
		var t: float = clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
		if on_step.is_valid():
			on_step.call(t, delta)
		if elapsed >= duration:
			queue_free()


static func _make_unshaded_mat(color: Color, emission_strength: float = 1.6) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b, 1.0)
		mat.emission_energy_multiplier = emission_strength
	return mat


static func _can_spawn(parent: Node3D) -> bool:
	return parent != null and is_instance_valid(parent) and parent.is_inside_tree()


static func spawn_slash(parent: Node3D, pos: Vector3, yaw: float, radius: float, is_combo_finisher: bool) -> void:
	if not _can_spawn(parent):
		return

	var root := _VfxUpdater.new()
	root.duration = 0.30 if is_combo_finisher else 0.22
	parent.add_child(root)
	root.global_position = pos + Vector3(0.0, 1.05, 0.0)
	root.rotation.y = yaw

	var base_color: Color = Color(1.0, 0.68, 0.18, 0.92) if is_combo_finisher else Color(0.82, 0.92, 1.0, 0.85)
	var mat := _make_unshaded_mat(base_color, 2.2 if is_combo_finisher else 1.4)

	var arc_holder := Node3D.new()
	root.add_child(arc_holder)

	var seg_count: int = 10
	var arc_span: float = PI * (1.15 if is_combo_finisher else 0.82)
	var arc_radius: float = maxf(radius * 0.72, 1.2)
	var seg_len: float = (arc_span * arc_radius) / float(seg_count) * 1.15

	for i in range(seg_count):
		var frac: float = float(i) / float(seg_count - 1)
		var angle: float = lerpf(-arc_span * 0.5, arc_span * 0.5, frac)
		var thickness: float = sin(frac * PI) * (0.48 if is_combo_finisher else 0.30) + 0.06

		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(seg_len, 0.07, thickness)
		mesh_inst.mesh = box
		mesh_inst.material_override = mat
		# Forward in Godot is -Z
		mesh_inst.position = Vector3(sin(angle) * arc_radius, 0.0, -cos(angle) * arc_radius)
		mesh_inst.rotation.y = -angle
		arc_holder.add_child(mesh_inst)

	if is_combo_finisher:
		arc_holder.rotation.z = 0.06
	else:
		arc_holder.rotation.z = randf_range(-0.28, 0.28)

	var start_rot: float = -0.55
	var end_rot: float = 0.45
	arc_holder.rotation.y = start_rot

	root.on_step = func(t: float, _delta: float) -> void:
		var ease_t: float = 1.0 - pow(1.0 - t, 3.0)
		arc_holder.rotation.y = lerpf(start_rot, end_rot, ease_t)
		var s: float = lerpf(0.85, 1.18, ease_t)
		arc_holder.scale = Vector3(s, 1.0, s)
		mat.albedo_color.a = base_color.a * (1.0 - t)


static func spawn_ring(parent: Node3D, pos: Vector3, max_radius: float, color: Color, duration: float = 0.45) -> void:
	if not _can_spawn(parent):
		return

	var root := _VfxUpdater.new()
	root.duration = maxf(duration, 0.08)
	parent.add_child(root)
	root.global_position = Vector3(pos.x, pos.y + 0.08, pos.z)

	var mat := _make_unshaded_mat(color, 1.8)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = mat
	ring.scale = Vector3(0.25, 0.22, 0.25)
	root.add_child(ring)

	var initial_alpha: float = clampf(color.a, 0.35, 1.0)
	var target_r: float = maxf(max_radius, 0.5)

	root.on_step = func(t: float, _delta: float) -> void:
		var ease_t: float = 1.0 - pow(1.0 - t, 2.4)
		var r: float = lerpf(0.25, target_r, ease_t)
		ring.scale = Vector3(r, 0.18, r)
		mat.albedo_color.a = initial_alpha * (1.0 - t)


static func spawn_arrow(parent: Node3D, from_pos: Vector3, to_pos: Vector3, color: Color, duration: float = 0.28) -> void:
	if not _can_spawn(parent):
		return

	var root := _VfxUpdater.new()
	root.duration = maxf(duration, 0.08)
	parent.add_child(root)
	root.global_position = from_pos

	var arrow_body := Node3D.new()
	root.add_child(arrow_body)

	var shaft_mat := _make_unshaded_mat(color, 1.5)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 0.95
	cyl.radial_segments = 6
	shaft.mesh = cyl
	shaft.rotation.x = PI * 0.5
	shaft.material_override = shaft_mat
	arrow_body.add_child(shaft)

	var tip_mat := _make_unshaded_mat(Color(1.0, 0.96, 0.85, 1.0), 2.0)
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.075
	tip_mesh.height = 0.24
	tip_mesh.radial_segments = 5
	tip.mesh = tip_mesh
	tip.rotation.x = -PI * 0.5
	tip.position = Vector3(0.0, 0.0, -0.56)
	tip.material_override = tip_mat
	arrow_body.add_child(tip)

	var dist: float = from_pos.distance_to(to_pos)
	var arc_height: float = clampf(dist * 0.18, 0.5, 4.2)

	root.on_step = func(t: float, _delta: float) -> void:
		var cur_pos: Vector3 = from_pos.lerp(to_pos, t)
		cur_pos.y += sin(t * PI) * arc_height
		var next_t: float = minf(t + 0.04, 1.0)
		var next_pos: Vector3 = from_pos.lerp(to_pos, next_t)
		next_pos.y += sin(next_t * PI) * arc_height
		root.global_position = cur_pos
		var dir: Vector3 = next_pos - cur_pos
		if dir.length_squared() > 0.0001:
			arrow_body.look_at(cur_pos + dir.normalized(), Vector3.UP)


static func spawn_floating_text(parent: Node3D, pos: Vector3, text: String, color: Color, font_size: int = 44) -> void:
	if not _can_spawn(parent):
		return

	var root := _VfxUpdater.new()
	root.duration = 0.78
	parent.add_child(root)
	var jitter := Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35))
	var start_pos: Vector3 = pos + Vector3(0.0, 2.0, 0.0) + jitter
	root.global_position = start_pos

	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = font_size
	lbl.pixel_size = 0.011
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = color
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.05, 0.05, 0.08, 0.92)
	root.add_child(lbl)

	root.on_step = func(t: float, _delta: float) -> void:
		var ease_t: float = 1.0 - pow(1.0 - t, 2.0)
		root.global_position = start_pos + Vector3(0.0, 1.45 * ease_t, 0.0)
		var pop: float = 1.18 if t < 0.18 else lerpf(1.18, 0.92, (t - 0.18) / 0.82)
		lbl.scale = Vector3.ONE * pop
		var alpha: float = 1.0 if t < 0.5 else clampf(1.0 - (t - 0.5) / 0.5, 0.0, 1.0)
		lbl.modulate.a = alpha
		lbl.outline_modulate.a = alpha * 0.92


static func spawn_death_burst(parent: Node3D, pos: Vector3, color: Color, count: int = 8) -> void:
	if not _can_spawn(parent):
		return

	var root := _VfxUpdater.new()
	root.duration = 0.58
	parent.add_child(root)
	root.global_position = pos + Vector3(0.0, 0.8, 0.0)

	var mat := _make_unshaded_mat(color, 1.2)
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.24, 0.24, 0.24)

	var shards: Array[MeshInstance3D] = []
	var velocities: Array[Vector3] = []
	var spin_axes: Array[Vector3] = []

	var shard_count: int = maxi(count, 1)
	for i in range(shard_count):
		var shard := MeshInstance3D.new()
		shard.mesh = box_mesh
		shard.material_override = mat
		shard.scale = Vector3.ONE * randf_range(0.65, 1.35)
		root.add_child(shard)
		shards.append(shard)

		var angle: float = (TAU / float(shard_count)) * float(i) + randf_range(-0.35, 0.35)
		var speed: float = randf_range(2.8, 6.2)
		velocities.append(Vector3(cos(angle) * speed, randf_range(3.2, 6.5), sin(angle) * speed))
		spin_axes.append(Vector3(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0), randf_range(-7.0, 7.0)))

	root.on_step = func(t: float, delta: float) -> void:
		var fade_scale: float = clampf(1.0 - t * 0.85, 0.05, 1.0)
		for i in range(shards.size()):
			var vel: Vector3 = velocities[i]
			vel.y -= 14.0 * delta
			velocities[i] = vel
			var shard: MeshInstance3D = shards[i]
			shard.position += vel * delta
			if shard.position.y < -0.7:
				shard.position.y = -0.7
				velocities[i].y = absf(vel.y) * 0.3
			shard.rotation += spin_axes[i] * delta
			shard.scale = Vector3.ONE * fade_scale
		mat.albedo_color.a = clampf(1.0 - t, 0.0, 1.0)


static func spawn_charge_trail(parent: Node3D, from_pos: Vector3, to_pos: Vector3, color: Color) -> void:
	if not _can_spawn(parent):
		return

	var delta_vec: Vector3 = to_pos - from_pos
	delta_vec.y = 0.0
	var length: float = maxf(delta_vec.length(), 0.5)
	var mid_pos: Vector3 = (from_pos + to_pos) * 0.5

	var root := _VfxUpdater.new()
	root.duration = 0.38
	parent.add_child(root)
	root.global_position = Vector3(mid_pos.x, 0.14, mid_pos.z)

	var yaw: float = atan2(delta_vec.x, delta_vec.z)
	root.rotation.y = yaw

	var mat := _make_unshaded_mat(color, 1.9)
	var ribbon := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.15, 0.08, length)
	ribbon.mesh = box
	ribbon.material_override = mat
	root.add_child(ribbon)

	var core_mat := _make_unshaded_mat(Color(1.0, 0.96, 0.82, 0.85), 2.3)
	var core := MeshInstance3D.new()
	var core_box := BoxMesh.new()
	core_box.size = Vector3(0.42, 0.11, length * 0.96)
	core.mesh = core_box
	core.material_override = core_mat
	root.add_child(core)

	root.on_step = func(t: float, _delta: float) -> void:
		var shrink_x: float = lerpf(1.0, 0.15, t)
		ribbon.scale = Vector3(shrink_x, 1.0, 1.0)
		core.scale = Vector3(shrink_x, 1.0, 1.0)
		mat.albedo_color.a = clampf(color.a * (1.0 - t), 0.0, 1.0)
		core_mat.albedo_color.a = clampf(0.85 * (1.0 - t), 0.0, 1.0)
