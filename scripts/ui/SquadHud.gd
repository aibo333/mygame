class_name SquadHud
extends CanvasLayer

signal character_selected(index: int)
signal action_preview_requested(action_name: String)
signal sync_all_toggled(enabled: bool)
signal camera_lock_toggled()
signal camera_recenter_requested()

var _squad_cards: Array[Dictionary] = []
var _status_label: Label = null
var _interact_hint_label: Label = null
var _camera_btn: Button = null
var _sync_check: CheckButton = null
var _interactive_panels: Array[Control] = []


func setup(squad: Array[SquadCharacter]) -> void:
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top_bar(root)
	_build_squad_bar(root, squad)
	_build_action_showcase_panel(root)
	_build_interact_prompt(root)


func _make_panel_style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _build_top_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.10, 0.15, 0.84), Color(0.95, 0.56, 0.30, 0.78)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "甲鐵廢墟戰線  //  基礎美術 × 3D小人 × 裝甲列車基地"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	var base_badge := Label.new()
	base_badge.text = "🚂 基地：甲鐵城號（爐心運轉中）"
	base_badge.add_theme_font_size_override("font_size", 13)
	base_badge.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	row.add_child(base_badge)

	_camera_btn = Button.new()
	_camera_btn.text = "🎥 LOL俯瞰：鎖定跟隨 [Y]"
	_camera_btn.pressed.connect(func(): camera_lock_toggled.emit())
	row.add_child(_camera_btn)

	var recenter_btn := Button.new()
	recenter_btn.text = "回到角色 [C]"
	recenter_btn.pressed.connect(func(): camera_recenter_requested.emit())
	row.add_child(recenter_btn)

	_status_label = Label.new()
	_status_label.text = "操作：WASD 或右鍵走路 ｜ 左鍵開槍 ｜ E/F 摸東摸西 ｜ Space 翻滾 ｜ 1/2/3 切換小人 ｜ 滾輪縮放"
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.96))
	vbox.add_child(_status_label)


func _build_squad_bar(root: Control, squad: Array[SquadCharacter]) -> void:
	var holder := HBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.offset_left = 18.0
	holder.offset_top = -118.0
	holder.offset_right = 640.0
	holder.offset_bottom = -16.0
	holder.add_theme_constant_override("separation", 10)
	root.add_child(holder)

	for i in range(squad.size()):
		var g := squad[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(198, 98)
		card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.11, 0.17, 0.88), Color(0.32, 0.38, 0.48, 0.8)))
		holder.add_child(card)
		_interactive_panels.append(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		card.add_child(vbox)

		var top_row := HBoxContainer.new()
		vbox.add_child(top_row)

		var key_lbl := Label.new()
		key_lbl.text = "[%d] %s" % [i + 1, g.display_name]
		key_lbl.add_theme_font_size_override("font_size", 15)
		key_lbl.add_theme_color_override("font_color", g.accent_color)
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(key_lbl)

		var pick_btn := Button.new()
		pick_btn.text = "切換"
		var idx := i
		pick_btn.pressed.connect(func(): character_selected.emit(idx))
		top_row.add_child(pick_btn)

		var role_lbl := Label.new()
		role_lbl.text = "%s · %s" % [g.role_label, g.weapon_label]
		role_lbl.add_theme_font_size_override("font_size", 11)
		role_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
		vbox.add_child(role_lbl)

		var state_lbl := Label.new()
		state_lbl.text = "動作：待機"
		state_lbl.add_theme_font_size_override("font_size", 12)
		state_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
		vbox.add_child(state_lbl)

		_squad_cards.append({
			"char_id": g.char_id,
			"card": card,
			"accent": g.accent_color,
			"state_label": state_lbl,
		})


func _build_action_showcase_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -368.0
	panel.offset_top = -134.0
	panel.offset_right = -18.0
	panel.offset_bottom = -16.0
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.10, 0.16, 0.88), Color(0.36, 0.78, 0.98, 0.72)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var lbl := Label.new()
	lbl.text = "🎬 4大基礎動作檢視台"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(lbl)

	_sync_check = CheckButton.new()
	_sync_check.text = "全員同步"
	_sync_check.toggled.connect(func(v: bool): sync_all_toggled.emit(v))
	hdr.add_child(_sync_check)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	var actions := [
		{"id": "walk", "label": "走路"},
		{"id": "shoot", "label": "開槍"},
		{"id": "interact", "label": "摸東摸西"},
		{"id": "roll", "label": "翻滾"},
		{"id": "idle", "label": "待機"},
	]
	for a in actions:
		var b := Button.new()
		b.text = str(a["label"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var aid := str(a["id"])
		b.pressed.connect(func(): action_preview_requested.emit(aid))
		btn_row.add_child(b)

	var tip := Label.new()
	tip.text = "點擊即可原地循環檢視動作（按 WASD 隨時切回手操）"
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(0.68, 0.74, 0.84))
	vbox.add_child(tip)


func _build_interact_prompt(root: Control) -> void:
	_interact_hint_label = Label.new()
	_interact_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interact_hint_label.offset_left = -190.0
	_interact_hint_label.offset_top = -168.0
	_interact_hint_label.offset_right = 190.0
	_interact_hint_label.offset_bottom = -134.0
	_interact_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint_label.add_theme_font_size_override("font_size", 15)
	_interact_hint_label.add_theme_color_override("font_color", Color(0.45, 0.94, 1.0))
	_interact_hint_label.visible = false
	root.add_child(_interact_hint_label)


func set_active_character(index: int) -> void:
	for i in range(_squad_cards.size()):
		var entry: Dictionary = _squad_cards[i]
		var card := entry["card"] as PanelContainer
		var accent: Color = entry["accent"]
		if i == index:
			card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.14, 0.17, 0.26, 0.95), accent))
		else:
			card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.10, 0.15, 0.82), Color(0.28, 0.32, 0.42, 0.7)))


func update_character_action(char_id: String, action_name: String) -> void:
	var zh := "待機"
	match action_name:
		"walk":
			zh = "走路"
		"shoot":
			zh = "開槍中 🔥"
		"interact":
			zh = "摸東摸西 🔧"
		"roll":
			zh = "戰術翻滾 💨"
	for entry in _squad_cards:
		if str(entry["char_id"]) == char_id:
			(entry["state_label"] as Label).text = "動作：%s" % zh
			break


func set_camera_locked(locked: bool) -> void:
	if _camera_btn != null:
		_camera_btn.text = "🎥 LOL俯瞰：鎖定跟隨 [Y]" if locked else "🎥 LOL俯瞰：自由平移 [Y]"


func set_interact_hint(station_label: String) -> void:
	if _interact_hint_label == null:
		return
	if station_label.is_empty():
		_interact_hint_label.visible = false
	else:
		_interact_hint_label.text = "[按住 E / F] 摸東摸西：%s" % station_label
		_interact_hint_label.visible = true


func push_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func is_mouse_over_controls() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var mpos := vp.get_mouse_position()
	for ctrl in _interactive_panels:
		if is_instance_valid(ctrl) and ctrl.visible and ctrl.get_global_rect().has_point(mpos):
			return true
	return false
