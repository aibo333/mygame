class_name BattleHud
extends CanvasLayer

signal regiment_selected(regiment_type: String)
signal wave_selected(wave_number: int)
signal camera_toggle_requested()
signal restart_requested()
signal next_wave_requested()
signal order_requested(order: String)
signal formation_requested(formation: String)
signal regiment_skill_requested()

const COLOR_BG := Color(0.06, 0.08, 0.12, 0.84)
const COLOR_BORDER := Color(0.78, 0.65, 0.34, 0.72)
const COLOR_BORDER_ACTIVE := Color(1.0, 0.84, 0.36, 1.0)
const COLOR_BTN := Color(0.11, 0.14, 0.21, 0.92)
const COLOR_BTN_HOVER := Color(0.18, 0.23, 0.34, 0.96)
const COLOR_BTN_ACTIVE := Color(0.42, 0.31, 0.12, 0.96)
const COLOR_TEXT := Color(0.95, 0.93, 0.88)
const COLOR_MUTED := Color(0.68, 0.72, 0.78)
const COLOR_GOLD := Color(1.0, 0.84, 0.36)

var _root: Control = null
var _reticle_root: Control = null

# Top bar widgets
var _gate_bar: ProgressBar = null
var _gate_label: Label = null
var _regiment_btns: Dictionary = {}
var _wave_btns: Dictionary = {}
var _camera_btn: Button = null

# Bottom-left Hero widgets
var _hero_title: Label = null
var _hero_hp_bar: ProgressBar = null
var _hero_hp_label: Label = null
var _hero_sta_bar: ProgressBar = null
var _hero_sta_label: Label = null
var _hero_stats_label: Label = null
var _skill_lmb_lbl: Label = null
var _skill_space_lbl: Label = null
var _skill_q_lbl: Label = null
var _skill_e_lbl: Label = null

# Bottom-right Regiment widgets
var _reg_name_lbl: Label = null
var _reg_desc_lbl: Label = null
var _reg_alive_lbl: Label = null
var _pip_container: HBoxContainer = null
var _order_btns: Dictionary = {}
var _formation_btns: Dictionary = {}
var _reg_skill_btn: Button = null

# Right side tactical info + log
var _wave_title_lbl: Label = null
var _wave_enemies_lbl: Label = null
var _log_lbl: Label = null
var _log_lines: Array[String] = []

# Modal overlay
var _modal_overlay: ColorRect = null
var _modal_title_lbl: Label = null
var _modal_body_lbl: Label = null
var _modal_next_btn: Button = null
var _modal_retry_btn: Button = null

var _style_panel: StyleBoxFlat = null
var _style_btn: StyleBoxFlat = null
var _style_btn_hover: StyleBoxFlat = null
var _style_btn_active: StyleBoxFlat = null


func _ready() -> void:
	layer = 10
	_init_styles()
	_build_ui()


func _init_styles() -> void:
	_style_panel = StyleBoxFlat.new()
	_style_panel.bg_color = COLOR_BG
	_style_panel.border_color = COLOR_BORDER
	_style_panel.set_border_width_all(1)
	_style_panel.set_corner_radius_all(6)
	_style_panel.content_margin_left = 10
	_style_panel.content_margin_right = 10
	_style_panel.content_margin_top = 8
	_style_panel.content_margin_bottom = 8

	_style_btn = StyleBoxFlat.new()
	_style_btn.bg_color = COLOR_BTN
	_style_btn.border_color = COLOR_BORDER
	_style_btn.set_border_width_all(1)
	_style_btn.set_corner_radius_all(4)
	_style_btn.content_margin_left = 9
	_style_btn.content_margin_right = 9
	_style_btn.content_margin_top = 5
	_style_btn.content_margin_bottom = 5

	_style_btn_hover = _style_btn.duplicate() as StyleBoxFlat
	_style_btn_hover.bg_color = COLOR_BTN_HOVER

	_style_btn_active = _style_btn.duplicate() as StyleBoxFlat
	_style_btn_active.bg_color = COLOR_BTN_ACTIVE
	_style_btn_active.border_color = COLOR_BORDER_ACTIVE
	_style_btn_active.set_border_width_all(2)


func _make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style_panel)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _make_button(text: String, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _style_btn)
	b.add_theme_stylebox_override("hover", _style_btn_hover)
	b.add_theme_stylebox_override("pressed", _style_btn_active)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 13)
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	return b


func _set_btn_active(btn: Button, active: bool) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", _style_btn_active if active else _style_btn)
	btn.add_theme_color_override("font_color", COLOR_GOLD if active else COLOR_TEXT)


func _make_bar(fill_color: Color, height: float = 16.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180.0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.1, 0.14, 0.95)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _make_label(text: String, font_size: int = 13, color: Color = COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_top_bar()
	_build_center_reticle()
	_build_bottom_left_hero()
	_build_bottom_right_regiment()
	_build_right_sidebar()
	_build_modal_overlay()


func _build_top_bar() -> void:
	var panel := _make_panel()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = 10
	panel.offset_bottom = 58
	_root.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var title := _make_label("戰意守城原型 · Godot 4", 15, COLOR_GOLD)
	hbox.add_child(title)

	# Gate HP section
	var gate_box := HBoxContainer.new()
	gate_box.add_theme_constant_override("separation", 6)
	hbox.add_child(gate_box)
	gate_box.add_child(_make_label("城門", 13, COLOR_MUTED))
	_gate_bar = _make_bar(Color(0.84, 0.56, 0.2), 18.0)
	_gate_bar.max_value = GameConfig.GATE_MAX_HP
	_gate_bar.value = GameConfig.GATE_MAX_HP
	_gate_bar.custom_minimum_size.x = 150.0
	gate_box.add_child(_gate_bar)
	_gate_label = _make_label("500 / 500", 13, COLOR_TEXT)
	gate_box.add_child(_gate_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Regiment switchers
	var reg_labels := {
		"shieldmen": "刀盾兵",
		"pikemen": "長槍兵",
		"archers": "長弓兵",
	}
	for reg_id in ["shieldmen", "pikemen", "archers"]:
		var btn := _make_button(reg_labels[reg_id])
		btn.pressed.connect(func(): regiment_selected.emit(reg_id))
		hbox.add_child(btn)
		_regiment_btns[reg_id] = btn

	# Wave switchers
	for w in [1, 2, 3]:
		var btn := _make_button("W%d" % w)
		btn.pressed.connect(func(): wave_selected.emit(w))
		hbox.add_child(btn)
		_wave_btns[w] = btn

	_camera_btn = _make_button("肩後 TPS [Tab]", 120.0)
	_camera_btn.pressed.connect(func(): camera_toggle_requested.emit())
	hbox.add_child(_camera_btn)

	var restart_btn := _make_button("重來")
	restart_btn.pressed.connect(func(): restart_requested.emit())
	hbox.add_child(restart_btn)


func _build_center_reticle() -> void:
	_reticle_root = Control.new()
	_reticle_root.set_anchors_preset(Control.PRESET_CENTER)
	_reticle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle_root.visible = false
	_root.add_child(_reticle_root)

	var dot := ColorRect.new()
	dot.color = Color(1.0, 0.92, 0.65, 0.9)
	dot.size = Vector2(4, 4)
	dot.position = Vector2(-2, -2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle_root.add_child(dot)

	var offsets: Array[Vector2] = [
		Vector2(-12, -1), Vector2(6, -1), Vector2(-1, -12), Vector2(-1, 6)
	]
	var sizes: Array[Vector2] = [
		Vector2(6, 2), Vector2(6, 2), Vector2(2, 6), Vector2(2, 6)
	]
	for i in range(4):
		var tick := ColorRect.new()
		tick.color = Color(1.0, 0.88, 0.52, 0.68)
		tick.size = sizes[i]
		tick.position = offsets[i]
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reticle_root.add_child(tick)


func _build_bottom_left_hero() -> void:
	var panel := _make_panel()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12
	panel.offset_top = -176
	panel.offset_right = 368
	panel.offset_bottom = -12
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	_hero_title = _make_label("武將：艾莉絲", 14, COLOR_GOLD)
	header.add_child(_hero_title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	_hero_stats_label = _make_label("擊殺 0 ｜ 輸出 0", 12, COLOR_MUTED)
	header.add_child(_hero_stats_label)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	vbox.add_child(hp_row)
	hp_row.add_child(_make_label("生命", 12, COLOR_MUTED))
	_hero_hp_bar = _make_bar(Color(0.84, 0.24, 0.24), 14.0)
	_hero_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(_hero_hp_bar)
	_hero_hp_label = _make_label("360 / 360", 12, COLOR_TEXT)
	_hero_hp_label.custom_minimum_size.x = 76
	hp_row.add_child(_hero_hp_label)

	var sta_row := HBoxContainer.new()
	sta_row.add_theme_constant_override("separation", 6)
	vbox.add_child(sta_row)
	sta_row.add_child(_make_label("耐力", 12, COLOR_MUTED))
	_hero_sta_bar = _make_bar(Color(0.24, 0.68, 0.9), 12.0)
	_hero_sta_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sta_row.add_child(_hero_sta_bar)
	_hero_sta_label = _make_label("100 / 100", 12, COLOR_TEXT)
	_hero_sta_label.custom_minimum_size.x = 76
	sta_row.add_child(_hero_sta_label)

	# Skill boxes
	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 6)
	vbox.add_child(skill_row)

	_skill_lmb_lbl = _add_skill_chip(skill_row, "[LMB]\n三段連斬")
	_skill_space_lbl = _add_skill_chip(skill_row, "[Space]\n翻滾閃避")
	_skill_q_lbl = _add_skill_chip(skill_row, "[Q/RMB]\n破陣衝鋒")
	_skill_e_lbl = _add_skill_chip(skill_row, "[E]\n戰意咆哮")


func _add_skill_chip(parent: HBoxContainer, initial_text: String) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style_btn)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var lbl := _make_label(initial_text, 11, COLOR_TEXT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(lbl)
	return lbl


func _build_bottom_right_regiment() -> void:
	var panel := _make_panel()
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -412
	panel.offset_top = -188
	panel.offset_right = -12
	panel.offset_bottom = -12
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	_reg_name_lbl = _make_label("鐵衛刀盾兵", 14, COLOR_GOLD)
	header.add_child(_reg_name_lbl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	_reg_alive_lbl = _make_label("存活 10 / 10", 13, Color(0.45, 0.92, 0.6))
	header.add_child(_reg_alive_lbl)

	_reg_desc_lbl = _make_label("", 11, COLOR_MUTED)
	_reg_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_reg_desc_lbl)

	_pip_container = HBoxContainer.new()
	_pip_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_pip_container)

	# Order buttons [C]/[X]/[V]
	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 6)
	vbox.add_child(order_row)
	var orders := [["follow", "[C] 跟隨"], ["hold", "[X] 駐守"], ["engage", "[V] 衝鋒"]]
	for item in orders:
		var oid: String = item[0]
		var btn := _make_button(item[1])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): order_requested.emit(oid))
		order_row.add_child(btn)
		_order_btns[oid] = btn

	# Formation [1]/[2] + Skill [F]
	var form_row := HBoxContainer.new()
	form_row.add_theme_constant_override("separation", 6)
	vbox.add_child(form_row)

	var btn_c := _make_button("[1] 密集陣")
	btn_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_c.pressed.connect(func(): formation_requested.emit("compact"))
	form_row.add_child(btn_c)
	_formation_btns["compact"] = btn_c

	var btn_s := _make_button("[2] 散兵陣")
	btn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_s.pressed.connect(func(): formation_requested.emit("spread"))
	form_row.add_child(btn_s)
	_formation_btns["spread"] = btn_s

	_reg_skill_btn = _make_button("[F] 兵團戰技")
	_reg_skill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reg_skill_btn.pressed.connect(func(): regiment_skill_requested.emit())
	form_row.add_child(_reg_skill_btn)


func _build_right_sidebar() -> void:
	var panel := _make_panel()
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -310
	panel.offset_top = 68
	panel.offset_right = -12
	panel.offset_bottom = 308
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	_wave_title_lbl = _make_label("第一波：哥布林先鋒營", 13, COLOR_GOLD)
	vbox.add_child(_wave_title_lbl)

	_wave_enemies_lbl = _make_label("剩餘敵軍：0", 12, COLOR_TEXT)
	vbox.add_child(_wave_enemies_lbl)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	var help_lbl := _make_label(
		"操作：WASD 移動｜左鍵 連斬｜右鍵/Q 衝鋒\nSpace 翻滾｜E 戰吼｜C/X/V 軍令｜1/2 陣型｜F 戰技\nTab 切換肩後/俯視｜ESC 釋放游標",
		11,
		COLOR_MUTED
	)
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(help_lbl)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	_log_lbl = _make_label("戰報準備就緒...", 11, Color(0.86, 0.89, 0.94))
	_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_log_lbl)


func _build_modal_overlay() -> void:
	_modal_overlay = ColorRect.new()
	_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.color = Color(0.02, 0.03, 0.06, 0.72)
	_modal_overlay.visible = false
	_root.add_child(_modal_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.add_child(center)

	var panel := _make_panel()
	panel.custom_minimum_size = Vector2(400, 210)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	_modal_title_lbl = _make_label("守城成功！", 24, COLOR_GOLD)
	_modal_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_modal_title_lbl)

	_modal_body_lbl = _make_label("", 14, COLOR_TEXT)
	_modal_body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_modal_body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_modal_next_btn = _make_button("下一波", 120.0)
	_modal_next_btn.pressed.connect(func(): next_wave_requested.emit())
	btn_row.add_child(_modal_next_btn)

	_modal_retry_btn = _make_button("重試本波", 120.0)
	_modal_retry_btn.pressed.connect(func(): restart_requested.emit())
	btn_row.add_child(_modal_retry_btn)


func push_log(message: String) -> void:
	_log_lines.append("• " + message)
	if _log_lines.size() > 5:
		_log_lines.remove_at(0)
	if _log_lbl != null:
		_log_lbl.text = "\n".join(_log_lines)


func show_result_modal(is_victory: bool, title: String, body: String, can_next_wave: bool) -> void:
	if _modal_overlay == null:
		return
	_modal_title_lbl.text = title
	_modal_title_lbl.add_theme_color_override("font_color", COLOR_GOLD if is_victory else Color(1.0, 0.36, 0.3))
	_modal_body_lbl.text = body
	_modal_next_btn.visible = is_victory and can_next_wave
	_modal_overlay.visible = true


func hide_result_modal() -> void:
	if _modal_overlay != null:
		_modal_overlay.visible = false


func update_hud(
	gate_hp: float,
	gate_max_hp: float,
	current_wave: int,
	wave_name: String,
	enemies_remaining: int,
	hero_state: Dictionary,
	reg_state: Dictionary
) -> void:
	# Gate HP
	_gate_bar.max_value = gate_max_hp
	_gate_bar.value = clampf(gate_hp, 0.0, gate_max_hp)
	_gate_label.text = "%d / %d" % [int(ceil(gate_hp)), int(round(gate_max_hp))]

	# Wave highlight
	for w in _wave_btns.keys():
		_set_btn_active(_wave_btns[w], int(w) == current_wave)
	_wave_title_lbl.text = wave_name
	_wave_enemies_lbl.text = "剩餘敵軍：%d" % enemies_remaining

	# Camera mode & reticle
	var is_tps: bool = bool(hero_state.get("is_tps", true))
	var mouse_captured: bool = bool(hero_state.get("mouse_captured", false))
	_camera_btn.text = "肩後 TPS [Tab]" if is_tps else "3D 俯視 [Tab]"
	_reticle_root.visible = is_tps and mouse_captured

	# Hero panel
	var h_name: String = str(hero_state.get("name", "艾莉絲"))
	var h_alive: bool = bool(hero_state.get("alive", true))
	var h_respawn: float = float(hero_state.get("respawn_sec", 0.0))
	_hero_title.text = ("武將：%s" % h_name) if h_alive else ("武將重傷 (%.1fs 復活)" % h_respawn)

	var h_hp: float = float(hero_state.get("hp", 0.0))
	var h_max_hp: float = maxf(float(hero_state.get("max_hp", 1.0)), 1.0)
	_hero_hp_bar.max_value = h_max_hp
	_hero_hp_bar.value = h_hp
	_hero_hp_label.text = "%d / %d" % [int(ceil(h_hp)), int(round(h_max_hp))]

	var h_sta: float = float(hero_state.get("stamina", 0.0))
	var h_max_sta: float = maxf(float(hero_state.get("max_stamina", 1.0)), 1.0)
	_hero_sta_bar.max_value = h_max_sta
	_hero_sta_bar.value = h_sta
	_hero_sta_label.text = "%d / %d" % [int(floor(h_sta)), int(round(h_max_sta))]

	var kills: int = int(hero_state.get("kills", 0))
	var dmg: int = int(round(float(hero_state.get("damage_dealt", 0.0))))
	_hero_stats_label.text = "擊殺 %d ｜ 輸出 %d" % [kills, dmg]

	var combo: int = int(hero_state.get("combo_step", 0)) + 1
	_skill_lmb_lbl.text = "[LMB]\n連斬 %d/3" % combo
	_skill_space_lbl.text = "[Space]\n翻滾" if h_sta >= 30.0 else "[Space]\n耐力不足"

	var s1_cd: float = float(hero_state.get("skill1_cd", 0.0))
	_skill_q_lbl.text = "[Q/RMB]\n破陣衝鋒" if s1_cd <= 0.01 else "[Q/RMB]\n%.1fs" % s1_cd

	var s2_cd: float = float(hero_state.get("skill2_cd", 0.0))
	var wc_sec: float = float(hero_state.get("warcry_sec", 0.0))
	if wc_sec > 0.05:
		_skill_e_lbl.text = "[E] 戰吼中\n%.1fs" % wc_sec
	elif s2_cd <= 0.01:
		_skill_e_lbl.text = "[E]\n戰意咆哮"
	else:
		_skill_e_lbl.text = "[E]\n%.1fs" % s2_cd

	# Regiment panel
	var r_type: String = str(reg_state.get("type", "shieldmen"))
	for rid in _regiment_btns.keys():
		_set_btn_active(_regiment_btns[rid], str(rid) == r_type)

	_reg_name_lbl.text = str(reg_state.get("name", r_type))
	_reg_desc_lbl.text = str(reg_state.get("description", ""))
	var alive_cnt: int = int(reg_state.get("alive_count", 0))
	var max_cnt: int = int(reg_state.get("max_count", 0))
	_reg_alive_lbl.text = "存活 %d / %d" % [alive_cnt, max_cnt]

	var cur_order: String = str(reg_state.get("order", "follow"))
	for oid in _order_btns.keys():
		_set_btn_active(_order_btns[oid], str(oid) == cur_order)

	var cur_form: String = str(reg_state.get("formation", "compact"))
	_formation_btns["compact"].text = "[1] " + str(reg_state.get("compact_label", "密集陣"))
	_formation_btns["spread"].text = "[2] " + str(reg_state.get("spread_label", "散兵陣"))
	_set_btn_active(_formation_btns["compact"], cur_form == "compact")
	_set_btn_active(_formation_btns["spread"], cur_form == "spread")

	var r_skill_name: String = str(reg_state.get("skill_name", "兵團戰技"))
	var r_skill_cd: float = float(reg_state.get("skill_cd", 0.0))
	_reg_skill_btn.text = ("[F] " + r_skill_name) if r_skill_cd <= 0.01 else ("[F] %.1fs" % r_skill_cd)
	_set_btn_active(_reg_skill_btn, r_skill_cd <= 0.01 and alive_cnt > 0)

	# Soldier HP pips
	var ratios: Array = reg_state.get("soldier_hp_ratios", [])
	_sync_soldier_pips(ratios)


func _sync_soldier_pips(ratios: Array) -> void:
	while _pip_container.get_child_count() < ratios.size():
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(28, 8)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pip_container.add_child(pip)
	while _pip_container.get_child_count() > ratios.size():
		var last := _pip_container.get_child(_pip_container.get_child_count() - 1)
		_pip_container.remove_child(last)
		last.queue_free()

	for i in range(ratios.size()):
		var ratio: float = float(ratios[i])
		var pip := _pip_container.get_child(i) as ColorRect
		if ratio <= 0.0:
			pip.color = Color(0.24, 0.24, 0.28, 0.65)
		elif ratio > 0.55:
			pip.color = Color(0.28, 0.86, 0.52)
		elif ratio > 0.25:
			pip.color = Color(0.95, 0.72, 0.22)
		else:
			pip.color = Color(0.92, 0.28, 0.24)
