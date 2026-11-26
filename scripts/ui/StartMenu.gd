class_name StartMenu
extends Control

const DEMO_SCENE_PATH: String = "res://scenes/Main.tscn"
const SANDBOX_SCENE_PATH: String = "res://scenes/AnimSandbox.tscn"

var demo_button: Button = null
var sandbox_button: Button = null
var quit_button: Button = null


class TacticalBackdropCanvas:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.045, 0.062, 1.0), true)
		var step: float = 48.0
		var grid_col := Color(0.18, 0.26, 0.34, 0.18)
		var cross_col := Color(0.28, 0.84, 0.96, 0.24)
		for gx in range(0, int(size.x) + 1, int(step)):
			draw_line(Vector2(float(gx), 0.0), Vector2(float(gx), size.y), grid_col, 1.0)
		for gy in range(0, int(size.y) + 1, int(step)):
			draw_line(Vector2(0.0, float(gy)), Vector2(size.x, float(gy)), grid_col, 1.0)
		for gx in range(int(step) * 2, int(size.x), int(step) * 4):
			for gy in range(int(step) * 2, int(size.y), int(step) * 4):
				draw_line(Vector2(float(gx) - 4.0, float(gy)), Vector2(float(gx) + 4.0, float(gy)), cross_col, 1.0)
				draw_line(Vector2(float(gx), float(gy) - 4.0), Vector2(float(gx), float(gy) + 4.0), cross_col, 1.0)
		# Top & bottom telemetry hairlines
		draw_line(Vector2(24.0, 42.0), Vector2(size.x - 24.0, 42.0), Color(0.28, 0.84, 0.96, 0.32), 1.0)
		draw_line(Vector2(24.0, size.y - 42.0), Vector2(size.x - 24.0, size.y - 42.0), Color(0.95, 0.63, 0.14, 0.26), 1.0)


func _ready() -> void:
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = TacticalTheme.build_theme(15)
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_1 or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
			launch_demo_mode()
		elif ke.keycode == KEY_2:
			launch_anim_sandbox()
		elif ke.keycode == KEY_ESCAPE:
			get_tree().quit()


func launch_demo_mode() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(DEMO_SCENE_PATH)


func launch_anim_sandbox() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(SANDBOX_SCENE_PATH)


func _build_ui() -> void:
	var bg := TacticalBackdropCanvas.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Top status telemetry strip
	var top_strip := HBoxContainer.new()
	top_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_strip.offset_left = 28.0
	top_strip.offset_top = 12.0
	top_strip.offset_right = -28.0
	add_child(top_strip)

	var sys_lbl := Label.new()
	sys_lbl.text = "RAIL-CMD // TACTICAL DEPLOYMENT TERMINAL v2.0"
	sys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_lbl.add_theme_font_size_override("font_size", 12)
	sys_lbl.add_theme_color_override("font_color", TacticalTheme.ACCENT_CYAN)
	top_strip.add_child(sys_lbl)

	var ver_lbl := Label.new()
	ver_lbl.text = "STATUS: STANDBY  |  SYS_OK"
	ver_lbl.add_theme_font_size_override("font_size", 12)
	ver_lbl.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	top_strip.add_child(ver_lbl)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680.0, 440.0)
	card.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL_DEEP, TacticalTheme.ACCENT_AMBER, 4, 32, 28))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	var tag_lbl := Label.new()
	tag_lbl.text = "// OPERATION: IRON RAIL EXTRACTION"
	tag_lbl.add_theme_font_size_override("font_size", 12)
	tag_lbl.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	vbox.add_child(tag_lbl)

	var title := Label.new()
	title.text = "甲鐵廢墟戰線"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ARMORED TRAIN DEFENSE & EXTRACTION PROTOCOL  //  選擇部署模式"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	demo_button = _make_mode_button(
		"[01] 實戰部署 // DEPLOY DEMO SECTOR",
		"隨機都市廢墟戰場・裝甲列車移動基地・三武器戰術切換（M4A1-S / AK-47 / DE）",
		TacticalTheme.ACCENT_AMBER
	)
	demo_button.pressed.connect(launch_demo_mode)
	vbox.add_child(demo_button)

	sandbox_button = _make_mode_button(
		"[02] 動作調校沙盒 // ANIMATION SANDBOX",
		"時間軸倍速精調・動作斷點截斷・走→滾→走連貫融合測試・模型即時切換",
		TacticalTheme.ACCENT_CYAN
	)
	sandbox_button.pressed.connect(launch_anim_sandbox)
	vbox.add_child(sandbox_button)

	vbox.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	vbox.add_child(footer)

	var hint := Label.new()
	hint.text = "KEYBIND: [1 / ENTER] DEPLOY   [2] SANDBOX   [ESC] EXIT"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", TacticalTheme.TEXT_MUTED)
	footer.add_child(hint)

	quit_button = Button.new()
	quit_button.text = "[ESC] 退出系統"
	quit_button.custom_minimum_size = Vector2(128.0, 34.0)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	footer.add_child(quit_button)


func _make_mode_button(headline: String, desc: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(616.0, 86.0)
	btn.text = "%s\n%s" % [headline, desc]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)

	var normal := TacticalTheme.make_accent_card_style(TacticalTheme.BG_CARD, accent, 3, 16, 14)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	var hover := TacticalTheme.make_accent_card_style(TacticalTheme.BG_CARD_HOVER, accent, 4, 16, 14)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn
