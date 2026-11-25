class_name StickmanFactory
extends RefCounted

# Procedural articulated 3D Stickman (火柴人) rig builder used for ALL non-player characters:
# - Working NPC crew inside the Armored Train
# - Trapped Survivors in the Sector
# - Horde Zombies (Walker / Runner / Brute / Bloater)


static func create_stickman(options: Dictionary = {}) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.name = str(options.get("name", "StickmanRig"))

	var body_color: Color = options.get("body_color", Color(0.16, 0.18, 0.22)) as Color
	var head_color: Color = options.get("head_color", Color(0.95, 0.94, 0.90)) as Color
	var accent_color: Color = options.get("accent_color", Color(0.36, 0.88, 1.0)) as Color
	var eye_color: Color = options.get("eye_color", Color(0.10, 0.12, 0.16)) as Color
	var emit_eyes: bool = bool(options.get("emit_eyes", false))
	var limb_thickness: float = float(options.get("limb_thickness", 0.065))
	var accessory: String = str(options.get("accessory", "none"))  # "none", "wrench", "hardhat", "clipboard", "backpack", "zombie"

	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.65

	var head_mat: StandardMaterial3D = StandardMaterial3D.new()
	head_mat.albedo_color = head_color
	head_mat.roughness = 0.55

	var accent_mat: StandardMaterial3D = StandardMaterial3D.new()
	accent_mat.albedo_color = accent_color
	accent_mat.roughness = 0.42
	accent_mat.metallic = 0.25

	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.albedo_color = eye_color
	if emit_eyes:
		eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye_mat.emission_enabled = true
		eye_mat.emission = eye_color
		eye_mat.emission_energy_multiplier = 2.8

	# Pelvis / Spine pivot
	var torso_pivot: Node3D = Node3D.new()
	torso_pivot.name = "TorsoPivot"
	torso_pivot.position = Vector3(0.0, 0.82, 0.0)
	root.add_child(torso_pivot)

	# Stick Torso
	var torso: MeshInstance3D = _cyl(torso_pivot, "Torso", limb_thickness * 1.15, 0.68, Vector3(0.0, 0.34, 0.0), body_mat)

	# Optional high-visibility vest / role stripe around stick torso
	if accessory != "zombie":
		_cyl(torso_pivot, "RoleVest", limb_thickness * 1.55, 0.34, Vector3(0.0, 0.36, 0.0), accent_mat)

	# Shoulder crossbar (classic stickman silhouette!)
	_cyl(torso_pivot, "Shoulders", limb_thickness * 0.9, 0.46, Vector3(0.0, 0.62, 0.0), body_mat, Vector3(0.0, 0.0, 90.0))

	# Head pivot
	var head_pivot: Node3D = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 0.72, 0.0)
	torso_pivot.add_child(head_pivot)

	var head: MeshInstance3D = _sphere(head_pivot, "Head", 0.21, Vector3(0.0, 0.20, 0.0), head_mat)
	var eye_l: MeshInstance3D = _sphere(head_pivot, "EyeL", 0.036, Vector3(-0.075, 0.22, -0.18), eye_mat)
	var eye_r: MeshInstance3D = _sphere(head_pivot, "EyeR", 0.036, Vector3(0.075, 0.22, -0.18), eye_mat)

	# Left & Right Arm Pivots
	var left_arm: Node3D = Node3D.new()
	left_arm.name = "LeftArm"
	left_arm.position = Vector3(-0.24, 0.62, 0.0)
	torso_pivot.add_child(left_arm)
	_cyl(left_arm, "LeftArmLimb", limb_thickness * 0.88, 0.62, Vector3(0.0, -0.30, 0.0), body_mat)
	_sphere(left_arm, "LeftHand", limb_thickness * 1.15, Vector3(0.0, -0.62, 0.0), head_mat)

	var right_arm: Node3D = Node3D.new()
	right_arm.name = "RightArm"
	right_arm.position = Vector3(0.24, 0.62, 0.0)
	torso_pivot.add_child(right_arm)
	_cyl(right_arm, "RightArmLimb", limb_thickness * 0.88, 0.62, Vector3(0.0, -0.30, 0.0), body_mat)
	_sphere(right_arm, "RightHand", limb_thickness * 1.15, Vector3(0.0, -0.62, 0.0), head_mat)

	# Left & Right Leg Pivots (attached to root at hip height)
	var left_leg: Node3D = Node3D.new()
	left_leg.name = "LeftLeg"
	left_leg.position = Vector3(-0.13, 0.82, 0.0)
	root.add_child(left_leg)
	_cyl(left_leg, "LeftLegLimb", limb_thickness * 0.95, 0.82, Vector3(0.0, -0.41, 0.0), body_mat)
	_sphere(left_leg, "LeftFoot", limb_thickness * 1.2, Vector3(0.0, -0.80, -0.04), body_mat)

	var right_leg: Node3D = Node3D.new()
	right_leg.name = "RightLeg"
	right_leg.position = Vector3(0.13, 0.82, 0.0)
	root.add_child(right_leg)
	_cyl(right_leg, "RightLegLimb", limb_thickness * 0.95, 0.82, Vector3(0.0, -0.41, 0.0), body_mat)
	_sphere(right_leg, "RightFoot", limb_thickness * 1.2, Vector3(0.0, -0.80, -0.04), body_mat)

	# Optional Role Accessories for instant visual personality!
	if accessory == "hardhat" or accessory == "wrench":
		_cyl(head_pivot, "HardHatBrim", 0.26, 0.06, Vector3(0.0, 0.34, 0.0), accent_mat)
		_sphere(head_pivot, "HardHatDome", 0.22, Vector3(0.0, 0.34, 0.0), accent_mat)
	if accessory == "wrench":
		var tool_mat: StandardMaterial3D = StandardMaterial3D.new()
		tool_mat.albedo_color = Color(0.76, 0.80, 0.86)
		tool_mat.metallic = 0.85
		tool_mat.roughness = 0.28
		_box(right_arm, "WrenchShaft", Vector3(0.05, 0.05, 0.42), Vector3(0.0, -0.62, -0.18), tool_mat)
		_box(right_arm, "WrenchJaw", Vector3(0.14, 0.06, 0.10), Vector3(0.0, -0.62, -0.38), tool_mat)
	elif accessory == "clipboard":
		var board_mat: StandardMaterial3D = StandardMaterial3D.new()
		board_mat.albedo_color = Color(0.82, 0.72, 0.52)
		_box(left_arm, "Clipboard", Vector3(0.24, 0.03, 0.32), Vector3(0.0, -0.58, -0.14), board_mat)
	elif accessory == "backpack":
		_box(torso_pivot, "SurvivorPack", Vector3(0.32, 0.40, 0.18), Vector3(0.0, 0.38, 0.16), accent_mat)

	return {
		"root": root,
		"torso": torso_pivot,
		"torso_mesh": torso,
		"head": head_pivot,
		"head_mesh": head,
		"left_arm": left_arm,
		"right_arm": right_arm,
		"left_leg": left_leg,
		"right_leg": right_leg,
		"eye_l": eye_l,
		"eye_r": eye_r,
		"body_mat": body_mat,
		"head_mat": head_mat,
		"accent_mat": accent_mat,
		"eye_mat": eye_mat,
	}


static func _cyl(parent: Node3D, node_name: String, r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, node_name: String, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 8
	mi.mesh = sm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, node_name: String, sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
