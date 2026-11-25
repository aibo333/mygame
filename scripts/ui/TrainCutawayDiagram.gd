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

	# 1. Warm Vintage Parchment Sky & Aged Paper Bands (matching reference illustration!)
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.89, 0.82, 0.66, 1.0), true)
	draw_rect(Rect2(0.0, 0.0, w, 92.0), Color(0.83, 0.74, 0.56, 0.65), true)
	draw_rect(Rect2(0.0, 92.0, w, 128.0), Color(0.93, 0.87, 0.72, 0.55), true)
	draw_rect(Rect2(0.0, 220.0, w, RAIL_Y - 220.0), Color(0.80, 0.71, 0.54, 0.60), true)

	# Soft aged-paper vignette bars & faint sepia drafting rules
	draw_rect(Rect2(0.0, 0.0, w, 18.0), Color(0.42, 0.31, 0.19, 0.22), true)
	draw_rect(Rect2(0.0, 0.0, 18.0, h), Color(0.42, 0.31, 0.19, 0.18), true)
	draw_rect(Rect2(w - 18.0, 0.0, 18.0, h), Color(0.42, 0.31, 0.19, 0.18), true)
	for gy in [70.0, 145.0, 220.0]:
		draw_line(Vector2(0.0, gy), Vector2(w, gy), Color(0.54, 0.42, 0.26, 0.16), 1.0)

	# 2. Warm Earth Embankment, Timber Sleepers & Cast-Iron Rail
	draw_rect(Rect2(0.0, RAIL_Y + 6.0, w, h - RAIL_Y), Color(0.28, 0.21, 0.16, 1.0), true)
	draw_rect(Rect2(0.0, RAIL_Y + 22.0, w, h - RAIL_Y), Color(0.20, 0.15, 0.11, 1.0), true)
	for tx in range(10, int(w), 24):
		draw_rect(Rect2(float(tx), RAIL_Y + 5.0, 12.0, 13.0), Color(0.42, 0.30, 0.20, 1.0), true)
		draw_rect(Rect2(float(tx), RAIL_Y + 5.0, 12.0, 3.0), Color(0.56, 0.42, 0.28, 0.7), true)
	draw_rect(Rect2(0.0, RAIL_Y, w, 7.0), Color(0.42, 0.38, 0.34, 1.0), true)
	draw_line(Vector2(0.0, RAIL_Y + 1.0), Vector2(w, RAIL_Y + 1.0), Color(0.76, 0.70, 0.58, 0.85), 2.0)

	if _consist == null:
		return

	var font: Font = ThemeDB.fallback_font
	var cursor_x: float = 38.0

	# 3. Animated Warm Steam Plume rising from Locomotive Smokestack
	_draw_steam_plume(cursor_x + 76.0, ROOF_Y + 14.0)

	# 4. Armored Steam Locomotive
	_draw_locomotive(cursor_x, font)
	cursor_x += LOCO_WIDTH + CAR_GAP

	# 5. Coupled Armored Carriages with Miniature Wood-Paneled Cabin Art
	var car_count: int = _consist.carriages.size()
	for idx in range(car_count):
		# Heavy iron coupler + brass buffers
		draw_rect(Rect2(cursor_x - CAR_GAP - 3.0, CABIN_Y + CABIN_H - 12.0, CAR_GAP + 6.0, 12.0), Color(0.26, 0.22, 0.19, 1.0), true)
		draw_rect(Rect2(cursor_x - CAR_GAP - 2.0, CABIN_Y + CABIN_H - 10.0, CAR_GAP + 4.0, 4.0), Color(0.72, 0.56, 0.32, 0.85), true)
		_draw_carriage(idx, cursor_x, _consist.carriages[idx], idx == car_count - 1, font)
		cursor_x += CAR_WIDTH + CAR_GAP

	# 6. "+ Expand New Carriage" Warm Vintage Blueprint Ghost Slot
	_draw_expand_carriage_slot(cursor_x, font)


func _draw_steam_plume(origin_x: float, origin_y: float) -> void:
	for i in range(9):
		var phase: float = fmod(_anim_time * 0.42 + float(i) * 0.111, 1.0)
		var px: float = origin_x + phase * 185.0 + sin(_anim_time * 1.4 + float(i)) * 7.0
		var py: float = origin_y - phase * 42.0 - sin(phase * PI) * 14.0
		var rad: float = 11.0 + phase * 26.0
		var alpha: float = (1.0 - phase) * 0.42
		draw_circle(Vector2(px, py), rad, Color(0.95, 0.90, 0.80, alpha))
		draw_circle(Vector2(px + 6.0, py + 4.0), rad * 0.72, Color(0.68, 0.62, 0.54, alpha * 0.55))


func _draw_locomotive(x0: float, font: Font) -> void:
	var stats: Dictionary = _consist.compute_stats()
	var boiler_lv: int = int(stats.get("boiler_level", 1))
	var armor_lv: int = int(stats.get("armor_level", 1))
	var lamp_lv: int = int(stats.get("headlamp_level", 1))

	# Cast-iron angled cowcatcher / crimson snowplow (strictly convex clockwise quad!)
	var plow: PackedVector2Array = PackedVector2Array([
		Vector2(x0 + 44.0, CABIN_Y + 34.0),
		Vector2(x0 + 44.0, RAIL_Y - 12.0),
		Vector2(x0 - 12.0, RAIL_Y - 12.0),
		Vector2(x0 + 10.0, CABIN_Y + 92.0),
	])
	draw_colored_polygon(plow, Color(0.40, 0.18, 0.16, 1.0))
	var plow_outline: PackedVector2Array = PackedVector2Array([plow[0], plow[1], plow[2], plow[3], plow[0]])
	draw_polyline(plow_outline, Color(0.84, 0.66, 0.34, 0.95), 2.5, true)
	for bar_i in range(1, 4):
		var t: float = float(bar_i) / 4.0
		draw_line(
			Vector2(lerpf(x0 + 10.0, x0 + 44.0, t), lerpf(CABIN_Y + 92.0, CABIN_Y + 40.0, t)),
			Vector2(lerpf(x0 - 8.0, x0 + 44.0, t), RAIL_Y - 12.0),
			Color(0.22, 0.18, 0.16, 0.9),
			2.0
		)

	# Classic tall flared cast-iron smokestack with brass band
	draw_rect(Rect2(x0 + 62.0, ROOF_Y + 14.0, 28.0, 96.0), Color(0.20, 0.18, 0.17, 1.0), true)
	draw_rect(Rect2(x0 + 52.0, ROOF_Y + 8.0, 48.0, 14.0), Color(0.27, 0.24, 0.22, 1.0), true)
	draw_rect(Rect2(x0 + 56.0, ROOF_Y + 22.0, 40.0, 6.0), Color(0.76, 0.58, 0.30, 0.95), true)
	if boiler_lv >= 2:
		# Brass steam dome & secondary exhaust pipe
		draw_circle(Vector2(x0 + 132.0, CABIN_Y - 14.0), 16.0, Color(0.68, 0.52, 0.28, 1.0))
		draw_rect(Rect2(x0 + 116.0, CABIN_Y - 14.0, 32.0, 14.0), Color(0.52, 0.39, 0.22, 1.0), true)

	# Main Cast-Iron Locomotive Hull & Brass Trim
	var hull_rect: Rect2 = Rect2(x0 + 42.0, CABIN_Y - 14.0, LOCO_WIDTH - 42.0, CABIN_H + 34.0)
	draw_rect(hull_rect, Color(0.19, 0.17, 0.16, 1.0), true)
	draw_rect(Rect2(x0 + 42.0, CABIN_Y - 14.0, LOCO_WIDTH - 42.0, 10.0), Color(0.32, 0.26, 0.20, 1.0), true)
	draw_rect(hull_rect, Color(0.76, 0.58, 0.32, 0.95), false, 2.5)

	# Warm brass boiler bands & rivets
	for bx in [x0 + 48.0, x0 + 142.0, x0 + 250.0]:
		draw_line(Vector2(bx, CABIN_Y - 12.0), Vector2(bx, CABIN_Y + CABIN_H + 16.0), Color(0.72, 0.56, 0.30, 0.8), 3.0)

	# Running board & crimson trim under locomotive
	draw_rect(Rect2(x0 + 40.0, CABIN_Y + CABIN_H + 10.0, LOCO_WIDTH - 38.0, 10.0), Color(0.46, 0.20, 0.16, 1.0), true)
	draw_line(Vector2(x0 + 40.0, CABIN_Y + CABIN_H + 10.0), Vector2(x0 + LOCO_WIDTH, CABIN_Y + CABIN_H + 10.0), Color(0.84, 0.66, 0.34, 0.95), 2.0)

	# Spoked Locomotive Wheels + Iron Connecting Rod
	var small_wheels: Array[float] = [x0 + 68.0, x0 + 108.0]
	for wx in small_wheels:
		_draw_spoked_wheel(Vector2(wx, RAIL_Y - 14.0), 15.0)
	var drive_wheels: Array[float] = [x0 + 184.0, x0 + 244.0, x0 + 304.0]
	for wx in drive_wheels:
		_draw_spoked_wheel(Vector2(wx, RAIL_Y - 21.0), 22.0)
	# Connecting rod bar across driving wheels
	var rod_y: float = RAIL_Y - 19.0 + sin(_anim_time * 2.2) * 2.5
	draw_line(Vector2(x0 + 178.0, rod_y), Vector2(x0 + 310.0, rod_y), Color(0.78, 0.68, 0.48, 0.95), 4.0)

	# Title Ribbon
	draw_string(font, Vector2(x0 + 114.0, ROOF_Y - 8.0), "🚂 蒸氣武裝火車頭", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.24, 0.16, 0.10))

	# Roof Slot: Brass Headlamp
	var lamp_rect: Rect2 = Rect2(x0 + 112.0, ROOF_Y + 8.0, 146.0, ROOF_H - 8.0)
	_draw_blueprint_slot(
		"loco_headlamp",
		lamp_rect,
		{"kind": "loco_part", "part": "headlamp"},
		"🔦 探照燈",
		"Lv.%d / %d" % [lamp_lv, TrainConsistManager.MAX_HEADLAMP_LEVEL],
		Color(0.95, 0.78, 0.34),
		true,
		"loco_lamp",
		false,
		font
	)

	# Interior Slot 1: Armor & Plow
	var armor_rect: Rect2 = Rect2(x0 + 50.0, CABIN_Y, 98.0, CABIN_H)
	_draw_blueprint_slot(
		"loco_armor",
		armor_rect,
		{"kind": "loco_part", "part": "armor"},
		"🛡 排障裝甲",
		"Lv.%d\n耐久%d" % [armor_lv, int(round(float(TrainConsistManager.ARMOR_TIERS[armor_lv - 1]["hull_hp"])))],
		Color(0.86, 0.68, 0.38),
		false,
		"loco_armor",
		false,
		font
	)

	# Interior Slot 2: Glowing Coal Boiler Core!
	var boiler_rect: Rect2 = Rect2(x0 + 154.0, CABIN_Y, 100.0, CABIN_H)
	_draw_blueprint_slot(
		"loco_boiler",
		boiler_rect,
		{"kind": "loco_part", "part": "boiler"},
		"🔥 鍋爐火箱",
		"Lv.%d\n牽引%d節" % [boiler_lv, int(stats.get("max_carriages", 3))],
		Color(1.0, 0.56, 0.24),
		false,
		"loco_boiler",
		false,
		font
	)

	# Interior Slot 3: Engineer Cab (Crew Station!)
	var loco_slots: Array = _consist.locomotive.get("crew_slots", [""]) as Array
	var loco_cid: String = str(loco_slots[0]) if loco_slots.size() > 0 else ""
	var crew_txt: String = "空位\n(放輪機師)"
	var crew_col: Color = Color(0.86, 0.78, 0.64)
	var has_crew: bool = not loco_cid.is_empty()
	if has_crew:
		var cdata: Dictionary = _consist.get_crew_by_id(loco_cid)
		var aff: float = _consist.get_crew_affinity(loco_cid, "mechanic")
		crew_txt = "%s\n%s%d%%" % [str(cdata.get("short_name", cdata.get("name", ""))), "★" if aff >= 1.25 else "", int(round(aff * 100.0))]
		crew_col = Color(0.56, 0.98, 0.68) if aff >= 1.25 else Color(0.98, 0.84, 0.44)

	var cab_rect: Rect2 = Rect2(x0 + 260.0, CABIN_Y, 98.0, CABIN_H)
	_draw_blueprint_slot(
		"loco_cab",
		cab_rect,
		{"kind": "loco_cab"},
		"⚙ 駕駛輪機",
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

	# Rooftop decorative luggage rack & vintage railing
	draw_line(Vector2(x0 + 12.0, CABIN_Y - 22.0), Vector2(x0 + CAR_WIDTH - 12.0, CABIN_Y - 22.0), Color(0.32, 0.24, 0.17, 0.85), 2.5)
	for rx in range(18, int(CAR_WIDTH) - 12, 24):
		draw_line(Vector2(x0 + float(rx), CABIN_Y - 22.0), Vector2(x0 + float(rx), CABIN_Y - 12.0), Color(0.32, 0.24, 0.17, 0.85), 2.0)

	# Waving heraldic banner flags on the tail carriage (just like the reference image!)
	if is_last:
		var pole_x: float = x0 + CAR_WIDTH - 14.0
		draw_line(Vector2(pole_x, ROOF_Y - 8.0), Vector2(pole_x, CABIN_Y - 10.0), Color(0.28, 0.21, 0.16, 1.0), 3.5)
		draw_circle(Vector2(pole_x, ROOF_Y - 10.0), 4.5, Color(0.88, 0.70, 0.34, 1.0))
		var wave: float = sin(_anim_time * 3.0) * 5.0
		var flag1: PackedVector2Array = PackedVector2Array([
			Vector2(pole_x + 2.0, ROOF_Y),
			Vector2(pole_x + 56.0, ROOF_Y - 4.0 + wave),
			Vector2(pole_x + 52.0, ROOF_Y + 18.0 + wave),
			Vector2(pole_x + 2.0, ROOF_Y + 20.0),
		])
		draw_colored_polygon(flag1, Color(0.92, 0.88, 0.76, 0.96))
		draw_polyline(PackedVector2Array([flag1[0], flag1[1], flag1[2], flag1[3], flag1[0]]), Color(0.24, 0.34, 0.48, 0.95), 2.0, true)
		var flag2: PackedVector2Array = PackedVector2Array([
			Vector2(pole_x - 2.0, ROOF_Y + 18.0),
			Vector2(pole_x - 46.0, ROOF_Y + 22.0 - wave * 0.7),
			Vector2(pole_x - 42.0, ROOF_Y + 36.0 - wave * 0.7),
			Vector2(pole_x - 2.0, ROOF_Y + 36.0),
		])
		draw_colored_polygon(flag2, Color(0.32, 0.46, 0.34, 0.92))
		draw_polyline(PackedVector2Array([flag2[0], flag2[1], flag2[2], flag2[3], flag2[0]]), Color(0.84, 0.76, 0.56, 0.9), 1.8, true)

	# Warm Walnut Wood & Riveted Cast-Iron Carriage Hull
	var hull_rect: Rect2 = Rect2(x0, CABIN_Y - 14.0, CAR_WIDTH, CABIN_H + 34.0)
	draw_rect(hull_rect, Color(0.24, 0.18, 0.14, 1.0), true)
	draw_rect(Rect2(x0, CABIN_Y - 14.0, CAR_WIDTH, 11.0), Color(0.36, 0.27, 0.19, 1.0), true)
	draw_rect(Rect2(x0, CABIN_Y + CABIN_H + 8.0, CAR_WIDTH, 12.0), Color(0.28, 0.22, 0.18, 1.0), true)
	draw_rect(hull_rect, Color(0.72, 0.56, 0.32, 0.92), false, 2.5)
	# Vertical wooden structural timber pillars & brass studs
	for px in [x0 + 4.0, x0 + CAR_WIDTH * 0.5 - 3.0, x0 + CAR_WIDTH - 9.0]:
		draw_rect(Rect2(px, CABIN_Y - 4.0, 6.0, CABIN_H + 12.0), Color(0.38, 0.28, 0.19, 1.0), true)
		draw_circle(Vector2(px + 3.0, CABIN_Y + 6.0), 2.2, Color(0.86, 0.70, 0.38, 0.9))
		draw_circle(Vector2(px + 3.0, CABIN_Y + CABIN_H - 6.0), 2.2, Color(0.86, 0.70, 0.38, 0.9))

	# Spoked Bogie Wheels + Iron Frame
	draw_rect(Rect2(x0 + 26.0, RAIL_Y - 22.0, 74.0, 9.0), Color(0.22, 0.19, 0.17, 1.0), true)
	draw_rect(Rect2(x0 + CAR_WIDTH - 100.0, RAIL_Y - 22.0, 74.0, 9.0), Color(0.22, 0.19, 0.17, 1.0), true)
	for wx in [x0 + 44.0, x0 + 82.0, x0 + CAR_WIDTH - 82.0, x0 + CAR_WIDTH - 44.0]:
		_draw_spoked_wheel(Vector2(wx, RAIL_Y - 16.0), 16.0)

	# Carriage Header Label (Ink brown on parchment!)
	draw_string(font, Vector2(x0 + 8.0, ROOF_Y - 8.0), "#%d 車廂（%s）" % [car_idx + 1, str(spec.get("short", "車廂"))], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.24, 0.16, 0.10))

	# 1. Roof Hardpoint Slot (Upper Deck Box on Parchment Sky — just like top squares in reference!)
	var roof_mod: String = str(car.get("roof", "none"))
	var rspec: Dictionary = _consist.get_roof_spec(roof_mod)
	var roof_rect: Rect2 = Rect2(x0 + 50.0, ROOF_Y + 8.0, CAR_WIDTH - 100.0, ROOF_H - 8.0)
	var rpwr: int = int(rspec.get("power", 0))
	var rsub: String = "車頂掛點" if roof_mod == "none" else ("⚡耗電%d" % rpwr if rpwr > 0 else "免電力")
	_draw_blueprint_slot(
		"car_%d_roof" % car_idx,
		roof_rect,
		{"kind": "car_roof", "car_idx": car_idx},
		"%s %s" % [str(rspec.get("icon", "⬜")), str(rspec.get("short", "空車頂"))],
		rsub,
		rspec.get("accent", Color(0.72, 0.56, 0.34)) as Color,
		true,
		"roof_" + roof_mod,
		false,
		font
	)

	# 2. Two Warm Wood-Paneled Interior Cabin Grid Cells!
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
		var accent: Color = cspec.get("accent", Color(0.76, 0.62, 0.42)) as Color
		var has_crew: bool = not cid.is_empty()
		if mod == "empty":
			sub_text = "點擊改裝\n機能艙室"
		elif not has_crew:
			sub_text = "空位\n(點此放人)"
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
			"%s %s" % [str(cspec.get("icon", "")), str(cspec.get("short", mod))],
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
	var border_col: Color = Color(0.46, 0.34, 0.18, 0.95) if can_expand else Color(0.48, 0.42, 0.36, 0.65)
	var bg_col: Color = Color(0.84, 0.76, 0.58, 0.85) if can_expand else Color(0.76, 0.69, 0.56, 0.62)
	if _hover_key == "expand_car" and can_expand:
		bg_col = Color(0.92, 0.84, 0.66, 0.95)

	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, 2.5)
	_draw_corner_triangles(rect, Color(0.36, 0.70, 0.94, 0.95) if can_expand else Color(0.54, 0.48, 0.42, 0.6), 11.0)

	var title_txt: String = "＋ 擴建新車廂" if can_expand else "牽引已達上限"
	var sub_txt: String = _consist.format_cost(TrainConsistManager.EXPAND_CARRIAGE_COST) if can_expand else "請升級鍋爐\n(%d/%d 節)" % [_consist.carriages.size(), _consist.get_max_carriages()]
	draw_string(font, Vector2(rect.position.x + 10.0, rect.position.y + 52.0), title_txt, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20.0, 18, Color(0.24, 0.15, 0.08))
	var lines: PackedStringArray = sub_txt.split("\n")
	for li in range(lines.size()):
		draw_string(font, Vector2(rect.position.x + 10.0, rect.position.y + 88.0 + float(li) * 24.0), lines[li], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20.0, 16, Color(0.36, 0.25, 0.14))

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
		# Translucent parchment-framed upper deck square (exactly like reference image roof slots!)
		var roof_bg: Color = Color(0.95, 0.88, 0.70, 0.88) if is_sel else (Color(0.93, 0.86, 0.70, 0.72) if is_hov else Color(0.86, 0.78, 0.62, 0.56))
		draw_rect(rect, roof_bg, true)
		_draw_roof_mini_art(rect, art_kind)
	else:
		# Warm wood-paneled cabin room interior!
		var room_bg: Color = Color(0.28, 0.20, 0.14, 1.0) if not is_sel else Color(0.38, 0.26, 0.16, 1.0)
		if is_hov and not is_sel:
			room_bg = Color(0.33, 0.24, 0.17, 1.0)
		draw_rect(rect, room_bg, true)
		# Back wall vertical wood planks
		var plank_col: Color = Color(0.20, 0.14, 0.09, 0.45)
		for px in range(18, int(rect.size.x), 20):
			draw_line(Vector2(rect.position.x + float(px), rect.position.y + 2.0), Vector2(rect.position.x + float(px), rect.end.y - 14.0), plank_col, 1.5)
		# Warm wooden floorboards
		draw_rect(Rect2(rect.position.x + 2.0, rect.end.y - 16.0, rect.size.x - 4.0, 14.0), Color(0.38, 0.27, 0.17, 1.0), true)
		draw_line(Vector2(rect.position.x + 2.0, rect.end.y - 16.0), Vector2(rect.end.x - 2.0, rect.end.y - 16.0), Color(0.56, 0.42, 0.26, 0.85), 1.5)
		# Warm hanging cabin lantern glow
		if art_kind != "empty":
			draw_circle(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 34.0), rect.size.x * 0.36, Color(1.0, 0.82, 0.42, 0.16))
		# Miniature room interior artwork + crew silhouette!
		_draw_cabin_mini_art(rect, art_kind, has_crew)
		# Top warm header ribbon so module title stays effortlessly readable
		draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0, rect.size.x - 4.0, 26.0), Color(0.16, 0.11, 0.08, 0.82), true)
		# Bottom dark-oak crew/status ribbon
		draw_rect(Rect2(rect.position.x + 2.0, rect.end.y - 44.0, rect.size.x - 4.0, 42.0), Color(0.14, 0.10, 0.07, 0.80), true)

	# Outer brass / gold frame
	var frame_col: Color = Color(1.0, 0.82, 0.28, 1.0) if is_sel else (Color(0.86, 0.70, 0.38, 1.0) if is_hov else Color(0.38, 0.29, 0.20, 0.95))
	draw_rect(rect, frame_col, false, 3.0 if is_sel else 2.0)

	# Iconic Uncharted Waters soft sky-blue corner triangles (gold when selected!)
	var corner_col: Color = Color(1.0, 0.82, 0.26, 1.0) if is_sel else Color(0.42, 0.76, 0.96, 0.96)
	_draw_corner_triangles(rect, corner_col, 12.0 if is_sel else 10.0)

	# Crisp large text
	var title_col: Color = Color(0.20, 0.13, 0.08) if is_roof else Color(0.98, 0.93, 0.82)
	var title_y: float = rect.position.y + (26.0 if is_roof else 21.0)
	draw_string(font, Vector2(rect.position.x + 6.0, title_y), title_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12.0, 16, title_col)

	var lines: PackedStringArray = sub_text.split("\n")
	var start_y: float = rect.position.y + (49.0 if is_roof else rect.size.y - 25.0)
	for li in range(lines.size()):
		var lcol: Color = Color(0.32, 0.22, 0.12) if is_roof else (Color(0.96, 0.86, 0.58) if li == 0 else Color(0.90, 0.84, 0.74))
		if not is_roof and has_crew and li == 0:
			lcol = Color(0.56, 1.0, 0.72)
		elif not is_roof and lines[li].contains("★"):
			lcol = Color(1.0, 0.86, 0.36)
		draw_string(font, Vector2(rect.position.x + 6.0, start_y + float(li) * 19.0), lines[li], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12.0, 15, lcol)

	_hit_rects.append({"key": key, "rect": rect, "sel": sel_dict})


func _draw_roof_mini_art(rect: Rect2, art_kind: String) -> void:
	var cx: float = rect.position.x + rect.size.x * 0.5
	var by: float = rect.end.y - 6.0
	match art_kind:
		"roof_turret":
			draw_rect(Rect2(cx - 22.0, by - 16.0, 44.0, 14.0), Color(0.28, 0.24, 0.21, 0.75), true)
			draw_line(Vector2(cx + 16.0, by - 12.0), Vector2(cx + 48.0, by - 14.0), Color(0.24, 0.20, 0.18, 0.85), 5.0)
		"roof_radar":
			draw_arc(Vector2(cx, by - 18.0), 18.0, deg_to_rad(200.0), deg_to_rad(340.0), 12, Color(0.30, 0.42, 0.52, 0.8), 3.0)
		"roof_tesla":
			draw_rect(Rect2(cx - 24.0, by - 18.0, 10.0, 16.0), Color(0.76, 0.48, 0.24, 0.75), true)
			draw_rect(Rect2(cx + 14.0, by - 18.0, 10.0, 16.0), Color(0.76, 0.48, 0.24, 0.75), true)
		"roof_shield":
			draw_rect(Rect2(cx - 34.0, by - 12.0, 68.0, 10.0), Color(0.56, 0.44, 0.26, 0.8), true)


func _draw_cabin_mini_art(rect: Rect2, art_kind: String, has_crew: bool) -> void:
	var x: float = rect.position.x
	var y: float = rect.position.y + 30.0
	var w: float = rect.size.x
	var mid_y: float = y + 48.0

	match art_kind:
		"loco_boiler":
			# Glowing orange-red arched coal firebox (exact signature visual from reference!)
			var fire_pulse: float = 0.88 + sin(_anim_time * 7.5) * 0.12
			draw_circle(Vector2(x + w * 0.5, mid_y - 10.0), 26.0, Color(0.95, 0.36, 0.10, 0.35 * fire_pulse))
			draw_rect(Rect2(x + 18.0, y + 6.0, w - 36.0, 42.0), Color(0.78, 0.26, 0.08, 0.92), true)
			draw_rect(Rect2(x + 26.0, y + 18.0, w - 52.0, 26.0), Color(1.0, 0.64, 0.18, 0.95 * fire_pulse), true)
			draw_rect(Rect2(x + 18.0, y + 6.0, w - 36.0, 42.0), Color(0.42, 0.30, 0.20, 1.0), false, 3.0)
		"loco_armor":
			# Riveted brass-banded iron bulkhead & gears
			draw_circle(Vector2(x + w * 0.5, y + 26.0), 17.0, Color(0.70, 0.54, 0.28, 0.65))
			draw_circle(Vector2(x + w * 0.5, y + 26.0), 8.0, Color(0.24, 0.18, 0.14, 1.0))
		"loco_cab":
			# Brass lever console & pressure gauges
			draw_rect(Rect2(x + 12.0, y + 16.0, 22.0, 30.0), Color(0.56, 0.42, 0.24, 0.85), true)
			draw_circle(Vector2(x + 23.0, y + 24.0), 6.0, Color(0.96, 0.88, 0.68, 0.9))
		"cargo":
			# Stacked wooden crates & iron-banded barrel (just like reference image!)
			draw_rect(Rect2(x + 14.0, y + 22.0, 28.0, 26.0), Color(0.58, 0.42, 0.24, 0.92), true)
			draw_rect(Rect2(x + 14.0, y + 22.0, 28.0, 26.0), Color(0.32, 0.22, 0.12, 1.0), false, 2.0)
			draw_rect(Rect2(x + 24.0, y + 6.0, 24.0, 20.0), Color(0.64, 0.48, 0.28, 0.92), true)
			draw_rect(Rect2(x + 52.0, y + 20.0, 22.0, 28.0), Color(0.46, 0.31, 0.18, 0.95), true)
			draw_line(Vector2(x + 52.0, y + 27.0), Vector2(x + 74.0, y + 27.0), Color(0.22, 0.20, 0.18, 1.0), 2.5)
			draw_line(Vector2(x + 52.0, y + 40.0), Vector2(x + 74.0, y + 40.0), Color(0.22, 0.20, 0.18, 1.0), 2.5)
		"quarters":
			# Cozy wooden bunk beds with cream pillows
			draw_rect(Rect2(x + 14.0, y + 12.0, 56.0, 7.0), Color(0.56, 0.40, 0.24, 0.95), true)
			draw_rect(Rect2(x + 16.0, y + 8.0, 14.0, 5.0), Color(0.92, 0.86, 0.72, 0.9), true)
			draw_rect(Rect2(x + 14.0, y + 34.0, 56.0, 7.0), Color(0.56, 0.40, 0.24, 0.95), true)
			draw_rect(Rect2(x + 16.0, y + 30.0, 14.0, 5.0), Color(0.92, 0.86, 0.72, 0.9), true)
			draw_line(Vector2(x + 14.0, y + 4.0), Vector2(x + 14.0, y + 48.0), Color(0.42, 0.28, 0.16, 1.0), 3.0)
			draw_line(Vector2(x + 70.0, y + 4.0), Vector2(x + 70.0, y + 48.0), Color(0.42, 0.28, 0.16, 1.0), 3.0)
		"gunnery":
			# Heavy brass breech cannon & stacked shells
			draw_rect(Rect2(x + 18.0, y + 24.0, 38.0, 14.0), Color(0.32, 0.30, 0.28, 0.95), true)
			draw_rect(Rect2(x + 48.0, y + 26.0, 26.0, 8.0), Color(0.46, 0.42, 0.38, 0.95), true)
			draw_circle(Vector2(x + 28.0, y + 42.0), 8.0, Color(0.58, 0.40, 0.22, 0.95))
		"medbay":
			# Warm linen medical bed + glowing green/red cross plaque
			draw_rect(Rect2(x + 14.0, y + 32.0, 54.0, 12.0), Color(0.86, 0.84, 0.76, 0.92), true)
			draw_rect(Rect2(x + 48.0, y + 8.0, 8.0, 20.0), Color(0.32, 0.86, 0.52, 0.92), true)
			draw_rect(Rect2(x + 42.0, y + 14.0, 20.0, 8.0), Color(0.32, 0.86, 0.52, 0.92), true)
		"armory":
			# Interlocking brass gears & workshop bench
			draw_circle(Vector2(x + 30.0, y + 22.0), 15.0, Color(0.76, 0.58, 0.30, 0.85))
			draw_circle(Vector2(x + 30.0, y + 22.0), 6.0, Color(0.24, 0.17, 0.12, 1.0))
			draw_circle(Vector2(x + 54.0, y + 32.0), 11.0, Color(0.64, 0.48, 0.24, 0.85))
			draw_circle(Vector2(x + 54.0, y + 32.0), 4.0, Color(0.24, 0.17, 0.12, 1.0))
		"recon":
			# Brass telegraph / map desk & glowing dial
			draw_rect(Rect2(x + 16.0, y + 26.0, 50.0, 18.0), Color(0.48, 0.34, 0.20, 0.92), true)
			draw_circle(Vector2(x + 32.0, y + 18.0), 9.0, Color(0.46, 0.84, 0.96, 0.85))
		"generator":
			# Glowing copper dynamo coils
			draw_rect(Rect2(x + 20.0, y + 10.0, 18.0, 36.0), Color(0.82, 0.48, 0.22, 0.92), true)
			draw_rect(Rect2(x + 48.0, y + 10.0, 18.0, 36.0), Color(0.82, 0.48, 0.22, 0.92), true)
			draw_line(Vector2(x + 29.0, y + 18.0), Vector2(x + 57.0, y + 22.0), Color(0.56, 0.94, 1.0, 0.9), 2.5)
		"boarding":
			# Brass command table & steel hatch
			draw_rect(Rect2(x + 16.0, y + 10.0, 34.0, 38.0), Color(0.36, 0.44, 0.42, 0.88), true)
			draw_rect(Rect2(x + 16.0, y + 10.0, 34.0, 38.0), Color(0.82, 0.66, 0.34, 0.9), false, 2.0)

	# Cozy lit miniature Crew Member silhouette standing inside the cabin when stationed!
	if has_crew:
		var px: float = x + w - 24.0
		var py: float = y + 34.0
		draw_circle(Vector2(px, py - 14.0), 7.5, Color(0.96, 0.84, 0.68, 0.98))
		draw_rect(Rect2(px - 8.0, py - 6.0, 16.0, 20.0), Color(0.34, 0.56, 0.46, 0.96), true)
		draw_rect(Rect2(px - 8.0, py - 6.0, 16.0, 20.0), Color(0.94, 0.82, 0.48, 0.85), false, 1.5)


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
	draw_circle(center, radius, Color(0.18, 0.16, 0.15, 1.0))
	draw_arc(center, radius, 0.0, TAU, 24, Color(0.64, 0.56, 0.42, 1.0), 3.0)
	draw_arc(center, radius * 0.72, 0.0, TAU, 20, Color(0.38, 0.32, 0.26, 0.9), 1.5)
	for si in range(6):
		var ang: float = float(si) * (PI / 3.0)
		var dv: Vector2 = Vector2(cos(ang), sin(ang)) * (radius - 2.0)
		draw_line(center - dv, center + dv, Color(0.56, 0.48, 0.36, 0.85), 1.8)
	draw_circle(center, radius * 0.28, Color(0.76, 0.60, 0.34, 1.0))


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
