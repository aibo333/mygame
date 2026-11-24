extends SceneTree

var _frame: int = 0
var _cam: Camera3D


func _initialize() -> void:
	var win := get_root()
	win.size = Vector2i(1440, 810)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.88, 0.91, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.70, 0.84)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	win.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-36.0, -35.0, 0.0)
	win.add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.65, 0.80, 1.0)
	rim.light_energy = 0.65
	rim.rotation_degrees = Vector3(-25.0, 145.0, 0.0)
	win.add_child(rim)

	var scene := load("res://assets/models/train/kabaneri_armored_train.glb") as PackedScene
	if scene == null:
		push_error("Failed to load kabaneri_armored_train.glb")
		quit(1)
		return
	var train := scene.instantiate()
	win.add_child(train)

	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.near = 0.2
	_cam.far = 250.0
	win.add_child(_cam)
	_cam.current = true
	# Shot 1: Low-front 3/4 hero angle matching the reference concept art!
	_cam.look_at_from_position(Vector3(29.5, 4.8, 17.5), Vector3(6.5, 3.6, 0.0), Vector3.UP)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 5:
		var img := get_root().get_texture().get_image()
		img.save_png("res://tools/art_pipeline/previews/train_preview.png")
		print("[Preview] Saved 3/4 hero shot -> train_preview.png")
		# Switch to Shot 2: 52-degree LoL top-down camera angle
		_cam.fov = 38.0
		_cam.position = Vector3(6.0, 22.0, 21.0)
		_cam.look_at(Vector3(3.0, 2.2, 0.0), Vector3.UP)
	elif _frame == 10:
		var img2 := get_root().get_texture().get_image()
		img2.save_png("res://tools/art_pipeline/previews/train_lol_preview.png")
		print("[Preview] Saved LoL angle shot -> train_lol_preview.png")
		quit(0)
		return true
	return false
