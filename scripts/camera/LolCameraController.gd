class_name LolCameraController
extends Node3D

signal lock_mode_changed(locked: bool)

@export var pitch_degrees: float = -52.0
@export var default_distance: float = 15.5
@export var min_distance: float = 7.5
@export var max_distance: float = 28.0
@export var zoom_step: float = 1.6
@export var pan_speed: float = 18.0
@export var edge_pan_margin: float = 18.0
@export var edge_pan_enabled: bool = false
@export var follow_smoothness: float = 9.0

var camera: Camera3D = null
var follow_target: Node3D = null
var camera_locked: bool = true
var focus_point: Vector3 = Vector3(-2.0, 0.0, -1.5)
var target_distance: float = 15.5
var current_distance: float = 15.5

var _middle_dragging: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	target_distance = default_distance
	current_distance = default_distance

	camera = Camera3D.new()
	camera.name = "LolCamera3D"
	camera.fov = 36.0
	camera.near = 0.2
	camera.far = 220.0
	camera.current = true
	add_child(camera)

	# Ensure mouse cursor is always visible & free (no TPS pointer lock!)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_camera_transform()


func set_follow_target(node: Node3D, snap: bool = false) -> void:
	follow_target = node
	if snap and follow_target != null:
		focus_point = Vector3(follow_target.global_position.x, 0.0, follow_target.global_position.z)
		_apply_camera_transform()


func set_camera_locked(locked: bool) -> void:
	if camera_locked == locked:
		return
	camera_locked = locked
	lock_mode_changed.emit(camera_locked)


func toggle_camera_lock() -> void:
	set_camera_locked(not camera_locked)


func recenter_on_target() -> void:
	if follow_target != null:
		focus_point = Vector3(follow_target.global_position.x, 0.0, follow_target.global_position.z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			target_distance = clampf(target_distance - zoom_step, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			target_distance = clampf(target_distance + zoom_step, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_dragging = mb.pressed
			_last_drag_pos = mb.position
			if mb.pressed and camera_locked:
				set_camera_locked(false)
	elif event is InputEventMouseMotion and _middle_dragging:
		var mm := event as InputEventMouseMotion
		var delta: Vector2 = mm.position - _last_drag_pos
		_last_drag_pos = mm.position
		var drag_scale: float = current_distance * 0.0018
		focus_point.x -= delta.x * drag_scale
		focus_point.z -= delta.y * drag_scale * 1.25
		_clamp_focus()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_Y:
			toggle_camera_lock()
		elif key.keycode == KEY_HOME or key.keycode == KEY_C:
			recenter_on_target()


func _process(delta: float) -> void:
	current_distance = lerpf(current_distance, target_distance, clampf(delta * 10.0, 0.0, 1.0))

	var hold_recenter: bool = Input.is_key_pressed(KEY_C)
	if (camera_locked or hold_recenter) and follow_target != null:
		var desired := Vector3(follow_target.global_position.x, 0.0, follow_target.global_position.z)
		focus_point = focus_point.lerp(desired, clampf(delta * follow_smoothness, 0.0, 1.0))
	else:
		# Free LoL pan with Arrow keys or optional screen-edge scroll
		var pan_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT):
			pan_dir.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			pan_dir.x += 1.0
		if Input.is_key_pressed(KEY_UP):
			pan_dir.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN):
			pan_dir.y += 1.0

		if edge_pan_enabled and pan_dir.length_squared() < 0.01:
			var vp := get_viewport()
			if vp != null:
				var mpos := vp.get_mouse_position()
				var vsize := vp.get_visible_rect().size
				if mpos.x < edge_pan_margin:
					pan_dir.x -= 1.0
				elif mpos.x > vsize.x - edge_pan_margin:
					pan_dir.x += 1.0
				if mpos.y < edge_pan_margin:
					pan_dir.y -= 1.0
				elif mpos.y > vsize.y - edge_pan_margin:
					pan_dir.y += 1.0

		if pan_dir.length_squared() > 0.001:
			pan_dir = pan_dir.normalized()
			focus_point.x += pan_dir.x * pan_speed * delta
			focus_point.z += pan_dir.y * pan_speed * delta

	_clamp_focus()
	_apply_camera_transform()


func _clamp_focus() -> void:
	focus_point.x = clampf(focus_point.x, -34.0, 34.0)
	focus_point.z = clampf(focus_point.z, -16.0, 22.0)


func _apply_camera_transform() -> void:
	if camera == null:
		return
	var pitch_rad: float = deg_to_rad(absf(pitch_degrees))
	var offset := Vector3(
		0.0,
		sin(pitch_rad) * current_distance,
		cos(pitch_rad) * current_distance
	)
	camera.global_position = focus_point + offset
	camera.look_at(focus_point + Vector3(0.0, 0.55, 0.0), Vector3.UP)


func raycast_ground(screen_pos: Vector2, ground_y: float = 0.0) -> Vector3:
	if camera == null:
		return focus_point
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return focus_point
	var t: float = (ground_y - origin.y) / dir.y
	if t < 0.0:
		return focus_point
	return origin + dir * t
