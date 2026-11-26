# 民防住家建築 45～55 件模組化 3D 資產規格書（CDDA 五步管線 MVP）

本規格書定義第一批隨機城市建築（普通民防住家民房）的 3D 模組技術規範、比例尺與命名標準，確保美工素材（自製或外部採購套件改編）能無縫接入 Godot 4 的 CDDA 式五步生成管線與《少女前線2：追放》冷峻戰術動漫美術風格。

---

## 1. 空間尺度與 Godot 匯入規範（必守標準）

| 項目 | 規格值 | 說明 |
| :--- | :--- | :--- |
| **外圍街區主格線** | `3.2m × 3.2m` | 對齊現有 `SectorGenerator.gd` 與公路／鐵軌廊道 |
| **建築室內子格線** | **`1.6m × 1.6m`**（或 `1.0m` 換算） | 採 `1.6m` 剛好為 `3.2m` 之一半，一棟小型民房約 `4×4` 至 `6×6` 子格（`6.4m～9.6m` 見方），兼顧俯瞰視角可讀性與室內走位空間 |
| **樓層高度（Wall Height）** | `2.8m`（含屋頂蓋層 `3.0m`） | 俯瞰攝影機切換切頂時不會過度遮擋鄰街視線 |
| **牆體類型** | **薄邊緣式（Edge-based）**，厚度 `0.18m～0.22m` | 軸心（Pivot）置於牆段底面邊緣中心，便於 `0°/90°/180°/270°` 旋轉對齊格線邊界而不佔用完整地格 |
| **正面朝向（Forward）** | Godot `-Z` 為正面 | 便於 Step 4 依據鄰近道路方向自動旋轉門面 |
| **屋頂獨立節點** | 命名含 `Roof` 或歸屬群組 `RoofCutaway` | 角色走入建築內部碰撞框時自動淡出／隱藏屋頂 |
| **桌面物品掛點** | `Marker3D` 命名 `Socket_Loot_01`、`Socket_Clutter_01` | 擺放於茶幾、餐桌、流理台、床頭櫃頂面，供生成器自動掛載小物與物資 |
| **格式與材質** | `.glb`（推薦）或 `.fbx` | 材質維持簡潔乾淨（BaseColor / Roughness / Normal），**不需要額外繪製髒污版貼圖**，由共用 World-Space Noise 髒污著色器統一疊加冷灰塵埃與牆角侵蝕 |

---

## 2. 最小可行性（MVP）45～55 件資產清單

### A. 建築結構件（Architectural Kit，15 件）
| ID | 名稱 | 尺寸基準 | 備註 |
| :--- | :--- | :--- | :--- |
| `floor_wood` | 客廳木地板 | `1.6m × 1.6m` | 客廳／臥室基底 |
| `floor_tile` | 廚衛磁磚地板 | `1.6m × 1.6m` | 廚房／浴室基底 |
| `floor_concrete` | 水泥地基／走廊 | `1.6m × 1.6m` | 車庫／民防玄關／室外門廊 |
| `floor_yard` | 庭院草地／石板地磚 | `1.6m × 1.6m` | 無建物內格填充 |
| `wall_ext_solid` | 完整外牆（磚牆／水泥板） | `1.6m × 2.8m` | 可靠 Tint 換色 |
| `wall_ext_window` | 帶窗框外牆 | `1.6m × 2.8m` | 窗洞高度約 `0.9m～2.1m`（保留射擊／視線穿透） |
| `wall_ext_door` | 帶大門框外牆 | `1.6m × 2.8m` | 門寬約 `1.0m` |
| `wall_ext_ruined` | 半毀坍塌外牆 | `1.6m × 2.8m` | Step 5 替換用，露出斷裂鋼筋／磚塊缺口，可作為掩體或通行破口 |
| `wall_int_solid` | 室內隔間牆 | `1.6m × 2.8m` | 石膏／薄隔板 |
| `wall_int_door` | 室內門框牆 | `1.6m × 2.8m` | 連接 Nested Room Block |
| `wall_int_breach` | 破洞室內牆 | `1.6m × 2.8m` | Step 5 替換用，可讓喪屍或玩家抄近路 |
| `door_intact` | 完好木門／鐵門 | 適配 `1.0m` 門框 | 支援開關旋轉或破壞 |
| `door_broken` | 歪斜破損門板 | 適配 `1.0m` 門框 | Step 5 替換用 |
| `window_intact` | 完好玻璃窗扇 | 適配窗框 | 半透明冷藍玻璃 |
| `window_shattered` | 碎裂窗框（殘留鋸齒玻璃） | 適配窗框 | Step 5 替換用；後續可接木板封窗工事 |

*(屋頂可使用簡潔平頂／微斜屋頂片模組 `roof_slab_1x1` 依建築外框自動鋪設並綁定 `RoofCutaway`，不佔用上述額度或算作結構擴充。)*

### B. 房間核心大型家具（Key Furniture，16 件）
*所有檯面／櫃頂類家具皆需附帶至少 1 個 `Socket_Loot_*` 或 `Socket_Clutter_*`。*

- **客廳（4 件）**：`furn_sofa_double`（雙人布沙發）、`furn_armchair`（單人扶手椅）、`furn_coffee_table`（茶幾＋Socket）、`furn_tv_stand`（電視櫃含舊螢幕＋Socket）
- **廚房與餐廳（5 件）**：`furn_kitchen_sink`（流理台含水槽＋Socket）、`furn_stove_oven`（瓦斯爐烤箱）、`furn_fridge`（雙門冰箱）、`furn_dining_table`（餐桌＋Socket）、`furn_dining_chair`（餐椅）
- **臥室（4 件）**：`furn_bed_double`（雙人床）、`furn_bed_single`（單人床）、`furn_wardrobe`（衣櫃，可作大型室內掩體）、`furn_nightstand`（床頭櫃／書桌＋Socket）
- **衛浴（3 件）**：`furn_toilet`（馬桶）、`furn_bathroom_sink`（洗手台＋鏡框）、`furn_bathtub`（浴缸／淋浴隔間）

*(說明：剛體家具在 Step 5 廢墟濾鏡中直接由程式將 `X` 或 `Z` 軸旋轉 `90°` 並貼地，即可零美術成本產出「翻倒的桌子／書櫃／沙發掩體」。)*

### C. 廢墟破壞與自然侵蝕件（Ruins & Decay，10 件）
- **結構殘骸（4 件）**：`ruin_rubble_small`（牆角小型瓦礫堆）、`ruin_rubble_slab`（坍塌水泥天花板／磚堆）、`ruin_broken_beam`（斷裂橫梁）、`ruin_charcoal_pile`（焦黑木炭雜物堆）
- **民防封鎖工事（2 件）**：`ruin_window_planks`（釘於門窗的封鎖木板條）、`ruin_makeshift_cover`（民防沙包／門板斜靠掩體）
- **植被侵蝕（4 件）**：`decay_weed_cluster`（牆角雜草叢）、`decay_vine_wall`（爬牆藤蔓片）、`decay_shrub`（庭院枯黃灌木）、`decay_cracked_asphalt`（路緣破損塊）

### D. 敘事雜物與貼花（Clutter & Decals，11 件）
- **桌面／地面小物件（7 件）**：`prop_mug`（馬克杯）、`prop_tin_can`（空罐頭）、`prop_medkit_box`（醫藥箱／繃帶盒）、`prop_desk_lamp`（檯燈）、`prop_book_stack`（散落書本／文件夾）、`prop_trash_bin`（傾倒垃圾桶）、`prop_cardboard_box`（儲物紙箱）
- **投影貼花 Decal 貼圖（4 張透明 PNG，不佔用碰撞與 NavMesh）**：`decal_floor_cracks.png`（水泥裂縫）、`decal_blood_splatter.png`（暗紅乾涸血跡）、`decal_scorch_mark.png`（焦痕）、`decal_scattered_papers.png`（散落報紙文件與破舊地毯）

---

## 3. 《少女前線2：追放》冷峻風格色調指引
- **牆面與結構**：低飽和冷灰、水泥白、深鐵灰、褪色藍灰磚面，避免高飽和暖黃／鮮紅玩具色。
- **家具與生活物件**：褪色軍綠、炭灰、霧藍、舊深棕木質；金屬邊緣保留微弱冷藍高光。
- **節省工作量原則**：所有模組保持中性偏冷的乾淨基底貼圖，由 Godot World-Space Noise 髒污著色器依世界座標自動加上牆腳潮濕、灰塵與鏽痕。
