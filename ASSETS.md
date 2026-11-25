# 外部素材包管理指南（Google Drive × GitHub 碼圖分離）

本專案採用 **「純原始碼與 Godot 匯入設定放 GitHub，大型二進位素材包放 Google Drive」** 的跨機器工作流，避免 Git 膨脹並隔離第三方素材授權。

## 目前素材包資訊
- **版本**：`v2`
- **壓縮檔名稱**：`mygame-assets-v2.zip`（719 個檔案，約 414.85 MB，未壓縮約 445.71 MB）
- **Google Drive 資料夾 (`mygame-repo`)**：https://drive.google.com/drive/folders/19ivogNI_AVD2hojZVCPThiHL_QI7RFoe
- **Google Drive 檔案連結**：https://drive.google.com/file/d/1BlBT5iHU0Jp90U2IV5_Zjkfw4SI7OTwn/view
- **內含素材**：
  - `assets/packs/kenney_retro_urban/` — Kenney Retro Urban Kit（CC0 復古都市模組 124 件與貼圖）
  - `assets/packs/summer_cuteness_avatar/` — SummerCuteness 動漫角色 FBX 與 2K 材質貼圖
  - `assets/packs/aria_idol_cuteness_avatar/` — Aria Idol Cuteness 動漫角色 FBX 與 2K 材質貼圖
  - `assets/packs/nangong_yu_cuteness_avatar/` — Nangong Yu Cuteness 動漫角色 FBX 與 2K 材質貼圖
  - `assets/packs/cs2_weapons_sound_pack/` — CS2 武器音效包（含 M4A1-S、AK-47、Desert Eagle 等槍聲、換彈、消音器音效）
  - `assets/animations/mixamo/` — 11 支 Mixamo 真人動捕動作（`rifle_idle`、`rifle_run`、`firing_rifle`、`dive_roll`、`strafe_left`、`strafe_right`、`run_backwards`、`reloading`、`reload_move`、`hit_reaction`、`death`）
  - `assets/models/weapons/` — 3 把武器 3D 模型與貼圖（`m4a1s/` M4A1-S、`ak47/` AK-47、`deagle/` Desert Eagle）

> [!IMPORTANT]
> 所有 `*.import`（含 `BoneMap` 人形骨骼重定向與 `fix_silhouette` 設定）及 `assets/animations/*.tres` 均**保留於 Git 中**；壓縮包內不含 `.import`，解包時不會覆蓋重定向規則。

## 換到另一台電腦的 3 步驟還原流程
1. 拉取最新程式碼：
   ```bash
   git clone https://github.com/aibo333/mygame.git
   cd mygame
   ```
2. 從上方 Google Drive 連結下載 `mygame-assets-v2.zip`，執行一鍵解包與完整性檢查：
   ```bash
   python tools/pack_assets.py unpack path/to/mygame-assets-v2.zip
   python tools/pack_assets.py verify
   ```
3. 讓 Godot 4 依 Git 內的 `.import` 規則重建本機 `.godot/` 快取並執行驗證：
   ```bash
   godot --headless --path . --import
   godot --headless --path . --script tests/run_tests.gd
   ```

## 新增或更新素材後如何重新打包上傳
```bash
python tools/pack_assets.py pack --out dist/mygame-assets-v3.zip --version v3 --drive-folder-id 19ivogNI_AVD2hojZVCPThiHL_QI7RFoe
```
打包後將新 zip 上傳至 Google Drive `mygame-repo` 資料夾，並將更新後的 `assets_manifest.json` 與任何新增的 `*.import` / `*.tres` 提交至 GitHub 即可。
