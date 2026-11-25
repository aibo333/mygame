class_name SquadHud
extends CanvasLayer

signal character_selected(index: int)
signal action_preview_requested(action_name: String)
signal sync_all_toggled(enabled: bool)
signal camera_lock_toggled()
signal camera_projection_toggled()
signal camera_recenter_requested()
signal regenerate_sector_requested()
signal train_blueprint_requested()
signal hub_requested()

var _squad_cards: Array[Dictionary] = []
var _status_label: Label = null
var _seed_label: Label = null
var _timer_label: Label = null
var _mission_label: Label = null
var _player_hp_bar: ProgressBar = null
var _player_vitals_label: Label = null
var _interact_hint_panel: PanelContainer = null
var _interact_hint_label: Label = null
var _camera_btn: Button = null
var _proj_btn: Button = null
var _sync_check: CheckButton = null
var _hull_bar: ProgressBar = null
var _hull_value_label: Label = null
var _consist_summary_label: Label = null
var _boarding_badge: Label = null
var _backpack_bar: ProgressBar = null
var _backpack_value_label: Label = null
var _backpack_detail_label: Label = null
var _stash_detail_label: Label = null
var _loot_counter_label: Label = null
var _interactive_panels: Array[Control] = []


func setup(squad: Array[SquadCharacter]) -> void:
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_theme := Theme.new()
	hud_theme.default_font_size = 16
	root.theme = hud_theme
	add_child(root)

	_build_top_bar(root)
	_build_train_and_inventory_panel(root)
	_build_squad_bar(root, squad)
	_build_action_showcase_panel(root)
	_build_interact_prompt(root)
	_disable_focus_recursive(root)


func _disable_focus_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for c in node.get_children():
		_disable_focus_recursive(c)


func _make_panel_style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _make_bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	return sb


func _make_bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18, 0.95)
	sb.border_color = Color(0.26, 0.31, 0.42, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


func _build_top_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.10, 0.15, 0.88), Color(0.95, 0.56, 0.30, 0.82)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "裝甲列車撤離戰線  //  隨機都市街區 × 裝甲列車藍圖 × 搜刮卸貨"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	_seed_label = Label.new()
	_seed_label.text = "🧭 Seed #--"
	_seed_label.add_theme_font_size_override("font_size", 16)
	_seed_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.46))
	row.add_child(_seed_label)

	var regen_btn := Button.new()
	regen_btn.text = "🎲 新街區 [R]"
	regen_btn.add_theme_font_size_override("font_size", 16)
	regen_btn.pressed.connect(func(): regenerate_sector_requested.emit())
	row.add_child(regen_btn)

	var train_btn := Button.new()
	train_btn.text = "🚂 列車藍圖 [T]"
	train_btn.add_theme_font_size_override("font_size", 16)
	train_btn.pressed.connect(func(): train_blueprint_requested.emit())
	row.add_child(train_btn)

	var hub_btn := Button.new()
	hub_btn.text = "🏕 整備大廳 [H]"
	hub_btn.add_theme_font_size_override("font_size", 16)
	hub_btn.pressed.connect(func(): hub_requested.emit())
	row.add_child(hub_btn)

	_proj_btn = Button.new()
	_proj_btn.text = "📽️ Zomboid 正交 [O]"
	_proj_btn.add_theme_font_size_override("font_size", 16)
	_proj_btn.pressed.connect(func(): camera_projection_toggled.emit())
	row.add_child(_proj_btn)

	_camera_btn = Button.new()
	_camera_btn.text = "🎥 鎖定 [Y]"
	_camera_btn.add_theme_font_size_override("font_size", 16)
	_camera_btn.pressed.connect(func(): camera_lock_toggled.emit())
	row.add_child(_camera_btn)

	var recenter_btn := Button.new()
	recenter_btn.text = "回角色 [C]"
	recenter_btn.add_theme_font_size_override("font_size", 16)
	recenter_btn.pressed.connect(func(): camera_recenter_requested.emit())
	row.add_child(recenter_btn)

	_timer_label = Label.new()
	_timer_label.text = "⏱ 06:00 ｜ 階段 1：靜默進站 ｜ 🧟 擊殺 0"
	_timer_label.add_theme_font_size_override("font_size", 16)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.46))
	vbox.add_child(_timer_label)

	_mission_label = Label.new()
	_mission_label.text = "🎯 主線目標載入中..."
	_mission_label.add_theme_font_size_override("font_size", 16)
	_mission_label.add_theme_color_override("font_color", Color(0.96, 0.68, 1.0))
	vbox.add_child(_mission_label)

	_status_label = Label.new()
	_status_label.text = "WASD/右鍵移動 ｜ 左鍵射擊 ｜ R 換彈 ｜ Space 翻滾無敵 ｜ E/F 搜刮與任務 ｜ T 列車藍圖 ｜ H 大廳"
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.80, 0.90, 0.98))
	vbox.add_child(_status_label)


func _build_train_and_inventory_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "TrainInventoryPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -468.0
	panel.offset_top = 16.0
	panel.offset_right = -18.0
	panel.offset_bottom = 290.0
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.10, 0.16, 0.90), Color(0.32, 0.82, 0.96, 0.82)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Armored Train Hull HP Row
	var hull_hdr := HBoxContainer.new()
	vbox.add_child(hull_hdr)

	var hull_title := Label.new()
	hull_title.text = "🚂 裝甲列車耐久"
	hull_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hull_title.add_theme_font_size_override("font_size", 17)
	hull_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	hull_hdr.add_child(hull_title)

	_hull_value_label = Label.new()
	_hull_value_label.text = "1000 / 1000 (100%)"
	_hull_value_label.add_theme_font_size_override("font_size", 17)
	_hull_value_label.add_theme_color_override("font_color", Color(0.42, 0.94, 0.62))
	hull_hdr.add_child(_hull_value_label)

	_hull_bar = ProgressBar.new()
	_hull_bar.custom_minimum_size = Vector2(0.0, 16.0)
	_hull_bar.max_value = 1000.0
	_hull_bar.value = 1000.0
	_hull_bar.show_percentage = false
	_hull_bar.add_theme_stylebox_override("background", _make_bar_bg())
	_hull_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.28, 0.84, 0.48)))
	vbox.add_child(_hull_bar)

	_consist_summary_label = Label.new()
	_consist_summary_label.text = "編成：3/3 節 ｜ 動力 5/6 ｜ 砲塔 1 座 ｜ 駐守 0/4"
	_consist_summary_label.add_theme_font_size_override("font_size", 15)
	_consist_summary_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.56))
	vbox.add_child(_consist_summary_label)

	_boarding_badge = Label.new()
	_boarding_badge.text = "登車區：未進入（北方鐵軌月台）"
	_boarding_badge.add_theme_font_size_override("font_size", 15)
	_boarding_badge.add_theme_color_override("font_color", Color(0.74, 0.80, 0.88))
	vbox.add_child(_boarding_badge)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Backpack Capacity Row
	var bp_hdr := HBoxContainer.new()
	vbox.add_child(bp_hdr)

	var bp_title := Label.new()
	bp_title.text = "🎒 隨身背包"
	bp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp_title.add_theme_font_size_override("font_size", 17)
	bp_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	bp_hdr.add_child(bp_title)

	_backpack_value_label = Label.new()
	_backpack_value_label.text = "0 / 12"
	_backpack_value_label.add_theme_font_size_override("font_size", 17)
	_backpack_value_label.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	bp_hdr.add_child(_backpack_value_label)

	_backpack_bar = ProgressBar.new()
	_backpack_bar.custom_minimum_size = Vector2(0.0, 14.0)
	_backpack_bar.max_value = 12.0
	_backpack_bar.value = 0.0
	_backpack_bar.show_percentage = false
	_backpack_bar.add_theme_stylebox_override("background", _make_bar_bg())
	_backpack_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.32, 0.78, 0.98)))
	vbox.add_child(_backpack_bar)

	_backpack_detail_label = Label.new()
	_backpack_detail_label.text = "金屬 0 ｜ 零件 0 ｜ 燃料 0 ｜ 補給 0"
	_backpack_detail_label.add_theme_font_size_override("font_size", 16)
	_backpack_detail_label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98))
	vbox.add_child(_backpack_detail_label)

	_stash_detail_label = Label.new()
	_stash_detail_label.text = "📦 暫存倉 (0)：金屬 0 ｜ 零件 0 ｜ 燃料 0 ｜ 補給 0"
	_stash_detail_label.add_theme_font_size_override("font_size", 16)
	_stash_detail_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44))
	vbox.add_child(_stash_detail_label)

	_loot_counter_label = Label.new()
	_loot_counter_label.text = "街區搜刮點剩餘：0 / 0"
	_loot_counter_label.add_theme_font_size_override("font_size", 15)
	_loot_counter_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.92))
	vbox.add_child(_loot_counter_label)


func _build_squad_bar(root: Control, squad: Array[SquadCharacter]) -> void:
	var holder := HBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.offset_left = 18.0
	holder.offset_top = -172.0
	holder.offset_right = 660.0
	holder.offset_bottom = -16.0
	holder.add_theme_constant_override("separation", 12)
	root.add_child(holder)

	for i in range(squad.size()):
		var g := squad[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(360, 150)
		card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.11, 0.17, 0.90), Color(0.32, 0.38, 0.48, 0.85)))
		holder.add_child(card)
		_interactive_panels.append(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		card.add_child(vbox)

		var top_row := HBoxContainer.new()
		vbox.add_child(top_row)

		var key_lbl := Label.new()
		key_lbl.text = "玩家：%s" % g.display_name if squad.size() == 1 else "[%d] %s" % [i + 1, g.display_name]
		key_lbl.add_theme_font_size_override("font_size", 19)
		key_lbl.add_theme_color_override("font_color", g.accent_color)
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(key_lbl)

		if squad.size() > 1:
			var pick_btn := Button.new()
			pick_btn.text = "切換"
			var idx := i
			pick_btn.pressed.connect(func(): character_selected.emit(idx))
			top_row.add_child(pick_btn)

		var role_lbl := Label.new()
		role_lbl.text = "%s · %s" % [g.role_label, g.weapon_label]
		role_lbl.add_theme_font_size_override("font_size", 15)
		role_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
		vbox.add_child(role_lbl)

		var state_lbl := Label.new()
		state_lbl.text = "動作：待機"
		state_lbl.add_theme_font_size_override("font_size", 16)
		state_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
		vbox.add_child(state_lbl)

		if i == 0:
			_player_hp_bar = ProgressBar.new()
			_player_hp_bar.custom_minimum_size = Vector2(0.0, 14.0)
			_player_hp_bar.max_value = 100.0
			_player_hp_bar.value = 100.0
			_player_hp_bar.show_percentage = false
			_player_hp_bar.add_theme_stylebox_override("background", _make_bar_bg())
			_player_hp_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.32, 0.88, 0.54)))
			vbox.add_child(_player_hp_bar)

			_player_vitals_label = Label.new()
			_player_vitals_label.text = "❤️ 100/100 ｜ 🔫 彈匣 30/30 [R]"
			_player_vitals_label.add_theme_font_size_override("font_size", 15)
			_player_vitals_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
			vbox.add_child(_player_vitals_label)

		_squad_cards.append({
			"char_id": g.char_id,
			"card": card,
			"accent": g.accent_color,
			"state_label": state_lbl,
		})


func _build_action_showcase_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -468.0
	panel.offset_top = -156.0
	panel.offset_right = -18.0
	panel.offset_bottom = -16.0
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.10, 0.16, 0.90), Color(0.36, 0.78, 0.98, 0.78)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var lbl := Label.new()
	lbl.text = "🎬 Mixamo 動捕動作檢視台"
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(lbl)

	_sync_check = CheckButton.new()
	_sync_check.text = "全員同步"
	_sync_check.visible = false
	_sync_check.toggled.connect(func(v: bool): sync_all_toggled.emit(v))
	hdr.add_child(_sync_check)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	var actions := [
		{"id": "walk", "label": "走路"},
		{"id": "shoot", "label": "開槍"},
		{"id": "interact", "label": "搜刮"},
		{"id": "roll", "label": "翻滾"},
		{"id": "idle", "label": "待機"},
	]
	for a in actions:
		var b := Button.new()
		b.text = str(a["label"])
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var aid := str(a["id"])
		b.pressed.connect(func(): action_preview_requested.emit(aid))
		btn_row.add_child(b)

	var tip := Label.new()
	tip.text = "點擊原地預覽動作（按 WASD 隨時切回手操）"
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.74, 0.80, 0.88))
	vbox.add_child(tip)


func _build_interact_prompt(root: Control) -> void:
	_interact_hint_panel = PanelContainer.new()
	_interact_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interact_hint_panel.offset_left = -340.0
	_interact_hint_panel.offset_top = -224.0
	_interact_hint_panel.offset_right = 340.0
	_interact_hint_panel.offset_bottom = -168.0
	_interact_hint_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.08, 0.13, 0.90), Color(0.40, 0.88, 1.0, 0.85), 10))
	_interact_hint_panel.visible = false
	root.add_child(_interact_hint_panel)

	_interact_hint_label = Label.new()
	_interact_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact_hint_label.add_theme_font_size_override("font_size", 19)
	_interact_hint_label.add_theme_color_override("font_color", Color(0.45, 0.94, 1.0))
	_interact_hint_panel.add_child(_interact_hint_label)


func set_sector_info(seed_value: int, block_summary: String) -> void:
	if _seed_label != null:
		_seed_label.text = "🧭 Seed #%d ｜ %s" % [seed_value, block_summary]


func update_run_timer(remaining_sec: float, stage_name: String, kills: int, active_zombies: int) -> void:
	if _timer_label == null:
		return
	var mins: int = int(floor(remaining_sec / 60.0))
	var secs: int = int(floor(fmod(remaining_sec, 60.0)))
	_timer_label.text = "⏱ %02d:%02d ｜ %s ｜ 🧟 擊殺 %d（場上 %d）" % [mins, secs, stage_name, kills, active_zombies]
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.34) if remaining_sec <= 60.0 else Color(1.0, 0.86, 0.46))


func update_mission_status(mission_text: String, compass_text: String) -> void:
	if _mission_label == null:
		return
	_mission_label.text = "%s ｜ 🧭 %s" % [mission_text, compass_text]


func update_player_vitals(hp: float, max_hp: float, ammo: int, mag_size: int, reloading: bool) -> void:
	var safe_max: float = maxf(1.0, max_hp)
	var ratio: float = clampf(hp / safe_max, 0.0, 1.0)
	if _player_hp_bar != null:
		_player_hp_bar.max_value = safe_max
		_player_hp_bar.value = clampf(hp, 0.0, safe_max)
		var col: Color = Color(0.32, 0.88, 0.54) if ratio > 0.5 else (Color(0.98, 0.72, 0.24) if ratio > 0.25 else Color(0.96, 0.28, 0.24))
		_player_hp_bar.add_theme_stylebox_override("fill", _make_bar_fill(col))
	if _player_vitals_label != null:
		var ammo_s: String = "換彈中..." if reloading else "%d/%d [R]" % [ammo, mag_size]
		_player_vitals_label.text = "❤️ %d/%d ｜ 🔫 彈匣 %s" % [int(round(hp)), int(round(safe_max)), ammo_s]


func update_train_consist_summary(stats: Dictionary) -> void:
	if _consist_summary_label == null:
		return
	_consist_summary_label.text = "編成：%d/%d 節 ｜ 動力 %d/%d ｜ 砲塔 %d 座 ｜ 駐守 %d/%d" % [
		int(stats.get("carriage_count", 3)),
		int(stats.get("max_carriages", 3)),
		int(stats.get("power_used", 5)),
		int(stats.get("power_capacity", 6)),
		int(stats.get("turret_count", 1)),
		int(stats.get("assigned_crew", 0)),
		int(stats.get("total_crew_slots", 4)),
	]


func update_train_hull(current_hp: float, max_hp: float) -> void:
	var safe_max: float = maxf(1.0, max_hp)
	var ratio: float = clampf(current_hp / safe_max, 0.0, 1.0)
	if _hull_bar != null:
		_hull_bar.max_value = safe_max
		_hull_bar.value = clampf(current_hp, 0.0, safe_max)
		var bar_color := Color(0.28, 0.84, 0.48) if ratio > 0.6 else (Color(0.96, 0.72, 0.24) if ratio > 0.3 else Color(0.92, 0.28, 0.26))
		_hull_bar.add_theme_stylebox_override("fill", _make_bar_fill(bar_color))
	if _hull_value_label != null:
		_hull_value_label.text = "%d / %d (%d%%)" % [int(round(current_hp)), int(round(safe_max)), int(round(ratio * 100.0))]


func set_boarding_zone_active(in_zone: bool) -> void:
	if _boarding_badge == null:
		return
	if in_zone:
		_boarding_badge.text = "✅ 已進入登車區（按 E/F 或 T 開啟列車設計圖）"
		_boarding_badge.add_theme_color_override("font_color", Color(0.42, 0.96, 0.68))
	else:
		_boarding_badge.text = "登車區：未進入（北方鐵軌月台）"
		_boarding_badge.add_theme_color_override("font_color", Color(0.74, 0.80, 0.88))


func update_inventory(
	backpack: Dictionary,
	used: int,
	capacity: int,
	train_stash: Dictionary,
	stash_total: int,
	loot_remaining: int,
	loot_total: int
) -> void:
	var cap: int = maxi(1, capacity)
	if _backpack_bar != null:
		_backpack_bar.max_value = float(cap)
		_backpack_bar.value = float(used)
		var full_col := Color(0.98, 0.42, 0.28) if used >= cap else Color(0.32, 0.78, 0.98)
		_backpack_bar.add_theme_stylebox_override("fill", _make_bar_fill(full_col))
	if _backpack_value_label != null:
		_backpack_value_label.text = "%d / %d%s" % [used, cap, " (已滿!)" if used >= cap else ""]
		_backpack_value_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.36) if used >= cap else Color(0.55, 0.90, 1.0))
	if _backpack_detail_label != null:
		_backpack_detail_label.text = "金屬 %d ｜ 零件 %d ｜ 燃料 %d ｜ 補給 %d" % [
			int(backpack.get("scrap", 0)),
			int(backpack.get("parts", 0)),
			int(backpack.get("fuel", 0)),
			int(backpack.get("supplies", 0)),
		]
	if _stash_detail_label != null:
		_stash_detail_label.text = "📦 暫存倉 (%d)：金屬 %d ｜ 零件 %d ｜ 燃料 %d ｜ 補給 %d" % [
			stash_total,
			int(train_stash.get("scrap", 0)),
			int(train_stash.get("parts", 0)),
			int(train_stash.get("fuel", 0)),
			int(train_stash.get("supplies", 0)),
		]
	if _loot_counter_label != null:
		_loot_counter_label.text = "街區搜刮點剩餘：%d / %d" % [loot_remaining, loot_total]


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
			zh = "搜刮／操作中 🔧"
		"roll":
			zh = "戰術翻滾 💨"
	for entry in _squad_cards:
		if str(entry["char_id"]) == char_id:
			(entry["state_label"] as Label).text = "動作：%s" % zh
			break


func set_camera_locked(locked: bool) -> void:
	if _camera_btn != null:
		_camera_btn.text = "🎥 鎖定 [Y]" if locked else "🎥 自由 [Y]"


func set_camera_orthographic(ortho: bool) -> void:
	if _proj_btn != null:
		_proj_btn.text = "📽️ Zomboid 正交 [O]" if ortho else "📽️ RO 透視 [O]"


func set_interact_hint(station_label: String) -> void:
	if station_label.is_empty():
		set_interact_prompt_text("")
	else:
		set_interact_prompt_text("[按住 E / F] 互動：%s" % station_label)


func set_interact_prompt_text(prompt_text: String, accent: Color = Color(0.45, 0.94, 1.0)) -> void:
	if _interact_hint_label == null or _interact_hint_panel == null:
		return
	if prompt_text.is_empty():
		_interact_hint_panel.visible = false
	else:
		_interact_hint_label.text = prompt_text
		_interact_hint_label.add_theme_color_override("font_color", accent)
		_interact_hint_panel.visible = true


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
