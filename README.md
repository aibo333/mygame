# mygame — 甲鐵廢墟戰線（Godot 4 · 基礎美術與視角原型）

> **Blue Archive 風格 3D 美少女小人 × LOL 固定俯瞰視角 × 《少女前線 2：追放》末日城市廢墟 × 《甲鐵城的卡巴內利》裝甲列車移動基地**，使用 **Godot 4 (GDScript)** 與 **Blender 4 Headless 自動化美術產線**開發。
>
> *(歷史原型封存標籤：`v0.2-web-prototype` 為早期 Three.js 網頁版；`v0.3-medieval-godot-prototype` 為中世紀戰意 TPS 原型。)*

## 環境與啟動方式
1. 使用 **Godot Engine 4.x** 開啟本資料夾（載入 `project.godot`）並按 **F5** 即可進入黃昏末日廢墟與甲鐵城基地場景。
2. 命令列直接啟動或跑自動化驗證：
   ```bash
   godot --path .
   godot --headless --path . --script tests/run_tests.gd
   ```

## 本階段基礎美術資產一覽
1. **3 名 Blue Archive 風格 3D 綁骨美少女小人**（含高解析動漫臉部 UV、賽璐璐描邊著色器、發光光環 Halo 與 4 大基礎動作＋待機）：
   - **`[1]` 白羽 玲奈（Reina）** — 銀白高馬尾・突擊步槍隊長（青藍星環光環）→ `assets/models/characters/reina_ar.glb`
   - **`[2]` 蒼井 千紗（Chisa）** — 深藍短髮護目鏡・衝鋒槍工兵（琥珀齒輪光環）→ `assets/models/characters/chisa_smg.glb`
   - **`[3]` 星野 莉莉（Lily）** — 暖金雙馬尾・重型霰彈先鋒（緋紅準心光環）→ `assets/models/characters/lily_sg.glb`
   - **內建骨架動畫（AnimationPlayer）**：`walk`（走路）、`shoot`（開槍）、`interact`（摸東摸西：開鎖／製作）、`roll`（戰術翻滾）、`idle`（待機）
2. **LOL 固定俯瞰視角**（`scripts/camera/LolCameraController.gd`）：
   - 取消肩後 TPS 與滑鼠鎖定；採用固定 52° 俯角＋窄 FOV 戰術等距透視。
3. **《少女前線 2：追放》黃昏末日城市廢墟套件**（`assets/models/ruins/*.glb`）：
   - 崩塌粗獷主義大樓、斷裂高架橋墩、生鏽廢棄車輛、水泥護欄與沙包掩體、歪斜路燈與可互動加密補給箱。
4. **《甲鐵城的卡巴內利》風格裝甲列車基地**（`assets/models/train/kabaneri_armored_train.glb`）：
   - 楔形破障排障器、鉚釘鋼板與深紅塗裝、側邊發光蒸氣爐心、雙煙囪蒸氣粒子、車頂雙管旋轉防禦砲塔、開放式基地整備艙與登車斜坡。

## 操作速覽
- **角色切換**：`1` / `2` / `3`（其餘 2 名隊員自動跟隨編隊）
- **移動（走路）**：`WASD` 或 `滑鼠右鍵點擊地面`
- **開槍**：按住 `滑鼠左鍵` 朝游標方向射擊（含槍口火光與彈道曳光）
- **摸東摸西（開鎖／製作）**：按住 `E` 或 `F`（靠近補給箱或列車整備工作台會顯示互動提示與進度條）
- **戰術翻滾**：`Space` 或 `Shift`
- **LOL 俯瞰鏡頭**：`滑鼠滾輪` 縮放、`Y` 切換鎖定跟隨／自由平移、`中鍵拖曳` 或 `方向鍵` 移鏡、`C`／`Home` 回到角色
- **右下角檢視台**：可直接一鍵預覽 4 種動作，並可勾選「全員同步」讓 3 名小人同時展示動作！

## 自動化美術產線（可隨時微調重產）
```bash
python3 tools/art_pipeline/generate_textures.py
blender --background --python tools/art_pipeline/build_chibi_characters.py
blender --background --python tools/art_pipeline/build_kabaneri_train.py
blender --background --python tools/art_pipeline/build_ruins_kit.py
```

## 規格與架構文件
- 架構決策紀錄：`docs/adr/`（最新轉型詳見 `docs/adr/0004-art-pivot-anime-chibi-lol-camera-ruins-train.md`）
