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
signal weapon_slot_requested(slot_index: int)
signal cheat_panel_requested()
signal flashlight_toggle_requested()

var _squad_cards: Array[Dictionary] = []
var _status_label: Label = null
var _seed_label: Label = null
var _timer_label: Label = null
var _mission_label: Label = null
var _cheat_badge_label: Label = null

# Clock Card below Minimap
var _clock_phase_label: Label = null
var _clock_timer_label: Label = null
var _clock_rail_label: Label = null
var _clock_bar: ProgressBar = null
var _blood_moon_label: Label = null
var _blood_moon_bar: ProgressBar = null

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
var _weapon_slot_buttons: Array[Button] = []

# Bottom-Center: 5-Slot Quickbelt
var _belt_buttons: Array[Button] = []

# Center-Bottom Interact Prompt
var _interact_hint_panel: PanelContainer = null
var _interact_hint_label: Label = null

var _camera_btn: Button = null
var _proj_btn: Button = null
var _flashlight_btn: Button = null
var _interactive_panels: Array[Control] = []


func setup(squad: Array[SquadCharacter]) -> void:
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = TacticalTheme.build_theme(14)
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


# --- TOP-LEFT: Compact Run Timer, Mission & Quick Utility Buttons ---
func _build_top_left_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL, TacticalTheme.ACCENT_CYAN, 3, 12, 9))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	_seed_label = Label.new()
	_seed_label.text = "SECTOR #--"
	_seed_label.add_theme_font_size_override("font_size", 13)
	_seed_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	row.add_child(_seed_label)

	var train_btn := Button.new()
	train_btn.text = "[T] 列車"
	train_btn.pressed.connect(func(): train_blueprint_requested.emit())
	row.add_child(train_btn)

	var build_btn := Button.new()
	build_btn.text = "[B] 建造"
	build_btn.pressed.connect(func(): build_menu_requested.emit())
	row.add_child(build_btn)

	var hub_btn := Button.new()
	hub_btn.text = "[H] 基地"
	hub_btn.pressed.connect(func(): hub_requested.emit())
	row.add_child(hub_btn)

	_proj_btn = Button.new()
	_proj_btn.text = "[O] ORTHO"
	_proj_btn.pressed.connect(func(): camera_projection_toggled.emit())
	row.add_child(_proj_btn)

	_camera_btn = Button.new()
	_camera_btn.text = "[Y] LOCK"
	_camera_btn.pressed.connect(func(): camera_lock_toggled.emit())
	row.add_child(_camera_btn)

	var cheat_btn := Button.new()
	cheat_btn.text = "[F1] DEV"
	cheat_btn.pressed.connect(func(): cheat_panel_requested.emit())
	row.add_child(cheat_btn)

	_flashlight_btn = Button.new()
	_flashlight_btn.text = "[L] 戰術燈"
	_flashlight_btn.pressed.connect(func(): flashlight_toggle_requested.emit())
	row.add_child(_flashlight_btn)

	_cheat_badge_label = Label.new()
	_cheat_badge_label.visible = false
	_cheat_badge_label.add_theme_font_size_override("font_size", 12)
	_cheat_badge_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_EMERALD)
	vbox.add_child(_cheat_badge_label)

	_timer_label = Label.new()
	_timer_label.text = "T-MINUS 06:00  |  PHASE 1  |  KILLS 0"
	_timer_label.add_theme_font_size_override("font_size", 14)
	_timer_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	vbox.add_child(_timer_label)

	_mission_label = Label.new()
	_mission_label.text = "OBJ // LOADING MISSION..."
	_mission_label.add_theme_font_size_override("font_size", 14)
	_mission_label.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	vbox.add_child(_mission_label)

	_status_label = Label.new()
	_status_label.text = "WASD 移動  |  LMB 射擊  |  1-3 切槍  |  4-8 道具  |  RMB 選單  |  B 建造  |  SPACE 翻滾"
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	vbox.add_child(_status_label)


# --- TOP-RIGHT: Tactical Radar Minimap + Compact Train/Cargo Status ---
func _build_top_right_minimap_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "MinimapPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -302.0
	panel.offset_top = 14.0
	panel.offset_right = -16.0
	panel.offset_bottom = 446.0
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL, TacticalTheme.ACCENT_CYAN, 2, 12, 10))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var map_hdr := HBoxContainer.new()
	vbox.add_child(map_hdr)

	var map_title := Label.new()
	map_title.text = "RADAR // SECTOR"
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_title.add_theme_font_size_override("font_size", 13)
	map_title.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	map_hdr.add_child(map_title)

	var legend := Label.new()
	legend.text = "◆OBJ  ●LOOT  ●HOSTILE"
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	map_hdr.add_child(legend)

	_minimap = MinimapWidget.new()
	_minimap.name = "MinimapWidget"
	vbox.add_child(_minimap)

	var clock_card := PanelContainer.new()
	clock_card.name = "WorldClockCard"
	clock_card.add_theme_stylebox_override(
		"panel",
		TacticalTheme.make_accent_card_style(TacticalTheme.BG_CARD, TacticalTheme.ACCENT_CYAN, 2, 10, 6)
	)
	vbox.add_child(clock_card)

	var clock_vbox := VBoxContainer.new()
	clock_vbox.add_theme_constant_override("separation", 4)
	clock_card.add_child(clock_vbox)

	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 8)
	clock_vbox.add_child(clock_row)

	_clock_phase_label = Label.new()
	_clock_phase_label.text = "DAY 1 · 白晝"
	_clock_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock_phase_label.add_theme_font_size_override("font_size", 13)
	_clock_phase_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	clock_row.add_child(_clock_phase_label)

	_clock_rail_label = Label.new()
	_clock_rail_label.text = "RAIL OK"
	_clock_rail_label.add_theme_font_size_override("font_size", 11)
	_clock_rail_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_EMERALD)
	clock_row.add_child(_clock_rail_label)

	_clock_timer_label = Label.new()
	_clock_timer_label.text = "03:00"
	_clock_timer_label.add_theme_font_size_override("font_size", 14)
	_clock_timer_label.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	clock_row.add_child(_clock_timer_label)

	_clock_bar = ProgressBar.new()
	_clock_bar.custom_minimum_size = Vector2(0.0, 6.0)
	_clock_bar.max_value = 1.0
	_clock_bar.value = 0.0
	_clock_bar.show_percentage = false
	_clock_bar.add_theme_stylebox_override("background", TacticalTheme.make_bar_bg())
	_clock_bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(TacticalTheme.ACCENT_CYAN))
	clock_vbox.add_child(_clock_bar)

	var bm_row := HBoxContainer.new()
	bm_row.add_theme_constant_override("separation", 8)
	clock_vbox.add_child(bm_row)

	_blood_moon_label = Label.new()
	_blood_moon_label.text = "BLOOD MOON  0%"
	_blood_moon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blood_moon_label.add_theme_font_size_override("font_size", 11)
	_blood_moon_label.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	bm_row.add_child(_blood_moon_label)

	_blood_moon_bar = ProgressBar.new()
	_blood_moon_bar.custom_minimum_size = Vector2(124.0, 7.0)
	_blood_moon_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_blood_moon_bar.max_value = 100.0
	_blood_moon_bar.value = 0.0
	_blood_moon_bar.show_percentage = false
	_blood_moon_bar.add_theme_stylebox_override("background", TacticalTheme.make_bar_bg())
	_blood_moon_bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(TacticalTheme.ACCENT_CRIMSON))
	bm_row.add_child(_blood_moon_bar)

	var hull_row := HBoxContainer.new()
	hull_row.add_theme_constant_override("separation", 8)
	vbox.add_child(hull_row)

	var hull_lbl := Label.new()
	hull_lbl.text = "HULL"
	hull_lbl.add_theme_font_size_override("font_size", 12)
	hull_lbl.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	hull_row.add_child(hull_lbl)

	_hull_bar = ProgressBar.new()
	_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hull_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_hull_bar.max_value = 1000.0
	_hull_bar.value = 1000.0
	_hull_bar.show_percentage = false
	_hull_bar.add_theme_stylebox_override("background", TacticalTheme.make_bar_bg())
	_hull_bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(TacticalTheme.ACCENT_EMERALD))
	hull_row.add_child(_hull_bar)

	_hull_value_label = Label.new()
	_hull_value_label.text = "100%"
	_hull_value_label.add_theme_font_size_override("font_size", 12)
	_hull_value_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_EMERALD)
	hull_row.add_child(_hull_value_label)

	_backpack_value_label = Label.new()
	_backpack_value_label.text = "BAG 0/12  |  SCR0 PRT0 FUL0 SUP0"
	_backpack_value_label.add_theme_font_size_override("font_size", 12)
	_backpack_value_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	vbox.add_child(_backpack_value_label)

	_stash_detail_label = Label.new()
	_stash_detail_label.text = "STASH (0)  |  SCR0 PRT0 FUL0 SUP0"
	_stash_detail_label.add_theme_font_size_override("font_size", 12)
	_stash_detail_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	vbox.add_child(_stash_detail_label)

	_consist_summary_label = Label.new()
	_consist_summary_label.text = "CONSIST 3/3  |  TURRETS 1"
	_consist_summary_label.add_theme_font_size_override("font_size", 12)
	_consist_summary_label.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	vbox.add_child(_consist_summary_label)

	_boarding_badge = Label.new()
	_boarding_badge.visible = false
	_boarding_badge.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_boarding_badge)


# --- BOTTOM-LEFT: Survival Vitals (HP / STA / NUT) ---
func _build_bottom_left_vitals_panel(root: Control, squad: Array[SquadCharacter]) -> void:
	var panel := PanelContainer.new()
	panel.name = "SurvivalVitalsPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = -168.0
	panel.offset_right = 338.0
	panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL, TacticalTheme.ACCENT_CYAN, 3, 14, 10))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var p_name: String = squad[0].display_name if not squad.is_empty() else "OPERATOR"
	var name_lbl := Label.new()
	name_lbl.text = "UNIT // %s" % p_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	hdr.add_child(name_lbl)

	_player_state_label = Label.new()
	_player_state_label.text = "STANDBY"
	_player_state_label.add_theme_font_size_override("font_size", 12)
	_player_state_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	hdr.add_child(_player_state_label)

	# 1. HP Bar
	var hp_row := _create_vital_row(vbox, "HP  生命", TacticalTheme.ACCENT_EMERALD)
	_hp_bar = hp_row["bar"] as ProgressBar
	_hp_val_label = hp_row["label"] as Label

	# 2. Stamina Bar
	var sta_row := _create_vital_row(vbox, "STA 體力", TacticalTheme.ACCENT_CYAN)
	_stamina_bar = sta_row["bar"] as ProgressBar
	_stamina_val_label = sta_row["label"] as Label

	# 3. Hunger Bar
	var hun_row := _create_vital_row(vbox, "NUT 補給", TacticalTheme.ACCENT_AMBER)
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
	lbl.custom_minimum_size = Vector2(76.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", TacticalTheme.make_bar_bg())
	bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(bar_color))
	row.add_child(bar)

	var val := Label.new()
	val.text = "100"
	val.custom_minimum_size = Vector2(40.0, 0.0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	row.add_child(val)

	return {"bar": bar, "label": val}


# --- BOTTOM-CENTER: 5-Slot Quickbelt (4-8) ---
func _build_bottom_center_quickbelt(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "QuickbeltPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -336.0
	panel.offset_top = -98.0
	panel.offset_right = 336.0
	panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_panel_style(TacticalTheme.BG_PANEL, TacticalTheme.BORDER_STEEL, 1, 10, 8, 1))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	_belt_buttons.clear()
	for i in range(5):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120.0, 62.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		btn.text = "[%d] SLOT" % (i + 4)
		var slot_idx: int = i
		btn.pressed.connect(func(): quickbelt_slot_requested.emit(slot_idx))
		row.add_child(btn)
		_belt_buttons.append(btn)


# --- BOTTOM-RIGHT: Current Weapon / Ammo Panel ---
func _build_bottom_right_weapon_panel(root: Control, squad: Array[SquadCharacter]) -> void:
	var panel := PanelContainer.new()
	panel.name = "WeaponAmmoPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -356.0
	panel.offset_top = -180.0
	panel.offset_right = -16.0
	panel.offset_bottom = -14.0
	panel.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL, TacticalTheme.ACCENT_AMBER, 3, 14, 10))
	root.add_child(panel)
	_interactive_panels.append(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 6)
	vbox.add_child(slot_row)
	_weapon_slot_buttons.clear()
	var default_slots := SquadConfig.get_default_loadout()
	for i: int in range(default_slots.size()):
		var wcfg: Dictionary = default_slots[i]
		var wbtn := Button.new()
		wbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wbtn.add_theme_font_size_override("font_size", 12)
		wbtn.text = "[%d] %s" % [i + 1, str(wcfg.get("short_name", ""))]
		var w_idx: int = i
		wbtn.pressed.connect(func(): weapon_slot_requested.emit(w_idx))
		slot_row.add_child(wbtn)
		_weapon_slot_buttons.append(wbtn)

	var w_label: String = squad[0].weapon_label if not squad.is_empty() else "M4A1-S 消音突擊步槍"
	_weapon_name_label = Label.new()
	_weapon_name_label.text = "[1] %s" % w_label
	_weapon_name_label.add_theme_font_size_override("font_size", 14)
	_weapon_name_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	vbox.add_child(_weapon_name_label)

	var ammo_row := HBoxContainer.new()
	vbox.add_child(ammo_row)

	_ammo_big_label = Label.new()
	_ammo_big_label.text = "30 / 30"
	_ammo_big_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ammo_big_label.add_theme_font_size_override("font_size", 26)
	_ammo_big_label.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	ammo_row.add_child(_ammo_big_label)

	var reload_tag := Label.new()
	reload_tag.text = "[R] RELOAD"
	reload_tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	reload_tag.add_theme_font_size_override("font_size", 12)
	reload_tag.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	ammo_row.add_child(reload_tag)

	_ammo_bar = ProgressBar.new()
	_ammo_bar.custom_minimum_size = Vector2(0.0, 8.0)
	_ammo_bar.max_value = 30.0
	_ammo_bar.value = 30.0
	_ammo_bar.show_percentage = false
	_ammo_bar.add_theme_stylebox_override("background", TacticalTheme.make_bar_bg())
	_ammo_bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(TacticalTheme.ACCENT_AMBER))
	vbox.add_child(_ammo_bar)

	_weapon_hint_label = Label.new()
	_weapon_hint_label.text = "[1-3] WEAPON  |  [V] SUPPRESSOR  |  [B] BUILD"
	_weapon_hint_label.add_theme_font_size_override("font_size", 11)
	_weapon_hint_label.add_theme_color_override("font_color", TacticalTheme.TEXT_MUTED)
	vbox.add_child(_weapon_hint_label)


func _build_interact_prompt(root: Control) -> void:
	_interact_hint_panel = PanelContainer.new()
	_interact_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interact_hint_panel.offset_left = -350.0
	_interact_hint_panel.offset_top = -164.0
	_interact_hint_panel.offset_right = 350.0
	_interact_hint_panel.offset_bottom = -114.0
	_interact_hint_panel.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL_DEEP, TacticalTheme.ACCENT_CYAN, 3, 14, 8))
	_interact_hint_panel.visible = false
	root.add_child(_interact_hint_panel)

	_interact_hint_label = Label.new()
	_interact_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact_hint_label.add_theme_font_size_override("font_size", 15)
	_interact_hint_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
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
		_hp_bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(TacticalTheme.ACCENT_EMERALD if r > 0.5 else (TacticalTheme.ACCENT_AMBER if r > 0.25 else TacticalTheme.ACCENT_CRIMSON)))
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
		var key_num: int = i + 4
		if infinite_mode:
			btn.text = "[%d] %s\nQTY: ∞" % [key_num, str(s.get("name", ""))]
			btn.disabled = false
			TacticalTheme.style_state_button(btn, true, TacticalTheme.ACCENT_EMERALD)
		else:
			btn.text = "[%d] %s\nx%d" % [key_num, str(s.get("name", "")), cnt]
			btn.disabled = cnt <= 0
			TacticalTheme.style_state_button(btn, false, TacticalTheme.BORDER_STEEL)


func update_weapon_info(slot_index: int, _weapon_id: String, weapon_label: String, supports_silencer: bool, silencer_attached: bool, loadout_summary: Array[Dictionary] = []) -> void:
	if _weapon_name_label != null:
		var sil_tag: String = (" // SUPPRESSED" if silencer_attached else " // UNSILENCED") if supports_silencer else ""
		_weapon_name_label.text = "[%d] %s%s" % [slot_index + 1, weapon_label, sil_tag]
	if _weapon_hint_label != null:
		if supports_silencer:
			_weapon_hint_label.text = "[1-3] WEAPON  |  [V] SUPPRESSOR  |  [B] BUILD"
		else:
			_weapon_hint_label.text = "[1-3] WEAPON  |  [LMB] FIRE  |  [B] BUILD"
	for i: int in range(mini(loadout_summary.size(), _weapon_slot_buttons.size())):
		var entry: Dictionary = loadout_summary[i]
		var btn: Button = _weapon_slot_buttons[i]
		var is_cur: bool = (i == slot_index)
		btn.text = "[%d] %s" % [i + 1, str(entry.get("short_name", ""))]
		TacticalTheme.style_state_button(btn, is_cur, TacticalTheme.ACCENT_AMBER)


func update_cheat_status(god_mode: bool, infinite_resources: bool, pause_spawns: bool) -> void:
	if _cheat_badge_label == null:
		return
	var tags: PackedStringArray = PackedStringArray()
	if god_mode:
		tags.append("GOD")
	if infinite_resources:
		tags.append("INF_RES")
	if pause_spawns:
		tags.append("NO_SPAWN")
	if tags.is_empty():
		_cheat_badge_label.visible = false
	else:
		_cheat_badge_label.visible = true
		_cheat_badge_label.text = "DEV OVERRIDE // " + " · ".join(tags)


func set_sector_info(seed_value: int, block_summary: String) -> void:
	if _seed_label != null:
		_seed_label.text = "SECTOR #%d  //  %s" % [seed_value, block_summary]


func update_run_timer(remaining_sec: float, stage_name: String, kills: int, active_zombies: int) -> void:
	if _timer_label == null:
		return
	var mins: int = int(floor(remaining_sec / 60.0))
	var secs: int = int(floor(fmod(remaining_sec, 60.0)))
	_timer_label.text = "T-%02d:%02d  |  %s  |  KILLS %d (ACTIVE %d)" % [mins, secs, stage_name, kills, active_zombies]
	_timer_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CRIMSON if remaining_sec <= 60.0 else TacticalTheme.ACCENT_AMBER)


func update_day_night_and_train(
	phase: int,
	day_num: int,
	remaining_sec: float,
	progress: float,
	is_mobile: bool,
	flashlight_on: bool,
	blood_moon_val: float = 0.0,
	blood_moon_warn: bool = false
) -> void:
	var phase_cn: String = "白晝"
	var col: Color = TacticalTheme.ACCENT_CYAN
	if phase == DayNightCycleManager.Phase.DUSK:
		phase_cn = "黃昏"
		col = TacticalTheme.ACCENT_AMBER
	elif phase == DayNightCycleManager.Phase.NIGHT:
		phase_cn = "黑夜"
		col = Color(0.56, 0.74, 1.0)
	elif phase == DayNightCycleManager.Phase.BLOOD_MOON:
		phase_cn = "血月"
		col = TacticalTheme.ACCENT_CRIMSON

	if _clock_phase_label != null:
		_clock_phase_label.text = "DAY %d · %s" % [day_num, phase_cn]
		_clock_phase_label.add_theme_color_override("font_color", col)
	if _clock_timer_label != null:
		var rem: int = int(ceilf(maxf(0.0, remaining_sec)))
		_clock_timer_label.text = "%02d:%02d" % [rem / 60, rem % 60]
		_clock_timer_label.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	if _clock_rail_label != null:
		_clock_rail_label.text = "行駛解鎖" if is_mobile else "夜鎖定"
		_clock_rail_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_EMERALD if is_mobile else TacticalTheme.ACCENT_CRIMSON)
	if _clock_bar != null:
		_clock_bar.value = clampf(progress, 0.0, 1.0)
		_clock_bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(col))

	if _blood_moon_label != null:
		var pct_bm: int = int(round(clampf(blood_moon_val, 0.0, 100.0)))
		if phase == DayNightCycleManager.Phase.BLOOD_MOON:
			_blood_moon_label.text = "BLOOD MOON // 降臨"
			_blood_moon_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CRIMSON)
		elif blood_moon_warn:
			_blood_moon_label.text = "BLOOD MOON // 預警!"
			_blood_moon_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CRIMSON)
		else:
			_blood_moon_label.text = "BLOOD MOON  %d%%" % pct_bm
			_blood_moon_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER if pct_bm >= 70 else TacticalTheme.TEXT_SECONDARY)
	if _blood_moon_bar != null:
		_blood_moon_bar.value = 100.0 if phase == DayNightCycleManager.Phase.BLOOD_MOON else clampf(blood_moon_val, 0.0, 100.0)

	if _flashlight_btn != null:
		_flashlight_btn.text = "[L] 戰術燈 ON" if flashlight_on else "[L] 戰術燈 OFF"
		TacticalTheme.style_state_button(_flashlight_btn, flashlight_on, TacticalTheme.ACCENT_EMERALD)


func update_mission_status(mission_text: String, compass_text: String) -> void:
	if _mission_label == null:
		return
	_mission_label.text = "%s  //  %s" % [mission_text, compass_text]


func update_player_vitals(hp: float, max_hp: float, ammo: int, mag_size: int, reloading: bool) -> void:
	if _hp_bar != null:
		_hp_bar.max_value = maxf(1.0, max_hp)
		_hp_bar.value = clampf(hp, 0.0, max_hp)
	if _hp_val_label != null:
		_hp_val_label.text = "%d" % int(round(hp))
	if _ammo_big_label != null:
		_ammo_big_label.text = "RELOADING..." if reloading else "%d / %d" % [ammo, mag_size]
		_ammo_big_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER if reloading or ammo <= 5 else TacticalTheme.TEXT_PRIMARY)
	if _ammo_bar != null:
		_ammo_bar.max_value = float(maxi(1, mag_size))
		_ammo_bar.value = 0.0 if reloading else float(ammo)


func update_train_consist_summary(stats: Dictionary) -> void:
	if _consist_summary_label == null:
		return
	_consist_summary_label.text = "CONSIST %d/%d  |  PWR %d/%d  |  TURRETS %d" % [
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
		var bar_color := TacticalTheme.ACCENT_EMERALD if ratio > 0.6 else (TacticalTheme.ACCENT_AMBER if ratio > 0.3 else TacticalTheme.ACCENT_CRIMSON)
		_hull_bar.add_theme_stylebox_override("fill", TacticalTheme.make_bar_fill(bar_color))
	if _hull_value_label != null:
		_hull_value_label.text = "%d%%" % int(round(ratio * 100.0))


func set_boarding_zone_active(in_zone: bool) -> void:
	if _boarding_badge == null:
		return
	_boarding_badge.visible = in_zone
	if in_zone:
		_boarding_badge.text = "[BOARDING ZONE] 位於列車安全區"
		_boarding_badge.add_theme_color_override("font_color", TacticalTheme.ACCENT_EMERALD)


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
		_backpack_value_label.text = "BAG %d/%d  |  金%d 零%d 燃%d 補%d" % [
			used,
			maxi(1, capacity),
			int(backpack.get("scrap", 0)),
			int(backpack.get("parts", 0)),
			int(backpack.get("fuel", 0)),
			int(backpack.get("supplies", 0)),
		]
		_backpack_value_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CRIMSON if used >= capacity else TacticalTheme.ACCENT_CYAN)
	if _stash_detail_label != null:
		_stash_detail_label.text = "STASH (%d)  |  金%d 零%d 燃%d 補%d" % [
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
	var tag := "STANDBY"
	match action_name:
		"walk":
			tag = "MOVING"
		"shoot":
			tag = "FIRING"
		"interact":
			tag = "UPLINK"
		"roll":
			tag = "EVADE"
		"reload":
			tag = "RELOAD"
		"death":
			tag = "DOWNED"
		"hit":
			tag = "IMPACT"
	_player_state_label.text = tag


func set_camera_locked(locked: bool) -> void:
	if _camera_btn != null:
		_camera_btn.text = "[Y] LOCK" if locked else "[Y] FREE"


func set_camera_orthographic(ortho: bool) -> void:
	if _proj_btn != null:
		_proj_btn.text = "[O] ORTHO" if ortho else "[O] PERSP"


func set_interact_hint(station_label: String) -> void:
	if station_label.is_empty():
		set_interact_prompt_text("")
	else:
		set_interact_prompt_text("[E / RMB] INTERACT // %s" % station_label)


func set_interact_prompt_text(prompt_text: String, accent: Color = TacticalTheme.ACCENT_CYAN) -> void:
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
