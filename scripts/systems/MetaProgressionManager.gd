class_name MetaProgressionManager
extends RefCounted

const DEFAULT_SAVE_PATH: String = "user://mygame_save.json"

const SECTOR_TIERS: Array[Dictionary] = [
	{
		"tier": 1,
		"name": "Tier 1 — 外環廢棄工業區",
		"duration_sec": 360.0,
		"difficulty_mult": 1.0,
		"reward_mult": 1.0,
		"desc": "標準威脅，適合搜刮基礎廢金屬與機械零件、熟悉火車防線。",
	},
	{
		"tier": 2,
		"name": "Tier 2 — 紅月封鎖商業帶",
		"duration_sec": 420.0,
		"difficulty_mult": 1.35,
		"reward_mult": 1.5,
		"desc": "疾行者與重甲喪屍頻率提高，任務獎勵 1.5 倍（需 1 次撤離勝利或鍋爐 Lv.2 解鎖）。",
	},
	{
		"tier": 3,
		"name": "Tier 3 — 核心感染隔離區",
		"duration_sec": 480.0,
		"difficulty_mult": 1.75,
		"reward_mult": 2.2,
		"desc": "高密度紅月屍潮與大量毒霧自爆體，任務獎勵 2.2 倍（需 3 次撤離勝利或鍋爐 Lv.3 解鎖）。",
	},
]

var warehouse: Dictionary = {"scrap": 8, "parts": 6, "fuel": 4, "supplies": 4}
var completed_runs: int = 0
var failed_runs: int = 0
var total_kills: int = 0
var selected_tier: int = 1
var highest_tier_unlocked: int = 1
var recruited_crew: Array[Dictionary] = []
var train_consist_snapshot: Dictionary = {}


func reset_profile() -> void:
	warehouse = {"scrap": 8, "parts": 6, "fuel": 4, "supplies": 4}
	completed_runs = 0
	failed_runs = 0
	total_kills = 0
	selected_tier = 1
	highest_tier_unlocked = 1
	recruited_crew.clear()
	train_consist_snapshot.clear()


func get_tier_config(tier_num: int) -> Dictionary:
	var idx: int = clampi(tier_num - 1, 0, SECTOR_TIERS.size() - 1)
	return SECTOR_TIERS[idx]


func is_tier_unlocked(tier_num: int, consist: TrainConsistManager = null) -> bool:
	if tier_num <= 1:
		return true
	var boiler_lv: int = int(consist.locomotive.get("boiler_level", 1)) if consist != null else 1
	if tier_num == 2:
		return highest_tier_unlocked >= 2 or completed_runs >= 1 or boiler_lv >= 2
	if tier_num == 3:
		return highest_tier_unlocked >= 3 or completed_runs >= 3 or boiler_lv >= 3
	return false


func sync_crew_into_consist(consist: TrainConsistManager) -> void:
	if consist == null:
		return
	var existing: Array[String] = []
	for c: Dictionary in consist.crew_roster:
		existing.append(str(c.get("id", "")))
	for rc: Dictionary in recruited_crew:
		var rid: String = str(rc.get("id", ""))
		if not rid.is_empty() and not existing.has(rid):
			consist.crew_roster.append(rc.duplicate(true))
			existing.append(rid)


func apply_run_settlement(settlement: Dictionary, consist: TrainConsistManager) -> Dictionary:
	var victory: bool = bool(settlement.get("victory", false))
	var secured: Dictionary = settlement.get("secured_resources", {}) as Dictionary
	var kills: int = int(settlement.get("kills", 0))
	total_kills += kills

	for k: String in ["scrap", "parts", "fuel", "supplies"]:
		warehouse[k] = int(warehouse.get(k, 0)) + int(secured.get(k, 0))

	if victory:
		completed_runs += 1
		var rescued_raw: Variant = settlement.get("rescued_crew", {})
		if rescued_raw is Dictionary and not (rescued_raw as Dictionary).is_empty():
			var rc: Dictionary = (rescued_raw as Dictionary).duplicate(true)
			var rid: String = str(rc.get("id", ""))
			var already: bool = false
			for e: Dictionary in recruited_crew:
				if str(e.get("id", "")) == rid:
					already = true
					break
			if not already and not rid.is_empty():
				recruited_crew.append(rc)
				sync_crew_into_consist(consist)
	else:
		failed_runs += 1

	var boiler_lv: int = int(consist.locomotive.get("boiler_level", 1)) if consist != null else 1
	if completed_runs >= 1 or boiler_lv >= 2:
		highest_tier_unlocked = maxi(highest_tier_unlocked, 2)
	if completed_runs >= 3 or boiler_lv >= 3:
		highest_tier_unlocked = maxi(highest_tier_unlocked, 3)

	if consist != null:
		train_consist_snapshot = consist.to_dict()

	return {
		"warehouse": warehouse.duplicate(),
		"completed_runs": completed_runs,
		"highest_tier_unlocked": highest_tier_unlocked,
	}


func to_dict(consist: TrainConsistManager = null) -> Dictionary:
	if consist != null:
		train_consist_snapshot = consist.to_dict()
	return {
		"version": 1,
		"warehouse": warehouse.duplicate(),
		"completed_runs": completed_runs,
		"failed_runs": failed_runs,
		"total_kills": total_kills,
		"selected_tier": selected_tier,
		"highest_tier_unlocked": highest_tier_unlocked,
		"recruited_crew": recruited_crew.duplicate(true),
		"train_consist": train_consist_snapshot.duplicate(true),
	}


func from_dict(data: Dictionary, consist: TrainConsistManager = null) -> bool:
	if not data.has("warehouse"):
		return false
	var wh_raw: Variant = data.get("warehouse", {})
	if wh_raw is Dictionary:
		for k: String in ["scrap", "parts", "fuel", "supplies"]:
			warehouse[k] = int((wh_raw as Dictionary).get(k, 0))
	completed_runs = int(data.get("completed_runs", 0))
	failed_runs = int(data.get("failed_runs", 0))
	total_kills = int(data.get("total_kills", 0))
	selected_tier = clampi(int(data.get("selected_tier", 1)), 1, SECTOR_TIERS.size())
	highest_tier_unlocked = clampi(int(data.get("highest_tier_unlocked", 1)), 1, SECTOR_TIERS.size())

	recruited_crew.clear()
	var rc_raw: Variant = data.get("recruited_crew", [])
	if rc_raw is Array:
		for item in (rc_raw as Array):
			if item is Dictionary:
				recruited_crew.append((item as Dictionary).duplicate(true))

	var tc_raw: Variant = data.get("train_consist", {})
	if tc_raw is Dictionary and not (tc_raw as Dictionary).is_empty():
		train_consist_snapshot = (tc_raw as Dictionary).duplicate(true)
		if consist != null:
			sync_crew_into_consist(consist)
			consist.from_dict(train_consist_snapshot)
	elif consist != null:
		sync_crew_into_consist(consist)
	return true


func save_to_file(consist: TrainConsistManager = null, path: String = DEFAULT_SAVE_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var payload: String = JSON.stringify(to_dict(consist), "\t")
	file.store_string(payload)
	file.close()
	return true


func load_from_file(consist: TrainConsistManager = null, path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var raw_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		return from_dict(parsed as Dictionary, consist)
	return false
