class_name TacticalTheme
extends RefCounted

# Cold Tactical Sci-Fi Anime Palette (Girls' Frontline 2: Exilium inspired)
const BG_BACKDROP: Color = Color(0.03, 0.04, 0.058, 0.88)
const BG_PANEL: Color = Color(0.055, 0.075, 0.102, 0.92)
const BG_PANEL_DEEP: Color = Color(0.038, 0.052, 0.074, 0.96)
const BG_CARD: Color = Color(0.082, 0.106, 0.142, 0.94)
const BG_CARD_HOVER: Color = Color(0.115, 0.155, 0.205, 0.98)
const BG_CARD_ACTIVE: Color = Color(0.135, 0.185, 0.235, 0.98)
const BG_TRACK: Color = Color(0.035, 0.045, 0.065, 0.96)

const BORDER_STEEL: Color = Color(0.22, 0.29, 0.38, 0.84)
const BORDER_TECH: Color = Color(0.32, 0.48, 0.62, 0.90)

const ACCENT_AMBER: Color = Color(0.95, 0.63, 0.14, 1.0)
const ACCENT_CYAN: Color = Color(0.28, 0.84, 0.96, 1.0)
const ACCENT_EMERALD: Color = Color(0.24, 0.86, 0.58, 1.0)
const ACCENT_CRIMSON: Color = Color(0.92, 0.26, 0.28, 1.0)
const ACCENT_VIOLET: Color = Color(0.68, 0.52, 0.96, 1.0)

const TEXT_PRIMARY: Color = Color(0.92, 0.95, 0.98, 1.0)
const TEXT_SECONDARY: Color = Color(0.62, 0.70, 0.78, 1.0)
const TEXT_MUTED: Color = Color(0.42, 0.48, 0.56, 1.0)


static func make_panel_style(
	bg: Color = BG_PANEL,
	border: Color = BORDER_STEEL,
	border_w: int = 1,
	margin_h: int = 12,
	margin_v: int = 8,
	radius: int = 1
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = float(margin_h)
	sb.content_margin_right = float(margin_h)
	sb.content_margin_top = float(margin_v)
	sb.content_margin_bottom = float(margin_v)
	return sb


static func make_accent_card_style(
	bg: Color = BG_CARD,
	accent: Color = ACCENT_CYAN,
	left_stripe_w: int = 3,
	margin_h: int = 12,
	margin_v: int = 8
) -> StyleBoxFlat:
	var sb := make_panel_style(bg, accent, 1, margin_h, margin_v, 1)
	sb.border_width_left = left_stripe_w
	return sb


static func make_bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_TRACK
	sb.border_color = BORDER_STEEL
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	return sb


static func make_bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(0)
	return sb


static func build_theme(default_font_size: int = 15) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = default_font_size

	var btn_normal := make_panel_style(BG_CARD, BORDER_STEEL, 1, 10, 6, 1)
	var btn_hover := make_panel_style(BG_CARD_HOVER, ACCENT_CYAN, 1, 10, 6, 1)
	var btn_pressed := make_panel_style(Color(0.18, 0.24, 0.30, 1.0), ACCENT_AMBER, 1, 10, 6, 1)
	var btn_disabled := make_panel_style(Color(0.05, 0.06, 0.08, 0.72), Color(0.16, 0.20, 0.26, 0.55), 1, 10, 6, 1)

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", btn_hover)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	theme.set_color("font_pressed_color", "Button", ACCENT_AMBER)
	theme.set_color("font_disabled_color", "Button", TEXT_MUTED)

	# OptionButton shares crisp dark tech look
	theme.set_stylebox("normal", "OptionButton", btn_normal)
	theme.set_stylebox("hover", "OptionButton", btn_hover)
	theme.set_stylebox("pressed", "OptionButton", btn_pressed)
	theme.set_color("font_color", "OptionButton", TEXT_PRIMARY)

	# PopupMenu (for OptionButton dropdowns)
	theme.set_stylebox("panel", "PopupMenu", make_panel_style(BG_PANEL_DEEP, BORDER_TECH, 1, 6, 6, 1))
	theme.set_stylebox("hover", "PopupMenu", make_panel_style(BG_CARD_ACTIVE, ACCENT_CYAN, 1, 8, 4, 0))
	theme.set_color("font_color", "PopupMenu", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT_CYAN)

	# Hairline HSeparator
	var sep := StyleBoxLine.new()
	sep.color = Color(0.20, 0.27, 0.36, 0.85)
	sep.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep)

	# Sharp HSlider
	var slider_bg := make_panel_style(BG_TRACK, BORDER_STEEL, 1, 0, 3, 0)
	var slider_fill := make_panel_style(Color(0.20, 0.62, 0.78, 0.90), ACCENT_CYAN, 0, 0, 3, 0)
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", make_panel_style(ACCENT_CYAN, ACCENT_CYAN, 0, 0, 3, 0))

	return theme


static func style_cta_button(btn: Button, accent: Color = ACCENT_AMBER) -> void:
	var n := make_accent_card_style(Color(0.24, 0.16, 0.06, 0.96), accent, 4, 14, 8)
	var h := make_accent_card_style(Color(0.34, 0.22, 0.08, 1.0), Color(1.0, 0.78, 0.32, 1.0), 4, 14, 8)
	var p := make_accent_card_style(Color(0.18, 0.12, 0.04, 1.0), accent, 4, 14, 8)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))


static func style_state_button(btn: Button, active: bool, accent: Color = ACCENT_CYAN) -> void:
	if active:
		var s := make_accent_card_style(BG_CARD_ACTIVE, accent, 3, 8, 5)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", s)
		btn.add_theme_color_override("font_color", accent)
	else:
		btn.add_theme_stylebox_override("normal", make_panel_style(BG_CARD, BORDER_STEEL, 1, 8, 5, 1))
		btn.add_theme_stylebox_override("hover", make_panel_style(BG_CARD_HOVER, BORDER_TECH, 1, 8, 5, 1))
		btn.add_theme_color_override("font_color", TEXT_SECONDARY)


static func make_section_header(tag_code: String, title_text: String, accent: Color = ACCENT_CYAN, font_size: int = 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(3.0, float(font_size + 4))
	chip.color = accent
	row.add_child(chip)

	var tag := Label.new()
	tag.text = "[%s]" % tag_code
	tag.add_theme_font_size_override("font_size", maxi(11, font_size - 3))
	tag.add_theme_color_override("font_color", accent)
	row.add_child(tag)

	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	row.add_child(title)

	return row


static func draw_corner_brackets(canvas: CanvasItem, rect: Rect2, color: Color, len_px: float = 8.0, width: float = 1.5) -> void:
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var x1: float = rect.end.x
	var y1: float = rect.end.y
	# Top-left
	canvas.draw_line(Vector2(x0, y0), Vector2(x0 + len_px, y0), color, width)
	canvas.draw_line(Vector2(x0, y0), Vector2(x0, y0 + len_px), color, width)
	# Top-right
	canvas.draw_line(Vector2(x1, y0), Vector2(x1 - len_px, y0), color, width)
	canvas.draw_line(Vector2(x1, y0), Vector2(x1, y0 + len_px), color, width)
	# Bottom-left
	canvas.draw_line(Vector2(x0, y1), Vector2(x0 + len_px, y1), color, width)
	canvas.draw_line(Vector2(x0, y1), Vector2(x0, y1 - len_px), color, width)
	# Bottom-right
	canvas.draw_line(Vector2(x1, y1), Vector2(x1 - len_px, y1), color, width)
	canvas.draw_line(Vector2(x1, y1), Vector2(x1, y1 - len_px), color, width)
