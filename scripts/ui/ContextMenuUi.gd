class_name ContextMenuUi
extends CanvasLayer

signal action_selected(action_id: String, payload: Dictionary)

var _backdrop: Control = null
var _panel: PanelContainer = null
var _title_label: Label = null
var _items_vbox: VBoxContainer = null
var _is_open: bool = false


func setup() -> void:
	layer = 19
	_build_ui()
	close()


func is_open() -> bool:
	return _is_open


func close() -> void:
	_is_open = false
	if _backdrop != null:
		_backdrop.visible = false


func show_menu(screen_pos: Vector2, title: String, options: Array[Dictionary]) -> void:
	if _items_vbox == null or _panel == null:
		return
	for c in _items_vbox.get_children():
		_items_vbox.remove_child(c)
		c.queue_free()

	_title_label.text = "// %s" % title
	for opt: Dictionary in options:
		var btn: Button = Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(268.0, 38.0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.text = "▸ " + str(opt.get("label", ""))
		btn.disabled = bool(opt.get("disabled", false))
		var aid: String = str(opt.get("id", ""))
		var pay: Dictionary = (opt.get("payload", {}) as Dictionary).duplicate(true)
		btn.pressed.connect(func():
			close()
			action_selected.emit(aid, pay)
		)
		_items_vbox.add_child(btn)

	_is_open = true
	_backdrop.visible = true

	var vp_size: Vector2 = Vector2(1440.0, 900.0)
	var vp: Viewport = get_viewport()
	if vp != null:
		vp_size = vp.get_visible_rect().size
	var est_w: float = 308.0
	var est_h: float = 52.0 + float(options.size()) * 44.0
	_panel.position = Vector2(
		clampf(screen_pos.x + 8.0, 14.0, maxf(14.0, vp_size.x - est_w - 14.0)),
		clampf(screen_pos.y + 8.0, 14.0, maxf(14.0, vp_size.y - est_h - 14.0))
	)


func _build_ui() -> void:
	_backdrop = Control.new()
	_backdrop.name = "ContextMenuBackdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.theme = TacticalTheme.build_theme(14)
	_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close()
	)
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "ContextMenuPanel"
	_panel.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL_DEEP, TacticalTheme.ACCENT_CYAN, 3, 10, 8))
	_backdrop.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	vbox.add_child(_title_label)

	vbox.add_child(HSeparator.new())

	_items_vbox = VBoxContainer.new()
	_items_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_items_vbox)
