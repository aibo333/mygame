class_name SquadConfig
extends RefCounted

# 4x playable area compared to initial 45.0 x 30.2 (1,359 m^2 -> 90.0 x 60.4 = 5,436 m^2)
const WORLD_MIN_X: float = -46.0
const WORLD_MAX_X: float = 44.0
const WORLD_MIN_Z: float = -24.2
const WORLD_MAX_Z: float = 36.2

const TRAIN_POSITION: Vector3 = Vector3(0.0, 0.0, -21.5)
const DEFAULT_SECTOR_SEED: int = 20261125
const KENNEY_DIR: String = "res://assets/packs/kenney_retro_urban/"
const AVATAR_DIR: String = "res://assets/packs/summer_cuteness_avatar/Avatar_Female_Size01_SummerCuteness_UI/"
const AVATAR_FBX_PATH: String = "res://assets/packs/summer_cuteness_avatar/Avatar_Female_Size01_SummerCuteness_UI/Avatar_Female_Size01_SummerCuteness_UI.fbx"

const MIXAMO_ANIMS: Dictionary = {
	"idle": "res://assets/animations/mixamo/rifle_idle.fbx",
	"walk": "res://assets/animations/mixamo/rifle_run.fbx",
	"shoot": "res://assets/animations/mixamo/firing_rifle.fbx",
	"roll": "res://assets/animations/mixamo/dive_roll.fbx",
}

static var active_playable_bounds: Rect2 = Rect2(WORLD_MIN_X, WORLD_MIN_Z, WORLD_MAX_X - WORLD_MIN_X, WORLD_MAX_Z - WORLD_MIN_Z)


static func set_playable_bounds(bounds: Rect2) -> void:
	if bounds.size.x > 1.0 and bounds.size.y > 1.0:
		active_playable_bounds = bounds


static func clamp_playable(pos: Vector3) -> Vector3:
	return Vector3(
		clampf(pos.x, active_playable_bounds.position.x, active_playable_bounds.end.x),
		pos.y,
		clampf(pos.z, active_playable_bounds.position.y, active_playable_bounds.end.y)
	)


static func get_squad_ids() -> PackedStringArray:
	# Solo player mode (AI followers removed)
	return PackedStringArray(["reina_ar"])


static func get_character(_char_id: String) -> Dictionary:
	return {
		"id": "reina_ar",
		"slot": 1,
		"name": "白羽 玲奈",
		"codename": "REINA",
		"role": "單人戰術特勤",
		"weapon_label": "突擊步槍 (Mixamo 動捕)",
		"model_path": AVATAR_FBX_PATH,
		"face_path": AVATAR_DIR + "Summer_Face_D.png",
		"sprite_halo_path": "res://assets/sprites/characters/reina_ar_halo.svg",
		"accent_color": Color(0.34, 0.86, 1.0),
		"muzzle_color": Color(0.55, 0.92, 1.0),
		"move_speed": 6.6,
		"roll_speed": 9.8,
		"fire_interval": 0.14,
		"pellets": 1,
		"spread_deg": 2.5,
		"spawn_pos": Vector3(0.0, 0.0, -14.8),
	}


static func get_interactive_stations() -> Array[Dictionary]:
	return [
		{
			"id": "yard_container",
			"label": "裝卸院貨櫃補給點",
			"action_text": "正在撬開貨運集裝箱搜刮物資...",
			"pos": Vector3(2.2, 0.0, -0.6),
		},
		{
			"id": "roadblock_checkpoint",
			"label": "大道檢查哨路障",
			"action_text": "正在檢修街區防禦路障...",
			"pos": Vector3(-9.2, 0.0, 5.8),
		},
		{
			"id": "alley_dumpster",
			"label": "廠房側巷垃圾箱",
			"action_text": "正在翻找工業零件與線材...",
			"pos": Vector3(-3.2, 0.0, 1.4),
		},
		{
			"id": "park_pallet",
			"label": "秋樹街角物資棧板",
			"action_text": "正在整理街邊補給棧板...",
			"pos": Vector3(11.2, 0.0, 10.6),
		},
	]
