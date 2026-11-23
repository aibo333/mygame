class_name GameConfig
extends RefCounted

const ARENA_MIN_X: float = -26.0
const ARENA_MAX_X: float = 26.0
const ARENA_HALF_Z: float = 15.0
const GATE_X: float = -22.0
const GATE_MAX_HP: float = 500.0


static func clamp_to_arena(pos: Vector3, margin: float = 0.8) -> Vector3:
	return Vector3(
		clampf(pos.x, ARENA_MIN_X + margin, ARENA_MAX_X - margin),
		pos.y,
		clampf(pos.z, -ARENA_HALF_Z + margin, ARENA_HALF_Z - margin)
	)


static func get_regiment_ids() -> PackedStringArray:
	return PackedStringArray(["shieldmen", "pikemen", "archers"])


static func get_regiment(type_id: String) -> Dictionary:
	match type_id:
		"shieldmen":
			return {
				"id": "shieldmen",
				"name": "鐵衛刀盾兵",
				"description": "重甲前排步兵，擅長架設盾牆吸收火力並發動盾擊衝鋒。",
				"count": 10,
				"max_hp": 185.0,
				"attack": 17.0,
				"defense": 12.0,
				"attack_range": 2.2,
				"attack_interval": 1.05,
				"move_speed": 5.5,
				"is_ranged": false,
				"skill_name": "盾擊衝鋒",
				"skill_cd": 10.0,
				"compact_label": "盾牆陣",
				"spread_label": "散兵陣",
			}
		"pikemen":
			return {
				"id": "pikemen",
				"name": "拒馬長槍兵",
				"description": "長距離突刺兵團，拒馬陣型可重創衝鋒敵軍，擅長疾風突刺。",
				"count": 10,
				"max_hp": 135.0,
				"attack": 24.0,
				"defense": 6.0,
				"attack_range": 3.5,
				"attack_interval": 0.98,
				"move_speed": 5.9,
				"is_ranged": false,
				"skill_name": "疾風突刺",
				"skill_cd": 9.0,
				"compact_label": "拒馬槍陣",
				"spread_label": "散兵陣",
			}
		"archers":
			return {
				"id": "archers",
				"name": "蒼穹長弓兵",
				"description": "遠程火力支援兵團，能覆蓋半場並對指定區域傾瀉致命箭雨。",
				"count": 8,
				"max_hp": 95.0,
				"attack": 22.0,
				"defense": 3.0,
				"attack_range": 16.0,
				"attack_interval": 1.12,
				"move_speed": 5.7,
				"is_ranged": true,
				"skill_name": "指定箭雨",
				"skill_cd": 11.0,
				"compact_label": "密集齊射",
				"spread_label": "散開射擊",
			}
		_:
			push_warning("GameConfig.get_regiment: 未知兵團類型 '%s'，改用 shieldmen" % type_id)
			return get_regiment("shieldmen")


static func get_enemy(type_id: String) -> Dictionary:
	match type_id:
		"goblin_raider":
			return {
				"id": "goblin_raider",
				"name": "哥布林掠奪者",
				"is_commander": false,
				"max_hp": 75.0,
				"attack": 11.0,
				"defense": 2.0,
				"attack_range": 1.9,
				"attack_interval": 1.0,
				"move_speed": 5.2,
				"is_ranged": false,
				"gate_damage": 14.0,
				"scale": 0.88,
			}
		"shield_orc":
			return {
				"id": "shield_orc",
				"name": "鐵甲盾獸人",
				"is_commander": false,
				"max_hp": 175.0,
				"attack": 17.0,
				"defense": 9.0,
				"attack_range": 2.2,
				"attack_interval": 1.25,
				"move_speed": 3.8,
				"is_ranged": false,
				"gate_damage": 24.0,
				"scale": 1.15,
			}
		"skeleton_archer":
			return {
				"id": "skeleton_archer",
				"name": "骸骨弓箭手",
				"is_commander": false,
				"max_hp": 80.0,
				"attack": 15.0,
				"defense": 2.0,
				"attack_range": 13.5,
				"attack_interval": 1.45,
				"move_speed": 4.2,
				"is_ranged": true,
				"gate_damage": 12.0,
				"scale": 0.95,
			}
		"berserker":
			return {
				"id": "berserker",
				"name": "狂戰雙斧兵",
				"is_commander": false,
				"max_hp": 145.0,
				"attack": 26.0,
				"defense": 4.0,
				"attack_range": 2.3,
				"attack_interval": 0.92,
				"move_speed": 5.6,
				"is_ranged": false,
				"gate_damage": 28.0,
				"scale": 1.08,
			}
		"enemy_commander":
			return {
				"id": "enemy_commander",
				"name": "敵方督軍",
				"is_commander": true,
				"max_hp": 680.0,
				"attack": 34.0,
				"defense": 10.0,
				"attack_range": 3.0,
				"attack_interval": 1.2,
				"move_speed": 4.4,
				"is_ranged": false,
				"gate_damage": 45.0,
				"scale": 1.45,
				"telegraph_radius": 4.5,
				"telegraph_windup": 1.1,
				"telegraph_damage": 75.0,
			}
		_:
			push_warning("GameConfig.get_enemy: 未知敵人類型 '%s'，改用 goblin_raider" % type_id)
			return get_enemy("goblin_raider")


static func get_wave(wave_number: int) -> Dictionary:
	match wave_number:
		1:
			var spawns_1: Array[Dictionary] = [
				{"type": "goblin_raider", "count": 6, "spawn_time": 0.5, "hp_mult": 1.0},
				{"type": "skeleton_archer", "count": 3, "spawn_time": 3.0, "hp_mult": 1.0},
				{"type": "goblin_raider", "count": 6, "spawn_time": 7.5, "hp_mult": 1.0},
				{"type": "shield_orc", "count": 2, "spawn_time": 11.0, "hp_mult": 1.0},
			]
			return {
				"wave_number": 1,
				"name": "第一波：哥布林先鋒營",
				"description": "大量哥布林掠奪者與骸骨弓手正試圖試探城門防線。",
				"spawns": spawns_1,
			}
		2:
			var spawns_2: Array[Dictionary] = [
				{"type": "shield_orc", "count": 4, "spawn_time": 0.5, "hp_mult": 1.0},
				{"type": "skeleton_archer", "count": 4, "spawn_time": 2.5, "hp_mult": 1.0},
				{"type": "berserker", "count": 3, "spawn_time": 6.5, "hp_mult": 1.0},
				{
					"type": "enemy_commander",
					"count": 1,
					"spawn_time": 9.0,
					"custom_name": "碎骨隊長",
					"hp_mult": 0.9,
				},
				{"type": "goblin_raider", "count": 5, "spawn_time": 13.5, "hp_mult": 1.1},
			]
			return {
				"wave_number": 2,
				"name": "第二波：鐵甲破陣連",
				"description": "重盾獸人護衛著「碎骨隊長」強攻城門，注意躲避範圍重劈！",
				"spawns": spawns_2,
			}
		3:
			var spawns_3: Array[Dictionary] = [
				{"type": "shield_orc", "count": 5, "spawn_time": 0.5, "hp_mult": 1.1},
				{"type": "berserker", "count": 5, "spawn_time": 3.0, "hp_mult": 1.05},
				{"type": "skeleton_archer", "count": 5, "spawn_time": 5.5, "hp_mult": 1.05},
				{
					"type": "enemy_commander",
					"count": 1,
					"spawn_time": 8.5,
					"custom_name": "血斧督軍",
					"hp_mult": 1.25,
				},
				{"type": "berserker", "count": 4, "spawn_time": 14.0, "hp_mult": 1.1},
				{"type": "goblin_raider", "count": 6, "spawn_time": 17.0, "hp_mult": 1.15},
			]
			return {
				"wave_number": 3,
				"name": "最終波：血斧總攻",
				"description": "「血斧督軍」率領全軍發動總攻！守住城門並擊潰敵軍督軍即可獲勝。",
				"spawns": spawns_3,
			}
		_:
			return get_wave(clampi(wave_number, 1, 3))
