class_name BuildMenuUi
extends CanvasLayer

signal structure_selected(kind: String)
signal closed()

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
			_materials_label.text = "🏗 野外建造模式 [B] — ♾️ 無限資源已啟用（全工事免費建造）｜ 左鍵放置 ｜ Q 旋轉 ｜ 右鍵/Esc 結束"
		else:
			_materials_label.text = "🏗 野外建造模式 [B] — 可用材料（背包＋暫存倉）：金屬 %d ｜ 零件 %d ｜ 燃料 %d ｜ 左鍵放置 ｜ Q 旋轉 ｜ 右鍵/Esc 結束" % [
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
		var sel_tag: String = "▶ " if kind == _selected_kind else ""
		btn.text = "%s%s %s\n%s" % [sel_tag, str(spec.get("icon", "")), str(spec.get("name", kind)), manager.format_cost(kind)]
		btn.modulate = Color(1.0, 0.96, 0.80) if afford else Color(0.65, 0.56, 0.52)


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
	root.name = "BuildMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "BuildMenuPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -450.0
	_panel.offset_top = -238.0
	_panel.offset_right = 450.0
	_panel.offset_bottom = -114.0
	_panel.add_theme_stylebox_override("panel", _make_style(Color(0.16, 0.13, 0.10, 0.95), Color(0.92, 0.70, 0.30, 0.94)))
	root.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_materials_label = Label.new()
	_materials_label.add_theme_font_size_override("font_size", 15)
	_materials_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	vbox.add_child(_materials_label)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	for kind: String in BuildDefenseManager.STRUCTURE_ORDER:
		var spec: Dictionary = BuildDefenseManager.STRUCTURE_CATALOG[kind] as Dictionary
		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 62.0)
		btn.add_theme_font_size_override("font_size", 16)
		btn.text = "%s %s" % [str(spec.get("icon", "")), str(spec.get("name", kind))]
		var cap_k: String = kind
		btn.pressed.connect(func(): structure_selected.emit(cap_k))
		row.add_child(btn)
		_buttons[kind] = btn

	var close_btn: Button = Button.new()
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(96.0, 62.0)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.text = "✕ 取消\n[Esc]"
	close_btn.pressed.connect(func(): set_open(false))
	row.add_child(close_btn)
