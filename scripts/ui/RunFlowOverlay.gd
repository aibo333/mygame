class_name RunFlowOverlay
extends CanvasLayer

signal deploy_run_requested(tier_num: int, seed_value: int)
signal open_train_blueprint_requested()
signal return_to_hub_requested()
signal save_profile_requested()
signal reset_profile_requested()

var _backdrop: ColorRect = null
var _content_vbox: VBoxContainer = null
var _is_open: bool = false
var _selected_tier: int = 1
var _pending_seed: int = SquadConfig.DEFAULT_SECTOR_SEED


func setup() -> void:
	layer = 18
	_build_shell()
	close()


func is_open() -> bool:
	return _is_open


func close() -> void:
	_is_open = false
	if _backdrop != null:
		_backdrop.visible = false


func _make_style(bg: Color, border: Color, radius: int = 8, border_w: int = 2) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _style_cta(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_style(Color(0.72, 0.36, 0.13, 0.98), Color(0.96, 0.78, 0.42, 0.98), 8, 2))
	btn.add_theme_stylebox_override("hover", _make_style(Color(0.84, 0.45, 0.18, 1.0), Color(1.0, 0.86, 0.52, 1.0), 8, 2))


func _build_shell() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "RunFlowBackdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.14, 0.10, 0.07, 0.86)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme: Theme = Theme.new()
	theme.default_font_size = 17
	_backdrop.theme = theme
	add_child(_backdrop)

	var frame: PanelContainer = PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -460.0
	frame.offset_top = -330.0
	frame.offset_right = 460.0
	frame.offset_bottom = 330.0
	frame.add_theme_stylebox_override("panel", _make_style(Color(0.22, 0.17, 0.13, 0.98), Color(0.84, 0.68, 0.38, 0.98), 12, 3))
	_backdrop.add_child(frame)

	var scroll: ScrollContainer = ScrollContainer.new()
	frame.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_content_vbox)


func _clear_content() -> void:
	for c in _content_vbox.get_children():
		_content_vbox.remove_child(c)
		c.queue_free()


func show_hub(meta: MetaProgressionManager, consist: TrainConsistManager, current_seed: int) -> void:
	_clear_content()
	_is_open = true
	_backdrop.visible = true
	_selected_tier = meta.selected_tier
	_pending_seed = current_seed

	var title: Label = Label.new()
	title.text = "🚂 裝甲列車整備基地 — 局外大廳與區域出擊選擇"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
	_content_vbox.add_child(title)

	var wh: Dictionary = meta.warehouse
	var stats: Dictionary = consist.compute_stats()
	var summary: Label = Label.new()
	summary.text = "📦 基地總倉：廢金屬 %d ｜ 機械零件 %d ｜ 高能燃料 %d ｜ 醫療補給 %d\n🏆 生涯紀錄：成功撤離 %d 局 ｜ 失敗 %d 局 ｜ 累計擊殺 %d 喪屍 ｜ 編成 %d/%d 節（砲塔 %d 座）" % [
		int(wh.get("scrap", 0)),
		int(wh.get("parts", 0)),
		int(wh.get("fuel", 0)),
		int(wh.get("supplies", 0)),
		meta.completed_runs,
		meta.failed_runs,
		meta.total_kills,
		int(stats.get("carriage_count", 3)),
		int(stats.get("max_carriages", 3)),
		int(stats.get("turret_count", 1)),
	]
	summary.add_theme_font_size_override("font_size", 16)
	summary.add_theme_color_override("font_color", Color(0.95, 0.89, 0.78))
	_content_vbox.add_child(summary)

	var tier_hdr: Label = Label.new()
	tier_hdr.text = "🗺 選擇下一局出擊區域難度（Sector Tier）："
	tier_hdr.add_theme_font_size_override("font_size", 18)
	tier_hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	_content_vbox.add_child(tier_hdr)

	for tcfg: Dictionary in MetaProgressionManager.SECTOR_TIERS:
		var tnum: int = int(tcfg.get("tier", 1))
		var unlocked: bool = meta.is_tier_unlocked(tnum, consist)
		var is_sel: bool = (_selected_tier == tnum)

		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_style(
			Color(0.30, 0.22, 0.15, 0.98) if is_sel else Color(0.18, 0.14, 0.11, 0.94),
			Color(1.0, 0.84, 0.36) if is_sel else Color(0.52, 0.42, 0.30),
			8,
			2 if is_sel else 1
		))
		_content_vbox.add_child(card)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var nlbl: Label = Label.new()
		nlbl.text = "%s%s" % [str(tcfg.get("name", "")), "" if unlocked else " 🔒（尚未解鎖）"]
		nlbl.add_theme_font_size_override("font_size", 18)
		nlbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.74) if unlocked else Color(0.62, 0.58, 0.52))
		info.add_child(nlbl)

		var dlbl: Label = Label.new()
		dlbl.text = str(tcfg.get("desc", ""))
		dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dlbl.add_theme_font_size_override("font_size", 15)
		dlbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.70))
		info.add_child(dlbl)

		var sel_btn: Button = Button.new()
		sel_btn.custom_minimum_size = Vector2(126.0, 48.0)
		sel_btn.text = "已選擇" if is_sel else ("選擇區域" if unlocked else "未解鎖")
		sel_btn.disabled = (not unlocked) or is_sel
		var cap_t: int = tnum
		sel_btn.pressed.connect(func():
			meta.selected_tier = cap_t
			show_hub(meta, consist, _pending_seed)
		)
		row.add_child(sel_btn)

	# Bottom action bar
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(actions)

	var bp_btn: Button = Button.new()
	bp_btn.text = "🚂 蒸氣列車設計圖 [T]"
	bp_btn.custom_minimum_size = Vector2(0.0, 52.0)
	bp_btn.pressed.connect(func():
		close()
		open_train_blueprint_requested.emit()
	)
	actions.add_child(bp_btn)

	var save_btn: Button = Button.new()
	save_btn.text = "💾 存檔"
	save_btn.custom_minimum_size = Vector2(0.0, 52.0)
	save_btn.pressed.connect(func(): save_profile_requested.emit())
	actions.add_child(save_btn)

	var reset_btn: Button = Button.new()
	reset_btn.text = "🔄 重置存檔"
	reset_btn.custom_minimum_size = Vector2(0.0, 52.0)
	reset_btn.pressed.connect(func(): reset_profile_requested.emit())
	actions.add_child(reset_btn)

	var go_btn: Button = Button.new()
	go_btn.text = "🚀 發車進站・開始出擊"
	go_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_btn.custom_minimum_size = Vector2(0.0, 54.0)
	_style_cta(go_btn)
	go_btn.pressed.connect(func():
		var next_seed: int = int(Time.get_ticks_usec() % 899999) + 100000
		close()
		deploy_run_requested.emit(_selected_tier, next_seed)
	)
	actions.add_child(go_btn)

	var resume_btn: Button = Button.new()
	resume_btn.text = "返回目前戰局 [H]"
	resume_btn.custom_minimum_size = Vector2(0.0, 52.0)
	resume_btn.pressed.connect(func(): close())
	actions.add_child(resume_btn)


func show_settlement(settlement: Dictionary) -> void:
	_clear_content()
	_is_open = true
	_backdrop.visible = true

	var victory: bool = bool(settlement.get("victory", false))
	var title: Label = Label.new()
	title.text = "🏆 撤離成功！裝甲列車安全離站" if victory else "💀 單局撤離失敗 — %s" % str(settlement.get("fail_reason", "行動中止"))
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.54, 0.98, 0.68) if victory else Color(1.0, 0.46, 0.38))
	_content_vbox.add_child(title)

	var secured: Dictionary = settlement.get("secured_resources", {}) as Dictionary
	var lost: Dictionary = settlement.get("lost_resources", {}) as Dictionary
	var kills: int = int(settlement.get("kills", 0))
	var mission_name: String = str(settlement.get("mission_title", ""))
	var mission_done: bool = bool(settlement.get("mission_complete", false))

	var body: Label = Label.new()
	body.text = (
		"🎯 單局主線【%s】：%s\n"
		+ "🧟 本局擊殺喪屍：%d 隻\n"
		+ "📦 安全入庫總資源：廢金屬 +%d ｜ 機械零件 +%d ｜ 高能燃料 +%d ｜ 醫療補給 +%d\n"
		+ "🎒 遺失隨身背包物資：廢金屬 %d ｜ 機械零件 %d ｜ 高能燃料 %d ｜ 醫療補給 %d"
	) % [
		mission_name,
		"已完成（含主線獎勵）" if mission_done else "未完成",
		kills,
		int(secured.get("scrap", 0)),
		int(secured.get("parts", 0)),
		int(secured.get("fuel", 0)),
		int(secured.get("supplies", 0)),
		int(lost.get("scrap", 0)),
		int(lost.get("parts", 0)),
		int(lost.get("fuel", 0)),
		int(lost.get("supplies", 0)),
	]
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	_content_vbox.add_child(body)

	var rescued_raw: Variant = settlement.get("rescued_crew", {})
	if victory and rescued_raw is Dictionary and not (rescued_raw as Dictionary).is_empty():
		var rc: Dictionary = rescued_raw as Dictionary
		var crew_lbl: Label = Label.new()
		crew_lbl.text = "✨ 新乘員永久加入名冊：%s（%s）— %s" % [
			str(rc.get("name", "")),
			str(rc.get("role", "")),
			str(rc.get("trait", "")),
		]
		crew_lbl.add_theme_font_size_override("font_size", 18)
		crew_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
		_content_vbox.add_child(crew_lbl)

	var note: Label = Label.new()
	note.text = "（已自動將入庫資源與進度儲存至本機存檔 user://mygame_save.json）"
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.76, 0.72, 0.64))
	_content_vbox.add_child(note)

	var hub_btn: Button = Button.new()
	hub_btn.text = "🚂 返回列車整備基地（改造列車 / 選擇下一局區域）"
	hub_btn.custom_minimum_size = Vector2(0.0, 56.0)
	_style_cta(hub_btn)
	hub_btn.pressed.connect(func():
		close()
		return_to_hub_requested.emit()
	)
	_content_vbox.add_child(hub_btn)
