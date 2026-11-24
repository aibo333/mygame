# mygame — 復古都市戰術動作原型（Godot 4）

> **Kenney Retro Urban Kit 模組化復古都市街區 × 現成 3D 動漫角色（SummerCuteness） × Adobe Mixamo 真人動捕骨骼重定向（Godot 4 `SkeletonProfileHumanoid`）**，採 **GitHub 純原始碼 ＋ Google Drive 外部素材包** 異地開發架構。
>
> *(歷史原型封存標籤：`v0.2-web-prototype` 為早期 Three.js 網頁版；`v0.3-medieval-godot-prototype` 為中世紀戰意 TPS 原型。)*

## 跨電腦快速啟動（碼／圖分離）
本 Repo **僅保留原始碼、場景、著色器與 Godot 匯入設定（`.import` / `.tres`）**；大型 3D／貼圖／動作二進位檔請從 Google Drive 取得（詳見 [ASSETS.md](ASSETS.md)）：

1. 取得外部素材包 `mygame-assets-v1.zip`（詳見 [ASSETS.md](ASSETS.md)）並解包至專案根目錄：
   ```bash
   python tools/pack_assets.py unpack path/to/mygame-assets-v1.zip
   python tools/pack_assets.py verify
   ```
2. 重建本機 Godot 4 快取（自動套用 Git 內的 `BoneMap` 重定向設定）並跑自動化測試：
   ```bash
   godot --headless --path . --import
   godot --headless --path . --script tests/run_tests.gd
   ```
3. 直接啟動 DEMO 或用 Godot 4 編輯器開啟 `project.godot` 按 **F5**：
   ```bash
   godot --path . scenes/Main.tscn
   ```

## 目前原型重點
1. **純現成模組都市街區**（`scripts/world/RuinsBaseWorld.gd`）：
   - 採用 **Kenney Retro Urban Kit**（124 個 CC0 模組、`3.2m` 格線），建構 16×12 格復古都市街區（柏油十字路口、抬升人行道、三層鋸齒屋頂工廠、鋼構鷹架塔、紅磚工坊、鐵圍籬貨運院子、卡車與貨櫃、秋樹公園、路障檢查哨與黃昏路燈）。
2. **單人玩家 × Mixamo 骨骼重定向**（`scripts/entities/SquadCharacter.gd`）：
   - 使用 Godot 4 原生 `SkeletonProfileHumanoid`（`assets/animations/bonemap_bip001.tres` + `bonemap_mixamo.tres`）將 4 支 Mixamo 真人動捕（`rifle_idle`、`rifle_run`、`firing_rifle`、`dive_roll`）重定向至免費動漫角色骨架，自動濾除水平位移並補償腳踝角度。
3. **雙視角即時切換**（`scripts/camera/LolCameraController.gd`）：
   - 支援 **`O` 鍵**即時切換 **Project Zomboid 45° 正交等角視角** 與 **RO / HD-2D 透視視角**（`WASD` 移動方向自動對齊鏡頭）。

## 操作速覽
- **奔跑移動**：`WASD` 或 `滑鼠右鍵點擊地面`
- **開槍射擊**：按住 `滑鼠左鍵` 朝游標方向射擊（含槍口動態火光與彈道曳光）
- **戰術撲地翻滾**：`Space` 或 `Shift`
- **互動搜刮**：靠近青藍色互動圓環按住 `E` 或 `F`
- **鏡頭控制**：`O` 切換 Zomboid 正交等角／RO 透視、`Y` 切換鎖定跟隨／自由平移、`滾輪`縮放、`中鍵拖曳`／`方向鍵`移鏡、`C`/`Home` 回到角色
- **右下角檢視台**：可直接點擊原地循環預覽各項 Mixamo 動捕動作。
