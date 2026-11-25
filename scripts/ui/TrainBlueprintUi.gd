class_name TrainBlueprintUi
extends CanvasLayer

signal closed()
signal sandbox_resources_requested()
signal feedback_message(message: String)

var _consist: TrainConsistManager = null
var _stash_ref: Dictionary = {}
var _is_open: bool = false
var _selection: Dictionary = {"kind": "car_cell", "car_idx": 0, "cell_idx": 0}

var _backdrop: ColorRect = null
var _resource_label: Label = null
var _stats_label: Label = null
var _feedback_label: Label = null
var _cutaway: TrainCutawayDiagram = null
var _inspector_title: Label = null
var _inspector_body: VBoxContainer = null
var _crew_body: VBoxContainer = null


func setup(consist: TrainConsistManager, stash_dict: Dictionary) -> void:
	layer = 20
	_consist = consist
	_stash_ref = stash_dict
	_build_ui()
	set_open(false)


func is_open() -> bool:
	return _is_open


func set_open(open: bool) -> void:
	_is_open = open
	if _backdrop != null:
		_backdrop.visible = open
	if open:
		refresh()
	else:
		closed.emit()


func toggle_open() -> void:
	set_open(not _is_open)


func update_stash_reference(stash_dict: Dictionary) -> void:
	_stash_ref = stash_dict
	if _is_open:
		refresh()


func _make_style(bg: Color, border: Color, radius: int = 8, border_w: int = 2) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _build_warm_vintage_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 17

	# Vintage deep-slate & brass buttons (matching the Uncharted Waters refit buttons!)
	var btn_normal: StyleBoxFlat = _make_style(Color(0.24, 0.32, 0.42, 0.96), Color(0.76, 0.62, 0.36, 0.95), 6, 2)
	var btn_hover: StyleBoxFlat = _make_style(Color(0.32, 0.42, 0.54, 1.0), Color(0.95, 0.78, 0.42, 1.0), 6, 2)
	var btn_pressed: StyleBoxFlat = _make_style(Color(0.68, 0.36, 0.14, 1.0), Color(1.0, 0.84, 0.46, 1.0), 6, 2)
	var btn_disabled: StyleBoxFlat = _make_style(Color(0.20, 0.17, 0.15, 0.82), Color(0.46, 0.39, 0.30, 0.72), 6, 1)

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", Color(0.98, 0.94, 0.84))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.97, 0.88))
	theme.set_color("font_disabled_color", "Button", Color(0.66, 0.59, 0.48))
	return theme


func _style_amber_cta(btn: Button) -> void:
	# Warm copper-orange CTA button (inspired by the "確定" button in reference!)
	btn.add_theme_stylebox_override("normal", _make_style(Color(0.72, 0.36, 0.13, 0.98), Color(0.96, 0.78, 0.42, 0.98), 6, 2))
	btn.add_theme_stylebox_override("hover", _make_style(Color(0.84, 0.45, 0.18, 1.0), Color(1.0, 0.86, 0.52, 1.0), 6, 2))
	btn.add_theme_stylebox_override("pressed", _make_style(Color(0.56, 0.27, 0.09, 1.0), Color(0.96, 0.78, 0.42, 1.0), 6, 2))


func _build_ui() -> void:
	# Warm sepia drafting-table vignette backdrop (never cold pitch black!)
	_backdrop = ColorRect.new()
	_backdrop.name = "BlueprintBackdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.18, 0.14, 0.10, 0.84)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.theme = _build_warm_vintage_theme()
	add_child(_backdrop)

	# Outer ornate bronze frame
	var outer_frame: PanelContainer = PanelContainer.new()
	outer_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_frame.offset_left = 22.0
	outer_frame.offset_top = 16.0
	outer_frame.offset_right = -22.0
	outer_frame.offset_bottom = -16.0
	outer_frame.add_theme_stylebox_override("panel", _make_style(Color(0.18, 0.14, 0.11, 0.99), Color(0.78, 0.62, 0.36, 0.98), 10, 3))
	_backdrop.add_child(outer_frame)

	# Inner warm espresso-walnut drafting window
	var window: PanelContainer = PanelContainer.new()
	window.add_theme_stylebox_override("panel", _make_style(Color(0.24, 0.18, 0.14, 0.99), Color(0.54, 0.42, 0.26, 0.92), 6, 2))
	outer_frame.add_child(window)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 9)
	window.add_child(root_vbox)

	# 1. Warm Header Bar
	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	root_vbox.add_child(hdr)

	var title: Label = Label.new()
	title.text = "🚂 蒸氣武裝列車設計圖 — 車頭改造 × 車廂擴建 × 艙室改裝 × 成員入艙"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.91, 0.72))
	hdr.add_child(title)

	var dev_btn: Button = Button.new()
	dev_btn.text = "🔧 測試補給 (+20 全資源)"
	dev_btn.add_theme_font_size_override("font_size", 17)
	_style_amber_cta(dev_btn)
	dev_btn.pressed.connect(func():
		sandbox_resources_requested.emit()
		_set_feedback("已補充測試資源至列車暫存倉（全資源 +20）！", Color(0.68, 0.98, 0.66))
		refresh()
	)
	hdr.add_child(dev_btn)

	var close_btn: Button = Button.new()
	close_btn.text = "✕ 完成返回 [T]"
	close_btn.add_theme_font_size_override("font_size", 17)
	close_btn.pressed.connect(func(): set_open(false))
	hdr.add_child(close_btn)

	# 2. Warm Bronze Ledger Strip (Inspired by 所持金 / 費用 / 蒸氣武裝列車 bars!)
	var info_panel: PanelContainer = PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _make_style(Color(0.18, 0.13, 0.10, 0.98), Color(0.72, 0.56, 0.32, 0.88), 6, 2))
	root_vbox.add_child(info_panel)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_panel.add_child(info_vbox)

	_resource_label = Label.new()
	_resource_label.add_theme_font_size_override("font_size", 17)
	_resource_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	info_vbox.add_child(_resource_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.add_theme_color_override("font_color", Color(0.95, 0.89, 0.78))
	info_vbox.add_child(_stats_label)

	# 3. Warm Vintage Parchment Cutaway Blueprint Frame
	var cutaway_frame: PanelContainer = PanelContainer.new()
	cutaway_frame.add_theme_stylebox_override("panel", _make_style(Color(0.34, 0.25, 0.17, 1.0), Color(0.84, 0.68, 0.38, 0.98), 6, 3))
	root_vbox.add_child(cutaway_frame)

	var cutaway_scroll: ScrollContainer = ScrollContainer.new()
	cutaway_scroll.custom_minimum_size = Vector2(0.0, TrainCutawayDiagram.DIAGRAM_HEIGHT + 12.0)
	cutaway_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cutaway_frame.add_child(cutaway_scroll)

	_cutaway = TrainCutawayDiagram.new()
	_cutaway.slot_selected.connect(_on_cutaway_slot_selected)
	cutaway_scroll.add_child(_cutaway)

	# 4. Bottom Warm Walnut Split Panel: Left = Cabin/Loco Refit, Right = Crew Roster Placement
	var split: HBoxContainer = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	root_vbox.add_child(split)

	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.25
	left_panel.add_theme_stylebox_override("panel", _make_style(Color(0.19, 0.14, 0.11, 0.98), Color(0.70, 0.54, 0.30, 0.88), 6, 2))
	split.add_child(left_panel)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_panel.add_child(left_scroll)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 9)
	left_scroll.add_child(left_vbox)

	_inspector_title = Label.new()
	_inspector_title.add_theme_font_size_override("font_size", 19)
	_inspector_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54))
	left_vbox.add_child(_inspector_title)

	_inspector_body = VBoxContainer.new()
	_inspector_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_body.add_theme_constant_override("separation", 8)
	left_vbox.add_child(_inspector_body)

	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	right_panel.add_theme_stylebox_override("panel", _make_style(Color(0.19, 0.14, 0.11, 0.98), Color(0.66, 0.56, 0.34, 0.88), 6, 2))
	split.add_child(right_panel)

	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_panel.add_child(right_scroll)

	_crew_body = VBoxContainer.new()
	_crew_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew_body.add_theme_constant_override("separation", 8)
	right_scroll.add_child(_crew_body)

	# 5. Warm Footer Feedback Ribbon
	_feedback_label = Label.new()
	_feedback_label.text = "點選上方羊皮紙設計圖中的任一【藍角方格】，即可改裝艙室／車頂武裝，並在右側直接將成員派駐入艙！"
	_feedback_label.add_theme_font_size_override("font_size", 16)
	_feedback_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	root_vbox.add_child(_feedback_label)


func _on_cutaway_slot_selected(sel: Dictionary) -> void:
	var kind: String = str(sel.get("kind", ""))
	if kind == "expand_car":
		var res: Dictionary = _consist.expand_carriage(_stash_ref)
		var ok: bool = bool(res.get("ok", false))
		if ok:
			_selection = {"kind": "car_cell", "car_idx": int(res.get("index", _consist.carriages.size() - 1)), "cell_idx": 0}
		_set_feedback(str(res.get("message", "")), Color(0.68, 0.98, 0.66) if ok else Color(1.0, 0.60, 0.40))
		refresh()
		return
	_selection = sel.duplicate()
	refresh()


func _set_feedback(msg: String, color: Color = Color(0.95, 0.88, 0.72)) -> void:
	if _feedback_label != null:
		_feedback_label.text = msg
		_feedback_label.add_theme_color_override("font_color", color)
	feedback_message.emit(msg)


func _clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _clamp_selection() -> void:
	var kind: String = str(_selection.get("kind", "car_cell"))
	if kind == "car_roof" or kind == "car_cell":
		if _consist.carriages.is_empty():
			_selection = {"kind": "loco_part", "part": "boiler"}
			return
		var ci: int = clampi(int(_selection.get("car_idx", 0)), 0, _consist.carriages.size() - 1)
		_selection["car_idx"] = ci


func refresh() -> void:
	if _consist == null or _cutaway == null:
		return
	_clamp_selection()

	var stats: Dictionary = _consist.compute_stats()
	_resource_label.text = "📦 列車暫存倉資源：廢金屬 %d ｜ 機械零件 %d ｜ 高能燃料 %d ｜ 醫療補給 %d" % [
		int(_stash_ref.get("scrap", 0)),
		int(_stash_ref.get("parts", 0)),
		int(_stash_ref.get("fuel", 0)),
		int(_stash_ref.get("supplies", 0)),
	]
	_stats_label.text = "🛡 裝甲耐久 %d ｜ 🚃 牽引 %d/%d 節 ｜ ⚡ 動力 %d/%d ｜ 🎒 背包上限 %d ｜ 🔫 砲塔 %d 座 (%d DPS) ｜ ⏱ 發車 %.0fs ｜ 👥 駐守 %d/%d" % [
		int(round(float(stats.get("max_hull_hp", 1000.0)))),
		int(stats.get("carriage_count", 0)),
		int(stats.get("max_carriages", 3)),
		int(stats.get("power_used", 0)),
		int(stats.get("power_capacity", 6)),
		int(stats.get("backpack_capacity", 12)),
		int(stats.get("turret_count", 0)),
		int(round(float(stats.get("turret_dps", 0.0)))),
		float(stats.get("departure_seconds", 45.0)),
		int(stats.get("assigned_crew", 0)),
		int(stats.get("total_crew_slots", 1)),
	]

	_cutaway.set_data(_consist, _selection)
	_rebuild_inspector(stats)
	_rebuild_crew_panel()


func _rebuild_inspector(stats: Dictionary) -> void:
	_clear_children(_inspector_body)
	var kind: String = str(_selection.get("kind", "loco_part"))

	if kind == "loco_part" or kind == "loco_cab":
		_inspector_title.text = "🔥 蒸氣武裝火車頭改造（點選火車頭各部件或下方升級）"
		_add_loco_upgrade_row(
			"鍋爐與傳動引擎",
			"boiler",
			int(stats.get("boiler_level", 1)),
			TrainConsistManager.MAX_BOILER_LEVEL,
			"目前：最大牽引 %d 節 ｜ 基礎動力 %d ｜ 發車倒數 %.0fs" % [
				int(stats.get("max_carriages", 3)),
				int(TrainConsistManager.BOILER_TIERS[int(stats.get("boiler_level", 1)) - 1].get("power", 6)),
				float(stats.get("departure_seconds", 45.0)),
			]
		)
		_add_loco_upgrade_row(
			"重裝排障器與車體裝甲",
			"armor",
			int(stats.get("armor_level", 1)),
			TrainConsistManager.MAX_ARMOR_LEVEL,
			"目前：總耐久 %d HP ｜ 減傷 %d%%（強化鉚釘側板與破障鏟）" % [
				int(round(float(stats.get("max_hull_hp", 1000.0)))),
				int(round(float(stats.get("damage_reduction", 0.0)) * 100.0)),
			]
		)
		_add_loco_upgrade_row(
			"黃銅探照燈與蒸氣汽笛",
			"headlamp",
			int(stats.get("headlamp_level", 1)),
			TrainConsistManager.MAX_HEADLAMP_LEVEL,
			"目前：照明射程 %.0fm（升級增設側燈與車頂探照燈）" % float(stats.get("headlamp_range", 13.0))
		)
		return

	var car_idx: int = int(_selection.get("car_idx", 0))
	var car: Dictionary = _consist.carriages[car_idx]

	var order_row: HBoxContainer = HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 10)
	_inspector_body.add_child(order_row)

	var left_btn: Button = Button.new()
	left_btn.text = "◀ 整節往車頭移動"
	left_btn.disabled = car_idx <= 0
	left_btn.pressed.connect(func():
		var res: Dictionary = _consist.move_carriage(car_idx, -1)
		if bool(res.get("ok", false)):
			_selection["car_idx"] = int(res.get("new_index", car_idx))
		_set_feedback(str(res.get("message", "")))
		refresh()
	)
	order_row.add_child(left_btn)

	var right_btn: Button = Button.new()
	right_btn.text = "整節往車尾移動 ▶"
	right_btn.disabled = car_idx >= _consist.carriages.size() - 1
	right_btn.pressed.connect(func():
		var res: Dictionary = _consist.move_carriage(car_idx, 1)
		if bool(res.get("ok", false)):
			_selection["car_idx"] = int(res.get("new_index", car_idx))
		_set_feedback(str(res.get("message", "")))
		refresh()
	)
	order_row.add_child(right_btn)

	var rm_btn: Button = Button.new()
	rm_btn.text = "🗑 卸除此節車廂"
	rm_btn.pressed.connect(func():
		var res: Dictionary = _consist.remove_carriage(car_idx)
		var ok: bool = bool(res.get("ok", false))
		_set_feedback(str(res.get("message", "")), Color(0.68, 0.98, 0.66) if ok else Color(1.0, 0.60, 0.40))
		refresh()
	)
	order_row.add_child(rm_btn)

	if kind == "car_roof":
		var cur_roof: String = str(car.get("roof", "none"))
		var rspec: Dictionary = _consist.get_roof_spec(cur_roof)
		_inspector_title.text = "🔫 第 %d 節車廂【車頂武裝掛點】— 目前：%s" % [car_idx + 1, str(rspec.get("name", cur_roof))]

		var rdesc: Label = Label.new()
		rdesc.text = str(rspec.get("desc", ""))
		rdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rdesc.add_theme_font_size_override("font_size", 16)
		rdesc.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
		_inspector_body.add_child(rdesc)

		var rgrid: GridContainer = GridContainer.new()
		rgrid.columns = 2
		rgrid.add_theme_constant_override("h_separation", 10)
		rgrid.add_theme_constant_override("v_separation", 10)
		_inspector_body.add_child(rgrid)

		for rkey in TrainConsistManager.ROOF_ORDER_KEYS:
			var spec: Dictionary = _consist.get_roof_spec(rkey)
			var pwr: int = int(spec.get("power", 0))
			var cost_s: String = _consist.format_cost(spec.get("cost", {}) as Dictionary)
			var btn: Button = Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0.0, 62.0)
			btn.disabled = (rkey == cur_roof)
			btn.text = "%s %s（耗電 %d）\n%s" % [
				str(spec.get("icon", "")),
				str(spec.get("name", rkey)),
				pwr,
				"目前裝配" if rkey == cur_roof else cost_s,
			]
			var target_r: String = rkey
			btn.pressed.connect(func():
				var res: Dictionary = _consist.refit_carriage_roof(car_idx, target_r, _stash_ref)
				var ok: bool = bool(res.get("ok", false))
				_set_feedback(str(res.get("message", "")), Color(0.68, 0.98, 0.66) if ok else Color(1.0, 0.60, 0.40))
				refresh()
			)
			rgrid.add_child(btn)
		return

	var cell_idx: int = clampi(int(_selection.get("cell_idx", 0)), 0, 1)
	var cells: Array = car.get("cells", []) as Array
	var cell: Dictionary = cells[cell_idx] as Dictionary
	var cur_mod: String = str(cell.get("module", "empty"))
	var cspec: Dictionary = _consist.get_cell_spec(cur_mod)

	_inspector_title.text = "🚪 第 %d 節車廂【艙格 %d】改裝 — 目前：%s %s" % [
		car_idx + 1,
		cell_idx + 1,
		str(cspec.get("icon", "")),
		str(cspec.get("name", cur_mod)),
	]

	var cdesc: Label = Label.new()
	cdesc.text = str(cspec.get("desc", ""))
	cdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cdesc.add_theme_font_size_override("font_size", 16)
	cdesc.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	_inspector_body.add_child(cdesc)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_inspector_body.add_child(grid)

	for mkey in TrainConsistManager.CELL_ORDER_KEYS:
		if mkey == "empty" and cur_mod == "empty":
			continue
		var spec: Dictionary = _consist.get_cell_spec(mkey)
		var pwr: int = int(spec.get("power", 0))
		var pwr_s: String = ("+%d動力" % (-pwr)) if pwr < 0 else ("耗%d動力" % pwr)
		var cost_s: String = _consist.format_cost(spec.get("cost", {}) as Dictionary)

		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 58.0)
		btn.disabled = (mkey == cur_mod)
		btn.text = "%s %s (%s)\n%s ｜ 適性：%s" % [
			str(spec.get("icon", "")),
			str(spec.get("name", mkey)),
			pwr_s,
			"目前艙室" if mkey == cur_mod else cost_s,
			_consist.get_role_label(str(spec.get("best_role", "any"))),
		]
		var target_m: String = mkey
		btn.pressed.connect(func():
			var res: Dictionary = _consist.refit_carriage_cell(car_idx, cell_idx, target_m, _stash_ref)
			var ok: bool = bool(res.get("ok", false))
			_set_feedback(str(res.get("message", "")), Color(0.68, 0.98, 0.66) if ok else Color(1.0, 0.60, 0.40))
			refresh()
		)
		grid.add_child(btn)


func _add_loco_upgrade_row(title_text: String, part_key: String, cur_lv: int, max_lv: int, desc_text: String) -> void:
	var is_sel_part: bool = str(_selection.get("kind", "")) == "loco_part" and str(_selection.get("part", "")) == part_key
	var box: PanelContainer = PanelContainer.new()
	box.add_theme_stylebox_override("panel", _make_style(Color(0.25, 0.19, 0.14, 0.96), Color(1.0, 0.82, 0.34) if is_sel_part else Color(0.58, 0.46, 0.28, 0.85), 6, 2 if is_sel_part else 1))
	_inspector_body.add_child(box)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	box.add_child(hbox)

	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(v)

	var lbl: Label = Label.new()
	lbl.text = "%s（Lv.%d / %d）" % [title_text, cur_lv, max_lv]
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.99, 0.93, 0.78))
	v.add_child(lbl)

	var d: Label = Label.new()
	d.text = desc_text
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 15)
	d.add_theme_color_override("font_color", Color(0.90, 0.84, 0.72))
	v.add_child(d)

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(186.0, 56.0)
	if cur_lv >= max_lv:
		btn.text = "已達滿級"
		btn.disabled = true
	else:
		var cost: Dictionary = _consist.get_locomotive_upgrade_cost(part_key)
		btn.text = "升級 Lv.%d\n(%s)" % [cur_lv + 1, _consist.format_cost(cost)]
		_style_amber_cta(btn)
	btn.pressed.connect(func():
		var res: Dictionary = _consist.upgrade_locomotive(part_key, _stash_ref)
		var ok: bool = bool(res.get("ok", false))
		_set_feedback(str(res.get("message", "")), Color(0.68, 0.98, 0.66) if ok else Color(1.0, 0.60, 0.40))
		refresh()
	)
	hbox.add_child(btn)


func _rebuild_crew_panel() -> void:
	_clear_children(_crew_body)

	var hdr: Label = Label.new()
	hdr.text = "👥 乘員入艙配置（點選上方艙格後直接派駐）"
	hdr.add_theme_font_size_override("font_size", 19)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	_crew_body.add_child(hdr)

	var kind: String = str(_selection.get("kind", "car_cell"))
	var target_is_loco: bool = (kind == "loco_cab" or kind == "loco_part")
	var car_idx: int = int(_selection.get("car_idx", 0))
	var cell_idx: int = int(_selection.get("cell_idx", 0))
	var can_place: bool = true
	var cur_cid: String = ""
	var best_role: String = "mechanic"
	var target_desc: String = ""

	if target_is_loco:
		var loco_slots: Array = _consist.locomotive.get("crew_slots", [""]) as Array
		cur_cid = str(loco_slots[0]) if loco_slots.size() > 0 else ""
		best_role = "mechanic"
		target_desc = "目標格子：裝甲火車頭【駕駛輪機艙】（最佳適性：輪機師）"
	elif kind == "car_roof":
		can_place = false
		target_desc = "目前選取的是【車頂武裝掛點】；請點選下方車廂的【木質內部艙格】來安排成員入艙！"
	else:
		var car: Dictionary = _consist.carriages[car_idx]
		var cells: Array = car.get("cells", []) as Array
		var cell: Dictionary = cells[cell_idx] as Dictionary
		var mod: String = str(cell.get("module", "empty"))
		var cspec: Dictionary = _consist.get_cell_spec(mod)
		cur_cid = str(cell.get("crew_id", ""))
		best_role = str(cspec.get("best_role", "any"))
		can_place = bool(cspec.get("can_assign_crew", false))
		if can_place:
			target_desc = "目標格子：#%d 車廂 艙格 %d【%s】（最佳適性：%s）" % [
				car_idx + 1,
				cell_idx + 1,
				str(cspec.get("name", mod)),
				_consist.get_role_label(best_role),
			]
		else:
			target_desc = "#%d 車廂 艙格 %d 目前為【空艙格】，請先於左側改建機能艙室後即可安排成員入艙。" % [car_idx + 1, cell_idx + 1]

	var t_lbl: Label = Label.new()
	t_lbl.text = target_desc
	t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t_lbl.add_theme_font_size_override("font_size", 16)
	t_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82) if can_place else Color(1.0, 0.74, 0.44))
	_crew_body.add_child(t_lbl)

	if not can_place:
		return

	if not cur_cid.is_empty():
		var cur_crew: Dictionary = _consist.get_crew_by_id(cur_cid)
		var un_row: HBoxContainer = HBoxContainer.new()
		un_row.add_theme_constant_override("separation", 10)
		_crew_body.add_child(un_row)

		var cur_lbl: Label = Label.new()
		cur_lbl.text = "目前格內成員：%s" % str(cur_crew.get("name", cur_cid))
		cur_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cur_lbl.add_theme_font_size_override("font_size", 16)
		cur_lbl.add_theme_color_override("font_color", Color(0.66, 0.98, 0.68))
		un_row.add_child(cur_lbl)

		var un_btn: Button = Button.new()
		un_btn.text = "移出此格"
		un_btn.pressed.connect(func():
			var res: Dictionary = _consist.assign_crew_to_locomotive("") if target_is_loco else _consist.assign_crew_to_cell(car_idx, cell_idx, "")
			_set_feedback(str(res.get("message", "")))
			refresh()
		)
		un_row.add_child(un_btn)

	var sep: HSeparator = HSeparator.new()
	_crew_body.add_child(sep)

	for crew: Dictionary in _consist.crew_roster:
		var cid: String = str(crew.get("id", ""))
		var aff: float = _consist.get_crew_affinity(cid, best_role)
		var is_best: bool = aff >= 1.25

		var crow: PanelContainer = PanelContainer.new()
		crow.add_theme_stylebox_override("panel", _make_style(Color(0.25, 0.19, 0.14, 0.96), Color(0.88, 0.72, 0.36, 0.92) if is_best else Color(0.46, 0.38, 0.28, 0.78), 6, 2 if is_best else 1))
		_crew_body.add_child(crow)

		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		crow.add_child(h)

		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)

		var nm: Label = Label.new()
		nm.text = "%s（%s）%s" % [
			str(crew.get("name", cid)),
			_consist.get_role_label(str(crew.get("role", ""))),
			" ★ 適性 %d%%" % int(round(aff * 100.0)) if is_best else " · 兼任 %d%%" % int(round(aff * 100.0)),
		]
		nm.add_theme_font_size_override("font_size", 17)
		nm.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46) if is_best else Color(0.96, 0.91, 0.82))
		info.add_child(nm)

		var tr: Label = Label.new()
		tr.text = "%s\n%s" % [str(crew.get("trait", "")), _consist.get_crew_assignment_label(cid)]
		tr.add_theme_font_size_override("font_size", 15)
		tr.add_theme_color_override("font_color", Color(0.84, 0.77, 0.66))
		info.add_child(tr)

		var abtn: Button = Button.new()
		abtn.custom_minimum_size = Vector2(106.0, 48.0)
		var already_here: bool = (cur_cid == cid)
		abtn.text = "已入艙" if already_here else "放入此格"
		abtn.disabled = already_here
		if is_best and not already_here:
			_style_amber_cta(abtn)
		var cap_cid: String = cid
		abtn.pressed.connect(func():
			var res: Dictionary = _consist.assign_crew_to_locomotive(cap_cid) if target_is_loco else _consist.assign_crew_to_cell(car_idx, cell_idx, cap_cid)
			var ok: bool = bool(res.get("ok", false))
			_set_feedback(str(res.get("message", "")), Color(0.68, 0.98, 0.66) if ok else Color(1.0, 0.60, 0.40))
			refresh()
		)
		h.add_child(abtn)
