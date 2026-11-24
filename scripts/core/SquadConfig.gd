class_name SquadConfig
extends RefCounted

const WORLD_MIN_X: float = -30.0
const WORLD_MAX_X: float = 30.0
const WORLD_MIN_Z: float = -6.0
const WORLD_MAX_Z: float = 20.0

const TRAIN_POSITION: Vector3 = Vector3(0.0, 0.0, -9.2)


static func clamp_playable(pos: Vector3) -> Vector3:
	return Vector3(
		clampf(pos.x, WORLD_MIN_X, WORLD_MAX_X),
		pos.y,
		clampf(pos.z, WORLD_MIN_Z, WORLD_MAX_Z)
	)


static func get_squad_ids() -> PackedStringArray:
	return PackedStringArray(["reina_ar", "chisa_smg", "lily_sg"])


static func get_character(char_id: String) -> Dictionary:
	match char_id:
		"reina_ar":
			return {
				"id": "reina_ar",
				"slot": 1,
				"name": "白羽 玲奈",
				"codename": "REINA",
				"role": "突擊步槍隊長",
				"weapon_label": "戰術突擊步槍 (AR)",
				"model_path": "res://assets/models/characters/reina_ar.glb",
				"face_path": "res://assets/textures/faces/face_reina.png",
				"accent_color": Color(0.34, 0.86, 1.0),
				"muzzle_color": Color(0.55, 0.92, 1.0),
				"move_speed": 6.2,
				"roll_speed": 11.8,
				"fire_interval": 0.14,
				"pellets": 1,
				"spread_deg": 2.5,
				"spawn_pos": Vector3(-2.6, 0.0, -1.2),
			}
		"chisa_smg":
			return {
				"id": "chisa_smg",
				"slot": 2,
				"name": "蒼井 千紗",
				"codename": "CHISA",
				"role": "衝鋒槍 · 工兵技師",
				"weapon_label": "緊湊衝鋒槍 (SMG)",
				"model_path": "res://assets/models/characters/chisa_smg.glb",
				"face_path": "res://assets/textures/faces/face_chisa.png",
				"accent_color": Color(1.0, 0.73, 0.26),
				"muzzle_color": Color(1.0, 0.84, 0.42),
				"move_speed": 6.7,
				"roll_speed": 12.6,
				"fire_interval": 0.095,
				"pellets": 1,
				"spread_deg": 4.2,
				"spawn_pos": Vector3(-5.0, 0.0, 0.4),
			}
		"lily_sg":
			return {
				"id": "lily_sg",
				"slot": 3,
				"name": "星野 莉莉",
				"codename": "LILY",
				"role": "重火霰彈先鋒",
				"weapon_label": "戰術霰彈槍 (SG)",
				"model_path": "res://assets/models/characters/lily_sg.glb",
				"face_path": "res://assets/textures/faces/face_lily.png",
				"accent_color": Color(1.0, 0.30, 0.42),
				"muzzle_color": Color(1.0, 0.56, 0.34),
				"move_speed": 5.9,
				"roll_speed": 11.2,
				"fire_interval": 0.46,
				"pellets": 5,
				"spread_deg": 11.0,
				"spawn_pos": Vector3(0.0, 0.0, 0.6),
			}
		_:
			return get_character("reina_ar")


static func get_interactive_stations() -> Array[Dictionary]:
	return [
		{
			"id": "train_workshop",
			"label": "甲鐵城整備工作台",
			"action_text": "維護列車核心與裝甲模組...",
			"pos": Vector3(-2.6, 0.0, -4.6),
			"is_crate": false,
		},
		{
			"id": "crate_west",
			"label": "廢墟補給加密箱 A",
			"action_text": "正在開鎖搜刮零件...",
			"pos": Vector3(-11.5, 0.0, 4.2),
			"is_crate": true,
		},
		{
			"id": "crate_center",
			"label": "戰術軍火箱 B",
			"action_text": "正在撬開彈藥箱...",
			"pos": Vector3(5.8, 0.0, 3.6),
			"is_crate": true,
		},
		{
			"id": "crate_east",
			"label": "遺落通訊中繼箱 C",
			"action_text": "正在拆解微電子元件...",
			"pos": Vector3(14.0, 0.0, 7.2),
			"is_crate": true,
		},
	]
