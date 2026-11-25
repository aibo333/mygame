class_name TrainConsistManager
extends RefCounted

signal consist_changed()

const MAX_BOILER_LEVEL: int = 4
const MAX_ARMOR_LEVEL: int = 4
const MAX_HEADLAMP_LEVEL: int = 3
const BASE_BACKPACK_CAPACITY: int = 8
const CELLS_PER_CARRIAGE: int = 2

const ROLE_LABELS: Dictionary = {
	"gunner": "砲手",
	"mechanic": "輪機師",
	"medic": "軍醫",
	"scout": "偵察手",
	"quartermaster": "軍需官",
	"any": "全職能",
}

const BOILER_TIERS: Array[Dictionary] = [
	{"level": 1, "max_carriages": 3, "power": 6, "departure_sec": 45.0, "cost": {}},
	{"level": 2, "max_carriages": 4, "power": 9, "departure_sec": 38.0, "cost": {"scrap": 4, "parts": 3, "fuel": 2}},
	{"level": 3, "max_carriages": 5, "power": 12, "departure_sec": 31.0, "cost": {"scrap": 7, "parts": 5, "fuel": 4}},
	{"level": 4, "max_carriages": 6, "power": 16, "departure_sec": 24.0, "cost": {"scrap": 10, "parts": 8, "fuel": 6}},
]

const ARMOR_TIERS: Array[Dictionary] = [
	{"level": 1, "hull_hp": 660.0, "damage_reduction": 0.0, "cost": {}},
	{"level": 2, "hull_hp": 1010.0, "damage_reduction": 0.10, "cost": {"scrap": 5, "parts": 2}},
	{"level": 3, "hull_hp": 1410.0, "damage_reduction": 0.20, "cost": {"scrap": 8, "parts": 4}},
	{"level": 4, "hull_hp": 1860.0, "damage_reduction": 0.30, "cost": {"scrap": 12, "parts": 6, "fuel": 2}},
]

const HEADLAMP_TIERS: Array[Dictionary] = [
	{"level": 1, "light_range": 13.0, "energy": 3.4, "cost": {}},
	{"level": 2, "light_range": 18.0, "energy": 4.2, "cost": {"scrap": 2, "parts": 3}},
	{"level": 3, "light_range": 24.0, "energy": 5.2, "cost": {"scrap": 4, "parts": 5, "fuel": 2}},
]

const EXPAND_CARRIAGE_COST: Dictionary = {"scrap": 4, "parts": 2}

# Roof hardpoint modules (Upper deck layer, like sails/deck guns in Uncharted Waters)
const ROOF_ORDER_KEYS: Array[String] = ["none", "turret", "radar", "tesla", "shield"]

const ROOF_CATALOG: Dictionary = {
	"none": {
		"name": "空車頂甲板",
		"short": "空車頂",
		"icon": "⬜",
		"power": 0,
		"hull_bonus": 0.0,
		"accent": Color(0.58, 0.64, 0.72),
		"desc": "未架設武裝的裝甲車頂，可改裝自動砲塔、雷達、電網或裝甲盾",
		"cost": {},
	},
	"turret": {
		"name": "雙管自動砲塔",
		"short": "自動砲塔",
		"icon": "🔫",
		"power": 2,
		"hull_bonus": 60.0,
		"turret_dps": 28.0,
		"accent": Color(0.96, 0.42, 0.34),
		"desc": "車頂架設自動機槍塔（基礎 28 DPS），同車廂配置砲控室與砲手大幅強化",
		"cost": {"scrap": 3, "parts": 3, "fuel": 1},
	},
	"radar": {
		"name": "旋轉偵察雷達",
		"short": "偵察雷達",
		"icon": "📡",
		"power": 1,
		"hull_bonus": 20.0,
		"radar_bonus": 35.0,
		"accent": Color(0.42, 0.86, 1.0),
		"desc": "擴大街區搜刮點、任務目標與屍潮來襲預警範圍（+35%）",
		"cost": {"scrap": 2, "parts": 3},
	},
	"tesla": {
		"name": "高壓防禦電網",
		"short": "高壓電網",
		"icon": "⚡",
		"power": 1,
		"hull_bonus": 40.0,
		"accent": Color(0.38, 0.94, 1.0),
		"desc": "在車廂外緣張開電弧護欄，減速並電擊靠近月台的屍潮",
		"cost": {"scrap": 2, "parts": 3, "fuel": 2},
	},
	"shield": {
		"name": "重型裝甲頂盾",
		"short": "裝甲頂盾",
		"icon": "🛡",
		"power": 0,
		"hull_bonus": 150.0,
		"accent": Color(0.84, 0.78, 0.56),
		"desc": "不消耗動力，直接為該節車廂加焊重裝甲板（+150 耐久）",
		"cost": {"scrap": 4, "parts": 1},
	},
}

# Interior cabin cell modules (Grid squares inside each carriage, like Uncharted Waters cabins!)
const CELL_ORDER_KEYS: Array[String] = [
	"empty",
	"boarding",
	"cargo",
	"gunnery",
	"medbay",
	"armory",
	"recon",
	"quarters",
	"generator",
]

const CELL_CATALOG: Dictionary = {
	"empty": {
		"name": "空艙格",
		"short": "空艙",
		"icon": "＋",
		"power": 0,
		"hull_bonus": 0.0,
		"best_role": "any",
		"can_assign_crew": false,
		"accent": Color(0.56, 0.62, 0.70),
		"desc": "未改裝的車廂內部空間，可自由改建為各類功能艙室",
		"cost": {},
	},
	"boarding": {
		"name": "指揮登車室",
		"short": "登車室",
		"icon": "🚪",
		"power": 1,
		"hull_bonus": 100.0,
		"best_role": "any",
		"can_assign_crew": true,
		"accent": Color(0.32, 0.92, 0.78),
		"desc": "核心登車門與發車控制台（全列車至少保留 1 格），可派駐指揮成員",
		"cost": {"scrap": 2, "parts": 2},
	},
	"cargo": {
		"name": "貨運暫存倉",
		"short": "貨運倉",
		"icon": "📦",
		"power": 1,
		"hull_bonus": 80.0,
		"backpack_bonus": 4,
		"best_role": "quartermaster",
		"can_assign_crew": true,
		"accent": Color(0.98, 0.78, 0.28),
		"desc": "提供卸貨點並擴充隨身背包 +4（至少保留 1 格），派駐軍需官額外放大容量",
		"cost": {"scrap": 2, "parts": 1},
	},
	"gunnery": {
		"name": "砲控彈藥室",
		"short": "砲控室",
		"icon": "🎯",
		"power": 1,
		"hull_bonus": 60.0,
		"turret_dps_bonus": 12.0,
		"best_role": "gunner",
		"can_assign_crew": true,
		"accent": Color(0.96, 0.44, 0.34),
		"desc": "為全車自動砲塔提供火控與供彈（+12 DPS），派駐砲手發揮 150% 專精",
		"cost": {"scrap": 3, "parts": 2, "fuel": 1},
	},
	"medbay": {
		"name": "戰地醫務室",
		"short": "醫務室",
		"icon": "✚",
		"power": 2,
		"hull_bonus": 50.0,
		"heal_rate": 18.0,
		"best_role": "medic",
		"can_assign_crew": true,
		"accent": Color(0.42, 0.96, 0.58),
		"desc": "返車快速治療與補給醫療包（+18 HP/s），派駐軍醫大幅提升治療效率",
		"cost": {"scrap": 2, "parts": 1, "supplies": 2},
	},
	"armory": {
		"name": "機械工坊室",
		"short": "工坊室",
		"icon": "🔧",
		"power": 2,
		"hull_bonus": 80.0,
		"repair_rate": 6.0,
		"best_role": "mechanic",
		"can_assign_crew": true,
		"accent": Color(0.96, 0.64, 0.24),
		"desc": "彈藥整備與自動修復車體裝甲（+6 HP/s），派駐輪機師加速搶修",
		"cost": {"scrap": 3, "parts": 3},
	},
	"recon": {
		"name": "無線電偵察室",
		"short": "偵察室",
		"icon": "📻",
		"power": 1,
		"hull_bonus": 40.0,
		"radar_bonus": 40.0,
		"best_role": "scout",
		"can_assign_crew": true,
		"accent": Color(0.42, 0.84, 1.0),
		"desc": "解譯街區求救訊號與資源分布（+40% 偵測），派駐偵察手發揮專精",
		"cost": {"scrap": 2, "parts": 3},
	},
	"quarters": {
		"name": "乘員宿舍艙",
		"short": "宿舍艙",
		"icon": "🛏",
		"power": 0,
		"hull_bonus": 40.0,
		"best_role": "any",
		"can_assign_crew": true,
		"accent": Color(0.84, 0.72, 1.0),
		"desc": "不耗動力，提供任意乘員駐守床位並穩定全列車士氣",
		"cost": {"scrap": 2, "supplies": 1},
	},
	"generator": {
		"name": "輔助發電室",
		"short": "發電室",
		"icon": "🔋",
		"power": -4,
		"hull_bonus": 60.0,
		"best_role": "mechanic",
		"can_assign_crew": true,
		"accent": Color(0.36, 0.92, 1.0),
		"desc": "額外供給 +4 全列車動力額度（支撐更多砲塔與艙室），派駐輪機師再加動力",
		"cost": {"scrap": 3, "parts": 3, "fuel": 2},
	},
}

# Legacy high-level carriage presets (maps cleanly onto roof + 2 cells for quick preset refit & backward compatibility)
const CARRIAGE_ORDER_KEYS: Array[String] = [
	"boarding",
	"cargo",
	"turret",
	"medbay",
	"armory",
	"recon",
	"quarters",
	"generator",
	"flatbed",
]

const CARRIAGE_CATALOG: Dictionary = {
	"boarding": {"name": "指揮登車車廂", "short": "登車", "roof": "none", "cell0": "boarding", "cell1": "quarters", "best_role": "any", "accent": Color(0.32, 0.90, 0.78), "cost": {"scrap": 3, "parts": 2}},
	"cargo": {"name": "貨運暫存車廂", "short": "貨倉", "roof": "none", "cell0": "cargo", "cell1": "empty", "best_role": "quartermaster", "accent": Color(0.98, 0.78, 0.28), "cost": {"scrap": 3, "parts": 2}},
	"turret": {"name": "裝甲砲塔車廂", "short": "砲塔", "roof": "turret", "cell0": "gunnery", "cell1": "empty", "best_role": "gunner", "accent": Color(0.96, 0.42, 0.34), "cost": {"scrap": 4, "parts": 4, "fuel": 1}},
	"medbay": {"name": "戰地醫療車廂", "short": "醫療", "roof": "none", "cell0": "medbay", "cell1": "empty", "best_role": "medic", "accent": Color(0.42, 0.96, 0.58), "cost": {"scrap": 2, "parts": 2, "supplies": 3}},
	"armory": {"name": "工坊軍械車廂", "short": "工坊", "roof": "none", "cell0": "armory", "cell1": "empty", "best_role": "mechanic", "accent": Color(0.96, 0.64, 0.24), "cost": {"scrap": 4, "parts": 4}},
	"recon": {"name": "瞭望通訊車廂", "short": "偵察", "roof": "radar", "cell0": "recon", "cell1": "empty", "best_role": "scout", "accent": Color(0.42, 0.84, 1.0), "cost": {"scrap": 2, "parts": 4, "fuel": 1}},
	"quarters": {"name": "乘員宿舍車廂", "short": "宿舍", "roof": "none", "cell0": "quarters", "cell1": "quarters", "best_role": "any", "accent": Color(0.84, 0.72, 1.0), "cost": {"scrap": 3, "supplies": 2}},
	"generator": {"name": "輔助動力電網車廂", "short": "動力", "roof": "tesla", "cell0": "generator", "cell1": "empty", "best_role": "mechanic", "accent": Color(0.36, 0.92, 1.0), "cost": {"scrap": 3, "parts": 4, "fuel": 3}},
	"flatbed": {"name": "空底盤車廂", "short": "空車", "roof": "none", "cell0": "empty", "cell1": "empty", "best_role": "any", "accent": Color(0.62, 0.66, 0.72), "cost": {}},
}

var locomotive: Dictionary = {}
var carriages: Array[Dictionary] = []
var crew_roster: Array[Dictionary] = []
var _next_carriage_uid: int = 1


func _init() -> void:
	reset_to_default()


func reset_to_default() -> void:
	_next_carriage_uid = 1
	locomotive = {
		"boiler_level": 1,
		"armor_level": 1,
		"headlamp_level": 1,
		"crew_slots": [""],
	}
	carriages = [
		_make_carriage("boarding"),
		_make_carriage("cargo"),
		_make_carriage("turret"),
	]
	crew_roster = _build_default_crew_roster()
	consist_changed.emit()


func _make_carriage(preset_type: String) -> Dictionary:
	var preset: Dictionary = CARRIAGE_CATALOG.get(preset_type, CARRIAGE_CATALOG["flatbed"]) as Dictionary
	var roof_mod: String = str(preset.get("roof", "none"))
	var c0: String = str(preset.get("cell0", "empty"))
	var c1: String = str(preset.get("cell1", "empty"))
	var cells: Array[Dictionary] = [
		{"module": c0, "crew_id": ""},
		{"module": c1, "crew_id": ""},
	]
	var entry: Dictionary = {
		"uid": "car_%02d" % _next_carriage_uid,
		"type": preset_type,
		"roof": roof_mod,
		"cells": cells,
		"crew_slots": ["", ""],
	}
	_next_carriage_uid += 1
	return entry


func _sync_carriage_derived_fields(car: Dictionary) -> void:
	var cells: Array = car.get("cells", []) as Array
	var slots: Array[String] = []
	for cell_raw in cells:
		var cell: Dictionary = cell_raw as Dictionary
		slots.append(str(cell.get("crew_id", "")))
	car["crew_slots"] = slots

	# Derive representative visual hull type from cells + roof
	var roof_mod: String = str(car.get("roof", "none"))
	var mods: Array[String] = []
	for cell_raw in cells:
		var m: String = str((cell_raw as Dictionary).get("module", "empty"))
		if m != "empty":
			mods.append(m)

	if mods.has("boarding"):
		car["type"] = "boarding"
	elif mods.has("cargo"):
		car["type"] = "cargo"
	elif roof_mod == "turret" or mods.has("gunnery"):
		car["type"] = "turret"
	elif mods.has("medbay"):
		car["type"] = "medbay"
	elif mods.has("generator") or roof_mod == "tesla":
		car["type"] = "generator"
	elif mods.has("armory"):
		car["type"] = "armory"
	elif mods.has("recon") or roof_mod == "radar":
		car["type"] = "recon"
	elif mods.has("quarters"):
		car["type"] = "quarters"
	else:
		car["type"] = "flatbed"


func _build_default_crew_roster() -> Array[Dictionary]:
	return [
		{
			"id": "gunner_kuro",
			"name": "黑鐵 隆",
			"short_name": "黑鐵",
			"role": "gunner",
			"trait": "重機槍專精（砲塔火力 +8）",
			"bonus_power": 0,
			"bonus_backpack": 0,
			"bonus_dps": 8.0,
		},
		{
			"id": "mech_hana",
			"name": "花梨 技師",
			"short_name": "花梨",
			"role": "mechanic",
			"trait": "急速暖爐（動力 +1 / 發車 -4s）",
			"bonus_power": 1,
			"bonus_backpack": 0,
			"bonus_dps": 0.0,
		},
		{
			"id": "medic_saya",
			"name": "紗耶 軍醫",
			"short_name": "紗耶",
			"role": "medic",
			"trait": "戰地縫合（治療效率 +40%）",
			"bonus_power": 0,
			"bonus_backpack": 0,
			"bonus_dps": 0.0,
		},
		{
			"id": "scout_ren",
			"name": "蓮 偵察員",
			"short_name": "蓮",
			"role": "scout",
			"trait": "鷹眼雷達（全圖偵測 +25%）",
			"bonus_power": 0,
			"bonus_backpack": 0,
			"bonus_dps": 0.0,
		},
		{
			"id": "qm_goro",
			"name": "五郎 軍需官",
			"short_name": "五郎",
			"role": "quartermaster",
			"trait": "緊密裝箱（貨運倉背包額外 +3）",
			"bonus_power": 0,
			"bonus_backpack": 3,
			"bonus_dps": 0.0,
		},
		{
			"id": "gunner_mika",
			"name": "美佳 砲手",
			"short_name": "美佳",
			"role": "gunner",
			"trait": "破甲點射（砲塔火力 +6）",
			"bonus_power": 0,
			"bonus_backpack": 0,
			"bonus_dps": 6.0,
		},
	]


func get_carriage_spec(ctype: String) -> Dictionary:
	return CARRIAGE_CATALOG.get(ctype, CARRIAGE_CATALOG["flatbed"]) as Dictionary


func get_cell_spec(module_type: String) -> Dictionary:
	return CELL_CATALOG.get(module_type, CELL_CATALOG["empty"]) as Dictionary


func get_roof_spec(roof_type: String) -> Dictionary:
	return ROOF_CATALOG.get(roof_type, ROOF_CATALOG["none"]) as Dictionary


func get_crew_by_id(crew_id: String) -> Dictionary:
	if crew_id.is_empty():
		return {}
	for c: Dictionary in crew_roster:
		if str(c.get("id", "")) == crew_id:
			return c
	return {}


func get_role_label(role_key: String) -> String:
	return str(ROLE_LABELS.get(role_key, role_key))


func get_crew_affinity(crew_id: String, target_role: String) -> float:
	var c: Dictionary = get_crew_by_id(crew_id)
	if c.is_empty():
		return 0.0
	if target_role == "any":
		return 1.25
	var role: String = str(c.get("role", ""))
	if role == target_role:
		return 1.50
	return 0.60


func get_crew_assignment_label(crew_id: String) -> String:
	var loco_slots: Array = locomotive.get("crew_slots", []) as Array
	for s in loco_slots:
		if str(s) == crew_id:
			return "駐守：火車頭駕駛艙"
	for idx in range(carriages.size()):
		var car: Dictionary = carriages[idx]
		var cells: Array = car.get("cells", []) as Array
		for ci in range(cells.size()):
			var cell: Dictionary = cells[ci] as Dictionary
			if str(cell.get("crew_id", "")) == crew_id:
				var cspec: Dictionary = get_cell_spec(str(cell.get("module", "empty")))
				return "駐守：#%d車 格%d【%s】" % [idx + 1, ci + 1, str(cspec.get("short", "艙室"))]
	return "待命（未配置）"


func get_locomotive_upgrade_cost(part: String) -> Dictionary:
	match part:
		"boiler":
			var lv: int = int(locomotive.get("boiler_level", 1))
			if lv >= MAX_BOILER_LEVEL:
				return {}
			return (BOILER_TIERS[lv].get("cost", {}) as Dictionary).duplicate()
		"armor":
			var lv: int = int(locomotive.get("armor_level", 1))
			if lv >= MAX_ARMOR_LEVEL:
				return {}
			return (ARMOR_TIERS[lv].get("cost", {}) as Dictionary).duplicate()
		"headlamp":
			var lv: int = int(locomotive.get("headlamp_level", 1))
			if lv >= MAX_HEADLAMP_LEVEL:
				return {}
			return (HEADLAMP_TIERS[lv].get("cost", {}) as Dictionary).duplicate()
		_:
			return {}


func can_afford(cost: Dictionary, stash: Dictionary) -> bool:
	for k in cost.keys():
		var req: int = int(cost.get(k, 0))
		if int(stash.get(k, 0)) < req:
			return false
	return true


func _spend_cost(cost: Dictionary, stash: Dictionary) -> void:
	for k in cost.keys():
		var req: int = int(cost.get(k, 0))
		stash[k] = maxi(0, int(stash.get(k, 0)) - req)


func format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "免費"
	var order: Array[String] = ["scrap", "parts", "fuel", "supplies"]
	var names: Dictionary = {"scrap": "金屬", "parts": "零件", "fuel": "燃料", "supplies": "補給"}
	var parts: PackedStringArray = PackedStringArray()
	for k in order:
		var v: int = int(cost.get(k, 0))
		if v > 0:
			parts.append("%s%d" % [str(names[k]), v])
	return " ".join(parts)


func get_max_carriages() -> int:
	var lv: int = clampi(int(locomotive.get("boiler_level", 1)), 1, MAX_BOILER_LEVEL)
	return int(BOILER_TIERS[lv - 1].get("max_carriages", 3))


func compute_stats() -> Dictionary:
	var boiler_lv: int = clampi(int(locomotive.get("boiler_level", 1)), 1, MAX_BOILER_LEVEL)
	var armor_lv: int = clampi(int(locomotive.get("armor_level", 1)), 1, MAX_ARMOR_LEVEL)
	var lamp_lv: int = clampi(int(locomotive.get("headlamp_level", 1)), 1, MAX_HEADLAMP_LEVEL)

	var boiler_tier: Dictionary = BOILER_TIERS[boiler_lv - 1]
	var armor_tier: Dictionary = ARMOR_TIERS[armor_lv - 1]
	var lamp_tier: Dictionary = HEADLAMP_TIERS[lamp_lv - 1]

	var max_carriages: int = int(boiler_tier.get("max_carriages", 3))
	var power_capacity: int = int(boiler_tier.get("power", 6))
	var power_used: int = 0
	var max_hull_hp: float = float(armor_tier.get("hull_hp", 660.0))
	var departure_sec: float = float(boiler_tier.get("departure_sec", 45.0))
	var backpack_cap: int = BASE_BACKPACK_CAPACITY
	var turret_count: int = 0
	var turret_dps: float = 0.0
	var heal_rate: float = 0.0
	var repair_rate: float = 0.0
	var radar_bonus: float = 0.0
	var assigned_crew: int = 0
	var total_crew_slots: int = 1  # Locomotive engineer cab

	var loco_slots: Array = locomotive.get("crew_slots", [""]) as Array
	if loco_slots.size() > 0 and not str(loco_slots[0]).is_empty():
		var cid: String = str(loco_slots[0])
		assigned_crew += 1
		var aff: float = get_crew_affinity(cid, "mechanic")
		var cdata: Dictionary = get_crew_by_id(cid)
		departure_sec = maxf(12.0, departure_sec - 4.0 * aff)
		power_capacity += int(cdata.get("bonus_power", 0))
		repair_rate += 3.0 * aff

	for car: Dictionary in carriages:
		# 1. Roof Hardpoint contribution
		var roof_mod: String = str(car.get("roof", "none"))
		var rspec: Dictionary = get_roof_spec(roof_mod)
		var rpwr: int = int(rspec.get("power", 0))
		if rpwr >= 0:
			power_used += rpwr
		else:
			power_capacity += -rpwr
		max_hull_hp += float(rspec.get("hull_bonus", 0.0))
		if roof_mod == "turret":
			turret_count += 1
			turret_dps += float(rspec.get("turret_dps", 28.0))
		elif roof_mod == "radar":
			radar_bonus += float(rspec.get("radar_bonus", 35.0))

		# 2. Interior Cabin Grid Cells contribution
		var cells: Array = car.get("cells", []) as Array
		for cell_raw in cells:
			var cell: Dictionary = cell_raw as Dictionary
			var mod: String = str(cell.get("module", "empty"))
			var cspec: Dictionary = get_cell_spec(mod)
			var cpwr: int = int(cspec.get("power", 0))
			if cpwr >= 0:
				power_used += cpwr
			else:
				power_capacity += -cpwr
			max_hull_hp += float(cspec.get("hull_bonus", 0.0))

			var can_crew: bool = bool(cspec.get("can_assign_crew", false))
			if can_crew:
				total_crew_slots += 1

			var cid: String = str(cell.get("crew_id", ""))
			var mult: float = 1.0
			var cdata: Dictionary = {}
			var aff: float = 0.0
			if not cid.is_empty():
				assigned_crew += 1
				aff = get_crew_affinity(cid, str(cspec.get("best_role", "any")))
				mult = 1.0 + (aff - 0.5) * 0.5
				cdata = get_crew_by_id(cid)

			match mod:
				"cargo":
					backpack_cap += int(cspec.get("backpack_bonus", 4)) + int(cdata.get("bonus_backpack", 0))
				"gunnery":
					turret_dps += float(cspec.get("turret_dps_bonus", 12.0)) * mult + float(cdata.get("bonus_dps", 0.0)) * aff
				"medbay":
					heal_rate += float(cspec.get("heal_rate", 18.0)) * mult
				"armory":
					repair_rate += float(cspec.get("repair_rate", 6.0)) * mult
				"recon":
					radar_bonus += float(cspec.get("radar_bonus", 40.0)) * mult
				"generator":
					power_capacity += int(cdata.get("bonus_power", 0))

	return {
		"boiler_level": boiler_lv,
		"armor_level": armor_lv,
		"headlamp_level": lamp_lv,
		"headlamp_range": float(lamp_tier.get("light_range", 13.0)),
		"headlamp_energy": float(lamp_tier.get("energy", 3.4)),
		"max_carriages": max_carriages,
		"carriage_count": carriages.size(),
		"power_used": power_used,
		"power_capacity": power_capacity,
		"max_hull_hp": max_hull_hp,
		"damage_reduction": float(armor_tier.get("damage_reduction", 0.0)),
		"departure_seconds": departure_sec,
		"backpack_capacity": backpack_cap,
		"turret_count": turret_count,
		"turret_dps": turret_dps,
		"heal_rate": heal_rate,
		"repair_rate": repair_rate,
		"radar_bonus": radar_bonus,
		"assigned_crew": assigned_crew,
		"total_crew_slots": total_crew_slots,
	}


func upgrade_locomotive(part: String, stash: Dictionary) -> Dictionary:
	var key: String = part + "_level"
	if not locomotive.has(key):
		return {"ok": false, "reason": "unknown_part", "message": "未知的火車頭改造部件"}
	var cur_lv: int = int(locomotive.get(key, 1))
	var max_lv: int = MAX_BOILER_LEVEL if part == "boiler" else (MAX_ARMOR_LEVEL if part == "armor" else MAX_HEADLAMP_LEVEL)
	if cur_lv >= max_lv:
		return {"ok": false, "reason": "max_level", "message": "此火車頭部件已達最高等級"}
	var cost: Dictionary = get_locomotive_upgrade_cost(part)
	if not can_afford(cost, stash):
		return {"ok": false, "reason": "insufficient_resources", "message": "暫存倉資源不足（需要：%s）" % format_cost(cost)}

	_spend_cost(cost, stash)
	locomotive[key] = cur_lv + 1
	consist_changed.emit()
	return {"ok": true, "level": cur_lv + 1, "message": "火車頭改造成功！已升級至 Lv.%d" % (cur_lv + 1)}


func expand_carriage(stash: Dictionary) -> Dictionary:
	var max_cars: int = get_max_carriages()
	if carriages.size() >= max_cars:
		return {
			"ok": false,
			"reason": "traction_limit",
			"message": "已達火車頭最大牽引上限（%d 節），請先升級鍋爐傳動！" % max_cars,
		}
	if not can_afford(EXPAND_CARRIAGE_COST, stash):
		return {
			"ok": false,
			"reason": "insufficient_resources",
			"message": "暫存倉資源不足（擴建需：%s）" % format_cost(EXPAND_CARRIAGE_COST),
		}

	_spend_cost(EXPAND_CARRIAGE_COST, stash)
	carriages.append(_make_carriage("flatbed"))
	consist_changed.emit()
	return {"ok": true, "index": carriages.size() - 1, "message": "車廂擴建完成！已掛接第 %d 節新車廂（含 1 車頂掛點＋2 內部艙格）" % carriages.size()}


func refit_carriage_cell(carriage_index: int, cell_index: int, module_type: String, stash: Dictionary) -> Dictionary:
	if carriage_index < 0 or carriage_index >= carriages.size():
		return {"ok": false, "reason": "invalid_index", "message": "無效的車廂編號"}
	var car: Dictionary = carriages[carriage_index]
	var cells: Array = car.get("cells", []) as Array
	if cell_index < 0 or cell_index >= cells.size():
		return {"ok": false, "reason": "invalid_cell", "message": "無效的艙格編號"}
	if not CELL_CATALOG.has(module_type):
		return {"ok": false, "reason": "unknown_module", "message": "未知的艙室類型"}

	var cell: Dictionary = cells[cell_index] as Dictionary
	var old_mod: String = str(cell.get("module", "empty"))
	if old_mod == module_type:
		return {"ok": false, "reason": "same_module", "message": "此艙格已是該設施"}

	if old_mod == "boarding" and _count_cells_of_module("boarding") <= 1:
		return {"ok": false, "reason": "core_required", "message": "全列車至少必須保留 1 格【指揮登車室】"}
	if old_mod == "cargo" and _count_cells_of_module("cargo") <= 1:
		return {"ok": false, "reason": "core_required", "message": "全列車至少必須保留 1 格【貨運暫存倉】"}

	var old_spec: Dictionary = get_cell_spec(old_mod)
	var new_spec: Dictionary = get_cell_spec(module_type)
	var stats: Dictionary = compute_stats()
	var sim_used: int = int(stats.get("power_used", 0))
	var sim_cap: int = int(stats.get("power_capacity", 6))
	var old_pwr: int = int(old_spec.get("power", 0))
	var new_pwr: int = int(new_spec.get("power", 0))
	if old_pwr >= 0:
		sim_used -= old_pwr
	else:
		sim_cap -= -old_pwr
	if new_pwr >= 0:
		sim_used += new_pwr
	else:
		sim_cap += -new_pwr

	if sim_used > sim_cap:
		return {
			"ok": false,
			"reason": "power_exceeded",
			"message": "列車動力不足（改建後 %d / %d），請先升級火車頭鍋爐或建造【輔助發電室】！" % [sim_used, sim_cap],
		}

	var cost: Dictionary = (new_spec.get("cost", {}) as Dictionary).duplicate()
	if not can_afford(cost, stash):
		return {"ok": false, "reason": "insufficient_resources", "message": "暫存倉資源不足（需：%s）" % format_cost(cost)}

	_spend_cost(cost, stash)
	cell["module"] = module_type
	if not bool(new_spec.get("can_assign_crew", false)):
		cell["crew_id"] = ""
	_sync_carriage_derived_fields(car)
	consist_changed.emit()
	return {"ok": true, "message": "第 %d 節車廂 艙格 %d 已改建為【%s】！" % [carriage_index + 1, cell_index + 1, str(new_spec.get("name", module_type))]}


func refit_carriage_roof(carriage_index: int, roof_type: String, stash: Dictionary) -> Dictionary:
	if carriage_index < 0 or carriage_index >= carriages.size():
		return {"ok": false, "reason": "invalid_index", "message": "無效的車廂編號"}
	if not ROOF_CATALOG.has(roof_type):
		return {"ok": false, "reason": "unknown_roof", "message": "未知的車頂武裝類型"}

	var car: Dictionary = carriages[carriage_index]
	var old_roof: String = str(car.get("roof", "none"))
	if old_roof == roof_type:
		return {"ok": false, "reason": "same_roof", "message": "車頂已是此配置"}

	var old_spec: Dictionary = get_roof_spec(old_roof)
	var new_spec: Dictionary = get_roof_spec(roof_type)
	var stats: Dictionary = compute_stats()
	var sim_used: int = int(stats.get("power_used", 0)) - int(old_spec.get("power", 0)) + int(new_spec.get("power", 0))
	var sim_cap: int = int(stats.get("power_capacity", 6))
	if sim_used > sim_cap:
		return {
			"ok": false,
			"reason": "power_exceeded",
			"message": "列車動力不足（安裝後 %d / %d），請先升級鍋爐或加裝【輔助發電室】！" % [sim_used, sim_cap],
		}

	var cost: Dictionary = (new_spec.get("cost", {}) as Dictionary).duplicate()
	if not can_afford(cost, stash):
		return {"ok": false, "reason": "insufficient_resources", "message": "暫存倉資源不足（需：%s）" % format_cost(cost)}

	_spend_cost(cost, stash)
	car["roof"] = roof_type
	_sync_carriage_derived_fields(car)
	consist_changed.emit()
	return {"ok": true, "message": "第 %d 節車廂車頂已安裝【%s】！" % [carriage_index + 1, str(new_spec.get("name", roof_type))]}


func refit_carriage(index: int, new_type: String, stash: Dictionary) -> Dictionary:
	if index < 0 or index >= carriages.size():
		return {"ok": false, "reason": "invalid_index", "message": "無效的車廂編號"}
	if not CARRIAGE_CATALOG.has(new_type):
		return {"ok": false, "reason": "unknown_type", "message": "未知的車廂改裝類型"}

	var car: Dictionary = carriages[index]
	var old_type: String = str(car.get("type", "flatbed"))
	if old_type == new_type:
		return {"ok": false, "reason": "same_type", "message": "該車廂已是此類型"}

	var preset: Dictionary = CARRIAGE_CATALOG[new_type] as Dictionary
	var new_roof: String = str(preset.get("roof", "none"))
	var new_c0: String = str(preset.get("cell0", "empty"))
	var new_c1: String = str(preset.get("cell1", "empty"))

	# Protect sole boarding or cargo cells
	var old_cells: Array = car.get("cells", []) as Array
	var had_boarding: bool = _carriage_has_cell_module(car, "boarding")
	var had_cargo: bool = _carriage_has_cell_module(car, "cargo")
	if had_boarding and new_c0 != "boarding" and new_c1 != "boarding" and _count_cells_of_module("boarding") <= 1:
		return {"ok": false, "reason": "core_required", "message": "列車必須至少保留 1 節【指揮登車車廂】"}
	if had_cargo and new_c0 != "cargo" and new_c1 != "cargo" and _count_cells_of_module("cargo") <= 1:
		return {"ok": false, "reason": "core_required", "message": "列車必須至少保留 1 節【貨運暫存車廂】"}

	# Simulate power balance
	var stats: Dictionary = compute_stats()
	var sim_used: int = int(stats.get("power_used", 0))
	var sim_cap: int = int(stats.get("power_capacity", 6))
	var old_delta: Vector2i = _carriage_power_delta(str(car.get("roof", "none")), str((old_cells[0] as Dictionary).get("module", "empty")), str((old_cells[1] as Dictionary).get("module", "empty")))
	var new_delta: Vector2i = _carriage_power_delta(new_roof, new_c0, new_c1)
	sim_used = sim_used - old_delta.x + new_delta.x
	sim_cap = sim_cap - old_delta.y + new_delta.y
	if sim_used > sim_cap:
		return {"ok": false, "reason": "power_exceeded", "message": "列車動力額度不足（改裝後需 %d / 上限 %d）！" % [sim_used, sim_cap]}

	var cost: Dictionary = (preset.get("cost", {}) as Dictionary).duplicate()
	if not can_afford(cost, stash):
		return {"ok": false, "reason": "insufficient_resources", "message": "暫存倉資源不足（需：%s）" % format_cost(cost)}

	_spend_cost(cost, stash)
	car["roof"] = new_roof
	(old_cells[0] as Dictionary)["module"] = new_c0
	if not bool(get_cell_spec(new_c0).get("can_assign_crew", false)):
		(old_cells[0] as Dictionary)["crew_id"] = ""
	(old_cells[1] as Dictionary)["module"] = new_c1
	if not bool(get_cell_spec(new_c1).get("can_assign_crew", false)):
		(old_cells[1] as Dictionary)["crew_id"] = ""
	_sync_carriage_derived_fields(car)
	consist_changed.emit()
	return {"ok": true, "message": "第 %d 節車廂已整車改造為【%s】！" % [index + 1, str(preset.get("name", new_type))]}


func _carriage_power_delta(roof_mod: String, c0: String, c1: String) -> Vector2i:
	var used: int = 0
	var cap: int = 0
	var rp: int = int(get_roof_spec(roof_mod).get("power", 0))
	if rp >= 0:
		used += rp
	else:
		cap += -rp
	for m in [c0, c1]:
		var cp: int = int(get_cell_spec(m).get("power", 0))
		if cp >= 0:
			used += cp
		else:
			cap += -cp
	return Vector2i(used, cap)


func move_carriage(index: int, delta: int) -> Dictionary:
	var target: int = index + delta
	if index < 0 or index >= carriages.size() or target < 0 or target >= carriages.size() or index == target:
		return {"ok": false, "reason": "out_of_range", "message": "無法往該方向移動車廂"}
	var tmp: Dictionary = carriages[index]
	carriages[index] = carriages[target]
	carriages[target] = tmp
	consist_changed.emit()
	return {"ok": true, "new_index": target, "message": "已調整車廂掛接順序（3D 列車即時重組）"}


func remove_carriage(index: int) -> Dictionary:
	if index < 0 or index >= carriages.size():
		return {"ok": false, "reason": "invalid_index", "message": "無效的車廂編號"}
	var car: Dictionary = carriages[index]
	if _carriage_has_cell_module(car, "boarding") and _count_cells_of_module("boarding") <= 1:
		return {"ok": false, "reason": "core_required", "message": "無法卸除包含最後一格【指揮登車室】的車廂"}
	if _carriage_has_cell_module(car, "cargo") and _count_cells_of_module("cargo") <= 1:
		return {"ok": false, "reason": "core_required", "message": "無法卸除包含最後一格【貨運暫存倉】的車廂"}

	var cells: Array = car.get("cells", []) as Array
	var delta: Vector2i = _carriage_power_delta(
		str(car.get("roof", "none")),
		str((cells[0] as Dictionary).get("module", "empty")),
		str((cells[1] as Dictionary).get("module", "empty"))
	)
	if delta.y > 0:
		var stats: Dictionary = compute_stats()
		if int(stats.get("power_used", 0)) - delta.x > int(stats.get("power_capacity", 6)) - delta.y:
			return {"ok": false, "reason": "power_exceeded", "message": "卸除此車廂會導致全車電力超載"}

	carriages.remove_at(index)
	consist_changed.emit()
	return {"ok": true, "message": "已卸除該節車廂"}


func assign_crew_to_locomotive(crew_id: String) -> Dictionary:
	if not crew_id.is_empty():
		if get_crew_by_id(crew_id).is_empty():
			return {"ok": false, "reason": "unknown_crew", "message": "找不到指定乘員"}
		_unassign_crew_everywhere(crew_id)
	var slots: Array = locomotive.get("crew_slots", [""]) as Array
	if slots.is_empty():
		slots.append("")
	slots[0] = crew_id
	locomotive["crew_slots"] = slots
	consist_changed.emit()
	if crew_id.is_empty():
		return {"ok": true, "message": "已解除火車頭駕駛艙乘員"}
	var c: Dictionary = get_crew_by_id(crew_id)
	return {"ok": true, "message": "已將【%s】放入火車頭駕駛輪機艙！" % str(c.get("name", crew_id))}


func assign_crew_to_cell(carriage_index: int, cell_index: int, crew_id: String) -> Dictionary:
	if carriage_index < 0 or carriage_index >= carriages.size():
		return {"ok": false, "reason": "invalid_index", "message": "無效的車廂編號"}
	var car: Dictionary = carriages[carriage_index]
	var cells: Array = car.get("cells", []) as Array
	if cell_index < 0 or cell_index >= cells.size():
		return {"ok": false, "reason": "invalid_slot", "message": "無效的艙格編號"}

	var cell: Dictionary = cells[cell_index] as Dictionary
	var mod: String = str(cell.get("module", "empty"))
	var cspec: Dictionary = get_cell_spec(mod)
	if not crew_id.is_empty():
		if not bool(cspec.get("can_assign_crew", false)):
			return {"ok": false, "reason": "empty_cell", "message": "此格為【空艙格】，請先改建為功能艙室再放入成員！"}
		if get_crew_by_id(crew_id).is_empty():
			return {"ok": false, "reason": "unknown_crew", "message": "找不到指定乘員"}
		_unassign_crew_everywhere(crew_id)

	cell["crew_id"] = crew_id
	_sync_carriage_derived_fields(car)
	consist_changed.emit()

	if crew_id.is_empty():
		return {"ok": true, "message": "已移出第 %d 節車廂 艙格 %d 的成員" % [carriage_index + 1, cell_index + 1]}
	var c: Dictionary = get_crew_by_id(crew_id)
	var aff: float = get_crew_affinity(crew_id, str(cspec.get("best_role", "any")))
	return {
		"ok": true,
		"affinity": aff,
		"message": "已將【%s】放入第 %d 節車廂 艙格 %d【%s】（適性 %d%%）！" % [
			str(c.get("name", crew_id)),
			carriage_index + 1,
			cell_index + 1,
			str(cspec.get("name", mod)),
			int(round(aff * 100.0)),
		],
	}


func assign_crew_to_carriage(carriage_index: int, slot_index: int, crew_id: String) -> Dictionary:
	return assign_crew_to_cell(carriage_index, slot_index, crew_id)


func _unassign_crew_everywhere(crew_id: String) -> void:
	var loco_slots: Array = locomotive.get("crew_slots", []) as Array
	for i in range(loco_slots.size()):
		if str(loco_slots[i]) == crew_id:
			loco_slots[i] = ""
	for car: Dictionary in carriages:
		var cells: Array = car.get("cells", []) as Array
		for cell_raw in cells:
			var cell: Dictionary = cell_raw as Dictionary
			if str(cell.get("crew_id", "")) == crew_id:
				cell["crew_id"] = ""
		_sync_carriage_derived_fields(car)


func _carriage_has_cell_module(car: Dictionary, module_type: String) -> bool:
	var cells: Array = car.get("cells", []) as Array
	for cell_raw in cells:
		if str((cell_raw as Dictionary).get("module", "")) == module_type:
			return true
	return false


func _count_cells_of_module(module_type: String) -> int:
	var cnt: int = 0
	for car: Dictionary in carriages:
		var cells: Array = car.get("cells", []) as Array
		for cell_raw in cells:
			if str((cell_raw as Dictionary).get("module", "")) == module_type:
				cnt += 1
	return cnt


func to_dict() -> Dictionary:
	return {
		"version": 2,
		"locomotive": locomotive.duplicate(true),
		"carriages": carriages.duplicate(true),
	}


func from_dict(data: Dictionary) -> bool:
	if not (data.has("locomotive") and data.has("carriages")):
		return false
	var loco_raw: Variant = data.get("locomotive")
	var cars_raw: Variant = data.get("carriages")
	if not (loco_raw is Dictionary and cars_raw is Array):
		return false
	locomotive = (loco_raw as Dictionary).duplicate(true)
	carriages.clear()
	for item in (cars_raw as Array):
		if item is Dictionary:
			var car: Dictionary = (item as Dictionary).duplicate(true)
			if not car.has("cells"):
				var fallback: Dictionary = _make_carriage(str(car.get("type", "flatbed")))
				car["roof"] = fallback["roof"]
				car["cells"] = fallback["cells"]
			_sync_carriage_derived_fields(car)
			carriages.append(car)
	consist_changed.emit()
	return true
