# 外部素材包管理指南（Google Drive × GitHub 碼圖分離）

本專案採用 **「純原始碼與 Godot 匯入設定放 GitHub，大型二進位素材包放 Google Drive」** 的跨機器工作流，避免 Git 膨脹並隔離第三方素材授權。

## 目前素材包資訊
- **版本**：`v1`
- **壓縮檔名稱**：`mygame-assets-v1.zip`（186 個檔案，約 17.45 MB）
- **Google Drive 資料夾 (`mygame-repo`)**：https://drive.google.com/drive/folders/19ivogNI_AVD2hojZVCPThiHL_QI7RFoe
- **Google Drive 檔案連結**：https://drive.google.com/file/d/1BH95g2EP2LUsAICN4jM914yg-POeZVP-/view
- **內含素材**：
  - `assets/packs/kenney_retro_urban/` — Kenney Retro Urban Kit（CC0 復古都市模組 124 件與貼圖）
  - `assets/packs/summer_cuteness_avatar/` — SummerCuteness 動漫角色 FBX 與 2K 材質貼圖（原型測試用）
  - `assets/animations/mixamo/` — 4 支 Mixamo 真人動捕動作（`rifle_idle`、`rifle_run`、`firing_rifle`、`dive_roll`）

> [!IMPORTANT]
> 所有 `*.import`（含 `BoneMap` 人形骨骼重定向與 `fix_silhouette` 設定）及 `assets/animations/*.tres` 均**保留於 Git 中**；壓縮包內不含 `.import`，解包時不會覆蓋重定向規則。

## 換到另一台電腦的 3 步驟還原流程
1. 拉取最新程式碼：
   ```bash
   git clone https://github.com/aibo333/mygame.git
   cd mygame
   ```
2. 從上方 Google Drive 連結下載 `mygame-assets-v1.zip`，執行一鍵解包與完整性檢查：
   ```bash
   python tools/pack_assets.py unpack path/to/mygame-assets-v1.zip
   python tools/pack_assets.py verify
   ```
3. 讓 Godot 4 依 Git 內的 `.import` 規則重建本機 `.godot/` 快取並執行驗證：
   ```bash
   godot --headless --path . --import
   godot --headless --path . --script tests/run_tests.gd
   ```

## 新增或更新素材後如何重新打包上傳
```bash
python tools/pack_assets.py pack --out dist/mygame-assets-v2.zip --version v2 --drive-folder-id 19ivogNI_AVD2hojZVCPThiHL_QI7RFoe
```
打包後將新 zip 上傳至 Google Drive `mygame-repo` 資料夾，並將更新後的 `assets_manifest.json` 與任何新增的 `*.import` / `*.tres` 提交至 GitHub 即可。
