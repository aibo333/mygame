# mygame — 復古都市戰術動作原型（Godot 4）

> **Kenney Retro Urban Kit 模組化復古都市街區 × 現成 3D 動漫角色（SummerCuteness） × Adobe Mixamo 真人動捕骨骼重定向（Godot 4 `SkeletonProfileHumanoid`）**，採 **GitHub 純原始碼 ＋ Google Drive 外部素材包** 異地開發架構。
>
> *(歷史原型封存標籤：`v0.2-web-prototype` 為早期 Three.js 網頁版；`v0.3-medieval-godot-prototype` 為中世紀戰意 TPS 原型。)*

---

## 異地開發流程（GitHub 原始碼 × Google Drive 素材包）

為避免大型 3D／貼圖／動作檔讓 Git Repo 膨脹並隔離第三方素材授權，本專案採**碼圖分離**工作流：

| 存放位置 | 管理內容 | 備註 |
| :--- | :--- | :--- |
| **GitHub Repo** | GDScript 程式碼、`.tscn` 場景、`.gdshader`、測試、`assets_manifest.json`、以及**所有 `*.import` 與 `BoneMap` `*.tres`** | 保留 `.import` 與 `.tres` 才能確保各台電腦還原時維持完全一致的骨骼重定向設定 |
| **Google Drive (`mygame-repo`)** | 外部大型二進位素材包 `mygame-assets-v*.zip`（`assets/packs/` 與 `assets/animations/mixamo/*.fbx`） | 壓縮包刻意排除 `*.import` 與 `*.tres`，解包時絕不覆蓋 Git 設定 |

- **Google Drive 資料夾**：https://drive.google.com/drive/folders/19ivogNI_AVD2hojZVCPThiHL_QI7RFoe
- **目前素材包（`v1`）**：https://drive.google.com/file/d/1BH95g2EP2LUsAICN4jM914yg-POeZVP-/view （詳細資產清單見 [ASSETS.md](ASSETS.md)）

### 情境 A：在另一台電腦拉取專案並還原環境
1. **拉取或更新原始碼**：
   ```bash
   git clone https://github.com/aibo333/mygame.git
   cd mygame
   # （既有本機則改執行 git pull origin main）
   ```
2. **下載素材包並一鍵解包驗證**（從上方 Google Drive 下載目前版本的 `mygame-assets-v*.zip`）：
   ```bash
   python tools/pack_assets.py unpack path/to/mygame-assets-v1.zip
   python tools/pack_assets.py verify
   ```
   > 若使用具備 Google Drive 插件的 AI 助理，也可直接下指令請助理依 `assets_manifest.json` 的 `drive_file_id` 自動下載解包。
3. **重建 Godot 4 本機快取並執行驗證**：
   ```bash
   godot --headless --path . --import
   godot --headless --path . --script tests/run_tests.gd
   ```
   *(Windows 若透過 WinGet 安裝，命令為 `Godot_v4.7.2-stable_win64_console.exe`。)*
4. **啟動 DEMO**（或用 Godot 4 編輯器開啟 `project.godot` 按 **F5**）：
   ```bash
   godot --path . scenes/Main.tscn
   ```

### 情境 B：在本機新增或更新素材後如何同步給其他電腦
1. 將新素材放入 `assets/packs/...` 或 `assets/animations/mixamo/`，並在 Godot 中完成匯入與 `.import`（如 `BoneMap`）調整。
2. 執行一鍵打包（自動排除 `*.import` / `*.tres`，並更新 `assets_manifest.json`）：
   ```bash
   python tools/pack_assets.py pack --out dist/mygame-assets-v2.zip --version v2 --drive-folder-id 19ivogNI_AVD2hojZVCPThiHL_QI7RFoe
   ```
3. 將 `dist/mygame-assets-v2.zip` 上傳至 Google Drive 的 `mygame-repo` 資料夾，並把新檔案 ID 更新至 `assets_manifest.json` 與 [ASSETS.md](ASSETS.md)（及本 README 連結）。
4. 確認 `git status` 沒有夾帶任何大型二進位檔後，將程式碼、新增的 `*.import` / `*.tres` 與 `assets_manifest.json` 提交並推送至 GitHub：
   ```bash
   git add -A
   git commit -m "chore: update asset bundle to v2"
   git push origin main
   ```

---

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
