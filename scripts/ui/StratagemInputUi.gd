class_name StratagemInputUi
extends CanvasLayer

signal step_succeeded(step_index: int, total_steps: int)
signal step_failed(expected_dir: String, got_dir: String)
signal sequence_completed(target: Dictionary, elapsed_sec: float)
signal sequence_cancelled(target: Dictionary)

const DIRS: Array[String] = ["up", "down", "left", "right"]

const DIR_GLYPHS: Dictionary = {
	"up": "⬆",
	"down": "⬇",
	"left": "⬅",
	"right": "➡",
}

const DIR_KEYS_HINT: Dictionary = {
	"up": "W / ↑",
	"down": "S / ↓",
	"left": "A / ←",
	"right": "D / →",
}

var is_active: bool = false
var active_target: Dictionary = {}
var sequence: Array[String] = []
var current_index: int = 0
var mistakes: int = 0

var _panel: PanelContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _arrows_row: HBoxContainer = null
var _tile_boxes: Array[PanelContainer] = []
var _tile_labels: Array[Label] = []
var _start_msec: int = 0
var _error_flash_timer: float = 0.0
var _base_offset_left: float = -340.0
var _base_offset_right: float = 340.0


func setup() -> void:
	layer = 16
	_build_ui()
	_set_panel_visible(false)


func get_length_for_kind(kind: String) -> int:
	match kind:
		"train_stash":
			return 3
		"loot":
			return 4
		"survivor_rescue":
			return 5
		"mission_objective", "boarding_extract":
			return 6
		_:
			return 4


func keycode_to_direction(keycode: int) -> String:
	match keycode:
		KEY_W, KEY_UP:
			return "up"
		KEY_S, KEY_DOWN:
			return "down"
		KEY_A, KEY_LEFT:
			return "left"
		KEY_D, KEY_RIGHT:
			return "right"
		_:
			return ""


func start_sequence(target: Dictionary, seed_hint: int = 0, forced_sequence: Array[String] = []) -> Array[String]:
	active_target = target.duplicate(true)
	var kind: String = str(active_target.get("kind", "loot"))
	var seq_len: int = get_length_for_kind(kind)

	sequence.clear()
	if not forced_sequence.is_empty():
		for d: String in forced_sequence:
			if DIRS.has(d):
				sequence.append(d)
	else:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		if seed_hint != 0:
			rng.seed = seed_hint
		else:
			rng.randomize()
		for i in range(seq_len):
			var pick: String = DIRS[rng.randi_range(0, DIRS.size() - 1)]
			# Avoid 3 identical consecutive arrows so patterns feel rhythmic and fun
			if i >= 2 and sequence[i - 1] == pick and sequence[i - 2] == pick:
				pick = DIRS[(DIRS.find(pick) + rng.randi_range(1, 3)) % DIRS.size()]
			sequence.append(pick)

	current_index = 0
	mistakes = 0
	is_active = true
	_start_msec = Time.get_ticks_msec()
	_error_flash_timer = 0.0

	_rebuild_arrow_tiles()
	if _title_label != null:
		_title_label.text = "⚡ 快速指令互動：%s" % str(active_target.get("label", "物件"))
	if _subtitle_label != null:
		_subtitle_label.text = "依序輸入 WASD 或 ↑↓←→（Space 緊急翻滾中斷 ｜ Esc 取消）"
	_set_panel_visible(true)
	return sequence.duplicate()


func feed_direction(dir: String) -> String:
	if not is_active or sequence.is_empty():
		return "inactive"
	if not DIRS.has(dir):
		return "inactive"

	var expected: String = sequence[current_index]
	if dir == expected:
		current_index += 1
		step_succeeded.emit(current_index, sequence.size())
		_refresh_tile_styles()
		if current_index >= sequence.size():
			var elapsed_sec: float = maxf(0.05, float(Time.get_ticks_msec() - _start_msec) / 1000.0)
			var done_target: Dictionary = active_target.duplicate(true)
			is_active = false
			active_target = {}
			_set_panel_visible(false)
			sequence_completed.emit(done_target, elapsed_sec)
			return "complete"
		return "step"
	else:
		mistakes += 1
		current_index = 0
		_error_flash_timer = 0.28
		_refresh_tile_styles()
		step_failed.emit(expected, dir)
		return "mistake"


func cancel() -> void:
	if not is_active:
		return
	var prev_target: Dictionary = active_target.duplicate(true)
	is_active = false
	active_target = {}
	current_index = 0
	_error_flash_timer = 0.0
	_set_panel_visible(false)
	sequence_cancelled.emit(prev_target)


func _process(delta: float) -> void:
	if _error_flash_timer > 0.0:
		_error_flash_timer = maxf(0.0, _error_flash_timer - delta)
		if _panel != null:
			var shake: float = sin(_error_flash_timer * 65.0) * 10.0 * (_error_flash_timer / 0.28)
			_panel.offset_left = _base_offset_left + shake
			_panel.offset_right = _base_offset_right + shake
			if _error_flash_timer <= 0.0:
				_panel.offset_left = _base_offset_left
				_panel.offset_right = _base_offset_right
				_refresh_tile_styles()


func _make_style(bg: Color, border: Color, radius: int = 8, border_w: int = 2) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _build_ui() -> void:
	var root: Control = Control.new()
	root.name = "StratagemRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "StratagemPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = _base_offset_left
	_panel.offset_top = -316.0
	_panel.offset_right = _base_offset_right
	_panel.offset_bottom = -168.0
	_panel.add_theme_stylebox_override("panel", _make_style(Color(0.16, 0.12, 0.09, 0.96), Color(0.95, 0.74, 0.30, 0.96), 12, 3))
	root.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 19)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	vbox.add_child(_title_label)

	_arrows_row = HBoxContainer.new()
	_arrows_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_arrows_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_arrows_row)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 15)
	_subtitle_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
	vbox.add_child(_subtitle_label)


func _set_panel_visible(vis: bool) -> void:
	if _panel != null:
		_panel.visible = vis
		_panel.offset_left = _base_offset_left
		_panel.offset_right = _base_offset_right


func _rebuild_arrow_tiles() -> void:
	if _arrows_row == null:
		return
	for c in _arrows_row.get_children():
		_arrows_row.remove_child(c)
		c.queue_free()
	_tile_boxes.clear()
	_tile_labels.clear()

	for d: String in sequence:
		var box: PanelContainer = PanelContainer.new()
		box.custom_minimum_size = Vector2(64.0, 62.0)
		_arrows_row.add_child(box)
		_tile_boxes.append(box)

		var lbl: Label = Label.new()
		lbl.text = str(DIR_GLYPHS.get(d, "?"))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 30)
		box.add_child(lbl)
		_tile_labels.append(lbl)

	_refresh_tile_styles()


func _refresh_tile_styles() -> void:
	var is_err: bool = _error_flash_timer > 0.0
	for i in range(_tile_boxes.size()):
		var box: PanelContainer = _tile_boxes[i]
		var lbl: Label = _tile_labels[i]
		if is_err:
			box.add_theme_stylebox_override("panel", _make_style(Color(0.50, 0.14, 0.12, 0.96), Color(1.0, 0.36, 0.28, 1.0), 8, 2))
			lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.78))
		elif i < current_index:
			# Completed arrow — bright emerald & gold!
			box.add_theme_stylebox_override("panel", _make_style(Color(0.16, 0.42, 0.24, 0.98), Color(0.45, 0.98, 0.64, 1.0), 8, 2))
			lbl.add_theme_color_override("font_color", Color(0.62, 1.0, 0.74))
		elif i == current_index:
			# Current active arrow — bright amber/gold focus!
			box.add_theme_stylebox_override("panel", _make_style(Color(0.62, 0.36, 0.12, 0.98), Color(1.0, 0.88, 0.36, 1.0), 8, 3))
			lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.86))
		else:
			# Pending arrow
			box.add_theme_stylebox_override("panel", _make_style(Color(0.22, 0.18, 0.14, 0.94), Color(0.56, 0.46, 0.32, 0.85), 8, 2))
			lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
