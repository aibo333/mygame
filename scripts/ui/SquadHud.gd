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
signal build_menu_requested()
signal quickbelt_slot_requested(slot_index: int)
signal cheat_panel_requested()

var _squad_cards: Array[Dictionary] = []
var _status_label: Label = null
var _seed_label: Label = null
var _timer_label: Label = null
var _mission_label: Label = null
var _cheat_badge_label: Label = null

# Bottom-Left: Survival Vitals (HP / Stamina / Hunger)
var _hp_bar: ProgressBar = null
var _hp_val_label: Label = null
var _stamina_bar: ProgressBar = null
var _stamina_val_label: Label = null
var _hunger_bar: ProgressBar = null
var _hunger_val_label: Label = null
var _player_state_label: Label = null

# Top-Right: Tactical Minimap + Compact Train/Inventory Readout
var _minimap: MinimapWidget = null
var _hull_bar: ProgressBar = null
var _hull_value_label: Label = null
var _consist_summary_label: Label = null
var _boarding_badge: Label = null
var _backpack_value_label: Label = null
var _stash_detail_label: Label = null

# Bottom-Right: Current Weapon / Ammo Panel
var _weapon_name_label: Label = null
var _ammo_big_label: Label = null
var _ammo_bar: ProgressBar = null
var _weapon_hint_label: Label = null

# Bottom-Center: 5-Slot Quickbelt
var _belt_buttons: Array[Button] = []

# Center-Bottom Interact Prompt
var _interact_hint_panel: PanelContainer = null
var _interact_hint_label: Label = null

var _camera_btn: Button = null
var _proj_btn: Button = null
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

	_build_top_left_bar(root)
	_build_top_right_minimap_panel(root)
	_build_bottom_left_vitals_panel(root, squad)
	_build_bottom_center_quickbelt(root)
	_build_bottom_right_weapon_panel(root, squad)
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
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _make_bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	return sb


func _make_bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	sb.border_color = Color(0.28, 0.32, 0.40, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


# --- TOP-LEFT: Compact Run Timer, Mission & Quick Utility Buttons ---
func _build_top_left_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.09, 0.09, 0.88), Color(0.84, 0.64, 0.34, 0.85)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	_seed_label = Label.new()
	_seed_label.text = "🧭 Seed #--"
	_seed_label.add_theme_font_size_override("font_size", 15)
	_seed_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	row.add_child(_seed_label)

	var train_btn := Button.new()
	train_btn.text = "🚂 列車 [T]"
	train_btn.pressed.connect(func(): train_blueprint_requested.emit())
	row.add_child(train_btn)

	var build_btn := Button.new()
	build_btn.text = "🏗 建造 [B]"
	build_btn.pressed.connect(func(): build_menu_requested.emit())
	row.add_child(build_btn)

	var hub_btn := Button.new()
	hub_btn.text = "🏕 大廳 [H]"
	hub_btn.pressed.connect(func(): hub_requested.emit())
	row.add_child(hub_btn)

	_proj_btn = Button.new()
	_proj_btn.text = "📽️ Zomboid [O]"
	_proj_btn.pressed.connect(func(): camera_projection_toggled.emit())
	row.add_child(_proj_btn)

	_camera_btn = Button.new()
	_camera_btn.text = "🎥 鎖定 [Y]"
	_camera_btn.pressed.connect(func(): camera_lock_toggled.emit())
	row.add_child(_camera_btn)

	var cheat_btn := Button.new()
	cheat_btn.text = "🛠 作弊 [F1]"
	cheat_btn.pressed.connect(func(): cheat_panel_requested.emit())
	row.add_child(cheat_btn)

	_cheat_badge_label = Label.new()
	_cheat_badge_label.visible = false
	_cheat_badge_label.add_theme_font_size_override("font_size", 14)
	_cheat_badge_label.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62))
	vbox.add_child(_cheat_badge_label)

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
	_status_label.text = "WASD 移動 ｜ 左鍵射擊 ｜ 右鍵選單互動 ｜ B 建造防禦 ｜ 1-5 快速腰帶 ｜ Space 翻滾"
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96))
	vbox.add_child(_status_label)


# --- TOP-RIGHT: Tactical Radar Minimap + Compact Train/Cargo Status ---
func _build_top_right_minimap_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "MinimapPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -302.0
	panel.offset_top = 14.0
	panel.offset_right = -16.0
	panel.offset_bottom = 358.0
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.11, 0.14, 0.90), Color(0.42, 0.78, 0.94, 0.85)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var map_hdr := HBoxContainer.new()
	vbox.add_child(map_hdr)

	var map_title := Label.new()
	map_title.text = "🗺 戰術小地圖"
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_title.add_theme_font_size_override("font_size", 16)
	map_title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	map_hdr.add_child(map_title)

	var legend := Label.new()
	legend.text = "🟣主線 🟡箱 🔴屍"
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color(0.80, 0.86, 0.92))
	map_hdr.add_child(legend)

	_minimap = MinimapWidget.new()
	_minimap.name = "MinimapWidget"
	vbox.add_child(_minimap)

	var hull_row := HBoxContainer.new()
	vbox.add_child(hull_row)

	var hull_lbl := Label.new()
	hull_lbl.text = "🚂 列車"
	hull_lbl.add_theme_font_size_override("font_size", 14)
	hull_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.80))
	hull_row.add_child(hull_lbl)

	_hull_bar = ProgressBar.new()
	_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hull_bar.custom_minimum_size = Vector2(0.0, 14.0)
	_hull_bar.max_value = 1000.0
	_hull_bar.value = 1000.0
	_hull_bar.show_percentage = false
	_hull_bar.add_theme_stylebox_override("background", _make_bar_bg())
	_hull_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.28, 0.84, 0.48)))
	hull_row.add_child(_hull_bar)

	_hull_value_label = Label.new()
	_hull_value_label.text = "100%"
	_hull_value_label.add_theme_font_size_override("font_size", 14)
	_hull_value_label.add_theme_color_override("font_color", Color(0.45, 0.96, 0.64))
	hull_row.add_child(_hull_value_label)

	_backpack_value_label = Label.new()
	_backpack_value_label.text = "🎒 背包 0/12 ｜ 金0 零0 燃0 補0"
	_backpack_value_label.add_theme_font_size_override("font_size", 14)
	_backpack_value_label.add_theme_color_override("font_color", Color(0.66, 0.92, 1.0))
	vbox.add_child(_backpack_value_label)

	_stash_detail_label = Label.new()
	_stash_detail_label.text = "📦 暫存倉 0 ｜ 金0 零0 燃0 補0"
	_stash_detail_label.add_theme_font_size_override("font_size", 14)
	_stash_detail_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.46))
	vbox.add_child(_stash_detail_label)

	_consist_summary_label = Label.new()
	_consist_summary_label.text = "編成 3/3節 ｜ 砲塔 1座"
	_consist_summary_label.add_theme_font_size_override("font_size", 13)
	_consist_summary_label.add_theme_color_override("font_color", Color(0.84, 0.80, 0.72))
	vbox.add_child(_consist_summary_label)

	_boarding_badge = Label.new()
	_boarding_badge.visible = false
	vbox.add_child(_boarding_badge)


# --- BOTTOM-LEFT: Survival Vitals (生命 / 體力 / 飢餓) ---
func _build_bottom_left_vitals_panel(root: Control, squad: Array[SquadCharacter]) -> void:
	var panel := PanelContainer.new()
	panel.name = "SurvivalVitalsPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = -176.0
	panel.offset_right = 338.0
	panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.11, 0.09, 0.09, 0.92), Color(0.84, 0.64, 0.34, 0.88)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var p_name: String = squad[0].display_name if not squad.is_empty() else "特勤員"
	var name_lbl := Label.new()
	name_lbl.text = "👤 %s" % p_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.76))
	hdr.add_child(name_lbl)

	_player_state_label = Label.new()
	_player_state_label.text = "待機"
	_player_state_label.add_theme_font_size_override("font_size", 15)
	_player_state_label.add_theme_color_override("font_color", Color(0.56, 0.94, 1.0))
	hdr.add_child(_player_state_label)

	# 1. HP Bar
	var hp_row := _create_vital_row(vbox, "❤️ 生命", Color(0.90, 0.28, 0.28))
	_hp_bar = hp_row["bar"] as ProgressBar
	_hp_val_label = hp_row["label"] as Label

	# 2. Stamina Bar
	var sta_row := _create_vital_row(vbox, "⚡ 體力", Color(0.28, 0.82, 0.96))
	_stamina_bar = sta_row["bar"] as ProgressBar
	_stamina_val_label = sta_row["label"] as Label

	# 3. Hunger Bar
	var hun_row := _create_vital_row(vbox, "🍖 飢餓", Color(0.96, 0.68, 0.22))
	_hunger_bar = hun_row["bar"] as ProgressBar
	_hunger_val_label = hun_row["label"] as Label

	if not squad.is_empty():
		_squad_cards.append({
			"char_id": squad[0].char_id,
			"card": panel,
			"accent": squad[0].accent_color,
			"state_label": _player_state_label,
		})


func _create_vital_row(parent: VBoxContainer, title_text: String, bar_color: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = title_text
	lbl.custom_minimum_size = Vector2(78.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0.0, 18.0)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _make_bar_bg())
	bar.add_theme_stylebox_override("fill", _make_bar_fill(bar_color))
	row.add_child(bar)

	var val := Label.new()
	val.text = "100"
	val.custom_minimum_size = Vector2(44.0, 0.0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	row.add_child(val)

	return {"bar": bar, "label": val}


# --- BOTTOM-CENTER: 5-Slot Quickbelt (快速腰帶 1-5) ---
func _build_bottom_center_quickbelt(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "QuickbeltPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -336.0
	panel.offset_top = -104.0
	panel.offset_right = 336.0
	panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.10, 0.09, 0.92), Color(0.84, 0.64, 0.34, 0.90), 10))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	_belt_buttons.clear()
	for i in range(5):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120.0, 68.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 15)
		btn.text = "[%d] 道具" % (i + 1)
		var slot_idx: int = i
		btn.pressed.connect(func(): quickbelt_slot_requested.emit(slot_idx))
		row.add_child(btn)
		_belt_buttons.append(btn)


# --- BOTTOM-RIGHT: Current Weapon / Ammo Panel (當前武器 / 彈藥) ---
func _build_bottom_right_weapon_panel(root: Control, squad: Array[SquadCharacter]) -> void:
	var panel := PanelContainer.new()
	panel.name = "WeaponAmmoPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -324.0
	panel.offset_top = -152.0
	panel.offset_right = -16.0
	panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.11, 0.10, 0.10, 0.92), Color(0.84, 0.64, 0.34, 0.88)))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var w_label: String = squad[0].weapon_label if not squad.is_empty() else "突擊步槍 AR-15"
	_weapon_name_label = Label.new()
	_weapon_name_label.text = "🔫 %s" % w_label
	_weapon_name_label.add_theme_font_size_override("font_size", 16)
	_weapon_name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	vbox.add_child(_weapon_name_label)

	var ammo_row := HBoxContainer.new()
	vbox.add_child(ammo_row)

	_ammo_big_label = Label.new()
	_ammo_big_label.text = "30 / 30"
	_ammo_big_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ammo_big_label.add_theme_font_size_override("font_size", 28)
	_ammo_big_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	ammo_row.add_child(_ammo_big_label)

	var reload_tag := Label.new()
	reload_tag.text = "[R] 換彈"
	reload_tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	reload_tag.add_theme_font_size_override("font_size", 15)
	reload_tag.add_theme_color_override("font_color", Color(0.76, 0.84, 0.92))
	ammo_row.add_child(reload_tag)

	_ammo_bar = ProgressBar.new()
	_ammo_bar.custom_minimum_size = Vector2(0.0, 12.0)
	_ammo_bar.max_value = 30.0
	_ammo_bar.value = 30.0
	_ammo_bar.show_percentage = false
	_ammo_bar.add_theme_stylebox_override("background", _make_bar_bg())
	_ammo_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.98, 0.78, 0.28)))
	vbox.add_child(_ammo_bar)

	_weapon_hint_label = Label.new()
	_weapon_hint_label.text = "左鍵射擊 ｜ 右鍵物件選單 ｜ [B] 建造"
	_weapon_hint_label.add_theme_font_size_override("font_size", 14)
	_weapon_hint_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	vbox.add_child(_weapon_hint_label)


func _build_interact_prompt(root: Control) -> void:
	_interact_hint_panel = PanelContainer.new()
	_interact_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interact_hint_panel.offset_left = -350.0
	_interact_hint_panel.offset_top = -170.0
	_interact_hint_panel.offset_right = 350.0
	_interact_hint_panel.offset_bottom = -118.0
	_interact_hint_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.08, 0.11, 0.92), Color(0.42, 0.88, 1.0, 0.86), 10))
	_interact_hint_panel.visible = false
	root.add_child(_interact_hint_panel)

	_interact_hint_label = Label.new()
	_interact_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact_hint_label.add_theme_font_size_override("font_size", 18)
	_interact_hint_label.add_theme_color_override("font_color", Color(0.45, 0.94, 1.0))
	_interact_hint_panel.add_child(_interact_hint_label)


# --- Public Update APIs ---
func update_minimap(snapshot: Dictionary) -> void:
	if _minimap != null:
		_minimap.update_snapshot(snapshot)


func update_survival_vitals(hp: float, max_hp: float, stamina: float, max_stamina: float, hunger: float, max_hunger: float) -> void:
	if _hp_bar != null:
		_hp_bar.max_value = maxf(1.0, max_hp)
		_hp_bar.value = clampf(hp, 0.0, max_hp)
		var r: float = hp / maxf(1.0, max_hp)
		_hp_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.32, 0.88, 0.50) if r > 0.5 else (Color(0.96, 0.68, 0.22) if r > 0.25 else Color(0.94, 0.26, 0.24))))
	if _hp_val_label != null:
		_hp_val_label.text = "%d" % int(round(hp))
	if _stamina_bar != null:
		_stamina_bar.max_value = maxf(1.0, max_stamina)
		_stamina_bar.value = clampf(stamina, 0.0, max_stamina)
	if _stamina_val_label != null:
		_stamina_val_label.text = "%d" % int(round(stamina))
	if _hunger_bar != null:
		_hunger_bar.max_value = maxf(1.0, max_hunger)
		_hunger_bar.value = clampf(hunger, 0.0, max_hunger)
	if _hunger_val_label != null:
		_hunger_val_label.text = "%d" % int(round(hunger))


func update_quickbelt(slots: Array[Dictionary], infinite_mode: bool = false) -> void:
	for i in range(mini(slots.size(), _belt_buttons.size())):
		var s: Dictionary = slots[i]
		var cnt: int = int(s.get("count", 0))
		var btn: Button = _belt_buttons[i]
		if infinite_mode:
			btn.text = "[%d] %s %s\n剩餘 ∞" % [i + 1, str(s.get("icon", "")), str(s.get("name", ""))]
			btn.disabled = false
			btn.modulate = Color(0.76, 1.0, 0.84)
		else:
			btn.text = "[%d] %s %s\n剩餘 x%d" % [i + 1, str(s.get("icon", "")), str(s.get("name", "")), cnt]
			btn.disabled = cnt <= 0
			btn.modulate = Color(1.0, 0.96, 0.86) if cnt > 0 else Color(0.56, 0.54, 0.52)


func update_cheat_status(god_mode: bool, infinite_resources: bool, pause_spawns: bool) -> void:
	if _cheat_badge_label == null:
		return
	var tags: PackedStringArray = PackedStringArray()
	if god_mode:
		tags.append("🛡️無敵")
	if infinite_resources:
		tags.append("♾️無限資源")
	if pause_spawns:
		tags.append("⏸️暫停出怪")
	if tags.is_empty():
		_cheat_badge_label.visible = false
	else:
		_cheat_badge_label.visible = true
		_cheat_badge_label.text = "🛠 DEV CHEAT ON： " + " ｜ ".join(tags)


func set_sector_info(seed_value: int, block_summary: String) -> void:
	if _seed_label != null:
		_seed_label.text = "🧭 #%d ｜ %s" % [seed_value, block_summary]


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
	if _hp_bar != null:
		_hp_bar.max_value = maxf(1.0, max_hp)
		_hp_bar.value = clampf(hp, 0.0, max_hp)
	if _hp_val_label != null:
		_hp_val_label.text = "%d" % int(round(hp))
	if _ammo_big_label != null:
		_ammo_big_label.text = "換彈中..." if reloading else "%d / %d" % [ammo, mag_size]
		_ammo_big_label.add_theme_color_override("font_color", Color(1.0, 0.66, 0.30) if reloading or ammo <= 5 else Color(0.98, 0.98, 1.0))
	if _ammo_bar != null:
		_ammo_bar.max_value = float(maxi(1, mag_size))
		_ammo_bar.value = 0.0 if reloading else float(ammo)


func update_train_consist_summary(stats: Dictionary) -> void:
	if _consist_summary_label == null:
		return
	_consist_summary_label.text = "編成 %d/%d節 ｜ 動力 %d/%d ｜ 砲塔 %d座" % [
		int(stats.get("carriage_count", 3)),
		int(stats.get("max_carriages", 3)),
		int(stats.get("power_used", 5)),
		int(stats.get("power_capacity", 6)),
		int(stats.get("turret_count", 1)),
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
		_hull_value_label.text = "%d%%" % int(round(ratio * 100.0))


func set_boarding_zone_active(in_zone: bool) -> void:
	if _boarding_badge == null:
		return
	_boarding_badge.visible = in_zone
	if in_zone:
		_boarding_badge.text = "✅ 已位於裝甲列車登車區"
		_boarding_badge.add_theme_color_override("font_color", Color(0.42, 0.96, 0.68))


func update_inventory(
	backpack: Dictionary,
	used: int,
	capacity: int,
	train_stash: Dictionary,
	stash_total: int,
	_loot_remaining: int,
	_loot_total: int
) -> void:
	if _backpack_value_label != null:
		_backpack_value_label.text = "🎒 背包 %d/%d ｜ 金%d 零%d 燃%d 補%d" % [
			used,
			maxi(1, capacity),
			int(backpack.get("scrap", 0)),
			int(backpack.get("parts", 0)),
			int(backpack.get("fuel", 0)),
			int(backpack.get("supplies", 0)),
		]
		_backpack_value_label.add_theme_color_override("font_color", Color(1.0, 0.54, 0.36) if used >= capacity else Color(0.66, 0.92, 1.0))
	if _stash_detail_label != null:
		_stash_detail_label.text = "📦 暫存(%d) ｜ 金%d 零%d 燃%d 補%d" % [
			stash_total,
			int(train_stash.get("scrap", 0)),
			int(train_stash.get("parts", 0)),
			int(train_stash.get("fuel", 0)),
			int(train_stash.get("supplies", 0)),
		]


func set_active_character(_index: int) -> void:
	pass


func update_character_action(_char_id: String, action_name: String) -> void:
	if _player_state_label == null:
		return
	var zh := "待機"
	match action_name:
		"walk":
			zh = "移動中"
		"shoot":
			zh = "射擊 🔥"
		"interact":
			zh = "操作中 🔧"
		"roll":
			zh = "翻滾 💨"
	_player_state_label.text = zh


func set_camera_locked(locked: bool) -> void:
	if _camera_btn != null:
		_camera_btn.text = "🎥 鎖定 [Y]" if locked else "🎥 自由 [Y]"


func set_camera_orthographic(ortho: bool) -> void:
	if _proj_btn != null:
		_proj_btn.text = "📽️ Zomboid [O]" if ortho else "📽️ RO [O]"


func set_interact_hint(station_label: String) -> void:
	if station_label.is_empty():
		set_interact_prompt_text("")
	else:
		set_interact_prompt_text("[E / 右鍵選單] 互動：%s" % station_label)


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
