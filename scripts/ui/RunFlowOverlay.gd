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


func _build_shell() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "RunFlowBackdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = TacticalTheme.BG_BACKDROP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.theme = TacticalTheme.build_theme(15)
	add_child(_backdrop)

	var frame: PanelContainer = PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -470.0
	frame.offset_top = -340.0
	frame.offset_right = 470.0
	frame.offset_bottom = 340.0
	frame.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_PANEL_DEEP, TacticalTheme.ACCENT_CYAN, 3, 22, 18))
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

	_content_vbox.add_child(TacticalTheme.make_section_header("CMD-HUB", "裝甲列車指揮終端 // SECTOR DEPLOYMENT", TacticalTheme.ACCENT_CYAN, 20))

	var wh: Dictionary = meta.warehouse
	var stats: Dictionary = consist.compute_stats()
	var summary_card := PanelContainer.new()
	summary_card.add_theme_stylebox_override("panel", TacticalTheme.make_panel_style(TacticalTheme.BG_CARD, TacticalTheme.BORDER_STEEL, 1, 14, 10, 1))
	_content_vbox.add_child(summary_card)

	var summary: Label = Label.new()
	summary.text = "WAREHOUSE  //  SCRAP %d  |  PARTS %d  |  FUEL %d  |  SUPPLIES %d\nRECORD     //  EXTRACTED %d  |  FAILED %d  |  KILLS %d  |  TRAIN %d/%d CARS (TURRETS %d)" % [
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
	summary.add_theme_font_size_override("font_size", 14)
	summary.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
	summary_card.add_child(summary)

	var tier_hdr: Label = Label.new()
	tier_hdr.text = "// SELECT TARGET SECTOR TIER (選擇區域威脅等級)"
	tier_hdr.add_theme_font_size_override("font_size", 13)
	tier_hdr.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
	_content_vbox.add_child(tier_hdr)

	for tcfg: Dictionary in MetaProgressionManager.SECTOR_TIERS:
		var tnum: int = int(tcfg.get("tier", 1))
		var unlocked: bool = meta.is_tier_unlocked(tnum, consist)
		var is_sel: bool = (_selected_tier == tnum)

		var card: PanelContainer = PanelContainer.new()
		if is_sel:
			card.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_CARD_ACTIVE, TacticalTheme.ACCENT_AMBER, 4, 14, 10))
		else:
			card.add_theme_stylebox_override("panel", TacticalTheme.make_panel_style(TacticalTheme.BG_CARD, TacticalTheme.BORDER_STEEL if unlocked else Color(0.16, 0.19, 0.24, 0.65), 1, 14, 10, 1))
		_content_vbox.add_child(card)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var nlbl: Label = Label.new()
		nlbl.text = "%s%s" % [str(tcfg.get("name", "")), "" if unlocked else "  [LOCKED]"]
		nlbl.add_theme_font_size_override("font_size", 16)
		nlbl.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER if is_sel else (TacticalTheme.TEXT_PRIMARY if unlocked else TacticalTheme.TEXT_MUTED))
		info.add_child(nlbl)

		var dlbl: Label = Label.new()
		dlbl.text = str(tcfg.get("desc", ""))
		dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dlbl.add_theme_font_size_override("font_size", 13)
		dlbl.add_theme_color_override("font_color", TacticalTheme.TEXT_SECONDARY)
		info.add_child(dlbl)

		var sel_btn: Button = Button.new()
		sel_btn.custom_minimum_size = Vector2(128.0, 44.0)
		sel_btn.text = "SELECTED" if is_sel else ("SELECT" if unlocked else "LOCKED")
		sel_btn.disabled = (not unlocked) or is_sel
		var cap_t: int = tnum
		sel_btn.pressed.connect(func():
			meta.selected_tier = cap_t
			show_hub(meta, consist, _pending_seed)
		)
		row.add_child(sel_btn)

	_content_vbox.add_child(HSeparator.new())

	# Bottom action bar
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_content_vbox.add_child(actions)

	var bp_btn: Button = Button.new()
	bp_btn.text = "[T] 列車改裝藍圖"
	bp_btn.custom_minimum_size = Vector2(0.0, 46.0)
	bp_btn.pressed.connect(func():
		close()
		open_train_blueprint_requested.emit()
	)
	actions.add_child(bp_btn)

	var save_btn: Button = Button.new()
	save_btn.text = "SAVE // 存檔"
	save_btn.custom_minimum_size = Vector2(0.0, 46.0)
	save_btn.pressed.connect(func(): save_profile_requested.emit())
	actions.add_child(save_btn)

	var reset_btn: Button = Button.new()
	reset_btn.text = "RESET // 重置"
	reset_btn.custom_minimum_size = Vector2(0.0, 46.0)
	reset_btn.pressed.connect(func(): reset_profile_requested.emit())
	actions.add_child(reset_btn)

	var go_btn: Button = Button.new()
	go_btn.text = "DEPLOY // 發車進站出擊"
	go_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_btn.custom_minimum_size = Vector2(0.0, 48.0)
	TacticalTheme.style_cta_button(go_btn, TacticalTheme.ACCENT_AMBER)
	go_btn.pressed.connect(func():
		var next_seed: int = int(Time.get_ticks_usec() % 899999) + 100000
		close()
		deploy_run_requested.emit(_selected_tier, next_seed)
	)
	actions.add_child(go_btn)

	var resume_btn: Button = Button.new()
	resume_btn.text = "RESUME [H]"
	resume_btn.custom_minimum_size = Vector2(0.0, 46.0)
	resume_btn.pressed.connect(func(): close())
	actions.add_child(resume_btn)


func show_settlement(settlement: Dictionary) -> void:
	_clear_content()
	_is_open = true
	_backdrop.visible = true

	var victory: bool = bool(settlement.get("victory", false))
	var tag: String = "EXTRACTED" if victory else "MIA / ABORTED"
	var accent: Color = TacticalTheme.ACCENT_EMERALD if victory else TacticalTheme.ACCENT_CRIMSON
	var title_txt: String = "撤離成功 // 裝甲列車安全離站" if victory else "撤離失敗 // %s" % str(settlement.get("fail_reason", "行動中止"))
	_content_vbox.add_child(TacticalTheme.make_section_header(tag, title_txt, accent, 21))

	var secured: Dictionary = settlement.get("secured_resources", {}) as Dictionary
	var lost: Dictionary = settlement.get("lost_resources", {}) as Dictionary
	var kills: int = int(settlement.get("kills", 0))
	var mission_name: String = str(settlement.get("mission_title", ""))
	var mission_done: bool = bool(settlement.get("mission_complete", false))

	var report_card := PanelContainer.new()
	report_card.add_theme_stylebox_override("panel", TacticalTheme.make_panel_style(TacticalTheme.BG_CARD, TacticalTheme.BORDER_STEEL, 1, 16, 14, 1))
	_content_vbox.add_child(report_card)

	var body: Label = Label.new()
	body.text = (
		"OBJECTIVE [%s] : %s\n"
		+ "HOSTILES ELIMINATED : %d\n"
		+ "SECURED STASH       : SCRAP +%d  |  PARTS +%d  |  FUEL +%d  |  SUPPLIES +%d\n"
		+ "LOST BACKPACK       : SCRAP %d  |  PARTS %d  |  FUEL %d  |  SUPPLIES %d"
	) % [
		mission_name,
		"COMPLETED (+BONUS)" if mission_done else "INCOMPLETE",
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
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", TacticalTheme.TEXT_PRIMARY)
	report_card.add_child(body)

	var rescued_raw: Variant = settlement.get("rescued_crew", {})
	if victory and rescued_raw is Dictionary and not (rescued_raw as Dictionary).is_empty():
		var rc: Dictionary = rescued_raw as Dictionary
		var crew_card := PanelContainer.new()
		crew_card.add_theme_stylebox_override("panel", TacticalTheme.make_accent_card_style(TacticalTheme.BG_CARD_ACTIVE, TacticalTheme.ACCENT_AMBER, 3, 14, 10))
		_content_vbox.add_child(crew_card)

		var crew_lbl: Label = Label.new()
		crew_lbl.text = "NEW OPERATOR RECRUITED // %s (%s) — %s" % [
			str(rc.get("name", "")),
			str(rc.get("role", "")),
			str(rc.get("trait", "")),
		]
		crew_lbl.add_theme_font_size_override("font_size", 15)
		crew_lbl.add_theme_color_override("font_color", TacticalTheme.ACCENT_AMBER)
		crew_card.add_child(crew_lbl)

	var note: Label = Label.new()
	note.text = "SYS // PROFILE AUTO-SAVED TO user://mygame_save.json"
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", TacticalTheme.TEXT_MUTED)
	_content_vbox.add_child(note)

	var hub_btn: Button = Button.new()
	hub_btn.text = "RETURN TO COMMAND HUB // 返回整備基地"
	hub_btn.custom_minimum_size = Vector2(0.0, 50.0)
	TacticalTheme.style_cta_button(hub_btn, TacticalTheme.ACCENT_CYAN)
	hub_btn.pressed.connect(func():
		close()
		return_to_hub_requested.emit()
	)
	_content_vbox.add_child(hub_btn)
