class_name LolCameraController
extends Node3D

signal lock_mode_changed(locked: bool)
signal projection_mode_changed(is_ortho: bool)

@export var pitch_degrees: float = -38.0
@export var default_distance: float = 26.0
@export var min_distance: float = 10.0
@export var max_distance: float = 58.0
@export var zoom_step: float = 2.0
@export var pan_speed: float = 24.0
@export var edge_pan_margin: float = 18.0
@export var edge_pan_enabled: bool = false
@export var follow_smoothness: float = 9.0

var camera: Camera3D = null
var follow_target: Node3D = null
var camera_locked: bool = true
var is_orthographic: bool = true  # Default: Crisp 45° Kenney / Project Zomboid Isometric! Press [O] for RO Perspective
var focus_point: Vector3 = Vector3(0.0, 0.0, 3.0)
var target_distance: float = 21.0
var current_distance: float = 21.0
var current_yaw_deg: float = 40.0
var focus_bounds: Rect2 = Rect2(-25.5, -18.5, 49.0, 38.5)
var input_suppressed: bool = false

var _middle_dragging: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	target_distance = default_distance
	current_distance = default_distance

	camera = Camera3D.new()
	camera.name = "LolCamera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if is_orthographic else Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 34.0
	camera.size = 17.5
	camera.near = 0.2
	camera.far = 360.0
	camera.current = true
	add_child(camera)

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


func set_orthographic_mode(ortho: bool) -> void:
	if is_orthographic == ortho:
		return
	is_orthographic = ortho
	if camera != null:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if is_orthographic else Camera3D.PROJECTION_PERSPECTIVE
	_apply_camera_transform()
	projection_mode_changed.emit(is_orthographic)


func toggle_projection_mode() -> void:
	set_orthographic_mode(not is_orthographic)


func recenter_on_target() -> void:
	if follow_target != null:
		focus_point = Vector3(follow_target.global_position.x, 0.0, follow_target.global_position.z)


func get_screen_axes() -> Dictionary:
	# Returns screen-aligned horizontal right & forward vectors flattened on XZ plane
	var yaw_rad: float = deg_to_rad(current_yaw_deg)
	var right := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad)).normalized()
	var forward := Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad)).normalized()
	return {"right": right, "forward": forward, "yaw_rad": yaw_rad}


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
		var axes := get_screen_axes()
		focus_point -= (axes["right"] as Vector3) * (delta.x * drag_scale)
		focus_point += (axes["forward"] as Vector3) * (delta.y * drag_scale * 1.35)
		_clamp_focus()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if input_suppressed:
			return
		if code == KEY_Y:
			toggle_camera_lock()
		elif code == KEY_O:
			toggle_projection_mode()
		elif code == KEY_HOME or code == KEY_C:
			recenter_on_target()


func _process(delta: float) -> void:
	current_distance = lerpf(current_distance, target_distance, clampf(delta * 10.0, 0.0, 1.0))
	var desired_yaw: float = 40.0 if is_orthographic else 0.0
	current_yaw_deg = lerpf(current_yaw_deg, desired_yaw, clampf(delta * 8.0, 0.0, 1.0))

	var hold_recenter: bool = Input.is_key_pressed(KEY_C)
	if (camera_locked or hold_recenter) and follow_target != null:
		var desired := Vector3(follow_target.global_position.x, 0.0, follow_target.global_position.z - 0.8)
		focus_point = focus_point.lerp(desired, clampf(delta * follow_smoothness, 0.0, 1.0))
	else:
		var pan_dir := Vector2.ZERO
		if not input_suppressed:
			if Input.is_key_pressed(KEY_LEFT):
				pan_dir.x -= 1.0
			if Input.is_key_pressed(KEY_RIGHT):
				pan_dir.x += 1.0
			if Input.is_key_pressed(KEY_UP):
				pan_dir.y += 1.0
			if Input.is_key_pressed(KEY_DOWN):
				pan_dir.y -= 1.0

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
					pan_dir.y += 1.0
				elif mpos.y > vsize.y - edge_pan_margin:
					pan_dir.y -= 1.0

		if pan_dir.length_squared() > 0.001:
			pan_dir = pan_dir.normalized()
			var axes := get_screen_axes()
			focus_point += (axes["right"] as Vector3) * (pan_dir.x * pan_speed * delta)
			focus_point += (axes["forward"] as Vector3) * (pan_dir.y * pan_speed * delta)

	_clamp_focus()
	_apply_camera_transform()


func set_focus_bounds(bounds: Rect2) -> void:
	if bounds.size.x > 1.0 and bounds.size.y > 1.0:
		focus_bounds = bounds
		_clamp_focus()


func _clamp_focus() -> void:
	focus_point.x = clampf(focus_point.x, focus_bounds.position.x, focus_bounds.end.x)
	focus_point.z = clampf(focus_point.z, focus_bounds.position.y, focus_bounds.end.y)


func _apply_camera_transform() -> void:
	if camera == null:
		return
	var active_pitch: float = 35.264 if is_orthographic else absf(pitch_degrees)
	var pitch_rad: float = deg_to_rad(active_pitch)
	var yaw_rad: float = deg_to_rad(current_yaw_deg)
	var dist: float = 54.0 if is_orthographic else current_distance
	if is_orthographic:
		camera.size = clampf(current_distance * 0.96, 10.0, 48.0)

	var horiz: float = cos(pitch_rad) * dist
	var offset := Vector3(
		sin(yaw_rad) * horiz,
		sin(pitch_rad) * dist,
		cos(yaw_rad) * horiz
	)
	camera.global_position = focus_point + offset
	camera.look_at(focus_point + Vector3(0.0, 1.2, 0.0), Vector3.UP)


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
