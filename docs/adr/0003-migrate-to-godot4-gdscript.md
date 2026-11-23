# ADR-0003: 遷移至 Godot 4 (GDScript) 遊戲引擎

- **狀態**：已採納（Accepted）
- **日期**：2026-11-23

## 背景（Context）

在 ADR-0002 將 Web 原型從 Phaser 3 升級至 Three.js 後，我們驗證了 3D 俯視角與《戰意》肩後 TPS 視角的可玩性與視覺潛力。然而一旦深入 3D 動作遊戲領域（防穿牆彈簧臂鏡頭、360° 游標視角、未來 3D 骨骼動畫混合、立體城牆地形碰撞與 10 人兵團 3D 尋路避障），基於純繪圖庫 Three.js 開發會不斷耗費精力在「重複造基礎引擎輪子」上，偏離「專注打磨核心玩法」的目標。

## 決策（Decision）

1. **將專案引擎正式遷移至 Godot 4（GDScript）**：
   - 善用 Godot 4 原生開箱即用的 3D 基礎設施：`CharacterBody3D`（3D 物理與斜坡）、`SpringArm3D`（防穿牆 TPS 鏡頭）、`NavigationAgent3D`（3D 尋路避障）、`AnimationTree`（骨骼動畫混合）與 `MultiplayerSynchronizer`（未來連線）。
2. **保留既有 Web 原型為 Git 封存標籤**：
   - 完整 Web 原型（Vite + React + Three.js + Vitest）封存於 Git Tag `v0.2-web-prototype`，根目錄清理為標準 Godot 4 專案結構。
3. **沿用 GDD v0.2 核心玩法規格**：
   - 維持《戰意》式「武將手操（WASD / 滑鼠連段 / Space 翻滾 / Q 破陣 / E 戰吼）＋ 3 支兵團即時指揮（C/X/V/F/1/2）＋ `Tab` 雙視角切換 ＋ Roguelike 守城波次」。

## 影響（Consequences）

- **正面**：大幅減少底層 3D 基礎設施開發時間，直接專注於戰鬥手感、兵團 AI、關卡地形與 Roguelike 玩法循環；`.gd` 與 `.tscn` 皆為純文字格式，對 Git 版控與 AI Agent 協作高度友善。
- **代價**：給朋友試玩改以匯出 Windows 執行檔（或 itch.io）為主，不再以本機 Vite 網頁即時開啟。
