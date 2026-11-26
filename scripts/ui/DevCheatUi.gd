class_name DevCheatUi
extends CanvasLayer

signal cheat_toggled(cheat_id: String, enabled: bool)
signal clear_zombies_requested()
signal spawn_demo_fortifications_requested()
signal grant_resources_requested()
signal avatar_selected(avatar_id: String)
signal phase_selected(phase: int)
signal next_day_requested()
signal blood_moon_delta_requested(delta_bm: float)
signal blood_moon_random_event_requested()
signal spawn_blood_elite_requested()

const CHEAT_ROWS: Array[Dictionary] = [
	{
		"id": "god_mode",
		"hotkey": "F2",
		"tag": "GOD",
		"name": "無敵模式",
		"desc": "角色／裝甲列車／工事免傷，體力與飢餓不降",
	},
	{
		"id": "infinite_resources",
		"hotkey": "F3",
		"tag": "INF",
		"name": "無限資源",
		"desc": "免費建造維修工事、無限彈藥與腰帶道具",
	},
	{
		"id": "pause_spawns",
		"hotkey": "F4",
		"tag": "FRZ",
		"name": "暫停出怪",
		"desc": "凍結屍潮定期出怪、波次與埋伏增援",
	},
]

var _panel: PanelContainer = null
var _is_open: bool = false
var _toggle_buttons: Dictionary = {}
var _status_labels: Dictionary = {}
var _avatar_buttons: Dictionary = {}
var _phase_buttons: Dictionary = {}
var _cycle_status_label: Label = null
var _active_avatar_id: String = SquadConfig.DEFAULT_AVATAR_ID
var _states: Dictionary = {
	"god_mode": false,
	"infinite_resources": false,
	"pause_spawns": false,
}


func setup() -> void:
	layer = 22
	_build_ui()
	set_open(false)


func is_open() -> bool:
	return _is_open


func set_open(open: bool) -> void:
	_is_open = open
	if _panel != null:
		_panel.visible = open


func toggle_open() -> void:
	set_open(not _is_open)


func is_mouse_over() -> bool:
	if not _is_open or _panel == null or not _panel.visible:
		return false
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	return _panel.get_global_rect().has_point(vp.get_mouse_position())


func sync_states(god_mode: bool, infinite_resources: bool, pause_spawns: bool) -> void:
	_states["god_mode"] = god_mode
	_states["infinite_resources"] = infinite_resources
	_states["pause_spawns"] = pause_spawns
	for row: Dictionary in CHEAT_ROWS:
		var cid: String = str(row["id"])
		var active: bool = bool(_states.get(cid, false))
		var btn: Button = _toggle_buttons.get(cid, null) as Button
		var st_lbl: Label = _status_labels.get(cid, null) as Label
		if btn != null:
			btn.text = "ACTIVE" if active else "OFF"
			TacticalTheme.style_state_button(btn, active, TacticalTheme.ACCENT_EMERALD)
		if st_lbl != null:
			st_lbl.text = "▪ ON" if active else "▫ OFF"
			st_lbl.add_theme_color_override("font_color", TacticalTheme.ACCENT_EMERALD if active else TacticalTheme.TEXT_MUTED)


func sync_active_avatar(avatar_id: String) -> void:
	_active_avatar_id = avatar_id
	for aid: String in _avatar_buttons.keys():
		var btn: Button = _avatar_buttons[aid] as Button
		if btn != null:
			TacticalTheme.style_state_button(btn, aid == avatar_id, TacticalTheme.ACCENT_CYAN)


func sync_day_night(phase: int, day_num: int, blood_moon_val: float, warning_active: bool) -> void:
	for p_key in _phase_buttons.keys():
		var p_int: int = int(p_key)
		var btn: Button = _phase_buttons[p_key] as Button
		if btn != null:
			var col: Color = TacticalTheme.ACCENT_CRIMSON if p_int == DayNightCycleManager.Phase.BLOOD_MOON else (TacticalTheme.ACCENT_AMBER if p_int == DayNightCycleManager.Phase.DUSK else TacticalTheme.ACCENT_CYAN)
			TacticalTheme.style_state_button(btn, p_int == phase, col)
	if _cycle_status_label != null:
		var pname: String = "白晝"
		if phase == DayNightCycleManager.Phase.DUSK:
			pname = "黃昏"
		elif phase == DayNightCycleManager.Phase.NIGHT:
			pname = "黑夜"
		elif phase == DayNightCycleManager.Phase.BLOOD_MOON:
			pname = "血月"
		var warn_tag: String = "  [預警!]" if warning_active else ""
		_cycle_status_label.text = "DAY %d · %s  |  BLOOD MOON %d%%%s" % [day_num, pname, int(round(blood_moon_val)), warn_tag]
		_cycle_status_label.add_theme_color_override(
			"font_color",
			TacticalTheme.ACCENT_CRIMSON if (phase == DayNightCycleManager.Phase.BLOOD_MOON or warning_active) else TacticalTheme.ACCENT_CYAN
		)


func _build_ui() -> void:
	var root: Control = Control.new()
	root.name = "DevCheatRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = TacticalTheme.build_theme(14)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "DevCheatTablePanel"
	_panel.position = Vector2(16.0, 174.0)
	_panel.custom_minimum_size = Vector2(560.0, 0.0)
	_panel.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL_DEEP, TacticalTheme.ACCENT_AMBER, 3, 14, 12))
	root.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Title bar
	var hdr: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hdr)

	var title: Label = Label.new()
	title.text = "SYS // DEV CHEAT CONSOLE [F1 / ~]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	hdr.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.text = "HIDE [ESC]"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): set_open(false))
	hdr.add_child(close_btn)

	# Table Column Header
	var col_hdr: HBoxContainer = HBoxContainer.new()
	col_hdr.add_theme_constant_override("separation", 10)
	vbox.add_child(col_hdr)
	_add_col_header(col_hdr, "KEY", 50.0)
	_add_col_header(col_hdr, "MODULE", 130.0)
	_add_col_header(col_hdr, "EFFECT", 220.0)
	_add_col_header(col_hdr, "STATE", 56.0)
	_add_col_header(col_hdr, "TOGGLE", 88.0)

	vbox.add_child(HSeparator.new())

	# Cheat Table Rows
	for row: Dictionary in CHEAT_ROWS:
		var cid: String = str(row["id"])
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(hbox)

		var hk_lbl: Label = Label.new()
		hk_lbl.text = "[%s]" % str(row["hotkey"])
		hk_lbl.custom_minimum_size = Vector2(50.0, 0.0)
		hk_lbl.add_theme_font_size_override("font_size", 13)
		hk_lbl.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
		hbox.add_child(hk_lbl)

		var name_lbl: Label = Label.new()
		name_lbl.text = "%s · %s" % [str(row["tag"]), str(row["name"])]
		name_lbl.custom_minimum_size = Vector2(130.0, 0.0)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
		hbox.add_child(name_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = str(row["desc"])
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.custom_minimum_size = Vector2(220.0, 0.0)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
		hbox.add_child(desc_lbl)

		var st_lbl: Label = Label.new()
		st_lbl.text = "▫ OFF"
		st_lbl.custom_minimum_size = Vector2(56.0, 0.0)
		st_lbl.add_theme_font_size_override("font_size", 13)
		st_lbl.add_theme_color_override("font_color", TacticalTheme.TEXT_MUTED)
		hbox.add_child(st_lbl)
		_status_labels[cid] = st_lbl

		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(88.0, 32.0)
		btn.add_theme_font_size_override("font_size", 13)
		btn.text = "OFF"
		var cap_id: String = cid
		btn.pressed.connect(func():
			var next_val: bool = not bool(_states.get(cap_id, false))
			cheat_toggled.emit(cap_id, next_val)
		)
		hbox.add_child(btn)
		_toggle_buttons[cid] = btn

	vbox.add_child(HSeparator.new())

	# Character Model Switcher Row
	var avatar_hdr: Label = Label.new()
	avatar_hdr.text = "MODEL // 即時人形模型切換 (OPERATOR AVATAR)"
	avatar_hdr.add_theme_font_size_override("font_size", 12)
	avatar_hdr.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	vbox.add_child(avatar_hdr)

	var avatar_row: HBoxContainer = HBoxContainer.new()
	avatar_row.add_theme_constant_override("separation", 8)
	vbox.add_child(avatar_row)
	_avatar_buttons.clear()
	for acfg: Dictionary in SquadConfig.get_avatar_catalog():
		var aid: String = str(acfg.get("id", ""))
		var abtn: Button = Button.new()
		abtn.focus_mode = Control.FOCUS_NONE
		abtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		abtn.custom_minimum_size = Vector2(0.0, 32.0)
		abtn.add_theme_font_size_override("font_size", 13)
		abtn.text = str(acfg.get("label", aid))
		var cap_aid: String = aid
		abtn.pressed.connect(func(): avatar_selected.emit(cap_aid))
		avatar_row.add_child(abtn)
		_avatar_buttons[aid] = abtn
	sync_active_avatar(_active_avatar_id)

	vbox.add_child(HSeparator.new())

	# Quick Dev Action Row
	var util_row: HBoxContainer = HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 8)
	vbox.add_child(util_row)

	var clear_btn: Button = Button.new()
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.custom_minimum_size = Vector2(0.0, 34.0)
	clear_btn.add_theme_font_size_override("font_size", 13)
	clear_btn.text = "PURGE // 清除喪屍"
	clear_btn.pressed.connect(func(): clear_zombies_requested.emit())
	util_row.add_child(clear_btn)

	var res_btn: Button = Button.new()
	res_btn.focus_mode = Control.FOCUS_NONE
	res_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_btn.custom_minimum_size = Vector2(0.0, 34.0)
	res_btn.add_theme_font_size_override("font_size", 13)
	res_btn.text = "GRANT // 全資源 +99"
	res_btn.pressed.connect(func(): grant_resources_requested.emit())
	util_row.add_child(res_btn)

	var fort_btn: Button = Button.new()
	fort_btn.focus_mode = Control.FOCUS_NONE
	fort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fort_btn.custom_minimum_size = Vector2(0.0, 34.0)
	fort_btn.add_theme_font_size_override("font_size", 13)
	fort_btn.text = "DEPLOY // 補齊工事"
	fort_btn.pressed.connect(func(): spawn_demo_fortifications_requested.emit())
	util_row.add_child(fort_btn)

	vbox.add_child(HSeparator.new())

	# Day / Night & Blood Moon Control Section
	var cycle_hdr_row := HBoxContainer.new()
	cycle_hdr_row.add_theme_constant_override("separation", 8)
	vbox.add_child(cycle_hdr_row)

	var cycle_hdr := Label.new()
	cycle_hdr.text = "CYCLE // 晝夜切換與血月控制"
	cycle_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cycle_hdr.add_theme_font_size_override("font_size", 12)
	cycle_hdr.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	cycle_hdr_row.add_child(cycle_hdr)

	_cycle_status_label = Label.new()
	_cycle_status_label.text = "DAY 1 · 白晝  |  BLOOD MOON 0%"
	_cycle_status_label.add_theme_font_size_override("font_size", 12)
	_cycle_status_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	cycle_hdr_row.add_child(_cycle_status_label)

	var phase_row := HBoxContainer.new()
	phase_row.add_theme_constant_override("separation", 6)
	vbox.add_child(phase_row)
	_phase_buttons.clear()
	var phase_specs: Array[Dictionary] = [
		{"phase": DayNightCycleManager.Phase.DAY, "label": "☀️ 白晝 DAY"},
		{"phase": DayNightCycleManager.Phase.DUSK, "label": "🌇 黃昏 DUSK"},
		{"phase": DayNightCycleManager.Phase.NIGHT, "label": "🌙 黑夜 NIGHT"},
		{"phase": DayNightCycleManager.Phase.BLOOD_MOON, "label": "🩸 血月 BLOOD"},
	]
	for ps: Dictionary in phase_specs:
		var p_val: int = int(ps["phase"])
		var pbtn := Button.new()
		pbtn.focus_mode = Control.FOCUS_NONE
		pbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pbtn.custom_minimum_size = Vector2(0.0, 32.0)
		pbtn.add_theme_font_size_override("font_size", 12)
		pbtn.text = str(ps["label"])
		pbtn.pressed.connect(func(): phase_selected.emit(p_val))
		phase_row.add_child(pbtn)
		_phase_buttons[p_val] = pbtn

	var next_day_btn := Button.new()
	next_day_btn.focus_mode = Control.FOCUS_NONE
	next_day_btn.custom_minimum_size = Vector2(74.0, 32.0)
	next_day_btn.add_theme_font_size_override("font_size", 12)
	next_day_btn.text = "DAY +1"
	next_day_btn.pressed.connect(func(): next_day_requested.emit())
	phase_row.add_child(next_day_btn)

	var bm_row := HBoxContainer.new()
	bm_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bm_row)

	var bm_add_btn := Button.new()
	bm_add_btn.focus_mode = Control.FOCUS_NONE
	bm_add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bm_add_btn.custom_minimum_size = Vector2(0.0, 32.0)
	bm_add_btn.add_theme_font_size_override("font_size", 12)
	bm_add_btn.text = "血月 +25%"
	bm_add_btn.pressed.connect(func(): blood_moon_delta_requested.emit(25.0))
	bm_row.add_child(bm_add_btn)

	var bm_full_btn := Button.new()
	bm_full_btn.focus_mode = Control.FOCUS_NONE
	bm_full_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bm_full_btn.custom_minimum_size = Vector2(0.0, 32.0)
	bm_full_btn.add_theme_font_size_override("font_size", 12)
	bm_full_btn.text = "血月滿值 (100%)"
	bm_full_btn.pressed.connect(func(): blood_moon_delta_requested.emit(100.0))
	bm_row.add_child(bm_full_btn)

	var bm_reset_btn := Button.new()
	bm_reset_btn.focus_mode = Control.FOCUS_NONE
	bm_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bm_reset_btn.custom_minimum_size = Vector2(0.0, 32.0)
	bm_reset_btn.add_theme_font_size_override("font_size", 12)
	bm_reset_btn.text = "血月歸零 (0%)"
	bm_reset_btn.pressed.connect(func(): blood_moon_delta_requested.emit(-100.0))
	bm_row.add_child(bm_reset_btn)

	var bm_evt_btn := Button.new()
	bm_evt_btn.focus_mode = Control.FOCUS_NONE
	bm_evt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bm_evt_btn.custom_minimum_size = Vector2(0.0, 32.0)
	bm_evt_btn.add_theme_font_size_override("font_size", 12)
	bm_evt_btn.text = "隨機異常事件"
	bm_evt_btn.pressed.connect(func(): blood_moon_random_event_requested.emit())
	bm_row.add_child(bm_evt_btn)

	var elite_btn := Button.new()
	elite_btn.focus_mode = Control.FOCUS_NONE
	elite_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elite_btn.custom_minimum_size = Vector2(0.0, 32.0)
	elite_btn.add_theme_font_size_override("font_size", 12)
	elite_btn.text = "生成血月精英"
	elite_btn.pressed.connect(func(): spawn_blood_elite_requested.emit())
	bm_row.add_child(elite_btn)


func _add_col_header(parent: HBoxContainer, text: String, min_w: float) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(min_w, 0.0)
	if min_w >= 200.0:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", TacticalTheme.TEXT_MUTED)
	parent.add_child(lbl)
