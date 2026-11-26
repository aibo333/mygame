class_name TrainHelmUi
extends CanvasLayer

## Cold tactical sci-fi Helm Console overlay opened with [F] inside the Locomotive Boiler Room.
## Keeps the viewport visible so the player can drive along the central railway in real time.

signal drive_requested(direction: int)
signal depart_requested()
signal closed()

var _panel: PanelContainer = null
var _phase_badge: Label = null
var _status_label: Label = null
var _pos_label: Label = null
var _depart_status_label: Label = null
var _depart_btn: Button = null
var _rev_btn: Button = null
var _stop_btn: Button = null
var _fwd_btn: Button = null


func setup() -> void:
	var root := Control.new()
	root.name = "TrainHelmRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = TacticalTheme.build_theme(14)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "TrainHelmPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -280.0
	_panel.offset_top = -296.0
	_panel.offset_right = 280.0
	_panel.offset_bottom = -96.0
	_panel.add_theme_stylebox_override(
		"panel",
		TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL_DEEP, TacticalTheme.ACCENT_AMBER, 3, 16, 12)
	)
	_panel.visible = false
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vbox.add_child(hdr)

	var title := Label.new()
	title.text = "HELM CONSOLE // 鍋爐室駕駛操縱台"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	hdr.add_child(title)

	_phase_badge = Label.new()
	_phase_badge.text = "DAY · RAIL READY"
	_phase_badge.add_theme_font_size_override("font_size", 12)
	_phase_badge.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	hdr.add_child(_phase_badge)

	var close_btn := Button.new()
	close_btn.text = "[F / ESC] 離開"
	close_btn.pressed.connect(func(): set_open(false))
	hdr.add_child(close_btn)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	vbox.add_child(info_row)

	_status_label = Label.new()
	_status_label.text = "STEAM PRESSURE READY"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	info_row.add_child(_status_label)

	_pos_label = Label.new()
	_pos_label.text = "RAIL X: 0.0m  |  HULL 100%"
	_pos_label.add_theme_font_size_override("font_size", 12)
	_pos_label.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	info_row.add_child(_pos_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_rev_btn = Button.new()
	_rev_btn.text = "[◀ A / ←] 西行 (-X)"
	_rev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rev_btn.custom_minimum_size = Vector2(0.0, 38.0)
	_rev_btn.pressed.connect(func(): drive_requested.emit(-1))
	btn_row.add_child(_rev_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "[■ S / SPACE] 煞停"
	_stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stop_btn.custom_minimum_size = Vector2(0.0, 38.0)
	_stop_btn.pressed.connect(func(): drive_requested.emit(0))
	btn_row.add_child(_stop_btn)

	_fwd_btn = Button.new()
	_fwd_btn.text = "[▶ D / →] 東行 (+X)"
	_fwd_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fwd_btn.custom_minimum_size = Vector2(0.0, 38.0)
	_fwd_btn.pressed.connect(func(): drive_requested.emit(1))
	btn_row.add_child(_fwd_btn)

	var depart_row := HBoxContainer.new()
	depart_row.add_theme_constant_override("separation", 8)
	vbox.add_child(depart_row)

	_depart_status_label = Label.new()
	_depart_status_label.text = "SECTOR #1 · 需清除路障與燃料 x2 離站"
	_depart_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_depart_status_label.add_theme_font_size_override("font_size", 12)
	_depart_status_label.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	depart_row.add_child(_depart_status_label)

	_depart_btn = Button.new()
	_depart_btn.text = ">> 駛離前往下一街區"
	_depart_btn.custom_minimum_size = Vector2(180.0, 32.0)
	_depart_btn.pressed.connect(func(): depart_requested.emit())
	depart_row.add_child(_depart_btn)

	var hint := Label.new()
	hint.text = "A / D 調控蒸氣推進方向  ｜  S / SPACE 氣壓煞車  ｜  F / E / ESC 離開操縱台"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", TacticalTheme.TEXT_MUTED)
	vbox.add_child(hint)

	_disable_focus_recursive(root)


func _disable_focus_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for c in node.get_children():
		_disable_focus_recursive(c)


func is_open() -> bool:
	return _panel != null and _panel.visible


func set_open(open_state: bool) -> void:
	if _panel == null or _panel.visible == open_state:
		return
	_panel.visible = open_state
	if not open_state:
		closed.emit()


func is_mouse_over() -> bool:
	if not is_open() or _panel == null:
		return false
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	return _panel.get_global_rect().has_point(vp.get_mouse_position())


func refresh(
	phase: int,
	clock_text: String,
	is_mobile: bool,
	throttle: int,
	rail_x: float,
	hull_hp: float,
	max_hull_hp: float,
	sector_index: int = 1,
	depart_check: Dictionary = {}
) -> void:
	if _phase_badge != null:
		_phase_badge.text = "%s · %s" % [clock_text, "行駛解鎖" if is_mobile else "夜間駐防鎖定"]
		var badge_col: Color = TacticalTheme.ACCENT_CYAN
		if phase == DayNightCycleManager.Phase.DUSK:
			badge_col = TacticalTheme.ACCENT_AMBER
		elif phase == DayNightCycleManager.Phase.NIGHT:
			badge_col = Color(0.56, 0.74, 1.0)
		elif phase == DayNightCycleManager.Phase.BLOOD_MOON:
			badge_col = TacticalTheme.ACCENT_CRIMSON
		_phase_badge.add_theme_color_override("font_color", badge_col)

	if _status_label != null:
		if not is_mobile:
			_status_label.text = "⛔ 夜間／黃昏鍋爐鎖定 — 僅白天可行駛"
			_status_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CRIMSON)
		elif throttle < 0:
			_status_label.text = "◀ 蒸氣推進中（向西行駛 -X）"
			_status_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
		elif throttle > 0:
			_status_label.text = "▶ 蒸氣推進中（向東行駛 +X）"
			_status_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
		else:
			_status_label.text = "■ 氣壓煞車就緒（等待推進指令）"
			_status_label.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)

	if _pos_label != null:
		var pct: int = int(round((hull_hp / maxf(1.0, max_hull_hp)) * 100.0))
		_pos_label.text = "RAIL X %+.1fm  |  HULL %d%%" % [rail_x, pct]

	if _rev_btn != null:
		_rev_btn.disabled = not is_mobile
		TacticalTheme.style_state_button(_rev_btn, is_mobile and throttle < 0, TacticalTheme.ACCENT_CYAN)
	if _stop_btn != null:
		_stop_btn.disabled = not is_mobile
		TacticalTheme.style_state_button(_stop_btn, (not is_mobile) or throttle == 0, TacticalTheme.ACCENT_AMBER)
	if _fwd_btn != null:
		_fwd_btn.disabled = not is_mobile
		TacticalTheme.style_state_button(_fwd_btn, is_mobile and throttle > 0, TacticalTheme.ACCENT_CYAN)

	var can_depart: bool = bool(depart_check.get("ok", false))
	if _depart_status_label != null:
		var msg: String = str(depart_check.get("message", "EXPEDITION SECTOR #%d" % sector_index))
		_depart_status_label.text = "EXPEDITION #%d · %s" % [sector_index, msg]
		_depart_status_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_EMERALD if can_depart else TacticalTheme.TEXT_SECONDARY)
	if _depart_btn != null:
		_depart_btn.disabled = not can_depart
		TacticalTheme.style_state_button(_depart_btn, can_depart, TacticalTheme.ACCENT_EMERALD)
