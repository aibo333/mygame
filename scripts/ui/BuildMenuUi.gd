class_name BuildMenuUi
extends CanvasLayer

signal structure_selected(kind: String)
signal closed()

const KIND_CODES: Dictionary = {
	"sandbag": "SB-01",
	"barricade": "BR-02",
	"landmine": "MN-03",
	"turret": "TR-04",
	"searchlight": "SL-05",
	"window_board": "WB-06",
}

var _panel: PanelContainer = null
var _materials_label: Label = null
var _buttons: Dictionary = {}
var _is_open: bool = false
var _selected_kind: String = "sandbag"


func setup() -> void:
	layer = 15
	_build_ui()
	set_open(false)


func is_open() -> bool:
	return _is_open


func set_open(open: bool) -> void:
	_is_open = open
	if _panel != null:
		_panel.visible = open
	if not open:
		closed.emit()


func is_mouse_over() -> bool:
	if not _is_open or _panel == null or not _panel.visible:
		return false
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	return _panel.get_global_rect().has_point(vp.get_mouse_position())


func refresh(manager: BuildDefenseManager, backpack: Dictionary, train_stash: Dictionary, selected_kind: String) -> void:
	_selected_kind = selected_kind
	if manager == null:
		return
	var pool: Dictionary = manager.get_combined_resources(backpack, train_stash)
	if _materials_label != null:
		if manager.infinite_resources:
			_materials_label.text = "FIELD FORTIFICATION [B] // DEV INFINITE STOCK ACTIVE  |  [LMB] DEPLOY  [Q] ROTATE  [RMB/ESC] EXIT"
		else:
			_materials_label.text = "FIELD FORTIFICATION [B] // STOCK: SCRAP %d | PARTS %d | FUEL %d  //  [LMB] DEPLOY  [Q] ROTATE  [ESC] EXIT" % [
				int(pool.get("scrap", 0)),
				int(pool.get("parts", 0)),
				int(pool.get("fuel", 0)),
			]
	for kind: String in BuildDefenseManager.STRUCTURE_ORDER:
		var btn: Button = _buttons.get(kind, null) as Button
		if btn == null:
			continue
		var spec: Dictionary = BuildDefenseManager.STRUCTURE_CATALOG[kind] as Dictionary
		var afford: bool = manager.can_afford_structure(kind, backpack, train_stash)
		var is_sel: bool = (kind == _selected_kind)
		var code: String = str(KIND_CODES.get(kind, "DF"))
		btn.text = "[%s] %s\n%s" % [code, str(spec.get("name", kind)), manager.format_cost(kind)]
		var accent: Color = spec.get("accent", TacticalTheme.ACCENT_CYAN) as Color
		if is_sel:
			TacticalTheme.style_state_button(btn, true, TacticalTheme.ACCENT_AMBER)
		elif afford:
			TacticalTheme.style_state_button(btn, false, accent)
		else:
			btn.add_theme_stylebox_override("normal", TacticalTheme.make_panel_style(Color(0.05, 0.06, 0.08, 0.85), Color(0.24, 0.20, 0.22, 0.7), 1, 8, 5, 1))
			btn.add_theme_color_override("font_color", TacticalTheme.TEXT_MUTED)


func _build_ui() -> void:
	var root: Control = Control.new()
	root.name = "BuildMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = TacticalTheme.build_theme(14)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "BuildMenuPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -520.0
	_panel.offset_top = -234.0
	_panel.offset_right = 520.0
	_panel.offset_bottom = -114.0
	_panel.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL_DEEP, TacticalTheme.ACCENT_AMBER, 3, 14, 10))
	root.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_materials_label = Label.new()
	_materials_label.add_theme_font_size_override("font_size", 13)
	_materials_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	vbox.add_child(_materials_label)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	for kind: String in BuildDefenseManager.STRUCTURE_ORDER:
		var spec: Dictionary = BuildDefenseManager.STRUCTURE_CATALOG[kind] as Dictionary
		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 58.0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.text = "[%s] %s" % [str(KIND_CODES.get(kind, "DF")), str(spec.get("name", kind))]
		var cap_k: String = kind
		btn.pressed.connect(func(): structure_selected.emit(cap_k))
		row.add_child(btn)
		_buttons[kind] = btn

	var close_btn: Button = Button.new()
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(96.0, 58.0)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.text = "EXIT\n[ESC]"
	close_btn.pressed.connect(func(): set_open(false))
	row.add_child(close_btn)
