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
const AVATAR_ARIA_DIR: String = "res://assets/packs/aria_idol_cuteness_avatar/Avatar_Female_Size01_AriaIdolCuteness_UI/"
const AVATAR_ARIA_FBX_PATH: String = "res://assets/packs/aria_idol_cuteness_avatar/Avatar_Female_Size01_AriaIdolCuteness_UI/Avatar_Female_Size01_AriaIdolCuteness_UI.fbx"
const AVATAR_NANGONG_DIR: String = "res://assets/packs/nangong_yu_cuteness_avatar/Avatar_Female_Size01_NangongYuCuteness_UI/"
const AVATAR_NANGONG_FBX_PATH: String = "res://assets/packs/nangong_yu_cuteness_avatar/Avatar_Female_Size01_NangongYuCuteness_UI/Avatar_Female_Size01_NangongYuCuteness_UI.fbx"
const DEFAULT_AVATAR_ID: String = "summer_cuteness"
const AVATAR_ORDER: Array[String] = ["summer_cuteness", "aria_idol", "nangong_yu"]
const WEAPON_M4A1S_DIR: String = "res://assets/models/weapons/m4a1s/"
const WEAPON_M4A1S_FBX_PATH: String = "res://assets/models/weapons/m4a1s/M4A1S_CS2.fbx"
const WEAPON_AK47_DIR: String = "res://assets/models/weapons/ak47/"
const WEAPON_AK47_GLB_PATH: String = "res://assets/models/weapons/ak47/AK47v2.glb"
const WEAPON_DEAGLE_DIR: String = "res://assets/models/weapons/deagle/"
const WEAPON_DEAGLE_GLB_PATH: String = "res://assets/models/weapons/deagle/DEAGLE.glb"
const WEAPON_SOUND_PACK_DIR: String = "res://assets/packs/cs2_weapons_sound_pack/"
const DEFAULT_WEAPON_IDS: Array[String] = ["m4a1s", "ak47", "deagle"]

const WEAPON_M4A1_SFX: Dictionary = {
	"fire": [
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_01.wav",
	],
	"fire_distant": [
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_distant_01.wav",
	],
	"fire_unsilenced": [
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_us_01.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_us_02.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_us_03.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_us_04.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_01.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_02.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_03.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_04.wav",
	],
	"fire_unsilenced_distant": [
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_us_distant.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_us_distant_02.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_us_distant_03.wav",
	],
	"clip_out": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_clipout.mp3",
	"clip_in": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_clipin.mp3",
	"clip_hit": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_cliphit.wav",
	"bolt_back": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_boltback.wav",
	"bolt_forward": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_boltforward.wav",
	"bolt_back_unsilenced": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_boltback.mp3",
	"bolt_forward_unsilenced": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_boltforward.mp3",
	"add_ammo": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_addammo_01.mp3",
	"draw": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_draw.mp3",
	"silencer_on": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_on.wav",
	"silencer_off": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_off.wav",
	"silencer_screw_on_start": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_screw_on_start.wav",
	"silencer_screw_off_end": "res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_screw_off_end.wav",
	"silencer_screws": [
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_screw_1.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_screw_2.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_screw_3.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_screw_4.wav",
		"res://assets/packs/cs2_weapons_sound_pack/m4a1/m4a1_silencer_screw_5.wav",
	],
}

const WEAPON_AK47_SFX: Dictionary = {
	"fire": [
		"res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_01.wav",
		"res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_02.wav",
		"res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_03.wav",
		"res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_04.wav",
		"res://assets/packs/cs2_weapons_sound_pack/ak47/ak47-1.wav",
	],
	"fire_distant": [
		"res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_distant.wav",
	],
	"clip_out": "res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_clipout_01.wav",
	"clip_in": "res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_addammo_02.wav",
	"bolt_back": "res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_boltpull_01.wav",
	"bolt_forward": "res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_boltpull.wav",
	"add_ammo": "res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_addammo_02.wav",
	"draw": "res://assets/packs/cs2_weapons_sound_pack/ak47/ak47_draw.wav",
}

const WEAPON_DEAGLE_SFX: Dictionary = {
	"fire": [
		"res://assets/packs/cs2_weapons_sound_pack/deagle/deagle_01.wav",
		"res://assets/packs/cs2_weapons_sound_pack/deagle/deagle_02.wav",
	],
	"fire_distant": [
		"res://assets/packs/cs2_weapons_sound_pack/deagle/deagle-1-distant.wav",
	],
	"clip_out": "res://assets/packs/cs2_weapons_sound_pack/deagle/de_clipout.wav",
	"clip_in": "res://assets/packs/cs2_weapons_sound_pack/deagle/de_clipin.mp3",
	"bolt_back": "res://assets/packs/cs2_weapons_sound_pack/deagle/de_slideback.wav",
	"bolt_forward": "res://assets/packs/cs2_weapons_sound_pack/deagle/de_slideforward.wav",
	"add_ammo": "res://assets/packs/cs2_weapons_sound_pack/deagle/deagle_addammo_01.mp3",
	"draw": "res://assets/packs/cs2_weapons_sound_pack/deagle/de_draw.wav",
}

const MIXAMO_ANIMS: Dictionary = {
	"idle": "res://assets/animations/mixamo/rifle_idle.fbx",
	"walk": "res://assets/animations/mixamo/rifle_run.fbx",
	"shoot": "res://assets/animations/mixamo/firing_rifle.fbx",
	"roll": "res://assets/animations/mixamo/dive_roll.fbx",
	"strafe_left": "res://assets/animations/mixamo/strafe_left.fbx",
	"strafe_right": "res://assets/animations/mixamo/strafe_right.fbx",
	"run_backwards": "res://assets/animations/mixamo/run_backwards.fbx",
	"reload": "res://assets/animations/mixamo/reloading.fbx",
	"reload_move": "res://assets/animations/mixamo/reload_move.fbx",
	"hit": "res://assets/animations/mixamo/hit_reaction.fbx",
	"death": "res://assets/animations/mixamo/death.fbx",
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


static func get_weapon_config(weapon_id: String) -> Dictionary:
	match weapon_id:
		"ak47":
			return {
				"id": "ak47",
				"slot": 2,
				"short_name": "AK-47",
				"label": "AK-47 突擊步槍",
				"model_path": WEAPON_AK47_GLB_PATH,
				"model_node_name": "AK47Model",
				"model_scale": Vector3.ONE * 0.78,
				"model_pos": Vector3(0.0, 0.01, 0.02),
				"muzzle_pos": Vector3(0.0, 0.062, 0.54),
				"apply_m4a1s_pbr": false,
				"mag_size": 30,
				"fire_interval": 0.165,
				"bullet_damage": 38.0,
				"pellets": 1,
				"spread_deg": 3.8,
				"reload_duration": 1.50,
				"supports_silencer": false,
				"muzzle_color": Color(1.0, 0.72, 0.30),
				"sfx": WEAPON_AK47_SFX,
			}
		"deagle":
			return {
				"id": "deagle",
				"slot": 3,
				"short_name": "Desert Eagle",
				"label": "Desert Eagle 沙漠之鷹",
				"model_path": WEAPON_DEAGLE_GLB_PATH,
				"model_node_name": "DeagleModel",
				"model_scale": Vector3.ONE * 0.92,
				"model_pos": Vector3(0.0, -0.01, 0.04),
				"muzzle_pos": Vector3(0.0, 0.068, 0.26),
				"apply_m4a1s_pbr": false,
				"mag_size": 7,
				"fire_interval": 0.36,
				"bullet_damage": 72.0,
				"pellets": 1,
				"spread_deg": 1.4,
				"reload_duration": 1.10,
				"supports_silencer": false,
				"muzzle_color": Color(1.0, 0.88, 0.45),
				"sfx": WEAPON_DEAGLE_SFX,
			}
		_:
			return {
				"id": "m4a1s",
				"slot": 1,
				"short_name": "M4A1-S",
				"label": "M4A1-S 消音突擊步槍",
				"model_path": WEAPON_M4A1S_FBX_PATH,
				"model_node_name": "M4A1SModel",
				"model_scale": Vector3.ONE * 0.72,
				"model_pos": Vector3(0.0, -0.02, 0.02),
				"muzzle_pos": Vector3(0.0, 0.055, 0.62),
				"apply_m4a1s_pbr": true,
				"mag_size": 30,
				"fire_interval": 0.14,
				"bullet_damage": 28.0,
				"pellets": 1,
				"spread_deg": 2.5,
				"reload_duration": 1.35,
				"supports_silencer": true,
				"muzzle_color": Color(0.55, 0.92, 1.0),
				"sfx": WEAPON_M4A1_SFX,
			}


static func get_default_loadout() -> Array[Dictionary]:
	var loadout: Array[Dictionary] = []
	for wid: String in DEFAULT_WEAPON_IDS:
		loadout.append(get_weapon_config(wid))
	return loadout


static func get_avatar_config(avatar_id: String) -> Dictionary:
	match avatar_id:
		"aria_idol":
			return {
				"id": "aria_idol",
				"label": "愛芮 Aria (偶像)",
				"model_path": AVATAR_ARIA_FBX_PATH,
				"texture_dir": AVATAR_ARIA_DIR,
				"material_mode": "hiragara_toon",
				"face_path": AVATAR_ARIA_DIR + "AriaIdol_Face_D.png",
				"scale": 1.45,
				"facing_yaw_offset": PI,
				"foot_pitch_fix_deg": -52.0,
				"hips_y_offset": -0.98,
				"hide_mesh_substrings": ["hairshadow", "shy", "weapon"],
				"tex_map": {
					"MAT_AriaIdol_Cuteness_Body_1_UI": "AriaIdol_Cuteness_Body_1_D.png",
					"MAT_AriaIdol_Cuteness_Body_2_UI": "AriaIdol_Cuteness_Body_2_D.png",
					"MAT_AriaIdol_Body_2_UI": "AriaIdol_Body_2_D.png",
					"MAT_AriaIdol_Hair_T_UI": "AriaIdol_Body_2_D.png",
					"MAT_AriaIdol_Face_UI": "AriaIdol_Face_D.png",
					"MAT_AriaIdol_Eye_UI": "AriaIdol_Face_D.png",
					"MAT_AriaIdol_Eyebrow_UI": "AriaIdol_Face_D.png",
					"MAT_AriaIdol_Weapon_UI": "AriaIdol_Weapon_D.png",
				},
			}
		"nangong_yu":
			return {
				"id": "nangong_yu",
				"label": "南宮羽 (天使光環)",
				"model_path": AVATAR_NANGONG_FBX_PATH,
				"texture_dir": AVATAR_NANGONG_DIR,
				"material_mode": "hiragara_toon",
				"face_path": AVATAR_NANGONG_DIR + "NangongYu_Face_D.png",
				"scale": 1.45,
				"facing_yaw_offset": PI,
				"foot_pitch_fix_deg": -52.0,
				"hips_y_offset": -0.98,
				"hide_mesh_substrings": ["hairshadow", "shy", "weapon", "wing_fx"],
				"tex_map": {
					"MAT_NangongYu_Cuteness_Body_1_UI": "NangongYu_Cuteness_Body_1_D.png",
					"MAT_NangongYu_Cuteness_Body_2_UI": "NangongYu_Cuteness_Body_2_D.png",
					"MAT_AriaIdol_Cuteness_Body_2_UI": "AriaIdol_Cuteness_Body_2_D.png",
					"MAT_NangongYu_Cuteness_Halo_UI": "NangongYu_Cuteness_Body_2_D.png",
					"MAT_NangongYu_Hair_UI": "NangongYu_Hair_D.png",
					"MAT_NangongYu_Hair_T_UI": "NangongYu_Hair_D.png",
					"MAT_NangongYu_Face_UI": "NangongYu_Face_D.png",
					"MAT_NangongYu_Eye_UI": "NangongYu_Face_D.png",
					"MAT_NangongYu_Eyebrow_UI": "NangongYu_Face_D.png",
					"MAT_NangongYu_Weapon_UI": "NangongYu_Weapon_D.png",
				},
			}
		"summer_cuteness":
			return {
				"id": "summer_cuteness",
				"label": "千夏 Summer (預設)",
				"model_path": AVATAR_FBX_PATH,
				"texture_dir": AVATAR_DIR,
				"material_mode": "hiragara_toon",
				"face_path": AVATAR_DIR + "Summer_Face_D.png",
				"scale": 1.45,
				"facing_yaw_offset": PI,
				"foot_pitch_fix_deg": -52.0,
				"hips_y_offset": -0.98,
				"hide_mesh_substrings": ["hairshadow", "shy"],
				"tex_map": {
					"MAT_Summer_Cuteness_Body_1_UI": "Summer_Cuteness_Body_1_D.png",
					"MAT_Summer_Cuteness_Body_2_UI": "Summer_Cuteness_Body_2_D.png",
					"MAT_Summer_Body_2_UI": "Summer_Body_Map2_D.png",
					"MAT_Summer_Hair_T_UI": "Summer_Body_Map2_D.png",
					"MAT_Summer_Face_UI": "Summer_Face_D.png",
					"MAT_Summer_Eye_UI": "Summer_Face_D.png",
					"MAT_Summer_Eyebrows_UI": "Summer_Face_D.png",
					"MAT_Summer_Weapon_1_UI": "Summer_Weapon_D.png",
				},
			}
		_:
			return {}


static func get_avatar_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for aid: String in AVATAR_ORDER:
		var cfg: Dictionary = get_avatar_config(aid)
		if not cfg.is_empty():
			catalog.append(cfg)
	return catalog


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
		"weapon_label": "M4A1-S 消音突擊步槍",
		"weapon_sfx": WEAPON_M4A1_SFX,
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
