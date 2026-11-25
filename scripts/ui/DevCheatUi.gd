class_name DevCheatUi
extends CanvasLayer

signal cheat_toggled(cheat_id: String, enabled: bool)
signal clear_zombies_requested()
signal spawn_demo_fortifications_requested()
signal grant_resources_requested()

const CHEAT_ROWS: Array[Dictionary] = [
	{
		"id": "god_mode",
		"hotkey": "F2",
		"icon": "🛡️",
		"name": "無敵模式",
		"desc": "角色／裝甲列車／工事免傷，體力與飢餓不降",
	},
	{
		"id": "infinite_resources",
		"hotkey": "F3",
		"icon": "♾️",
		"name": "無限資源",
		"desc": "免費建造維修工事、無限彈藥與腰帶道具",
	},
	{
		"id": "pause_spawns",
		"hotkey": "F4",
		"icon": "⏸️",
		"name": "暫停出怪",
		"desc": "凍結屍潮定期出怪、波次與埋伏增援",
	},
]

var _panel: PanelContainer = null
var _is_open: bool = false
var _toggle_buttons: Dictionary = {}
var _status_labels: Dictionary = {}
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
			btn.text = "開啟中 ON" if active else "關閉 OFF"
			btn.modulate = Color(0.45, 1.0, 0.62) if active else Color(0.88, 0.84, 0.80)
		if st_lbl != null:
			st_lbl.text = "● ON" if active else "○ OFF"
			st_lbl.add_theme_color_override("font_color", Color(0.38, 1.0, 0.56) if active else Color(0.62, 0.64, 0.68))


func _make_style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _build_ui() -> void:
	var root: Control = Control.new()
	root.name = "DevCheatRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "DevCheatTablePanel"
	_panel.position = Vector2(16.0, 178.0)
	_panel.custom_minimum_size = Vector2(540.0, 0.0)
	_panel.add_theme_stylebox_override("panel", _make_style(Color(0.09, 0.09, 0.12, 0.95), Color(0.95, 0.72, 0.28, 0.94)))
	root.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Title bar
	var hdr: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hdr)

	var title: Label = Label.new()
	title.text = "🛠 開發用 Cheat Code Table [F1 / ~]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	hdr.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.text = "✕ 隱藏"
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(func(): set_open(false))
	hdr.add_child(close_btn)

	# Table Column Header
	var col_hdr: HBoxContainer = HBoxContainer.new()
	col_hdr.add_theme_constant_override("separation", 10)
	vbox.add_child(col_hdr)
	_add_col_header(col_hdr, "熱鍵", 52.0)
	_add_col_header(col_hdr, "作弊項目", 126.0)
	_add_col_header(col_hdr, "效果說明", 215.0)
	_add_col_header(col_hdr, "狀態", 58.0)
	_add_col_header(col_hdr, "切換", 92.0)

	var sep1: HSeparator = HSeparator.new()
	vbox.add_child(sep1)

	# Cheat Table Rows
	for row: Dictionary in CHEAT_ROWS:
		var cid: String = str(row["id"])
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(hbox)

		var hk_lbl: Label = Label.new()
		hk_lbl.text = "[%s]" % str(row["hotkey"])
		hk_lbl.custom_minimum_size = Vector2(52.0, 0.0)
		hk_lbl.add_theme_font_size_override("font_size", 15)
		hk_lbl.add_theme_color_override("font_color", Color(0.56, 0.92, 1.0))
		hbox.add_child(hk_lbl)

		var name_lbl: Label = Label.new()
		name_lbl.text = "%s %s" % [str(row["icon"]), str(row["name"])]
		name_lbl.custom_minimum_size = Vector2(126.0, 0.0)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
		hbox.add_child(name_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = str(row["desc"])
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.custom_minimum_size = Vector2(215.0, 0.0)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.84, 0.88))
		hbox.add_child(desc_lbl)

		var st_lbl: Label = Label.new()
		st_lbl.text = "○ OFF"
		st_lbl.custom_minimum_size = Vector2(58.0, 0.0)
		st_lbl.add_theme_font_size_override("font_size", 14)
		st_lbl.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
		hbox.add_child(st_lbl)
		_status_labels[cid] = st_lbl

		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(92.0, 34.0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.text = "關閉 OFF"
		var cap_id: String = cid
		btn.pressed.connect(func():
			var next_val: bool = not bool(_states.get(cap_id, false))
			cheat_toggled.emit(cap_id, next_val)
		)
		hbox.add_child(btn)
		_toggle_buttons[cid] = btn

	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)

	# Quick Dev Action Row
	var util_row: HBoxContainer = HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 8)
	vbox.add_child(util_row)

	var clear_btn: Button = Button.new()
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.custom_minimum_size = Vector2(0.0, 36.0)
	clear_btn.add_theme_font_size_override("font_size", 14)
	clear_btn.text = "🧹 清除場上喪屍"
	clear_btn.pressed.connect(func(): clear_zombies_requested.emit())
	util_row.add_child(clear_btn)

	var res_btn: Button = Button.new()
	res_btn.focus_mode = Control.FOCUS_NONE
	res_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_btn.custom_minimum_size = Vector2(0.0, 36.0)
	res_btn.add_theme_font_size_override("font_size", 14)
	res_btn.text = "📦 補給全資源 +99"
	res_btn.pressed.connect(func(): grant_resources_requested.emit())
	util_row.add_child(res_btn)

	var fort_btn: Button = Button.new()
	fort_btn.focus_mode = Control.FOCUS_NONE
	fort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fort_btn.custom_minimum_size = Vector2(0.0, 36.0)
	fort_btn.add_theme_font_size_override("font_size", 14)
	fort_btn.text = "🧱 補齊全套工事"
	fort_btn.pressed.connect(func(): spawn_demo_fortifications_requested.emit())
	util_row.add_child(fort_btn)


func _add_col_header(parent: HBoxContainer, text: String, min_w: float) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(min_w, 0.0)
	if min_w >= 200.0:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.94, 0.78, 0.44))
	parent.add_child(lbl)
