class_name TrainCutawayDiagram
extends Control

signal slot_selected(selection: Dictionary)

const LOCO_WIDTH: float = 368.0
const CAR_WIDTH: float = 282.0
const CAR_GAP: float = 18.0
const EXPAND_WIDTH: float = 182.0
const DIAGRAM_HEIGHT: float = 336.0

const ROOF_Y: float = 34.0
const ROOF_H: float = 72.0
const CABIN_Y: float = 128.0
const CABIN_H: float = 126.0
const RAIL_Y: float = 294.0

var _consist: TrainConsistManager = null
var _selection: Dictionary = {"kind": "car_cell", "car_idx": 0, "cell_idx": 0}
var _hit_rects: Array[Dictionary] = []
var _hover_key: String = ""
var _anim_time: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(1240.0, DIAGRAM_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_anim_time += delta
	queue_redraw()


func set_data(consist: TrainConsistManager, selection: Dictionary) -> void:
	_consist = consist
	_selection = selection.duplicate()
	var car_cnt: int = _consist.carriages.size() if _consist != null else 3
	var total_w: float = 34.0 + LOCO_WIDTH + CAR_GAP + float(car_cnt) * (CAR_WIDTH + CAR_GAP) + EXPAND_WIDTH + 34.0
	custom_minimum_size = Vector2(maxf(1240.0, total_w), DIAGRAM_HEIGHT)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mpos: Vector2 = (event as InputEventMouseMotion).position
		var found: String = ""
		for entry: Dictionary in _hit_rects:
			var r: Rect2 = entry["rect"] as Rect2
			if r.has_point(mpos):
				found = str(entry["key"])
				break
		if found != _hover_key:
			_hover_key = found
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			for entry: Dictionary in _hit_rects:
				var r: Rect2 = entry["rect"] as Rect2
				if r.has_point(mb.position):
					var sel: Dictionary = entry["sel"] as Dictionary
					slot_selected.emit(sel.duplicate())
					accept_event()
					return


func _draw() -> void:
	_hit_rects.clear()
	var w: float = maxf(size.x, custom_minimum_size.x)
	var h: float = maxf(size.y, DIAGRAM_HEIGHT)

	# 1. Cold CAD Blueprint Background & Precision Coordinate Grid
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.032, 0.048, 0.072, 1.0), true)
	for gx in range(0, int(w), 32):
		var col := Color(0.16, 0.34, 0.48, 0.22) if (gx % 128 == 0) else Color(0.14, 0.24, 0.34, 0.12)
		draw_line(Vector2(float(gx), 0.0), Vector2(float(gx), RAIL_Y), col, 1.0)
	for gy in range(0, int(RAIL_Y), 32):
		var col := Color(0.16, 0.34, 0.48, 0.22) if (gy % 128 == 0) else Color(0.14, 0.24, 0.34, 0.12)
		draw_line(Vector2(0.0, float(gy)), Vector2(w, float(gy)), col, 1.0)

	# Telemetry elevation axis lines
	draw_line(Vector2(0.0, ROOF_Y + ROOF_H + 8.0), Vector2(w, ROOF_Y + ROOF_H + 8.0), Color(0.28, 0.84, 0.96, 0.16), 1.0)

	# 2. Steel Railbed & Ballast
	draw_rect(Rect2(0.0, RAIL_Y + 6.0, w, h - RAIL_Y), Color(0.025, 0.035, 0.052, 1.0), true)
	for tx in range(10, int(w), 24):
		draw_rect(Rect2(float(tx), RAIL_Y + 5.0, 12.0, 12.0), Color(0.12, 0.17, 0.23, 1.0), true)
	draw_rect(Rect2(0.0, RAIL_Y, w, 5.0), Color(0.26, 0.34, 0.44, 1.0), true)
	draw_line(Vector2(0.0, RAIL_Y), Vector2(w, RAIL_Y), Color(0.32, 0.82, 0.96, 0.65), 1.5)

	if _consist == null:
		return

	var font: Font = ThemeDB.fallback_font
	var cursor_x: float = 38.0

	# 3. Animated Reactor Exhaust Plume
	_draw_steam_plume(cursor_x + 76.0, ROOF_Y + 14.0)

	# 4. Armored Locomotive Schematic
	_draw_locomotive(cursor_x, font)
	cursor_x += LOCO_WIDTH + CAR_GAP

	# 5. Coupled Armored Carriages
	var car_count: int = _consist.carriages.size()
	for idx in range(car_count):
		draw_rect(Rect2(cursor_x - CAR_GAP - 3.0, CABIN_Y + CABIN_H - 12.0, CAR_GAP + 6.0, 10.0), Color(0.14, 0.20, 0.28, 1.0), true)
		draw_line(Vector2(cursor_x - CAR_GAP - 2.0, CABIN_Y + CABIN_H - 7.0), Vector2(cursor_x + 2.0, CABIN_Y + CABIN_H - 7.0), TacticalTheme.ACCENT_AMBER, 2.0)
		_draw_carriage(idx, cursor_x, _consist.carriages[idx], idx == car_count - 1, font)
		cursor_x += CAR_WIDTH + CAR_GAP

	# 6. Expand Carriage Ghost CAD Slot
	_draw_expand_carriage_slot(cursor_x, font)


func _draw_steam_plume(origin_x: float, origin_y: float) -> void:
	for i in range(8):
		var phase: float = fmod(_anim_time * 0.45 + float(i) * 0.125, 1.0)
		var px: float = origin_x + phase * 175.0 + sin(_anim_time * 1.4 + float(i)) * 5.0
		var py: float = origin_y - phase * 36.0 - sin(phase * PI) * 10.0
		var rad: float = 8.0 + phase * 20.0
		var alpha: float = (1.0 - phase) * 0.28
		draw_circle(Vector2(px, py), rad, Color(0.28, 0.84, 0.96, alpha))


func _draw_locomotive(x0: float, font: Font) -> void:
	var stats: Dictionary = _consist.compute_stats()
	var boiler_lv: int = int(stats.get("boiler_level", 1))
	var armor_lv: int = int(stats.get("armor_level", 1))
	var lamp_lv: int = int(stats.get("headlamp_level", 1))

	# Sloped Heavy Armored Ram / Plow
	var plow: PackedVector2Array = PackedVector2Array([
		Vector2(x0 + 44.0, CABIN_Y + 34.0),
		Vector2(x0 + 44.0, RAIL_Y - 12.0),
		Vector2(x0 - 12.0, RAIL_Y - 12.0),
		Vector2(x0 + 10.0, CABIN_Y + 92.0),
	])
	draw_colored_polygon(plow, Color(0.11, 0.15, 0.21, 1.0))
	var plow_outline: PackedVector2Array = PackedVector2Array([plow[0], plow[1], plow[2], plow[3], plow[0]])
	draw_polyline(plow_outline, TacticalTheme.ACCENT_AMBER, 2.0, true)

	# Exhaust Stack
	draw_rect(Rect2(x0 + 62.0, ROOF_Y + 14.0, 28.0, 96.0), Color(0.10, 0.14, 0.19, 1.0), true)
	draw_rect(Rect2(x0 + 52.0, ROOF_Y + 8.0, 48.0, 12.0), Color(0.14, 0.19, 0.26, 1.0), true)
	draw_rect(Rect2(x0 + 56.0, ROOF_Y + 20.0, 40.0, 4.0), TacticalTheme.ACCENT_CYAN, true)
	if boiler_lv >= 2:
		draw_circle(Vector2(x0 + 132.0, CABIN_Y - 14.0), 14.0, Color(0.16, 0.24, 0.34, 1.0))
		draw_arc(Vector2(x0 + 132.0, CABIN_Y - 14.0), 14.0, 0.0, TAU, 20, TacticalTheme.ACCENT_CYAN, 1.5)

	# Main Tactical Steel Hull
	var hull_rect: Rect2 = Rect2(x0 + 42.0, CABIN_Y - 14.0, LOCO_WIDTH - 42.0, CABIN_H + 34.0)
	draw_rect(hull_rect, Color(0.075, 0.10, 0.14, 1.0), true)
	draw_rect(Rect2(x0 + 42.0, CABIN_Y - 14.0, LOCO_WIDTH - 42.0, 8.0), Color(0.15, 0.21, 0.28, 1.0), true)
	draw_rect(hull_rect, TacticalTheme.BORDER_TECH, false, 2.0)

	# Structural bulkhead seams
	for bx in [x0 + 48.0, x0 + 142.0, x0 + 250.0]:
		draw_line(Vector2(bx, CABIN_Y - 12.0), Vector2(bx, CABIN_Y + CABIN_H + 16.0), Color(0.24, 0.36, 0.48, 0.6), 2.0)

	# Under-chassis tactical amber stripe
	draw_rect(Rect2(x0 + 40.0, CABIN_Y + CABIN_H + 10.0, LOCO_WIDTH - 38.0, 8.0), Color(0.12, 0.16, 0.22, 1.0), true)
	draw_line(Vector2(x0 + 40.0, CABIN_Y + CABIN_H + 10.0), Vector2(x0 + LOCO_WIDTH, CABIN_Y + CABIN_H + 10.0), TacticalTheme.ACCENT_AMBER, 2.0)

	# Steel Bogie & Drive Wheels
	for wx in [x0 + 68.0, x0 + 108.0]:
		_draw_spoked_wheel(Vector2(wx, RAIL_Y - 14.0), 15.0)
	for wx in [x0 + 184.0, x0 + 244.0, x0 + 304.0]:
		_draw_spoked_wheel(Vector2(wx, RAIL_Y - 21.0), 22.0)
	var rod_y: float = RAIL_Y - 19.0 + sin(_anim_time * 2.2) * 2.5
	draw_line(Vector2(x0 + 178.0, rod_y), Vector2(x0 + 310.0, rod_y), TacticalTheme.ACCENT_CYAN, 3.0)

	# Title Tag
	draw_string(font, Vector2(x0 + 114.0, ROOF_Y - 10.0), "UNIT-00 // 裝甲動力車頭", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TacticalTheme.ACCENT_CYAN)

	# Roof Slot: Headlamp
	_draw_blueprint_slot(
		"loco_headlamp",
		Rect2(x0 + 112.0, ROOF_Y + 8.0, 146.0, ROOF_H - 8.0),
		{"kind": "loco_part", "part": "headlamp"},
		"探照陣列",
		"Lv.%d / %d" % [lamp_lv, TrainConsistManager.MAX_HEADLAMP_LEVEL],
		TacticalTheme.ACCENT_AMBER,
		true,
		"loco_lamp",
		false,
		font
	)

	# Interior Slot 1: Armor & Plow
	_draw_blueprint_slot(
		"loco_armor",
		Rect2(x0 + 50.0, CABIN_Y, 98.0, CABIN_H),
		{"kind": "loco_part", "part": "armor"},
		"複合裝甲",
		"Lv.%d\nHP %d" % [armor_lv, int(round(float(TrainConsistManager.ARMOR_TIERS[armor_lv - 1]["hull_hp"])))],
		TacticalTheme.ACCENT_CYAN,
		false,
		"loco_armor",
		false,
		font
	)

	# Interior Slot 2: Reactor Boiler Core
	_draw_blueprint_slot(
		"loco_boiler",
		Rect2(x0 + 154.0, CABIN_Y, 100.0, CABIN_H),
		{"kind": "loco_part", "part": "boiler"},
		"動力爐心",
		"Lv.%d\n牽引%d節" % [boiler_lv, int(stats.get("max_carriages", 3))],
		TacticalTheme.ACCENT_AMBER,
		false,
		"loco_boiler",
		false,
		font
	)

	# Interior Slot 3: Engineer Cab
	var loco_slots: Array = _consist.locomotive.get("crew_slots", [""]) as Array
	var loco_cid: String = str(loco_slots[0]) if loco_slots.size() > 0 else ""
	var crew_txt: String = "EMPTY\n(輪機位)"
	var crew_col: Color = TacticalTheme.TEXT_SECONDARY
	var has_crew: bool = not loco_cid.is_empty()
	if has_crew:
		var cdata: Dictionary = _consist.get_crew_by_id(loco_cid)
		var aff: float = _consist.get_crew_affinity(loco_cid, "mechanic")
		crew_txt = "%s\n%s%d%%" % [str(cdata.get("short_name", cdata.get("name", ""))), "★" if aff >= 1.25 else "", int(round(aff * 100.0))]
		crew_col = TacticalTheme.ACCENT_EMERALD if aff >= 1.25 else TacticalTheme.ACCENT_AMBER

	_draw_blueprint_slot(
		"loco_cab",
		Rect2(x0 + 260.0, CABIN_Y, 98.0, CABIN_H),
		{"kind": "loco_cab"},
		"輪機駕駛",
		crew_txt,
		crew_col,
		false,
		"loco_cab",
		has_crew,
		font
	)


func _draw_carriage(car_idx: int, x0: float, car: Dictionary, is_last: bool, font: Font) -> void:
	var ctype: String = str(car.get("type", "flatbed"))
	var spec: Dictionary = _consist.get_carriage_spec(ctype)

	# Roof tactical railing
	draw_line(Vector2(x0 + 12.0, CABIN_Y - 22.0), Vector2(x0 + CAR_WIDTH - 12.0, CABIN_Y - 22.0), Color(0.24, 0.36, 0.48, 0.8), 1.5)
	for rx in range(18, int(CAR_WIDTH) - 12, 24):
		draw_line(Vector2(x0 + float(rx), CABIN_Y - 22.0), Vector2(x0 + float(rx), CABIN_Y - 12.0), Color(0.24, 0.36, 0.48, 0.7), 1.5)

	# Tail tactical antenna & beacon
	if is_last:
		var pole_x: float = x0 + CAR_WIDTH - 14.0
		draw_line(Vector2(pole_x, ROOF_Y - 10.0), Vector2(pole_x, CABIN_Y - 10.0), Color(0.32, 0.46, 0.60, 1.0), 2.5)
		var pulse: float = 0.55 + 0.45 * sin(_anim_time * 4.0)
		draw_circle(Vector2(pole_x, ROOF_Y - 12.0), 4.0, Color(0.95, 0.32, 0.24, pulse))

	# Armored Steel Carriage Hull
	var hull_rect: Rect2 = Rect2(x0, CABIN_Y - 14.0, CAR_WIDTH, CABIN_H + 34.0)
	draw_rect(hull_rect, Color(0.07, 0.095, 0.135, 1.0), true)
	draw_rect(Rect2(x0, CABIN_Y - 14.0, CAR_WIDTH, 9.0), Color(0.14, 0.19, 0.26, 1.0), true)
	draw_rect(Rect2(x0, CABIN_Y + CABIN_H + 8.0, CAR_WIDTH, 11.0), Color(0.11, 0.15, 0.21, 1.0), true)
	draw_rect(hull_rect, TacticalTheme.BORDER_TECH, false, 1.8)
	for px in [x0 + 4.0, x0 + CAR_WIDTH * 0.5 - 3.0, x0 + CAR_WIDTH - 9.0]:
		draw_rect(Rect2(px, CABIN_Y - 4.0, 5.0, CABIN_H + 12.0), Color(0.14, 0.20, 0.27, 1.0), true)

	# Bogie Wheels
	draw_rect(Rect2(x0 + 26.0, RAIL_Y - 22.0, 74.0, 8.0), Color(0.12, 0.16, 0.22, 1.0), true)
	draw_rect(Rect2(x0 + CAR_WIDTH - 100.0, RAIL_Y - 22.0, 74.0, 8.0), Color(0.12, 0.16, 0.22, 1.0), true)
	for wx in [x0 + 44.0, x0 + 82.0, x0 + CAR_WIDTH - 82.0, x0 + CAR_WIDTH - 44.0]:
		_draw_spoked_wheel(Vector2(wx, RAIL_Y - 16.0), 16.0)

	# Carriage Label
	draw_string(font, Vector2(x0 + 8.0, ROOF_Y - 10.0), "CAR-%02d // %s" % [car_idx + 1, str(spec.get("short", "車廂"))], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TacticalTheme.TEXT_PRIMARY)

	# 1. Roof Hardpoint Slot
	var roof_mod: String = str(car.get("roof", "none"))
	var rspec: Dictionary = _consist.get_roof_spec(roof_mod)
	var roof_rect: Rect2 = Rect2(x0 + 50.0, ROOF_Y + 8.0, CAR_WIDTH - 100.0, ROOF_H - 8.0)
	var rpwr: int = int(rspec.get("power", 0))
	var rsub: String = "HARDPOINT" if roof_mod == "none" else ("PWR -%d" % rpwr if rpwr > 0 else "PASSIVE")
	_draw_blueprint_slot(
		"car_%d_roof" % car_idx,
		roof_rect,
		{"kind": "car_roof", "car_idx": car_idx},
		str(rspec.get("short", "空車頂")),
		rsub,
		rspec.get("accent", TacticalTheme.ACCENT_CYAN) as Color,
		true,
		"roof_" + roof_mod,
		false,
		font
	)

	# 2. Two Interior Module Bays
	var cells: Array = car.get("cells", []) as Array
	var cell_w: float = (CAR_WIDTH - 30.0) * 0.5
	for ci in range(mini(2, cells.size())):
		var cell: Dictionary = cells[ci] as Dictionary
		var mod: String = str(cell.get("module", "empty"))
		var cspec: Dictionary = _consist.get_cell_spec(mod)
		var cid: String = str(cell.get("crew_id", ""))
		var cx: float = x0 + 11.0 + float(ci) * (cell_w + 8.0)
		var crect: Rect2 = Rect2(cx, CABIN_Y, cell_w, CABIN_H)

		var sub_text: String = ""
		var accent: Color = cspec.get("accent", TacticalTheme.ACCENT_CYAN) as Color
		var has_crew: bool = not cid.is_empty()
		if mod == "empty":
			sub_text = "OPEN BAY\n點擊改裝"
		elif not has_crew:
			sub_text = "UNSTAFFED\n點擊派駐"
		else:
			var cdata: Dictionary = _consist.get_crew_by_id(cid)
			var aff: float = _consist.get_crew_affinity(cid, str(cspec.get("best_role", "any")))
			sub_text = "%s\n%s%d%%" % [
				str(cdata.get("short_name", cdata.get("name", cid))),
				"★" if aff >= 1.25 else "",
				int(round(aff * 100.0)),
			]

		_draw_blueprint_slot(
			"car_%d_cell_%d" % [car_idx, ci],
			crect,
			{"kind": "car_cell", "car_idx": car_idx, "cell_idx": ci},
			str(cspec.get("short", mod)),
			sub_text,
			accent,
			false,
			mod,
			has_crew,
			font
		)


func _draw_expand_carriage_slot(x0: float, font: Font) -> void:
	var can_expand: bool = _consist.carriages.size() < _consist.get_max_carriages()
	var rect: Rect2 = Rect2(x0, CABIN_Y - 10.0, EXPAND_WIDTH, CABIN_H + 26.0)
	var border_col: Color = TacticalTheme.ACCENT_CYAN if can_expand else TacticalTheme.BORDER_STEEL
	var bg_col: Color = Color(0.06, 0.11, 0.16, 0.9) if can_expand else Color(0.04, 0.055, 0.08, 0.6)
	if _hover_key == "expand_car" and can_expand:
		bg_col = Color(0.10, 0.18, 0.25, 0.98)

	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, 1.5)
	_draw_corner_triangles(rect, TacticalTheme.ACCENT_AMBER if can_expand else TacticalTheme.TEXT_MUTED, 9.0)

	var title_txt: String = "+ EXPAND CAR" if can_expand else "MAX TRACTION"
	var sub_txt: String = _consist.format_cost(TrainConsistManager.EXPAND_CARRIAGE_COST) if can_expand else "升級鍋爐\n(%d/%d 節)" % [_consist.carriages.size(), _consist.get_max_carriages()]
	draw_string(font, Vector2(rect.position.x + 10.0, rect.position.y + 52.0), title_txt, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20.0, 15, TacticalTheme.ACCENT_CYAN if can_expand else TacticalTheme.TEXT_MUTED)
	var lines: PackedStringArray = sub_txt.split("\n")
	for li in range(lines.size()):
		draw_string(font, Vector2(rect.position.x + 10.0, rect.position.y + 84.0 + float(li) * 22.0), lines[li], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20.0, 13, TacticalTheme.TEXT_SECONDARY)

	_hit_rects.append({"key": "expand_car", "rect": rect, "sel": {"kind": "expand_car"}})


func _draw_blueprint_slot(
	key: String,
	rect: Rect2,
	sel_dict: Dictionary,
	title_text: String,
	sub_text: String,
	accent: Color,
	is_roof: bool,
	art_kind: String,
	has_crew: bool,
	font: Font
) -> void:
	var is_sel: bool = _matches_selection(sel_dict)
	var is_hov: bool = (_hover_key == key)

	if is_roof:
		var roof_bg: Color = Color(0.11, 0.17, 0.24, 0.94) if is_sel else (Color(0.085, 0.13, 0.18, 0.85) if is_hov else Color(0.055, 0.085, 0.125, 0.72))
		draw_rect(rect, roof_bg, true)
		_draw_roof_mini_art(rect, art_kind)
	else:
		var room_bg: Color = Color(0.055, 0.08, 0.115, 1.0) if not is_sel else Color(0.09, 0.135, 0.19, 1.0)
		if is_hov and not is_sel:
			room_bg = Color(0.075, 0.11, 0.155, 1.0)
		draw_rect(rect, room_bg, true)
		# Subtle technical bulkhead lines
		var grid_col := Color(0.16, 0.26, 0.36, 0.25)
		for px in range(18, int(rect.size.x), 22):
			draw_line(Vector2(rect.position.x + float(px), rect.position.y + 2.0), Vector2(rect.position.x + float(px), rect.end.y - 14.0), grid_col, 1.0)
		draw_rect(Rect2(rect.position.x + 2.0, rect.end.y - 16.0, rect.size.x - 4.0, 14.0), Color(0.08, 0.12, 0.17, 1.0), true)
		_draw_cabin_mini_art(rect, art_kind, has_crew)
		draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0, rect.size.x - 4.0, 24.0), Color(0.03, 0.045, 0.07, 0.88), true)
		draw_rect(Rect2(rect.position.x + 2.0, rect.end.y - 42.0, rect.size.x - 4.0, 40.0), Color(0.03, 0.045, 0.07, 0.86), true)

	var frame_col: Color = TacticalTheme.ACCENT_AMBER if is_sel else (TacticalTheme.ACCENT_CYAN if is_hov else Color(0.24, 0.34, 0.45, 0.9))
	draw_rect(rect, frame_col, false, 2.0 if is_sel else 1.2)

	var corner_col: Color = TacticalTheme.ACCENT_AMBER if is_sel else TacticalTheme.ACCENT_CYAN
	_draw_corner_triangles(rect, corner_col, 10.0 if is_sel else 8.0)

	var title_col: Color = TacticalTheme.ACCENT_AMBER if is_sel else (accent if is_roof else TacticalTheme.TEXT_PRIMARY)
	var title_y: float = rect.position.y + (24.0 if is_roof else 19.0)
	draw_string(font, Vector2(rect.position.x + 6.0, title_y), title_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12.0, 14, title_col)

	var lines: PackedStringArray = sub_text.split("\n")
	var start_y: float = rect.position.y + (45.0 if is_roof else rect.size.y - 24.0)
	for li in range(lines.size()):
		var lcol: Color = TacticalTheme.TEXT_SECONDARY if is_roof else (TacticalTheme.ACCENT_CYAN if li == 0 else TacticalTheme.TEXT_SECONDARY)
		if not is_roof and has_crew and li == 0:
			lcol = TacticalTheme.ACCENT_EMERALD
		elif not is_roof and lines[li].contains("★"):
			lcol = TacticalTheme.ACCENT_AMBER
		draw_string(font, Vector2(rect.position.x + 6.0, start_y + float(li) * 18.0), lines[li], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12.0, 13, lcol)

	_hit_rects.append({"key": key, "rect": rect, "sel": sel_dict})


func _draw_roof_mini_art(rect: Rect2, art_kind: String) -> void:
	var cx: float = rect.position.x + rect.size.x * 0.5
	var by: float = rect.end.y - 6.0
	match art_kind:
		"roof_turret":
			draw_rect(Rect2(cx - 22.0, by - 14.0, 44.0, 12.0), Color(0.22, 0.30, 0.38, 0.8), true)
			draw_line(Vector2(cx + 16.0, by - 10.0), Vector2(cx + 46.0, by - 12.0), TacticalTheme.ACCENT_AMBER, 3.0)
		"roof_radar":
			draw_arc(Vector2(cx, by - 16.0), 16.0, deg_to_rad(200.0), deg_to_rad(340.0), 12, TacticalTheme.ACCENT_CYAN, 2.0)
		"roof_tesla":
			draw_rect(Rect2(cx - 22.0, by - 16.0, 8.0, 14.0), TacticalTheme.ACCENT_CYAN, true)
			draw_rect(Rect2(cx + 14.0, by - 16.0, 8.0, 14.0), TacticalTheme.ACCENT_CYAN, true)
		"roof_shield":
			draw_rect(Rect2(cx - 32.0, by - 10.0, 64.0, 8.0), Color(0.42, 0.52, 0.62, 0.85), true)


func _draw_cabin_mini_art(rect: Rect2, art_kind: String, has_crew: bool) -> void:
	var x: float = rect.position.x
	var y: float = rect.position.y + 30.0
	var w: float = rect.size.x

	match art_kind:
		"loco_boiler":
			var fire_pulse: float = 0.88 + sin(_anim_time * 7.5) * 0.12
			draw_circle(Vector2(x + w * 0.5, y + 32.0), 22.0, Color(0.95, 0.45, 0.12, 0.25 * fire_pulse))
			draw_rect(Rect2(x + 20.0, y + 8.0, w - 40.0, 38.0), Color(0.18, 0.24, 0.32, 0.9), true)
			draw_rect(Rect2(x + 28.0, y + 16.0, w - 56.0, 22.0), Color(0.96, 0.62, 0.16, 0.92 * fire_pulse), true)
			draw_rect(Rect2(x + 20.0, y + 8.0, w - 40.0, 38.0), TacticalTheme.ACCENT_AMBER, false, 1.5)
		"loco_armor":
			draw_circle(Vector2(x + w * 0.5, y + 26.0), 16.0, Color(0.18, 0.28, 0.38, 0.8))
			draw_arc(Vector2(x + w * 0.5, y + 26.0), 16.0, 0.0, TAU, 20, TacticalTheme.ACCENT_CYAN, 1.5)
		"loco_cab":
			draw_rect(Rect2(x + 14.0, y + 16.0, 24.0, 28.0), Color(0.14, 0.22, 0.30, 0.9), true)
			draw_circle(Vector2(x + 26.0, y + 24.0), 5.0, TacticalTheme.ACCENT_CYAN)
		"cargo":
			draw_rect(Rect2(x + 14.0, y + 22.0, 28.0, 24.0), Color(0.16, 0.24, 0.32, 0.92), true)
			draw_rect(Rect2(x + 14.0, y + 22.0, 28.0, 24.0), TacticalTheme.ACCENT_AMBER, false, 1.2)
			draw_rect(Rect2(x + 48.0, y + 18.0, 22.0, 28.0), Color(0.14, 0.20, 0.28, 0.92), true)
		"quarters":
			draw_rect(Rect2(x + 14.0, y + 12.0, 54.0, 6.0), Color(0.24, 0.34, 0.44, 0.95), true)
			draw_rect(Rect2(x + 14.0, y + 32.0, 54.0, 6.0), Color(0.24, 0.34, 0.44, 0.95), true)
		"gunnery":
			draw_rect(Rect2(x + 18.0, y + 24.0, 36.0, 12.0), Color(0.24, 0.32, 0.40, 0.95), true)
			draw_rect(Rect2(x + 48.0, y + 26.0, 24.0, 6.0), TacticalTheme.ACCENT_AMBER, true)
		"medbay":
			draw_rect(Rect2(x + 46.0, y + 8.0, 6.0, 18.0), TacticalTheme.ACCENT_EMERALD, true)
			draw_rect(Rect2(x + 40.0, y + 14.0, 18.0, 6.0), TacticalTheme.ACCENT_EMERALD, true)
		"armory":
			draw_circle(Vector2(x + 30.0, y + 22.0), 13.0, Color(0.22, 0.32, 0.42, 0.85))
			draw_arc(Vector2(x + 30.0, y + 22.0), 13.0, 0.0, TAU, 16, TacticalTheme.ACCENT_AMBER, 1.5)
		"recon":
			draw_rect(Rect2(x + 16.0, y + 26.0, 48.0, 16.0), Color(0.16, 0.24, 0.32, 0.92), true)
			draw_circle(Vector2(x + 32.0, y + 18.0), 8.0, TacticalTheme.ACCENT_CYAN)
		"generator":
			draw_rect(Rect2(x + 20.0, y + 10.0, 16.0, 34.0), Color(0.18, 0.34, 0.44, 0.92), true)
			draw_rect(Rect2(x + 48.0, y + 10.0, 16.0, 34.0), Color(0.18, 0.34, 0.44, 0.92), true)
			draw_line(Vector2(x + 28.0, y + 18.0), Vector2(x + 56.0, y + 22.0), TacticalTheme.ACCENT_CYAN, 2.0)
		"boarding":
			draw_rect(Rect2(x + 16.0, y + 10.0, 34.0, 36.0), Color(0.14, 0.24, 0.28, 0.88), true)
			draw_rect(Rect2(x + 16.0, y + 10.0, 34.0, 36.0), TacticalTheme.ACCENT_EMERALD, false, 1.5)

	if has_crew:
		var px: float = x + w - 22.0
		var py: float = y + 32.0
		draw_circle(Vector2(px, py - 12.0), 6.0, TacticalTheme.ACCENT_CYAN)
		draw_rect(Rect2(px - 7.0, py - 5.0, 14.0, 18.0), Color(0.16, 0.42, 0.48, 0.96), true)
		draw_rect(Rect2(px - 7.0, py - 5.0, 14.0, 18.0), TacticalTheme.ACCENT_CYAN, false, 1.0)


func _draw_corner_triangles(rect: Rect2, color: Color, sz: float) -> void:
	var x0: float = rect.position.x + 1.0
	var y0: float = rect.position.y + 1.0
	var x1: float = rect.end.x - 1.0
	var y1: float = rect.end.y - 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + sz, y0), Vector2(x0, y0 + sz)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(x1, y0), Vector2(x1 - sz, y0), Vector2(x1, y0 + sz)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(x0, y1), Vector2(x0 + sz, y1), Vector2(x0, y1 - sz)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(x1, y1), Vector2(x1 - sz, y1), Vector2(x1, y1 - sz)]), color)


func _draw_spoked_wheel(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color(0.08, 0.11, 0.15, 1.0))
	draw_arc(center, radius, 0.0, TAU, 24, Color(0.32, 0.44, 0.56, 1.0), 2.5)
	draw_arc(center, radius * 0.72, 0.0, TAU, 20, Color(0.20, 0.28, 0.38, 0.9), 1.2)
	for si in range(6):
		var ang: float = float(si) * (PI / 3.0)
		var dv: Vector2 = Vector2(cos(ang), sin(ang)) * (radius - 2.0)
		draw_line(center - dv, center + dv, Color(0.26, 0.36, 0.46, 0.85), 1.5)
	draw_circle(center, radius * 0.26, TacticalTheme.ACCENT_CYAN)


func _matches_selection(candidate: Dictionary) -> bool:
	if str(candidate.get("kind", "")) != str(_selection.get("kind", "")):
		return false
	var kind: String = str(candidate.get("kind", ""))
	match kind:
		"loco_part":
			return str(candidate.get("part", "")) == str(_selection.get("part", ""))
		"loco_cab":
			return true
		"car_roof":
			return int(candidate.get("car_idx", -1)) == int(_selection.get("car_idx", -2))
		"car_cell":
			return int(candidate.get("car_idx", -1)) == int(_selection.get("car_idx", -2)) and int(candidate.get("cell_idx", -1)) == int(_selection.get("cell_idx", -2))
		_:
			return false
