class_name StartMenu
extends Control

const DEMO_SCENE_PATH: String = "res://scenes/Main.tscn"
const SANDBOX_SCENE_PATH: String = "res://scenes/AnimSandbox.tscn"

var demo_button: Button = null
var sandbox_button: Button = null
var quit_button: Button = null


func _ready() -> void:
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.11, 1.0)
	add_child(bg)

	# Subtle top accent bar
	var top_bar := ColorRect.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0.0, 5.0)
	top_bar.color = Color(0.28, 0.84, 0.98, 0.95)
	add_child(top_bar)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640.0, 440.0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.13, 0.18, 0.96)
	card_style.border_color = Color(0.28, 0.82, 0.98, 0.55)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card_style.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "甲鐵廢墟戰線"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ARMORED TRAIN EXTRACTION  •  請選擇啟動模式"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.54, 0.76, 0.88))
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	demo_button = _make_mode_button(
		"▶  [1] 進入 DEMO 模式",
		"完整廢墟撤離戰場、裝甲列車基地、三武器實戰（M4A1-S / AK-47 / DE）",
		Color(0.16, 0.42, 0.56),
		Color(0.22, 0.56, 0.74)
	)
	demo_button.pressed.connect(launch_demo_mode)
	vbox.add_child(demo_button)

	sandbox_button = _make_mode_button(
		"🎬  [2] 進入動作調教沙盒",
		"Debug Panel + 時間軸倍速播放 + 動作斷點截斷 + 走→滾→走連貫測試",
		Color(0.24, 0.30, 0.46),
		Color(0.34, 0.44, 0.68)
	)
	sandbox_button.pressed.connect(launch_anim_sandbox)
	vbox.add_child(sandbox_button)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	vbox.add_child(footer)

	var hint := Label.new()
	hint.text = "快捷鍵：[1 / Enter] DEMO 模式   [2] 動作調教沙盒   [Esc] 離開"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
	footer.add_child(hint)

	quit_button = Button.new()
	quit_button.text = "離開"
	quit_button.custom_minimum_size = Vector2(88.0, 34.0)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	footer.add_child(quit_button)


func _make_mode_button(headline: String, desc: String, base_col: Color, hover_col: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(560.0, 86.0)
	btn.text = "%s\n%s" % [headline, desc]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))

	var normal := StyleBoxFlat.new()
	normal.bg_color = base_col
	normal.border_color = Color(0.45, 0.85, 1.0, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(14)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_col
	hover.border_color = Color(0.55, 0.92, 1.0, 0.95)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn
