extends SceneTree

var _frame: int = 0
var _world: RuinsBaseWorld = null


func _initialize() -> void:
	var win := get_root()
	win.size = Vector2i(1440, 810)
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return
	_world = packed.instantiate() as RuinsBaseWorld
	win.add_child(_world)
	if _world.camera_rig != null:
		_world.camera_rig.set_orthographic_mode(false)
		_world.camera_rig.current_yaw_deg = 25.0
		_world.camera_rig.current_distance = 7.2
		_world.camera_rig.target_distance = 7.2
		_world.camera_rig.pitch_degrees = -20.0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 4 and _world != null and _world.camera_rig != null:
		_world.camera_rig.set_orthographic_mode(false)
		_world.camera_rig.current_yaw_deg = 28.0
		_world.camera_rig.current_distance = 7.0
		_world.camera_rig.target_distance = 7.0
		_world.camera_rig.pitch_degrees = -22.0
	if _frame == 12:
		var img := get_root().get_texture().get_image()
		img.save_png("res://tools/art_pipeline/previews/mixamo_idle.png")
		print("[Preview] Saved Mixamo Rifle Idle shot -> mixamo_idle.png")
		var p := _world.get_active_character()
		if p != null:
			p.trigger_preview_action("walk")
	elif _frame == 26:
		var img2 := get_root().get_texture().get_image()
		img2.save_png("res://tools/art_pipeline/previews/mixamo_run.png")
		print("[Preview] Saved Mixamo Rifle Run shot -> mixamo_run.png")
		quit(0)
		return true
	return false
