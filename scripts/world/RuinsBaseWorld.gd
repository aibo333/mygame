class_name RuinsBaseWorld
extends Node3D

# Retro Urban City Block built 100% from Kenney Retro Urban Kit (TILE = 3.2m modular grid!)
const TILE: float = 3.2
const KIT: String = "res://assets/packs/kenney_retro_urban/"

var env_root: Node3D = null
var squad_root: Node3D = null
var vfx_root: Node3D = null
var camera_rig: LolCameraController = null
var hud: SquadHud = null

var squad: Array[SquadCharacter] = []
var active_index: int = 0
var sync_all_preview: bool = false

var _aim_cursor: MeshInstance3D = null
var _station_markers: Array[Dictionary] = []
var _flicker_lamps: Array[OmniLight3D] = []
var _model_cache: Dictionary = {}
var _time_elapsed: float = 0.0


func _ready() -> void:
	_setup_retro_urban_environment()
	_setup_world_geometry()
	_setup_squad_and_camera()
	_setup_hud()


func _setup_retro_urban_environment() -> void:
	# Warm Late-Afternoon / Retro PS1-PS2 Urban Atmosphere inspired by Kenney Sample.png & Project Zomboid!
	var we := WorldEnvironment.new()
	we.name = "RetroUrbanEnvironment"
	var env := Environment.new()

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.24, 0.34)
	sky_mat.sky_horizon_color = Color(0.66, 0.54, 0.48)
	sky_mat.ground_bottom_color = Color(0.14, 0.14, 0.17)
	sky_mat.ground_horizon_color = Color(0.36, 0.32, 0.32)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.23, 0.28)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.62, 0.74)
	env.ambient_light_energy = 0.85

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.36
	env.glow_bloom = 0.12

	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.40, 0.46)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.2

	we.environment = env
	add_child(we)

	# Crisp warm late-afternoon sun casting clean architectural shadows across the brick & asphalt!
	var sun := DirectionalLight3D.new()
	sun.name = "UrbanSunLight"
	sun.light_color = Color(1.0, 0.87, 0.72)
	sun.light_energy = 1.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.03
	sun.rotation_degrees = Vector3(-44.0, -32.0, 0.0)
	add_child(sun)

	# Cool slate sky rim fill from opposite angle so dark sides stay readable
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFillLight"
	fill.light_color = Color(0.58, 0.70, 0.92)
	fill.light_energy = 0.55
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	add_child(fill)


func _setup_world_geometry() -> void:
	env_root = Node3D.new()
	env_root.name = "KenneyRetroUrbanDistrict"
	add_child(env_root)

	vfx_root = Node3D.new()
	vfx_root.name = "VfxRoot"
	add_child(vfx_root)

	_build_ground_collider()
	_build_kenney_roads_and_terrain()
	_build_kenney_industrial_factory_block()
	_build_kenney_brick_workshop_and_yard()
	_build_kenney_east_apartment_and_garage()
	_build_kenney_street_props_and_park()
	_build_interactive_stations()
	_build_aim_cursor()


func _build_ground_collider() -> void:
	# Invisible solid collision floor under the entire Kenney tile grid
	_add_invisible_collider(env_root, "MainGroundCollider", Vector3(96.0, 0.4, 96.0), Vector3(0.0, -0.2, 0.0))


func _spawn_kenney(
	asset_name: String,
	gx: float,
	gy: float,
	gz: float,
	rot_y_deg: float = 0.0,
	extra_scale: float = 1.0,
	collider_tiles: Vector3 = Vector3.ZERO
) -> Node3D:
	var path: String = KIT + asset_name + ".glb"
	var packed: PackedScene = _model_cache.get(path, null) as PackedScene
	if packed == null and ResourceLoader.exists(path):
		packed = load(path) as PackedScene
		_model_cache[path] = packed

	var holder := Node3D.new()
	holder.name = "%s_%d_%d" % [asset_name, int(round(gx * 10)), int(round(gz * 10))]
	holder.position = Vector3(gx * TILE, gy * TILE, gz * TILE)
	holder.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	env_root.add_child(holder)

	if packed != null:
		var inst := packed.instantiate()
		if inst is Node3D:
			(inst as Node3D).scale = Vector3.ONE * (TILE * extra_scale)
		holder.add_child(inst)
	else:
		push_warning("RuinsBaseWorld: Missing Kenney GLB %s" % path)

	if collider_tiles.length_squared() > 0.001:
		var csize := collider_tiles * TILE
		_add_invisible_collider(holder, holder.name + "_Col", csize, Vector3(0.0, csize.y * 0.5, 0.0))

	return holder


func _build_kenney_roads_and_terrain() -> void:
	# 16 x 12 Modular Retro Urban Grid (gx = -8..+7, gz = -5..+6)
	# Main East-West Asphalt Avenue along gz = +1 (north lane) and gz = +2 (south lane)
	# North-South Cross Street / Loading Access along gx = +2 (west lane) and gx = +3 (east lane)
	for gx in range(-8, 8):
		for gz in range(-5, 7):
			var on_ew_road: bool = (gz == 1 or gz == 2)
			var on_ns_road: bool = (gx == 2 or gx == 3) and gz >= -4

			if on_ew_road and on_ns_road:
				# Crisp intersection asphalt center
				_spawn_kenney("road-asphalt-center", gx, 0.0, gz)
			elif on_ew_road:
				# East-West asphalt avenue with raised curbs on north (gz=1) & south (gz=2)
				if gz == 1:
					_spawn_kenney("road-asphalt-side", gx, 0.0, gz, 180.0)
				else:
					_spawn_kenney("road-asphalt-side", gx, 0.0, gz, 0.0)
			elif on_ns_road:
				# North-South cross-street
				if gx == 2:
					_spawn_kenney("road-asphalt-side", gx, 0.0, gz, 90.0)
				else:
					_spawn_kenney("road-asphalt-side", gx, 0.0, gz, -90.0)
			elif gz >= 4 and gx <= -3:
				# South-West autumn grass & dirt corner lot (classic Kenney / Zomboid neighborhood edge!)
				if gx == -3:
					_spawn_kenney("road-dirt-side", gx, 0.0, gz, 90.0)
				elif gz == 4:
					_spawn_kenney("road-dirt-side", gx, 0.0, gz, 180.0)
				else:
					_spawn_kenney("grass", gx, 0.0, gz)
			elif gz >= 5 and gx >= 5:
				# South-East grassy park corner
				_spawn_kenney("grass", gx, 0.0, gz)
			else:
				# Concrete urban sidewalk & industrial concrete yard slabs
				var is_damaged: bool = ((gx * 7 + gz * 13) % 11 == 0) and gz >= 0
				_spawn_kenney("road-asphalt-damaged" if is_damaged else "road-asphalt-pavement", gx, 0.0, gz)


func _build_kenney_industrial_factory_block() -> void:
	# Hero Landmark: Multi-story Sage-Green Sawtooth-Roof Industrial Factory (inspired directly by Kenney Sample.png!)
	# Footprint: gx = -6..-3, gz = -4..-2 (back-left dominant skyline!)
	for gx in range(-6, -2):
		for gz in range(-4, -1):
			# Ground floor (gy = 0)
			var ground_piece := "wall-b"
			var rot := 180.0
			if gz == -2:
				ground_piece = "wall-b-garage" if (gx == -5 or gx == -4) else "wall-b-door"
			elif gx == -3:
				ground_piece = "wall-b-window"
				rot = -90.0
			_spawn_kenney(ground_piece, gx, 0.0, gz, rot, 1.0, Vector3(1.0, 1.0, 1.0))

			# Second floor (gy = 1) with industrial windows facing the street
			var f2_piece := "wall-b-window" if (gz == -2 or gx == -3) else "wall-b"
			var f2_rot := 180.0 if gz == -2 else (-90.0 if gx == -3 else 0.0)
			_spawn_kenney(f2_piece, gx, 1.0, gz, f2_rot)

			# Iconic Sawtooth Slanted Metal Roofs (gy = 2)
			var roof_piece := "wall-b-roof-slant-detailed" if (gx % 2 == 0) else "wall-b-roof-slant"
			_spawn_kenney(roof_piece, gx, 2.0, gz, 180.0)

	# Towering 3rd-story penthouse monitor roof on rear factory spine
	_spawn_kenney("wall-b-window", -5, 2.0, -4, 180.0)
	_spawn_kenney("wall-b-roof-detailed", -5, 3.0, -4, 180.0)

	# Iconic 3-Story Steel Scaffolding Tower right behind the factory corner (just like Sample.png!)
	for gy in range(0, 3):
		_spawn_kenney("scaffolding-structure", -2, float(gy), -4, 0.0, 1.0, Vector3(0.9, 1.0, 0.9) if gy == 0 else Vector3.ZERO)
		_spawn_kenney("scaffolding-floor", -2, float(gy + 1), -4, 0.0)
	_spawn_kenney("detail-barrier-type-a", -3, 2.0, -2, 0.0)

	# Side industrial awning over factory loading door
	_spawn_kenney("detail-awning-wide", -3, 0.88, -1.45, 0.0)


func _build_kenney_brick_workshop_and_yard() -> void:
	# Gritty Red-Brick Corner Workshop & Loading Yard (gx = -2..+1, gz = -3..-1)
	# 2-story Red-Brick Garage / Corner Watchtower facing the avenue
	_spawn_kenney("wall-a-garage", -2, 0.0, -1, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
	_spawn_kenney("wall-a-window", -2, 1.0, -1, 180.0)
	_spawn_kenney("wall-a-roof-detailed", -2, 2.0, -1, 90.0)
	# Fire escape balcony & iron ladder on brick corner!
	_spawn_kenney("balcony-type-a", -2, 1.0, -0.45, 180.0)
	_spawn_kenney("balcony-ladder-bottom", -2.55, 0.0, -1.0, 90.0)

	# Adjacent single-story brick storefront garage bay
	_spawn_kenney("wall-a-garage", -1, 0.0, -1, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
	_spawn_kenney("wall-a-roof-slant", -1, 1.0, -1, 180.0)

	# Fenced Industrial Loading Yard on gx = 0..+1, gz = -3..-1
	# Perimeter iron security fences along rear & west yard edge
	_spawn_kenney("wall-fence", 0, 0.0, -3.45, 0.0, 1.0, Vector3(1.0, 0.6, 0.2))
	_spawn_kenney("wall-fence", 1, 0.0, -3.45, 0.0, 1.0, Vector3(1.0, 0.6, 0.2))
	_spawn_kenney("wall-fence", -0.5, 0.0, -2.0, 90.0, 1.0, Vector3(0.2, 0.6, 1.0))
	_spawn_kenney("wall-fence", -0.5, 0.0, -3.0, 90.0, 1.0, Vector3(0.2, 0.6, 1.0))

	# Parked Teal Cargo Truck & Detached Shipping Container inside the Loading Yard!
	_spawn_kenney("truck-green", 0.5, 0.0, -2.0, 0.0, 1.0, Vector3(0.9, 1.0, 1.65))
	_spawn_kenney("truck-green-cargo", 1.8, 0.0, -2.8, 90.0, 1.0, Vector3(1.2, 0.8, 0.85))
	_spawn_kenney("pallet", 0.5, 0.0, -0.6, 12.0, 0.55)
	_spawn_kenney("pallet-small", 1.1, 0.0, -0.65, -18.0, 0.55)

	# Covered corrugated metal shelter beside the western yard edge
	_spawn_kenney("roof-metal-poles", -6, 0.0, -1, 0.0)
	_spawn_kenney("roof-metal-poles", -7, 0.0, -1, 0.0)
	_spawn_kenney("detail-bricks-type-a", -6.2, 0.0, -0.4, 25.0)
	_spawn_kenney("detail-dumpster-open", -1.0, 0.0, -0.1, 180.0, 1.0, Vector3(0.65, 0.6, 0.5))


func _build_kenney_east_apartment_and_garage() -> void:
	# East Block (gx = +4..+6, gz = -4..-1): Red-Brick Corner Townhouse + Sage-Green Auto Garage
	# Tall 3-story brick apartment corner tower
	_spawn_kenney("wall-a-door", 4, 0.0, -1, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
	_spawn_kenney("wall-a-window", 4, 1.0, -1, 180.0)
	_spawn_kenney("wall-a-painted", 4, 2.0, -1, 180.0)
	_spawn_kenney("wall-a-roof-detailed", 4, 3.0, -1, 0.0)
	_spawn_kenney("balcony-type-a", 4, 1.0, -0.45, 180.0)

	# Connected 2-story brick commercial wing
	_spawn_kenney("wall-a-window", 5, 0.0, -1, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
	_spawn_kenney("wall-a-window", 5, 1.0, -1, 180.0)
	_spawn_kenney("wall-a-roof", 5, 2.0, -1, 0.0)
	_spawn_kenney("detail-awning-wide", 5, 0.85, -0.45, 180.0)

	# Rear Sage-Green Auto Garage + Carport Shed
	_spawn_kenney("wall-b-garage", 4, 0.0, -3, 90.0, 1.0, Vector3(1.0, 1.0, 1.0))
	_spawn_kenney("wall-b-roof-detailed", 4, 1.0, -3, 90.0)
	_spawn_kenney("wall-b", 5, 0.0, -3, 180.0, 1.0, Vector3(1.0, 1.0, 1.0))
	_spawn_kenney("wall-b-roof", 5, 1.0, -3, 90.0)
	_spawn_kenney("roof-metal-poles", 6, 0.0, -3, 90.0)

	# Grey Delivery Truck parked along the east alley + spare container
	_spawn_kenney("truck-grey", 5.8, 0.0, -1.8, 90.0, 1.0, Vector3(1.65, 1.0, 0.9))
	_spawn_kenney("truck-grey-cargo", 6.2, 0.0, -0.2, 0.0, 1.0, Vector3(0.85, 0.8, 1.2))
	_spawn_kenney("detail-dumpster-closed", 4.6, 0.0, -2.0, 0.0, 1.0, Vector3(0.65, 0.6, 0.5))


func _build_kenney_street_props_and_park() -> void:
	# 1. Tactical Roadblock Checkpoint & Parked Flatbed Truck on the Main Avenue (gz = 1..2)
	_spawn_kenney("truck-flat", -3.8, 0.0, 1.2, 82.0, 1.0, Vector3(1.6, 1.0, 0.9))
	_spawn_kenney("detail-barrier-strong-type-a", -3.0, 0.0, 2.1, 12.0, 1.0, Vector3(0.7, 0.4, 0.3))
	_spawn_kenney("detail-barrier-strong-damaged", -2.2, 0.0, 2.3, -15.0, 1.0, Vector3(0.7, 0.4, 0.3))
	_spawn_kenney("detail-barrier-type-a", -3.4, 0.0, 0.4, 24.0)
	_spawn_kenney("detail-beam", -4.6, 0.0, 2.4, 65.0)

	# East Avenue Cover Cluster
	_spawn_kenney("detail-barrier-strong-type-b", 4.5, 0.0, 2.2, -10.0, 1.0, Vector3(0.7, 0.4, 0.3))
	_spawn_kenney("detail-block", 5.3, 0.0, 2.1, 8.0, 1.0, Vector3(0.6, 0.5, 0.6))
	_spawn_kenney("planks", 4.9, 0.0, 0.5, 32.0)

	# 2. Low Foreground Broken Brick Walls, Iron Fences & Covered Bus-Stop Shelter (kept low so camera is NEVER blocked!)
	_spawn_kenney("wall-broken-type-a", -5, 0.0, 3.4, 0.0, 1.0, Vector3(1.0, 0.5, 0.2))
	_spawn_kenney("wall-broken-type-b", -4, 0.0, 3.4, 0.0, 1.0, Vector3(1.0, 0.5, 0.2))
	_spawn_kenney("wall-fence", 0, 0.0, 3.4, 0.0, 1.0, Vector3(1.0, 0.6, 0.2))
	_spawn_kenney("wall-fence", 1, 0.0, 3.4, 0.0, 1.0, Vector3(1.0, 0.6, 0.2))
	_spawn_kenney("roof-metal-poles", -6, 0.0, 3.6, 0.0)
	_spawn_kenney("detail-bench", -6, 0.0, 3.6, 0.0)
	_spawn_kenney("detail-bench", 0.5, 0.0, 3.1, 180.0)

	# Supply pallets & crates on south-east sidewalk (Station 4!)
	_spawn_kenney("pallet", 3.5, 0.0, 3.5, 8.0, 0.55)
	_spawn_kenney("pallet-small", 4.1, 0.0, 3.6, -22.0, 0.55)
	_spawn_kenney("detail-bricks-type-b", 3.0, 0.0, 4.1, 15.0)

	# 3. Autumn Golden Trees, Dark Pines & Shrubs Framing the Urban Block (iconic Kenney color contrast!)
	_spawn_kenney("tree-park-large", -7.2, 0.0, -0.5, 15.0, 1.15)
	_spawn_kenney("tree-large", -5.8, 0.0, 4.8, 40.0, 1.2)
	_spawn_kenney("tree-pine-large", -4.4, 0.0, 5.2, 10.0, 1.15)
	_spawn_kenney("tree-shrub", -3.6, 0.0, 4.3, 25.0)
	_spawn_kenney("tree-large", 6.4, 0.0, -4.2, -30.0, 1.2)
	_spawn_kenney("tree-park-pine-large", 5.8, 0.0, 4.8, 20.0, 1.15)
	_spawn_kenney("tree-small", 4.8, 0.0, 4.5, 55.0)
	_spawn_kenney("tree-large", 0.8, 0.0, -4.4, 75.0, 1.1)

	# 4. Streetlights, Traffic Light & Overhead Power Cables with Warm Dusk Pools of Light!
	var lamp_specs: Array[Dictionary] = [
		{"asset": "detail-light-single", "gx": -4.5, "gz": 0.4, "rot": 180.0, "lit": true},
		{"asset": "detail-light-traffic", "gx": 1.6, "gz": 0.4, "rot": -90.0, "lit": true},
		{"asset": "detail-light-single", "gx": 4.2, "gz": 0.4, "rot": 180.0, "lit": true},
		{"asset": "detail-light-double", "gx": -1.5, "gz": 3.2, "rot": 0.0, "lit": true},
		{"asset": "detail-light-single", "gx": 5.5, "gz": 3.2, "rot": 0.0, "lit": false},
	]
	for i in range(lamp_specs.size()):
		var ls: Dictionary = lamp_specs[i]
		_spawn_kenney(str(ls["asset"]), float(ls["gx"]), 0.0, float(ls["gz"]), float(ls["rot"]), 1.25)
		if bool(ls["lit"]):
			var light := OmniLight3D.new()
			light.name = "UrbanLampGlow_%d" % i
			light.light_color = Color(1.0, 0.80, 0.50)
			light.light_energy = 2.6
			light.omni_range = 10.5
			light.position = Vector3(float(ls["gx"]) * TILE, 3.8, float(ls["gz"]) * TILE)
			env_root.add_child(light)
			_flicker_lamps.append(light)

	# Sagging urban power cables slung between factory & east building
	_spawn_kenney("detail-cables-type-a", 1.5, 1.65, -1.0, 0.0, 1.4)
	_spawn_kenney("detail-cables-type-b", 3.0, 1.65, -1.0, 0.0, 1.4)


func _build_interactive_stations() -> void:
	for st in SquadConfig.get_interactive_stations():
		var pos: Vector3 = st["pos"]
		var ring := MeshInstance3D.new()
		ring.name = "InteractRing_" + str(st["id"])
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.06
		torus.rings = 28
		torus.ring_segments = 8
		ring.mesh = torus
		ring.position = Vector3(pos.x, 0.18, pos.z)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.28, 0.88, 1.0, 0.72)
		mat.emission_enabled = true
		mat.emission = Color(0.28, 0.88, 1.0)
		mat.emission_energy_multiplier = 1.6
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		env_root.add_child(ring)

		var entry := st.duplicate()
		entry["ring"] = ring
		_station_markers.append(entry)


func _build_aim_cursor() -> void:
	_aim_cursor = MeshInstance3D.new()
	_aim_cursor.name = "GroundAimCursor"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.31
	torus.rings = 20
	torus.ring_segments = 6
	_aim_cursor.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.90, 0.45, 0.88)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.35)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_cursor.material_override = mat
	_aim_cursor.position = Vector3(0.0, 0.18, 0.0)
	add_child(_aim_cursor)


func _setup_squad_and_camera() -> void:
	squad_root = Node3D.new()
	squad_root.name = "SquadRoot"
	add_child(squad_root)

	for char_id in SquadConfig.get_squad_ids():
		var cfg: Dictionary = SquadConfig.get_character(char_id)
		var girl := SquadCharacter.new()
		girl.name = "Girl_" + char_id
		squad_root.add_child(girl)
		girl.setup(cfg, vfx_root)
		girl.global_position = cfg["spawn_pos"]
		girl.action_changed.connect(_on_character_action_changed)
		girl.interaction_completed.connect(_on_interaction_completed)
		squad.append(girl)

	camera_rig = LolCameraController.new()
	camera_rig.name = "LolCameraController"
	add_child(camera_rig)
	camera_rig.lock_mode_changed.connect(_on_camera_lock_changed)
	camera_rig.projection_mode_changed.connect(_on_camera_projection_changed)

	select_character(0, true)


func _setup_hud() -> void:
	hud = SquadHud.new()
	hud.name = "SquadHud"
	add_child(hud)
	hud.setup(squad)
	hud.character_selected.connect(func(idx: int): select_character(idx, false))
	hud.action_preview_requested.connect(_on_hud_action_preview)
	hud.sync_all_toggled.connect(func(enabled: bool): sync_all_preview = enabled)
	hud.camera_lock_toggled.connect(func(): camera_rig.toggle_camera_lock())
	hud.camera_projection_toggled.connect(func(): camera_rig.toggle_projection_mode())
	hud.camera_recenter_requested.connect(func(): camera_rig.recenter_on_target())
	hud.set_active_character(active_index)
	hud.set_camera_locked(camera_rig.camera_locked)
	hud.set_camera_orthographic(camera_rig.is_orthographic)


func select_character(idx: int, snap_camera: bool = false) -> void:
	if squad.is_empty():
		return
	active_index = clampi(idx, 0, squad.size() - 1)
	var leader := squad[active_index]

	var follower_offsets: Array[Vector3] = [Vector3(-2.3, 0.0, 1.5), Vector3(2.3, 0.0, 1.5)]
	var f_slot := 0
	for i in range(squad.size()):
		var g := squad[i]
		if i == active_index:
			g.set_active(true)
			g.set_follow_leader(null, Vector3.ZERO)
		else:
			g.set_active(false)
			g.set_follow_leader(leader, follower_offsets[f_slot % follower_offsets.size()])
			f_slot += 1

	if camera_rig != null:
		camera_rig.set_follow_target(leader, snap_camera)
	if hud != null:
		hud.set_active_character(active_index)
		hud.push_status("切換操控：%s（%s）" % [leader.display_name, leader.weapon_label])


func get_active_character() -> SquadCharacter:
	if squad.is_empty():
		return null
	return squad[active_index]


func _on_hud_action_preview(action_name: String) -> void:
	if sync_all_preview:
		for g in squad:
			g.trigger_preview_action(action_name)
		if hud != null:
			hud.push_status("全員同步預覽動作：%s" % _action_zh(action_name))
	else:
		var active := get_active_character()
		if active != null:
			active.trigger_preview_action(action_name)
			if hud != null:
				hud.push_status("%s 執行動作：%s" % [active.display_name, _action_zh(action_name)])


func _on_character_action_changed(char_id: String, action_name: String) -> void:
	if hud != null:
		hud.update_character_action(char_id, action_name)


func _on_interaction_completed(char_id: String, station_label: String) -> void:
	var who := char_id
	for g in squad:
		if g.char_id == char_id:
			who = g.display_name
			break
	if hud != null:
		hud.push_status("✓ %s 完成了【%s】操作！" % [who, station_label])


func _on_camera_lock_changed(locked: bool) -> void:
	if hud != null:
		hud.set_camera_locked(locked)


func _on_camera_projection_changed(is_ortho: bool) -> void:
	if hud != null:
		hud.set_camera_orthographic(is_ortho)
		hud.push_status("視角切換為：%s" % ("Zomboid 45° 正交等角" if is_ortho else "RO / HD-2D 透視"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				select_character(0)
			KEY_2:
				select_character(1)
			KEY_3:
				select_character(2)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and camera_rig != null:
			var click_pos: Vector3 = camera_rig.raycast_ground(mb.position, 0.0)
			var active := get_active_character()
			if active != null:
				active.set_click_move_target(click_pos)
				_spawn_move_ping(click_pos)


func _physics_process(delta: float) -> void:
	_time_elapsed += delta
	_animate_urban_lights()

	if squad.is_empty() or camera_rig == null:
		return

	var active := get_active_character()
	var vp := get_viewport()
	var aim_pos := active.global_position + Vector3.RIGHT * 4.0
	if vp != null:
		aim_pos = camera_rig.raycast_ground(vp.get_mouse_position(), 0.0)

	if _aim_cursor != null:
		_aim_cursor.global_position = Vector3(aim_pos.x, 0.18, aim_pos.z)

	# Align WASD & standee billboards cleanly to active camera angle (works in both 45° Zomboid & 0° RO views!)
	var axes: Dictionary = camera_rig.get_screen_axes()
	var cam_right: Vector3 = axes["right"]
	var cam_fwd: Vector3 = axes["forward"]
	var cam_yaw: float = float(axes["yaw_rad"])

	var move_in := Vector3.ZERO
	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W):
		move_in += cam_fwd
	if Input.is_action_pressed("move_back") or Input.is_key_pressed(KEY_S):
		move_in -= cam_fwd
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
		move_in -= cam_right
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
		move_in += cam_right

	var mouse_over_ui: bool = hud != null and hud.is_mouse_over_controls()
	var want_shoot: bool = (not mouse_over_ui) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var want_interact: bool = Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_F)
	var want_roll: bool = Input.is_action_just_pressed("dodge") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)

	var nearest_label := _find_nearest_station_label(active.global_position)
	if hud != null:
		hud.set_interact_hint(nearest_label)

	for i in range(squad.size()):
		var g := squad[i]
		g.set_camera_yaw(cam_yaw)
		if i == active_index:
			g.update_character(delta, move_in, aim_pos, want_shoot, want_interact, want_roll, nearest_label)
		else:
			g.update_character(delta, Vector3.ZERO, aim_pos, false, false, false, "")


func _find_nearest_station_label(pos: Vector3) -> String:
	var best_dist := 3.6
	var best_label := ""
	for st in _station_markers:
		var spos: Vector3 = st["pos"]
		var d: float = Vector2(pos.x - spos.x, pos.z - spos.z).length()
		if d < best_dist:
			best_dist = d
			best_label = str(st["label"])
	return best_label


func _animate_urban_lights() -> void:
	for i in range(_flicker_lamps.size()):
		var f := _flicker_lamps[i]
		if is_instance_valid(f):
			var wave := sin(_time_elapsed * 11.0 + float(i) * 2.9) * sin(_time_elapsed * 3.1)
			f.light_energy = 1.6 if wave > 0.78 else 2.6


func _spawn_move_ping(pos: Vector3) -> void:
	if vfx_root == null:
		return
	var ping := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.34
	ping.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.38, 0.92, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.38, 0.92, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ping.material_override = mat
	vfx_root.add_child(ping)
	ping.global_position = Vector3(pos.x, 0.18, pos.z)

	var tw := ping.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ping, "scale", Vector3.ONE * 2.2, 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(ping.queue_free)


func _add_invisible_collider(parent: Node3D, node_name: String, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)


func _action_zh(action_name: String) -> String:
	match action_name:
		"walk":
			return "走路"
		"shoot":
			return "開槍"
		"interact":
			return "摸東摸西"
		"roll":
			return "翻滾"
		_:
			return "待機"
